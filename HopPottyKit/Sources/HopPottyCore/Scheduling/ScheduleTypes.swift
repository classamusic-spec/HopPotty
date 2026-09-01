import Foundation

// The scheduling engine is deliberately split into values (this file) and the
// pure functions that produce them (`PottyScheduleService`). Nothing here reads
// a clock, a locale or a time zone on its own: every answer is a function of an
// explicit `now` and an explicit `Calendar`, because a scheduling bug that only
// reproduces at 1:30 AM on the first Sunday in November is a bug nobody can fix.

/// Everything the engine needs to reason about one child's schedule at one instant.
///
/// Passed as a value rather than held as service state so the same service can
/// answer questions about several children, and so a test can replay a whole day
/// by handing it a sequence of states.
public struct ScheduleState: Hashable, Sendable {
    public var schedule: PottySchedule
    /// The instant being reasoned about. The engine never calls `Date()`.
    public var now: Date
    /// When the most recent pause finished, if there has been one today.
    ///
    /// This is the *end* of the pause, not its start, because cooldown is measured
    /// from the moment the child got their screen back.
    public var lastPauseEnd: Date?
    /// Qualifying screen activity accumulated since `lastPauseEnd`, in seconds.
    ///
    /// Only `.screenActivity` schedules read this. `DeviceActivity` reports usage
    /// of the caregiver-selected apps; time in other apps, or with the device
    /// asleep, does not count and must not be included here.
    public var accumulatedActivity: TimeInterval

    public init(
        schedule: PottySchedule,
        now: Date,
        lastPauseEnd: Date? = nil,
        accumulatedActivity: TimeInterval = 0
    ) {
        self.schedule = schedule
        self.now = now
        self.lastPauseEnd = lastPauseEnd
        self.accumulatedActivity = max(0, accumulatedActivity)
    }
}

/// One concrete occurrence of a wall-clock window on a real calendar day.
///
/// A `QuietWindow` says "12:30 to 14:30". An occurrence says "12:30 to 14:30 on
/// Sunday 9 March 2025 in America/New_York", which is where daylight saving lives.
public struct ScheduleWindowOccurrence: Hashable, Sendable {
    public let start: Date
    /// Exclusive. A pause scheduled exactly at the end instant is allowed through.
    public let end: Date
    /// The weekday of the day the occurrence *began*.
    ///
    /// Day membership follows the start, so a bedtime window of 19:30–07:00
    /// restricted to Friday runs Friday evening into Saturday morning — which is
    /// what a caregiver ticking "Friday" means.
    public let weekday: Weekday

    public init(start: Date, end: Date, weekday: Weekday) {
        self.start = start
        self.end = end
        self.weekday = weekday
    }

    /// Real elapsed seconds, which is *not* the wall-clock length on a DST day.
    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public func contains(_ instant: Date) -> Bool { instant >= start && instant < end }
}

/// The quiet window in force at an instant, plus everything that overlaps it.
public struct ActiveQuietWindow: Hashable, Sendable {
    /// The window that governs, per the documented precedence rule.
    public let window: QuietWindow
    /// The governing window's own occurrence bounds.
    public let start: Date
    public let end: Date
    /// Every enabled window covering the instant, in precedence order. `window`
    /// is always the first element.
    public let overlapping: [QuietWindow]
    /// When quiet actually lifts, having followed the whole chain of overlapping
    /// and back-to-back windows. Nap 12:30–14:30 butted against lunch 12:00–12:30
    /// resumes at 14:30, not 12:30.
    public let resumesAt: Date

    public init(
        window: QuietWindow,
        start: Date,
        end: Date,
        overlapping: [QuietWindow],
        resumesAt: Date
    ) {
        self.window = window
        self.start = start
        self.end = end
        self.overlapping = overlapping
        self.resumesAt = resumesAt
    }
}

