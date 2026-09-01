import Foundation
import Testing
@testable import HopPottyCore

/// The interval question is the only place the engine addresses the parent
/// directly, so it gets its own suite: it must ask, never act, and never appear
/// on thin data.
@Suite("Interval suggestion")
struct IntervalSuggestionTests {

    private let calendar = InsightsFixture.calendar
    private let now = InsightsFixture.wednesdayEvening

    @Test("One gap short of the minimum, no question is raised")
    func belowThreshold() {
        let events = InsightsFixture.sameDayGaps(InsightThresholds.minimumSuggestionGapSamples - 1)
        let suggestion = InsightsEngine.intervalSuggestion(
            events: events,
            currentInterval: .minutes90,
            window: .trailingDays(14),
            calendar: calendar,
            now: now
        )
        #expect(suggestion == nil)
    }

    @Test("The question needs more data than the pattern it rests on")
    func suggestionThresholdExceedsGapThreshold() {
        #expect(InsightThresholds.minimumSuggestionGapSamples > InsightThresholds.minimumGapSamples)

        // Enough for the pattern, not enough to ask the family to change anything.
        let events = InsightsFixture.sameDayGaps(InsightThresholds.minimumGapSamples)
        #expect(InsightsEngine.typicalGap(events: events, window: .week, calendar: calendar, now: now) != nil)
        #expect(
            InsightsEngine.intervalSuggestion(
                events: events,
                currentInterval: .minutes90,
                window: .week,
                calendar: calendar,
                now: now
            ) == nil
        )
    }

    @Test("At the minimum, the parent is asked a question")
    func atThreshold() throws {
        let events = InsightsFixture.sameDayGaps(InsightThresholds.minimumSuggestionGapSamples)
        let suggestion = try #require(
            InsightsEngine.intervalSuggestion(
                events: events,
                currentInterval: .minutes90,
                window: .trailingDays(14),
                calendar: calendar,
                now: now
            )
        )

        #expect(suggestion.sampleCount == InsightThresholds.minimumSuggestionGapSamples)
        #expect(suggestion.currentMinutes == 90)
        #expect(suggestion.suggestedMinutes == 50)
        #expect(suggestion.observedMedianMinutes == 50)
        #expect(suggestion.observedRangeMinutes == 45...55)
        #expect(suggestion.direction == .lower)
        #expect(suggestion.question == "Would you like to change the pause interval from 90 minutes to 50 minutes?")
        #expect(suggestion.question.hasSuffix("?"))
        #expect(suggestion.disclaimerRequired)
    }

    @Test("A difference too small to matter is not raised at all")
    func differenceBelowTheMinimumIsNotWorthAsking() {
        let events = InsightsFixture.sameDayGaps(InsightThresholds.minimumSuggestionGapSamples)
        // The observed middle is 50 minutes; a schedule already set to 45 is
        // inside the noise of when a caregiver happened to tap.
        let suggestion = InsightsEngine.intervalSuggestion(
            events: events,
            currentInterval: .minutes45,
            window: .trailingDays(14),
            calendar: calendar,
            now: now
        )
        #expect(suggestion == nil)
    }

    @Test("A suggestion stays inside the schedule's own guard rails")
    func suggestionRespectsIntervalBounds() throws {
        // Visits six minutes apart: past the floor a schedule allows.
        let events = InsightsFixture.sameDayGaps(
            InsightThresholds.minimumSuggestionGapSamples,
            gaps: [6]
        )
        let suggestion = try #require(
            InsightsEngine.intervalSuggestion(
                events: events,
                currentInterval: .minutes60,
                window: .trailingDays(14),
                calendar: calendar,
                now: now
            )
        )

        #expect(suggestion.suggestedMinutes == PottyInterval.customRange.lowerBound)
        #expect(PottyInterval.customRange.contains(suggestion.suggestedMinutes))
        #expect(suggestion.suggestedInterval.minutes == suggestion.suggestedMinutes)
    }

    @Test("A suggestion is a value: reading it changes nothing")
    func suggestionIsInert() throws {
        let schedule = PottySchedule(childID: InsightsFixture.childID, interval: .minutes90)
        let events = InsightsFixture.sameDayGaps(InsightThresholds.minimumSuggestionGapSamples)

        let suggestion = try #require(
            InsightsEngine.intervalSuggestion(
                events: events,
                currentInterval: schedule.interval,
                window: .trailingDays(14),
                calendar: calendar,
                now: now
            )
        )

        // Everything a caller can reach on the suggestion is read-only. The
        // schedule it was derived from is untouched, and stays untouched no
        // matter what is read off the suggestion.
        _ = suggestion.suggestedInterval
        _ = suggestion.question
        _ = suggestion.observation
        _ = suggestion.generatedStrings
        #expect(schedule.interval == .minutes90)
        #expect(schedule.interval.minutes == 90)
        #expect(suggestion.currentInterval == schedule.interval)

        // Asking twice gives the same answer: nothing was consumed or advanced.
        let again = InsightsEngine.intervalSuggestion(
            events: events,
            currentInterval: schedule.interval,
            window: .trailingDays(14),
            calendar: calendar,
            now: now
        )
        #expect(again == suggestion)
    }

    @Test("A report only carries a question when the caller supplies the current interval")
    func reportOmitsSuggestionWithoutAnInterval() {
        let events = InsightsFixture.sameDayGaps(InsightThresholds.minimumSuggestionGapSamples)
        let withoutInterval = InsightsEngine.report(
            events: events,
            window: .trailingDays(14),
            calendar: calendar,
            now: now
        )
        let withInterval = InsightsEngine.report(
            events: events,
            window: .trailingDays(14),
            currentInterval: .minutes90,
            calendar: calendar,
            now: now
        )

        #expect(withoutInterval.intervalSuggestion == nil)
        #expect(withInterval.intervalSuggestion != nil)
        // The rest of the report is identical either way.
        #expect(withoutInterval.typicalGap == withInterval.typicalGap)
        #expect(withoutInterval.participation == withInterval.participation)
    }
}
