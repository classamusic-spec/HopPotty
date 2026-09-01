import Foundation
import HopPottyCore

/// What HopPotty intends to register with `DeviceActivityCenter`, computed as a
/// value before anything is registered.
///
/// ## Why a plan, and not just a sequence of calls
///
/// Three reasons, in order of how much trouble each saves:
///
/// 1. **Deterministic re-registration.** Re-registering monitoring is the
///    dangerous operation in this layer: get it wrong and the family is left with
///    either no monitoring or an orphaned activity that fires forever. Computing
///    the desired end state first turns "update the schedule" into "diff two
///    lists", which is a thing that can be reasoned about and tested.
/// 2. **The interesting logic becomes testable without a device.** Every hard
///    part here — the usage ladder, the clock-slot arithmetic, what a 10-minute
///    cadence does against a 15-minute platform floor, quiet windows straddling
///    midnight — is `Foundation` arithmetic that runs on Linux.
/// 3. **Honesty about what was actually possible.** Apple's limits mean HopPotty
///    sometimes cannot register what a caregiver asked for. `notes` records every
///    such compromise so the parent UI can say what it did instead of silently
///    doing something different.
///
/// ## The two trigger bases are genuinely different mechanisms
///
/// They are never mixed, because they are not variations of one idea:
///
/// - **`.screenActivity`** — `DeviceActivityEvent.threshold` counts *accumulated
///   foreground usage* of the selected apps, not wall-clock time. Apple: "Device
///   activity is the amount of time an application, category, or web domain is
///   frontmost on the screen." A child who puts the iPad down accrues nothing.
///   One activity spanning the active window carries a *ladder* of events at
///   1×, 2×, 3× the interval, because "an application's extension receives a
///   callback once the combination … have been in use longer than the event's
///   threshold within the activity's scheduled interval" — once. A single event
///   would fire on the first 45 minutes of the day and never again.
///
/// - **`.clockTime`** — a wall-clock cadence, which `DeviceActivitySchedule`
///   cannot express as a repeat, since a schedule describes one interval. So each
///   pause time gets its own activity whose `intervalDidStart` is the trigger.
///
/// A family that wants "every 45 minutes of iPad" and a family that wants "every
/// hour during the afternoon" want different products, and this is where that
/// shows up as different code.
public struct MonitoringPlan: Equatable, Sendable {

    public struct Event: Equatable, Sendable {
        public let name: String
        public let role: ScreenTimeIdentifiers.EventRole
        /// Accumulated foreground usage, in minutes, at which this fires.
        public let thresholdMinutes: Int

        public init(name: String, role: ScreenTimeIdentifiers.EventRole, thresholdMinutes: Int) {
            self.name = name
            self.role = role
            self.thresholdMinutes = thresholdMinutes
        }
    }

    public struct Activity: Equatable, Sendable {
        public let name: String
        public let role: ScreenTimeIdentifiers.ActivityRole
        /// `[.hour, .minute]` only, so the schedule repeats on the wall clock in
        /// whatever zone the family is in today. See the DST note on `make`.
        public let intervalStart: DateComponents
        public let intervalEnd: DateComponents
        public let repeats: Bool
        /// Lead time for `intervalWillEndWarning` / `intervalWillStartWarning`.
        public let warningTime: DateComponents?
        public let events: [Event]

        public init(
            name: String,
            role: ScreenTimeIdentifiers.ActivityRole,
            intervalStart: DateComponents,
            intervalEnd: DateComponents,
            repeats: Bool,
            warningTime: DateComponents? = nil,
            events: [Event] = []
        ) {
            self.name = name
            self.role = role
            self.intervalStart = intervalStart
            self.intervalEnd = intervalEnd
            self.repeats = repeats
            self.warningTime = warningTime
            self.events = events
        }
    }

    /// A compromise the plan had to make. Every one of these is something a
    /// caregiver may notice, so every one of them has to be sayable.
    public enum Note: Equatable, Sendable {
        /// Potty Pause is off, suspended indefinitely, or in `gentle` mode.
        /// Nothing is registered and nothing ever shields.
        case nothingToMonitor
        /// A usage trigger with no selection can never fire.
        case selectionRequired
        /// The caregiver's cadence is below the 15-minute platform floor for
        /// wall-clock schedules, so pauses are spaced further apart than asked.
        case cadenceRaisedToPlatformMinimum(requestedMinutes: Int, actualMinutes: Int)
        /// More pause slots fit in the active window than HopPotty will register.
        case clockSlotsTruncated(requested: Int, registered: Int)
        /// The usage ladder hit the per-activity event ceiling.
        case usageLadderTruncated(requested: Int, registered: Int)
        /// The active window is shorter than the 15-minute platform minimum, so
        /// no schedule can cover it.
        case activeWindowTooShort(minutes: Int)
    }

    public let activities: [Activity]
    public let notes: [Note]

    public init(activities: [Activity], notes: [Note] = []) {
        self.activities = activities
        self.notes = notes
    }

