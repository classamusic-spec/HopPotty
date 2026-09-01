import Foundation

/// Descriptive statistics over a family's potty timeline.
///
/// Everything here is a pure function of its arguments. There is no stored
/// state, no `init`, no singleton and no call to `Date()` — the caller supplies
/// `now` and the `Calendar`, which is what lets a test pin a day boundary to a
/// specific time zone and get the same answer every run.
///
/// What this engine will not do, by construction:
///
/// - It never decides anything. Every entry point returns a value; nothing here
///   writes a schedule, a setting or an event.
/// - It never divides an accident count by anything. There is no success rate
///   in this file and no way to derive one from what it returns without
///   deliberately building it elsewhere.
/// - It never claims a pattern it cannot support. Each insight has a minimum
///   sample size in `InsightThresholds` and returns `nil` under it.
public enum InsightsEngine {

    /// Sources whose timestamps are trusted for interval statistics.
    ///
    /// `restored` is excluded on the strength of `PottyEventSource`'s own note:
    /// an import or migration may carry approximate times, and a coarse
    /// timestamp would quietly widen or shift a reported range. Restored
    /// entries still count fully towards participation, which is about whether
    /// a child took part rather than exactly when.
    public static let gapEligibleSources: Set<PottyEventSource> = [
        .childRoutine, .parentManual, .pauseCompletion,
    ]

    // MARK: - Normalisation

