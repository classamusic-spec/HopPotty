import SwiftUI
import HopPottyCore

/// Everything the child has collected, and the few things coming next.
///
/// This is the pond's accessible spine: the scene above is one summarised
/// element, and every decoration is individually reachable here, in unlock
/// order, with its own name and its own state. It is also where a child browses
/// with their finger, which is why each tile clears `HopHitTarget.childMinimum`
/// on its own.
///
/// Two states and no third: **Yours!**, or a star price. There is no "expired",
/// no "locked again", no timer on anything. `PondCatalog` has no API that could
/// produce one.
struct PondCollectionStrip: View {
    @Environment(\.hopTheme) private var theme

    let unlocked: Set<PondItemID>
    let stars: Int
    let onTapItem: (PondItemID) -> Void

    /// Everything owned, then a short look ahead. The whole catalog is 41 items
    /// and a child at three stars does not need to scroll past thirty-eight
    /// prices to find their lily pad.
    private var visibleItems: [PondItem] {
        let owned = PondCatalog.items.filter { unlocked.contains($0.id) }
        let ahead = PondCatalog.upcomingItems(atStars: stars).prefix(3)
        return owned + ahead
    }

    private var tileSide: CGFloat { theme.hitTarget.child }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            Text(HopCopy.pond.collectionTitle.value)
                .hopTextStyle(.parentTitle)
                .foregroundStyle(theme.color.textPrimary)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal) {
                HStack(spacing: theme.spacing.m) {
                    ForEach(visibleItems) { item in
                        PondCollectionTile(
                            item: item,
                            isUnlocked: unlocked.contains(item.id),
                            side: tileSide,
                            onTap: { onTapItem(item.id) }
                        )
                    }
                }
                .padding(.vertical, theme.spacing.xs)
                .padding(.horizontal, theme.spacing.xxs)
            }
            .scrollIndicators(.hidden)

            Text(HopCopy.pond.tapHint.value)
                .hopTextStyle(.parentCallout)
                .foregroundStyle(theme.color.textSecondary)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(HopCopy.pond.collectionTitle.value)
    }
}

/// One decoration in the strip.
private struct PondCollectionTile: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    let item: PondItem
    let isUnlocked: Bool
    let side: CGFloat
    let onTap: () -> Void

    private var name: String { PondItemNaming.name(for: item.id).value }

    /// What VoiceOver says about the tile's state. Never a deficit: an item
    /// still coming is announced by what it costs, not by what is missing.
    private var stateDescription: String {
        isUnlocked
            ? HopCopy.pond.itemUnlocked.value
            : HopCopy.pond.itemLocked.resolved(for: item.starCost)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: theme.spacing.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                        .fill(isUnlocked ? theme.color.surfaceElevated : theme.color.surfaceSunken)

                    HopArtwork(.pondItem(item.id))
                        .frame(width: side * 0.62, height: side * 0.62)
                        // An item still coming is a soft sketch of itself, so a
                        // child can see what is on its way. It is not greyed
                        // out: nothing here was ever theirs and taken back.
                        .opacity(isUnlocked ? 1 : 0.32)
                }
                .frame(width: side, height: side)
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                        .strokeBorder(
                            isUnlocked ? theme.color.celebration.opacity(0.8) : theme.color.divider,
                            lineWidth: isUnlocked ? 2 : 1
                        )
                }

                // The state is written as well as drawn: a person who cannot
                // separate the two borders by colour reads "Yours!" or a price.
                Label {
                    Text(stateDescription)
                        .hopTextStyle(.parentFootnote)
                } icon: {
                    HopGlyphView(isUnlocked ? .check : .star, size: 11)
                }
                .labelStyle(.titleAndIcon)
                .foregroundStyle(isUnlocked ? theme.color.textPrimary : theme.color.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: side, minHeight: side)
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: theme.radius.l)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(stateDescription)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Collection strip · early") {
    PondCollectionStrip(
        unlocked: Set(PondCatalog.unlockedItems(atStars: 8).map(\.id)),
        stars: 8,
        onTapItem: { _ in }
    )
    .padding()
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Collection strip · AX3") {
    PondCollectionStrip(
        unlocked: Set(PondCatalog.unlockedItems(atStars: 60).map(\.id)),
        stars: 60,
        onTapItem: { _ in }
    )
    .environment(\.dynamicTypeSize, .accessibility3)
    .padding()
    .hopBackground()
    .hopThemedRoot()
}
