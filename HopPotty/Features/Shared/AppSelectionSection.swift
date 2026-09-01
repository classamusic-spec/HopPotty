import SwiftUI
import HopPottyCore
#if canImport(FamilyControls)
import FamilyControls
#endif

/// "Choose apps", used by onboarding and by the timer settings screen.
///
/// The whole `FamilyActivitySelection` is persisted as one encoded blob rather
/// than three loose token sets, because that is what round-trips
/// `includeEntireCategory` — see `Docs/ScreenTimeArchitecture.md` §3. HopPotty
/// stores the blob, reads the *counts* out of it, and knows nothing else: the
/// tokens are opaque by design and the app is not entitled to look inside them.
///
/// The view never renders app names. `Label(applicationToken)` could show real
/// icons, but a list of a child's apps sitting on a parent screen is a privacy
/// surface HopPotty has no need for.
struct AppSelectionSection: View {
    @Environment(\.hopTheme) private var theme
    @Environment(ParentEnvironment.self) private var parent

    let childID: UUID
    var onChange: ((ScreenTimeConfiguration) -> Void)? = nil

    @State private var isPickerPresented = false
    @State private var configuration: ScreenTimeConfiguration?
    @State private var saveFailure: ParentFailure?

    #if canImport(FamilyControls)
    @State private var selection = FamilyActivitySelection()
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            summary
            picker
            if let saveFailure {
                Text(verbatim: saveFailure.presentation.message)
                    .font(theme.font(.parentFootnote))
                    .foregroundStyle(theme.color.warning)
            }
        }
        .task { await load() }
    }

    /// The picker button and the sheet it raises. The `FamilyControls` import is
    /// confined to this one property.
    @ViewBuilder
    private var picker: some View {
        #if canImport(FamilyControls)
        HopSecondaryButton(HopCopy.onboarding.appsPickButton.localized) {
            isPickerPresented = true
        }
        .familyActivityPicker(
            headerText: HopCopy.onboarding.appsTitle.localized,
            footerText: HopCopy.onboarding.appsBody.localized,
            isPresented: $isPickerPresented,
            selection: $selection
        )
        .onChange(of: selection) { _, _ in
            // Saved on every change rather than on dismiss: the picker can be
            // dismissed by a swipe, and a selection the caregiver made but that
            // never reached disk is the worst kind of silent failure.
            Task { await persistSelection() }
        }
        #else
        // Family Controls is unavailable in this build. The section still
        // renders its counts so the surrounding screen keeps its shape.
        EmptyView()
        #endif
    }

    @ViewBuilder
    private var summary: some View {
        let counts = configuration ?? ScreenTimeConfiguration(childID: childID)
        if counts.hasSelection {
            HStack(spacing: theme.spacing.m) {
                HopGlyphView(.shield, size: 22)
                    .foregroundStyle(theme.color.brandPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: ParentFormat.count(counts.totalSelectionCount))
                        .font(theme.font(.parentHeadline))
                        .monospacedDigit()
                    Text(hop: HopCopy.onboarding.appsBody)
                        .font(theme.font(.parentFootnote))
                        .foregroundStyle(theme.color.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            Text(hop: HopCopy.errors.screenTimeNoSelectionBody)
                .font(theme.font(.parentCallout))
                .foregroundStyle(theme.color.textSecondary)
        }
    }

    private func load() async {
        let snapshot = await parent.screenTime.snapshot(for: childID)
        configuration = snapshot.configuration
        #if canImport(FamilyControls)
        if let data = snapshot.selectionData,
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = decoded
        }
        #endif
    }

    private func persistSelection() async {
        #if canImport(FamilyControls)
        let data = try? JSONEncoder().encode(selection)
        do {
            let updated = try await parent.screenTime.saveSelection(data, for: childID)
            configuration = updated
            saveFailure = nil
            onChange?(updated)
        } catch {
            saveFailure = .saveFailed
        }
        #endif
    }
}
