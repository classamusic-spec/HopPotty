import Foundation

/// How assertively HopPotty interrupts.
public enum PottyPauseMode: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Reminders only. Nothing is ever shielded.
    case gentle
    /// Selected apps are shielded and the child sees the Potty Pause screen.
    case pause
    /// Selected apps are shielded and Hop walks the child through the full routine.
    case routine

    public var id: String { rawValue }

    /// Whether this mode ever applies a `ManagedSettings` shield.
    public var shieldsApps: Bool { self != .gentle }

    /// Whether this mode requires Family Controls authorization to function.
    public var requiresScreenTimeAuthorization: Bool { shieldsApps }
}

/// What starts the countdown to the next pause.
///
/// These are genuinely different mechanisms and are never mixed. Screen-activity
/// pauses fire on accumulated use of the selected apps, reported by
/// `DeviceActivity`. Clock pauses fire on the wall clock regardless of what the
/// device is doing. A family that wants "every 45 minutes of iPad" and a family
/// that wants "every hour during the afternoon" want different products.
public enum PottyTriggerBasis: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Accumulated usage of the caregiver-selected apps reaches the interval.
    case screenActivity
    /// A fixed wall-clock cadence across the active window.
    case clockTime

    public var id: String { rawValue }

    /// Clock pauses can run without any app selection; activity pauses cannot.
    public var requiresAppSelection: Bool { self == .screenActivity }
}

/// The interval between pauses.
public enum PottyInterval: Hashable, Codable, Sendable {
    case minutes15, minutes20, minutes30, minutes45, minutes60, minutes90
    case custom(minutes: Int)

    /// Presets offered in the picker, in order.
    public static let presets: [PottyInterval] = [
        .minutes15, .minutes20, .minutes30, .minutes45, .minutes60, .minutes90,
    ]

    /// Guard rails on custom intervals. The floor keeps HopPotty from becoming a
    /// nuisance that families switch off; the ceiling keeps a "reminder" app from
    /// silently never reminding.
    public static let customRange: ClosedRange<Int> = 10...240

    public var minutes: Int {
        switch self {
        case .minutes15: 15
        case .minutes20: 20
        case .minutes30: 30
        case .minutes45: 45
        case .minutes60: 60
        case .minutes90: 90
        case .custom(let m): min(max(m, Self.customRange.lowerBound), Self.customRange.upperBound)
        }
    }

    public var duration: TimeInterval { TimeInterval(minutes) * 60 }

    public init(minutes: Int) {
        self = switch minutes {
        case 15: .minutes15
        case 20: .minutes20
        case 30: .minutes30
        case 45: .minutes45
        case 60: .minutes60
        case 90: .minutes90
        default: .custom(minutes: minutes)
        }
    }
}

/// A window during which HopPotty never interrupts.
public struct QuietWindow: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var start: LocalTimeOfDay
    public var end: LocalTimeOfDay
    public var label: QuietWindowLabel
    public var isEnabled: Bool
    /// Days this window applies on. Empty means every day.
    public var days: Set<Weekday>

    public init(
        id: UUID = UUID(),
        start: LocalTimeOfDay,
        end: LocalTimeOfDay,
        label: QuietWindowLabel = .custom,
        isEnabled: Bool = true,
        days: Set<Weekday> = []
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.label = label
        self.isEnabled = isEnabled
        self.days = days
    }

    /// Whether the window crosses midnight, e.g. bedtime 19:30 → 07:00.
    public var wrapsMidnight: Bool { end <= start }

    /// Whether a wall-clock time falls inside this window.
    ///
    /// The window is half-open: a pause scheduled exactly at the end time is
    /// allowed through, so a 07:00 wake-up boundary does not suppress a 07:00 pause.
    public func contains(_ time: LocalTimeOfDay) -> Bool {
        guard isEnabled else { return false }
        let t = time.minutesSinceMidnight
        let s = start.minutesSinceMidnight
        let e = end.minutesSinceMidnight
        if wrapsMidnight {
            // 19:30 → 07:00 covers [19:30, 24:00) ∪ [00:00, 07:00)
            return t >= s || t < e
        }
        return t >= s && t < e
    }

    /// Whether the window applies on a given weekday.
    public func applies(on weekday: Weekday) -> Bool {
        days.isEmpty || days.contains(weekday)
    }
}

/// Why a quiet window exists. Purely descriptive — it changes the label and icon,
/// never the behaviour.
public enum QuietWindowLabel: String, Codable, CaseIterable, Sendable, Identifiable {
    case nap, bedtime, school, mealtime, custom
    public var id: String { rawValue }
}

