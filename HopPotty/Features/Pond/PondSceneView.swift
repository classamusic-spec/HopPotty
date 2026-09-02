import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

/// Hop's Pond, drawn as a place.
///
/// ## A living environment, not a reward menu
///
/// The scene is a full landscape composed in depth — sky, clouds, far hills and
/// treeline, the water, what is under the water, the shore, the plants rooted in
/// it, Hop, and the grass nearest the viewer. It is drawn back to front in the
/// order ``PondLayer`` names, and every decoration the child has earned sits
/// *inside* that world at its own ``PondAnchor``, not in a row of tiles beside
/// it. A child looking at this screen should see somewhere they know, which
/// happens to have got richer, rather than a list of things they own.
///
/// ## What moves, and what does not
///
/// The whole scene is drawn in three canvases, split by *whether it moves*:
///
/// - **`pond-still`** — sky, sun, hills, treelines, shrubs, meadow, the water
///   body and its shading, the shore ring and its pebbles. Four gradients and a
///   few dozen paths, rasterised once, never invalidated.
/// - **`pond-drift`** — clouds, the fish under the surface, the shimmer, the
///   ripples, the base lily pads, the near reeds and the dragonfly. One
///   ``HopPondTimeline`` drives all of it at 30fps; everything in it is a small
///   path.
/// - **`pond-foreground`** — the near grass band and the vignette. Still, and on
///   top, because that is what foreground means.
///
/// **Most of it is not moving at any given moment**, which is the point (§26).
/// The clouds take forty-one seconds to travel sixteen points. The fish and the
/// dragonfly *shuttle*: a saturated sine holds them at one end of a short trip
/// for most of the cycle and moves them across quickly, so the eye catches a
/// fish crossing occasionally rather than a fish endlessly swimming. Everything
/// rooted, built, dropped or made of light holds perfectly still, and no two
/// moving things share a period or a phase, so the scene never pulses as one.
///
/// Under Reduce Motion the clock stops dead and the pond stands exactly as
/// drawn — a still pond is a perfectly good pond.
///
/// ## Hop stays readable, without being put in a card
///
/// He is a mid-value, medium-saturation green frog in a landscape made largely
/// of green plants, so ``PondPalette`` reserves his band of the ramp and gives
/// the vegetation everything else: the far hills and treeline are pale, cool and
/// desaturated; the near bank and lily pads are deep and shifted toward blue;
/// the nearest grass is near-black green at low opacity. Nothing else in the
/// scene is Hop's green. On top of that he gets three things a card would
/// otherwise have done: the water's brightest patch is placed behind him so his
/// body reads dark against light and his pale belly reads light against the
/// deeper water below; the catalogue's own layout leaves a clearing of open
/// water around him; and he stands on a deep-green pad with a soft contact
/// shadow, which is what stops him floating.
///
/// ## Nothing here can take anything away
///
/// There is no locked state drawn over an item, no dimming of something once
/// earned, no expiry and no re-lock: the only input is the set of unlocked ids.
/// The one forward-looking element is the *next* item, sketched at the place it
/// will appear — an invitation, not a gap.
struct PondSceneView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.childContext) private var context

    let unlocked: Set<PondItemID>
    /// The item the child is working toward, sketched in place. `nil` once the
    /// pond is complete.
    let nextUp: PondItem?
    /// Drawn on his own lily pad in the middle of his own pond.
    var showsHop: Bool = true
    /// Whether the scene is a *place* rather than a picture.
    ///
    /// The pond screen shows the scene as a tall window on a page: rounded
    /// corners and a hairline, which is what makes it read as somewhere the
    /// child owns and can look into. `HopHubView` uses the same drawing as the
    /// ground the child's home stands on, where a frame halfway up the screen
    /// would be a border around the room the child is standing in. Every anchor
    /// is in unit coordinates, so the scene simply takes the shape it is given.
    var isFullBleed: Bool = false
    /// Whether a finger can reach the pond at all.
    ///
    /// False on the hub, where the scene is the ground behind four doors and a
    /// tap belongs to whatever is on top of it.
    var isInteractive: Bool = true
    let onTapItem: (PondItemID) -> Void

    /// Every touchable thing in the scene, and which of them is answering.
    ///
    /// Rebuilt from the catalogue whenever the unlocked set changes, so a
    /// decoration is touchable from the frame it arrives in.
    @State private var interactions = PondInteractionRegistry()

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
                PondStillLayer()
                PondDriftLayer()

                ForEach(itemsToDraw) { item in
                    PondItemView(
                        item: item,
                        sceneSize: size,
                        activations: interactions.activationCount(item.id.rawValue),
                        onTap: { tapped(item) }
                    )
                    .hopTransition(.childArrive)
                }

                if showsHop {
                    PondHopStage(
                        sceneSize: size,
                        gaze: interactions.gaze(
                            fromHopAt: PondGeometry.hop,
                            hopExtent: PondGeometry.hopExtent
                        ),
                        activations: interactions.activationCount(PondGeometry.hopID)
                    )
                }

                if let nextUp {
                    PondNextItemSketch(item: nextUp, sceneSize: size)
                }

                PondForegroundLayer()

                if let touch = interactions.lastTouch {
                    PondTouchRing(
                        unitPoint: touch,
                        activations: interactions.waterTouches,
                        sceneSize: size
                    )
                }
            }
            .contentShape(Rectangle())
            .modifier(PondTouchTarget(isEnabled: isInteractive, size: size) { unit in
                touchedWater(at: unit)
            })
            .hopAnimation(.childArrive, value: unlocked)
        }
        .modifier(PondSceneFraming(isFullBleed: isFullBleed))
        .onChange(of: unlocked, initial: true) { _, _ in registerInteractiveObjects() }
        // One element with a summary. Forty-one separately focusable sprites in
        // a picture is not navigation, it is a maze; the collection strip below
        // is the linear, per-item list VoiceOver actually wants.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HopCopy.a11y.pondScene.localized(forNickname: context.nickname))
        .accessibilityValue(HopCopy.pond.starCount.localized(for: context.totalStars))
    }

    // MARK: - Direct manipulation

    /// Declares everything a finger can reach.
    ///
    /// The catalogue's own decorations, plus Hop. Base scenery — the fish
    /// shadows under the surface, the pads that were always there, the reeds on
    /// the bank — is deliberately *not* registered: it is drawn inside a canvas
    /// where a per-object transform would cost a redraw of the whole layer, and
    /// a touch that lands on it is a touch on the water, which rings. Every
    /// example in the brief (a flower opening, a fish darting, a pad bobbing, a
    /// butterfly moving on, Hop looking over, the water rippling) is either a
    /// catalogue decoration, Hop, or the water.
    private func registerInteractiveObjects() {
        interactions.removeAll()
        for item in itemsToDraw {
            interactions.registerInteractiveObject(
                item,
                label: PondItemNaming.name(for: item.id).localized
            )
        }
        if showsHop {
            interactions.registerInteractiveObject(
                id: PondGeometry.hopID,
                reaction: .wave,
                at: PondGeometry.hop,
                radius: PondGeometry.hopExtent * 0.55,
                label: HopCopy.a11y.hopCharacter.localized
            )
        }
    }

    /// A decoration was touched: it answers in place, *and* the screen is told,
    /// because the pond screen says the thing's name out loud.
    private func tapped(_ item: PondItem) {
        interactions.touch(at: CGPoint(x: item.anchor.x, y: item.anchor.y))
        onTapItem(item.id)
    }

    /// A touch that missed every decoration. The water rings, and Hop looks over.
    private func touchedWater(at unit: CGPoint) {
        interactions.touch(at: unit)
    }
}

