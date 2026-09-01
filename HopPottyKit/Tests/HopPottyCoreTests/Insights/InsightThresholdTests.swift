import Foundation
import Testing
@testable import HopPottyCore

/// Every insight has a minimum sample size, and every one of them is tested at
/// the exact boundary: one observation short returns `nil`, and the threshold
/// itself returns a value.
///
/// The fixtures are built *from* `InsightThresholds` rather than from
/// hard-coded counts. If someone revises a threshold, these tests keep testing
/// the boundary instead of quietly testing an interior point.
@Suite("Insight sample thresholds")
struct InsightThresholdTests {

    private let calendar = InsightsFixture.calendar
    private let now = InsightsFixture.wednesdayEvening

    // MARK: Typical gap between visits

    @Test("One gap short of the minimum, no range is reported")
    func gapRangeBelowThreshold() {
        let events = InsightsFixture.sameDayGaps(InsightThresholds.minimumGapSamples - 1)
        #expect(InsightsEngine.typicalGap(events: events, window: .week, calendar: calendar, now: now) == nil)
    }

    @Test("At the minimum, a range is reported as a range")
    func gapRangeAtThreshold() throws {
        let events = InsightsFixture.sameDayGaps(InsightThresholds.minimumGapSamples)
        let insight = try #require(
            InsightsEngine.typicalGap(events: events, window: .week, calendar: calendar, now: now)
        )