    public static let empty = MonitoringPlan(activities: [], notes: [.nothingToMonitor])

    public var isEmpty: Bool { activities.isEmpty }
    public var activityNames: Set<String> { Set(activities.map(\.name)) }

    // MARK: - Building

    /// Compute the plan for one child's schedule.
    ///
    /// ## On time zones and daylight saving
    ///
    /// Every interval here is `[.hour, .minute]` with no date, which is exactly
    /// what a caregiver means by "between 7am and 7:30pm": the wall clock in
    /// whatever zone the family is in today. A family that flies to another zone
    /// gets pauses in local time on arrival, and a DST transition shifts nothing.
    /// This is the same reasoning that puts quiet windows in `LocalTimeOfDay`
    /// rather than in absolute `Date`s.
    ///
    /// The one wrinkle is the spring-forward hour, which does not exist. A clock
    /// slot inside it simply does not occur that day; the next slot does. Nothing
    /// is scheduled to *end* a pause on wall-clock time — a pause's ceiling is an
    /// absolute instant in `SharedPauseRecord` — so a missing hour can delay a
    /// pause but can never extend one.
    ///
    /// Apple's own caveat is recorded for completeness: "If the device's time zone
    /// changes in the middle of a schedule's interval, any ongoing events include
    /// device activity that may have accumulated outside of the new time zone."
    /// For a usage ladder that means a travelling child's accumulated minutes are
    /// carried across the change rather than reset, which is the behaviour a
    /// parent would expect anyway.
    ///
    /// - Parameters:
    ///   - schedule: the caregiver's configuration.
    ///   - hasSelection: whether anything is picked. A usage trigger with nothing
    ///     selected can never fire, and registering it would be a lie.
    public static func make(for schedule: PottySchedule, hasSelection: Bool) -> MonitoringPlan {
        guard schedule.isEnabled, schedule.suspension != .indefinite, schedule.mode.shieldsApps else {
            return .empty
        }

        let windowMinutes = activeWindowMinutes(schedule)
        guard windowMinutes >= Int(ScreenTimeIdentifiers.minimumScheduleInterval / 60) else {
            return MonitoringPlan(activities: [], notes: [.activeWindowTooShort(minutes: windowMinutes)])
        }

        switch schedule.triggerBasis {
        case .screenActivity:
            guard hasSelection else {
                return MonitoringPlan(activities: [], notes: [.selectionRequired])
            }
            return usagePlan(schedule, windowMinutes: windowMinutes)
        case .clockTime:
            return clockPlan(schedule, windowMinutes: windowMinutes)
        }
    }

    /// Minutes covered by the active window, handling a window that wraps past
    /// midnight (a caregiver who allows screens until 21:00 and starts again at
    /// 06:30 has a 22.5-hour window, not a negative one).
    private static func activeWindowMinutes(_ schedule: PottySchedule) -> Int {
        let start = schedule.activeWindowStart.minutesSinceMidnight
        let end = schedule.activeWindowEnd.minutesSinceMidnight
        return end > start ? end - start : (24 * 60) - start + end
    }

    // MARK: Usage ladder

    private static func usagePlan(_ schedule: PottySchedule, windowMinutes: Int) -> MonitoringPlan {
        let interval = schedule.interval.minutes
        let warning = Int(schedule.effectiveWarningOffset / 60)

        // How many pauses could fit if the child used the device for the whole
        // window. More than that is unreachable; registering unreachable events
        // wastes the per-activity budget on rungs nobody will climb.
        let reachableSteps = max(1, windowMinutes / max(interval, 1))

        // Each step costs one threshold event, plus one warning event when a
        // warning is configured. The ceiling is on events, not on steps.
        let eventsPerStep = warning > 0 ? 2 : 1
        let affordableSteps = max(1, ScreenTimeIdentifiers.maximumUsageEvents / eventsPerStep)
        let steps = min(reachableSteps, affordableSteps)

        var events: [Event] = []
        for step in 1...steps {
            let threshold = interval * step
            if warning > 0, threshold - warning > 0 {
                events.append(
                    Event(
                        name: ScreenTimeIdentifiers.warningEventName(step: step),
                        role: .warning,
                        thresholdMinutes: threshold - warning
                    )
                )
            }
            events.append(
                Event(
                    name: ScreenTimeIdentifiers.thresholdEventName(step: step),
                    role: .threshold,
                    thresholdMinutes: threshold
                )
            )
        }

        var notes: [Note] = []
        if steps < reachableSteps {
            notes.append(.usageLadderTruncated(requested: reachableSteps, registered: steps))
        }

        let activity = Activity(
            name: ScreenTimeIdentifiers.usageActivityName,
            role: .usage,
            intervalStart: components(schedule.activeWindowStart),
            intervalEnd: components(schedule.activeWindowEnd),
            repeats: true,
            // No schedule-level warning: the approach cue for a usage trigger is
            // an *event* warning, not an interval warning. Mixing them would give
            // a family two different "potty time soon" nudges from two mechanisms.
            warningTime: nil,
            events: events
        )
        return MonitoringPlan(activities: [activity], notes: notes)
    }