/// Routes a tap on the scene to a unit coordinate.
///
/// A modifier rather than an inline gesture so the whole interaction can be
/// switched off in one place — the hub draws this scene as inert ground behind
/// four doors, and a pond that answered a finger there would be competing with
/// the buttons on top of it.
private struct PondTouchTarget: ViewModifier {
    let isEnabled: Bool
    let size: CGSize
    let onTouch: (CGPoint) -> Void

    func body(content: Content) -> some View {
        if isEnabled, size.width > 0, size.height > 0 {
            content.gesture(
                SpatialTapGesture().onEnded { value in
                    onTouch(PondGeometry.unit(value.location, in: size))
                }
            )
        } else {
            content
        }
    }
}

/// Gives the scene its shape: a window on a page, or the ground under a room.
private struct PondSceneFraming: ViewModifier {
    @Environment(\.hopTheme) private var theme
    let isFullBleed: Bool

    func body(content: Content) -> some View {
        if isFullBleed {
            content
        } else {
            content
                // Portrait, not landscape. The pond has a sky, a horizon, a
                // water body and a near bank stacked in depth, and a 4:3 letter
                // box crops that into a strip of water — which is exactly how a
                // place turns back into a picture of a place.
                .aspectRatio(0.86, contentMode: .fit)
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

// MARK: - Where everything is

/// The scene's band lines and anchor points, in unit coordinates.
///
/// One copy, read by all three canvases and by the character stage, which is
/// what guarantees the still half and the drifting half agree about where the
/// water line is. A second `0.62` in another renderer would be a seam waiting to
/// happen. Every number here matches what `PondCatalog` documents and places its
/// items against.
enum PondGeometry {
    /// The aspect the pond is *composed* at, width over height.
    ///
    /// `PondCatalog` places its forty-one anchors in unit coordinates against a
    /// scene of roughly this shape: the water is 0.78 of the width and 0.46 of
    /// the height, which is a properly foreshortened pond at 0.86 and a circular
    /// puddle at a phone's 0.46. Stretching the composition to whatever frame it
    /// is handed is what turns the catalogue's geometry into nonsense — a
    /// duckling on the grass, a reed in the water — so the drawing keeps its own
    /// shape and the *frame* is what varies.
    static let referenceAspect: CGFloat = 0.86

    /// The rectangle the whole composition is drawn into, for a given frame.
    ///
    /// As wide as the frame, and as tall as that width makes it. A frame taller
    /// than the drawing (a full-bleed phone) gets the stage hung a little above
    /// centre, with the sky's own colour continuing above it and the near bank's
    /// continuing below — so the crop has no seam and the extra height is sky and
    /// grass rather than a stretched pond. A frame shorter than the drawing (a
    /// landscape iPad) crops evenly, top and bottom.
    ///
    /// One function, called by all three canvases and by the item layout, which
    /// is what guarantees they agree about where the water is.
    static func stage(in size: CGSize) -> CGRect {
        let w = max(1, size.width)
        let h = max(1, size.height)
        let stageHeight = w / referenceAspect
        let slack = h - stageHeight
        return CGRect(x: 0, y: slack >= 0 ? slack * 0.34 : slack * 0.5, width: w, height: stageHeight)
    }

    /// The inverse of ``point(_:in:)``: where a finger landed, in the
    /// composition's own coordinates. A touch above or below the stage returns a
    /// value outside 0...1, which is correct — it is a touch on the extended sky
    /// or the extended grass, and it still rings.
    static func unit(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let stage = stage(in: size)
        guard stage.width > 0, stage.height > 0 else { return .zero }
        return CGPoint(
            x: (point.x - stage.minX) / stage.width,
            y: (point.y - stage.minY) / stage.height
        )
    }

    /// A unit coordinate, in the frame's own points.
    static func point(_ unit: CGPoint, in size: CGSize) -> CGPoint {
        let stage = stage(in: size)
        return CGPoint(x: stage.minX + unit.x * stage.width, y: stage.minY + unit.y * stage.height)
    }

    /// A `PondAnchor`'s place, in the frame's own points.
    static func point(_ anchor: PondAnchor, in size: CGSize) -> CGPoint {
        point(CGPoint(x: anchor.x, y: anchor.y), in: size)
    }

    /// The size one decoration is drawn at. A fraction of the stage's width, so
    /// a lily pad is the same size relative to the pond on every device.
    static func itemSide(scale: Double, in size: CGSize) -> CGFloat {
        stage(in: size).width * 0.155 * scale
    }

    /// The horizon: where the far hills meet the sky.
    static let horizon = 0.30
    /// The water body, as an ellipse in unit coordinates.
    static let waterCentre = CGPoint(x: 0.5, y: 0.62)
    static let waterRadiusX = 0.39
    static let waterRadiusY = 0.23
    /// Where the nearest band of grass begins.
    static let foreground = 0.93

    /// Hop's own place: the middle of his own pond.
    static let hop = CGPoint(x: 0.5, y: 0.665)
    /// How wide he is drawn, as a fraction of the scene's width.
    static let hopExtent = 0.22
    /// The registry key for Hop himself.
    static let hopID = "hop"

    /// The water body as a rectangle, for clipping.
    static var waterBounds: CGRect {
        CGRect(
            x: waterCentre.x - waterRadiusX,
            y: waterCentre.y - waterRadiusY,
            width: waterRadiusX * 2,
            height: waterRadiusY * 2
        )
    }

    /// The water body in *stage-local* points.
    ///
    /// Every canvas draws inside a context translated to the stage's origin, so
    /// each of them asks for the water in the stage's own coordinates and none
    /// of them has to know where the stage was hung.
    static func water(width: CGFloat, height: CGFloat) -> CGRect {
        let bounds = waterBounds
        return CGRect(
            x: bounds.minX * width,
            y: bounds.minY * height,
            width: bounds.width * width,
            height: bounds.height * height
        )
    }

    /// Ornament sizes are authored against a 393pt phone. They drift a little
    /// with the width so a reed is not a blade of grass on a small phone and not
    /// a tree on an iPad, but they do not scale linearly: this is a landscape,
    /// and things in it keep their own size.
    static func unit(for width: CGFloat) -> CGFloat {
        min(1.4, max(0.7, width / 393))
    }

    /// A shuttle: mostly at one end of its trip or the other, quick in between.
    ///
    /// A saturated sine. This is the whole of "occasionally" — a fish on a plain
    /// sine is a fish swimming continuously, which is a screensaver; a fish on
    /// this rests, crosses, and rests again, which is a pond.
    static func shuttle(_ wave: Double, gain: Double = 2.6) -> Double {
        min(1, max(-1, wave * gain))
    }
}

// MARK: - The colours the pond is drawn in

/// Every colour in the drawing, resolved once so a render closure captures
/// values rather than a view.
///
/// ## Why these are `HopPalette` and not semantic tokens
///
/// This is a *drawing*. `HopSemanticPalette` exists so that a surface, a divider
/// or a label can change between light, dark and high contrast; a pond whose
/// greens and blues swapped between appearances would stop being the same pond.
/// The same call `PondBackdropView` documents and makes. Nothing here is a raw
/// hex: every value is a named brand token, mixed by ratio where the landscape
/// needs a step the brand ramp does not carry.
///
/// ## The greens rule
///
/// Hop is `hopGreen` — mid value, medium saturation. **Nothing else in the pond
/// is allowed in that band.** Vegetation is placed either well above it (the far
/// hills and treeline, pale and desaturated toward `hopGreenSoft`) or well below
/// it (the near bank, the pads and the nearest grass, deep and pulled toward
/// `hopGreenInk` and `pondBlueDeep`). That single rule is most of why Hop can
/// stand in the middle of a landscape of plants without a card behind him, and
/// it is the rule to check first if he ever stops reading.
private struct PondPalette {
    let skyTop: Color
    let skyBottom: Color
    let sun: Color
    let cloud: Color

    /// Vegetation, far to near. Pale and cool at the back, deep and cool at the
    /// front; Hop's own band is left empty in the middle.
    let hillFar: Color
    let hillNear: Color
    let treeFar: Color
    let treeNear: Color
    let meadow: Color
    let bank: Color
    let bankShade: Color
    let grassNear: Color

    let waterTop: Color
    let waterMid: Color
    let waterDeep: Color
    let waterSky: Color
    let waterShade: Color
    let sheen: Color
    let fishShadow: Color

    let sand: Color
    let sandWet: Color
    let stone: Color

    let padDeep: Color
    let padMid: Color
    let reedDeep: Color
    let reedMid: Color
    let cattail: Color
    let petal: Color
    let petalHeart: Color
    let wing: Color
    let wingFar: Color
    let insectBody: Color

    /// The evening pass. `nil` in light, where there is nothing to pass over.
    let dusk: Color?

    init(theme: HopTheme) {
        skyTop = Color(PondPalette.mix(HopPalette.pondBlueLight, HopPalette.pondBlueSoft, 0.42))
        skyBottom = Color(PondPalette.mix(HopPalette.cloud, HopPalette.sunshineSoft, 0.55))
        sun = Color(HopPalette.sunshineSoft).opacity(0.62)
        cloud = Color(HopPalette.white)

        // Far and pale. Two-thirds of the way to `hopGreenSoft` puts these a
        // long way above Hop in value and a long way below him in chroma.
        hillFar = Color(PondPalette.mix(HopPalette.hopGreenLight, HopPalette.hopGreenSoft, 0.62))
        hillNear = Color(PondPalette.mix(HopPalette.hopGreenLight, HopPalette.hopGreenSoft, 0.34))
        treeFar = Color(PondPalette.mix(HopPalette.hopGreenLight, HopPalette.hopGreenSoft, 0.48))
        treeNear = Color(PondPalette.mix(HopPalette.hopGreenLight, HopPalette.hopGreenSoft, 0.16))
        meadow = Color(PondPalette.mix(HopPalette.hopGreenLight, HopPalette.hopGreenSoft, 0.28))

        // Near and deep, pulled toward the water's blue so the bank reads as
        // damp ground rather than as more of Hop.
        bank = Color(PondPalette.mix(HopPalette.hopGreenDeep, HopPalette.hopGreenLight, 0.34))
        bankShade = Color(PondPalette.mix(HopPalette.hopGreenDeep, HopPalette.pondBlueDeep, 0.22))
        grassNear = Color(HopPalette.hopGreenInk)

        waterTop = Color(PondPalette.mix(HopPalette.pondBlueLight, HopPalette.cloud, 0.28))
        waterMid = Color(HopPalette.pondBlue)
        waterDeep = Color(PondPalette.mix(HopPalette.pondBlue, HopPalette.pondBlueDeep, 0.55))
        waterSky = Color(HopPalette.pondBlueSoft)
        waterShade = Color(HopPalette.pondBlueDeep)
        sheen = Color(HopPalette.white)
        fishShadow = Color(HopPalette.pondBlueInk)

        sand = Color(PondPalette.mix(HopPalette.sand200, HopPalette.sand100, 0.4))
        sandWet = Color(PondPalette.mix(HopPalette.sand300, HopPalette.pondBlueLight, 0.3))
        stone = Color(HopPalette.sand300)

        padDeep = Color(PondPalette.mix(HopPalette.hopGreenDeep, HopPalette.pondBlueDeep, 0.18))
        padMid = Color(PondPalette.mix(HopPalette.hopGreenDeep, HopPalette.hopGreenLight, 0.22))
        reedDeep = Color(HopPalette.hopGreenDeep)
        reedMid = Color(PondPalette.mix(HopPalette.hopGreenDeep, HopPalette.hopGreenLight, 0.4))
        cattail = Color(HopPalette.sand400)
        petal = Color(HopPalette.white)
        petalHeart = Color(HopPalette.sunshine)
        wing = Color(HopPalette.lavender)
        wingFar = Color(HopPalette.lavenderSoft)
        insectBody = Color(HopPalette.lavenderDeep)

        // One drawing, two appearances: dusk is a scrim over the top rather than
        // a second, colder pond underneath.
        dusk = theme.isDark ? Color(theme.color.values.scrim.opacity(0.42)) : nil
    }

    static func mix(_ a: HopColorValue, _ b: HopColorValue, _ t: Double) -> HopColorValue {
        HopColorValue(
            red: a.red + (b.red - a.red) * t,
            green: a.green + (b.green - a.green) * t,
            blue: a.blue + (b.blue - a.blue) * t
        )
    }
}

// MARK: - pond-still

/// Everything that does not move: sky, sun, hills, treelines, shrubs, the
/// meadow, the water body and its shading, the shore ring and its pebbles.
///
/// No timeline above it, so SwiftUI never re-runs this renderer and the four
/// gradients in it are paid for exactly once.
private struct PondStillLayer: View {
    @Environment(\.hopTheme) private var theme

    var body: some View {
        let ink = PondPalette(theme: theme)
        return Canvas(rendersAsynchronously: false) { context, size in
            PondStillLayer.draw(into: &context, size: size, ink: ink)
        }
        .overlay { if let dusk = ink.dusk { dusk.allowsHitTesting(false) } }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func draw(into outer: inout GraphicsContext, size: CGSize, ink: PondPalette) {
        let stage = PondGeometry.stage(in: size)

        // The frame is usually taller than the drawing. Rather than stretch the
        // composition — which is what turns a pond into a puddle and puts a
        // duckling on the grass — the sky's own top colour continues above the
        // stage and the near bank's continues below it, so the crop has no seam
        // and the extra height reads as more sky and more grass.
        outer.fill(
            Path(CGRect(x: 0, y: 0, width: max(1, size.width), height: max(0, stage.minY) + 1)),
            with: .color(ink.skyTop)
        )
        outer.fill(
            Path(CGRect(
                x: 0,
                y: stage.maxY - 1,
                width: max(1, size.width),
                height: max(0, size.height - stage.maxY) + 1
            )),
            with: .color(ink.meadow)
        )

        var context = outer
        context.translateBy(x: stage.minX, y: stage.minY)

        let w = stage.width
        let h = stage.height
        let u = PondGeometry.unit(for: w)
        let horizon = h * PondGeometry.horizon

        // -- pond-sky ------------------------------------------------------
        context.fill(
            Path(CGRect(origin: .zero, size: CGSize(width: w, height: h))),
            with: .linearGradient(
                Gradient(colors: [ink.skyTop, ink.skyBottom]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: horizon * 1.15)
            )
        )

        // The key light: an off-frame sun, high and to the left. Every highlight
        // below is placed against this one call. A soft radial, not a disc —
        // `sunbeam` is a decoration a child unlocks and would collide with one.
        let sunCentre = CGPoint(x: w * 0.16, y: horizon * 0.22)
        let sunRadius = w * 0.62
        context.fill(
            Path(ellipseIn: CGRect(
                x: sunCentre.x - sunRadius,
                y: sunCentre.y - sunRadius,
                width: sunRadius * 2,
                height: sunRadius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [ink.sun, ink.sun.opacity(0)]),
                center: sunCentre,
                startRadius: 0,
                endRadius: sunRadius
            )
        )

        // -- pond-backdrop: hills, treeline, shrubs ------------------------
        drawFarBank(into: &context, w: w, h: h, u: u, horizon: horizon, ink: ink)

        // -- pond-water ----------------------------------------------------
        let water = PondGeometry.water(width: w, height: h)

        // The bank the water sits in: a wider, lower ellipse of damp ground, so
        // the water has an edge instead of being pasted onto the meadow.
        context.fill(
            Path(ellipseIn: water.insetBy(dx: -w * 0.075, dy: -h * 0.045).offsetBy(dx: 0, dy: h * 0.012)),
            with: .linearGradient(
                Gradient(colors: [ink.bank, ink.bankShade]),
                startPoint: CGPoint(x: 0, y: water.minY),
                endPoint: CGPoint(x: 0, y: h)
            )
        )
        // The wet sand ring, pushed down so the shore is a sliver at the far
        // side and a beach at the near one. A concentric ring reads as a bathtub
        // surround rather than as a pond.
        context.fill(
            Path(ellipseIn: water.insetBy(dx: -w * 0.030, dy: -h * 0.018).offsetBy(dx: 0, dy: h * 0.008)),
            with: .color(ink.sand)
        )
        context.fill(
            Path(ellipseIn: water.insetBy(dx: -w * 0.014, dy: -h * 0.008).offsetBy(dx: 0, dy: h * 0.004)),
            with: .color(ink.sandWet)
        )

        context.fill(
            Path(ellipseIn: water),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: ink.waterTop, location: 0),
                    .init(color: ink.waterMid, location: 0.38),
                    .init(color: ink.waterDeep, location: 1),
                ]),
                startPoint: CGPoint(x: 0, y: water.minY),
                endPoint: CGPoint(x: 0, y: water.maxY)
            )
        )

        // -- pond-water-shadows -------------------------------------------
        var pond = context
        pond.clip(to: Path(ellipseIn: water))

        // The far bank's own reflection, along the top rim.
        pond.opacity = 0.20
        pond.fill(
            Path(CGRect(x: water.minX, y: water.minY, width: water.width, height: water.height * 0.22)),
            with: .color(ink.bankShade)
        )
        pond.opacity = 1

        // The sky patch: the brightest part of the water, placed *behind Hop* on
        // purpose. It is the negative space his silhouette reads against, and
        // moving it is the fastest way to make him disappear into the pond.
        pond.opacity = 0.55
        pond.fill(
            Path(ellipseIn: CGRect(
                x: w * (PondGeometry.hop.x - 0.34),
                y: h * (PondGeometry.hop.y - 0.145),
                width: w * 0.68,
                height: h * 0.20
            )),
            with: .radialGradient(
                Gradient(colors: [ink.waterSky, ink.waterSky.opacity(0)]),
                center: CGPoint(x: w * PondGeometry.hop.x, y: h * (PondGeometry.hop.y - 0.045)),
                startRadius: 0,
                endRadius: w * 0.34
            )
        )
        pond.opacity = 1

        // The near bank's shadow on the water, so the bottom of the pond is the
        // dark his pale belly reads against.
        pond.opacity = 0.22
        pond.fill(
            Path(CGRect(
                x: water.minX,
                y: water.maxY - water.height * 0.30,
                width: water.width,
                height: water.height * 0.30
            )),
            with: .linearGradient(
                Gradient(colors: [ink.waterShade.opacity(0), ink.waterShade]),
                startPoint: CGPoint(x: 0, y: water.maxY - water.height * 0.30),
                endPoint: CGPoint(x: 0, y: water.maxY)
            )
        )
        pond.opacity = 1

        // -- pond-rocks: a few pebbles on the near shore --------------------
        for (x, y, r) in [(0.17, 0.845, 0.030), (0.24, 0.870, 0.021), (0.80, 0.850, 0.026), (0.87, 0.826, 0.017)] {
            let radius = w * CGFloat(r)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: w * CGFloat(x) - radius,
                    y: h * CGFloat(y) - radius * 0.44,
                    width: radius * 2,
                    height: radius * 0.88
                )),
                with: .color(ink.stone)
            )
        }
    }

    /// The far bank: two hill bands, two treelines and the meadow that runs down
    /// to the water. Everything here is pale and desaturated — the back of the
    /// scene, and the half of the greens ramp Hop is not standing in.
    private static func drawFarBank(
        into context: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        u: CGFloat,
        horizon: CGFloat,
        ink: PondPalette
    ) {
        var far = Path()
        far.move(to: CGPoint(x: -w * 0.02, y: horizon + 6 * u))
        far.addCurve(
            to: CGPoint(x: w * 0.62, y: horizon + 2 * u),
            control1: CGPoint(x: w * 0.18, y: horizon - 34 * u),
            control2: CGPoint(x: w * 0.44, y: horizon - 26 * u)
        )
        far.addCurve(
            to: CGPoint(x: w * 1.02, y: horizon - 4 * u),
            control1: CGPoint(x: w * 0.80, y: horizon + 22 * u),
            control2: CGPoint(x: w * 0.92, y: horizon - 20 * u)
        )
        far.addLine(to: CGPoint(x: w * 1.02, y: h))
        far.addLine(to: CGPoint(x: -w * 0.02, y: h))
        far.closeSubpath()
        context.fill(far, with: .color(ink.hillFar))

        // pond-trees, far: a broken treeline rather than a band, so the horizon
        // has a silhouette instead of a texture.
        drawTreeline(into: &context, w: w, from: 0.00, to: 0.34, y: horizon - 1 * u, count: 5, tone: ink.treeFar, u: u)
        drawTreeline(into: &context, w: w, from: 0.62, to: 1.00, y: horizon + 3 * u, count: 5, tone: ink.treeFar, u: u)

        var near = Path()
        near.move(to: CGPoint(x: -w * 0.02, y: horizon + 30 * u))
        near.addCurve(
            to: CGPoint(x: w * 0.52, y: horizon + 24 * u),
            control1: CGPoint(x: w * 0.16, y: horizon + 2 * u),
            control2: CGPoint(x: w * 0.34, y: horizon + 6 * u)
        )
        near.addCurve(
            to: CGPoint(x: w * 1.02, y: horizon + 32 * u),
            control1: CGPoint(x: w * 0.74, y: horizon + 44 * u),
            control2: CGPoint(x: w * 0.90, y: horizon + 14 * u)
        )
        near.addLine(to: CGPoint(x: w * 1.02, y: h))
        near.addLine(to: CGPoint(x: -w * 0.02, y: h))
        near.closeSubpath()
        context.fill(near, with: .color(ink.hillNear))

        // pond-trees, near: two clumps with real weight, at the sides, so the
        // middle distance stays open behind the water.
        drawCanopy(into: &context, at: CGPoint(x: w * 0.10, y: horizon + 30 * u), width: 62 * u, height: 44 * u, tone: ink.treeNear)
        drawCanopy(into: &context, at: CGPoint(x: w * 0.21, y: horizon + 34 * u), width: 40 * u, height: 26 * u, tone: ink.treeNear)
        drawCanopy(into: &context, at: CGPoint(x: w * 0.91, y: horizon + 32 * u), width: 66 * u, height: 46 * u, tone: ink.treeNear)
        drawCanopy(into: &context, at: CGPoint(x: w * 0.79, y: horizon + 36 * u), width: 38 * u, height: 24 * u, tone: ink.treeNear)

        // The meadow the pond sits in.
        var meadow = Path()
        meadow.move(to: CGPoint(x: -w * 0.02, y: horizon + 56 * u))
        meadow.addCurve(
            to: CGPoint(x: w * 1.02, y: horizon + 52 * u),
            control1: CGPoint(x: w * 0.30, y: horizon + 34 * u),
            control2: CGPoint(x: w * 0.70, y: horizon + 38 * u)
        )
        meadow.addLine(to: CGPoint(x: w * 1.02, y: h))
        meadow.addLine(to: CGPoint(x: -w * 0.02, y: h))
        meadow.closeSubpath()
        context.fill(meadow, with: .color(ink.meadow))
    }

    /// A row of soft canopies along a line. Deterministic: the jitter is a fixed
    /// hash of the index, so the same treeline is drawn on every launch.
    private static func drawTreeline(
        into context: inout GraphicsContext,
        w: CGFloat,
        from: Double,
        to: Double,
        y: CGFloat,
        count: Int,
        tone: Color,
        u: CGFloat
    ) {
        guard count > 0 else { return }
        for index in 0..<count {
            let t = Double(index) / Double(max(1, count - 1))
            let noise = PondStillLayer.noise(index)
            let x = w * CGFloat(from + (to - from) * t)
            let width = (26 + noise * 20) * u
            let height = (18 + PondStillLayer.noise(index + 41) * 16) * u
            drawCanopy(
                into: &context,
                at: CGPoint(x: x, y: y + CGFloat(PondStillLayer.noise(index + 7) * 6) * u),
                width: width,
                height: height,
                tone: tone
            )
        }
    }

    /// One soft, lumpy canopy: three overlapping ellipses, no stroke, no filter.
    private static func drawCanopy(
        into context: inout GraphicsContext,
        at point: CGPoint,
        width: CGFloat,
        height: CGFloat,
        tone: Color
    ) {
        var path = Path()
        path.addEllipse(in: CGRect(x: point.x - width, y: point.y - height, width: width * 1.5, height: height * 2))
        path.addEllipse(in: CGRect(x: point.x - width * 0.4, y: point.y - height * 1.4, width: width * 1.4, height: height * 2.2))
        path.addEllipse(in: CGRect(x: point.x - width * 0.1, y: point.y - height * 0.8, width: width * 1.1, height: height * 1.7))
        context.fill(path, with: .color(tone))
    }

    /// A fixed 0...1 value for an index. Not random: the same pond, every time.
    static func noise(_ index: Int) -> Double {
        let x = sin(Double(index) * 127.1 + 311.7) * 43_758.5453
        return x - x.rounded(.down)
    }
}

