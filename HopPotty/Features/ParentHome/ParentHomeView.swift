import SwiftUI
import HopPottyCore

/// The dashboard.
///
/// The screen *is* Hop's pond. The scene is the backdrop rather than an
/// illustration placed on one, Hop sits in it, and the two things a caregiver
/// opens the app for float over the water: who this is about, and when the next
/// Potty Pause is. Everything else — today's numbers, today's entries, the one
/// observation — lives on a panel that rises out of the pond and is pulled up
/// with the same scroll that reveals it. There is no modal: a caregiver checking
/// the timeline should never have to dismiss anything to get back to the timer.
///
/// On a regular width the panel splits into two columns and the countdown sits
/// beside the water instead of across it, because an iPad in landscape has room
/// for both and a single column down the middle of a 1024pt screen is a phone
/// layout that was stretched. The measure is capped either way — see
/// `HopLayout.readableWidth`.
///
/// The countdown itself has no card under it: it stands on the water, and
/// `HopTimerCard`'s `.scene` surface is where the contrast that costs is bought
/// back. Nothing below it changed — the panel, the quick reminder bar and the
/// footer are all still on their own opaque grounds.
///
/// Nothing about what the screen *does* moved: the same model call behind Skip,
/// Start Now, Resume and Restore access; the same log sheet; the same two
/// navigation destinations; the same failure alert.
struct ParentHomeView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ParentEnvironment.self) private var parent

    @State private var model: ParentHomeModel?
    @State private var isLogSheetPresented = false
    @State private var route: ParentHomeRoute?

    var body: some View {
        // Loading, empty and failed are all one card-shaped surface in the
        // middle of the screen, so they arrive the way a card arrives. The
        // loaded state deliberately does not: it is a full-bleed pond with a
        // stack of cards on it, and it arrives by *staggering those cards*
        // (`arrivalIndex:` in `ParentHomeSections`) rather than by lifting the
        // whole pond fourteen points. Doing both would be the same motion
        // twice, which is worse than either.
        Group {
            switch model?.state {
            case .loaded(let snapshot):
                content(snapshot)
            case .empty, .none:
                emptyFamilyState
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
        .navigationTitle(Text(hop: HopCopy.parentHome.title))
        // The pond needs the top of the display, so the dashboard's own title
        // bar goes away once there is a pond to show. It comes back for every
        // other state, where a screen with no scene needs its heading.
        .navigationBarTitleDisplayMode(isPondLayout ? .inline : .large)
        .toolbar(navigationBarVisibility, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
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

    // MARK: Chrome

    /// Whether the pond is on screen. Only the loaded state has one.
    private var isPondLayout: Bool {
        guard let state = model?.state else { return false }
        if case .loaded = state { return true }
        return false
    }

    /// The navigation bar is hidden over the pond on a phone, and kept on iPad.
    ///
    /// Not a stylistic difference: on a regular width this view is the detail
    /// column of `ParentRootView`'s split view, and the control that brings the
    /// sidebar back when a caregiver has collapsed it lives in this bar. Losing
    /// it would leave them with no way to reach Progress or Settings. Its
    /// background is hidden either way, so the water runs under it.
    private var navigationBarVisibility: Visibility {
        guard isPondLayout else { return .visible }
        return horizontalSizeClass == .regular ? .visible : .hidden
    }

    // MARK: Layout

    @ViewBuilder
    private func content(_ snapshot: ParentHomeModel.Snapshot) -> some View {
        GeometryReader { proxy in
            let metrics = HomePondMetrics(
                size: proxy.size,
                isRegular: horizontalSizeClass == .regular,
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            )

            ZStack(alignment: .top) {
                HomePondScene(metrics: metrics)

                ScrollView {
                    VStack(spacing: 0) {
                        // The water the screen opens on. Clear rather than a
                        // spacer view so the pond behind it is what a caregiver
                        // sees, and part of the scroll content so it is what
                        // they push out of the way.
                        Color.clear
                            .frame(height: metrics.opening)
                            .accessibilityHidden(true)

                        heroCard(snapshot)
                            .frame(maxWidth: metrics.cardMaxWidth, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .hopPageMargins()
                            .padding(.bottom, theme.spacing.s)

                        // A one-off nudge the caregiver set, or the affordance
                        // to set one. Draws nothing when the service is absent.
                        QuickReminderBar(childID: snapshot.child.id)
                            .frame(maxWidth: metrics.cardMaxWidth, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .hopPageMargins()
                            .padding(.bottom, theme.spacing.l)

                        HomeSheetPanel(minimumHeight: metrics.sheetMinHeight) {
                            panelContent(snapshot)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .refreshable { await model?.load(childID: parent.activeChildID) }

                HomeSceneTopBar(
                    greeting: ParentGreeting.text(at: parent.clock.now, calendar: parent.clock.calendar),
                    children: parent.children,
                    child: snapshot.child,
                    starsToday: snapshot.starsToday,
                    onSelectChild: { childID in
                        Task { await parent.selectChild(childID) }
                    }
                )
                .hopPageMargins()
                .padding(.top, theme.spacing.xs)
                // Drawn last so it floats, read first because it says whose
                // screen this is. Z-order is the reading order in a `ZStack`
                // otherwise, and "Maya" would arrive after the timeline.
                .accessibilitySortPriority(1)
            }
        }
    }

    /// The panel's own content: the day, the entries, the observation.
    ///
    /// Two columns on iPad with the timeline given its own, because it is the
    /// only block on this screen that grows without limit and a column that
    /// grows should not push a fixed one down the page.
    @ViewBuilder
    private func panelContent(_ snapshot: ParentHomeModel.Snapshot) -> some View {
        if horizontalSizeClass == .regular {
            HStack(alignment: .top, spacing: theme.spacing.xl) {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    todaySection(snapshot)
                    HomeInsightSection(insight: snapshot.insight, onAction: handle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TodayTimelineSection(events: snapshot.todayEvents) {
                    isLogSheetPresented = true
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .hopPageMargins()
        } else {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                todaySection(snapshot)
                TodayTimelineSection(events: snapshot.todayEvents) {
                    isLogSheetPresented = true
                }
                HomeInsightSection(insight: snapshot.insight, onAction: handle)
            }
            .hopPageMargins()
            .hopReadableWidth()
        }
    }

    private func todaySection(_ snapshot: ParentHomeModel.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            HopSectionHeader(HopCopy.parentHome.summaryTitle.localized)
            TodayMetricsRow(snapshot: snapshot)
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

#Preview("Reduce Motion, still pond") {
    NavigationStack { ParentHomeView() }
        .environment(ParentEnvironment.preview())
        .hopThemedRoot(reduceMotion: true)
}

#Preview("iPad, side by side") {
    // The size class is set explicitly: a wide preview frame alone still
    // reports `.compact`, and the two-column panel is the thing being checked.
    homePreview(.preview())
        .environment(\.horizontalSizeClass, .regular)
        .frame(width: 1024, height: 768)
}
#endif
