import Foundation
import Testing
@testable import HopPottyCore

/// The safety rail.
///
/// HopPotty is not a medical device. This suite exists so that a sentence a
/// paediatrician would object to cannot reach a parent, whoever writes it and
/// whenever they write it. It is not a style check — a failure here is a
/// product-contract failure (`Docs/CONTRACTS.md` §4.5).
///
/// The forbidden list is declared here, in the test, rather than read from the
/// engine. If someone narrows `InsightLanguagePolicy.forbiddenFragments` to get
/// a build green, this suite still fails.
@Suite("Insight language safety")
struct InsightLanguageTests {

    private let calendar = InsightsFixture.calendar
    private let now = InsightsFixture.wednesdayEvening

    /// Words and stems a paediatrician would object to seeing in a consumer app
    /// describing a child's toileting.
    ///
    /// Matched case-insensitively as substrings, so stems catch inflections:
    /// "diagnos" catches diagnose, diagnosis and diagnostic; "cause" catches
    /// caused, causes and because.
    static let forbidden: [String] = [
        // Named in the product contract.
        "should", "normal", "abnormal", "delayed", "diagnos", "treat",
        "prevent", "cure", "condition", "disorder", "must", "recommended",
        // The same failure modes, other spellings.
        "recommend", "ought", "need to", "supposed to", "required",
        "symptom", "syndrome", "dysfunction", "incontinen", "constipat",
        "therapy", "medication", "clinical",
        // Norms about development.
        "delay", "behind", "on track", "regress", "milestone", "average child",
        "typical for", "expected for", "age-appropriate",
        // Causal claims this engine has no basis for.
        "cause", "leads to", "due to", "results in", "proves", "guarantee",
        // Shame, failure and loss.
        "fail", "wrong", "poor", "worse", "problem", "lost", "streak",
        "success rate",
    ]

    /// Reports covering every shape of data the engine can be handed, so the
    /// scan below runs over real output rather than a curated sample.
    private func everyReachableString() -> [String] {
        var events = InsightsFixture.sameDayGaps(InsightThresholds.minimumSuggestionGapSamples)
        events.append(
            InsightsFixture.event(
                at: InsightsFixture.date(2025, 3, 11, 19, 0),
                kind: .accident,
                source: .parentManual
            )
        )
        for offset in 0..<6 {
            let day = 12 - offset
            events.append(InsightsFixture.event(at: InsightsFixture.date(2025, 3, day, 8, 0), kind: .pee))
            events.append(InsightsFixture.event(at: InsightsFixture.date(2025, 3, day, 20, 0), kind: .poop))
        }

        let accidentsOnly = (10...12).flatMap { day in
            [
                InsightsFixture.event(at: InsightsFixture.date(2025, 3, day, 10, 0), kind: .accident, source: .parentManual),
                InsightsFixture.event(at: InsightsFixture.date(2025, 3, day, 16, 0), kind: .accident, source: .parentManual),
            ]
        }

        let reports: [InsightsReport] = [
            InsightsEngine.report(events: events, window: .week, currentInterval: .minutes90, calendar: calendar, now: now),
            InsightsEngine.report(events: events, window: .trailingDays(14), currentInterval: .minutes15, calendar: calendar, now: now),
            InsightsEngine.report(events: events, window: .day, currentInterval: .minutes60, calendar: calendar, now: now),
            InsightsEngine.report(events: accidentsOnly, window: .week, currentInterval: .minutes60, calendar: calendar, now: now),
            InsightsEngine.report(events: [], window: .week, currentInterval: .minutes60, calendar: calendar, now: now),
            InsightsEngine.report(
                events: [InsightsFixture.event(at: InsightsFixture.date(2025, 3, 12, 9, 0))],
                window: .week,
                currentInterval: .minutes60,
                calendar: calendar,
                now: now
            ),
        ]

        var strings = reports.flatMap(\.allGeneratedStrings)
        strings += InsightsEngine.allStaticStrings

        // Sweep the number-dependent builders across the shapes their output
        // changes on: zero, one, plural, and each unit boundary.
        for value in [0, 1, 2, 5, 45, 59, 60, 61, 90, 100, 1_439, 1_440, 1_441, 1_500, 2_880, 4_321] {
            strings.append(InsightPhrasing.minutes(value))
            strings.append(InsightPhrasing.visits(value))
            strings.append(InsightPhrasing.days(value))
            strings.append(InsightPhrasing.duration(TimeInterval(value) * 60))
            strings.append(InsightPhrasing.minuteRange(lower: value, upper: value + 5))
        }
        for higher in DaySegment.allCases {
            for lower in DaySegment.allCases {
                strings.append(
                    InsightPhrasing.timeOfDayConsistency(
                        higher: higher,
                        higherDays: 5,
                        lower: lower,
                        lowerDays: 2,
                        observedDays: 7
                    )
                )
            }
        }
        for current in PottyInterval.presets {
            for suggested in PottyInterval.presets {
                strings.append(
                    InsightPhrasing.intervalQuestion(
                        currentMinutes: current.minutes,
                        suggestedMinutes: suggested.minutes
                    )
                )
            }
        }
        return strings
    }

