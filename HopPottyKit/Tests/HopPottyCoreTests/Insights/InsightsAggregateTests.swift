import Foundation
import Testing
@testable import HopPottyCore

@Suite("Insight windows and aggregates")
struct InsightsAggregateTests {

    private let calendar = InsightsFixture.calendar
    private let now = InsightsFixture.wednesdayEvening

    // MARK: Day and week boundaries

    @Test("A day window is half-open at local midnight")
    func dayBoundary() {
        let window = InsightWindow.day.interval(containing: now, calendar: calendar)

        #expect(window.start == InsightsFixture.date(2025, 3, 12, 0, 0))
        #expect(window.end == InsightsFixture.date(2025, 3, 13, 0, 0))
        #expect(window.contains(InsightsFixture.date(2025, 3, 12, 0, 0)))
        #expect(window.contains(InsightsFixture.date(2025, 3, 12, 23, 59)))
        // The instant midnight belongs to the next day and only the next day.
        #expect(!window.contains(InsightsFixture.date(2025, 3, 13, 0, 0)))
        #expect(!window.contains(InsightsFixture.date(2025, 3, 11, 23, 59)))
    }

    @Test("A week window starts on the calendar's first weekday")
    func weekBoundaryHonoursCalendar() {
        let sundayFirst = InsightWindow.week.interval(containing: now, calendar: calendar)
        #expect(sundayFirst.start == InsightsFixture.date(2025, 3, 9, 0, 0))
        #expect(sundayFirst.end == InsightsFixture.date(2025, 3, 16, 0, 0))

        // Same instant, Monday-first calendar: a different week entirely.
        let mondayCalendar = InsightsFixture.mondayFirstCalendar
        let mondayFirst = InsightWindow.week.interval(containing: now, calendar: mondayCalendar)
        #expect(mondayFirst.start == InsightsFixture.date(2025, 3, 10, 0, 0))
        #expect(mondayFirst.end == InsightsFixture.date(2025, 3, 17, 0, 0))
    }

    @Test("The previous week abuts this one and keeps local midnight across a DST change")
    func previousWeekAcrossDaylightSaving() {
        let window = InsightWindow.week.interval(containing: now, calendar: calendar)
        let previous = window.previous(calendar: calendar)

        #expect(previous.end == window.start)
        #expect(previous.start == InsightsFixture.date(2025, 3, 2, 0, 0))
        // The clocks went forward inside this week, so it is 167 hours long and
        // still exactly seven day rows.
        #expect(window.duration == 167 * 3600)
        #expect(window.dayCount(calendar: calendar) == 7)
    }

    @Test("A trailing window ends with the day containing now")
    func trailingDays() {
        let window = InsightWindow.trailingDays(3).interval(containing: now, calendar: calendar)
        #expect(window.start == InsightsFixture.date(2025, 3, 10, 0, 0))
        #expect(window.end == InsightsFixture.date(2025, 3, 13, 0, 0))
        #expect(window.dayCount(calendar: calendar) == 3)
    }

    // MARK: Counts

    @Test("Counts by kind, per day and per weekday")
    func aggregateCounts() {
        let events = [
            InsightsFixture.event(at: InsightsFixture.date(2025, 3, 9, 8, 0)),
            InsightsFixture.event(at: InsightsFixture.date(2025, 3, 9, 8, 2), kind: .pee),
            InsightsFixture.event(at: InsightsFixture.date(2025, 3, 10, 9, 0), kind: .pee),
            InsightsFixture.event(at: InsightsFixture.date(2025, 3, 10, 14, 0), kind: .accident, source: .parentManual),
            InsightsFixture.event(at: InsightsFixture.date(2025, 3, 12, 7, 30), kind: .poop),
        ]
        let window = InsightWindow.week.interval(containing: now, calendar: calendar)
        let aggregate = InsightsEngine.aggregate(events: events, in: window, calendar: calendar)

        #expect(aggregate.count(of: .tried) == 1)
        #expect(aggregate.count(of: .pee) == 2)
        #expect(aggregate.count(of: .poop) == 1)
        #expect(aggregate.count(of: .accident) == 1)
        #expect(aggregate.participationCount == 4)
        #expect(aggregate.accidentCount == 1)
        #expect(aggregate.recordedCount == 5)

        // Seven rows including the days nobody logged, so a chart never has to
        // tell "zero" from "missing".
        #expect(aggregate.dayCount == 7)
        #expect(aggregate.dayTotals.count == 7)
        #expect(aggregate.observedDayCount == 3)
        #expect(aggregate.dayTotals.map(\.recordedCount) == [2, 2, 0, 1, 0, 0, 0])
        #expect(aggregate.dayTotals.first?.weekday == .sunday)

        #expect(aggregate.participationByWeekday[.sunday] == 2)
        #expect(aggregate.participationByWeekday[.monday] == 1)
        #expect(aggregate.participationByWeekday[.wednesday] == 1)
        #expect(aggregate.participationByWeekday[.friday] == 0)
        // Every weekday occurs once in a seven-day window.
        #expect(aggregate.daysByWeekday.values.allSatisfy { $0 == 1 })
    }

