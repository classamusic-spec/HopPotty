import AVFoundation
import Foundation
import HopPottyCore

// MARK: - Observable state

/// What the UI needs to know about audio right now.
///
/// The caption is the important one. When a line has no recording — which is
/// every line today — the *caption is the delivery*, not a consolation prize,
/// and the routine screen renders it from here.
@Observable
@MainActor
final class AudioState {
    /// The caption for the line currently being delivered, spoken or not.
    var currentCaption: String?
    /// Why the current line is text-only, when it is. `nil` while audio plays.
    var captionReason: HopVoiceUnavailability?
    var isSpeaking = false
    var isAmbientPlaying = false
    /// Lines this session asked for that had no audio. Surfaced in the debug
    /// lab, never to a caregiver.
    private(set) var missingAudioCount = 0

    func noteMissingAudio() { missingAudioCount += 1 }
}

// MARK: - Protocol

@MainActor
protocol AudioProviding: AnyObject {
    var state: AudioState { get }

    /// Delivers a line, by audio plus caption or by caption alone.
    ///
    /// Returns the decision so the caller can render the caption *and* know
    /// whether anything was audible — a routine step that must wait for Hop to
    /// finish speaking should not wait when nothing is speaking.
    @discardableResult
    func speak(_ line: HopVoiceLine) -> HopVoicePlayback

    /// Stops Hop mid-line. Called when the child taps ahead.
    func stopSpeaking()

    func play(_ effect: HopSoundEffect)

    /// Starts the pond bed, if ambient audio is on. Bounded — see
    /// `maximumAmbientDuration`.
    func startAmbient(_ track: HopAmbientTrack)
    func stopAmbient()

    /// Everything off, session deactivated. Called on background and when a
    /// Potty Pause hands the screen back.
    func stopAll()

    /// Applies the caregiver's three switches.
    func apply(_ settings: AppSettings)
}

// MARK: - Service

/// Plays Hop's voice, sound effects and the ambient bed.
///
/// ## Deliberately absent: speech synthesis
///
/// `AVSpeechSynthesizer` is not imported here and must not be. A synthesised
/// voice reading Hop's lines would be a different character every time the
/// system voice changed, would mispronounce the word "potty" in several locales,
/// and would turn a warm, cast performance into a screen reader. When a line has
/// no recording, HopPotty shows the caption — which every line has, by contract
/// §6 — and says nothing. A caption is an honest absence; a robot voice is a
/// wrong presence.
///
/// ## Session behaviour
///
/// The child may be resuming a video, and HopPotty interrupts on purpose but
/// should not seize the device:
///
/// - **Effects and ambience** use `.ambient` with `.mixWithOthers`. They mix
///   under whatever is playing and are silenced by the ring switch, which is
///   the correct behaviour for decoration.
/// - **Hop's voice** uses `.playback` with `.mixWithOthers` and `.duckOthers`,
///   so the video the child was watching drops in volume for the length of the
///   line and comes back. Ducking requires `.playback`; it is not a legal
///   option on `.ambient`, which is why the category moves.
/// - The session is deactivated with `.notifyOthersOnDeactivation` as soon as
///   nothing is playing, so the other app's volume returns promptly.
@MainActor
final class AudioService: AudioProviding {
    let state = AudioState()

    private let assets: any AudioAssetResolving
    private var settings: AppSettings
    private var availableVoiceAssets: Set<HopVoiceAssetKey>

    private var voicePlayer: AVAudioPlayer?
    private var effectPlayer: AVAudioPlayer?
    private var ambientPlayer: AVAudioPlayer?

    private var voiceStopTask: Task<Void, Never>?
    private var ambientStopTask: Task<Void, Never>?
    private var interruptionObserver: (any NSObjectProtocol)?

    /// The ceiling on a single ambient run.
    ///
    /// Nothing in HopPotty loops for ever. An eight-minute bed covers any
    /// screen a child is on, and when it ends it ends — a sound that has been
    /// playing since breakfast is a sound nobody notices and a battery nobody
    /// can account for.
    static let maximumAmbientDuration: TimeInterval = 8 * 60

    /// Ambience sits well under speech and effects.
    static let ambientVolume: Float = 0.35
    static let effectVolume: Float = 0.7

    init(
        assets: any AudioAssetResolving = BundleAudioAssetResolver(),
        settings: AppSettings = AppSettings()
    ) {
        self.assets = assets
        self.settings = settings
        // Probed once at construction: a bundle's contents cannot change while
        // the app runs, and probing per line would hit the file system on every
        // routine step.
        self.availableVoiceAssets = assets.availableVoiceAssets()
        observeInterruptions()
        HopLog.persistence.info(
            "audio ready recordedVoiceAssets=\(self.availableVoiceAssets.count, privacy: .public)"
        )
    }

