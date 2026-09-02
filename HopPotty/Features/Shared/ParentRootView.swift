import SwiftUI
import HopPottyCore
#if DEBUG
// Sample children live in their own module so they can never reach a real
// family's data. Previews are the only callers.
import HopPottyFixtures
#endif

/// The parent app's shell.
///
/// Two genuinely different layouts, not one stretched:
///
/// - **Compact** — a `TabView`. Four destinations, thumb-reachable, exactly
///   what Health and Fitness do on a phone.
/// - **Regular** — a `NavigationSplitView` with a persistent sidebar. On an iPad
///   the dashboard, the timer settings and Progress are all things a caregiver
///   moves between while comparing them, and a tab bar 1024 points wide with
///   three items in the middle is a phone layout wearing an iPad's clothes.
///
/// The sidebar also carries the child switcher, because on iPad there is room
/// to show which child every column is about instead of hiding it in a menu.
///
/// ## The fourth destination is a door, not a pane
///
/// `ParentDestination.hop` is the child's side of the app. Selecting it does
/// not swap the pane: it presents `HopHubView` as a full-screen cover over the
/// entire shell and puts the selection straight back where it was. That is what
/// `Docs/InformationArchitecture.md` §2 means by "Child Space — full-screen
/// cover, no tab bar, no navigation chrome": while a child is holding the
/// device the caregiver's three tabs are not one mis-tap away, and the only way
/// back is the grown-up gate.
///
/// ## And it can open itself
///
/// The shield cannot launch HopPotty before iOS 26.5, so on every other version
/// the child taps the shield, lands on the Home Screen and opens HopPotty
/// themselves. When that happens *during* a pause, the routine is what they came
/// for — so this view reads the App Group's pause record whenever the app
/// becomes active and opens child mode on the routine, once per pause. It only
/// reads. The pause ends on its own timer, on completion, or on a caregiver
/// override, and nothing here is a fourth path (`Docs/ScreenTimeArchitecture.md`
/// §9, Contract §4.1).
struct ParentRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(ParentEnvironment.self) private var parent
    @Environment(\.scenePhase) private var scenePhase

    @State private var selection: ParentDestination? = .today
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    /// The last pane the caregiver was actually on. `.hop` is never one of
    /// these, so dismissing child mode lands back where they left off.
    @State private var lastPane: ParentDestination = .today

    /// Child mode, or `nil` for the caregiver's shell. Item-based rather than a
    /// `Bool` so "open on the hub" and "open on the routine" are two different
    /// presentations rather than one presentation and a flag that has to be
    /// reset by hand.
    @State private var childMode: ChildModeRequest?

    /// The pause we have already opened the routine for.
    ///
    /// Keyed by the App Group session id — the one identifier that is minted
    /// once per pause and is opaque, so this can never become a per-child fact.
    /// Without it, a child who leaves the routine and comes back to HopPotty
    /// during the same pause would be walked into the routine again, which
    /// reads as the app refusing to let them out.
    @State private var autoStartedPauseSessionID: String?

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                splitLayout
            } else {
                tabLayout
            }
        }
        .environment(\.parentGateStyle, parent.settings.parentGateStyle)
        .task {
            await parent.reload()
            openChildModeIfPauseIsRunning()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            openChildModeIfPauseIsRunning()
        }
        .onChange(of: selection) { _, new in
            handleSelection(new)
        }
        .fullScreenCover(item: $childMode) { request in
            HopHubView(
                environment: parent,
                startsInRoutine: request.startsInRoutine,
                onLeaveToGrownUps: { childMode = nil }
            )
            // Re-installed rather than relied upon: a presentation inherits the
            // environment of the view it is attached to, and both of these are
            // load-bearing enough — one is the child's whole world, the other is
            // the gate that gets the caregiver back — to be worth stating twice.
            .environment(parent)
            .environment(\.parentGateStyle, parent.settings.parentGateStyle)
        }
    }

    // MARK: Child mode

    /// Handles a tap on the Hop tab, or a click on the Hop row in the sidebar.
    ///
    /// The selection is put back before the cover animates up, so the pane
    /// behind child mode is the one the caregiver was reading and not an empty
    /// placeholder.
    private func handleSelection(_ new: ParentDestination?) {
        guard let new else { return }
        guard new == .hop else {
            lastPane = new
            return
        }
        selection = lastPane
        guard childMode == nil else { return }
        childMode = ChildModeRequest(startsInRoutine: false)
    }

    /// Opens child mode on the routine when the app comes forward during a live
    /// Potty Pause.
    ///
    /// Three conditions, and all three err toward *not* interrupting:
    ///
    /// * the App Group record says a shield may be standing — `SharedPauseState`
    ///   resolves every unknown to `.idle`, so a missing or unreadable record
    ///   opens nothing;
    /// * the pause has not reached the caregiver's intended end. Access is
    ///   restored at `plannedEndAt`, so a record that has passed it describes a
    ///   pause that is over even if reconciliation has not yet tidied it away —
    ///   and the cold-start pass may not have run yet when this does;
    /// * this pause has not already opened it.
    ///
    /// Nothing is written. The record's instants are `let` and no code path in
    /// HopPotty may lengthen a pause; this one could not if it wanted to.
    private func openChildModeIfPauseIsRunning() {
        guard childMode == nil else { return }
        let now = parent.clock.now
        guard let pause = parent.screenTime.appGroupSnapshot(now: now).pause else { return }
        guard pause.state.mayHaveShieldUp, pause.plannedEndAt > now else { return }
        guard autoStartedPauseSessionID != pause.sessionID else { return }

        autoStartedPauseSessionID = pause.sessionID
        childMode = ChildModeRequest(startsInRoutine: true)
    }

    // MARK: Compact

    private var tabLayout: some View {
        TabView(selection: Binding(get: { selection ?? .today }, set: { selection = $0 })) {
            NavigationStack { ParentHomeView() }
                .tabItem { Label(hop: HopCopy.parentHome.title, systemImage: "house") }
                .tag(ParentDestination.today)

            NavigationStack { ProgressDashboardView() }
                .tabItem {
                    Label(HopFeatureStrings.progressTitle, systemImage: "chart.bar")
                }
                .tag(ParentDestination.progress)

            // The door to Child Space, in the order the design puts it: Today,
            // Progress, Hop, Settings. Its content is never read — selecting
            // this tag presents the cover and hands the selection back within
            // the same update — so it is the ground colour rather than a second
            // copy of a screen, which would build a whole view tree to show for
            // one frame underneath a cover.
            Color.clear
                .hopBackground()
                .tabItem { Label(hop: HopCopy.childHub.tab, systemImage: ParentDestination.hop.systemImage) }
                .tag(ParentDestination.hop)

            NavigationStack { SettingsRootView() }
                .tabItem { Label(hop: HopCopy.settings.title, systemImage: "gearshape") }
                .tag(ParentDestination.settings)
        }
    }

    // MARK: Regular

    private var splitLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selection) {
                if let child = parent.activeChild, parent.hasMultipleChildren {
                    Section {
                        ForEach(parent.children) { candidate in
                            Button {
                                Task { await parent.selectChild(candidate.id) }
                            } label: {
                                ChildProfileRow(child: candidate, isActive: candidate.id == child.id)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text(hop: HopCopy.parentHome.childSwitcher)
                    }
                }

                Section {
                    ForEach(ParentDestination.allCases) { destination in
                        NavigationLink(value: destination) {
                            sidebarLabel(for: destination)
                        }
                    }
                }
            }
            .navigationTitle(Text(hop: HopCopy.brand.name))
        } detail: {
            NavigationStack {
                // `.hop` is grouped with `.today` because it is never really the
                // value here: `handleSelection` puts the selection back in the
                // same update that presents the cover, so this arm can only be
                // reached for a frame, and the dashboard is the honest thing to
                // draw behind Child Space.
                switch selection ?? .today {
                case .today, .hop: ParentHomeView()
                case .progress: ProgressDashboardView()
                case .settings: SettingsRootView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    /// Hop gets his own face in the sidebar, where a row can draw any view.
    ///
    /// The tab bar cannot: `tabItem` renders `Image` and `Text` and nothing
    /// else, so the phone's Hop tab uses the SF Symbol below. See
    /// ``ParentDestination/systemImage``.
    @ViewBuilder
    private func sidebarLabel(for destination: ParentDestination) -> some View {
        if destination == .hop {
            Label {
                Text(verbatim: destination.title)
            } icon: {
                HopChip(diameter: 22)
            }
        } else {
            Label(destination.title, systemImage: destination.systemImage)
        }
    }
}

/// Why child mode is on screen.
///
/// A value rather than a `Bool` pair, so "the caregiver handed the device over"
/// and "the app came forward during a pause" are two presentations that cannot
/// be confused, and so a stale flag cannot survive a dismissal.
private struct ChildModeRequest: Identifiable {
    let id = UUID()
    /// Whether the hub opens with the guided routine already on screen.
    let startsInRoutine: Bool
}

/// The four places the app's shell can take you — three panes and one door.
///
/// `hop` is the door. It is a `ParentDestination` because it lives in the
/// caregiver's tab bar and sidebar and is chosen the same way the panes are; it
/// is not a pane because choosing it leaves Parent Space entirely. Ordered as
/// the design renders it: Today, Progress, Hop, Settings.
enum ParentDestination: String, CaseIterable, Identifiable, Hashable {
    case today, progress, hop, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: HopCopy.parentHome.title.localized
        case .progress: HopFeatureStrings.progressTitle
        case .hop: HopCopy.childHub.tab.localized
        case .settings: HopCopy.settings.title.localized
        }
    }

    /// The SF Symbol for this destination.
    ///
    /// **Note on the Hop tab.** The design render (`Art/render/screens/01-parent-home.png`)
    /// draws Hop's own face in the tab bar, and the app does have a face
    /// component for it — ``HopChip``, which is `HopPose.idle` cropped to
    /// `HopPoseGeometry.faceCrop`. It cannot back a `tabItem`: SwiftUI renders
    /// only `Image` and `Text` inside one, and a drawn `View` is silently
    /// dropped. `HopChip` is therefore used in the iPad sidebar, where a row can
    /// draw anything, and the phone tab falls back to `face.smiling` until
    /// either the face ships as a rasterised asset the tab bar can load or the
    /// shell grows a custom tab bar.
    var systemImage: String {
        switch self {
        case .today: "house"
        case .progress: "chart.bar"
        case .hop: "face.smiling"
        case .settings: "gearshape"
        }
    }
}

/// Chooses between onboarding and the app.
///
/// Onboarding is not a modal over the dashboard: until a caregiver has finished
/// it there is no child, no schedule and nothing for a dashboard to show, so it
/// is the root.
struct ParentAppRootView: View {
    @Environment(ParentEnvironment.self) private var parent
    @State private var hasFinishedOnboarding: Bool?

    var body: some View {
        Group {
            switch hasFinishedOnboarding {
            case .some(true):
                ParentRootView()
            case .some(false):
                OnboardingFlowView(environment: parent) {
                    hasFinishedOnboarding = true
                }
            case .none:
                HopLoadingState(message: nil)
            }
        }
        .task {
            await parent.reload()
            hasFinishedOnboarding = parent.settings.hasCompletedOnboarding
        }
    }
}

#if DEBUG
#Preview("Shell, iPhone") {
    ParentRootView()
        .environment(ParentEnvironment.preview())
        .hopThemedRoot()
}

#Preview("Shell, two children") {
    ParentRootView()
        .environment(ParentEnvironment.preview(children: [HopFixtures.maya, HopFixtures.sam], entitlement: .family))
        .hopThemedRoot()
}

#Preview("Shell, dark AX3") {
    ParentRootView()
        .environment(ParentEnvironment.preview())
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
        .hopThemedRoot()
}

#Preview("First run, onboarding") {
    ParentAppRootView()
        .environment(ParentEnvironment.previewFirstRun())
        .hopThemedRoot()
}
#endif