/// Why a pause may not start right now.
///
/// Exhaustive and ordered: `canStartPause` reports exactly one reason, the first
/// that applies in `precedence` order, so the parent UI can always say something
/// specific instead of going silent.
public enum PauseBlockReason: Hashable, Sendable {
    /// The caregiver switched Potty Pause off entirely.
    case scheduleDisabled
    /// "Disable Potty Pause" without an end date.
    case suspendedIndefinitely
    /// Snoozed until a specific instant.
    case suspendedUntil(Date)
    /// Snoozed for the rest of the local day; resumes at the given instant.
    case suspendedUntilTomorrow(resumesAt: Date)
    /// Today is not one of the schedule's active days.
    case inactiveDay(Weekday)
    /// Outside the daily active window. `resumesAt` is `nil` only when no active
    /// window occurrence exists within the search horizon.
    case outsideActiveWindow(resumesAt: Date?)
    /// Inside a quiet window — nap, bedtime, school, mealtime.
    case quietWindow(QuietWindow, resumesAt: Date)
    /// A pause ended recently and the cooldown has not elapsed.
    case cooldown(until: Date)
    /// Everything else says yes, but the caregiver asked to skip this one.
    case skippingNextPause

    /// Strict priority. Lower wins when several conditions block at once.
    ///
    /// The order is "broadest and most deliberate first":
    /// 0. the master switch, which makes every other answer irrelevant;
    /// 1–2. an explicit caregiver hold, which outranks configuration because the
    ///      caregiver set it *after* the configuration;
    /// 3–5. calendar configuration, narrowing from the whole day to a carve-out;
    /// 6. cooldown, which is HopPotty's own doing and the most transient;
    /// 7. `skipNext` last on purpose — it is consumed when a pause would
    ///    otherwise have fired, so it must not be reported (and spent) on a day
    ///    or in a window where nothing was going to happen anyway.
    public var precedence: Int {
        switch self {
        case .scheduleDisabled: 0
        case .suspendedIndefinitely: 1
        case .suspendedUntil, .suspendedUntilTomorrow: 2
        case .inactiveDay: 3
        case .outsideActiveWindow: 4
        case .quietWindow: 5
        case .cooldown: 6
        case .skippingNextPause: 7
        }
    }

    /// The blocking quiet window, when that is what blocked. Lets the copy layer
    /// say "it is nap time" rather than "not right now".
    public var quietWindow: QuietWindow? {
        if case .quietWindow(let window, _) = self { return window }
        return nil
    }

    /// Whether the caregiver has to do something before pauses resume.
    public var needsCaregiverAction: Bool {
        switch self {
        case .scheduleDisabled, .suspendedIndefinitely: true
        default: false
        }
    }

    /// The earliest instant at which the answer could change on its own.
    /// `nil` means "not without someone changing something".
    public var resumesAt: Date? {
        switch self {
        case .scheduleDisabled, .suspendedIndefinitely, .skippingNextPause, .inactiveDay: nil
        case .suspendedUntil(let date): date
        case .suspendedUntilTomorrow(let date): date
        case .outsideActiveWindow(let date): date
        case .quietWindow(_, let date): date
        case .cooldown(let date): date
        }
    }
}

/// The answer to "may a pause start right now, and if not, why not".
public struct PauseStartDecision: Hashable, Sendable {
    public let isAllowed: Bool
    /// Non-`nil` exactly when `isAllowed` is `false`.
    public let reason: PauseBlockReason?
    /// When it is worth asking again. `nil` when only a caregiver action changes
    /// the answer, or when the day itself has to roll over.
    public let retryAfter: Date?

    public var isBlocked: Bool { !isAllowed }

    public static let allowed = PauseStartDecision(isAllowed: true, reason: nil, retryAfter: nil)

    public static func blocked(_ reason: PauseBlockReason, retryAfter: Date?) -> PauseStartDecision {
        PauseStartDecision(isAllowed: false, reason: reason, retryAfter: retryAfter)
    }

