import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import HopPottyCore

/// Handing the exported file to the caregiver.
///
/// A share sheet rather than a download: the file is written inside HopPotty's
/// own container and the caregiver decides where it goes — Files, Mail, nowhere.
/// Nothing is uploaded, which is the promise `HopCopy.settings.privacyExportFooter`
/// makes.
struct ExportShareSheet: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let url: URL

    var body: some View {
        NavigationStack {
            VStack(spacing: theme.spacing.l) {
                HopGlyphView(.check, size: 44, isDecorative: false)
                    .foregroundStyle(theme.color.success)
                Text(verbatim: HopFeatureStrings.exportReady)
                    .font(theme.font(.parentBody))
                    .foregroundStyle(theme.color.textSecondary)
                    .multilineTextAlignment(.center)
                ShareLink(item: url) {
                    Text(hop: HopCopy.settings.privacyExport)
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(theme.spacing.l)
            .hopReadableWidth()
            .hopBackground(.primary)
            .navigationTitle(Text(hop: HopCopy.settings.privacyExport))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(HopCopy.common.done.localized) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Third-party notices.
///
/// HopPotty links no third-party code today, so this states that rather than
/// showing an empty screen a caregiver would read as a bug.
struct AcknowledgementsView: View {
    @Environment(\.hopTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                Text(hop: HopCopy.onboarding.privacyBody)
                    .font(theme.font(.parentBody))
                    .foregroundStyle(theme.color.textSecondary)
            }
            .hopPageMargins()
            .padding(.vertical, theme.spacing.l)
            .hopReadableWidth()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .hopBackground(.primary)
        .navigationTitle(Text(hop: HopCopy.settings.aboutAcknowledgements))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
/// The entry point for the developer lab.
///
/// `#if DEBUG` at the call site in `SettingsRootView`, and the whole view is
/// compiled out of a release build — a debug menu that ships is a debug menu
/// that can shield a child's apps by accident.
struct DebugLabPlaceholderView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(ParentEnvironment.self) private var parent

    var body: some View {
        List {
            Section {
                ParentValueRow(
                    title: HopStrings.glyphShield,
                    value: parent.screenTime.authorizationStatus.rawValue
                )
                ParentValueRow(
                    title: HopStrings.glyphStar,
                    value: parent.purchases.entitlement.isUnlocked
                        ? HopFeatureStrings.settingsPurchasedBadge
                        : HopCopy.purchase.title.localized
                )
                ParentValueRow(
                    title: HopCopy.parentHome.childSwitcher.localized,
                    value: ParentFormat.count(parent.children.count)
                )
            } header: {
                Text(verbatim: HopFeatureStrings.settingsDebugLab)
            } footer: {
                Text(verbatim: HopFeatureStrings.settingsDebugLabFooter)
            }
        }
        .navigationTitle(Text(verbatim: HopFeatureStrings.settingsDebugLab))
    }
}
#endif

#if DEBUG
#Preview("Settings, free tier") {
    NavigationStack { SettingsRootView() }
        .environment(ParentEnvironment.preview(entitlement: .free))
        .hopThemedRoot()
}

#Preview("Settings, purchased") {
    NavigationStack { SettingsRootView() }
        .environment(ParentEnvironment.preview(entitlement: .family))
        .hopThemedRoot()
}

#Preview("Settings, notifications denied") {
    NavigationStack { SettingsRootView() }
        .environment(ParentEnvironment.preview(notificationPermission: .denied))
        .hopThemedRoot()
}

#Preview("Settings, store unavailable AX3 dark") {
    NavigationStack { SettingsRootView() }
        .environment(ParentEnvironment.preview(isStoreAvailable: false))
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
        .hopThemedRoot()
}
#endif
