import Foundation

// MARK: - What a widget is allowed to know
//
// A home-screen or lock-screen widget is drawn by a *different process* from
// the app, out of a file in the App Group container, and it is visible to
// anybody who glances at the phone — including on a locked screen, in a
// classroom, on a table in a café.
//
// Two consequences, and they are the whole design of this file:
//
// 1. **The App Group boundary.** `Docs/PrivacyArchitecture.md` §5: nothing about
//    a child crosses it. `WidgetSnapshot` is a new payload on that boundary, so
//    it carries the least it can — five facts and a timestamp — and the one
//    field that *could* identify a child is opt-in at the call site rather than
//    filled in by default. See `WidgetSnapshotBuilder`.
//
// 2. **Never a record of what happened.** A widget that said "3 successes
//    today" would be a health record about a three-year-old, rendered at
//    readable size, on a locked phone, to whoever is holding it. So the snapshot
//    describes only *what is about to happen*: the next appointment, and whether
//    the schedule is on.
//
// Deliberately absent, and not to be added:
//
//   * potty events, outcomes, accidents, streaks, or any count of any of them
//   * stars, pond items, quiz or game progress
//   * the child's UUID, age, pronouns, avatar or notes
//   * the names, icons, bundle identifiers or *number* of shielded apps
//   * anything derived from a `FamilyActivitySelection`
//   * free text of any kind other than the optional display name
//
// The last one is structural: there is exactly one `String` field on this type,
// and it exists so a caregiver can choose to see a name. Everything else is a
// date, a flag, or an enum raw value.

/// Everything the HopPotty widget draws, resolved by the app and read by the
/// widget extension.
///
/// Small, `Codable`, versioned, and free of anything a stranger reading a locked
/// screen should not see. The widget computes nothing from it beyond formatting:
/// a widget process gets a fraction of a second and no chance to ask a question,
/// so every judgement — is the schedule on, which mood is Hop in, which of two
/// upcoming instants is the one to show — is made in the app and stored here.
public struct WidgetSnapshot: Codable, Equatable, Sendable {

    /// Bumped whenever the meaning of a field changes.
    ///
    /// A reader that finds a version it does not recognise treats the file as
    /// absent rather than guessing, exactly like `SharedPauseRecord`. An app and
    /// its widget are updated together, so the only way to see a mismatch is a
    /// widget that has not been re-rendered since an update — and a placeholder
    /// is a better answer there than a stale one drawn with new rules.
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int

    /// When the next Potty Pause is projected to begin, or `nil` when there is
    /// no next pause — the schedule is off, suspended indefinitely, or there is
    /// no schedule at all.
    ///
    /// Absolute, because the widget renders it with `Text(_:style:)` and the
    /// system keeps that live without waking anybody.
    public let nextPauseAt: Date?

    /// The name to greet, or `nil` for the neutral phrasing.
    ///
    /// **Opt-in, and `nil` unless a caregiver asked for it.** A widget is
    /// readable from a locked screen by anyone holding the phone, and a child's
    /// name on a lock screen is a different disclosure from the same name inside
    /// an app behind a parent gate. `WidgetSnapshotBuilder` will not populate
    /// this field unless the caller says so explicitly.
    ///
    /// Sanitised and length-limited by `ChildProfile.sanitize` before it ever
    /// reaches here.
    public let childDisplayName: String?

    /// Which way Hop is drawn, as `HopWidgetMood.rawValue`.
    ///
    /// A string rather than the enum so that a widget built before a mood was
    /// added still decodes the file instead of failing the whole snapshot over a
    /// pose it does not know. Read it through ``mood``, which falls back.
    public let hopPoseName: String

    /// When the caregiver's one-off Quick Reminder arrives, if one is pending.
    ///
    /// Carried separately from ``nextPauseAt`` rather than merged into it,
    /// because they are different promises: a pause may hold a child's apps, a
    /// Quick Reminder never does, and a widget that blurred the two would be
    /// telling a caregiver the wrong thing about what is going to happen to the
    /// device in their child's hands.
    public let quickReminderAt: Date?

    /// Whether Potty Pause is switched on for the child the widget is about.
    ///
    /// Distinct from `nextPauseAt == nil`: a schedule can be enabled and still
    /// have no projection — a caregiver has skipped the next one, or the active
    /// window closes before another pause fits. The widget says something
    /// different in each case.
    public let isScheduleEnabled: Bool

    /// When a pause or guided routine currently in progress is expected to end,
    /// or `nil` when nothing is running.
    ///
    /// Written by whichever process started the pause — which is often the
    /// DeviceActivity monitor extension with the app not running at all — so the
    /// widget can show "Potty Pause now" rather than counting down to an
    /// appointment that has already arrived. It is an *expectation*, not a
    /// promise: every end-path in `Docs/ScreenTimeArchitecture.md` §9 can end a
    /// pause earlier than this.
    public let pauseEndsAt: Date?

    /// When the app resolved this. Lets a widget notice that it is looking at
    /// something written days ago and fall back to a neutral face.
    public let generatedAt: Date

