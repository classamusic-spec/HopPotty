import Foundation
import Observation
import HopPottyCore

/// Day / Week / Month, mapped onto the windows the insights engine understands.
///
/// "Month" is thirty trailing days rather than a calendar month: a family
/// opening the app on the 2nd would otherwise see two days of data labelled as
/// a month, and every threshold in `InsightThresholds` counts days.
enum ProgressRange: String, CaseIterable, Identifiable, Sendable {
    case day, week, month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: HopFeatureStrings.progressRangeDay
        case .week: HopFeatureStrings.progressRangeWeek
        case .month: HopFeatureStrings.progressRangeMonth
        }
    }

    var window: InsightWindow {
        switch self {
        case .day: .day
        case .week: .week
        case .month: .trailingDays(30)
        }
    }
}

/// The Progress screen's data.
@MainActor
@Observable
final class ProgressModel {

    struct Snapshot: Equatable {
        var child: ChildProfile
        var range: ProgressRange
        var report: InsightsReport
        var events: [PottyEvent]
        var timeline: [TimelineDay]
        var insights: [Insight]
        var intervalQuestion: Insight?

        var aggregate: PeriodAggregate { report.current }
        var hasEntries: Bool { aggregate.recordedCount > 0 }
    }

    private(set) var state: ParentLoadState<Snapshot> = .firstLoad
    var range: ProgressRange = .week

    private let environment: ParentEnvironment

    init(environment: ParentEnvironment) {
        self.environment = environment
    }

    var calendar: Calendar { environment.clock.calendar }

    func load(childID: UUID?) async {
        guard let child = environment.resolvedChild(childID) else {
            state = .empty
            return
        }
        state = .loading(previous: state.value)

        do {
            let now = environment.clock.now
            let window = range.window
            let period = window.interval(containing: now, calendar: calendar)

            // The whole history feeds the engine, which scopes to the period
            // itself. Handing it only the period's rows would silently break
            // the previous-period comparison.
            let allEvents = try await environment.repositories.events.events(
                matching: PottyEventQuery(childID: child.id)
            )
            let schedule = await environment.schedule(for: child.id)

            let report = InsightsEngine.report(
                events: allEvents,
                childID: child.id,
                window: window,
                currentInterval: schedule.interval,
                calendar: calendar,
                now: now
            )

            let periodEvents = allEvents
                .filter { period.contains($0.timestamp) }
                .sorted { $0.timestamp > $1.timestamp }

            state = .loaded(
                Snapshot(
                    child: child,
                    range: range,
                    report: report,
                    events: periodEvents,
                    timeline: TimelineDay.group(periodEvents, calendar: calendar),
                    insights: ParentInsightPolicy.shown(InsightPresentation.cards(from: report)),
                    intervalQuestion: InsightPresentation.intervalCard(from: report)
                )
            )
        } catch {
            state = .failed(environment.isStoreAvailable ? .readFailed : .storageUnavailable)
        }
    }

    func select(_ range: ProgressRange, childID: UUID?) async {
        guard range != self.range else { return }
        self.range = range
        await load(childID: childID)
    }

    /// Applies the interval the engine observed. Only ever called from the
    /// caregiver's own tap — `IntervalSuggestion` holds minutes, not a
    /// schedule, precisely so that this write lives in the app and not in the
    /// engine.
    func applyIntervalSuggestion(childID: UUID) async {
        guard let suggestion = state.value?.report.intervalSuggestion else { return }
        var schedule = await environment.schedule(for: childID)
        schedule.interval = suggestion.suggestedInterval
        _ = await environment.saveSchedule(schedule)
        await load(childID: childID)
    }
}


/// Observations the caregiver surfaces refuse to draw, whatever the engine
/// returned.
///
/// `dryStretch` is "the longest stretch with no accident recorded". It is a
/// *record*: a record invites beating it, and the thing being scored is a
/// child's body. §7 and §13 bar dry streaks, best days, longest streaks and
/// every other ranking, and this is the one the engine still produces — it used
/// to be the third card on Progress, with a week-on-week bar pair under it
/// framing the child's week as a contest with last week's.
///
/// Filtering here rather than in the engine is deliberate and temporary.
/// `InsightsEngine.longestDryStretch` and `InsightPresentation` both live
/// outside this feature; deleting the metric at its source is the correct fix
/// and belongs to whoever owns `HopPottyCore/Insights`. Until then, no parent
/// surface draws it: this is the only path Progress has to a card, and
/// `ParentHomeModel` applies the same policy to the dashboard's single
/// headline.
enum ParentInsightPolicy {
    /// Insight ids that never reach a caregiver.
    static let suppressed: Set<String> = ["dryStretch"]

    static func shown(_ insights: [Insight]) -> [Insight] {
        insights.filter { !suppressed.contains($0.id) }
    }

    static func shown(_ insight: Insight?) -> Insight? {
        guard let insight, !suppressed.contains(insight.id) else { return nil }
        return insight
    }
}
