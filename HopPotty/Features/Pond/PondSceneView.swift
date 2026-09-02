import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

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
///
/// ## The pond is alive, quietly
///
/// The water carries a drifting `pond-ripples` and `pond-shimmer` layer on one
/// shared clock, and every unlocked decoration has a small idle of its own —
/// afloat, rooted, airborne or perfectly still, per ``HopPondIdle``. All of it
/// is scenery: it is slow, it is low-amplitude, it never arrives or leaves, and
/// **nothing in it rewards or asks for a tap**. A pond that was worth watching
/// would be an engagement mechanic (`Docs/ChildSafety.md` §1.4), and a pond that
/// pulsed would be the movement Reduce Motion exists to remove — so under
/// Reduce Motion every bit of it stops and the scene stands exactly as drawn.
struct PondSceneView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.childContext) private var context

    let unlocked: Set<PondItemID>
    /// The item the child is working toward, sketched in place. `nil` once the
    /// pond is complete.
    let nextUp: PondItem?
    /// Drawn on its lily pad in the middle of his own pond.
    var showsHop: Bool = true
    /// Whether the scene is a *place* rather than a picture.
    ///
    /// The pond screen shows the scene as an object on a page: a 4:3 card with
    /// rounded corners and a hairline, which is what makes it read as something
    /// the child owns and can look into. `HopHubView` uses the same drawing as
    /// the ground the child's home stands on, where a card edge halfway up the
    /// screen would be a frame around the room the child is standing in. The
    /// geometry needs no second set of numbers either way — every anchor in
    /// `PondCatalog` is in unit coordinates, so the scene simply takes the shape
    /// it is given.
    var isFullBleed: Bool = false
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
        .modifier(PondSceneFraming(isFullBleed: isFullBleed))
        // One element with a summary. Forty-one separately focusable sprites in
        // a picture is not navigation, it is a maze; the collection strip below
        // is the linear, per-item list VoiceOver actually wants.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HopCopy.a11y.pondScene.localized(forNickname: context.nickname))
        .accessibilityValue(HopCopy.pond.starCount.localized(for: context.totalStars))
    }
}

/// Gives the scene its shape: a card on a page, or the ground under a room.
///
/// A `ViewModifier` rather than an `if` in `body` because the two branches are
/// different concrete view types, and because the theme it needs for the corner
/// radius is only reachable from a real `View`.
private struct PondSceneFraming: ViewModifier {
    @Environment(\.hopTheme) private var theme
    let isFullBleed: Bool

    func body(content: Content) -> some View {
        if isFullBleed {
            content
        } else {
            content
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.hero, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radius.hero, style: .continuous)
                        .strokeBorder(
                            theme.color.divider.opacity(theme.isHighContrast ? 1 : 0.4),
                            lineWidth: theme.isHighContrast ? 1.5 : 0.75
                        )
                }
        }
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

                PondWaterSurface()
            }
        }
        .accessibilityHidden(true)
    }
}

/// The moving surface of the reward pond: `pond-ripples` drifting and a
/// `pond-shimmer` crossing the water.
///
/// One `Canvas` on one clock, clipped to the same ellipse `PondGround` fills.
/// It is the only per-frame work in the whole scene — the decorations above it
/// animate through the render server instead — and it stops entirely off screen,
/// in the background and under Reduce Motion.
private struct PondWaterSurface: View {
    @Environment(\.hopTheme) private var theme

    /// The water, in unit coordinates: the same ellipse `PondGround` draws.
    private static let bounds = CGRect(x: 0.11, y: 0.39, width: 0.78, height: 0.46)

    /// One ripple's place inside the water, as fractions of the water's own box.
    private struct RippleSpec {
        let x: CGFloat
        let y: CGFloat
        let span: CGFloat
        let opacity: Double
    }

    private static let ripples: [RippleSpec] = [
        RippleSpec(x: 0.10, y: 0.22, span: 0.24, opacity: 0.26),
        RippleSpec(x: 0.46, y: 0.48, span: 0.21, opacity: 0.20),
        RippleSpec(x: 0.16, y: 0.74, span: 0.19, opacity: 0.15),
    ]

    var body: some View {
        // Resolved out here so the render closure captures a colour rather than
        // a view that would read the environment at an unpredictable moment.
        let sheen = Color(HopPalette.white)
        let strength = theme.isDark ? 0.7 : 1.0
        return HopPondTimeline { clock in
            Canvas(rendersAsynchronously: false) { context, size in
                Self.draw(into: &context, size: size, clock: clock, sheen: sheen, strength: strength)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func draw(
        into context: inout GraphicsContext,
        size: CGSize,
        clock: HopPondClock,
        sheen: Color,
        strength: Double
    ) {
        let w = max(1, size.width)
        let h = max(1, size.height)
        let water = CGRect(
            x: bounds.minX * w,
            y: bounds.minY * h,
            width: bounds.width * w,
            height: bounds.height * h
        )
        var pond = context
        pond.clip(to: Path(ellipseIn: water))

        // pond-shimmer: a broad, soft band of light, well under a tenth of the
        // water's own contrast, sliding back and forth across it.
        let travel = CGFloat(clock.wave(period: HopMotion.pondShimmerPeriod)) * HopPondMotion.shimmerTravel * w
        let centre = water.midX + travel
        let reach = water.width * 0.55
        pond.fill(
            Path(water),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: sheen.opacity(0), location: 0),
                    .init(color: sheen.opacity(HopPondMotion.shimmerOpacity * strength), location: 0.5),
                    .init(color: sheen.opacity(0), location: 1),
                ]),
                startPoint: CGPoint(x: centre - reach, y: 0),
                endPoint: CGPoint(x: centre + reach, y: 0)
            )
        )