        #expect(insight.sampleCount == InsightThresholds.minimumGapSamples)
        #expect(insight.confidence.minimumSampleSize == InsightThresholds.minimumGapSamples)
        #expect(insight.confidence.meetsMinimum)
        #expect(insight.confidence.level == .provisional)
        // Gaps cycle 45/50/55, so the middle half of them lands on 45–55.
        #expect(insight.lowerMinutes == 45)
        #expect(insight.upperMinutes == 55)
        #expect(insight.medianMinutes == 50)
        #expect(insight.rangeText == "45–55 minutes")
        #expect(insight.lowerMinutes <= insight.upperMinutes)
    }

    @Test("One wild gap barely moves the reported range")
    func gapRangeResistsAnOutlier() throws {
        let ordinary = InsightsFixture.sameDayGaps(InsightThresholds.minimumGapSamples)
        let baseline = try #require(
            InsightsEngine.typicalGap(events: ordinary, window: .week, calendar: calendar, now: now)
        )

        // A four-hour gap: an afternoon out, a nap, a forgotten log. A mean of
        // twelve fifty-minute gaps would jump by roughly a quarter of an hour.
        let lastEntry = try #require(ordinary.map(\.timestamp).max())
        let withOutlier = ordinary + [InsightsFixture.event(at: lastEntry.addingTimeInterval(240 * 60))]
        let disturbed = try #require(
            InsightsEngine.typicalGap(events: withOutlier, window: .week, calendar: calendar, now: now)
        )

        #expect(disturbed.sampleCount == baseline.sampleCount + 1)
        let step = InsightThresholds.reportingStepMinutes
        #expect(abs(disturbed.lowerMinutes - baseline.lowerMinutes) <= step)
        #expect(abs(disturbed.upperMinutes - baseline.upperMinutes) <= step)
        #expect(abs(disturbed.medianMinutes - baseline.medianMinutes) <= step)
        // The mean of the same numbers would have moved far further, which is
        // the entire reason the range is built from quartiles.
        let disturbedMean = 240.0 / Double(disturbed.sampleCount)
        #expect(disturbedMean > Double(step))
    }

    // MARK: Participation

    @Test("One visit short of the minimum, the period is not summarised")
    func participationBelowThreshold() {
        let events = InsightsFixture.series(
            from: InsightsFixture.date(2025, 3, 12, 8, 0),
            gaps: [60],
            count: InsightThresholds.minimumParticipationVisits - 1
        )
        #expect(InsightsEngine.participation(events: events, window: .day, calendar: calendar, now: now) == nil)
    }

    @Test("At the minimum, participation is counted and compared")
    func participationAtThreshold() throws {
        let events = InsightsFixture.series(
            from: InsightsFixture.date(2025, 3, 12, 8, 0),
            gaps: [60],
            count: InsightThresholds.minimumParticipationVisits
        )
        let insight = try #require(
            InsightsEngine.participation(events: events, window: .day, calendar: calendar, now: now)
        )

        #expect(insight.visitCount == InsightThresholds.minimumParticipationVisits)
        #expect(insight.observedDayCount == 1)
        #expect(insight.previousVisitCount == 0)
        #expect(insight.confidence.minimumSampleSize == InsightThresholds.minimumParticipationVisits)
    }

    @Test("Trying counts exactly as much as producing something")
    func participationCountsTryingEqually() throws {
        let tried = InsightsFixture.series(
            from: InsightsFixture.date(2025, 3, 12, 8, 0),
            gaps: [60],
            count: 4,
            kind: .tried
        )
        let produced = InsightsFixture.series(
            from: InsightsFixture.date(2025, 3, 12, 8, 0),
            gaps: [60],
            count: 4,
            kind: .pee
        )
        let a = try #require(InsightsEngine.participation(events: tried, window: .day, calendar: calendar, now: now))
        let b = try #require(InsightsEngine.participation(events: produced, window: .day, calendar: calendar, now: now))

        #expect(a.visitCount == b.visitCount)
        #expect(a.patternStatement == b.patternStatement)
    }

    // MARK: Time-of-day consistency

    /// Mornings every day, afternoons on the two most recent days only.
    private func consistencyEvents(dayCount: Int) -> [PottyEvent] {
        var events: [PottyEvent] = []
        for offset in 0..<dayCount {
            let day = 12 - offset
            events.append(InsightsFixture.event(at: InsightsFixture.date(2025, 3, day, 8, 0)))
            events.append(InsightsFixture.event(at: InsightsFixture.date(2025, 3, day, 9, 30)))
        }
        for day in [12, 11] {
            events.append(InsightsFixture.event(at: InsightsFixture.date(2025, 3, day, 13, 0)))
            events.append(InsightsFixture.event(at: InsightsFixture.date(2025, 3, day, 14, 30)))
            events.append(InsightsFixture.event(at: InsightsFixture.date(2025, 3, day, 16, 0)))
        }
        return events
    }

    @Test("One logged day short of the minimum, parts of the day are not compared")
    func consistencyBelowThreshold() {
        let events = consistencyEvents(dayCount: InsightThresholds.minimumConsistencyDays - 1)
        let insight = InsightsEngine.timeOfDayConsistency(
            events: events,
            window: .trailingDays(14),
            calendar: calendar,
            now: now
        )
        #expect(insight == nil)
    }

    @Test("At the minimum, parts of the day are compared")
    func consistencyAtThreshold() throws {
        let days = InsightThresholds.minimumConsistencyDays
        let events = consistencyEvents(dayCount: days)
        let insight = try #require(
            InsightsEngine.timeOfDayConsistency(
                events: events,
                window: .trailingDays(14),
                calendar: calendar,
                now: now
            )
        )

        #expect(insight.observedDayCount == days)
        #expect(insight.mostConsistent.segment == .morning)
        #expect(insight.mostConsistent.daysWithVisit == days)
        #expect(insight.leastConsistent.segment == .afternoon)
        #expect(insight.leastConsistent.daysWithVisit == 2)
        #expect(insight.confidence.minimumSampleSize == InsightThresholds.minimumConsistencyDays)
        // Evenings and nights have too few entries to be named at all.
        #expect(insight.segments.count == 2)
    }

    @Test("A part of the day with a couple of stray entries is never named")
    func segmentsBelowTheirOwnMinimumAreIgnored() {
        var events = consistencyEvents(dayCount: InsightThresholds.minimumConsistencyDays)
        // One lone late entry: not enough to describe anyone's evenings.
        events.append(InsightsFixture.event(at: InsightsFixture.date(2025, 3, 12, 19, 30)))

        let insight = InsightsEngine.timeOfDayConsistency(
            events: events,
            window: .trailingDays(14),
            calendar: calendar,
            now: now
        )
        #expect(insight?.segments.contains { $0.segment == .evening } == false)
    }

    @Test("Parts of the day that look alike are not written up as a difference")
    func consistencyNeedsARealDifference() {
        var events: [PottyEvent] = []
        for offset in 0..<6 {
            let day = 12 - offset
            events.append(InsightsFixture.event(at: InsightsFixture.date(2025, 3, day, 8, 0)))
            events.append(InsightsFixture.event(at: InsightsFixture.date(2025, 3, day, 13, 0)))
        }
        let insight = InsightsEngine.timeOfDayConsistency(
            events: events,
            window: .trailingDays(14),
            calendar: calendar,
            now: now
        )
        #expect(insight == nil)
    }

    // MARK: Longest dry stretch

    private func dryStretchEvents(dayCount: Int) -> [PottyEvent] {
        var events: [PottyEvent] = []
        for offset in 0..<dayCount {
            let day = 12 - offset
            events.append(InsightsFixture.event(at: InsightsFixture.date(2025, 3, day, 8, 0)))
            events.append(
                InsightsFixture.event(
                    at: InsightsFixture.date(2025, 3, day, 15, 0),
                    kind: .accident,
                    source: .parentManual
                )
            )
        }
        return events
    }

    @Test("One logged day short of the minimum, no stretch is reported")
    func dryStretchBelowThreshold() {
        let events = dryStretchEvents(dayCount: InsightThresholds.minimumDryStretchDays - 1)
        #expect(
            InsightsEngine.longestDryStretch(
                events: events,
                window: .trailingDays(14),
                calendar: calendar,
                now: now
            ) == nil
        )
    }

    @Test("At the minimum, the longest stretch is reported as an observation")
    func dryStretchAtThreshold() throws {
        let days = InsightThresholds.minimumDryStretchDays
        let events = dryStretchEvents(dayCount: days)
        let insight = try #require(
            InsightsEngine.longestDryStretch(
                events: events,
                window: .trailingDays(14),
                calendar: calendar,
                now: now
            )
        )

        // Accidents were recorded at 15:00 on consecutive days, so the longest
        // span with none between them is the twenty-four hours from one to the
        // next.
        #expect(insight.duration == TimeInterval(24 * 3600))
        #expect(insight.durationText == "1 day")
        #expect(insight.accidentCount == days)
        #expect(insight.observedDayCount == days)
        #expect(insight.confidence.minimumSampleSize == InsightThresholds.minimumDryStretchDays)
    }

    @Test("A later entry can only lengthen a stretch already reported")
    func dryStretchNeverShrinksAsEntriesArrive() throws {
        let events = dryStretchEvents(dayCount: InsightThresholds.minimumDryStretchDays)
        let before = try #require(
            InsightsEngine.longestDryStretch(events: events, window: .trailingDays(14), calendar: calendar, now: now)
        )

        // The day goes on and nothing further is recorded until the evening.
        let later = events + [InsightsFixture.event(at: InsightsFixture.date(2025, 3, 12, 23, 0))]
        let after = try #require(
            InsightsEngine.longestDryStretch(events: later, window: .trailingDays(14), calendar: calendar, now: now)
        )

        #expect(after.duration >= before.duration)
        // Nothing here is a live counter: the value is bounded by recorded
        // entries, so it does not move on its own and cannot be lost.
        #expect(after.end <= (later.map(\.timestamp).max() ?? after.end))
    }
}
