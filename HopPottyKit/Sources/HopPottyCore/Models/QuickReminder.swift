import Foundation

// MARK: - What a Quick Reminder is
//
// A Quick Reminder is a caregiver's one-off timer: "remind me in 20 minutes."
// It is deliberately *not* part of the Potty Pause schedule.
//
// - It fires **once** and then it is over. There is no repeat, no snooze, no
//   escalation and no second nudge if nobody acted on the first one. A device
//   that reminds you again because you ignored it is an engagement mechanic
//   (`Docs/CONTRACTS.md` §4.7), and this feature is one timer, once.
// - It **never shields an app**. Nothing here touches ManagedSettings, which is
//   why it works in `.gentle` mode with no Screen Time permission at all —
//   after a big drink, before leaving the house, or for a sibling on a rhythm
//   of their own.
// - It **leaves the schedule alone**. Setting, firing or cancelling one never
//   reads or writes `PottySchedule`. The only relationship between the two is
//   advisory: the planner can tell the UI that a pause is already coming at
//   about the same time, so a caregiver is not surprised by two interruptions
//   in a row.

/// A one-off potty reminder a caregiver set by hand.
public struct QuickReminder: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    /// The child this is about, or `nil` for "anyone".
    ///
    /// Optional because the real use is often not child-specific: a caregiver
    /// with two children in the bath sets one timer for the bathroom, not one
    /// per child. Forcing a child on it would make the caregiver pick a name
    /// they do not mean, and would then scope the reminder to a profile that is
    /// not the point.
    public let childID: UUID?
    /// The instant the reminder should arrive. Absolute, not a wall-clock time:
    /// the horizon is under four hours, so there is no DST edge to get wrong.
    public var fireAt: Date
    /// When the caregiver set it. Together with `fireAt` this is the requested
    /// duration, which is why neither is derived from the other.
    public let createdAt: Date
    /// Why it was set, when the caregiver said. Purely descriptive: it changes
    /// the row's wording and nothing about the behaviour.
    public var label: QuickReminderLabel?
    public var state: QuickReminderState

    public init(
        id: UUID = UUID(),
        childID: UUID? = nil,
        fireAt: Date,
        createdAt: Date = Date(),
        label: QuickReminderLabel? = nil,
        state: QuickReminderState = .pending
    ) {
        self.id = id
        self.childID = childID
        self.fireAt = fireAt
        self.createdAt = createdAt
        self.label = label
        self.state = state
    }

    /// The way the UI makes one: a duration chosen from the chips, and the
    /// instant the caregiver tapped Set.
    public init(
        id: UUID = UUID(),
        childID: UUID? = nil,
        duration: QuickReminderDuration,
        setAt: Date,
        label: QuickReminderLabel? = nil
    ) {
        self.init(
            id: id,
            childID: childID,
            fireAt: setAt.addingTimeInterval(duration.duration),
            createdAt: setAt,
            label: label,
            state: .pending
        )
    }

    public var isPending: Bool { state == .pending }

    /// How long the caregiver asked for, recovered from the two stored instants.
    public var requestedDuration: TimeInterval {
        max(0, fireAt.timeIntervalSince(createdAt))
    }

    /// The state after the notification has been delivered.
    ///
    /// Terminal states are terminal: firing a cancelled reminder would resurrect
    /// something the caregiver explicitly took back, so it returns itself
    /// unchanged rather than moving.
    public func firedCopy() -> QuickReminder {
        guard state == .pending else { return self }
        var copy = self
        copy.state = .fired
        return copy
    }

    /// The state after the caregiver tapped the chip's cancel affordance.
    public func cancelledCopy() -> QuickReminder {
        guard state == .pending else { return self }
        var copy = self
        copy.state = .cancelled
        return copy
    }
}

// MARK: - Label

