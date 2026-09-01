import SwiftUI
import HopPottyCore

/// The confirmation every destructive action passes through.
///
/// It states exactly what will be removed, with counts, and it says "this cannot
/// be undone" once, plainly (`Docs/CONTRACTS.md` §4.6). What it does not do:
///
/// - no guilt-worded cancel ("No thanks, I don't want my child's progress");
/// - no pre-selected destructive button;
/// - no colour or size that makes Cancel harder to find than Delete;
/// - no "are you sure?" second round, which trains people to tap through.
///
/// The counts come from the repositories at the moment the sheet opens, not
/// from anything the app remembered earlier.
struct DestructiveConfirmationSheet: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let title: String
    let receipt: DeletionReceipt
    let isWorking: Bool
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                VStack(alignment: .leading, spacing: theme.spacing.s) {
                    Text(verbatim: title)
                        .font(theme.font(.parentTitle))
                        .foregroundStyle(theme.color.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(lines, id: \.self) { line in
                        Label {
                            Text(verbatim: line)
                                .font(theme.font(.parentBody))
                                .foregroundStyle(theme.color.textSecondary)
                        } icon: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(theme.color.textTertiary)
                        }
                    }

                    Text(hop: HopCopy.parentGate.deleteIrreversible)
                        .font(theme.font(.parentHeadline))
                        .foregroundStyle(theme.color.textPrimary)
                        .padding(.top, theme.spacing.xs)
                }
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                VStack(spacing: theme.spacing.s) {
                    if isWorking {
                        HopLoadingState(message: nil)
                    } else {
                        HopDestructiveButton(HopCopy.parentGate.deleteConfirm.localized, action: onConfirm)
                        // Cancel is a full-width, equally reachable control. It
                        // is not a small grey word in a corner.
                        HopSecondaryButton(HopCopy.common.cancel.localized) { dismiss() }
                    }
                }
            }
            .padding(theme.spacing.l)
            .hopReadableWidth()
            .frame(maxWidth: .infinity, alignment: .leading)
            .hopBackground(.primary)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    /// One sentence per kind of thing, and a plural-correct zero sentence rather
    /// than a hidden row: "No stars to remove" is information a caregiver wants
    /// before they tap.
    private var lines: [String] {
        var result: [String] = []
        if receipt.children > 0 {
            result.append(HopCopy.parentGate.deleteEverythingChildren.localized(for: receipt.children))
        }
        result.append(HopCopy.parentGate.deleteEvents.localized(for: receipt.events))
        result.append(HopCopy.parentGate.deleteStars.localized(for: receipt.stars))
        result.append(HopCopy.parentGate.deleteDecorations.localized(for: receipt.decorations))
        return result
    }
}

#if DEBUG
#Preview("Delete one child") {
    DestructiveConfirmationSheet(
        title: HopCopy.parentGate.deleteChildTitle.localized(forNickname: "Maya"),
        receipt: DeletionReceipt(childName: "Maya", events: 47, stars: 31, decorations: 6),
        isWorking: false,
        onConfirm: {}
    )
    .hopThemedRoot()
}

#Preview("Delete everything, AX3") {
    DestructiveConfirmationSheet(
        title: HopCopy.parentGate.deleteEverythingTitle.localized,
        receipt: DeletionReceipt(events: 412, stars: 260, decorations: 18, children: 2),
        isWorking: false,
        onConfirm: {}
    )
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopThemedRoot()
}

#Preview("Nothing to remove, dark") {
    DestructiveConfirmationSheet(
        title: HopCopy.parentGate.deleteChildTitle.localized(forNickname: nil),
        receipt: DeletionReceipt(),
        isWorking: false,
        onConfirm: {}
    )
    .preferredColorScheme(.dark)
    .hopThemedRoot()
}
#endif
