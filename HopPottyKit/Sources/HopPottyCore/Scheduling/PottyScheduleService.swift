import Foundation

/// Decides when a Potty Pause may happen.
///
/// Everything is a pure function of an injected `Calendar` (which carries the
/// time zone) and an explicit `now`. There is no `Date()` anywhere in this file,
/// no `TimeZone.current`, and no stored mutable state, so the same inputs always
/// produce the same answer on a device, in a Screen Time extension, and in a test
/// running on Linux in July.
///
/// ## Wall clock, not instants
///
/// Quiet hours and the active window are `LocalTimeOfDay` values, and membership
/// is tested by converting the *instant* to wall-clock components and comparing
/// there — never by comparing against a precomputed boundary `Date`. That single
/// choice is what makes the daylight-saving cases fall out correctly:
///
/// - Spring forward: 02:00–03:00 simply never occurs, so a 01:00–03:00 quiet
///   window covers one real hour that day instead of two, and no instant is
///   wrongly classified.
/// - Fall back: 01:30 occurs twice and both instants report an hour of 1, so both
///   are quiet. A boundary-`Date` comparison would silently let one of them
///   through.
/// - A 12:30 nap is 12:30 on both sides of a transition, and stays 12:30 when the
///   family lands in a different zone.
public struct PottyScheduleService: Sendable {
    /// Carries the time zone. Injected, never defaulted to `.current`, so travel
    /// and DST are ordinary test inputs rather than field reports.
    public let calendar: Calendar

    /// How far ahead the engine will look for a usable slot. Any weekly pattern
    /// recurs within seven days; the eighth is slack for a window that wraps past
    /// midnight into the last active day.
    public static let searchHorizonDays = 8

    /// Bound on every advance loop. Each iteration is proven to move `cursor`
    /// strictly forward, so this only ever catches a future bug — but a parenting
    /// app must not spin in a Screen Time extension.
    private static let maxAdvanceSteps = 256

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    public init(timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }
}

// MARK: - Wall-clock primitives

extension PottyScheduleService {
    /// The wall-clock reading a family would see on the kitchen clock.
    public func localTime(at instant: Date) -> LocalTimeOfDay {
        let components = calendar.dateComponents([.hour, .minute], from: instant)
        return LocalTimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    public func weekday(at instant: Date) -> Weekday {
        Weekday(rawValue: calendar.component(.weekday, from: instant)) ?? .sunday
    }

    /// Half-open `[start, end)` containment on the 24-hour clock.
    ///
    /// `end <= start` wraps midnight, matching `QuietWindow.wrapsMidnight`. Equal
    /// bounds therefore mean the whole day, which is the same reading the model
    /// gives them.
    static func covers(start: LocalTimeOfDay, end: LocalTimeOfDay, _ time: LocalTimeOfDay) -> Bool {
        let s = start.minutesSinceMidnight
        let e = end.minutesSinceMidnight
        let t = time.minutesSinceMidnight
        if e <= s { return t >= s || t < e }
        return t >= s && t < e
    }

    /// Midnight of the calendar day `offset` days from `instant`.
    ///
    /// Calendar arithmetic, not `+86400`: adding a day across a DST boundary has
    /// to land on the next midnight, not 23:00 or 01:00.
    func day(_ instant: Date, offsetBy offset: Int) -> Date? {
        let startOfDay = calendar.startOfDay(for: instant)
        guard offset != 0 else { return startOfDay }
        return calendar.date(byAdding: DateComponents(day: offset), to: startOfDay)
    }

    /// The concrete occurrence of a wall-clock window containing `instant`, or
    /// `nil` if the instant is outside it.
    func occurrence(
        start: LocalTimeOfDay,
        end: LocalTimeOfDay,
        containing instant: Date
    ) -> ScheduleWindowOccurrence? {
        let time = localTime(at: instant)
        guard Self.covers(start: start, end: end, time) else { return nil }

        let wraps = end <= start
        // Past midnight inside a wrapping window means the occurrence started on
        // the previous calendar day, and that is the day whose weekday counts.
        let beganYesterday = wraps && time.minutesSinceMidnight < end.minutesSinceMidnight

        guard let anchorDay = day(instant, offsetBy: beganYesterday ? -1 : 0),
              let startDate = calendar.resolving(start, on: anchorDay),
              let endDay = day(anchorDay, offsetBy: wraps ? 1 : 0),
              let endDate = calendar.resolving(end, on: endDay)
        else { return nil }

        return ScheduleWindowOccurrence(
            start: startDate,
            end: endDate,
            weekday: weekday(at: anchorDay)
        )
    }

    /// An empty `activeDays` set means every day. The initialiser normalises this,
    /// but `Codable` bypasses initialisers, so a decoded schedule can still arrive
    /// empty and must not mean "never".
    func effectiveActiveDays(_ schedule: PottySchedule) -> Set<Weekday> {
        schedule.activeDays.isEmpty ? Weekday.everyDay : schedule.activeDays
    }
}

// MARK: - Active window

extension PottyScheduleService {
    /// Whether the instant falls inside the daily active window.
    ///
    /// Deliberately independent of `activeDays`: "is it daytime" and "is today a
    /// HopPotty day" are different questions with different explanations.
    public func isWithinActiveWindow(at instant: Date, in schedule: PottySchedule) -> Bool {
        activeWindowOccurrence(at: instant, in: schedule) != nil
    }