/// Why a caregiver set a Quick Reminder.
///
/// A fixed set rather than free text. Free text would be one more thing to
/// sanitise, store, export and translate, and every real reason a parent gives
/// falls into one of these three plus "no reason, just remind me".
public enum QuickReminderLabel: String, Codable, CaseIterable, Sendable, Identifiable {
    case afterADrink
    case beforeLeaving
    case beforeNap
    /// Set without saying why. Not "other" — a caregiver does not owe the app a
    /// reason for a timer.
    case custom

    public var id: String { rawValue }
}

// MARK: - State

/// Where a Quick Reminder is in its very short life.
public enum QuickReminderState: String, Codable, CaseIterable, Sendable {
    /// Set and waiting. The only state with a scheduled notification behind it.
    case pending
    /// Its instant has passed. The notification did the delivering; this is the
    /// record that it happened.
    case fired
    /// The caregiver took it back before it arrived.
    case cancelled

    /// Whether the reminder can still change on its own.
    public var isTerminal: Bool { self != .pending }
}

// MARK: - Duration

/// How far ahead a Quick Reminder is set.
///
/// Separate from `PottyInterval` on purpose. They look alike and mean different
/// things: an interval is a *cadence* the schedule repeats on, and this is a
/// single delay. Sharing the type would make "change the reminder presets" a
/// change to everybody's schedule presets. The custom bounds *are* shared,
/// because those are a product judgement about what a useful potty timer is,
/// and it does not become a different judgement here.
public enum QuickReminderDuration: Hashable, Codable, Sendable {
    case minutes10, minutes15, minutes20, minutes30, minutes45, minutes60
    case custom(minutes: Int)

    /// The chips, in the order they are drawn.
    public static let presets: [QuickReminderDuration] = [
        .minutes10, .minutes15, .minutes20, .minutes30, .minutes45, .minutes60,
    ]

    /// The same guard rails as a schedule interval: see `PottyInterval.customRange`.
    public static var customRange: ClosedRange<Int> { PottyInterval.customRange }

    /// Always inside `customRange`. A custom value from outside it — a corrupt
    /// row, a build from the future — is clamped rather than honoured, so no
    /// path can produce a reminder that fires in one second or in a week.
    public var minutes: Int {
        switch self {
        case .minutes10: 10
        case .minutes15: 15
        case .minutes20: 20
        case .minutes30: 30
        case .minutes45: 45
        case .minutes60: 60
        case .custom(let m):
            min(max(m, Self.customRange.lowerBound), Self.customRange.upperBound)
        }
    }

    public var duration: TimeInterval { TimeInterval(minutes) * 60 }

    /// Round-trips a stored integer back to a preset where one matches, so a
    /// new preset is never a schema change — the same trick `PottyInterval`
    /// uses, for the same reason.
    public init(minutes: Int) {
        self = switch minutes {
        case 10: .minutes10
        case 15: .minutes15
        case 20: .minutes20
        case 30: .minutes30
        case 45: .minutes45
        case 60: .minutes60
        default: .custom(minutes: minutes)
        }
    }

    public var isPreset: Bool { Self.presets.contains(self) }
}

// MARK: - Collision

/// A scheduled Potty Pause landing close to a Quick Reminder.
///
/// Advisory only. It exists so the sheet can say "a Potty Pause is already
/// coming at 2:35 — set it anyway?" and let the caregiver decide. Nothing in
/// HopPotty refuses a reminder because of one, and nothing moves the pause.
public struct QuickReminderCollision: Hashable, Sendable {
    /// When the reminder would arrive.
    public let reminderAt: Date
    /// When the pause is projected to start.
    public let pauseAt: Date
    /// Whether the pause lands at or after the reminder. Lets the copy layer
    /// choose between "already coming at" and "just happened at" without
    /// re-deriving it from two dates.
    public let pauseIsAfterReminder: Bool

    public init(reminderAt: Date, pauseAt: Date) {
        self.reminderAt = reminderAt
        self.pauseAt = pauseAt
        self.pauseIsAfterReminder = pauseAt >= reminderAt
    }