    /// Sorts, de-duplicates and optionally filters to one child.
    ///
    /// Callers hand over whatever the store gave them: unsorted, possibly
    /// containing the same event twice after a merge, possibly covering the
    /// whole family. Sorting by timestamp *and then by id* matters — two events
    /// at the same instant would otherwise come back in whatever order the
    /// array happened to be in, and every number downstream would depend on it.
    static func prepared(_ events: [PottyEvent], childID: UUID?) -> [PottyEvent] {
        var seen = Set<UUID>()
        let scoped = events.filter { event in
            guard childID == nil || event.childID == childID else { return false }
            return seen.insert(event.id).inserted
        }
        return scoped.sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// One trip to the bathroom, however many entries describe it.
    struct Visit: Hashable, Sendable {
        let time: Date
        let eventCount: Int
    }

    /// Collapses entries within `visitClusterWindow` of each other into one
    /// visit, so a child tapping "tried" and then "pee" is one trip and not two.
    static func visits(from events: [PottyEvent]) -> [Visit] {
        var result: [Visit] = []
        var clusterStart: Date?
        var clusterLast: Date?
        var clusterCount = 0

        for event in events {
            if let last = clusterLast,
               event.timestamp.timeIntervalSince(last) <= InsightThresholds.visitClusterWindow {
                clusterLast = event.timestamp
                clusterCount += 1
                continue
            }
            if let start = clusterStart {
                result.append(Visit(time: start, eventCount: clusterCount))
            }
            clusterStart = event.timestamp
            clusterLast = event.timestamp
            clusterCount = 1
        }
        if let start = clusterStart {
            result.append(Visit(time: start, eventCount: clusterCount))
        }
        return result
    }

    static func participationEvents(_ events: [PottyEvent], in window: DateWindow) -> [PottyEvent] {
        events.filter { window.contains($0.timestamp) && $0.kind.countsAsParticipation }
    }

    // MARK: - Aggregates

    /// Counts by kind, per local day and per weekday, for one window.
    public static func aggregate(
        events: [PottyEvent],
        childID: UUID? = nil,
        in window: DateWindow,
        calendar: Calendar
    ) -> PeriodAggregate {
        let scoped = prepared(events, childID: childID).filter { window.contains($0.timestamp) }

        var countsByKind: [PottyEventKind: Int] = [:]
        var countsByDay: [Date: [PottyEventKind: Int]] = [:]
        for event in scoped {
            countsByKind[event.kind, default: 0] += 1
            let day = calendar.startOfDay(for: event.timestamp)
            countsByDay[day, default: [:]][event.kind, default: 0] += 1
        }

        // Walk the window a calendar day at a time rather than adding 86,400
        // seconds, so a daylight-saving day is still one row.
        var dayTotals: [DayTotal] = []
        var participationByWeekday: [Weekday: Int] = [:]
        var daysByWeekday: [Weekday: Int] = [:]
        var cursor = calendar.startOfDay(for: window.start)
        while cursor < window.end {
            let weekday = Weekday(date: cursor, calendar: calendar) ?? .sunday
            let total = DayTotal(
                dayStart: cursor,
                weekday: weekday,
                countsByKind: countsByDay[cursor] ?? [:]
            )
            dayTotals.append(total)
            participationByWeekday[weekday, default: 0] += total.participationCount
            daysByWeekday[weekday, default: 0] += 1

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }

        return PeriodAggregate(
            window: window,
            dayTotals: dayTotals,
            countsByKind: countsByKind,
            participationByWeekday: participationByWeekday,
            daysByWeekday: daysByWeekday
        )
    }

    /// This period beside the one immediately before it.
    public static func comparison(
        events: [PottyEvent],
        childID: UUID? = nil,
        window: InsightWindow,
        calendar: Calendar,
        now: Date
    ) -> PeriodComparison {
        let current = window.interval(containing: now, calendar: calendar)
        let previous = current.previous(calendar: calendar)
        return PeriodComparison(
            current: aggregate(events: events, childID: childID, in: current, calendar: calendar),
            previous: aggregate(events: events, childID: childID, in: previous, calendar: calendar)
        )
    }

    // MARK: - Gaps between visits

    /// Minutes between consecutive visits on the same local day.
    ///
    /// Same-day only: the span from the last entry one evening to the first the
    /// next morning is a night's sleep, and including it would make the middle
    /// of the distribution meaningless.
    static func sameDayGapMinutes(
        events: [PottyEvent],
        in window: DateWindow,
        calendar: Calendar
    ) -> [Double] {
        let eligible = participationEvents(events, in: window)
            .filter { gapEligibleSources.contains($0.source) }
        let visitTimes = visits(from: eligible).map(\.time)

        var byDay: [Date: [Date]] = [:]
        for time in visitTimes {
            byDay[calendar.startOfDay(for: time), default: []].append(time)
        }

        var gaps: [Double] = []
        // Days in ascending order so the returned array is stable, which keeps
        // the sorted copy inside the quantile identical run to run.
        for day in byDay.keys.sorted() {
            let times = (byDay[day] ?? []).sorted()
            for index in 1..<max(times.count, 1) where times.count > 1 {
                let minutes = times[index].timeIntervalSince(times[index - 1]) / 60
                if minutes > 0 { gaps.append(minutes) }
            }
        }
        return gaps
    }

    /// How far apart recorded visits have been, as the middle 50% of observed
    /// gaps. `nil` below `InsightThresholds.minimumGapSamples`.
    public static func typicalGap(
        events: [PottyEvent],
        childID: UUID? = nil,
        window: InsightWindow = .week,
        calendar: Calendar,
        now: Date
    ) -> TypicalGapInsight? {
        let scoped = prepared(events, childID: childID)
        let period = window.interval(containing: now, calendar: calendar)
        let gaps = sameDayGapMinutes(events: scoped, in: period, calendar: calendar)

        guard gaps.count >= InsightThresholds.minimumGapSamples,
              let range = RobustStatistics.interquartileRange(of: gaps),
              let middle = RobustStatistics.median(of: gaps)
        else { return nil }

        let step = InsightThresholds.reportingStepMinutes
        let lower = RobustStatistics.floored(range.low, toStep: step)
        let upper = max(lower, RobustStatistics.ceiled(range.high, toStep: step))

        return TypicalGapInsight(
            lowerMinutes: lower,
            upperMinutes: upper,
            medianMinutes: RobustStatistics.rounded(middle, toStep: step),
            sampleCount: gaps.count,
            confidence: InsightConfidence(
                sampleSize: gaps.count,
                minimumSampleSize: InsightThresholds.minimumGapSamples,
                observedDays: aggregate(events: scoped, in: period, calendar: calendar).observedDayCount
            )
        )
    }

    // MARK: - Participation

    /// Visits recorded this period, beside the period before. `nil` below
    /// `InsightThresholds.minimumParticipationVisits`.
    public static func participation(
        events: [PottyEvent],
        childID: UUID? = nil,
        window: InsightWindow = .week,
        calendar: Calendar,
        now: Date
    ) -> ParticipationInsight? {
        let scoped = prepared(events, childID: childID)
        let period = window.interval(containing: now, calendar: calendar)
        let previousPeriod = period.previous(calendar: calendar)

        let current = participationEvents(scoped, in: period)
        let currentVisits = visits(from: current)
        guard currentVisits.count >= InsightThresholds.minimumParticipationVisits else { return nil }

        let previousVisits = visits(from: participationEvents(scoped, in: previousPeriod))
        let observedDays = aggregate(events: scoped, in: period, calendar: calendar).observedDayCount

        return ParticipationInsight(
            visitCount: currentVisits.count,
            eventCount: current.count,
            previousVisitCount: previousVisits.count,
            observedDayCount: observedDays,
            confidence: InsightConfidence(
                sampleSize: currentVisits.count,
                minimumSampleSize: InsightThresholds.minimumParticipationVisits,
                observedDays: observedDays
            )
        )
    }

    // MARK: - Time of day

    /// Which parts of the day have had entries most often, day to day.
    ///
    /// `nil` unless there are at least `minimumConsistencyDays` days with
    /// entries, at least two parts of the day carrying
    /// `minimumSegmentVisits` visits each, and a difference between the top and
    /// bottom of at least `minimumConsistencyRateDifference`. The last of those
    /// is the one that keeps an ordering that flips on a single day's data from
    /// being written up as a pattern.
    public static func timeOfDayConsistency(
        events: [PottyEvent],
        childID: UUID? = nil,
        window: InsightWindow = .week,
        calendar: Calendar,
        now: Date
    ) -> TimeOfDayConsistencyInsight? {
        let scoped = prepared(events, childID: childID)
        let period = window.interval(containing: now, calendar: calendar)
        let observedDays = aggregate(events: scoped, in: period, calendar: calendar).observedDayCount
        guard observedDays >= InsightThresholds.minimumConsistencyDays else { return nil }

        let periodVisits = visits(from: participationEvents(scoped, in: period))

        var daysBySegment: [DaySegment: Set<Date>] = [:]
        var countBySegment: [DaySegment: Int] = [:]
        for visit in periodVisits {
            let segment = DaySegment.containing(visit.time, calendar: calendar)
            daysBySegment[segment, default: []].insert(calendar.startOfDay(for: visit.time))
            countBySegment[segment, default: 0] += 1
        }

        let eligible = DaySegment.allCases
            .map { segment in
                SegmentConsistency(
                    segment: segment,
                    daysWithVisit: daysBySegment[segment]?.count ?? 0,
                    observedDays: observedDays,
                    visitCount: countBySegment[segment] ?? 0
                )
            }
            .filter { $0.visitCount >= InsightThresholds.minimumSegmentVisits }
            .sorted { lhs, rhs in
                if lhs.rate != rhs.rate { return lhs.rate > rhs.rate }
                return lhs.segment.sortOrder < rhs.segment.sortOrder
            }

        guard eligible.count >= 2,
              let most = eligible.first,
              let least = eligible.last,
              most.rate - least.rate >= InsightThresholds.minimumConsistencyRateDifference
        else { return nil }

        return TimeOfDayConsistencyInsight(
            segments: eligible,
            mostConsistent: most,
            leastConsistent: least,
            observedDayCount: observedDays,
            confidence: InsightConfidence(
                sampleSize: observedDays,
                minimumSampleSize: InsightThresholds.minimumConsistencyDays,
                observedDays: observedDays
            )
        )
    }

    // MARK: - Longest dry stretch

    /// The longest span in the period with no accident recorded.
    ///
    /// Bounded by the first and last entries in the period, never by `now`, so
    /// the number does not climb while a parent looks at it and there is
    /// nothing live to lose. `nil` below `minimumDryStretchDays` days with
    /// entries.
    public static func longestDryStretch(
        events: [PottyEvent],
        childID: UUID? = nil,
        window: InsightWindow = .week,
        calendar: Calendar,
        now: Date
    ) -> DryStretchInsight? {
        let scoped = prepared(events, childID: childID)
        let period = window.interval(containing: now, calendar: calendar)
        let inPeriod = scoped.filter { period.contains($0.timestamp) }
        let summary = aggregate(events: scoped, in: period, calendar: calendar)

        guard summary.observedDayCount >= InsightThresholds.minimumDryStretchDays,
              let first = inPeriod.first?.timestamp,
              let last = inPeriod.last?.timestamp
        else { return nil }

        // Boundaries: the edges of what was recorded, plus each accident.
        let accidentTimes = inPeriod.filter { $0.kind == .accident }.map(\.timestamp)
        var marks = [first] + accidentTimes + [last]
        marks.sort()

        var bestStart = first
        var bestEnd = first
        var best: TimeInterval = 0
        for index in 1..<max(marks.count, 1) where marks.count > 1 {
            let span = marks[index].timeIntervalSince(marks[index - 1])
            // Strictly greater keeps the earliest of equal-length stretches, so
            // the same timeline always reports the same one.
            if span > best {
                best = span
                bestStart = marks[index - 1]
                bestEnd = marks[index]
            }
        }

        guard best > 0 else { return nil }

        return DryStretchInsight(
            duration: best,
            start: bestStart,
            end: bestEnd,
            accidentCount: accidentTimes.count,
            observedDayCount: summary.observedDayCount,
            confidence: InsightConfidence(
                sampleSize: summary.observedDayCount,
                minimumSampleSize: InsightThresholds.minimumDryStretchDays,
                observedDays: summary.observedDayCount
            )
        )
    }

    // MARK: - Interval question

    /// A question about the pause interval, or `nil` when there is no question
    /// worth asking.
    ///
    /// Returns a value and nothing else. Applying it takes a caregiver
    /// answering "yes" and the app writing its own schedule; there is no path
    /// from here to a settings change.
    public static func intervalSuggestion(
        events: [PottyEvent],
        childID: UUID? = nil,
        currentInterval: PottyInterval,
        window: InsightWindow = .week,
        calendar: Calendar,
        now: Date
    ) -> IntervalSuggestion? {
        let scoped = prepared(events, childID: childID)
        let period = window.interval(containing: now, calendar: calendar)
        let gaps = sameDayGapMinutes(events: scoped, in: period, calendar: calendar)

        guard gaps.count >= InsightThresholds.minimumSuggestionGapSamples,
              let middle = RobustStatistics.median(of: gaps),
              let range = RobustStatistics.interquartileRange(of: gaps)
        else { return nil }

        let step = InsightThresholds.reportingStepMinutes
        let observedMedian = RobustStatistics.rounded(middle, toStep: step)
        let bounds = PottyInterval.customRange
        let proposed = min(max(observedMedian, bounds.lowerBound), bounds.upperBound)
        let current = currentInterval.minutes

        guard abs(proposed - current) >= InsightThresholds.minimumSuggestionDeltaMinutes else { return nil }

        let lower = RobustStatistics.floored(range.low, toStep: step)
        let upper = max(lower, RobustStatistics.ceiled(range.high, toStep: step))

        return IntervalSuggestion(
            currentMinutes: current,
            suggestedMinutes: proposed,
            observedMedianMinutes: observedMedian,
            observedRangeMinutes: lower...upper,
            sampleCount: gaps.count,
            confidence: InsightConfidence(
                sampleSize: gaps.count,
                minimumSampleSize: InsightThresholds.minimumSuggestionGapSamples,
                observedDays: aggregate(events: scoped, in: period, calendar: calendar).observedDayCount
            )
        )
    }

    // MARK: - Report

    /// Everything the parent dashboard needs for one period, in one value.
    public static func report(
        events: [PottyEvent],
        childID: UUID? = nil,
        window: InsightWindow = .week,
        currentInterval: PottyInterval? = nil,
        calendar: Calendar,
        now: Date
    ) -> InsightsReport {
        let scoped = prepared(events, childID: childID)
        let period = window.interval(containing: now, calendar: calendar)

        return InsightsReport(
            window: window,
            period: period,
            previousPeriod: period.previous(calendar: calendar),
            comparison: comparison(events: scoped, window: window, calendar: calendar, now: now),
            participation: participation(events: scoped, window: window, calendar: calendar, now: now),
            typicalGap: typicalGap(events: scoped, window: window, calendar: calendar, now: now),
            timeOfDayConsistency: timeOfDayConsistency(events: scoped, window: window, calendar: calendar, now: now),
            longestDryStretch: longestDryStretch(events: scoped, window: window, calendar: calendar, now: now),
            intervalSuggestion: currentInterval.flatMap {
                intervalSuggestion(
                    events: scoped,
                    currentInterval: $0,
                    window: window,
                    calendar: calendar,
                    now: now
                )
            }
        )
    }

    /// Every fixed string this module can put on a screen, whatever the data.
    ///
    /// The data-dependent sentences are reachable through
    /// `InsightsReport.allGeneratedStrings`; between the two, the language test
    /// covers the module's complete output surface.
    public static let allStaticStrings: [String] =
        [InsightConfidence.disclaimer, InsightLanguagePolicy.neutralFallback]
        + InsightConfidence.Level.allCases.map(\.label)
        + DaySegment.allCases.map(\.pluralLabel)
        + DaySegment.allCases.map(\.pluralLabelLowercased)
        + [
            InsightPhrasing.participationDetail(),
            InsightPhrasing.timeOfDayDetail(),
            InsightPhrasing.dryStretchDetail(),
        ]
}
