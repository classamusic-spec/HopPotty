import SwiftUI
import HopPottyDesignTokens

/// Hop's pond, drawn as the ground the dashboard stands on rather than as a
/// picture placed on it.
///
/// This is the same place `PondScreen` shows, seen from a different crop: sky at
/// the top, a far bank behind, the water filling the middle, the near shore at
/// the bottom — the geometry `PondCatalog` documents and `PondSceneView` draws
/// against. It is deliberately *scenery only*. The reward screen owns the
/// child's unlocked decorations; Home is a view of the same pond, not a second
/// place to spend stars, so nothing here reads progress and nothing here can be
/// mistaken for something the child has or has not earned.
///
/// **One drawing, two appearances.** The scene keeps its own hues in light and
/// dark, and dusk is carried by a scrim over the top — which is what makes the
/// dark screen read as the same pond in the evening instead of a second, colder
/// pond. The scrim is the only reason a translucent pill or a countdown stays
/// legible over water, so it is driven by ``HopSemanticPalette/scrim`` rather
/// than by a hand-picked black.
///
/// ## Two canvases, one clock
///
/// The drawing is split by *whether it moves*, not by what it is:
///
/// - **`pond-still`** holds everything fixed — the sky gradient, the sun, the
///   far bank and its hills, the grass tufts, and the water gradient. These are
///   the four expensive fills in the scene and they are rasterised exactly once,
///   because this canvas sits outside the timeline and is never invalidated.
/// - **`pond-drift`** holds everything that moves, in its original draw order,
///   plus the near-shore band that has to cover the water layers. Only this
///   canvas is redrawn, at most thirty times a second, and everything in it is
///   a small path.
///
/// One ``HopPondTimeline`` drives the whole drift layer, so a dozen moving
/// things share one clock rather than owning a timer each — and that clock stops
/// dead under Reduce Motion, off screen, and whenever the scene phase is not
/// `.active`. Layer names mirror the ids the pond artwork exposes
/// (`pond-ripples`, `pond-lily-N`, `pond-reeds`, `pond-fish`, `pond-clouds`,
/// `pond-dragonfly`, `pond-shimmer`) so the SwiftUI pond and the SVG pond stay
/// legible side by side.
struct PondBackdropView: View {
    @Environment(\.hopTheme) private var theme

    /// Height of the drawing's own box. The view fills whatever it is given; the
    /// box is hung at the top and the near-shore colour continues below it, so a
    /// crop that ends below the drawing has no seam.
    let sceneHeight: CGFloat

    var body: some View {
        let ink = PondInk(theme: theme)
        let box = sceneHeight
        return ZStack {
            // pond-still. No timeline above it, so SwiftUI never re-runs this
            // renderer: the gradients are paid for once.
            Canvas(rendersAsynchronously: false) { context, size in
                ink.drawStill(into: &context, size: size, sceneHeight: box)
            }

            // pond-drift. Redrawn on the clock; small paths only.
            HopPondTimeline { clock in
                Canvas(rendersAsynchronously: false) { context, size in
                    ink.drawDrift(into: &context, size: size, sceneHeight: box, clock: clock)
                }
            }
        }
        // The strip behind the status bar is the sky's own top colour with the
        // scrim already composited into it, so it matches the first stop of the
        // gradient below and the bleed has no seam. The scrim itself stays
        // inside the drawing's frame — laying it over the strip as well would
        // darken that strip twice.
        .background { ink.bleed.ignoresSafeArea(edges: .top) }
        .overlay { dusk }
        .accessibilityHidden(true)
    }

    /// The evening pass over the water. Nothing but a scrim and one warm glow —
    /// the drawing underneath is unchanged.
    @ViewBuilder
    private var dusk: some View {
        if theme.isDark {
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: scrim(0.62), location: 0),
                        .init(color: scrim(0.50), location: 0.40),
                        .init(color: scrim(0.68), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [Color(HopPalette.lavender).opacity(0.26), Color(HopPalette.lavender).opacity(0)],
                    center: UnitPoint(x: 0.22, y: 0.06),
                    startRadius: 0,
                    endRadius: max(1, sceneHeight)
                )
            }
            .allowsHitTesting(false)
        }
    }

    private func scrim(_ opacity: Double) -> Color {
        Color(theme.color.values.scrim.opacity(opacity))
    }
}

// MARK: - Where everything is

