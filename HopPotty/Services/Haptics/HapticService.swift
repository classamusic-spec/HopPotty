import CoreHaptics
import Foundation
import HopPottyCore
import UIKit

// MARK: - Events

/// Every haptic HopPotty is allowed to play.
///
/// Five, and no more. A closed list is how haptics stay *meaningful*: a buzz
/// that happens on every tap teaches a child nothing and becomes noise a parent
/// switches off wholesale, taking the two that mattered with it.
///
/// Each case names an occasion, not a waveform. The feature layer says "a star
/// was earned"; this file decides what that feels like, so the same moment feels
/// the same everywhere in the app.
enum HopHapticEvent: String, CaseIterable, Sendable {
    /// A setting was written. The quiet confirmation that a change stuck.
    case settingSaved
    /// The full potty routine finished. The warmest haptic in the app.
    case routineComplete
    /// A star landed. Two light taps — a heartbeat, not an alarm.
    case starEarned
    /// A switch that changes what the app *does* to the child's device —
    /// enabling Potty Pause, changing mode. Weightier than a normal toggle
    /// because it deserves a beat of attention.
    case importantToggle
    /// Moving between options in a picker.
    case selection
}

// MARK: - Protocol

@MainActor
protocol HapticProviding: AnyObject {
    func play(_ event: HopHapticEvent)
    /// Warms the generators before a screen that will use them, so the first
    /// tap is not the one that feels late.
    func prepare(for event: HopHapticEvent)
    func apply(_ settings: AppSettings)
}

// MARK: - Service

/// Centralised haptics.
///
/// ## Never continuous
///
/// Every pattern here is built from `CHHapticEvent.EventType.hapticTransient`.
/// `.hapticContinuous` is not used anywhere in HopPotty and should not be added:
/// a sustained vibration in the hands of a three-year-old is startling, it reads
/// as an error state in every other app they will ever use, and it is the shape
/// of feedback that makes a device feel like it is demanding something. Short,
/// discrete, done.
///
/// ## Three tiers of hardware, one API
///
/// 1. **Core Haptics** (iPhone 8 and later) gets the two-transient star pattern.
/// 2. **`UIFeedbackGenerator`** covers everything else and every device where
///    Core Haptics is unavailable but the Taptic Engine is not.
/// 3. **No haptics at all** (most iPads) plays nothing and never logs an error —
///    a large share of this app's use is on an iPad, so "no haptics" is a normal
///    configuration, not a degraded one.
///
/// The caller never learns which tier it got.
@MainActor
final class HapticService: HapticProviding {
    private var settings: AppSettings
    private var engine: CHHapticEngine?
    private var engineStartFailed = false

    // Generators are cheap to hold and expensive to create on the frame you
    // need them, which is the frame a child just tapped something.
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let selectionGenerator = UISelectionFeedbackGenerator()

    /// Whether this device can run Core Haptics patterns at all.
    private let supportsCoreHaptics: Bool

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        self.supportsCoreHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    func apply(_ settings: AppSettings) {
        self.settings = settings
        if !settings.hapticsEnabled { stopEngine() }
    }

    func prepare(for event: HopHapticEvent) {
        guard settings.hapticsEnabled else { return }
        switch event {
        case .settingSaved, .routineComplete: notificationGenerator.prepare()
        case .starEarned: lightImpactGenerator.prepare()
        case .importantToggle: mediumImpactGenerator.prepare()
        case .selection: selectionGenerator.prepare()
        }
    }

    func play(_ event: HopHapticEvent) {
        // The single gate. Every haptic in the app goes through this method, so
        // `AppSettings.hapticsEnabled` cannot be bypassed by a view that calls a
        // generator directly — and the review rule "no `UIFeedbackGenerator`
        // outside this file" is checkable with one grep.
        guard settings.hapticsEnabled else { return }

        switch event {
        case .starEarned:
            // The one custom pattern: two light transients, 90 ms apart. It
            // reads as "something arrived" rather than "something happened to
            // you", which is the difference between a reward and an alert.
            if playStarPattern() { return }
            lightImpactGenerator.impactOccurred(intensity: 0.7)

        case .routineComplete:
            notificationGenerator.notificationOccurred(.success)

        case .settingSaved:
            // `.success` rather than an impact: a setting that saved is
            // information, and the notification family is what iOS users
            // already read as "that worked".
            notificationGenerator.notificationOccurred(.success)

        case .importantToggle:
            mediumImpactGenerator.impactOccurred()

        case .selection:
            selectionGenerator.selectionChanged()
        }
    }

    // MARK: Core Haptics

    /// Plays the star pattern. Returns `false` when the caller should fall back.
    private func playStarPattern() -> Bool {
        guard supportsCoreHaptics, !engineStartFailed else { return false }
        guard let engine = startedEngine() else { return false }
        do {
            let pattern = try CHHapticPattern(events: Self.starEvents, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            // One failure is enough to stop trying: a device whose engine
            // refuses a two-event pattern will refuse the next one too, and the
            // `UIImpactFeedbackGenerator` fallback is perfectly good.
            engineStartFailed = true
            HopLog.persistence.debug(
                "core haptics pattern failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            return false
        }
    }

    /// Two transients. `hapticTransient` only — see the type documentation.
    private static var starEvents: [CHHapticEvent] {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
        return [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: 0.09
            ),
        ]
    }

    private func startedEngine() -> CHHapticEngine? {
        if let engine { return engine }
        do {
            let engine = try CHHapticEngine()
            // Shuts itself down when idle, so a paused app is not holding the
            // haptic hardware awake.
            engine.isAutoShutdownEnabled = true
            // The system stops the engine for its own reasons — a call, a
            // media services reset. Clearing the reference means the next star
            // rebuilds it instead of playing into a dead engine.
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.engine = nil }
            }
            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.engine = nil
                }
            }
            try engine.start()
            self.engine = engine
            return engine
        } catch {
            engineStartFailed = true
            HopLog.persistence.debug(
                "core haptics engine failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            return nil
        }
    }

    private func stopEngine() {
        engine?.stop(completionHandler: nil)
        engine = nil
    }
}

// MARK: - Mock

@MainActor
final class MockHapticService: HapticProviding {
    private(set) var played: [HopHapticEvent] = []
    private(set) var prepared: [HopHapticEvent] = []
    var settings = AppSettings()

    func play(_ event: HopHapticEvent) {
        guard settings.hapticsEnabled else { return }
        played.append(event)
    }

    func prepare(for event: HopHapticEvent) { prepared.append(event) }
    func apply(_ settings: AppSettings) { self.settings = settings }
}