// MARK: - pond-drift

/// Everything that moves, on one clock: clouds, the fish under the surface, the
/// shimmer, the ripples, the base lily pads, the near reeds and the dragonfly.
///
/// One rule holds the split with `pond-still` together: nothing here may overlap
/// anything the still canvas draws *after* it would have been drawn originally.
/// The clouds sit entirely in the sky band and clear the hills' crest by a wide
/// margin at every size the pond is used at; the fish and the shimmer are
/// clipped to the water; the reeds root above the shore, which is the last thing
/// the still canvas draws.
private struct PondDriftLayer: View {
    @Environment(\.hopTheme) private var theme

    var body: some View {
        let ink = PondPalette(theme: theme)
        return HopPondTimeline { clock in
            Canvas(rendersAsynchronously: false) { context, size in
                PondDriftLayer.draw(into: &context, size: size, clock: clock, ink: ink)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct RippleSpec {
        let x: Double
        let y: Double
        let span: Double
        let opacity: Double
    }

    /// Three ripples, spread across the surface. Not four and not a dozen: the
    /// water reads as water at three, and every one after that is a moving thing
    /// on a screen a child is meant to be calm in front of.
    private static let ripples: [RippleSpec] = [
        RippleSpec(x: 0.24, y: 0.545, span: 0.13, opacity: 0.30),
        RippleSpec(x: 0.66, y: 0.615, span: 0.11, opacity: 0.22),
        RippleSpec(x: 0.36, y: 0.760, span: 0.15, opacity: 0.17),
    ]

    static func draw(
        into outer: inout GraphicsContext,
        size: CGSize,
        clock: HopPondClock,
        ink: PondPalette
    ) {
        let stage = PondGeometry.stage(in: size)
        var context = outer
        context.translateBy(x: stage.minX, y: stage.minY)

        let w = stage.width
        let h = stage.height
        let u = PondGeometry.unit(for: w)
        let water = PondGeometry.water(width: w, height: h)

        // -- pond-clouds ---------------------------------------------------
        // Bounded drift, horizontal only, forty-one seconds a cycle. A cloud
        // that crossed the sky would have to enter and leave, and something
        // arriving at the edge of a scene is exactly what catches an eye that
        // was resting.
        let farDrift = CGFloat(clock.wave(period: HopMotion.pondCloudDriftPeriod, phase: HopPondMotion.phase(1)))
        let nearDrift = CGFloat(clock.wave(period: HopMotion.pondCloudDriftPeriod, phase: HopPondMotion.phase(4)))
        drawCloud(
            into: &context,
            at: CGPoint(x: w * 0.72 + farDrift * HopPondMotion.cloudDrift * u, y: h * 0.085),
            width: w * 0.30,
            opacity: 0.92,
            ink: ink
        )
        // The higher, fainter cloud is further away, so it moves less. That is
        // the only parallax in the scene and it is deliberately tiny.
        drawCloud(
            into: &context,
            at: CGPoint(x: w * 0.26 + nearDrift * HopPondMotion.cloudDrift * 0.55 * u, y: h * 0.145),
            width: w * 0.20,
            opacity: 0.48,
            ink: ink
        )

        // -- inside the water ----------------------------------------------
        var pond = context
        pond.clip(to: Path(ellipseIn: water))

        // pond-fish: two soft silhouettes seen *through* the surface, so the
        // pond has depth before a single decoration is unlocked. They shuttle —
        // long rests, quick crossings — which is what "a fish occasionally
        // swimming" actually looks like.
        drawShadowFish(
            into: &pond,
            water: water,
            at: CGPoint(x: 0.34, y: 0.58),
            travel: PondGeometry.shuttle(clock.wave(period: HopMotion.pondFishPeriod, phase: HopPondMotion.phase(3))),
            scale: 1.0 * u,
            opacity: 0.17,
            ink: ink
        )
        drawShadowFish(
            into: &pond,
            water: water,
            at: CGPoint(x: 0.70, y: 0.72),
            travel: -PondGeometry.shuttle(clock.wave(period: HopMotion.pondFishPeriod, phase: HopPondMotion.phase(12))),
            scale: 0.78 * u,
            opacity: 0.13,
            ink: ink
        )

        // pond-shimmer: a broad, very low band of light sliding across the
        // water. Well under a tenth of the water's own contrast.
        let travel = CGFloat(clock.wave(period: HopMotion.pondShimmerPeriod)) * HopPondMotion.shimmerTravel * w
        let centre = water.midX + travel
        let reach = water.width * 0.55
        pond.fill(
            Path(water),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: ink.sheen.opacity(0), location: 0),
                    .init(color: ink.sheen.opacity(HopPondMotion.shimmerOpacity), location: 0.5),
                    .init(color: ink.sheen.opacity(0), location: 1),
                ]),
                startPoint: CGPoint(x: centre - reach, y: 0),
                endPoint: CGPoint(x: centre + reach, y: 0)
            )
        )