/// The scene's band lines, resolved once from the box it was given.
///
/// Both canvases build one of these from the same two numbers, which is what
/// guarantees the still half and the drifting half agree about where the water
/// line is. A second copy of `h * 0.40` in the other renderer would be a seam
/// waiting to happen.
private struct PondLayout {
    let w: CGFloat
    let h: CGFloat
    /// The horizon.
    let sky: CGFloat
    /// The water line.
    let water: CGFloat
    /// Where the near shore begins.
    let shore: CGFloat
    /// Ornament sizes are authored against a 393pt phone. They are allowed to
    /// drift a little with the width so a reed is not a blade of grass on a
    /// small phone and not a tree on an iPad, but they do not scale linearly:
    /// this is a landscape, and things in it keep their own size.
    let u: CGFloat

    init(width: CGFloat, height: CGFloat) {
        w = max(1, width)
        h = max(1, height)
        sky = h * 0.28
        water = h * 0.40
        shore = h * 0.735
        u = min(1.25, max(0.8, w / 393))
    }
}

// MARK: - The drawing

/// Every colour the pond is drawn in, resolved once so the render closure
/// captures values rather than a view.
///
/// The hues come from ``HopPalette`` rather than from the semantic palette on
/// purpose: this is a *drawing*, and a drawing whose greens and blues swapped
/// between appearances would stop being the same pond. What does change with the
/// appearance is the scrim above it, and the one token read here — the sky's
/// bleed colour — is composited through it.
private struct PondInk {
    let bleed: Color

    private let skyTop: Color
    private let skyBottom: Color
    private let sun: Color
    private let cloud: Color
    private let farBank: Color
    private let hill: Color
    private let tuft: Color
    private let waterTop: Color
    private let waterMid: Color
    private let waterDeep: Color
    private let ripple: Color
    private let shoreTop: Color
    private let shoreBottom: Color
    private let padNear: Color
    private let padFar: Color
    private let padNotch: Color
    private let padSheen: Color
    private let reedDark: Color
    private let reedLight: Color
    private let cattail: Color
    private let petal: Color
    private let heart: Color
    private let fish: Color
    private let wingNear: Color
    private let wingFar: Color
    private let ink: Color

    init(theme: HopTheme) {
        let skyTopValue = PondInk.mix(HopPalette.pondBlueSoft, HopPalette.pondBlueLight, 0.34)
        skyTop = Color(skyTopValue)
        skyBottom = Color(PondInk.mix(HopPalette.cloud, HopPalette.sunshineSoft, 0.45))
        sun = Color(HopPalette.sunshine).opacity(0.5)
        cloud = Color(HopPalette.white)
        farBank = Color(PondInk.mix(HopPalette.hopGreenSoft, HopPalette.hopGreenLight, 0.55))
        hill = Color(PondInk.mix(HopPalette.hopGreenLight, HopPalette.hopGreen, 0.45))
        tuft = Color(PondInk.mix(HopPalette.hopGreen, HopPalette.hopGreenDeep, 0.2))
        waterTop = Color(PondInk.mix(HopPalette.pondBlueLight, HopPalette.cloud, 0.3))
        waterMid = Color(HopPalette.pondBlue)
        waterDeep = Color(PondInk.mix(HopPalette.pondBlue, HopPalette.pondBlueDeep, 0.5))
        ripple = Color(HopPalette.white)
        shoreTop = Color(HopPalette.hopGreenLight)
        shoreBottom = Color(PondInk.mix(HopPalette.hopGreenLight, HopPalette.hopGreen, 0.75))
        padNear = Color(PondInk.mix(HopPalette.hopGreen, HopPalette.hopGreenDeep, 0.3))
        padFar = Color(PondInk.mix(HopPalette.hopGreen, HopPalette.hopGreenLight, 0.35))
        padNotch = Color(HopPalette.pondBlueSoft).opacity(0.55)
        padSheen = Color(HopPalette.white).opacity(0.18)
        reedDark = Color(HopPalette.hopGreenDeep)
        reedLight = Color(HopPalette.hopGreenLight)
        cattail = Color(HopPalette.sand300)
        petal = Color(HopPalette.white)
        heart = Color(HopPalette.sunshine)
        fish = Color(HopPalette.peachPop)
        wingNear = Color(HopPalette.pondBlue)
        wingFar = Color(HopPalette.pondBlueLight)
        ink = Color(HopPalette.midnight)

        // Composited rather than layered so the strip above the drawing matches
        // the first stop of the scrim gradient exactly.
        bleed = theme.isDark
            ? Color(theme.color.values.scrim.opacity(0.62).composited(over: skyTopValue))
            : Color(skyTopValue)
    }

