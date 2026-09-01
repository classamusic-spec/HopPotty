import AVFoundation
import Foundation
import HopPottyCore

// MARK: - Categories

/// The three independent audio channels. Each has its own switch in Settings and
/// none is required for any feature to work.
enum HopAudioCategory: String, CaseIterable, Sendable {
    /// Hop speaking. Always accompanied by a caption.
    case hopVoice
    /// Short interface and celebration sounds.
    case soundEffect
    /// A quiet pond bed under the child-facing screens. Off by default.
    case ambient

    func isEnabled(in settings: AppSettings) -> Bool {
        switch self {
        case .hopVoice: settings.hopVoiceEnabled
        case .soundEffect: settings.soundEffectsEnabled
        case .ambient: settings.ambientAudioEnabled
        }
    }

    /// Sub-directory of the bundle this category's files live in. Keeping them
    /// apart means a missing *voice* bundle cannot be mistaken for a missing
    /// *effects* bundle when diagnosing a build.
    var bundleSubdirectory: String {
        switch self {
        case .hopVoice: "Audio/Voice"
        case .soundEffect: "Audio/Effects"
        case .ambient: "Audio/Ambient"
        }
    }
}

// MARK: - Effects and ambience

/// Every sound effect HopPotty can play. Closed, so an effect cannot be
/// introduced without appearing in this list and in the asset audit.
enum HopSoundEffect: String, CaseIterable, Sendable {
    /// A star landing in the pond. The one celebratory sound the child hears often.
    case starEarned
    /// The full routine finishing.
    case routineComplete
    /// A pond decoration appearing.
    case pondUnlock
    /// A large child-facing button being pressed.
    case tap
    /// A gentle chime when the pause screen appears. Never an alarm — the
    /// child is being invited, not summoned.
    case pauseArrive
    /// Water for the hand-washing step.
    case waterSplash

    var assetName: String { "sfx_" + rawValue }
}

/// Background beds. Short, quiet, and bounded — see
/// `AudioService.maximumAmbientDuration`.
enum HopAmbientTrack: String, CaseIterable, Sendable {
    case meadowPond
    var assetName: String { "amb_" + rawValue }
}

// MARK: - Asset resolution

/// Finds audio files. The seam that lets the app run with no audio at all.
///
/// The production voice assets do not exist yet — every line in
/// `HopVoiceCatalog` is `.planned`. That is a normal state, not a failure, and
/// the whole point of this protocol is that the app behaves *identically well*
/// whether or not a file is there: the caption is shown either way, and the
/// absence is reported rather than swallowed.
protocol AudioAssetResolving: Sendable {
    /// The file for an asset name, or `nil` when it is not in the bundle.
    func url(forAsset name: String, category: HopAudioCategory) -> URL?
    /// Voice asset keys actually present. Feeds `HopVoiceResolver`, which is
    /// what decides between playing and captioning.
    func availableVoiceAssets() -> Set<HopVoiceAssetKey>
}

/// Looks assets up in the app bundle.
struct BundleAudioAssetResolver: AudioAssetResolving {
    let bundle: Bundle
    /// Extensions tried in order. M4A first: it is what a voice session
    /// delivers, and it is the smallest of the three for speech.
    static let extensions = ["m4a", "caf", "wav"]

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func url(forAsset name: String, category: HopAudioCategory) -> URL? {
        for ext in Self.extensions {
            // Subdirectory first, then a flat lookup, because Xcode flattens
            // folder references that were added as groups rather than folders —
            // a packaging detail that should not silently mute the app.
            if let url = bundle.url(
                forResource: name, withExtension: ext, subdirectory: category.bundleSubdirectory
            ) {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    func availableVoiceAssets() -> Set<HopVoiceAssetKey> {
        // Only lines the catalog claims are recorded are worth probing; a
        // `.planned` line has no file by definition.
        var available: Set<HopVoiceAssetKey> = []
        for line in HopVoiceCatalog.allLines where line.asset.state == .recorded {
            if url(forAsset: line.asset.key.rawValue, category: .hopVoice) != nil {
                available.insert(line.asset.key)
            } else {
                // The catalog says a recording exists and the bundle disagrees.
                // That is a packaging mistake and it must be loud, because the
                // symptom — a silent line with a caption — looks exactly like
                // the normal not-yet-recorded state.
                HopLog.persistence.fault(
                    "voice asset declared recorded but missing key=\(line.asset.key.rawValue, privacy: .public)"
                )
            }
        }
        return available
    }
}

/// Reports every asset as present, with no file behind it. Used by tests that
/// exercise the "audio is available" branches without shipping audio.
struct StubAudioAssetResolver: AudioAssetResolving {
    var availableKeys: Set<HopVoiceAssetKey> = []
    var resolvesEffects = false

    func url(forAsset name: String, category: HopAudioCategory) -> URL? { nil }
    func availableVoiceAssets() -> Set<HopVoiceAssetKey> { availableKeys }
}