    // No `deinit` unregistering the observer, deliberately. `deinit` on a
    // `@MainActor` class is non-isolated, so touching an isolated stored
    // property from it is exactly the kind of concurrency corner this codebase
    // avoids. `AudioService` is created once and lives as long as the app; the
    // observer is released with it.

    // MARK: Settings

    func apply(_ settings: AppSettings) {
        self.settings = settings
        if !settings.hopVoiceEnabled { stopSpeaking() }
        if !settings.ambientAudioEnabled { stopAmbient() }
    }

    // MARK: Voice

    @discardableResult
    func speak(_ line: HopVoiceLine) -> HopVoicePlayback {
        // The decision itself is Core's, and it is pure: caregiver switch plus
        // the set of assets that exist. The service only carries it out.
        let resolver = HopVoiceResolver(
            isVoiceEnabled: settings.hopVoiceEnabled,
            availableAssets: availableVoiceAssets
        )
        let playback = resolver.playback(for: line)
        state.currentCaption = playback.caption

        switch playback {
        case .captionOnly(_, let reason):
            state.captionReason = reason
            state.isSpeaking = false
            stopVoicePlayer()
            if reason == .assetMissingFromBundle { state.noteMissingAudio() }
            return playback

        case .play(let key, _):
            state.captionReason = nil
            guard let url = assets.url(forAsset: key.rawValue, category: .hopVoice) else {
                // The resolver said the asset was available and the file has
                // gone. Degrade explicitly to the caption rather than falling
                // silent with nothing on screen.
                state.captionReason = .assetMissingFromBundle
                state.isSpeaking = false
                state.noteMissingAudio()
                HopLog.persistence.error("voice asset vanished between probe and play")
                return .captionOnly(caption: line.caption, because: .assetMissingFromBundle)
            }
            playVoice(url: url, caption: line.caption)
            return playback
        }
    }

    func stopSpeaking() {
        stopVoicePlayer()
        state.isSpeaking = false
        deactivateSessionIfIdle()
    }

