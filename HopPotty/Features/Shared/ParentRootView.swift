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
/// - **Compact** — a `TabView`. Three destinations, thumb-reachable, exactly
///   what Health and Fitness do on a phone.
/// - **Regular** — a `NavigationSplitView` with a persistent sidebar. On an iPad
///   the dashboard, the timer settings and Progress are all things a caregiver
///   moves between while comparing them, and a tab bar 1024 points wide with
///   three items in the middle is a phone layout wearing an iPad's clothes.
///
/// The sidebar also carries the child switcher, because on iPad there is room
/// to show which child every column is about instead of hiding it in a menu.
struct ParentRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(ParentEnvironment.self) private var parent

    @State private var selection: ParentDestination? = .today
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                splitLayout
            } else {
                tabLayout
            }
        }
        .environment(\.parentGateStyle, parent.settings.parentGateStyle)
        .task { await parent.reload() }
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
                            Label(destination.title, systemImage: destination.systemImage)
                        }
                    }
                }
            }
            .navigationTitle(Text(hop: HopCopy.brand.name))
        } detail: {
            NavigationStack {
                switch selection ?? .today {
                case .today: ParentHomeView()
                case .progress: ProgressDashboardView()
                case .settings: SettingsRootView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

/// The three places the parent app has.
enum ParentDestination: String, CaseIterable, Identifiable, Hashable {
    case today, progress, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: HopCopy.parentHome.title.localized
        case .progress: HopFeatureStrings.progressTitle
        case .settings: HopCopy.settings.title.localized
        }
    }

    var systemImage: String {
        switch self {
        case .today: "house"
        case .progress: "chart.bar"
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