    // MARK: pond-still

    /// Everything that does not move, drawn once.
    func drawStill(into context: inout GraphicsContext, size: CGSize, sceneHeight: CGFloat) {
        let l = PondLayout(width: size.width, height: min(sceneHeight, size.height))

        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(skyTop))
        if size.height > l.h {
            context.fill(
                Path(CGRect(x: 0, y: l.h, width: l.w, height: size.height - l.h)),
                with: .color(shoreBottom)
            )
        }

        var scene = context
        scene.clip(to: Path(CGRect(x: 0, y: 0, width: l.w, height: l.h)))

        scene.fill(
            Path(CGRect(x: 0, y: 0, width: l.w, height: l.h)),
            with: .linearGradient(
                Gradient(colors: [skyTop, skyBottom]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: l.h)
            )
        )

        let sunCentre = CGPoint(x: l.w * 0.17, y: l.sky * 0.42)
        let sunRadius = l.w * 0.42
        scene.fill(
            Path(ellipseIn: CGRect(
                x: sunCentre.x - sunRadius,
                y: sunCentre.y - sunRadius,
                width: sunRadius * 2,
                height: sunRadius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [sun, sun.opacity(0)]),
                center: sunCentre,
                startRadius: 0,
                endRadius: sunRadius
            )
        )