    @Test("No string the engine can produce contains forbidden language")
    func noForbiddenLanguageAnywhere() {
        let strings = everyReachableString()
        // A rail that scans nothing passes trivially; make sure it is scanning.
        #expect(strings.count > 100)

        for string in strings {
            let hits = Self.forbidden.filter { string.lowercased().contains($0) }
            #expect(hits.isEmpty, "Forbidden language \(hits) in generated string: \(string)")
        }
    }

    @Test("Every generated string is real copy, not an empty placeholder")
    func generatedStringsAreSubstantive() {
        for string in everyReachableString() {
            #expect(!string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @Test("The engine's own policy covers every word this suite forbids")
    func policyCoversTheContractsVocabulary() {
        for word in Self.forbidden {
            let covered = InsightLanguagePolicy.forbiddenFragments.contains { fragment in
                word.contains(fragment)
            }
            #expect(covered, "InsightLanguagePolicy no longer catches \(word)")
        }
    }

    @Test("The policy catches language it is meant to catch")
    func policyRejectsUnsafeCopy() {
        let unsafeExamples = [
            "Your child should go every 45 minutes.",
            "This is a normal interval for a three-year-old.",
            "Fewer accidents means that toilet training is working.",
            "We recommend a shorter interval.",
            "Longer gaps may indicate a medical condition.",
            "You must keep the streak going.",
            "This pattern is abnormal and may need to be treated.",
        ]
        for example in unsafeExamples {
            #expect(!InsightLanguagePolicy.isAcceptable(example), "Policy let this through: \(example)")
            #expect(!InsightLanguagePolicy.violations(in: example).isEmpty)
        }
    }

    @Test("Matching ignores capitalisation")
    func policyIsCaseInsensitive() {
        #expect(!InsightLanguagePolicy.isAcceptable("SHOULD"))
        #expect(!InsightLanguagePolicy.isAcceptable("Normal"))
        #expect(!InsightLanguagePolicy.isAcceptable("Diagnosis"))
    }

    @Test("Observations the engine does make are accepted")
    func policyAcceptsObservationalCopy() {
        #expect(InsightLanguagePolicy.isAcceptable(InsightConfidence.disclaimer))
        #expect(InsightLanguagePolicy.isAcceptable(InsightLanguagePolicy.neutralFallback))
        #expect(InsightLanguagePolicy.isAcceptable("Half of the recorded gaps fell within 45–55 minutes."))
    }

    // MARK: The label

    @Test("Every insight declares that it needs the disclaimer")
    func everyInsightRequiresTheDisclaimer() throws {
        var events = InsightsFixture.sameDayGaps(InsightThresholds.minimumSuggestionGapSamples)
        for offset in 0..<6 {
            let day = 12 - offset
            events.append(InsightsFixture.event(at: InsightsFixture.date(2025, 3, day, 8, 0), kind: .pee))
        }
        let report = InsightsEngine.report(
            events: events,
            window: .week,
            currentInterval: .minutes90,
            calendar: calendar,
            now: now
        )

        #expect(report.disclaimerRequired)
        #expect(report.disclaimer == InsightConfidence.disclaimer)
        #expect(report.allGeneratedStrings.contains(InsightConfidence.disclaimer))

        let participation = try #require(report.participation)
        let gap = try #require(report.typicalGap)
        let suggestion = try #require(report.intervalSuggestion)
        #expect(participation.disclaimerRequired)
        #expect(gap.disclaimerRequired)
        #expect(suggestion.disclaimerRequired)
        #expect(participation.generatedStrings.contains(InsightConfidence.disclaimer))
        #expect(gap.generatedStrings.contains(InsightConfidence.disclaimer))
        #expect(suggestion.generatedStrings.contains(InsightConfidence.disclaimer))
    }

    @Test("Confidence never claims certainty, at any sample size")
    func confidenceIsNeverAbsolute() {
        for size in [0, 1, 5, 12, 24, 100, 10_000] {
            let confidence = InsightConfidence(sampleSize: size, minimumSampleSize: 12, observedDays: 7)
            #expect(confidence.disclaimerRequired)
            #expect(InsightConfidence.Level.allCases.contains(confidence.level))
            #expect(InsightLanguagePolicy.isAcceptable(confidence.level.label))
        }
        // There is no level above "supported": the engine has one family's log
        // and no population to compare it with.
        #expect(InsightConfidence.Level.allCases.count == 3)
    }
}