    public init(
        schemaVersion: Int = WidgetSnapshot.currentSchemaVersion,
        nextPauseAt: Date? = nil,
        childDisplayName: String? = nil,
        hopPoseName: String = HopWidgetMood.idle.rawValue,
        quickReminderAt: Date? = nil,
        isScheduleEnabled: Bool = false,
        pauseEndsAt: Date? = nil,
        generatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.nextPauseAt = nextPauseAt
        self.childDisplayName = childDisplayName
        self.hopPoseName = hopPoseName
        self.quickReminderAt = quickReminderAt
        self.isScheduleEnabled = isScheduleEnabled
        self.pauseEndsAt = pauseEndsAt
        self.generatedAt = generatedAt
    }

    // MARK: - Derived

    /// The mood to draw, falling back to `.idle` for anything unrecognised.
    public var mood: HopWidgetMood {
        HopWidgetMood(rawValue: hopPoseName) ?? .idle
    }

    /// Whether a pause or routine is running as far as this snapshot knows.
    public func isPauseRunning(at instant: Date) -> Bool {
        guard let pauseEndsAt else { return false }
        return instant < pauseEndsAt
    }

    /// The soonest thing the widget has to say something about, pause or
    /// reminder, ignoring anything already in the past.
    ///
    /// This is what the timeline planner refreshes around, and what a small
    /// widget counts down to. Nil means "nothing scheduled" — draw the resting
    /// state, and let WidgetKit come back on the lazy cadence.
    public func nextEvent(after instant: Date) -> Date? {
        [nextPauseAt, quickReminderAt]
            .compactMap { $0 }
            .filter { $0 > instant }
            .min()
    }

    /// How old this snapshot is, in seconds. Never negative: a file written by a
    /// process whose clock ran slightly ahead is treated as brand new rather
    /// than as arriving from the future.
    public func age(at instant: Date) -> TimeInterval {
        max(0, instant.timeIntervalSince(generatedAt))
    }

    /// Past this age a snapshot describes a world nobody has confirmed in a
    /// while.
    ///
    /// Twelve hours: long enough to cover a night with the app unopened and the
    /// schedule genuinely unchanged, short enough that "next pause 09:15" left
    /// over from last Tuesday never gets drawn as though it were true. WidgetKit
    /// budgets refreshes and a family that has not opened HopPotty in half a day
    /// is better served by "open HopPotty" than by a confident wrong time.
    public static let stalenessHorizon: TimeInterval = 12 * 60 * 60

    public func isStale(at instant: Date) -> Bool {
        age(at: instant) > Self.stalenessHorizon
    }

    /// What a widget shows before any snapshot exists: first install, App Group
    /// unavailable, or a container cleared by "Delete everything".
    public static func placeholder(at instant: Date) -> WidgetSnapshot {
        WidgetSnapshot(
            nextPauseAt: instant.addingTimeInterval(45 * 60),
            childDisplayName: nil,
            hopPoseName: HopWidgetMood.idle.rawValue,
            quickReminderAt: nil,
            isScheduleEnabled: true,
            pauseEndsAt: nil,
            generatedAt: instant
        )
    }

    /// The honest empty state: nothing scheduled, nobody named, Hop asleep.
    public static func empty(at instant: Date) -> WidgetSnapshot {
        WidgetSnapshot(
            hopPoseName: HopWidgetMood.sleep.rawValue,
            isScheduleEnabled: false,
            generatedAt: instant
        )
    }
}

// MARK: - Mood

/// How Hop is drawn on a widget.
///
/// A deliberately tiny vocabulary, and a separate type from the app's `HopPose`
/// even though every case here shares that type's raw value. Two reasons:
///
/// - `HopPose` lives in the app's design system, which is a SwiftUI module that
///   `HopPottyCore` cannot see and a widget process should not pay for.
/// - A widget can only draw a face at 40 points. Half of `HopPose` — walking
///   with a backpack, catching a fly with his tongue — is invisible at that
///   size, so offering it here would be offering a choice the renderer cannot
///   honour.
///
/// The raw values match `HopPose` exactly so the app can map one to the other
/// with `HopPose(rawValue:)` where a full-size Hop is available.
public enum HopWidgetMood: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Nothing due for a while. The resting face.
    case idle
    /// A pause or reminder is approaching. Hop looks up.
    case wave
    /// It is nearly time — inside the last couple of minutes.
    case jump
    /// A pause or routine is running right now.
    case cheer
    /// The schedule is off, or the day is over.
    case sleep

    public var id: String { rawValue }

    /// Spoken by VoiceOver in place of the drawing. Kept here rather than in the
    /// widget so the copy is testable on Linux with everything else.
    ///
    /// Phrased about Hop rather than about the child: a widget label is read
    /// aloud wherever the phone is, and "Ellie's potty break is in 5 minutes" is
    /// not a sentence a family chose to broadcast.
    public var accessibilityDescription: String {
        switch self {
        case .idle: "Hop the frog, waiting"
        case .wave: "Hop the frog, waving hello"
        case .jump: "Hop the frog, jumping"
        case .cheer: "Hop the frog, cheering"
        case .sleep: "Hop the frog, asleep"
        }
    }
}