    @Test("An accident is a count on the timeline and nothing else")
    func accidentsAreNeverAScore() {
        let events = [
            InsightsFixture.event(at: InsightsFixture.date(2025, 3, 12, 9, 0)),
            InsightsFixture.event(at: InsightsFixture.date(2025, 3, 12, 12, 0), kind: .accident, source: .parentManual),
        ]
        let window = InsightWindow.day.interval(containing: now, calendar: calendar)
        let aggregate = InsightsEngine.aggregate(events: events, in: window, calendar: calendar)

        // Participation counts taking part. An accident is not a participation
        // event and can never reduce one, so no ratio between them exists.
        #expect(aggregate.participationCount == 1)
        #expect(aggregate.accidentCount == 1)
        #expect(aggregate.dayTotals.first?.participationCount == 1)
        #expect(PottyEventKind.accident.countsAsParticipation == false)
    }

    @Test("Entries minutes apart describe one visit")
    func entriesAreClusteredIntoVisits() {
        let events = [
            InsightsFixture.event(at: InsightsFixture.date(2025, 3, 12, 9, 0)),
            InsightsFixture.event(at: InsightsFixture.date(2025, 3, 12, 9, 1), kind: .pee),
            InsightsFixture.event(at: InsightsFixture.date(2025, 3, 12, 9, 3), kind: .poop),
            InsightsFixture.event(at: InsightsFixture.date(2025, 3, 12, 11, 0)),
        ]
        let insight = InsightsEngine.participation(events: events, window: .day, calendar: calendar, now: now)

        #expect(insight?.visitCount == 2)
        #expect(insight?.eventCount == 4)
    }

    @Test("This period is compared with the one before it")
    func periodComparison() {
        var events = InsightsFixture.series(from: InsightsFixture.date(2025, 3, 10, 8, 0), gaps: [60], count: 4)
        events += InsightsFixture.series(from: InsightsFixture.date(2025, 3, 3, 8, 0), gaps: [60], count: 2)

        let comparison = InsightsEngine.comparison(events: events, window: .week, calendar: calendar, now: now)
        #expect(comparison.current.participationCount == 4)
        #expect(comparison.previous.participationCount == 2)
        #expect(comparison.participationDifference == 2)
        #expect(comparison.participationDirection == .higher)
        #expect(comparison.difference(of: .accident) == 0)
    }

    // MARK: Awkward input

    @Test("Empty input yields no insights and no claims")
    func emptyInput() {
        let report = InsightsEngine.report(
            events: [],
            window: .week,
            currentInterval: .minutes60,
            calendar: calendar,
            now: now
        )

        #expect(report.participation == nil)
        #expect(report.typicalGap == nil)
        #expect(report.timeOfDayConsistency == nil)
        #expect(report.longestDryStretch == nil)
        #expect(report.intervalSuggestion == nil)
        #expect(report.hasAnyInsight == false)
        #expect(report.current.observedDayCount == 0)
        #expect(report.current.recordedCount == 0)
        // The label travels even when there is nothing else to say.
        #expect(report.disclaimerRequired)
        #expect(report.allGeneratedStrings == [InsightConfidence.disclaimer])
    }

    @Test("A single event is a count, never a pattern")
    func singleEvent() {
        let report = InsightsEngine.report(
            events: [InsightsFixture.event(at: InsightsFixture.date(2025, 3, 12, 9, 0))],
            window: .week,
            currentInterval: .minutes60,
            calendar: calendar,
            now: now
        )

        #expect(report.current.participationCount == 1)
        #expect(report.hasAnyInsight == false)
        #expect(report.typicalGap == nil)
        #expect(report.participation == nil)
    }