    public func activeWindowOccurrence(
        at instant: Date,
        in schedule: PottySchedule
    ) -> ScheduleWindowOccurrence? {
        occurrence(
            start: schedule.activeWindowStart,
            end: schedule.activeWindowEnd,
            containing: instant
        )
    }

    /// The weekday that governs the day check at this instant.
    ///
    /// Inside a window that started yesterday it is yesterday's weekday, so a
    /// Friday-only schedule with a 19:30–07:00 window still covers Saturday's
    /// small hours.
    public func governingWeekday(at instant: Date, in schedule: PottySchedule) -> Weekday {
        activeWindowOccurrence(at: instant, in: schedule)?.weekday ?? weekday(at: instant)
    }

    public func isActiveDay(at instant: Date, in schedule: PottySchedule) -> Bool {
        effectiveActiveDays(schedule).contains(governingWeekday(at: instant, in: schedule))
    }

    /// The next instant at which an active-window occurrence begins on an active
    /// day, strictly after `instant`.
    public func nextActiveWindowStart(after instant: Date, in schedule: PottySchedule) -> Date? {
        let days = effectiveActiveDays(schedule)
        for offset in 0...Self.searchHorizonDays {
            guard let candidateDay = day(instant, offsetBy: offset),
                  days.contains(weekday(at: candidateDay)),
                  let start = calendar.resolving(schedule.activeWindowStart, on: candidateDay)
            else { continue }
            if start > instant { return start }
        }
        return nil
    }
}

// MARK: - Quiet windows

extension PottyScheduleService {
    public func isQuiet(at instant: Date, in schedule: PottySchedule) -> Bool {
        !quietOccurrences(at: instant, in: schedule).isEmpty
    }

    /// The quiet window in force, or `nil`.
    ///
    /// ## Overlap precedence
    ///
    /// When several windows cover the same instant the governing one is:
    /// 1. the occurrence that **ends latest**, because that is the one that still
    ///    has something to say about when the child may be interrupted;
    /// 2. then the one that **started earliest** (the longer window);
    /// 3. then by label — bedtime, nap, school, mealtime, custom — so the most
    ///    protective description wins a genuine tie;
    /// 4. then by window `id`, which is arbitrary but total: two identical windows
    ///    must never produce a different answer on different runs.
    ///
    /// `resumesAt` follows the whole chain, so back-to-back windows resume once,
    /// at the end of the last one.
    public func activeQuietWindow(at instant: Date, in schedule: PottySchedule) -> ActiveQuietWindow? {
        let hits = quietOccurrences(at: instant, in: schedule)
        guard let governing = hits.first else { return nil }
        return ActiveQuietWindow(
            window: governing.window,
            start: governing.occurrence.start,
            end: governing.occurrence.end,
            overlapping: hits.map(\.window),
            resumesAt: quietPeriodEnd(from: instant, in: schedule)
        )
    }

    /// When quiet lifts, following overlapping and adjacent windows. Returns
    /// `instant` unchanged when it is not quiet.
    public func quietPeriodEnd(from instant: Date, in schedule: PottySchedule) -> Date {
        var cursor = instant
        var steps = 0
        while steps < Self.maxAdvanceSteps,
              let governing = quietOccurrences(at: cursor, in: schedule).first {
            steps += 1
            // A window is half-open, so its end instant is already outside it. The
            // one-minute floor only fires on a degenerate window and exists so a
            // corrupt schedule cannot hang a device-activity extension.
            cursor = governing.occurrence.end > cursor
                ? governing.occurrence.end
                : cursor.addingTimeInterval(60)
        }
        return cursor
    }