    public init(isAllowed: Bool, reason: PauseBlockReason?, retryAfter: Date?) {
        self.isAllowed = isAllowed
        self.reason = reason
        self.retryAfter = retryAfter
    }
}

/// When the next pause can happen, and what pushed it there.
public struct PauseProjection: Hashable, Sendable {
    /// When the pause may begin.
    public let start: Date
    /// When the pause lifts on its own.
    ///
    /// Always `start + pauseDuration`. This is a ceiling and it is unconditional:
    /// nothing in the engine can extend it, and no biological outcome is an input
    /// to it. See `Docs/CONTRACTS.md` §4.1.
    public let end: Date
    public let basis: PottyTriggerBasis
    /// The derived warning instant, or `nil` when warnings are switched off.
    public let warning: Date?
    /// When the trigger itself comes due, before any window or cooldown is applied.
    ///
    /// For `.screenActivity` this is a *floor*: it assumes the child keeps using
    /// the selected apps continuously from `now`. Real usage is bursty, so the
    /// actual pause lands at or after this instant, never before.
    public let earliestPossible: Date
    /// Why `start` is later than `earliestPossible`, when it is. This is exactly
    /// the reason `canStartPause(at: earliestPossible)` would give.
    public let deferredBy: PauseBlockReason?
    /// The caregiver has `skipNext` pending, so this projected pause is the one
    /// that will be consumed. The pause after it is not projected here because,
    /// for `.screenActivity`, it depends on usage that has not happened yet.
    public let willBeSkipped: Bool

    public var wasDeferred: Bool { start > earliestPossible }
    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public init(
        start: Date,
        end: Date,
        basis: PottyTriggerBasis,
        warning: Date?,
        earliestPossible: Date,
        deferredBy: PauseBlockReason?,
        willBeSkipped: Bool
    ) {
        self.start = start
        self.end = end
        self.basis = basis
        self.warning = warning
        self.earliestPossible = earliestPossible
        self.deferredBy = deferredBy
        self.willBeSkipped = willBeSkipped
    }
}

/// The heads-up before a pause.
public struct WarningProjection: Hashable, Sendable {
    public let fireAt: Date
    public let pauseAt: Date
    public let leadTime: TimeInterval
    /// The warning instant is already behind `now` — schedule the pause, not the
    /// warning.
    public let hasElapsed: Bool
    /// The warning would land inside quiet hours even though the pause does not.
    /// Waking a napping child to tell them they are about to be interrupted is
    /// the opposite of the point, so the caller must not post it.
    public let suppressedBy: QuietWindow?

    public var shouldNotify: Bool { !hasElapsed && suppressedBy == nil }

    public init(
        fireAt: Date,
        pauseAt: Date,
        leadTime: TimeInterval,
        hasElapsed: Bool,
        suppressedBy: QuietWindow?
    ) {
        self.fireAt = fireAt
        self.pauseAt = pauseAt
        self.leadTime = leadTime
        self.hasElapsed = hasElapsed
        self.suppressedBy = suppressedBy
    }
}

/// What a suspension resolves to at a given instant.
public struct SuspensionResolution: Hashable, Sendable {
    /// The value the caller should persist. Expired holds collapse to `.none`.
    public let suspension: ScheduleSuspension
    /// Whether `suspension` differs from what was passed in, so a caller can skip
    /// a pointless write.
    public let didChange: Bool
    /// Whether the hold blocks a pause at this instant.
    public let isBlocking: Bool
    /// When the hold lifts by itself, if it ever does.
    public let resumesAt: Date?

    public init(
        suspension: ScheduleSuspension,
        didChange: Bool,
        isBlocking: Bool,
        resumesAt: Date?
    ) {
        self.suspension = suspension
        self.didChange = didChange
        self.isBlocking = isBlocking
        self.resumesAt = resumesAt
    }
}
