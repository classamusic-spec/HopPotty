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
struct PondBackdropView: View {
    @Environment(\.hopTheme) private var theme

    /// Height of the drawing's own box. The view fills whatever it is given; the
    /// box is hung at the top and the near-shore colour continues below it, so a
    /// crop that ends below the drawing has no seam.
    let sceneHeight: CGFloat

    var body: some View {
        let ink = PondInk(theme: theme)
        let box = sceneHeight
        return Canvas(rendersAsynchronously: false) { context, size in
            ink.draw(into: &context, size: size, sceneHeight: box)
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

    // MARK: Composition

    func draw(into context: inout GraphicsContext, size: CGSize, sceneHeight: CGFloat) {
        let width = max(1, size.width)
        let box = max(1, min(sceneHeight, size.height))

        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(skyTop))
        if size.height > box {
            context.fill(
                Path(CGRect(x: 0, y: box, width: width, height: size.height - box)),
                with: .color(shoreBottom)
            )
        }

        var scene = context
        scene.clip(to: Path(CGRect(x: 0, y: 0, width: width, height: box)))
        drawScene(into: &scene, width: width, height: box)
    }

    private func drawScene(into context: inout GraphicsContext, width w: CGFloat, height h: CGFloat) {
        let sky = h * 0.28
        let water = h * 0.40
        let shore = h * 0.735
        // Ornament sizes are authored against a 393pt phone. They are allowed to
        // drift a little with the width so a reed is not a blade of grass on a
        // small phone and not a tree on an iPad, but they do not scale linearly:
        // this is a landscape, and things in it keep their own size.
        let u = min(1.25, max(0.8, w / 393))

        context.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: h)),
            with: .linearGradient(
                Gradient(colors: [skyTop, skyBottom]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: h)
            )
        )

        let sunCentre = CGPoint(x: w * 0.17, y: sky * 0.42)
        let sunRadius = w * 0.42
        context.fill(
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

        drawCloud(into: &context, at: CGPoint(x: w * 0.74, y: sky * 0.34), scale: 0.95 * u, opacity: 0.9)
        drawCloud(into: &context, at: CGPoint(x: w * 0.28, y: sky * 0.20), scale: 0.55 * u, opacity: 0.42)

        drawFarBank(into: &context, width: w, sky: sky, water: water, unit: u)
        drawWater(into: &context, width: w, height: h, water: water, unit: u)
        drawNearShore(into: &context, width: w, height: h, shore: shore, unit: u)
    }

    // MARK: Bands

    private func drawFarBank(into context: inout GraphicsContext, width w: CGFloat, sky: CGFloat, water: CGFloat, unit u: CGFloat) {
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

        drawReeds(into: &context, at: CGPoint(x: w * 0.20, y: sky + 30 * u), scale: 0.7 * u)
        for (x, dy) in [(0.50, 4.0), (0.86, 2.0), (0.16, 6.0)] {
            drawTuft(into: &context, at: CGPoint(x: w * CGFloat(x), y: water + CGFloat(dy) * u), scale: 0.55 * u)
        }
    }

    private func drawWater(into context: inout GraphicsContext, width w: CGFloat, height h: CGFloat, water: CGFloat, unit u: CGFloat) {
        var pond = Path()
        pond.move(to: CGPoint(x: 0, y: water + 8 * u))
        pond.addCurve(
            to: CGPoint(x: w, y: water + 10 * u),
            control1: CGPoint(x: w * 0.30, y: water - 18 * u),
            control2: CGPoint(x: w * 0.72, y: water - 14 * u)
        )
        pond.addLine(to: CGPoint(x: w, y: h))
        pond.addLine(to: CGPoint(x: 0, y: h))
        pond.closeSubpath()
        context.fill(
            pond,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: waterTop, location: 0),
                    .init(color: waterMid, location: 0.35),
                    .init(color: waterDeep, location: 1),
                ]),
                startPoint: CGPoint(x: 0, y: water - 18 * u),
                endPoint: CGPoint(x: 0, y: h)
            )
        )

        for (x, dy, opacity, span) in [(0.08, 46.0, 0.30, 52.0), (0.50, 92.0, 0.22, 48.0), (0.04, 150.0, 0.18, 48.0), (0.52, 196.0, 0.16, 44.0)] {
            drawRipple(
                into: &context,
                at: CGPoint(x: w * CGFloat(x), y: water + CGFloat(dy) * u),
                span: CGFloat(span) * u,
                opacity: opacity,
                unit: u
            )
        }

        drawLilyPad(into: &context, at: CGPoint(x: w * 0.22, y: h * 0.66), scale: 0.8 * u, tone: padFar)
        drawLilyPad(into: &context, at: CGPoint(x: w * 0.30, y: h * 0.585), scale: 0.95 * u, tone: padFar)
        drawFish(into: &context, at: CGPoint(x: w * 0.72, y: h * 0.64), scale: u)
        drawFlower(into: &context, at: CGPoint(x: w * 0.78, y: h * 0.545), scale: 0.9 * u)
        // Hop's own pad, last of the things in the water: he sits on it, and
        // `HomePondMetrics.padPoint` is the same point.
        drawLilyPad(into: &context, at: CGPoint(x: w * 0.56, y: h * 0.508), scale: 1.6 * u, tone: padNear)
    }

    private func drawNearShore(into context: inout GraphicsContext, width w: CGFloat, height h: CGFloat, shore: CGFloat, unit u: CGFloat) {
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

        drawReeds(into: &context, at: CGPoint(x: w * 0.08, y: shore + 16 * u), scale: 1.15 * u)
        drawReeds(into: &context, at: CGPoint(x: w * 0.93, y: shore + 10 * u), scale: 1.0 * u)
        drawButterfly(into: &context, at: CGPoint(x: w * 0.19, y: h * 0.44), scale: u)
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

    private func drawReeds(into context: inout GraphicsContext, at p: CGPoint, scale s: CGFloat) {
        func blade(_ dx: CGFloat, _ length: CGFloat, _ lean: CGFloat, _ colour: Color) {
            var path = Path()
            path.move(to: CGPoint(x: p.x + dx * s, y: p.y))
            path.addCurve(
                to: CGPoint(x: p.x + (dx + lean * 1.2) * s, y: p.y - length * s),
                control1: CGPoint(x: p.x + (dx + lean * 0.3) * s, y: p.y - length * 0.5 * s),
                control2: CGPoint(x: p.x + (dx + lean) * s, y: p.y - length * 0.8 * s)
            )
            context.stroke(path, with: .color(colour), style: StrokeStyle(lineWidth: 6 * s, lineCap: .round))
        }
        blade(-14, 54, -12, reedDark)
        blade(0, 74, 4, reedDark)
        blade(13, 46, 14, reedLight)
        context.fill(
            Path(ellipseIn: CGRect(x: p.x - 6 * s, y: p.y - 90 * s, width: 12 * s, height: 28 * s)),
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

    private func drawLilyPad(into context: inout GraphicsContext, at p: CGPoint, scale s: CGFloat, tone: Color) {
        context.fill(
            Path(ellipseIn: CGRect(x: p.x - 34 * s, y: p.y - 13 * s, width: 68 * s, height: 26 * s)),
            with: .color(tone)
        )
        var notch = Path()
        notch.move(to: p)
        notch.addLine(to: CGPoint(x: p.x + 26 * s, y: p.y - 8 * s))
        notch.addLine(to: CGPoint(x: p.x + 20 * s, y: p.y - 10 * s))
        notch.closeSubpath()
        context.fill(notch, with: .color(padNotch))
        context.fill(
            Path(ellipseIn: CGRect(x: p.x - 22 * s, y: p.y - 8 * s, width: 32 * s, height: 10 * s)),
            with: .color(padSheen)
        )
    }

    private func drawFlower(into context: inout GraphicsContext, at p: CGPoint, scale s: CGFloat) {
        for step in 0..<6 {
            let angle = CGFloat(step) * 60 * .pi / 180
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

    private func drawButterfly(into context: inout GraphicsContext, at p: CGPoint, scale s: CGFloat) {
        func wing(_ dx: CGFloat, _ degrees: CGFloat, _ colour: Color) {
            var path = Path(ellipseIn: CGRect(x: -10 * s, y: -15 * s, width: 20 * s, height: 24 * s))
            path = path.applying(CGAffineTransform(rotationAngle: degrees * .pi / 180))
            path = path.applying(CGAffineTransform(translationX: p.x + dx * s, y: p.y - 3 * s))
            context.fill(path, with: .color(colour))
        }
        wing(-9, -22, wingFar)
        wing(9, 22, wingNear)
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

#Preview("Pond backdrop · iPad band") {
    PondBackdropView(sceneHeight: 452)
        .frame(width: 780, height: 520)
        .hopThemedRoot()
}
#endif