        drawFarBank(into: &scene, layout: l)
        scene.fill(waterPath(l), with: waterShading(l))
    }

    /// The far bank, its hills and the grass on the waterline. The bank's reeds
    /// are not here — they sway, so they belong to the drift layer, and they sit
    /// entirely above the water line so drawing them later changes nothing.
    private func drawFarBank(into context: inout GraphicsContext, layout l: PondLayout) {
        let w = l.w
        let u = l.u
        let sky = l.sky
        let water = l.water

        var bank = Path()
        bank.move(to: CGPoint(x: 0, y: sky + 26 * u))
        bank.addCurve(
            to: CGPoint(x: w * 0.78, y: sky + 18 * u),
            control1: CGPoint(x: w * 0.22, y: sky - 24 * u),
            control2: CGPoint(x: w * 0.58, y: sky - 18 * u)
        )
        bank.addCurve(
            to: CGPoint(x: w, y: sky + 22 * u),
            control1: CGPoint(x: w * 0.90, y: sky + 40 * u),
            control2: CGPoint(x: w * 0.96, y: sky + 30 * u)
        )
        bank.addLine(to: CGPoint(x: w, y: water + 30 * u))
        bank.addLine(to: CGPoint(x: 0, y: water + 30 * u))
        bank.closeSubpath()
        context.fill(bank, with: .color(farBank))

        // The rise behind the bank. Not decorations: a pond with nothing
        // unlocked is still a place.
        var hills = context
        hills.opacity = 0.55
        for (x, rx, ry, dy) in [(0.08, 42.0, 26.0, 20.0), (0.38, 34.0, 20.0, 8.0), (0.72, 46.0, 24.0, 26.0), (0.96, 30.0, 18.0, 18.0)] {
            let radiusX = CGFloat(rx) * u
            let radiusY = CGFloat(ry) * u
            hills.fill(
                Path(ellipseIn: CGRect(
                    x: w * CGFloat(x) - radiusX,
                    y: sky + CGFloat(dy) * u - radiusY,
                    width: radiusX * 2,
                    height: radiusY * 2
                )),
                with: .color(hill)
            )
        }

        for (x, dy) in [(0.50, 4.0), (0.86, 2.0), (0.16, 6.0)] {
            drawTuft(into: &context, at: CGPoint(x: w * CGFloat(x), y: water + CGFloat(dy) * u), scale: 0.55 * u)
        }
    }

    // MARK: pond-drift

    /// Everything that moves, in the order the scene draws it — plus the near
    /// shore, which has to stay on top of the water layers.
    ///
    /// One rule holds this split together: nothing in here may overlap anything
    /// the still canvas draws *after* it would have been drawn originally. The
    /// clouds clear the far bank's crest by a wide margin at every size the pond
    /// is used at, so they need nothing. The far bank's reeds root *just* above
    /// the water line — with a landscape phone's crop they root within a point
    /// of it — so they are drawn against the inverse of the water instead, which
    /// is exactly what the water fill did for them before.
    func drawDrift(
        into context: inout GraphicsContext,
        size: CGSize,
        sceneHeight: CGFloat,
        clock: HopPondClock
    ) {
        let l = PondLayout(width: size.width, height: min(sceneHeight, size.height))
        var scene = context
        scene.clip(to: Path(CGRect(x: 0, y: 0, width: l.w, height: l.h)))

        let w = l.w
        let h = l.h
        let u = l.u

        // pond-clouds. Bounded drift, horizontal only: a cloud that entered from
        // the edge would be a new thing appearing behind a countdown.
        let cloudFar = CGFloat(clock.wave(period: HopMotion.pondCloudDriftPeriod, phase: HopPondMotion.phase(1)))
        let cloudNear = CGFloat(clock.wave(period: HopMotion.pondCloudDriftPeriod, phase: HopPondMotion.phase(4)))
        drawCloud(
            into: &scene,
            at: CGPoint(x: w * 0.74 + cloudFar * HopPondMotion.cloudDrift * u, y: l.sky * 0.34),
            scale: 0.95 * u,
            opacity: 0.9
        )
        // The higher, fainter cloud is further away, so it moves less. That is
        // the only parallax in the scene and it is deliberately tiny.
        drawCloud(
            into: &scene,
            at: CGPoint(x: w * 0.28 + cloudNear * HopPondMotion.cloudDrift * 0.6 * u, y: l.sky * 0.20),
            scale: 0.55 * u,
            opacity: 0.42
        )

        // pond-reeds, far bank. Clipped out of the water rather than trusted to
        // clear it: the stroke's round cap hangs a couple of points below the
        // root, and on a landscape crop the root itself sits within a point of
        // the water line.
        var bankAir = scene
        bankAir.clip(to: waterPath(l), options: .inverse)
        drawReeds(
            into: &bankAir,
            at: CGPoint(x: w * 0.20, y: l.sky + 30 * u),
            scale: 0.7 * u,
            clock: clock,
            phase: HopPondMotion.phase(2)
        )

        // pond-ripples. Each slides and lifts on its own phase, so the surface
        // never moves as one sheet.
        for (index, spec) in PondInk.ripples.enumerated() {
            let turn = HopPondMotion.phase(11 + index)
            let slide = CGFloat(clock.wave(period: HopMotion.pondRipplePeriod, phase: turn))
            let lift = CGFloat(clock.wave(period: HopMotion.pondRipplePeriod, phase: turn + 0.31))
            drawRipple(
                into: &scene,
                at: CGPoint(
                    x: w * spec.x + slide * HopPondMotion.rippleDrift * u,
                    y: l.water + spec.dy * u + lift * HopPondMotion.rippleLift * u
                ),
                span: spec.span * u,
                opacity: spec.opacity,
                unit: u
            )
        }

        // pond-shimmer. A wide, very low band of light crossing the water.
        drawShimmer(
            into: &scene,
            layout: l,
            offset: CGFloat(clock.wave(period: HopMotion.pondShimmerPeriod, phase: HopPondMotion.phase(0)))
                * HopPondMotion.shimmerTravel * w
        )

        // pond-lily-1 and pond-lily-2. The roll trails the bob by a quarter
        // turn, which is what makes a pad look like it is riding water rather
        // than being waved at the viewer.
        drawFloatingPad(
            into: &scene,
            at: CGPoint(x: w * 0.22, y: h * 0.66),
            scale: 0.8 * u,
            tone: padFar,
            lift: 2.2 * u,
            clock: clock,
            phase: HopPondMotion.phase(6)
        )
        drawFloatingPad(
            into: &scene,
            at: CGPoint(x: w * 0.30, y: h * 0.585),
            scale: 0.95 * u,
            tone: padFar,
            lift: 2.6 * u,
            clock: clock,
            phase: HopPondMotion.phase(9)
        )

        // pond-fish. A long flat loop rather than a traverse: it always passes
        // back through the place the still pond draws it, and it never leaves.
        let fishTurn = HopPondMotion.phase(3)
        drawFish(
            into: &scene,
            at: CGPoint(
                x: w * 0.72 - CGFloat(clock.wave(period: HopMotion.pondFishPeriod, phase: fishTurn))
                    * HopPondMotion.fishTravel * u,
                y: h * 0.64 + CGFloat(clock.rise(period: HopMotion.pondFishPeriod, phase: fishTurn))
                    * HopPondMotion.fishLift * u
            ),
            scale: u
        )

        // The blossom on the water: it stirs, it does not travel. A flower that
        // slid would look like it had come loose from its stem.
        let stirTurn = HopPondMotion.phase(7)
        drawFlower(
            into: &scene,
            at: CGPoint(
                x: w * 0.78,
                y: h * 0.545 + CGFloat(clock.wave(period: HopMotion.pondLilyBobPeriod, phase: stirTurn)) * 1.5 * u
            ),
            scale: 0.9 * u,
            stir: clock.wave(period: HopMotion.pondLilyBobPeriod, phase: stirTurn + 0.5)
                * HopPondMotion.blossomStirDegrees
        )

        // pond-lily-3: Hop's own pad, and the only thing in the water that holds
        // perfectly still. `HomePondMetrics.padPoint` is this exact point and
        // Hop is placed against it, so a pad that bobbed would leave him hanging
        // in the air a few points above his own feet.
        drawLilyPad(into: &scene, at: CGPoint(x: w * 0.56, y: h * 0.508), scale: 1.6 * u, tone: padNear)

        drawNearShore(into: &scene, layout: l, clock: clock)
    }

    private func drawNearShore(into context: inout GraphicsContext, layout l: PondLayout, clock: HopPondClock) {
        let w = l.w
        let h = l.h
        let u = l.u
        let shore = l.shore

        var bank = Path()
        bank.move(to: CGPoint(x: 0, y: shore + 12 * u))
        bank.addCurve(
            to: CGPoint(x: w, y: shore + 6 * u),
            control1: CGPoint(x: w * 0.26, y: shore - 26 * u),
            control2: CGPoint(x: w * 0.68, y: shore - 22 * u)
        )
        bank.addLine(to: CGPoint(x: w, y: h))
        bank.addLine(to: CGPoint(x: 0, y: h))
        bank.closeSubpath()
        context.fill(
            bank,
            with: .linearGradient(
                Gradient(colors: [shoreTop, shoreBottom]),
                startPoint: CGPoint(x: 0, y: shore - 26 * u),
                endPoint: CGPoint(x: 0, y: h)
            )
        )

        // pond-reeds, near shore.
        drawReeds(
            into: &context,
            at: CGPoint(x: w * 0.08, y: shore + 16 * u),
            scale: 1.15 * u,
            clock: clock,
            phase: HopPondMotion.phase(8)
        )
        drawReeds(
            into: &context,
            at: CGPoint(x: w * 0.93, y: shore + 10 * u),
            scale: 1.0 * u,
            clock: clock,
            phase: HopPondMotion.phase(10)
        )

        // pond-dragonfly. Wave and rise are quadrature, so the butterfly traces
        // a shallow oval that always returns through its authored point.
        let flitTurn = HopPondMotion.phase(5)
        drawButterfly(
            into: &context,
            at: CGPoint(
                x: w * 0.19 + CGFloat(clock.wave(period: HopMotion.pondDragonflyPeriod, phase: flitTurn))
                    * HopPondMotion.flitTravel * u,
                y: h * 0.44 + CGFloat(clock.rise(period: HopMotion.pondDragonflyPeriod, phase: flitTurn))
                    * HopPondMotion.flitLift * u
            ),
            scale: u,
            flutter: clock.wave(period: HopMotion.pondDragonflyPeriod, phase: flitTurn + 0.25)
                * HopPondMotion.flitWingDegrees
        )
    }

    // MARK: Water

    /// One ripple's authored place on the surface.
    private struct RippleSpec {
        let x: CGFloat
        let dy: CGFloat
        let opacity: Double
        let span: CGFloat
    }

    private static let ripples: [RippleSpec] = [
        RippleSpec(x: 0.08, dy: 46, opacity: 0.30, span: 52),
        RippleSpec(x: 0.50, dy: 92, opacity: 0.22, span: 48),
        RippleSpec(x: 0.04, dy: 150, opacity: 0.18, span: 48),
        RippleSpec(x: 0.52, dy: 196, opacity: 0.16, span: 44),
    ]

    private func waterPath(_ l: PondLayout) -> Path {
        var pond = Path()
        pond.move(to: CGPoint(x: 0, y: l.water + 8 * l.u))
        pond.addCurve(
            to: CGPoint(x: l.w, y: l.water + 10 * l.u),
            control1: CGPoint(x: l.w * 0.30, y: l.water - 18 * l.u),
            control2: CGPoint(x: l.w * 0.72, y: l.water - 14 * l.u)
        )
        pond.addLine(to: CGPoint(x: l.w, y: l.h))
        pond.addLine(to: CGPoint(x: 0, y: l.h))
        pond.closeSubpath()
        return pond
    }

    private func waterShading(_ l: PondLayout) -> GraphicsContext.Shading {
        .linearGradient(
            Gradient(stops: [
                .init(color: waterTop, location: 0),
                .init(color: waterMid, location: 0.35),
                .init(color: waterDeep, location: 1),
            ]),
            startPoint: CGPoint(x: 0, y: l.water - 18 * l.u),
            endPoint: CGPoint(x: 0, y: l.h)
        )
    }

    /// A broad, soft sheen sliding over the water.
    ///
    /// Clipped to the water so it cannot light the bank, and capped at
    /// ``HopPondMotion/shimmerOpacity`` — at that strength the brightest point
    /// of the water changes by about five per cent of white over four and a half
    /// seconds, which is a shimmer rather than a highlight sweeping past.
    private func drawShimmer(into context: inout GraphicsContext, layout l: PondLayout, offset: CGFloat) {
        var water = context
        water.clip(to: waterPath(l))
        let centre = l.w * 0.5 + offset
        let reach = l.w * 0.42
        water.fill(
            Path(CGRect(x: 0, y: l.water - 20 * l.u, width: l.w, height: l.h - l.water + 20 * l.u)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: ripple.opacity(0), location: 0),
                    .init(color: ripple.opacity(HopPondMotion.shimmerOpacity), location: 0.5),
                    .init(color: ripple.opacity(0), location: 1),
                ]),
                startPoint: CGPoint(x: centre - reach, y: 0),
                endPoint: CGPoint(x: centre + reach, y: 0)
            )
        )
    }

    // MARK: Ornaments

    private func drawCloud(into context: inout GraphicsContext, at p: CGPoint, scale s: CGFloat, opacity: Double) {
        var path = Path()
        path.addEllipse(in: CGRect(x: p.x - 52 * s, y: p.y - 11 * s, width: 104 * s, height: 34 * s))
        path.addEllipse(in: CGRect(x: p.x - 37 * s, y: p.y - 21 * s, width: 38 * s, height: 38 * s))
        path.addEllipse(in: CGRect(x: p.x - 16 * s, y: p.y - 33 * s, width: 48 * s, height: 48 * s))
        path.addEllipse(in: CGRect(x: p.x + 16 * s, y: p.y - 16 * s, width: 32 * s, height: 32 * s))
        context.fill(path, with: .color(cloud.opacity(opacity)))
    }

    /// A clump of reeds, rocking about its own roots.
    ///
    /// Each blade carries its own phase offset, so the clump breathes instead of
    /// tilting as one rigid block — which is the difference between grass in air
    /// and a signpost being pushed over. The cattail head rides the blade it
    /// grows on, at that blade's angle, so it never drifts off its stem.
    private func drawReeds(
        into context: inout GraphicsContext,
        at p: CGPoint,
        scale s: CGFloat,
        clock: HopPondClock,
        phase: Double
    ) {
        func sway(_ turns: Double) -> CGFloat {
            CGFloat(clock.wave(period: HopMotion.pondReedSwayPeriod, phase: phase + turns)
                * HopMotion.pondSwayDegrees)
        }
        func rooted(_ path: Path, _ degrees: CGFloat) -> Path {
            guard degrees != 0 else { return path }
            let rotation = CGAffineTransform(translationX: p.x, y: p.y)
                .rotated(by: degrees * .pi / 180)
                .translatedBy(x: -p.x, y: -p.y)
            return path.applying(rotation)
        }
        func blade(_ dx: CGFloat, _ length: CGFloat, _ lean: CGFloat, _ colour: Color, _ turns: Double) {
            var path = Path()
            path.move(to: CGPoint(x: p.x + dx * s, y: p.y))
            path.addCurve(
                to: CGPoint(x: p.x + (dx + lean * 1.2) * s, y: p.y - length * s),
                control1: CGPoint(x: p.x + (dx + lean * 0.3) * s, y: p.y - length * 0.5 * s),
                control2: CGPoint(x: p.x + (dx + lean) * s, y: p.y - length * 0.8 * s)
            )
            context.stroke(
                rooted(path, sway(turns)),
                with: .color(colour),
                style: StrokeStyle(lineWidth: 6 * s, lineCap: .round)
            )
        }
        blade(-14, 54, -12, reedDark, 0)
        blade(0, 74, 4, reedDark, 0.11)
        blade(13, 46, 14, reedLight, 0.23)
        context.fill(
            rooted(
                Path(ellipseIn: CGRect(x: p.x - 6 * s, y: p.y - 90 * s, width: 12 * s, height: 28 * s)),
                sway(0.11)
            ),
            with: .color(cattail)
        )
    }

    private func drawTuft(into context: inout GraphicsContext, at p: CGPoint, scale s: CGFloat) {
        for (dx, dy, cx, cy) in [(-9.0, -17.0, -8.0, -8.0), (0.0, -22.0, 0.0, -10.0), (9.0, -16.0, 9.0, -7.0)] {
            var path = Path()
            path.move(to: CGPoint(x: p.x + CGFloat(dx) * s, y: p.y))
            path.addQuadCurve(
                to: CGPoint(x: p.x + CGFloat(dx) * 0.4 * s, y: p.y + CGFloat(dy) * s),
                control: CGPoint(x: p.x + CGFloat(cx) * s, y: p.y + CGFloat(cy) * s)
            )
            context.stroke(path, with: .color(tuft), style: StrokeStyle(lineWidth: 4 * s, lineCap: .round))
        }
    }

    private func drawRipple(into context: inout GraphicsContext, at p: CGPoint, span: CGFloat, opacity: Double, unit u: CGFloat) {
        var path = Path()
        path.move(to: p)
        path.addQuadCurve(
            to: CGPoint(x: p.x + span, y: p.y),
            control: CGPoint(x: p.x + span * 0.5, y: p.y - 10 * u)
        )
        path.addQuadCurve(
            to: CGPoint(x: p.x + span * 2, y: p.y),
            control: CGPoint(x: p.x + span * 1.5, y: p.y + 10 * u)
        )
        context.stroke(
            path,
            with: .color(ripple.opacity(opacity)),
            style: StrokeStyle(lineWidth: 4 * u, lineCap: .round)
        )
    }

    /// A lily pad riding the water: it rises and settles, and rolls a quarter
    /// turn behind the rise.
    private func drawFloatingPad(
        into context: inout GraphicsContext,
        at p: CGPoint,
        scale s: CGFloat,
        tone: Color,
        lift: CGFloat,
        clock: HopPondClock,
        phase: Double
    ) {
        let bob = CGFloat(clock.wave(period: HopMotion.pondLilyBobPeriod, phase: phase))
        let roll = clock.wave(period: HopMotion.pondLilyBobPeriod, phase: phase + 0.25)
        drawLilyPad(
            into: &context,
            at: CGPoint(x: p.x, y: p.y + bob * lift),
            scale: s,
            tone: tone,
            roll: roll * HopPondMotion.lilyRollDegrees
        )
    }

    private func drawLilyPad(
        into context: inout GraphicsContext,
        at p: CGPoint,
        scale s: CGFloat,
        tone: Color,
        roll: Double = 0
    ) {
        // The same translate-rotate-translate the reeds use, so the pad turns
        // about its own centre rather than about the corner of the scene.
        let turn: CGAffineTransform? = roll == 0
            ? nil
            : CGAffineTransform(translationX: p.x, y: p.y)
                .rotated(by: CGFloat(roll) * .pi / 180)
                .translatedBy(x: -p.x, y: -p.y)
        func rolled(_ path: Path) -> Path { turn.map { path.applying($0) } ?? path }

        context.fill(
            rolled(Path(ellipseIn: CGRect(x: p.x - 34 * s, y: p.y - 13 * s, width: 68 * s, height: 26 * s))),
            with: .color(tone)
        )
        var notch = Path()
        notch.move(to: p)
        notch.addLine(to: CGPoint(x: p.x + 26 * s, y: p.y - 8 * s))
        notch.addLine(to: CGPoint(x: p.x + 20 * s, y: p.y - 10 * s))
        notch.closeSubpath()
        context.fill(rolled(notch), with: .color(padNotch))
        context.fill(
            rolled(Path(ellipseIn: CGRect(x: p.x - 22 * s, y: p.y - 8 * s, width: 32 * s, height: 10 * s))),
            with: .color(padSheen)
        )
    }

    private func drawFlower(into context: inout GraphicsContext, at p: CGPoint, scale s: CGFloat, stir: Double = 0) {
        let turn = CGFloat(stir) * .pi / 180
        for step in 0..<6 {
            let angle = CGFloat(step) * 60 * .pi / 180 + turn
            var petalPath = Path(ellipseIn: CGRect(x: -5 * s, y: -18 * s, width: 10 * s, height: 20 * s))
            petalPath = petalPath.applying(CGAffineTransform(rotationAngle: angle))
            petalPath = petalPath.applying(CGAffineTransform(translationX: p.x, y: p.y))
            context.fill(petalPath, with: .color(petal))
        }
        context.fill(
            Path(ellipseIn: CGRect(x: p.x - 4.4 * s, y: p.y - 4.4 * s, width: 8.8 * s, height: 8.8 * s)),
            with: .color(heart)
        )
    }

    private func drawFish(into context: inout GraphicsContext, at p: CGPoint, scale s: CGFloat) {
        context.fill(
            Path(ellipseIn: CGRect(x: p.x - 17 * s, y: p.y - 10 * s, width: 34 * s, height: 20 * s)),
            with: .color(fish)
        )
        var tail = Path()
        tail.move(to: CGPoint(x: p.x + 15 * s, y: p.y))
        tail.addLine(to: CGPoint(x: p.x + 28 * s, y: p.y - 9 * s))
        tail.addLine(to: CGPoint(x: p.x + 28 * s, y: p.y + 9 * s))
        tail.closeSubpath()
        context.fill(tail, with: .color(fish))
        context.fill(
            Path(ellipseIn: CGRect(x: p.x - 9.6 * s, y: p.y - 4.6 * s, width: 5.2 * s, height: 5.2 * s)),
            with: .color(ink)
        )
    }

    /// The butterfly. `flutter` opens and closes the wings by a couple of
    /// degrees across the whole eleven-second arc — a real butterfly's wingbeat
    /// would be a strobe on a background screen.
    private func drawButterfly(into context: inout GraphicsContext, at p: CGPoint, scale s: CGFloat, flutter: Double = 0) {
        func wing(_ dx: CGFloat, _ degrees: CGFloat, _ colour: Color) {
            var path = Path(ellipseIn: CGRect(x: -10 * s, y: -15 * s, width: 20 * s, height: 24 * s))
            path = path.applying(CGAffineTransform(rotationAngle: degrees * .pi / 180))
            path = path.applying(CGAffineTransform(translationX: p.x + dx * s, y: p.y - 3 * s))
            context.fill(path, with: .color(colour))
        }
        wing(-9, -22 - CGFloat(flutter), wingFar)
        wing(9, 22 + CGFloat(flutter), wingNear)
        context.fill(
            Path(roundedRect: CGRect(x: p.x - 1.8 * s, y: p.y - 10 * s, width: 3.6 * s, height: 19 * s), cornerRadius: 1.8 * s),
            with: .color(ink.opacity(0.7))
        )
    }

    // MARK: Colour arithmetic

    /// Two token colours, blended. Scene gradients stay inside the palette this
    /// way instead of reaching for a hex value the contrast tests never saw.
    private static func mix(_ a: HopColorValue, _ b: HopColorValue, _ t: Double) -> HopColorValue {
        HopColorValue(
            red: a.red + (b.red - a.red) * t,
            green: a.green + (b.green - a.green) * t,
            blue: a.blue + (b.blue - a.blue) * t,
            alpha: 1
        )
    }
}

#if DEBUG
#Preview("Pond backdrop") {
    PondBackdropView(sceneHeight: 385)
        .frame(width: 393, height: 560)
        .hopThemedRoot()
}

#Preview("Pond backdrop · dark") {
    PondBackdropView(sceneHeight: 385)
        .frame(width: 393, height: 560)
        .hopThemedRoot()
        .preferredColorScheme(.dark)
}

/// The whole point of the Reduce Motion preview: nothing moves, and what is left
/// is the drawing at its authored arrangement — not a frame caught mid-wobble.
#Preview("Pond backdrop · Reduce Motion") {
    PondBackdropView(sceneHeight: 385)
        .frame(width: 393, height: 560)
        .hopThemedRoot(reduceMotion: true)
}

#Preview("Pond backdrop · Reduce Motion, dark") {
    PondBackdropView(sceneHeight: 385)
        .frame(width: 393, height: 560)
        .hopThemedRoot(reduceMotion: true)
        .preferredColorScheme(.dark)
}

#Preview("Pond backdrop · iPad band") {
    PondBackdropView(sceneHeight: 452)
        .frame(width: 780, height: 520)
        .hopThemedRoot()
}
#endif