    // MARK: Clock slots

    private static func clockPlan(_ schedule: PottySchedule, windowMinutes: Int) -> MonitoringPlan {
        var notes: [Note] = []

        // A `DeviceActivitySchedule` cannot be shorter than 15 minutes, so two
        // wall-clock pauses cannot be closer together than that without their
        // intervals overlapping. Rather than register overlapping activities —
        // whose behaviour Apple does not document — the cadence is raised, and
        // the caregiver is told.
        let floor = Int(ScreenTimeIdentifiers.minimumScheduleInterval / 60)
        let requested = schedule.interval.minutes
        let cadence = max(requested, floor)
        if cadence != requested {
            notes.append(.cadenceRaisedToPlatformMinimum(requestedMinutes: requested, actualMinutes: cadence))
        }

        // Slots start one cadence *into* the window: a child who has just been
        // handed a device at 07:00 does not need a potty break at 07:00.
        var offsets: [Int] = []
        var offset = cadence
        while offset < windowMinutes {
            offsets.append(offset)
            offset += cadence
        }

        let startMinutes = schedule.activeWindowStart.minutesSinceMidnight
        let candidates = offsets.map { LocalTimeOfDay(minutesSinceMidnight: (startMinutes + $0) % (24 * 60)) }

        // Quiet windows are applied here rather than in the extension, so a nap
        // is never interrupted by an activity that should not have existed. This
        // is the cheapest possible place to enforce it: nothing is registered, so
        // nothing has to remember to stay quiet.
        let permitted = candidates.filter { time in
            !schedule.quietWindows.contains { $0.contains(time) }
        }

        let registered = Array(permitted.prefix(ScreenTimeIdentifiers.maximumScheduledActivities))
        if registered.count < permitted.count {
            notes.append(.clockSlotsTruncated(requested: permitted.count, registered: registered.count))
        }

        let activities = registered.enumerated().map { index, time -> Activity in
            let end = LocalTimeOfDay(minutesSinceMidnight: (time.minutesSinceMidnight + floor) % (24 * 60))
            return Activity(
                name: ScreenTimeIdentifiers.clockActivityName(slot: index),
                role: .clock,
                intervalStart: components(time),
                intervalEnd: components(end),
                // Daily. The alternative — the app re-registering every morning —
                // only works for families who open HopPotty every morning.
                repeats: true,
                // `intervalWillStartWarning` is the approach cue for a clock
                // trigger. Apple clamps a warning longer than the interval to the
                // interval's start, so an over-long warning degrades to "fires at
                // the start", which is early rather than late.
                warningTime: schedule.effectiveWarningOffset > 0
                    ? DateComponents(minute: Int(schedule.effectiveWarningOffset / 60))
                    : nil,
                events: []
            )
        }

        if activities.isEmpty { notes.append(.nothingToMonitor) }
        return MonitoringPlan(activities: activities, notes: notes)
    }

    // MARK: Backstop

    /// The 15-minute safety-net activity registered the moment a shield goes up.
    ///
    /// This is the whole answer to "how does a 3-minute pause end when HopPotty is
    /// not running?", and it is a workaround for the 15-minute floor rather than a
    /// design anyone would choose:
    ///
    /// - `intervalWillEndWarning` is aimed at the *intended* end, by setting
    ///   `warningTime` to `backstopEnd − plannedEnd`. That is path (B) in
    ///   `Docs/ScreenTimeArchitecture.md` §9.
    /// - `intervalDidEnd` at +15 minutes is the guaranteed ceiling, path (C).
    ///
    /// `repeats: false`, so the activity stops calling back after one interval and
    /// cannot become an orphan that ends future pauses early.
    ///
    /// UNVERIFIED — confirm on device: whether `intervalWillEndWarning` is subject
    /// to the same "only when the device is in use" gating Apple documents for
    /// `intervalDidStart`/`intervalDidEnd`, and how punctual it is. The intended
    /// pause duration depends on it. If it turns out to be unusable, the pause
    /// still ends — at the 15-minute backstop, or on next foreground — but it ends
    /// late, and the product would need to raise its minimum pause duration to
    /// match rather than pretend.
    public static func backstop(for record: SharedPauseRecord, calendar: Calendar = .current) -> Activity {
        let start = calendar.dateComponents([.hour, .minute], from: record.startedAt)
        let end = calendar.dateComponents([.hour, .minute], from: record.backstopEndAt)
        let lead = Int(record.warningLeadTime / 60)
        return Activity(
            name: ScreenTimeIdentifiers.backstopActivityName,
            role: .backstop,
            intervalStart: start,
            intervalEnd: end,
            repeats: false,
            warningTime: lead > 0 ? DateComponents(minute: lead) : nil,
            events: []
        )
    }

    private static func components(_ time: LocalTimeOfDay) -> DateComponents {
        DateComponents(hour: time.hour, minute: time.minute)
    }
}