    func quietOccurrences(
        at instant: Date,
        in schedule: PottySchedule
    ) -> [(window: QuietWindow, occurrence: ScheduleWindowOccurrence)] {
        schedule.quietWindows
            .compactMap { window -> (window: QuietWindow, occurrence: ScheduleWindowOccurrence)? in
                guard window.isEnabled,
                      let occurrence = occurrence(
                          start: window.start,
                          end: window.end,
                          containing: instant
                      ),
                      window.applies(on: occurrence.weekday)
                else { return nil }
                return (window, occurrence)
            }
            .sorted { lhs, rhs in
                if lhs.occurrence.end != rhs.occurrence.end {
                    return lhs.occurrence.end > rhs.occurrence.end
                }
                if lhs.occurrence.start != rhs.occurrence.start {
                    return lhs.occurrence.start < rhs.occurrence.start
                }
                if lhs.window.label.protectionRank != rhs.window.label.protectionRank {
                    return lhs.window.label.protectionRank < rhs.window.label.protectionRank
                }
                return lhs.window.id.uuidString < rhs.window.id.uuidString
            }
    }
}

extension QuietWindowLabel {
    /// Tie-break order for overlapping windows. Descriptive only — it never
    /// changes whether a window applies, just which one gets named.
    var protectionRank: Int {
        switch self {
        case .bedtime: 0
        case .nap: 1
        case .school: 2
        case .mealtime: 3
        case .custom: 4
        }
    }
}

// MARK: - Suspension

extension PottyScheduleService {
    /// Expires time-based holds and, when asked, consumes `skipNext`.
    ///
    /// Consumption is opt-in because this function is also called from read-only
    /// paths — a dashboard refresh must not silently spend the caregiver's
    /// "skip the next one". Only the code that actually suppresses a pause passes
    /// `consumingSkip: true`.
    public func resolveSuspension(
        _ suspension: ScheduleSuspension,
        at now: Date,
        consumingSkip: Bool = false
    ) -> SuspensionResolution {
        switch suspension {
        case .none:
            return SuspensionResolution(
                suspension: .none, didChange: false, isBlocking: false, resumesAt: nil
            )

        case .indefinite:
            return SuspensionResolution(
                suspension: .indefinite, didChange: false, isBlocking: true, resumesAt: nil
            )

        case .until(let date):
            guard now < date else {
                return SuspensionResolution(
                    suspension: .none, didChange: true, isBlocking: false, resumesAt: nil
                )
            }
            return SuspensionResolution(
                suspension: suspension, didChange: false, isBlocking: true, resumesAt: date
            )

        case .untilTomorrow(let from):
            // "Not until tomorrow" means the next local midnight in whatever zone
            // the family is in now — so a family that flies east resumes earlier,
            // which is exactly what their new day does.
            guard let resumesAt = day(from, offsetBy: 1) else {
                return SuspensionResolution(
                    suspension: .none, didChange: true, isBlocking: false, resumesAt: nil
                )
            }
            guard now < resumesAt else {
                return SuspensionResolution(
                    suspension: .none, didChange: true, isBlocking: false, resumesAt: nil
                )
            }
            return SuspensionResolution(
                suspension: suspension, didChange: false, isBlocking: true, resumesAt: resumesAt
            )

        case .skipNext:
            return SuspensionResolution(
                suspension: consumingSkip ? .none : .skipNext,
                didChange: consumingSkip,
                isBlocking: true,
                resumesAt: nil
            )
        }
    }
}

// MARK: - Can a pause start

extension PottyScheduleService {
    /// The single deterministic gate. Every caller — the device-activity
    /// extension, the parent dashboard, the debug screen — asks this and nothing
    /// else, so they cannot disagree.
    public func canStartPause(at state: ScheduleState) -> PauseStartDecision {
        canStartPause(at: state.now, in: state.schedule, lastPauseEnd: state.lastPauseEnd)
    }

    public func canStartPause(
        at now: Date,
        in schedule: PottySchedule,
        lastPauseEnd: Date? = nil
    ) -> PauseStartDecision {
        guard let reason = blockReason(at: now, in: schedule, lastPauseEnd: lastPauseEnd) else {
            return .allowed
        }
        return .blocked(reason, retryAfter: reason.resumesAt)
    }