        // pond-ripples: each on its own phase, so the surface never moves as one
        // sheet. A couple of points over seven seconds.
        for (index, spec) in ripples.enumerated() {
            let turn = HopPondMotion.phase(index + 1)
            let slide = CGFloat(clock.wave(period: HopMotion.pondRipplePeriod, phase: turn))
            let lift = CGFloat(clock.wave(period: HopMotion.pondRipplePeriod, phase: turn + 0.31))
            let origin = CGPoint(
                x: w * CGFloat(spec.x) + slide * HopPondMotion.rippleDrift * u * 0.5,
                y: h * CGFloat(spec.y) + lift * HopPondMotion.rippleLift * u
            )
            let span = w * CGFloat(spec.span) * 0.5
            var path = Path()
            path.move(to: origin)
            path.addQuadCurve(
                to: CGPoint(x: origin.x + span, y: origin.y),
                control: CGPoint(x: origin.x + span * 0.5, y: origin.y - 6 * u)
            )
            path.addQuadCurve(
                to: CGPoint(x: origin.x + span * 2, y: origin.y),
                control: CGPoint(x: origin.x + span * 1.5, y: origin.y + 6 * u)
            )
            pond.stroke(
                path,
                with: .color(ink.sheen.opacity(spec.opacity)),
                style: StrokeStyle(lineWidth: 2.5 * u, lineCap: .round)
            )
        }