/// Days of the week, matching `Calendar`'s 1-based Sunday-first numbering so
/// conversion is a lookup rather than arithmetic that drifts across locales.
public enum Weekday: Int, Codable, CaseIterable, Sendable, Identifiable, Comparable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public var id: Int { rawValue }
    public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }

    public static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    public static let weekend: Set<Weekday> = [.saturday, .sunday]
    public static let everyDay: Set<Weekday> = Set(Weekday.allCases)

    public init?(date: Date, calendar: Calendar) {
        self.init(rawValue: calendar.component(.weekday, from: date))
    }
}

/// A caregiver's complete Potty Pause configuration for one child.
public struct PottySchedule: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let childID: UUID

    public var mode: PottyPauseMode
    public var triggerBasis: PottyTriggerBasis
    public var interval: PottyInterval

    /// How long before a pause the warning fires. Zero disables the warning.
    public var warningOffset: TimeInterval
    /// How long the shield stays up before it lifts on its own.
    ///
    /// This is a ceiling, not a requirement: the pause always ends when this
    /// elapses, whether or not the child did anything. Screen access is never
    /// contingent on a biological outcome.
    public var pauseDuration: TimeInterval
    /// Minimum gap after a pause ends before another can start, so a child is not
    /// re-interrupted the moment they get back to their game.
    public var cooldown: TimeInterval

    public var quietWindows: [QuietWindow]
    /// Days HopPotty is active. Empty is treated as every day.
    public var activeDays: Set<Weekday>
    /// The earliest and latest wall-clock times a pause may occur.
    public var activeWindowStart: LocalTimeOfDay
    public var activeWindowEnd: LocalTimeOfDay

    public var isEnabled: Bool
    public var suspension: ScheduleSuspension

    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        childID: UUID,
        mode: PottyPauseMode = .gentle,
        triggerBasis: PottyTriggerBasis = .screenActivity,
        interval: PottyInterval = .minutes45,
        warningOffset: TimeInterval = 120,
        pauseDuration: TimeInterval = 180,
        cooldown: TimeInterval = 300,
        quietWindows: [QuietWindow] = [],
        activeDays: Set<Weekday> = Weekday.everyDay,
        activeWindowStart: LocalTimeOfDay = LocalTimeOfDay(hour: 7, minute: 0),
        activeWindowEnd: LocalTimeOfDay = LocalTimeOfDay(hour: 19, minute: 30),
        isEnabled: Bool = true,
        suspension: ScheduleSuspension = .none,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.childID = childID
        self.mode = mode
        self.triggerBasis = triggerBasis
        self.interval = interval
        self.warningOffset = max(0, warningOffset)
        self.pauseDuration = max(PottySchedule.minimumPauseDuration, pauseDuration)
        self.cooldown = max(0, cooldown)
        self.quietWindows = quietWindows
        self.activeDays = activeDays.isEmpty ? Weekday.everyDay : activeDays
        self.activeWindowStart = activeWindowStart
        self.activeWindowEnd = activeWindowEnd
        self.isEnabled = isEnabled
        self.suspension = suspension
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// A pause shorter than this is not long enough to walk to a bathroom.
    public static let minimumPauseDuration: TimeInterval = 60
    /// A pause longer than this stops being a routine and starts being a lockout.
    public static let maximumPauseDuration: TimeInterval = 600

    /// Whether this configuration can actually shield anything right now.
    public var requiresScreenTimeAuthorization: Bool { mode.requiresScreenTimeAuthorization }

    /// The warning offset can never exceed the interval — a warning that fires
    /// before the previous pause ended would be incoherent.
    public var effectiveWarningOffset: TimeInterval {
        min(warningOffset, max(0, interval.duration - 60))
    }
}

/// A temporary hold on an otherwise-enabled schedule.
///
/// Modelled as one value rather than a set of booleans so "skip the next one"
/// and "pause until tomorrow" cannot both be half-true at once.
public enum ScheduleSuspension: Hashable, Codable, Sendable {
    /// Running normally.
    case none
    /// Skip exactly one upcoming pause, then resume.
    case skipNext
    /// Suspended until a specific instant.
    case until(Date)
    /// Suspended until the next local day begins.
    case untilTomorrow(from: Date)
    /// Suspended indefinitely by the caregiver — the "Disable Potty Pause" switch.
    case indefinite

    /// Whether the suspension has expired and the schedule should resume.
    public func hasExpired(at now: Date, calendar: Calendar) -> Bool {
        switch self {
        case .none: true
        case .skipNext, .indefinite: false
        case .until(let date): now >= date
        case .untilTomorrow(let from):
            // Resumes at the start of the next calendar day in the current zone,
            // which is what a parent means by "not until tomorrow".
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: from)) {
                now >= nextDay
            } else {
                true
            }
        }
    }
}