    /// The first blocking reason in `PauseBlockReason.precedence` order, or `nil`.
    func blockReason(
        at now: Date,
        in schedule: PottySchedule,
        lastPauseEnd: Date?
    ) -> PauseBlockReason? {
        guard schedule.isEnabled else { return .scheduleDisabled }

        let suspension = resolveSuspension(schedule.suspension, at: now)
        if suspension.isBlocking {
            switch suspension.suspension {
            case .indefinite:
                return .suspendedIndefinitely
            case .until(let date):
                return .suspendedUntil(date)
            case .untilTomorrow:
                if let resumesAt = suspension.resumesAt {
                    return .suspendedUntilTomorrow(resumesAt: resumesAt)
                }
            case .skipNext, .none:
                // Ranked last; evaluated after the calendar checks below so it is
                // never reported for a pause that was not going to fire.
                break
            }
        }

        let occurrence = activeWindowOccurrence(at: now, in: schedule)
        let weekdayInForce = occurrence?.weekday ?? weekday(at: now)
        if !effectiveActiveDays(schedule).contains(weekdayInForce) {
            return .inactiveDay(weekdayInForce)
        }

        if occurrence == nil {
            return .outsideActiveWindow(
                resumesAt: nextActiveWindowStart(after: now, in: schedule)
            )
        }

        if let quiet = activeQuietWindow(at: now, in: schedule) {
            return .quietWindow(quiet.window, resumesAt: quiet.resumesAt)
        }

        if let lastPauseEnd, schedule.cooldown > 0 {
            let cooldownEnd = lastPauseEnd.addingTimeInterval(schedule.cooldown)
            if now < cooldownEnd { return .cooldown(until: cooldownEnd) }
        }

        if case .skipNext = schedule.suspension { return .skippingNextPause }

        return nil
    }
}

// MARK: - Next pause

extension PottyScheduleService {
    /// When the next pause can happen.
    ///
    /// Returns `nil` when no pause is coming at all: the schedule is off, it is
    /// suspended with no end, or no usable slot exists inside the search horizon
    /// (a schedule whose active window is entirely swallowed by quiet windows).
    ///
    /// The two trigger bases are genuinely different mechanisms, and are handled
    /// differently on purpose:
    ///
    /// - `.screenActivity` counts qualifying use. When a quiet window swallows the
    ///   moment the interval comes due, the child is *owed* a pause, so it lands
    ///   the instant quiet lifts.
    /// - `.clockTime` is a cadence the family can predict — "every hour from
    ///   seven". Its slots are fixed to the wall clock, measured from the active
    ///   window start, and a slot lost to quiet hours is skipped rather than
    ///   dragged forward, so the pattern never drifts.
    public func nextPause(after state: ScheduleState) -> PauseProjection? {
        let schedule = state.schedule
        guard schedule.isEnabled else { return nil }

        let suspension = resolveSuspension(schedule.suspension, at: state.now)
        if suspension.isBlocking, case .indefinite = suspension.suspension { return nil }
        let willBeSkipped = suspension.isBlocking && suspension.suspension == .skipNext

        // What the trigger alone says, with no windows, cooldown or holds applied.
        let triggerDue: Date
        switch schedule.triggerBasis {
        case .screenActivity:
            let remaining = max(0, schedule.interval.duration - state.accumulatedActivity)
            triggerDue = state.now.addingTimeInterval(remaining)
        case .clockTime:
            // The cadence is owned by the grid below; the trigger itself is "now".
            triggerDue = state.now
        }

        var earliest = triggerDue
        if let resumesAt = suspension.resumesAt, resumesAt > earliest { earliest = resumesAt }
        if let lastPauseEnd = state.lastPauseEnd {
            let cooldownEnd = lastPauseEnd.addingTimeInterval(schedule.cooldown)
            if cooldownEnd > earliest { earliest = cooldownEnd }
        }

        let start: Date?
        switch schedule.triggerBasis {
        case .screenActivity:
            start = firstAllowedInstant(atOrAfter: earliest, in: schedule)
        case .clockTime:
            start = firstAllowedSlot(
                atOrAfter: earliest,
                in: schedule,
                after: state.lastPauseEnd
            )
        }
        guard let start else { return nil }

        // The explanation is the reason a pause could not start the moment the
        // trigger came due — the same answer `canStartPause` would give there, so
        // the two functions can never contradict each other.
        let deferredBy = start > triggerDue
            ? blockReason(at: triggerDue, in: schedule, lastPauseEnd: state.lastPauseEnd)
            : nil

        return PauseProjection(
            start: start,
            end: start.addingTimeInterval(schedule.pauseDuration),
            basis: schedule.triggerBasis,
            warning: warningTime(forPauseAt: start, in: schedule),
            earliestPossible: triggerDue,
            deferredBy: deferredBy,
            willBeSkipped: willBeSkipped
        )
    }

