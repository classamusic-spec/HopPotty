import SwiftUI
import HopPottyCore
#if DEBUG
// Sample children live in their own module so they can never reach a real
// family's data. Previews are the only callers.
import HopPottyFixtures
#endif

/// The child list.
///
/// Multi-child is first-class: each child has their own schedule, their own
/// timeline, their own stars and their own pond, and switching between them is
/// one tap from the dashboard. What the free tier limits is *how many* profiles
/// exist — never what an existing child can do, and never anything a child has
/// already earned.
struct ChildProfilesView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(ParentEnvironment.self) private var parent

    @State private var isAddPresented = false
    @State private var isPaywallGatePresented = false
    @State private var paywallAuthorization: ParentAuthorization?

    var body: some View {
        List {
            Section {
                ForEach(parent.children) { child in
                    NavigationLink {
                        ChildProfileEditor(childID: child.id)
                    } label: {
                        ChildProfileRow(child: child, isActive: child.id == parent.activeChildID)
                    }
                }
            } header: {
                Text(verbatim: HopFeatureStrings.settingsSectionChildren)
            }

            Section {
                if parent.canAddChild {
                    Button {
                        isAddPresented = true
                    } label: {
                        Label(hop: HopCopy.settings.childAdd, systemImage: "plus")
                    }
                } else {
                    HopLockedState(feature: .additionalChildren) {
                        isPaywallGatePresented = true
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            } footer: {
                if !parent.canAddChild {
                    Text(hop: HopCopy.purchase.freeFooter)
                }
            }
        }
        .navigationTitle(Text(verbatim: HopFeatureStrings.settingsSectionChildren))
        .sheet(isPresented: $isAddPresented) {
            ChildProfileEditor(childID: nil)
        }
        .hopParentGated(isPresented: $isPaywallGatePresented, reason: .purchase) { granted in
            paywallAuthorization = granted
        }
        .sheet(item: $paywallAuthorization) { authorization in
            PaywallView(authorization: authorization)
        }
        .task { await parent.reload() }
    }
}

struct ChildProfileRow: View {
    @Environment(\.hopTheme) private var theme
    let child: ChildProfile
    let isActive: Bool

    var body: some View {
        HStack(spacing: theme.spacing.m) {
            HopAvatar(style: child.avatar, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: child.nickname ?? HopCopy.pond.title.unnamed.localized)
                    .font(theme.font(.parentBody))
                    .foregroundStyle(theme.color.textPrimary)
                    .lineLimit(1)
                if isActive {
                    Text(verbatim: HopFeatureStrings.activeChildMarker)
                        .font(theme.font(.parentFootnote))
                        .foregroundStyle(theme.color.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// `ParentAuthorization` is not `Identifiable` by nature; this makes it usable
/// as a `sheet(item:)` trigger without inventing a second piece of state that
/// could disagree with it.
extension ParentAuthorization: Identifiable {
    var id: String { "\(reason.rawValue)-\(grantedAt.timeIntervalSince1970)" }
}

#if DEBUG
#Preview("One child, free tier") {
    NavigationStack { ChildProfilesView() }
        .environment(ParentEnvironment.preview(entitlement: .free))
        .hopThemedRoot()
}

#Preview("Two children, purchased") {
    NavigationStack { ChildProfilesView() }
        .environment(
            ParentEnvironment.preview(children: [HopFixtures.maya, HopFixtures.sam], entitlement: .family)
        )
        .hopThemedRoot()
}

#Preview("No nickname, AX3 dark") {
    NavigationStack { ChildProfilesView() }
        .environment(ParentEnvironment.previewEmpty())
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
        .hopThemedRoot()
}
#endif