    private func playVoice(url: URL, caption: String) {
        stopVoicePlayer()
        guard activateSession(for: .hopVoice) else { return }
        guard let player = makePlayer(url: url, volume: 1) else { return }
        voicePlayer = player
        state.isSpeaking = true
        player.play()

        // Completion is timed rather than delegated. `AVAudioPlayerDelegate` is
        // not main-actor isolated, so conforming this class to it under Swift 6
        // means an `@unchecked Sendable` shim for no benefit: the duration is
        // known exactly, and being a few milliseconds late to clear a flag
        // costs nothing.
        let duration = player.duration
        voiceStopTask?.cancel()
        voiceStopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, duration) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.state.isSpeaking = false
            self?.deactivateSessionIfIdle()
        }
    }

    private func stopVoicePlayer() {
        voiceStopTask?.cancel()
        voiceStopTask = nil
        voicePlayer?.stop()
        voicePlayer = nil
    }

    // MARK: Effects

    func play(_ effect: HopSoundEffect) {
        guard settings.soundEffectsEnabled else { return }
        guard let url = assets.url(forAsset: effect.assetName, category: .soundEffect) else {
            // An effect has no caption and needs none: it decorates something
            // that is already on screen. A missing file is logged once and the
            // interaction proceeds in silence, which is a complete experience.
            HopLog.persistence.debug(
                "effect asset missing name=\(effect.rawValue, privacy: .public)"
            )
            return
        }
        guard activateSession(for: .soundEffect) else { return }
        effectPlayer?.stop()
        effectPlayer = makePlayer(url: url, volume: Self.effectVolume)
        effectPlayer?.play()
    }

    // MARK: Ambient

    func startAmbient(_ track: HopAmbientTrack) {
        guard settings.ambientAudioEnabled else { return }
        guard let url = assets.url(forAsset: track.assetName, category: .ambient) else {
            HopLog.persistence.debug("ambient asset missing name=\(track.rawValue, privacy: .public)")
            return
        }
        guard activateSession(for: .ambient) else { return }
        stopAmbient()
        guard let player = makePlayer(url: url, volume: Self.ambientVolume) else { return }

        // Bounded looping, two ways: a finite loop count derived from the file's
        // own length, and a hard stop task. Either alone would be enough; both
        // together mean a zero-length or mis-encoded file cannot produce an
        // endless bed.
        let clipLength = max(1, player.duration)
        player.numberOfLoops = max(0, Int(Self.maximumAmbientDuration / clipLength) - 1)
        ambientPlayer = player
        state.isAmbientPlaying = true
        player.play()

        ambientStopTask?.cancel()
        ambientStopTask = Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(Self.maximumAmbientDuration * 1_000_000_000)
            )
            guard !Task.isCancelled else { return }
            self?.stopAmbient()
        }
    }

    func stopAmbient() {
        ambientStopTask?.cancel()
        ambientStopTask = nil
        ambientPlayer?.stop()
        ambientPlayer = nil
        state.isAmbientPlaying = false
        deactivateSessionIfIdle()
    }

    // MARK: Everything off

    func stopAll() {
        stopVoicePlayer()
        effectPlayer?.stop()
        effectPlayer = nil
        stopAmbient()
        state.isSpeaking = false
        state.currentCaption = nil
        state.captionReason = nil
        deactivateSessionIfIdle()
    }

    // MARK: Players

    private func makePlayer(url: URL, volume: Float) -> AVAudioPlayer? {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()
            return player
        } catch {
            HopLog.persistence.error(
                "audio player init failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            return nil
        }
    }

    // MARK: Session

    private var activeCategory: HopAudioCategory?

    /// Configures and activates the session for one category.
    ///
    /// Returns `false` when the session refuses, which happens for real — a
    /// phone call, a CarPlay handover — and must degrade to silence rather than
    /// to an error the child sees.
    private func activateSession(for category: HopAudioCategory) -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            if activeCategory != category {
                switch category {
                case .hopVoice:
                    // `.duckOthers` is only legal on `.playback`,
                    // `.playAndRecord` or `.multiRoute`; this is why the
                    // category moves for a spoken line.
                    try session.setCategory(
                        .playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers]
                    )
                case .soundEffect, .ambient:
                    // `.ambient` mixes and obeys the ring switch: the right
                    // manners for decoration.
                    try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                }
                activeCategory = category
            }
            try session.setActive(true)
            return true
        } catch {
            HopLog.persistence.error(
                "audio session activate failed category=\(category.rawValue, privacy: .public) error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            return false
        }
    }

    /// Hands the session back the moment nothing is playing, so a ducked video
    /// returns to full volume without waiting for the app to be backgrounded.
    private func deactivateSessionIfIdle() {
        guard voicePlayer == nil, ambientPlayer == nil else { return }
        guard effectPlayer?.isPlaying != true else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            activeCategory = nil
        } catch {
            // Not worth surfacing: the session deactivates on background anyway.
            HopLog.persistence.debug("audio session deactivate deferred")
        }
    }

    // MARK: Interruptions

    /// Stops on a phone call or a Siri invocation, and does **not** resume.
    ///
    /// Automatic resumption would have Hop start talking again in the middle of
    /// whatever the family turned to instead. The routine step is still on
    /// screen with its caption; a tap replays the line.
    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { notification in
            // Only a plain `UInt` crosses into the task: `Notification` is not
            // `Sendable`, and nothing else in it is needed.
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak self] in
                self?.stopAll()
            }
        }
    }
}

// MARK: - Mock

/// Records what would have been played. Previews and tests.
@MainActor
final class MockAudioService: AudioProviding {
    let state = AudioState()
    private(set) var spokenLines: [HopVoiceLineID] = []
    private(set) var playedEffects: [HopSoundEffect] = []
    private(set) var ambientTrack: HopAmbientTrack?
    /// Voice assets to pretend exist. Empty by default, which is the real
    /// launch state and the one previews should show.
    var availableVoiceAssets: Set<HopVoiceAssetKey> = []
    var settings = AppSettings()

    @discardableResult
    func speak(_ line: HopVoiceLine) -> HopVoicePlayback {
        spokenLines.append(line.id)
        let playback = HopVoiceResolver(
            isVoiceEnabled: settings.hopVoiceEnabled,
            availableAssets: availableVoiceAssets
        ).playback(for: line)
        state.currentCaption = playback.caption
        state.isSpeaking = playback.isAudible
        if case .captionOnly(_, let reason) = playback { state.captionReason = reason }
        return playback
    }

    func stopSpeaking() { state.isSpeaking = false }
    func play(_ effect: HopSoundEffect) { playedEffects.append(effect) }
    func startAmbient(_ track: HopAmbientTrack) {
        ambientTrack = track
        state.isAmbientPlaying = true
    }
    func stopAmbient() {
        ambientTrack = nil
        state.isAmbientPlaying = false
    }
    func stopAll() {
        stopSpeaking()
        stopAmbient()
        state.currentCaption = nil
    }
    func apply(_ settings: AppSettings) { self.settings = settings }
}