        // -- pond-lily-pads: the base pads, afloat -------------------------
        // Deliberately plainer and deeper in tone than the pads a child unlocks:
        // these are scenery, and a decoration has to look like the better thing.
        // Hop's own pad is drawn with him, and it does not bob — a pad that
        // bobbed would leave him hanging a few points above his own feet.
        drawFloatingPad(
            into: &context,
            at: CGPoint(x: w * 0.20, y: h * 0.700),
            radius: w * 0.075,
            clock: clock,
            phase: HopPondMotion.phase(6),
            tone: ink.padDeep,
            u: u,
            ink: ink
        )
        drawFloatingPad(
            into: &context,
            at: CGPoint(x: w * 0.82, y: h * 0.660),
            radius: w * 0.058,
            clock: clock,
            phase: HopPondMotion.phase(9),
            tone: ink.padDeep,
            u: u,
            ink: ink
        )
        drawFloatingPad(
            into: &context,
            at: CGPoint(x: w * 0.30, y: h * 0.790),
            radius: w * 0.050,
            clock: clock,
            phase: HopPondMotion.phase(14),
            tone: ink.padMid,
            u: u,
            ink: ink
        )

        // -- pond-reeds: rooted on the near shore, swaying -----------------
        // The far bank's reeds are in the still canvas: at that size they are a
        // texture, and a texture that moves is a shimmer nobody asked for.
        drawReeds(into: &context, at: CGPoint(x: w * 0.055, y: h * 0.800), scale: 1.15 * u,
                  clock: clock, phase: HopPondMotion.phase(8), ink: ink)
        drawReeds(into: &context, at: CGPoint(x: w * 0.945, y: h * 0.812), scale: 1.05 * u,
                  clock: clock, phase: HopPondMotion.phase(10), ink: ink)
        drawReeds(into: &context, at: CGPoint(x: w * 0.135, y: h * 0.870), scale: 0.82 * u,
                  clock: clock, phase: HopPondMotion.phase(15), ink: ink)

