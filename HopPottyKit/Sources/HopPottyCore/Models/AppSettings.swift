import Foundation

/// Device-wide preferences that are not specific to one child.
public struct AppSettings: Hashable, Codable, Sendable {
    // Sound and feedback. Each is independent; none is required for any feature
    // to work, and text alternatives exist for every spoken line.
    public var hopVoiceEnabled: Bool
    public var soundEffectsEnabled: Bool
    public var ambientAudioEnabled: Bool
    public var hapticsEnabled: Bool
    /// Shows the written form of every line Hop speaks. On by default: it helps
    /// pre-readers' caregivers, deaf and hard-of-hearing families, and anyone
    /// using the app with sound off.
    public var spokenTextCaptionsEnabled: Bool

    // Notifications
    public var warningNotificationsEnabled: Bool
    public var dailySummaryEnabled: Bool
    public var dailySummaryTime: LocalTimeOfDay

    // Child experience
    public var miniGamesEnabled: Bool
    public var quizzesEnabled: Bool
    /// Shows a calm visual timer during the "give it a try" step. Off by default —
    /// some children find a visible countdown stressful rather than reassuring.
    public var routineSitTimerEnabled: Bool
    public var routineSitTimerDuration: TimeInterval

    // Parent gate
    public var parentGateStyle: ParentGateStyle

    public var activeChildID: UUID?
    public var hasCompletedOnboarding: Bool
    /// Bumped when a release needs to show a "what changed" note or run a migration.
    public var lastSeenReleaseVersion: String?

    public init(
        hopVoiceEnabled: Bool = true,
        soundEffectsEnabled: Bool = true,
        ambientAudioEnabled: Bool = false,
        hapticsEnabled: Bool = true,
        spokenTextCaptionsEnabled: Bool = true,
        warningNotificationsEnabled: Bool = true,
        dailySummaryEnabled: Bool = false,
        dailySummaryTime: LocalTimeOfDay = LocalTimeOfDay(hour: 20, minute: 0),
        miniGamesEnabled: Bool = true,
        quizzesEnabled: Bool = true,
        routineSitTimerEnabled: Bool = false,
        routineSitTimerDuration: TimeInterval = 90,
        parentGateStyle: ParentGateStyle = .holdAndArithmetic,
        activeChildID: UUID? = nil,
        hasCompletedOnboarding: Bool = false,
        lastSeenReleaseVersion: String? = nil
    ) {
        self.hopVoiceEnabled = hopVoiceEnabled
        self.soundEffectsEnabled = soundEffectsEnabled
        self.ambientAudioEnabled = ambientAudioEnabled
        self.hapticsEnabled = hapticsEnabled
        self.spokenTextCaptionsEnabled = spokenTextCaptionsEnabled
        self.warningNotificationsEnabled = warningNotificationsEnabled
        self.dailySummaryEnabled = dailySummaryEnabled
        self.dailySummaryTime = dailySummaryTime
        self.miniGamesEnabled = miniGamesEnabled
        self.quizzesEnabled = quizzesEnabled
        self.routineSitTimerEnabled = routineSitTimerEnabled
        self.routineSitTimerDuration = routineSitTimerDuration
        self.parentGateStyle = parentGateStyle
        self.activeChildID = activeChildID
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.lastSeenReleaseVersion = lastSeenReleaseVersion
    }
}

/// How the parent gate challenges the person tapping.
public enum ParentGateStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Press and hold, then answer a two-digit sum. The default: it defeats a
    /// preschooler without demanding a device passcode from a caregiver whose
    /// hands are full.
    case holdAndArithmetic
    /// Device owner authentication (Face ID / Touch ID / passcode).
    case deviceOwner

    public var id: String { rawValue }
}
