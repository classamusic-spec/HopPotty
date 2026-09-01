import SwiftUI
import HopPottyCore
#if DEBUG
// Sample children live in their own module so they can never reach a real
// family's data. Previews are the only callers.
import HopPottyFixtures
#endif

/// Adding or editing one child.
///
/// HopPotty asks for a nickname and a character. That is the whole form, and it
/// is deliberate: no legal name, no birthday, no photograph, no gender. Age
/// defaults come from the routine the caregiver chose, not from personal data —
/// see `ChildProfile`, which has nowhere to put any of it.
struct ChildProfileEditor: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(ParentEnvironment.self) private var parent

    /// `nil` creates a new child.
    let childID: UUID?

    @State private var nickname = ""
    @State private var avatar: HopAvatarStyle = .frogGreen
    @State private var isDeleteGatePresented = false
    @State private var deletionAuthorization: ParentAuthorization?
    @State private var receipt: DeletionReceipt?
    @State private var failure: ParentFailure?

    private var isNew: Bool { childID == nil }

    var body: some View {
        Form {
            Section {
                TextField(HopCopy.onboarding.namePlaceholder.localized, text: $nickname)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onChange(of: nickname) { _, newValue in
                        if newValue.count > ChildProfile.maxNicknameLength {
                            nickname = String(newValue.prefix(ChildProfile.maxNicknameLength))
                        }
                    }
            } header: {
                Text(hop: HopCopy.settings.childNickname)
            } footer: {
                Text(hop: HopCopy.settings.childNicknameFooter)
            }

            Section {
                AvatarPicker(selection: $avatar)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text(hop: HopCopy.settings.childAvatar)
            }

            if let childID, parent.children.count > 1 {
                Section {
                    Button(HopCopy.settings.childRemove.localized, role: .destructive) {
                        isDeleteGatePresented = true
                    }
                } footer: {
                    Text(hop: HopCopy.parentGate.deleteIrreversible)
                }
            }
        }
        // Attached to the form rather than to the section: a modifier applied
        // to a `Section` stops it being one, and the row loses its grouping.
        .hopParentGated(isPresented: $isDeleteGatePresented, reason: .deleteData) { granted in
            guard let childID else { return }
            Task {
                receipt = try? await parent.deletion.receipt(forChild: childID)
                deletionAuthorization = granted
            }
        }
        .navigationTitle(Text(hop: isNew ? HopCopy.settings.childAdd : HopCopy.settings.childNickname))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(HopCopy.common.save.localized) { Task { await save() } }
            }
        }
        .task { await load() }
        .sheet(item: $deletionAuthorization) { authorization in
            if let childID, let receipt {
                DestructiveConfirmationSheet(
                    title: HopCopy.parentGate.deleteChildTitle.localized(forNickname: nickname),
                    receipt: receipt,
                    isWorking: false
                ) {
                    Task {
                        _ = try? await parent.deletion.deleteChild(childID, authorization: authorization)
                        await parent.reload()
                        deletionAuthorization = nil
                        dismiss()
                    }
                }
            }
        }
        .alert(
            failure?.presentation.title ?? "",
            isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
        ) {
            Button(HopCopy.errors.dismissButton.localized) { failure = nil }
        } message: {
            Text(verbatim: failure?.presentation.message ?? "")
        }
    }

    private func load() async {
        guard let childID, let child = parent.children.first(where: { $0.id == childID }) else { return }
        nickname = child.nickname ?? ""
        avatar = child.avatar
    }

    private func save() async {
        var profile: ChildProfile
        if let childID, let existing = parent.children.first(where: { $0.id == childID }) {
            profile = existing
            profile.nickname = ChildProfile.sanitize(nickname)
            profile.avatar = avatar
            profile.modifiedAt = parent.clock.now
        } else {
            profile = ChildProfile(nickname: nickname, avatar: avatar)
        }
        do {
            try await parent.repositories.profiles.save(profile)
            // A new child needs a schedule, or the timer screen would open onto
            // nothing and the dashboard would have no cadence to project.
            if isNew {
                try await parent.repositories.schedules.save(PottySchedule(childID: profile.id))
            }
            await parent.reload()
            dismiss()
        } catch {
            failure = .saveFailed
        }
    }
}

/// The built-in character set. Illustrated, never a photograph.
struct AvatarPicker: View {
    @Environment(\.hopTheme) private var theme
    @Binding var selection: HopAvatarStyle

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 12) {
            ForEach(HopAvatarStyle.allCases) { style in
                Button {
                    selection = style
                } label: {
                    HopAvatar(style: style, size: 56)
                        .padding(6)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    style == selection ? theme.color.brandAction : Color.clear,
                                    lineWidth: 3
                                )
                        )
                }
                .buttonStyle(.plain)
                .hopHitTarget(theme.hitTarget.parent)
                .accessibilityLabel(Text(verbatim: style.rawValue))
                .accessibilityAddTraits(style == selection ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(theme.spacing.m)
    }
}

#if DEBUG
#Preview("Edit existing child") {
    NavigationStack { ChildProfileEditor(childID: HopFixtures.mayaChildID) }
        .environment(ParentEnvironment.preview(children: [HopFixtures.maya, HopFixtures.sam]))
        .hopThemedRoot()
}

#Preview("Add a child, AX3") {
    NavigationStack { ChildProfileEditor(childID: nil) }
        .environment(ParentEnvironment.preview())
        .environment(\.dynamicTypeSize, .accessibility3)
        .hopThemedRoot()
}

#Preview("Long nickname, dark") {
    NavigationStack { ChildProfileEditor(childID: HopFixtures.mayaChildID) }
        .environment(ParentEnvironment.previewLongNickname())
        .preferredColorScheme(.dark)
        .hopThemedRoot()
}
#endif
