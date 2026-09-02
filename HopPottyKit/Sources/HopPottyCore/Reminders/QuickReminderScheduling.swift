import Foundation

// MARK: - What the sheet asks for

/// A caregiver's request for a Quick Reminder, before anything has decided
/// whether it can be granted.
///
/// Two shapes, because the sheet offers two ways in and they are not the same
/// question. A chip means "this long from now", which is a duration and stays
/// correct however long the sheet sat open. "Pick a time" means "at 3:40", which
/// is an instant and does not move. Collapsing them into one would force the
/// caller to convert, and converting a duration to an instant too early is
/// exactly how a reminder ends up firing at the moment the sheet was opened
/// rather than the moment Set was tapped.
public struct QuickReminderRequest: Hashable, Sendable {

    public enum Timing: Hashable, Sendable {
        /// One of the chips: a delay measured from the instant Set is tapped.
        case after(QuickReminderDuration)
        /// The time picker: an absolute instant the caregiver chose.
        case at(Date)
    }

    public let timing: Timing
    public let childID: UUID?
    public let label: QuickReminderLabel?

    public init(timing: Timing, childID: UUID? = nil, label: QuickReminderLabel? = nil) {
        self.timing = timing
        self.childID = childID
        self.label = label
    }

    public static func after(
        _ duration: QuickReminderDuration,
        childID: UUID? = nil,
        label: QuickReminderLabel? = nil
    ) -> QuickReminderRequest {
        QuickReminderRequest(timing: .after(duration), childID: childID, label: label)
    }

    public static func at(
        _ date: Date,
        childID: UUID? = nil,
        label: QuickReminderLabel? = nil
    ) -> QuickReminderRequest {
        QuickReminderRequest(timing: .at(date), childID: childID, label: label)
    }

    /// The instant this request resolves to, given when it was made.
    public func fireDate(setAt now: Date) -> Date {
        switch timing {
        case .after(let duration): QuickReminderPlanner.fireDate(setAt: now, duration: duration)
        case .at(let date): date
        }
    }
}

// MARK: - Why a request can be refused

/// The four ways a Quick Reminder is not set.
///
/// Each names a limit, never the caregiver. There is no `.invalid`: a request
/// that cannot be granted always has a reason a person can act on, and a
/// refusal a screen cannot explain is a refusal that reads as a bug.
public enum QuickReminderRejection: Hashable, Sendable {
    /// The chosen instant has already happened. Almost always a typo in the
    /// time picker, or a sheet left open across the time it was set for.
    case inThePast
    /// Closer than ``QuickReminderPlanner/minimumLead``. A "reminder" arriving
    /// in nine seconds is not a reminder, and the picker's granularity is
    /// minutes, so this is only reachable from the time picker.
    case tooSoon
    /// Further out than ``QuickReminderPlanner/maximumHorizon``.
    case beyondHorizon
    /// ``QuickReminderPlanner/maximumPending`` reminders are already waiting and
    /// none of them belongs to this child, so this one would be a queue rather
    /// than a timer.
    case tooManyPending
}

// MARK: - What granting one does

/// A Quick Reminder that may be set, and what setting it costs.
///
/// `replaces` is the whole reason this is a struct rather than a bare
/// `QuickReminder`. Setting a second reminder for the same child replaces the
/// first — that is the rule, and it is the commonest thing a caregiver does —
/// but the *caller* has to cancel the notification behind the old one. Handing
/// back only the new reminder would leave a scheduled notification with nothing
/// pointing at it, which is the one failure this feature can produce that a
/// caregiver cannot undo from inside the app.
public struct QuickReminderPlan: Hashable, Sendable {
    /// The reminder to schedule and save. Always `.pending`.
    public let reminder: QuickReminder
    /// The pending reminder this one takes the place of, if any. Cancel its
    /// notification and save its `cancelledCopy()`.
    public let replaces: QuickReminder?
    /// A projected Potty Pause landing near the new reminder. Advisory: nothing
    /// in HopPotty refuses a reminder because of one, and nothing moves the
    /// pause.
    public let collision: QuickReminderCollision?

    public init(
        reminder: QuickReminder,
        replaces: QuickReminder? = nil,
        collision: QuickReminderCollision? = nil
    ) {
        self.reminder = reminder
        self.replaces = replaces
        self.collision = collision
    }

    public var replacesAnother: Bool { replaces != nil }
}

// MARK: - The answer