    /// Unsigned gap between the two, in seconds.
    public var separation: TimeInterval {
        abs(pauseAt.timeIntervalSince(reminderAt))
    }
}

// MARK: - Admission

/// Whether a proposed Quick Reminder may be set, and what setting it does to
/// the ones already there.
public enum QuickReminderAdmission: Hashable, Sendable {
    /// Nothing in the way.
    case allowed
    /// There is already a pending reminder for this child (or, for a reminder
    /// with no child, another one with no child). The new one replaces it.
    case replaces(QuickReminder)
    /// The ceiling on pending reminders is reached and none of them belongs to
    /// this child, so setting another would be piling up timers.
    case refusedTooManyPending
}

// MARK: - Planner

/// The pure arithmetic behind Quick Reminders.
///
/// Reads no clock and no calendar: every answer is a function of an explicit
/// `now`, which is what lets the whole feature be tested on fixed dates.
///
/// ## The rules, in one place
///
/// 1. **Due** means pending *and* `fireAt <= now`. A fired or cancelled
///    reminder is never due again, at any instant.
/// 2. **Remaining** is `max(0, fireAt - now)` while pending and exactly zero
///    once terminal, so a chip counting down cannot show time left on a
///    reminder that has already arrived.
/// 3. **Reconciling** turns a pending reminder whose instant has passed into a
///    `.fired` one. The app being closed at that moment changes nothing: the
///    notification was delivered by the system, and this is the record catching
///    up.
/// 4. **Collision** is proximity, not conflict: a pause projected within
///    `collisionWindow` either side of the reminder. It never blocks anything.
/// 5. **Admission** allows one pending reminder per child and
///    `maximumPending` overall.
/// 6. **Staleness** is a fired-or-cancelled reminder older than `staleAfter`.
///    Pending ones are never stale, however long ago they were set.
public enum QuickReminderPlanner {

    /// How close a projected pause has to be before the sheet mentions it.
    ///
    /// Ten minutes: close enough that a caregiver would feel two interruptions
    /// as one clumsy run of them, wide enough to cover a pause projection that
    /// is only approximate — for a `.screenActivity` schedule the projected
    /// start is a floor that assumes continuous use, so being generous here
    /// costs a sentence and being stingy costs a surprise.
    public static let collisionWindow: TimeInterval = TimeInterval(10 * 60)

    /// The ceiling on pending reminders across the whole device.
    ///
    /// Three is a family with three children, or one caregiver having an
    /// unusually complicated afternoon. Past that it stops being "remind me in
    /// twenty minutes" and starts being a queue of alarms, and a queue of
    /// alarms is the thing this feature is not.
    public static let maximumPending = 3

    /// How long a finished reminder is kept before launch prunes it.
    ///
    /// Twenty-four hours. Long enough that a reminder set last night is still
    /// there this morning if anyone wonders what fired; short enough that the
    /// table never becomes a history nobody asked HopPotty to keep.
    public static let staleAfter: TimeInterval = TimeInterval(24 * 60 * 60)

    // MARK: Timing

    /// When a reminder set now, for this duration, should arrive.
    public static func fireDate(setAt: Date, duration: QuickReminderDuration) -> Date {
        setAt.addingTimeInterval(duration.duration)
    }

    /// Rule 1.
    public static func isDue(_ reminder: QuickReminder, at now: Date) -> Bool {
        reminder.state == .pending && reminder.fireAt <= now
    }

    /// Rule 2.
    public static func remaining(_ reminder: QuickReminder, at now: Date) -> TimeInterval {
        guard reminder.state == .pending else { return 0 }
        return max(0, reminder.fireAt.timeIntervalSince(now))
    }

    /// The fraction elapsed, `0...1`, for a progress ring. Zero when the
    /// caregiver asked for no time at all, which is the only division this
    /// file does and the only place it could have been by zero.
    public static func progress(_ reminder: QuickReminder, at now: Date) -> Double {
        let total = reminder.requestedDuration
        guard total > 0 else { return reminder.isPending ? 0 : 1 }
        let elapsed = total - remaining(reminder, at: now)
        return min(1, max(0, elapsed / total))
    }