        // -- pond-flowers: two on the bank, stirring -----------------------
        // Rotation only, and a fraction of the reeds' amplitude. A flower that
        // slid would look like it had come off its stem.
        drawBankFlower(into: &context, at: CGPoint(x: w * 0.865, y: h * 0.880), scale: 0.9 * u,
                       stir: clock.wave(period: HopMotion.pondReedSwayPeriod, phase: HopPondMotion.phase(13)), ink: ink)
        drawBankFlower(into: &context, at: CGPoint(x: w * 0.075, y: h * 0.905), scale: 0.8 * u,
                       stir: clock.wave(period: HopMotion.pondReedSwayPeriod, phase: HopPondMotion.phase(17)), ink: ink)

        // -- pond-dragonfly: moving between two points ---------------------
        // The same shuttle the fish use, so it hangs at one end of its beat,
        // crosses, and hangs at the other — rather than orbiting for ever.
        let flit = HopPondMotion.phase(5)
        let across = CGFloat(PondGeometry.shuttle(clock.wave(period: HopMotion.pondDragonflyPeriod, phase: flit), gain: 1.9))
        let rise = CGFloat(clock.rise(period: HopMotion.pondDragonflyPeriod, phase: flit))
        drawDragonfly(
            into: &context,
            at: CGPoint(
                x: w * 0.70 + across * w * 0.11,
                y: h * 0.480 + rise * HopPondMotion.flitLift * u
            ),
            scale: 0.9 * u,
            wing: clock.wave(period: HopMotion.pondDragonflyPeriod * 0.18, phase: flit) * HopPondMotion.flitWingDegrees,
            ink: ink
        )
    }

    // MARK: Pieces

    private static func drawCloud(
        into context: inout GraphicsContext,
        at point: CGPoint,
        width: CGFloat,
        opacity: Double,
        ink: PondPalette
    ) {
        let r = width * 0.5
        var path = Path()
        path.addEllipse(in: CGRect(x: point.x - r, y: point.y - r * 0.20, width: r * 2, height: r * 0.62))
        path.addEllipse(in: CGRect(x: point.x - r * 0.72, y: point.y - r * 0.52, width: r * 0.86, height: r * 0.86))
        path.addEllipse(in: CGRect(x: point.x - r * 0.18, y: point.y - r * 0.78, width: r * 1.06, height: r * 1.06))
        path.addEllipse(in: CGRect(x: point.x + r * 0.30, y: point.y - r * 0.42, width: r * 0.70, height: r * 0.70))
        context.fill(path, with: .color(ink.cloud.opacity(opacity)))
    }

    /// A fish seen through the surface: a soft dark silhouette, no features.
    /// `travel` is -1...1 across a short lane, not a traverse — it never leaves.
    private static func drawShadowFish(
        into context: inout GraphicsContext,
        water: CGRect,
        at unit: CGPoint,
        travel: Double,
        scale: CGFloat,
        opacity: Double,
        ink: PondPalette
    ) {
        let centre = CGPoint(
            x: water.minX + water.width * unit.x + CGFloat(travel) * water.width * 0.16,
            y: water.minY + water.height * unit.y
        )
        let facing: CGFloat = travel >= 0 ? 1 : -1
        let length = 17 * scale
        let depth = 8 * scale

        var body = Path()
        body.move(to: CGPoint(x: centre.x - length * facing, y: centre.y))
        body.addQuadCurve(
            to: CGPoint(x: centre.x + length * facing, y: centre.y),
            control: CGPoint(x: centre.x, y: centre.y - depth)
        )
        body.addQuadCurve(
            to: CGPoint(x: centre.x - length * facing, y: centre.y),
            control: CGPoint(x: centre.x, y: centre.y + depth)
        )
        body.closeSubpath()

        var tail = Path()
        tail.move(to: CGPoint(x: centre.x - length * facing, y: centre.y))
        tail.addLine(to: CGPoint(x: centre.x - (length + depth) * facing, y: centre.y - depth * 0.8))
        tail.addLine(to: CGPoint(x: centre.x - (length + depth) * facing, y: centre.y + depth * 0.8))
        tail.closeSubpath()

        context.fill(body, with: .color(ink.fishShadow.opacity(opacity)))
        context.fill(tail, with: .color(ink.fishShadow.opacity(opacity * 0.75)))
    }

    /// A lily pad afloat: it rises and settles, with a whisper of roll a beat
    /// behind, which is what makes it look like it is riding water rather than
    /// being waved at the viewer.
    private static func drawFloatingPad(
        into context: inout GraphicsContext,
        at point: CGPoint,
        radius: CGFloat,
        clock: HopPondClock,
        phase: Double,
        tone: Color,
        u: CGFloat,
        ink: PondPalette
    ) {
        let lift = CGFloat(clock.wave(period: HopMotion.pondLilyBobPeriod, phase: phase)) * 2.2 * u
        let roll = clock.wave(period: HopMotion.pondLilyBobPeriod, phase: phase + 0.25) * HopPondMotion.lilyRollDegrees
        let centre = CGPoint(x: point.x, y: point.y + lift)

        var pad = context
        pad.translateBy(x: centre.x, y: centre.y)
        pad.rotate(by: .degrees(roll))

        // The shadow the pad casts on the water, a shade below it.
        pad.fill(
            Path(ellipseIn: CGRect(x: -radius, y: -radius * 0.30 + 3 * u, width: radius * 2, height: radius * 0.78)),
            with: .color(ink.waterShade.opacity(0.14))
        )
        // The pad, with the wedge cut out of it that says "lily pad" at 20pt.
        var shape = Path(ellipseIn: CGRect(x: -radius, y: -radius * 0.36, width: radius * 2, height: radius * 0.72))
        shape.move(to: .zero)
        shape.addLine(to: CGPoint(x: radius * 0.80, y: -radius * 0.24))
        shape.addLine(to: CGPoint(x: radius * 0.62, y: -radius * 0.31))
        shape.closeSubpath()
        pad.fill(shape, with: .color(tone), style: FillStyle(eoFill: true))
        pad.fill(
            Path(ellipseIn: CGRect(x: -radius * 0.62, y: -radius * 0.26, width: radius * 0.86, height: radius * 0.22)),
            with: .color(ink.sheen.opacity(0.16))
        )
    }

    /// A clump of reeds, rocking about its own base.
    private static func drawReeds(
        into context: inout GraphicsContext,
        at point: CGPoint,
        scale: CGFloat,
        clock: HopPondClock,
        phase: Double,
        ink: PondPalette
    ) {
        let sway = clock.wave(period: HopMotion.pondReedSwayPeriod, phase: phase) * HopMotion.pondSwayDegrees

        var reeds = context
        reeds.translateBy(x: point.x, y: point.y)
        reeds.rotate(by: .degrees(sway))

        func blade(_ dx: CGFloat, _ length: CGFloat, _ lean: CGFloat, _ tone: Color, _ width: CGFloat) {
            var path = Path()
            path.move(to: CGPoint(x: dx * scale, y: 0))
            path.addCurve(
                to: CGPoint(x: (dx + lean) * scale, y: -length * scale),
                control1: CGPoint(x: (dx + lean * 0.2) * scale, y: -length * 0.5 * scale),
                control2: CGPoint(x: (dx + lean * 0.8) * scale, y: -length * 0.82 * scale)
            )
            reeds.stroke(
                path,
                with: .color(tone),
                style: StrokeStyle(lineWidth: width * scale, lineCap: .round)
            )
        }

        blade(-9, 34, -7, ink.reedDeep, 4.5)
        blade(0, 48, 3, ink.reedDeep, 5)
        blade(8, 30, 9, ink.reedMid, 4)
        reeds.fill(
            Path(ellipseIn: CGRect(x: -2.6 * scale, y: -56 * scale, width: 5.2 * scale, height: 13 * scale)),
            with: .color(ink.cattail)
        )
    }

    /// A five-petalled flower on the bank. Stirs, never travels.
    private static func drawBankFlower(
        into context: inout GraphicsContext,
        at point: CGPoint,
        scale: CGFloat,
        stir: Double,
        ink: PondPalette
    ) {
        var flower = context
        flower.translateBy(x: point.x, y: point.y)
        flower.rotate(by: .degrees(stir * HopPondMotion.blossomStirDegrees))

        var stem = Path()
        stem.move(to: CGPoint(x: 0, y: 0))
        stem.addQuadCurve(to: CGPoint(x: 0, y: -18 * scale), control: CGPoint(x: 3 * scale, y: -10 * scale))
        flower.stroke(stem, with: .color(ink.reedDeep), style: StrokeStyle(lineWidth: 2.4 * scale, lineCap: .round))

        for step in 0..<5 {
            var petals = flower
            petals.translateBy(x: 0, y: -18 * scale)
            petals.rotate(by: .degrees(Double(step) * 72))
            petals.fill(
                Path(ellipseIn: CGRect(x: -3.0 * scale, y: -9.6 * scale, width: 6.0 * scale, height: 8.4 * scale)),
                with: .color(ink.petal)
            )
        }
        flower.fill(
            Path(ellipseIn: CGRect(x: -2.6 * scale, y: -20.6 * scale, width: 5.2 * scale, height: 5.2 * scale)),
            with: .color(ink.petalHeart)
        )
    }

    /// The dragonfly. Two pairs of wings and a body; the wing angle is the only
    /// thing running on a fast period anywhere in the scene, and it moves three
    /// degrees.
    private static func drawDragonfly(
        into context: inout GraphicsContext,
        at point: CGPoint,
        scale: CGFloat,
        wing: Double,
        ink: PondPalette
    ) {
        var fly = context
        fly.translateBy(x: point.x, y: point.y)

        for side in [-1.0, 1.0] {
            var pair = fly
            pair.rotate(by: .degrees(wing * side))
            pair.fill(
                Path(ellipseIn: CGRect(
                    x: CGFloat(side) * 2 * scale - (side < 0 ? 15 * scale : 0),
                    y: -5.4 * scale,
                    width: 15 * scale,
                    height: 5.2 * scale
                )),
                with: .color(ink.wing.opacity(0.72))
            )
            pair.fill(
                Path(ellipseIn: CGRect(
                    x: CGFloat(side) * 2 * scale - (side < 0 ? 12 * scale : 0),
                    y: 0.4 * scale,
                    width: 12 * scale,
                    height: 4.2 * scale
                )),
                with: .color(ink.wingFar.opacity(0.72))
            )
        }
        fly.fill(
            Path(roundedRect: CGRect(x: -1.8 * scale, y: -6 * scale, width: 3.6 * scale, height: 20 * scale), cornerRadius: 1.8 * scale),
            with: .color(ink.insectBody)
        )
        fly.fill(
            Path(ellipseIn: CGRect(x: -3.2 * scale, y: -9.4 * scale, width: 6.4 * scale, height: 6.4 * scale)),
            with: .color(ink.insectBody)
        )
    }
}