/// What the planner says about a request.
///
/// An enum rather than `Result`, because a refusal here is not an error.
/// Nothing went wrong when a caregiver picked a time that has already passed,
/// nothing is logged, nothing is retried, and no code path treats it as a
/// failure — the sheet says which limit was hit and the caregiver turns the
/// wheel. `Result` would put every one of these on an error track it does not
/// belong on, and `try` at every call site would imply a recovery that is
/// really just "pick again".
public enum QuickReminderOutcome: Hashable, Sendable {
    case planned(QuickReminderPlan)
    case refused(QuickReminderRejection)

    public var plan: QuickReminderPlan? {
        guard case .planned(let plan) = self else { return nil }
        return plan
    }

    public var rejection: QuickReminderRejection? {
        guard case .refused(let rejection) = self else { return nil }
        return rejection
    }

    public var isPlanned: Bool { plan != nil }
}

// MARK: - Planning

public extension QuickReminderPlanner {

    /// The closest a Quick Reminder may be set.
    ///
    /// One minute. Below that the notification and the tap that asked for it
    /// arrive together, which reads as a bug rather than a reminder, and the
    /// time picker cannot express anything finer than a minute anyway.
    static var minimumLead: TimeInterval { 60 }

    /// The furthest ahead a Quick Reminder may be set.
    ///
    /// Twenty-four hours. Past a day this is not "remind us after her drink",
    /// it is a calendar — and a calendar is a thing the caregiver's phone
    /// already has, with snoozing, editing and sync that HopPotty is never
    /// going to build. The ceiling is also what keeps `staleAfter` meaningful:
    /// nothing pending can outlive the window in which a finished reminder is
    /// pruned.
    static var maximumHorizon: TimeInterval { TimeInterval(24 * 60 * 60) }

    /// Whether an instant is one a Quick Reminder may be set for.
    ///
    /// Split out from ``plan(_:existing:projection:at:)`` so the sheet can grey
    /// out its primary button while the caregiver is still turning the picker's
    /// wheel, using exactly the rule that will be applied when they tap.
    static func validate(fireAt: Date, now: Date) -> QuickReminderRejection? {
        let lead = fireAt.timeIntervalSince(now)
        if lead <= 0 { return .inThePast }
        if lead < minimumLead { return .tooSoon }
        if lead > maximumHorizon { return .beyondHorizon }
        return nil
    }

    /// Whether a request is one that may be granted, without building the plan.
    static func validate(_ request: QuickReminderRequest, at now: Date) -> QuickReminderRejection? {
        validate(fireAt: request.fireDate(setAt: now), now: now)
    }

    /// Turns a request into a reminder, or says why not.
    ///
    /// The order is deliberate. Timing is checked first, because a caregiver who
    /// picked yesterday needs to hear about *that* and not about a ceiling on
    /// pending reminders they were never going to hit. Admission runs second,
    /// and replacement beats the ceiling — re-setting the timer for the same
    /// child must not be refused by a limit the replacement does not raise.
    ///
    /// `projection` is the scheduling engine's next projected pause, if the
    /// caller has one. It only ever adds an advisory note.
    static func plan(
        _ request: QuickReminderRequest,
        existing: [QuickReminder] = [],
        projection: PauseProjection? = nil,
        at now: Date
    ) -> QuickReminderOutcome {
        let fireAt = request.fireDate(setAt: now)
        if let rejection = validate(fireAt: fireAt, now: now) {
            return .refused(rejection)
        }

        let replaced: QuickReminder?
        switch admit(childID: request.childID, existing: existing, at: now) {
        case .allowed:
            replaced = nil
        case .replaces(let existingForChild):
            replaced = existingForChild
        case .refusedTooManyPending:
            return .refused(.tooManyPending)
        }

        let reminder = QuickReminder(
            childID: request.childID,
            fireAt: fireAt,
            createdAt: now,
            label: request.label,
            state: .pending
        )

        return .planned(
            QuickReminderPlan(
                reminder: reminder,
                replaces: replaced,
                collision: collision(reminderAt: fireAt, projection: projection)
            )
        )
    }

    /// The reminders a caller should write after acting on a plan: the new one,
    /// and the cancelled copy of whatever it replaced.
    ///
    /// Returned as a list so the save path is one loop rather than two
    /// branches, and so "the replaced reminder was forgotten" is not a state
    /// the caller can reach by writing the happy path first.
    static func writes(for plan: QuickReminderPlan) -> [QuickReminder] {
        guard let replaced = plan.replaces else { return [plan.reminder] }
        return [replaced.cancelledCopy(), plan.reminder]
    }
}

// MARK: - Words

