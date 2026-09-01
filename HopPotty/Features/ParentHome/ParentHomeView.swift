import SwiftUI
import HopPottyCore

/// The dashboard.
///
/// On a regular width the hero and the day's detail sit side by side rather than
/// stacked, because an iPad in landscape has room for both and a single column
/// of cards down the middle of a 1024pt screen is a phone layout that was
/// stretched. The measure is capped either way — see `HopLayout.readableWidth`.
struct ParentHomeView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ParentEnvironment.self) private var parent

    @State private var model: ParentHomeModel?
    @State private var isLogSheetPresented = false
    @State private var route: ParentHomeRoute?

    var body: some View {
        Group {
            switch model?.state {
            case .loaded(let snapshot):
                content(snapshot)
            case .empty, .none:
                emptyFamilyState
            case .failed(let failure):
                failureState(failure)
            case .firstLoad, .loading:
                HopLoadingState(message: nil)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(Text(hop: HopCopy.parentHome.title))
        .navigationBarTitleDisplayMode(.large)
        .hopBackground(.primary)
        .task(id: parent.activeChildID) { await ensureLoaded() }
        .onChange(of: scenePhase) { _, phase in
            // Authorization, the shield and the clock can all move while the
            // app is away. The dashboard re-derives rather than trusting what
            // it drew before the caregiver switched apps.
            guard phase == .active else { return }
            Task { await model?.load(childID: parent.activeChildID) }
        }
        .sheet(isPresented: $isLogSheetPresented) {
            if let model {
                LogVisitSheet { kind, timestamp, note in
                    await model.logEvent(kind: kind, at: timestamp, note: note)
                }
            }
        }
        .navigationDestination(item: $route) { destination in
            switch destination {
            case .timerSettings(let childID):
                PottyPauseSettingsView(childID: childID)
            case .progress(let childID):
                ProgressDashboardView(childID: childID)
            }
        }
        .alert(
            model?.actionFailure?.presentation.title ?? "",
            isPresented: Binding(
                get: { model?.actionFailure != nil },
                set: { if !$0 { model?.dismissActionFailure() } }
            )
        ) {
            Button(HopCopy.errors.dismissButton.localized) { model?.dismissActionFailure() }
        } message: {
            Text(verbatim: model?.actionFailure?.presentation.message ?? "")
        }
    }

    // MARK: Layout

    @ViewBuilder
    private func content(_ snapshot: ParentHomeModel.Snapshot) -> some View {
        ScrollView {
            if horizontalSizeClass == .regular {
                HStack(alignment: .top, spacing: theme.spacing.l) {
                    VStack(alignment: .leading, spacing: theme.spacing.l) {
                        header(snapshot)
                        heroCard(snapshot)
                        TodayMetricsRow(snapshot: snapshot)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: theme.spacing.l) {
                        HomeInsightSection(insight: snapshot.insight, onAction: handle)
                        TodayTimelineSection(events: snapshot.todayEvents) {
                            isLogSheetPresented = true
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .hopPageMargins()
                .padding(.vertical, theme.spacing.l)
            } else {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    header(snapshot)
                    heroCard(snapshot)
                    TodayMetricsRow(snapshot: snapshot)
                    HomeInsightSection(insight: snapshot.insight, onAction: handle)
                    TodayTimelineSection(events: snapshot.todayEvents) {
                        isLogSheetPresented = true
                    }
                }
                .hopPageMargins()
                .padding(.vertical, theme.spacing.l)
                .hopReadableWidth()
            }
        }
        .refreshable { await model?.load(childID: parent.activeChildID) }
    }

    private func header(_ snapshot: ParentHomeModel.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
            Text(verbatim: ParentGreeting.text(at: parent.clock.now, calendar: parent.clock.calendar))
                .font(theme.font(.parentCallout))
                .foregroundStyle(theme.color.textSecondary)
            ChildSwitcher(children: parent.children, selected: snapshot.child) { childID in
                Task { await parent.selectChild(childID) }
            }
        }
    }

    @ViewBuilder
    private func heroCard(_ snapshot: ParentHomeModel.Snapshot) -> some View {
        if let model {
            NextPauseCard(
                snapshot: snapshot,
                now: parent.clock.now,
                calendar: parent.clock.calendar,
                onSkip: { Task { await model.skipNextPause() } },
                onStartNow: { Task { await model.startPauseNow() } },
                onResume: { Task { await model.resume() } },
                onReviewSettings: { route = .timerSettings(snapshot.child.id) },
                onRestoreAccess: { Task { await model.restoreScreenAccess() } }
            )
        }
    }

    // MARK: States

    private var emptyFamilyState: some View {
        HopEmptyState(
            glyph: .pond,
            title: HopFeatureStrings.homeNoChildTitle,
            message: HopFeatureStrings.homeNoChildMessage,
            action: nil
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failureState(_ failure: ParentFailure) -> some View {
        let presentation = failure.presentation
        return VStack(spacing: theme.spacing.m) {
            HopEmptyState(
                glyph: .shield,
                title: presentation.title,
                message: presentation.message,
                action: (
                    HopCopy.errors.retryButton.localized,
                    { Task { await model?.load(childID: parent.activeChildID) } }
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handle(_ action: InsightAction) {
        switch action.kind {
        case .adjustSchedule, .addQuietHours:
            if let childID = model?.state.value?.child.id { route = .timerSettings(childID) }
        case .viewTimeline:
            if let childID = model?.state.value?.child.id { route = .progress(childID) }
        case .dismiss:
            break
        }
    }

    private func ensureLoaded() async {
        if model == nil { model = ParentHomeModel(environment: parent) }
        await model?.load(childID: parent.activeChildID)
    }
}

/// Where the dashboard can push to.
enum ParentHomeRoute: Hashable, Identifiable {
    case timerSettings(UUID)
    case progress(UUID)

    var id: String {
        switch self {
        case .timerSettings(let id): "timer-\(id.uuidString)"
        case .progress(let id): "progress-\(id.uuidString)"
        }
    }
}

#if DEBUG
private func homePreview(_ environment: ParentEnvironment) -> some View {
    NavigationStack { ParentHomeView() }
        .environment(environment)
        .hopThemedRoot()
}

#Preview("Populated") { homePreview(.preview()) }

#Preview("First use, empty") { homePreview(.previewEmpty()) }

#Preview("Long nickname, AX3") {
    homePreview(.previewLongNickname())
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Permission denied") {
    homePreview(.preview(authorization: .denied))
}

#Preview("Dark") {
    homePreview(.preview()).preferredColorScheme(.dark)
}

#Preview("Store unavailable") {
    homePreview(.preview(isStoreAvailable: false))
}
#endif