// MARK: - pond-foreground

/// The nearest band of grass, and the vignette over the whole scene.
///
/// Still, and on top of everything, because that is what foreground means. It is
/// the darkest, least detailed thing in the pond — a near-black-green silhouette
/// that pushes the rest of the world away from the eye and, incidentally, gives
/// Hop's green somewhere to be lighter than.
private struct PondForegroundLayer: View {
    @Environment(\.hopTheme) private var theme

    var body: some View {
        let ink = PondPalette(theme: theme)
        return Canvas(rendersAsynchronously: false) { outer, size in
            let stage = PondGeometry.stage(in: size)
            var context = outer
            context.translateBy(x: stage.minX, y: stage.minY)

            let w = stage.width
            let h = stage.height
            let u = PondGeometry.unit(for: w)
            let top = h * PondGeometry.foreground
            // The band runs to the bottom of the *frame*, not the stage, so a
            // full-bleed phone has grass under the tray rather than a hard edge.
            let bottom = max(h, size.height - stage.minY)

            var band = Path()
            band.move(to: CGPoint(x: -w * 0.02, y: top + 6 * u))
            band.addCurve(
                to: CGPoint(x: w * 1.02, y: top),
                control1: CGPoint(x: w * 0.28, y: top - 14 * u),
                control2: CGPoint(x: w * 0.70, y: top + 10 * u)
            )
            band.addLine(to: CGPoint(x: w * 1.02, y: bottom))
            band.addLine(to: CGPoint(x: -w * 0.02, y: bottom))
            band.closeSubpath()
            context.fill(band, with: .color(ink.grassNear.opacity(0.34)))

            for (x, height) in [(0.06, 22.0), (0.15, 15.0), (0.86, 24.0), (0.94, 16.0), (0.46, 13.0)] {
                var tuft = Path()
                let base = CGPoint(x: w * CGFloat(x), y: top + 8 * u)
                for lean in [CGFloat(-7), 0, 7] {
                    tuft.move(to: CGPoint(x: base.x + lean * u * 0.6, y: base.y))
                    tuft.addQuadCurve(
                        to: CGPoint(x: base.x + lean * u * 1.6, y: base.y - CGFloat(height) * u),
                        control: CGPoint(x: base.x + lean * u, y: base.y - CGFloat(height) * 0.6 * u)
                    )
                }
                context.stroke(
                    tuft,
                    with: .color(ink.grassNear.opacity(0.30)),
                    style: StrokeStyle(lineWidth: 3.2 * u, lineCap: .round)
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Hop, in the middle of his own pond

/// Hop on his pad, grounded and legible, with no card anywhere near him.
///
/// Four things do the work a card would otherwise have done, and none of them
/// puts a rectangle behind a frog:
///
/// 1. **Local contrast.** The pad under him is the deepest green in the scene
///    and the water behind him is the palest blue, so his outline is carried by
///    the drawing rather than by a border.
/// 2. **A contact shadow.** One soft ellipse on the pad. It is what stops him
///    hovering, and it is the cheapest legibility in the whole file — no blur,
///    no filter, one fill.
/// 3. **Negative space.** The pad is wider than he is, so there is a ring of
///    clear water between him and whatever is planted nearest.
/// 4. **Gaze.** He looks at the last place the child touched, which is what
///    makes him the subject of the picture rather than an item in it (§27).
private struct PondHopStage: View {
    @Environment(\.hopTheme) private var theme

    let sceneSize: CGSize
    let gaze: HopGaze
    /// Increments when a finger lands on him. He waves back, once.
    let activations: Int

    private var side: CGFloat {
        PondGeometry.stage(in: sceneSize).width * CGFloat(PondGeometry.hopExtent)
    }
    private var centre: CGPoint { PondGeometry.point(PondGeometry.hop, in: sceneSize) }

    var body: some View {
        ZStack {
            pad
            HopCharacterStage(
                act: activations > 0 ? .greeting : .idle,
                size: side,
                gaze: gaze
            )
            .id(activations)
            .position(x: centre.x, y: centre.y - side * 0.28)
        }
        .accessibilityHidden(true)
    }

    /// His pad, and the shadow he casts on it. Drawn here rather than in the
    /// drift canvas because it must not bob: a pad that rose and fell would
    /// leave Hop hanging a few points above his own feet.
    private var pad: some View {
        let ink = PondPalette(theme: theme)
        let radius = side * 0.62
        return Canvas(rendersAsynchronously: false) { context, _ in
            var shape = Path(ellipseIn: CGRect(
                x: centre.x - radius,
                y: centre.y - radius * 0.30,
                width: radius * 2,
                height: radius * 0.60
            ))
            shape.move(to: CGPoint(x: centre.x, y: centre.y))
            shape.addLine(to: CGPoint(x: centre.x + radius * 0.86, y: centre.y - radius * 0.20))
            shape.addLine(to: CGPoint(x: centre.x + radius * 0.70, y: centre.y - radius * 0.27))
            shape.closeSubpath()
            context.fill(shape, with: .color(ink.padDeep), style: FillStyle(eoFill: true))

            // The pale rim: a sliver of lit edge on the side the sun is on. It
            // separates the pad from the water without a stroke around it.
            context.fill(
                Path(ellipseIn: CGRect(
                    x: centre.x - radius * 0.72,
                    y: centre.y - radius * 0.24,
                    width: radius * 1.0,
                    height: radius * 0.17
                )),
                with: .color(ink.sheen.opacity(0.18))
            )

            // The contact shadow. Hop's feet land at the pad's centre.
            context.fill(
                Path(ellipseIn: CGRect(
                    x: centre.x - side * 0.26,
                    y: centre.y - side * 0.055,
                    width: side * 0.52,
                    height: side * 0.11
                )),
                with: .color(ink.fishShadow.opacity(0.20))
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - One unlocked decoration

private struct PondItemView: View {
    @Environment(\.hopTheme) private var theme

    let item: PondItem
    let sceneSize: CGSize
    /// How many times a finger has landed on this decoration.
    let activations: Int
    let onTap: () -> Void

    /// Base size before the anchor's own scale, measured against the composition
    /// rather than the frame, so a lily pad is the same size relative to the pond
    /// whether the scene is a window on a page or the ground under a room.
    private var side: CGFloat {
        PondGeometry.itemSide(scale: item.anchor.scale, in: sceneSize)
    }

    var body: some View {
        Button(action: onTap) {
            HopArtwork(.pondItem(item.id))
                .frame(width: side, height: side)
                // A comfortable target around a small drawing. A ladybug is
                // eight points across and a three-year-old's finger is not.
                .contentShape(Rectangle().inset(by: -theme.hitTarget.child * 0.2))
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
        // …and answers a touch with one short beat of its own, on top of the
        // idle, which keeps running underneath.
        .pondReaction(
            PondInteractionRegistry.reaction(for: item.id),
            activations: activations,
            extent: side
        )
        .position(PondGeometry.point(item.anchor, in: sceneSize))
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

    private var side: CGFloat { PondGeometry.itemSide(scale: item.anchor.scale, in: sceneSize) }

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
        .position(PondGeometry.point(item.anchor, in: sceneSize))
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
/// clubhouse holding perfectly still — and Hop still readable in the middle of
/// all of it, with nothing behind him but water.
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
/// put it. A touch still answers; it simply answers without travelling.
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

#Preview("Pond scene · full bleed, as the hub uses it") {
    PondSceneView(
        unlocked: Set(PondCatalog.unlockedItems(atStars: 100).map(\.id)),
        nextUp: nil,
        showsHop: false,
        isFullBleed: true,
        isInteractive: false,
        onTapItem: { _ in }
    )
    .hopThemedRoot()
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