        // pond-ripples: each on its own phase, so the surface never moves as one
        // sheet. The drift is a couple of points over seven seconds.
        let unit = max(0.7, min(1.4, w / 393))
        for (index, spec) in ripples.enumerated() {
            let turn = HopPondMotion.phase(index + 1)
            let slide = CGFloat(clock.wave(period: HopMotion.pondRipplePeriod, phase: turn))
            let lift = CGFloat(clock.wave(period: HopMotion.pondRipplePeriod, phase: turn + 0.31))
            let origin = CGPoint(
                x: water.minX + spec.x * water.width + slide * HopPondMotion.rippleDrift * unit * 0.5,
                y: water.minY + spec.y * water.height + lift * HopPondMotion.rippleLift * unit
            )
            let span = spec.span * water.width * 0.5
            var path = Path()
            path.move(to: origin)
            path.addQuadCurve(
                to: CGPoint(x: origin.x + span, y: origin.y),
                control: CGPoint(x: origin.x + span * 0.5, y: origin.y - 6 * unit)
            )
            path.addQuadCurve(
                to: CGPoint(x: origin.x + span * 2, y: origin.y),
                control: CGPoint(x: origin.x + span * 1.5, y: origin.y + 6 * unit)
            )
            pond.stroke(
                path,
                with: .color(sheen.opacity(spec.opacity * strength)),
                style: StrokeStyle(lineWidth: 2.5 * unit, lineCap: .round)
            )
        }
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

    var body: some View {
        Button(action: onTap) {
            HopArtwork(.pondItem(item.id))
                .frame(width: side, height: side)
        }
        .buttonStyle(.plain)
        // Each decoration idles on its own phase, staggered by its rank, so a
        // row of lily pads breathes rather than pulsing as one raft. The design
        // system's ambient layer owns Reduce Motion here, not this file.
        .hopPondIdle(
            item.idle,
            extent: side,
            phase: HopPondMotion.phase(PondCatalog.rank(of: item.id))
        )
        .position(x: sceneSize.width * item.anchor.x, y: sceneSize.height * item.anchor.y)
        // The scene above is one accessibility element; the pieces inside it are
        // reachable through the collection strip instead.
        .accessibilityHidden(true)
    }
}

// MARK: - What each decoration does when nothing is happening

private extension PondItem {
    /// A pond has four kinds of thing in it: what floats, what is rooted, what
    /// is airborne, and what was built or dropped there and stays where it was
    /// put. A stone that swayed would be wrong in a way a four-year-old would
    /// notice before an adult did, so the switch is exhaustive with no
    /// `default`: a new decoration cannot ship without someone deciding which of
    /// the four it is.
    var idle: HopPondIdle {
        switch id {
        // Afloat.
        case .lilyPadSmall, .lilyPadLarge, .lilyFlower, .waterLilyCluster,
             .duckling, .turtleRock, .fishOrange, .fishBlue, .tadpoleFriend,
             .moonReflection:
            return .bob

        // Rooted, or hanging from something rooted.
        case .reedsLeft, .reedsRight, .cattails,
             .flowerYellow, .flowerPink, .flowerPurple,
             .mushroomCluster, .fernPatch, .blossomTree,
             .windChime, .lantern, .starLantern, .pondSwing:
            return .sway

        // Airborne.
        case .butterflyBlue, .butterflyYellow, .dragonfly, .fireflies, .cloudPuff:
            return .drift

        // Built, dropped, resting — or made of light, which does not wobble.
        case .stoneSmall, .stoneStack, .pebblePath, .driftwood,
             .snail, .ladybug,
             .rainbow, .sunbeam,
             .frogFriendGreen, .frogFriendBlue,
             .clubhouse, .signpost, .birdhouse:
            return .still
        }
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

/// Every decoration unlocked, so the four idles can be seen against each other:
/// pads bobbing, reeds swaying, the butterflies drifting, the stones and the
/// clubhouse holding perfectly still.
#Preview("Pond scene · complete") {
    PondSceneView(
        unlocked: Set(PondCatalog.items.map(\.id)),
        nextUp: nil,
        onTapItem: { _ in }
    )
    .padding()
    .hopBackground()
    .hopThemedRoot()
}

/// Nothing moves: no bob, no sway, no drift, no ripple, no shimmer — and the
/// pond is still the same pond, with every decoration at the place the catalog
/// put it.
#Preview("Pond scene · Reduce Motion") {
    PondSceneView(
        unlocked: Set(PondCatalog.unlockedItems(atStars: 180).map(\.id)),
        nextUp: PondCatalog.nextUnlock(after: 180),
        onTapItem: { _ in }
    )
    .padding()
    .hopBackground()
    .hopThemedRoot(reduceMotion: true)
}

#Preview("Pond scene · iPad width") {
    PondSceneView(
        unlocked: Set(PondCatalog.unlockedItems(atStars: 408).map(\.id)),
        nextUp: PondCatalog.nextUnlock(after: 408),
        onTapItem: { _ in }
    )
    .frame(width: 900)
    .padding()
    .hopBackground()
    .hopThemedRoot()
}