    /// Walk forward from `earliest` to the first instant that is on an active day,
    /// inside the active window and not quiet.
    func firstAllowedInstant(atOrAfter earliest: Date, in schedule: PottySchedule) -> Date? {
        var cursor = earliest
        var steps = 0
        while steps < Self.maxAdvanceSteps {
            steps += 1
            let occurrence = activeWindowOccurrence(at: cursor, in: schedule)
            let weekdayInForce = occurrence?.weekday ?? weekday(at: cursor)

            if occurrence == nil || !effectiveActiveDays(schedule).contains(weekdayInForce) {
                guard let next = nextActiveWindowStart(after: cursor, in: schedule) else {
                    return nil
                }
                cursor = next
                continue
            }

            if let quiet = activeQuietWindow(at: cursor, in: schedule) {
                cursor = quiet.resumesAt > cursor
                    ? quiet.resumesAt
                    : cursor.addingTimeInterval(60)
                continue
            }

            return cursor
        }
        return nil
    }

    /// The wall-clock cadence for `.clockTime`.
    ///
    /// Slots are `activeWindowStart + n × interval` **measured in wall-clock
    /// minutes**, resolved against each day. Measuring in wall-clock minutes
    /// rather than adding seconds is what keeps an "every hour from 07:00"
    /// schedule on the hour across a DST transition instead of sliding to :00
    /// past the wrong hour for the rest of the day.
    func firstAllowedSlot(
        atOrAfter earliest: Date,
        in schedule: PottySchedule,
        after lastPauseEnd: Date?
    ) -> Date? {
        let days = effectiveActiveDays(schedule)
        let startMinute = schedule.activeWindowStart.minutesSinceMidnight
        let rawLength = schedule.activeWindowEnd.minutesSinceMidnight - startMinute
        // Equal bounds mean the whole day, matching `QuietWindow`'s reading.
        let windowLength = rawLength > 0 ? rawLength : rawLength + 1440
        let step = max(1, schedule.interval.minutes)

        // Start one day back: a window that wraps midnight can still be running.
        for dayOffset in -1...Self.searchHorizonDays {
            guard let anchorDay = day(earliest, offsetBy: dayOffset),
                  days.contains(weekday(at: anchorDay))
            else { continue }

            for elapsed in stride(from: 0, to: windowLength, by: step) {
                let total = startMinute + elapsed
                let slotTime = LocalTimeOfDay(minutesSinceMidnight: total % 1440)
                guard let slotDay = day(anchorDay, offsetBy: total / 1440),
                      let slot = calendar.resolving(slotTime, on: slotDay)
                else { continue }

                // A slot inside the spring-forward gap does not exist; Foundation
                // resolves it to the instant after the gap, which is another
                // slot's job. Skipping it keeps the cadence honest instead of
                // firing twice at 03:00.
                guard localTime(at: slot) == slotTime else { continue }

                if slot < earliest { continue }
                if let lastPauseEnd, slot <= lastPauseEnd { continue }
                if isQuiet(at: slot, in: schedule) { continue }
                return slot
            }
        }
        return nil
    }
}

// MARK: - Warning

extension PottyScheduleService {
    /// The heads-up for the next projected pause.
    public func nextWarning(for state: ScheduleState) -> WarningProjection? {
        guard let pause = nextPause(after: state) else { return nil }
        guard let fireAt = warningTime(forPauseAt: pause.start, in: state.schedule) else {
            return nil
        }
        // A warning inside quiet hours is only ever a mistake: the pause itself is
        // outside them, so the warning is the one thing that would reach a
        // sleeping child.
        let suppressedBy = activeQuietWindow(at: fireAt, in: state.schedule)?.window
        return WarningProjection(
            fireAt: fireAt,
            pauseAt: pause.start,
            leadTime: pause.start.timeIntervalSince(fireAt),
            hasElapsed: fireAt <= state.now,
            suppressedBy: suppressedBy
        )
    }

    /// Pure derivation from the pause instant. `nil` when warnings are off.
    ///
    /// Uses `effectiveWarningOffset`, which the model already clamps below the
    /// interval so a warning can never precede the pause before it.
    public func warningTime(forPauseAt pause: Date, in schedule: PottySchedule) -> Date? {
        let offset = schedule.effectiveWarningOffset
        guard offset > 0 else { return nil }
        return pause.addingTimeInterval(-offset)
    }
}