/// The strings a Quick Reminder puts on screen.
///
/// Core assembles these rather than the view layer, for the same reason
/// `ScheduleSummary` exists: the sentence is product logic — which entry, with
/// which slots, in which order — and only the *rendering* of a locale-shaped
/// value like "3:40 PM" belongs to the caller.
///
/// Every function takes the already-formatted clock or duration text. Core owns
/// no `DateFormatter`: a wall-clock time has a shape the target language owns,
/// and a format string cannot express it (see `HopCopyPlaceholderKind`).
///
/// `resolve` is the localisation seam. It defaults to the English authored in
/// `HopCopy`, which is what makes these functions testable on any toolchain; the
/// app passes a closure that goes through `NSLocalizedString` first, so a
/// translated build renders the translation with no second copy of the logic.
public enum QuickReminderText {

    /// How a copy entry becomes a string. See the note above.
    public typealias Resolver = @Sendable (HopCopyEntry, [Int: HopCopyArgument]) -> String

    /// The catalog's own English. The default everywhere here.
    public static let catalogEnglish: Resolver = { entry, values in entry.filled(values) }

    /// "Reminder · 3:40 PM"
    public static func chip(clockText: String, resolve: Resolver = catalogEnglish) -> String {
        resolve(HopCopy.quickReminder.chip, [1: .text(clockText)])
    }

    /// "Reminder set for 3:40 PM"
    public static func confirmation(clockText: String, resolve: Resolver = catalogEnglish) -> String {
        resolve(HopCopy.quickReminder.confirmation, [1: .text(clockText)])
    }

    /// "Cancel the reminder set for 3:40 PM" — the chip's VoiceOver label.
    public static func cancelLabel(clockText: String, resolve: Resolver = catalogEnglish) -> String {
        resolve(HopCopy.quickReminder.chipCancelLabel, [1: .text(clockText)])
    }

    /// "12 minutes from now" — the chip's VoiceOver value.
    public static func remaining(durationText: String, resolve: Resolver = catalogEnglish) -> String {
        resolve(HopCopy.quickReminder.remaining, [1: .text(durationText)])
    }

    /// "This takes the place of your reminder at 2:15 PM."
    public static func replacesExisting(clockText: String, resolve: Resolver = catalogEnglish) -> String {
        resolve(HopCopy.quickReminder.replacesExisting, [1: .text(clockText)])
    }

    /// "A Potty Pause is already coming at 3:35 PM."
    public static func pauseNearby(clockText: String, resolve: Resolver = catalogEnglish) -> String {
        resolve(HopCopy.quickReminder.pauseNearby, [1: .text(clockText)])
    }

    /// The chip for one duration. A preset has its own authored sentence; any
    /// other value falls back to the format, so a restored custom duration
    /// still draws a chip rather than a blank.
    public static func presetLabel(
        _ duration: QuickReminderDuration,
        durationText: String = "",
        resolve: Resolver = catalogEnglish
    ) -> String {
        if let entry = presetEntry(duration) { return resolve(entry, [:]) }
        return resolve(HopCopy.quickReminder.presetCustom, [1: .text(durationText)])
    }

    /// The authored chip for a preset, or `nil` for a custom duration.
    public static func presetEntry(_ duration: QuickReminderDuration) -> HopCopyEntry? {
        switch duration {
        case .minutes10: HopCopy.quickReminder.presetMinutes10
        case .minutes15: HopCopy.quickReminder.presetMinutes15
        case .minutes20: HopCopy.quickReminder.presetMinutes20
        case .minutes30: HopCopy.quickReminder.presetMinutes30
        case .minutes45: HopCopy.quickReminder.presetMinutes45
        case .minutes60: HopCopy.quickReminder.presetMinutes60
        case .custom: nil
        }
    }

    /// The sentence for a refusal. Exhaustive by construction: a new rejection
    /// case is a compile error here, which is the point — a refusal with no
    /// wording would surface as a silently disabled button.
    public static func rejection(_ rejection: QuickReminderRejection, resolve: Resolver = catalogEnglish) -> String {
        resolve(entry(for: rejection), [:])
    }

    public static func entry(for rejection: QuickReminderRejection) -> HopCopyEntry {
        switch rejection {
        case .inThePast: HopCopy.quickReminder.rejectedInThePast
        case .tooSoon: HopCopy.quickReminder.rejectedTooSoon
        case .beyondHorizon: HopCopy.quickReminder.rejectedBeyondHorizon
        case .tooManyPending: HopCopy.quickReminder.rejectedTooManyPending
        }
    }
}
