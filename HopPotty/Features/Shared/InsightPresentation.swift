import Foundation
import HopPottyCore

/// Turns an `InsightsReport` into the cards a parent screen draws.
///
/// The only transformation performed is *selection and naming*. Every sentence
/// comes from the engine (`patternStatement` / `supportingDetail`), unedited: the
/// language rules in `Docs/CONTRACTS.md` §4.5 are enforced by tests that walk
/// `InsightsReport.allGeneratedStrings`, and a view that rewrote a sentence
/// would slip straight past them.
///
/// An insight the engine returned `nil` for produces no card. There is no
/// placeholder, no "not enough data yet" card standing in for a finding, and no
/// hedged variant — a hedge on a dashboard reads as a finding.
enum InsightPresentation {

    static func cards(from report: InsightsReport) -> [Insight] {
        var cards: [Insight] = []

        if let participation = report.participation {
            cards.append(
                Insight(
                    id: "participation",
                    title: participation.patternStatement,
                    detail: participation.supportingDetail,
                    glyph: .tried,
                    window: report.window,
                    sampleSize: participation.visitCount,
                    observedDays: participation.observedDayCount,
                    confidence: participation.confidence.level,
                    actions: [
                        InsightAction(kind: .viewTimeline, title: HopCopy.parentHome.timelineTitle.localized)
                    ]
                )
            )
        }

        if let gap = report.typicalGap {
            cards.append(
                Insight(
                    id: "typicalGap",
                    title: gap.patternStatement,
                    detail: gap.supportingDetail,
                    glyph: .timer,
                    window: report.window,
                    sampleSize: gap.sampleCount,
                    observedDays: gap.confidence.observedDays,
                    confidence: gap.confidence.level
                )
            )
        }

        if let consistency = report.timeOfDayConsistency {
            cards.append(
                Insight(
                    id: "timeOfDay",
                    title: consistency.patternStatement,
                    detail: consistency.supportingDetail,
                    glyph: .quietHours,
                    window: report.window,
                    sampleSize: consistency.segments.reduce(0) { $0 + $1.visitCount },
                    observedDays: consistency.observedDayCount,
                    confidence: consistency.confidence.level,
                    actions: [
                        InsightAction(kind: .addQuietHours, title: HopCopy.timerSettings.quietAdd.localized)
                    ]
                )
            )
        }

        if let dry = report.longestDryStretch {
            cards.append(
                Insight(
                    id: "dryStretch",
                    title: dry.patternStatement,
                    detail: dry.supportingDetail,
                    glyph: .check,
                    window: report.window,
                    sampleSize: dry.confidence.sampleSize,
                    observedDays: dry.observedDayCount,
                    confidence: dry.confidence.level
                )
            )
        }

        return cards
    }

    /// The interval question, kept separate from the pattern cards.
    ///
    /// It is the one insight with a consequence, so it is drawn differently and
    /// asks rather than tells. Answering "no" does nothing, which is the whole
    /// design of `IntervalSuggestion`.
    static func intervalCard(from report: InsightsReport) -> Insight? {
        guard let suggestion = report.intervalSuggestion else { return nil }
        return Insight(
            id: "intervalSuggestion",
            title: suggestion.question,
            detail: suggestion.observation,
            glyph: .timer,
            window: report.window,
            sampleSize: suggestion.sampleCount,
            observedDays: suggestion.confidence.observedDays,
            confidence: suggestion.confidence.level,
            actions: [
                InsightAction(kind: .adjustSchedule, title: HopCopy.timerSettings.title.localized),
                InsightAction(kind: .dismiss, title: HopCopy.common.notNow.localized)
            ]
        )
    }

    /// The single card the dashboard shows, when there is one.
    ///
    /// The dashboard is not a report: it shows at most one observation so the
    /// hero card stays the thing a caregiver looks at. Order is fixed rather
    /// than "most interesting", because a card that changes identity every time
    /// the app opens is a card nobody trusts.
    static func headline(from report: InsightsReport) -> Insight? {
        cards(from: report).first
    }

    /// Whether any card at all cleared its threshold. Drives the "a few more
    /// days of logging will fill this in" empty state — which is a statement
    /// about the log, not about the child.
    static func hasAnyCard(_ report: InsightsReport) -> Bool {
        report.hasAnyInsight || report.intervalSuggestion != nil
    }
}
