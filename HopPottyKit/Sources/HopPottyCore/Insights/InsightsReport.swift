import Foundation

/// One period's worth of insights, ready for the parent dashboard.
///
/// Every pattern is optional and is `nil` whenever its minimum sample size was
/// not met. A screen that renders "nothing yet" for a young log is the correct
/// screen: an empty state is honest, and a hedged statistic is not.
public struct InsightsReport: Hashable, Sendable {

    public let window: InsightWindow
    public let period: DateWindow
    public let previousPeriod: DateWindow
    /// Raw counts for this period and the one before, including every kind.
    public let comparison: PeriodComparison

    public let participation: ParticipationInsight?
    public let typicalGap: TypicalGapInsight?
    public let timeOfDayConsistency: TimeOfDayConsistencyInsight?
    public let longestDryStretch: DryStretchInsight?
    /// A question for the parent, never an action. See `IntervalSuggestion`.
    public let intervalSuggestion: IntervalSuggestion?

    init(
        window: InsightWindow,
        period: DateWindow,
        previousPeriod: DateWindow,
        comparison: PeriodComparison,
        participation: ParticipationInsight?,
        typicalGap: TypicalGapInsight?,
        timeOfDayConsistency: TimeOfDayConsistencyInsight?,
        longestDryStretch: DryStretchInsight?,
        intervalSuggestion: IntervalSuggestion?
    ) {
        self.window = window
        self.period = period
        self.previousPeriod = previousPeriod
        self.comparison = comparison
        self.participation = participation
        self.typicalGap = typicalGap
        self.timeOfDayConsistency = timeOfDayConsistency
        self.longestDryStretch = longestDryStretch
        self.intervalSuggestion = intervalSuggestion
    }

    public var current: PeriodAggregate { comparison.current }
    public var previous: PeriodAggregate { comparison.previous }

    /// Whether any pattern cleared its threshold.
    public var hasAnyInsight: Bool {
        participation != nil || typicalGap != nil || timeOfDayConsistency != nil || longestDryStretch != nil
    }

    /// Always true. Any surface showing any part of this report attaches
    /// `disclaimer`; there is no code path that returns `false`.
    public var disclaimerRequired: Bool { true }
    public var disclaimer: String { InsightConfidence.disclaimer }

    /// Every data-dependent string in this report.
    ///
    /// Exists so the language test can walk the engine's real output rather
    /// than a list somebody remembered to update.
    public var allGeneratedStrings: [String] {
        var strings: [String] = [disclaimer]
        if let participation { strings += participation.generatedStrings }
        if let typicalGap { strings += typicalGap.generatedStrings }
        if let timeOfDayConsistency { strings += timeOfDayConsistency.generatedStrings }
        if let longestDryStretch { strings += longestDryStretch.generatedStrings }
        if let intervalSuggestion { strings += intervalSuggestion.generatedStrings }
        return strings
    }
}