    /// Rule 3.
    public static func reconciled(_ reminder: QuickReminder, at now: Date) -> QuickReminder {
        isDue(reminder, at: now) ? reminder.firedCopy() : reminder
    }

    /// Rule 3, over a whole list.
    public static func reconciled(_ reminders: [QuickReminder], at now: Date) -> [QuickReminder] {
        reminders.map { reconciled($0, at: now) }
    }

    // MARK: Collision

    /// Rule 4, against a concrete pause instant.
    public static func collision(
        reminderAt: Date,
        pauseAt: Date?,
        within window: TimeInterval = collisionWindow
    ) -> QuickReminderCollision? {
        guard let pauseAt else { return nil }
        let collision = QuickReminderCollision(reminderAt: reminderAt, pauseAt: pauseAt)
        // Inclusive at the boundary. The note is advisory, and mentioning a
        // pause exactly ten minutes out is a kinder failure than staying quiet
        // about it.
        guard collision.separation <= max(0, window) else { return nil }
        return collision
    }

    /// Rule 4, against what the scheduling engine projected.
    ///
    /// A projection the caregiver has already chosen to skip is not a
    /// collision: nothing is going to interrupt them, so saying so would be
    /// wrong in the one direction that matters.
    public static func collision(
        reminderAt: Date,
        projection: PauseProjection?,
        within window: TimeInterval = collisionWindow
    ) -> QuickReminderCollision? {
        guard let projection, !projection.willBeSkipped else { return nil }
        return collision(reminderAt: reminderAt, pauseAt: projection.start, within: window)
    }

    // MARK: Admission

    /// Rule 5.
    ///
    /// `existing` may contain reminders in any state; only pending ones count,
    /// because a fired reminder occupies nothing.
    public static func admit(
        childID: UUID?,
        existing: [QuickReminder],
        at now: Date
    ) -> QuickReminderAdmission {
        let pending = existing.filter { isPendingInFuture($0, at: now) }
        // Replacement comes first: re-setting a timer for the same child is
        // the commonest action there is, and it must not be refused by a
        // ceiling that the replacement would not raise.
        if let existingForChild = pending.first(where: { $0.childID == childID }) {
            return .replaces(existingForChild)
        }
        guard pending.count < maximumPending else { return .refusedTooManyPending }
        return .allowed
    }

    /// Pending reminders, newest arrival first — the order the chips draw in.
    public static func pending(_ reminders: [QuickReminder], at now: Date) -> [QuickReminder] {
        reminders
            .filter { isPendingInFuture($0, at: now) }
            .sorted { $0.fireAt < $1.fireAt }
    }

    /// A reminder that is pending *and* has not already come due. A pending row
    /// whose instant has passed is really a fired one that has not been
    /// reconciled yet, and it must not hold a slot open.
    private static func isPendingInFuture(_ reminder: QuickReminder, at now: Date) -> Bool {
        reminder.state == .pending && reminder.fireAt > now
    }

    // MARK: Pruning

    /// Rule 6.
    public static func isStale(_ reminder: QuickReminder, at now: Date) -> Bool {
        guard reminder.state.isTerminal else { return false }
        return now.timeIntervalSince(reminder.fireAt) > staleAfter
    }

    /// Splits a list into what launch keeps and what launch removes.
    public static func partitionForPruning(
        _ reminders: [QuickReminder],
        at now: Date
    ) -> (kept: [QuickReminder], pruned: [QuickReminder]) {
        var kept: [QuickReminder] = []
        var pruned: [QuickReminder] = []
        for reminder in reminders {
            if isStale(reminder, at: now) {
                pruned.append(reminder)
            } else {
                kept.append(reminder)
            }
        }
        return (kept, pruned)
    }
}
