import SwiftUI
import HopPottyCore

/// Hop's Pond, drawn.
///
/// The scene is a real place rather than a grid of trophies: sky at the top, a
/// far bank behind, the water as an ellipse roughly centred on (0.5, 0.62), the
/// shore ringing it and the nearest things at the bottom — the geometry
/// `PondCatalog` documents and places every item against. Decorations composite
/// in `PondLayer` order, each at its own `PondAnchor` in unit coordinates, so
/// one layout is correct on every screen without a second set of numbers.
///
/// **Nothing here can remove anything.** There is no locked state drawn over an
/// item, no dimming of something once earned, no expiry and no re-lock: the only
/// input is the set of unlocked ids, and the only thing the view does with it is
/// draw. The one forward-looking element is the *next* item, sketched at the
/// place it will appear — that is an invitation, not a gap.
struct PondSceneView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.childContext) private var context

    let unlocked: Set<PondItemID>
    /// The item the child is working toward, sketched in place. `nil` once the
    /// pond is complete.
    let nextUp: PondItem?
    /// Drawn on its lily pad in the middle of his own pond.
    var showsHop: Bool = true
    let onTapItem: (PondItemID) -> Void

    private var itemsToDraw: [PondItem] {
        PondCatalog.items
            .filter { unlocked.contains($0.id) }
            // Back to front: by layer first, then by depth within the layer, so
            // a duckling nearer the viewer overlaps the reeds behind it.
            // `PondLayer` is `Comparable`, so this is the standard library's own
            // lexicographic tuple comparison, not a hand-rolled ordering.
            .sorted { ($0.layer, $0.anchor.y) < ($1.layer, $1.anchor.y) }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                PondGround()

                ForEach(itemsToDraw) { item in
                    PondItemView(item: item, sceneSize: size, onTap: { onTapItem(item.id) })
                        .hopTransition(.childArrive)
                }

                if showsHop {
                    HopCharacterStage(pose: .idle, size: size.width * 0.22)
                        .position(x: size.width * 0.5, y: size.height * 0.665)
                        .accessibilityHidden(true)
                }

                if let nextUp {
                    PondNextItemSketch(item: nextUp, sceneSize: size)
                }
            }
            .hopAnimation(.childArrive, value: unlocked)
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.radius.hero, style: .continuous)
                .strokeBorder(theme.color.divider.opacity(theme.isHighContrast ? 1 : 0.4), lineWidth: theme.isHighContrast ? 1.5 : 0.75)
        }
        // One element with a summary. Forty-one separately focusable sprites in
        // a picture is not navigation, it is a maze; the collection strip below
        // is the linear, per-item list VoiceOver actually wants.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HopCopy.a11y.pondScene.resolved(forNickname: context.nickname))
        .accessibilityValue(HopCopy.pond.starCount.resolved(for: context.totalStars))
    }
}

/// The pond itself, before anything has been unlocked.
///
/// Drawn rather than loaded so the scene is a recognisable place from the first
/// launch, when the child owns nothing and the item art may not have shipped.
private struct PondGround: View {
    @Environment(\.hopTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [
                        theme.color.brandSecondary.opacity(theme.isDark ? 0.45 : 0.30),
                        theme.color.backgroundSecondary,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // The far bank: a soft rise across the middle distance.
                Ellipse()
                    .fill(HopColors.wash(theme.color.success, isDark: theme.isDark))
                    .frame(width: size.width * 1.5, height: size.height * 0.62)
                    .position(x: size.width * 0.5, y: size.height * 0.46)

                // The water, at the centre PondCatalog places items against.
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.color.brandPrimary.opacity(theme.isDark ? 0.55 : 0.42),
                                theme.color.brandPrimary.opacity(theme.isDark ? 0.75 : 0.62),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size.width * 0.78, height: size.height * 0.46)
                    .position(x: size.width * 0.5, y: size.height * 0.62)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One unlocked decoration, at its anchor.
private struct PondItemView: View {
    @Environment(\.hopTheme) private var theme

    let item: PondItem
    let sceneSize: CGSize
    let onTap: () -> Void

    /// Base size before the anchor's own scale. A fraction of the scene width so
    /// a lily pad is the same size relative to the pond on every device.
    private var side: CGFloat {
        sceneSize.width * 0.155 * item.anchor.scale
    }

    /// Things that hang or hover drift a little; things that sit stay put. The
    /// float stops entirely under Reduce Motion — the design system's ambient
    /// layer owns that, not this file.
    private var floats: Bool {
        item.layer == .foreground || item.layer == .sky
    }

    var body: some View {
        Button(action: onTap) {
            HopArtwork(.pondItem(item.id))
                .frame(width: side, height: side)
        }
        .buttonStyle(.plain)
        .hopFloating(floats, distance: side * 0.05, period: 5.6)
        .position(x: sceneSize.width * item.anchor.x, y: sceneSize.height * item.anchor.y)
        // The scene above is one accessibility element; the pieces inside it are
        // reachable through the collection strip instead.
        .accessibilityHidden(true)
    }
}

/// The next decoration, sketched where it will appear.
///
/// Phrased and drawn forwards: an outline of something arriving, with what it
/// costs. It is never styled as a hole, a lock or a missing piece, because the
/// child has not lost it — they have not got to it yet.
private struct PondNextItemSketch: View {
    @Environment(\.hopTheme) private var theme

    let item: PondItem
    let sceneSize: CGSize

    private var side: CGFloat { sceneSize.width * 0.155 * item.anchor.scale }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.32, style: .continuous)
                .strokeBorder(
                    theme.color.brandAction.opacity(0.75),
                    style: StrokeStyle(lineWidth: 2.5, dash: [7, 6])
                )
                .frame(width: side, height: side)

            HopGlyphView(.star, size: side * 0.34)
                .foregroundStyle(theme.color.brandAction)
        }
        .position(x: sceneSize.width * item.anchor.x, y: sceneSize.height * item.anchor.y)
        .hopBreathing(amplitude: 0.02)
        .accessibilityHidden(true)
    }
}

#Preview("Pond scene · day one") {
    PondSceneView(
        unlocked: Set(PondCatalog.unlockedItems(atStars: 8).map(\.id)),
        nextUp: PondCatalog.nextUnlock(after: 8),
        onTapItem: { _ in }
    )
    .padding()
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Pond scene · mid progress") {
    PondSceneView(
        unlocked: Set(PondCatalog.unlockedItems(atStars: 180).map(\.id)),
        nextUp: PondCatalog.nextUnlock(after: 180),
        onTapItem: { _ in }
    )
    .padding()
    .hopBackground()
    .hopThemedRoot()
}
