import SwiftUI
import HopPottyCore

/// Progress.
///
/// Named `ProgressDashboardView` rather than `ProgressView` because SwiftUI
/// already owns that name and shadowing it inside the app target would be a
/// long-running practical joke.
struct ProgressDashboardView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(ParentEnvironment.self) private var parent

    var childID: UUID? = nil

    @State private var model: ProgressModel?

    var body: some View {
        // Changing the range reloads, so this swap runs whenever a caregiver
        // taps the picker, not only on first open. The three card-shaped states
        // arrive as cards; the loaded state is a *stack* of cards and arrives by
        // staggering them (`arrivalIndex:` below and in `ProgressChartSection`)
        // rather than lifting the whole page — doing both would animate every
        // card twice.
        Group {
            switch model?.state {
            case .loaded(let snapshot):
                content(snapshot)
            case .empty, .none:
                HopEmptyState(
                    glyph: .pond,
                    title: HopFeatureStrings.homeNoChildTitle,
                    message: HopFeatureStrings.homeNoChildMessage,
                    action: nil
                )
                .hopScreenTransition(.cardArrival)
            case .failed(let failure):
                failureState(failure)
                    .hopScreenTransition(.cardArrival)
            case .firstLoad, .loading:
                HopLoadingState(message: nil)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .hopScreenTransition(.cardArrival)
            }
        }
        .hopScreenChange(.cardArrival, value: model?.state)
        .navigationTitle(Text(verbatim: HopFeatureStrings.progressTitle))
        .hopBackground(.primary)
        .task(id: parent.activeChildID) { await ensureLoaded() }
    }

    @ViewBuilder
    private func content(_ snapshot: ProgressModel.Snapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                rangePicker
                periodLabel(snapshot)

                if snapshot.hasEntries {
                    if horizontalSizeClass == .regular {
                        // Two columns on iPad: the chart and totals on the left,
                        // the observations and the timeline on the right, so a
                        // caregiver can compare a pattern against the entries it
                        // came from without scrolling between them.
                        HStack(alignment: .top, spacing: theme.spacing.l) {
                            VStack(alignment: .leading, spacing: theme.spacing.l) {
                                ProgressTotalsRow(aggregate: snapshot.aggregate)
                                ProgressChartSection(
                                    aggregate: snapshot.aggregate,
                                    calendar: parent.clock.calendar
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .leading, spacing: theme.spacing.l) {
                                insights(snapshot)
                                ProgressTimelineSection(days: snapshot.timeline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ProgressTotalsRow(aggregate: snapshot.aggregate)
                        ProgressChartSection(
                            aggregate: snapshot.aggregate,
                            calendar: parent.clock.calendar
                        )
                        insights(snapshot)
                        ProgressTimelineSection(days: snapshot.timeline)
                    }
                } else {
                    HopEmptyState(
                        glyph: .timer,
                        title: HopFeatureStrings.progressEmptyTitle,
                        message: HopFeatureStrings.progressEmptyMessage,
                        action: nil
                    )
                }
            }
            .hopPageMargins()
            .padding(.vertical, theme.spacing.l)
            .modifier(ProgressMeasure(isRegular: horizontalSizeClass == .regular))
        }
        .refreshable { await model?.load(childID: childID ?? parent.activeChildID) }
    }

    private var rangePicker: some View {
        Picker(HopFeatureStrings.progressTitle, selection: rangeBinding) {
            ForEach(ProgressRange.allCases) { range in
                Text(verbatim: range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private func periodLabel(_ snapshot: ProgressModel.Snapshot) -> some View {
        Text(
            verbatim: ParentFormat.windowLabel(
                snapshot.report.period,
                calendar: parent.clock.calendar
            )
        )
        .font(theme.font(.parentFootnote))
        .foregroundStyle(theme.color.textSecondary)
    }

    /// Observations, and the interval question if the engine raised one.
    ///
    /// Nothing is drawn when nothing cleared its threshold — the sentence below
    /// says the log is young, and says nothing about the child.
    @ViewBuilder
    private func insights(_ snapshot: ProgressModel.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            HopSectionHeader(HopFeatureStrings.progressPatternsTitle)

            if snapshot.insights.isEmpty && snapshot.intervalQuestion == nil {
                Text(hop: HopCopy.parentHome.insightsNotEnoughData)
                    .font(theme.font(.parentCallout))
                    .foregroundStyle(theme.color.textSecondary)
            } else {
                Text(hop: HopCopy.parentHome.insightsDisclaimer)
                    .font(theme.font(.parentFootnote))
                    .foregroundStyle(theme.color.textSecondary)

                ForEach(Array(snapshot.insights.enumerated()), id: \.element.id) { index, insight in
                    HopInsightCard(insight: insight, onAction: nil, arrivalIndex: index)
                }
                if let question = snapshot.intervalQuestion {
                    HopInsightCard(
                        insight: question,
                        onAction: { action in
                            guard action.kind == .adjustSchedule else { return }
                            Task { await model?.applyIntervalSuggestion(childID: snapshot.child.id) }
                        },
                        // Last in the section, so it settles after the
                        // observations it sits under.
                        arrivalIndex: snapshot.insights.count
                    )
                }
                // Not repeated here: every `HopInsightCard` above renders
                // `insight.disclaimer` itself, and three cards under one more
                // copy of the same sentence is the boilerplate §35 rules out.
                // The section's own preamble above still states it once.
            }
        }
    }

    private func failureState(_ failure: ParentFailure) -> some View {
        let presentation = failure.presentation
        return HopEmptyState(
            glyph: .shield,
            title: presentation.title,
            message: presentation.message,
            action: (
                HopCopy.errors.retryButton.localized,
                { Task { await model?.load(childID: childID ?? parent.activeChildID) } }
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rangeBinding: Binding<ProgressRange> {
        Binding(
            get: { model?.range ?? .week },
            set: { range in
                Task { await model?.select(range, childID: childID ?? parent.activeChildID) }
            }
        )
    }

    private func ensureLoaded() async {
        if model == nil { model = ProgressModel(environment: parent) }
        await model?.load(childID: childID ?? parent.activeChildID)
    }
}

/// The measure. A single column is capped for readability; two columns already
/// have their own measure and must not be squeezed into the single-column one.
private struct ProgressMeasure: ViewModifier {
    let isRegular: Bool

    func body(content: Content) -> some View {
        if isRegular {
            content
        } else {
            content.hopReadableWidth()
        }
    }
}

#if DEBUG
// `@MainActor` because a file-scope `private func` is nonisolated by default,
// while `ParentEnvironment`, the design-system modifiers and the views
// themselves are all main-actor isolated. Every call site is a `#Preview` body,
// which is main-actor anyway, so the annotation states what was already true.
//
// Seven file-scope preview helpers across the app have this shape. One
// (`sheetPreview` in QuickReminderSheet) was already annotated. Of the six that
// were not, the compiler named four -- one in run 60, three in run 66 -- and
// stopped; `paywallPreview` and `homePreview` were found by looking for the
// shape rather than waiting to be told.
@MainActor
private func progressPreview(_ environment: ParentEnvironment) -> some View {
    NavigationStack { ProgressDashboardView() }
        .environment(environment)
        .hopThemedRoot()
}

#Preview("Week, populated") { progressPreview(.preview()) }
#Preview("Empty period") { progressPreview(.previewEmpty()) }
#Preview("Long nickname") { progressPreview(.previewLongNickname()) }
#Preview("AX3 dark") {
    progressPreview(.preview())
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}
#Preview("Store unavailable") { progressPreview(.preview(isStoreAvailable: false)) }
#endif