    @Test("A timeline of nothing but accidents still refuses to score anyone")
    func allAccidents() {
        var events: [PottyEvent] = []
        for day in 10...12 {
            events.append(InsightsFixture.event(at: InsightsFixture.date(2025, 3, day, 10, 0), kind: .accident, source: .parentManual))
            events.append(InsightsFixture.event(at: InsightsFixture.date(2025, 3, day, 16, 0), kind: .accident, source: .parentManual))
        }
        let report = InsightsEngine.report(
            events: events,
            window: .week,
            currentInterval: .minutes60,
            calendar: calendar,
            now: now
        )

        #expect(report.participation == nil)
        #expect(report.typicalGap == nil)
        #expect(report.timeOfDayConsistency == nil)
        #expect(report.intervalSuggestion == nil)
        #expect(report.current.accidentCount == 6)
        #expect(report.current.participationCount == 0)

        // The one thing that can be said is the neutral one: the longest span
        // with nothing recorded, 16:00 to 10:00 the next morning.
        let dry = try? #require(report.longestDryStretch)
        #expect(dry?.duration == 18 * 3600)
        #expect(dry?.accidentCount == 6)
    }

    @Test("Events out of chronological order produce the same report")
    func outOfOrderInput() {
        let ordered = InsightsFixture.sameDayGaps(InsightThresholds.minimumGapSamples)
            + [InsightsFixture.event(at: InsightsFixture.date(2025, 3, 11, 19, 0), kind: .accident, source: .parentManual)]
        let reversed = Array(ordered.reversed())
        let rotated = Array(ordered.dropFirst(3)) + Array(ordered.prefix(3))

        let a = InsightsEngine.report(events: ordered, window: .week, currentInterval: .minutes60, calendar: calendar, now: now)
        let b = InsightsEngine.report(events: reversed, window: .week, currentInterval: .minutes60, calendar: calendar, now: now)
        let c = InsightsEngine.report(events: rotated, window: .week, currentInterval: .minutes60, calendar: calendar, now: now)

        #expect(a == b)
        #expect(a == c)
    }

    @Test("The same input yields an identical report every run")
    func determinism() {
        let events = InsightsFixture.sameDayGaps(InsightThresholds.minimumSuggestionGapSamples)
        var reports: [InsightsReport] = []
        for _ in 0..<25 {
            reports.append(
                InsightsEngine.report(
                    events: events.shuffled(),
                    window: .week,
                    currentInterval: .minutes90,
                    calendar: calendar,
                    now: now
                )
            )
        }
        #expect(Set(reports).count == 1)
        #expect(reports.allSatisfy { $0 == reports[0] })
        #expect(reports.allSatisfy { $0.allGeneratedStrings == reports[0].allGeneratedStrings })
    }

    @Test("The same event recorded twice is counted once")
    func duplicateEventsAreDeduplicated() {
        let events = InsightsFixture.sameDayGaps(InsightThresholds.minimumGapSamples)
        let once = InsightsEngine.report(events: events, window: .week, calendar: calendar, now: now)
        let twice = InsightsEngine.report(events: events + events, window: .week, calendar: calendar, now: now)
        #expect(once == twice)
    }

    @Test("Another child's entries never reach this child's insights")
    func childFiltering() {
        let mine = InsightsFixture.series(from: InsightsFixture.date(2025, 3, 12, 8, 0), gaps: [60], count: 3)
        let sibling = InsightsFixture.series(
            from: InsightsFixture.date(2025, 3, 12, 8, 30),
            gaps: [60],
            count: 5,
            childID: InsightsFixture.siblingID
        )
        let insight = InsightsEngine.participation(
            events: mine + sibling,
            childID: InsightsFixture.childID,
            window: .day,
            calendar: calendar,
            now: now
        )
        #expect(insight?.visitCount == 3)
    }

    @Test("Gaps are measured within a day, never across a night")
    func gapsDoNotCrossMidnight() {
        // Eight visits an hour apart each evening, three evenings running: any
        // overnight span would be an eleven-hour gap and would drag the range.
        var events: [PottyEvent] = []
        for day in 10...12 {
            events += InsightsFixture.series(from: InsightsFixture.date(2025, 3, day, 14, 0), gaps: [60], count: 6)
        }
        let insight = InsightsEngine.typicalGap(events: events, window: .week, calendar: calendar, now: now)
        #expect(insight?.sampleCount == 15)
        #expect(insight?.lowerMinutes == 60)
        #expect(insight?.upperMinutes == 60)
    }

    @Test("Restored entries count as taking part but not as timings")
    func restoredEntriesAreExcludedFromGapTiming() {
        let events = InsightsFixture.sameDayGaps(InsightThresholds.minimumGapSamples, source: .restored)
        #expect(InsightsEngine.typicalGap(events: events, window: .week, calendar: calendar, now: now) == nil)

        let participation = InsightsEngine.participation(events: events, window: .week, calendar: calendar, now: now)
        // Every entry here is more than five minutes from its neighbours, so
        // each one is its own visit.
        #expect(participation?.visitCount == events.count)
    }
}
