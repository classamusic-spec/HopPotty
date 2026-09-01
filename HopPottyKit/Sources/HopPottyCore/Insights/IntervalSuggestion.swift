import Foundation

/// A question the UI may put to a parent about the pause interval. Never an
/// action, and never applied.
///
/// The safety of this type is structural rather than a matter of discipline:
///
/// - It is an immutable value. Every property is `let`, there are no `mutating`
///   members, and there is no method that takes a `PottySchedule`, so there is
///   nothing here to call that changes a family's settings.
/// - Its initialiser is internal to the module, so only `InsightsEngine` can
///   mint one. A view cannot fabricate a suggestion and present it as observed.
/// - It holds `suggestedMinutes`, not a schedule. Turning it into a change of
///   configuration takes a caregiver tapping "yes" and the app writing the
///   schedule itself, which keeps the decision where it belongs.
///
/// The wording is a question for the same reason. The engine has counted gaps
/// between entries a family made; it has no idea what interval suits a child,
/// and it says so by asking rather than advising.
public struct IntervalSuggestion: Hashable, Sendable {

    /// The interval the schedule is set to now.
    public let currentMinutes: Int
    /// The interval the observed gaps would round to.
    public let suggestedMinutes: Int
    /// Middle observed gap, rounded to the reporting step.
    public let observedMedianMinutes: Int
    /// The middle 50% of observed gaps.
    public let observedRangeMinutes: ClosedRange<Int>
    /// Gaps this rests on.
    public let sampleCount: Int
    public let confidence: InsightConfidence

    init(
        currentMinutes: Int,
        suggestedMinutes: Int,
        observedMedianMinutes: Int,
        observedRangeMinutes: ClosedRange<Int>,
        sampleCount: Int,
        confidence: InsightConfidence
    ) {
        self.currentMinutes = currentMinutes
        self.suggestedMinutes = suggestedMinutes
        self.observedMedianMinutes = observedMedianMinutes
        self.observedRangeMinutes = observedRangeMinutes
        self.sampleCount = sampleCount
        self.confidence = confidence
    }

    /// The current setting as a schedule value, for display beside the question.
    public var currentInterval: PottyInterval { PottyInterval(minutes: currentMinutes) }

    /// The proposed setting as a schedule value.
    ///
    /// Reading this does not change anything. Writing the schedule is the app's
    /// job, after the parent answers the question.
    public var suggestedInterval: PottyInterval { PottyInterval(minutes: suggestedMinutes) }

    /// Whether the proposal is a shorter gap between pauses.
    public var direction: ChangeDirection {
        ChangeDirection(difference: suggestedMinutes - currentMinutes)
    }

    /// What was observed. States the data, nothing else.
    public var observation: String {
        InsightPhrasing.intervalObservation(
            medianMinutes: observedMedianMinutes,
            lower: observedRangeMinutes.lowerBound,
            upper: observedRangeMinutes.upperBound
        )
    }

    /// The question to put to the parent. Answerable with "no" and nothing
    /// happens, which is the entire design.
    public var question: String {
        InsightPhrasing.intervalQuestion(
            currentMinutes: currentMinutes,
            suggestedMinutes: suggestedMinutes
        )
    }

    /// Always true. A suggestion is a pattern with a question attached, and it
    /// carries the same label as every other insight.
    public var disclaimerRequired: Bool { confidence.disclaimerRequired }
    public var disclaimer: String { InsightConfidence.disclaimer }

    public var generatedStrings: [String] {
        [observation, question, confidence.level.label, disclaimer]
    }
}
