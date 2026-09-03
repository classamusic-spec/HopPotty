import SwiftUI

/// Hop's authoring spaces.
///
/// He is drawn in the 150 × 160 space of the approved reference
/// (`hop_mascot.svg`), exactly as `Scripts/hop-art.js` draws him, so every
/// number in ``HopPoseGeometry`` and ``HopAnatomy`` can be checked against the
/// generator line for line. That space is then placed onto the 512 × 512 canvas
/// the art files ship in, and the canvas is fitted to whatever rectangle the
/// view was given. Two steps, both at the edge, so nothing in between has to
/// know how big Hop is on screen.
///
/// ## The placement is not a preference, it is a fit
///
/// It used to be `scale 3.2, offset (16, 0)`, which was hand-written and wrong:
/// the pose set actually draws 169 × 174 reference units, so at 3.2 it needed
/// 542 × 558 of a 512 box. **Fourteen of the fifteen poses were clipped** —
/// every one but `face` lost its ground shadow, `idle`/`blink`/`talk` were cut
/// on both sides, and `jump` lost the top of its head, which is what a caregiver
/// reported. `Scripts/check-hop-fit.js` now measures the rendered alpha bounds
/// of every pose and fails on any content that touches an edge.
///
/// These numbers are the generator's, solved rather than chosen: the stage
/// rectangle the pose set occupies is `x 5…145`, `y −3…164`, so a 512 canvas
/// with a 12-unit margin gives `scale 2.9` and the origin that centres it. They
/// must equal `wrap()` in `Scripts/hop-art.js`; if that file's stage changes,
/// these change with it or the app and the shipped art draw different frogs.
enum HopCanvas {
    /// The side of the shipped canvas, which `Art/character/hop-*.svg` uses.
    static let side: CGFloat = 512
    /// The reference space, in which all anatomy is authored.
    static let referenceSize = CGSize(width: 150, height: 160)
    /// `transform="translate(38.5 22.55) scale(2.9)"` from the generator's `wrap`.
    static let referenceScale: CGFloat = 2.9
    static let referenceOrigin = CGPoint(x: 38.5, y: 22.55)

    /// The reference y a grounded pose's toes touch, and the ankle that puts
    /// them there. `hop-art.js` sets `ankle = groundAnkle + lift` for every
    /// grounded pose, which is what makes standing and sitting share one ground
    /// line — and therefore lets a screen place any pose with one constant.
    static let groundLine: CGFloat = 163.6
    static let groundAnkle: CGFloat = 146

    /// Where Hop's feet sit in the canvas, as a fraction of its height. Screens
    /// position him by this rather than by guessing at his silhouette.
    static var feetFraction: CGFloat { (groundLine * referenceScale + referenceOrigin.y) / side }

    /// Reference space → canvas space.
    static let referenceTransform = CGAffineTransform(scaleX: referenceScale, y: referenceScale)
        .concatenating(CGAffineTransform(translationX: referenceOrigin.x, y: referenceOrigin.y))

    /// Scales an authored canvas path to fill `rect`, preserving the square
    /// aspect.
    static func fit(_ path: Path, in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / side
        let dx = rect.midX - side * scale / 2
        let dy = rect.midY - side * scale / 2
        return path
            .applying(CGAffineTransform(scaleX: scale, y: scale))
            .applying(CGAffineTransform(translationX: dx, y: dy))
    }

    /// Places a path authored in reference space into `rect`.
    static func place(_ path: Path, in rect: CGRect) -> Path {
        fit(path.applying(referenceTransform), in: rect)
    }

    /// How many points one reference unit covers when Hop is drawn at `size`.
    /// Stroke widths are authored in reference units and have to be converted,
    /// because a stroke does not scale with the path it is applied to.
    static func unit(for size: CGFloat) -> CGFloat {
        referenceScale * size / side
    }
}

/// How strongly Hop is separated from what is behind him, and from himself.
///
/// Three levels of separation hold this character together and none of them is
/// allowed to carry it alone: the exterior silhouette, the internal overlap
/// rims, and the tonal ramp in ``HopCharacterPalette``. This type carries the
/// two that are geometry.
///
/// `exterior` is how far the silhouette underlay grows past the fill — the
/// weight of the outside edge. `inner` is the same for a part's own rim, drawn
/// at `innerOpacity` beneath its own fill so it only appears where that part
/// crosses something already drawn. `inner` is always roughly half `exterior`,
/// because an internal boundary as strong as the outside one reads as a
/// cut-out rather than as an arm in front of a chest.
///
/// Both are in **reference units** and are multiplied by ``HopCanvas/unit(for:)``
/// at the one place they are used, so the outline scales with Hop exactly as
/// every other line in the drawing does. That is deliberate and it is why the
/// SVG side rejects `vector-effect="non-scaling-stroke"`: a stroke pinned to
/// device pixels would be eight times heavier relative to the body at 64pt than
/// at 512pt, which is the "magnified sticker" failure inverted.
///
/// The numbers are `OUTLINE` in `Scripts/hop-art.js`, and `highContrast` is
/// capped at 2.8 by the canvas rather than by taste: at 3.1 the `jump` pose's
/// eye sockets come within 5.5 units of the top edge and `check-hop-fit.js`
/// goes red.
struct HopOutlineStyle: Equatable, Sendable {
    var exterior: CGFloat
    var inner: CGFloat
    var innerOpacity: Double

    /// No outline at all. Not a shipping state — it is the test that the pose,
    /// the depth order and the green ramp hold Hop up on their own.
    static let off = HopOutlineStyle(exterior: 0, inner: 0, innerOpacity: 0)
    /// 200pt and up. A softer edge, because at hero size the tonal separation is
    /// doing more of the work and a small Hop's outline looks like a sticker.
    static let hero = HopOutlineStyle(exterior: 1.55, inner: 0.9, innerOpacity: 0.5)
    /// The everyday state, and what `Art/character/hop-*.svg` ships with.
    static let standard = HopOutlineStyle(exterior: 2.0, inner: 1.15, innerOpacity: 0.62)
    /// Over illustration — pond water, vegetation green, a dark sky — where the
    /// background is Hop's own hue and the silhouette is all that is left.
    static let scene = HopOutlineStyle(exterior: 2.35, inner: 1.25, innerOpacity: 0.72)
    /// 96pt and below, where the everyday edge is under a pixel.
    static let small = HopOutlineStyle(exterior: 2.6, inner: 1.35, innerOpacity: 0.78)
    /// Increase Contrast, and any accessibility appearance.
    static let highContrast = HopOutlineStyle(exterior: 2.8, inner: 1.75, innerOpacity: 0.95)

    /// The responsive rule, and the only place it is written on this side.
    ///
    /// Its twin is the `SIZES` table in `Scripts/hop-lab.js`, which is what the
    /// lab's **Auto** setting draws — so what a reviewer sees in the lab is what
    /// the app puts on screen.
    static func resolved(
        forSize size: CGFloat,
        onScenery: Bool = false,
        highContrast: Bool = false
    ) -> HopOutlineStyle {
        if highContrast { return .highContrast }
        if size <= 96 { return .small }
        if onScenery { return .scene }
        return size >= 200 ? .hero : .standard
    }
}

/// Where Hop is standing, as far as his outline is concerned.
///
/// Semantic, not a per-screen override: a caller says *what kind of ground this
/// is*, and the outline state is resolved from that together with the size and
/// the accessibility appearance. No screen gets to nudge a stroke width.
///
/// Not to be confused with `HopGround` in `HopThemeEnvironment.swift`, which is
/// the app's *background colour* role — primary, secondary, sunken. This one is
/// about what is behind Hop specifically, and it has only two answers because
/// the only question the outline asks is whether his own green is back there.
public enum HopCharacterGround: Equatable, Sendable {
    /// Cards, sheets, cream, white — the app's own surfaces.
    case surface
    /// Illustration: pond water, vegetation, a night sky. Hop's own hue is in
    /// the background, so the silhouette has to work harder.
    case scenery
}

/// The fixed numbers of Hop's body — the ones a pose never changes.
///
/// Transcribed from the constants and part functions at the top of
/// `Scripts/hop-art.js`. A pose sets where the hands and feet are; this sets
/// what a hand and a foot *are*.
enum HopAnatomy {
    static let eyeL = CGPoint(x: 42.4, y: 25.7)
    static let eyeR = CGPoint(x: 108.4, y: 25.7)
    /// The socket is the bump in the head silhouette, drawn in body green.
    static let socketRadius: CGFloat = 20.5
    static let whiteRadius: CGFloat = 16.5
    static let pupilRadius: CGFloat = 12.3
    static let highlightRadius: CGFloat = 3.4
    /// The pupil sits a unit below the socket centre; the catchlight above it.
    static let pupilOffset = CGSize(width: 0, height: 1)
    static let highlightOffset = CGSize(width: 3.2, height: -4)

    /// Shoulders are fixed: the pose moves the hand and the arm follows.
    static let shoulderL = CGPoint(x: 48, y: 86)
    static let shoulderR = CGPoint(x: 102, y: 86)
    static let armWidth: CGFloat = 15
    static let palmRadius: CGFloat = 9.5
    static let fingerLength: CGFloat = 12
    static let fingerWidth: CGFloat = 10.5
    /// Three fingers, fanned about the arm's own direction.
    static let fingerAngles: [Double] = [-50, 0, 50]

    // The close-up hand is no longer generated. It is the owner's drawing,
    // `Art/source/wash-hands.svg`, shipped as two keyed assets — so there is
    // one hand in the product rather than a drawing and a parameter table that
    // have to be kept in step.

    static let legWidth: CGFloat = 26
    static let soleRadii = CGSize(width: 14, height: 8.5)
    /// Toe angle (relative to the foot's outward direction) and half-width.
    /// The generator strokes each toe at `r * 2`, so the radius *is* `r`.
    static let toes: [(angle: Double, radius: CGFloat)] = [
        (angle: -6, radius: 6), (angle: -44, radius: 6), (angle: -82, radius: 5.6),
    ]
    /// How far a toe reaches from the sole centre: the horizontal reach is
    /// multiplied by the pose's toe spread, the vertical one is not.
    static let toeReach = CGSize(width: 15, height: 11)

    /// The point the head rotates about, and the mouth scales about.
    static let faceCentre = CGPoint(x: 75, y: 50)
    /// The point the body leans about.
    static let hipCentre = CGPoint(x: 75, y: 100)
    /// Where a tongue leaves the mouth.
    static let tongueOrigin = HopPoseGeometry.tongueOrigin

    static let crownCentre = CGPoint(x: 75, y: 40)
    static let crownRadii = CGSize(width: 44, height: 33)
    static let jawCentre = CGPoint(x: 75, y: 56)
    static let jawRadii = CGSize(width: 61, height: 27)

    /// The top of Hop's head, in reference units.
    static let crownTop: CGFloat = crownCentre.y - crownRadii.height

    /// The floor Hop stands on, in reference units — the line the ground shadow
    /// is centred on in `figure()`, which is ``HopCanvas/groundLine`` less the
    /// shadow's own height so that the toes touch the shadow rather than pierce
    /// it. Motion anchors here rather than at the bottom of the view, because
    /// the view is a square and Hop is not.
    static let shadowRadii = CGSize(width: 40, height: 3.6)
    static let groundLine: CGFloat = HopCanvas.groundLine - shadowRadii.height

    /// The head's bounding box in reference space: the jaw sets the width, the
    /// eye sockets the top, the jaw the bottom.
    static let headBoundsInReference = CGRect(
        x: jawCentre.x - jawRadii.width,
        y: eyeL.y - socketRadius,
        width: jawRadii.width * 2,
        height: (jawCentre.y + jawRadii.height) - (eyeL.y - socketRadius)
    )

    /// The same box on the 512 canvas — what ``HopPoseGeometry/faceCrop`` is.
    static let headBoundsOnCanvas = headBoundsInReference.applying(HopCanvas.referenceTransform)

    /// The three forehead spots, exactly where the reference puts them.
    static let spots: [(centre: CGPoint, radii: CGSize)] = [
        (centre: CGPoint(x: 75.3, y: 19.4), radii: CGSize(width: 4.4, height: 2.6)),
        (centre: CGPoint(x: 72.8, y: 26.2), radii: CGSize(width: 2.6, height: 1.9)),
        (centre: CGPoint(x: 80.6, y: 24.6), radii: CGSize(width: 3.0, height: 1.6)),
    ]
    static let nostrils = [CGPoint(x: 67.4, y: 41), CGPoint(x: 82.6, y: 41)]
    static let nostrilRadius: CGFloat = 2.1
    static let cheeks = [CGPoint(x: 32, y: 51), CGPoint(x: 118, y: 51)]
    static let cheekRadius: CGFloat = 7.6

    // Stroke widths, in reference units. Converted to points by
    // `HopCanvas.unit(for:)` at the one place they are used.
    static let closedEyeStroke: CGFloat = 3.2
    static let smileStroke: CGFloat = 3.4
    static let strapStroke: CGFloat = 4
    static let wiggleStroke: CGFloat = 2.4
    static let tongueStroke: CGFloat = 7
    static let tongueTipRadius: CGFloat = 5.5
}

// MARK: - Path primitives

/// Everything Hop is made of is an ellipse, a capsule or a rounded rectangle,
/// and the whole green body is filled as a single path so it has no seams. That
/// only works if every sub-path winds the same way — a sub-path wound the other
/// way punches a hole under the non-zero rule — so all three primitives are
/// built here from arcs that sweep in one direction, rather than from
/// `addEllipse`/`addRect`, whose winding is not specified to agree.
extension Path {
    /// Appends an elliptical arc sweeping from `from` to `to` degrees, always in
    /// the direction of increasing angle.
    mutating func addHopArc(centre: CGPoint, radii: CGSize, from: Double, to: Double) {
        let segments = max(1, Int(ceil(abs(to - from) / 90)))
        let step = (to - from) / Double(segments)
        for index in 0..<segments {
            let a0 = (from + step * Double(index)) * .pi / 180
            let a1 = (from + step * Double(index + 1)) * .pi / 180
            let k = 4.0 / 3.0 * tan((a1 - a0) / 4)
            let start = CGPoint(
                x: centre.x + radii.width * cos(a0),
                y: centre.y + radii.height * sin(a0)
            )
            let end = CGPoint(
                x: centre.x + radii.width * cos(a1),
                y: centre.y + radii.height * sin(a1)
            )
            if currentPoint == nil { move(to: start) }
            addCurve(
                to: end,
                control1: CGPoint(
                    x: start.x - k * radii.width * sin(a0),
                    y: start.y + k * radii.height * cos(a0)
                ),
                control2: CGPoint(
                    x: end.x + k * radii.width * sin(a1),
                    y: end.y - k * radii.height * cos(a1)
                )
            )
        }
    }

    mutating func addHopEllipse(centre: CGPoint, radii: CGSize) {
        guard radii.width > 0, radii.height > 0 else { return }
        move(to: CGPoint(x: centre.x + radii.width, y: centre.y))
        addHopArc(centre: centre, radii: radii, from: 0, to: 360)
        closeSubpath()
    }

    mutating func addHopCircle(centre: CGPoint, radius: CGFloat) {
        addHopEllipse(centre: centre, radii: CGSize(width: radius, height: radius))
    }

    /// A rounded rectangle wound to match ``addHopEllipse``.
    mutating func addHopRoundedRect(_ rect: CGRect, radius: CGFloat) {
        let r = min(radius, min(rect.width, rect.height) / 2)
        guard rect.width > 0, rect.height > 0 else { return }
        let radii = CGSize(width: r, height: r)
        move(to: CGPoint(x: rect.maxX, y: rect.minY + r))
        addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        addHopArc(centre: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radii: radii, from: 0, to: 90)
        addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        addHopArc(centre: CGPoint(x: rect.minX + r, y: rect.maxY - r), radii: radii, from: 90, to: 180)
        addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        addHopArc(centre: CGPoint(x: rect.minX + r, y: rect.minY + r), radii: radii, from: 180, to: 270)
        addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        addHopArc(centre: CGPoint(x: rect.maxX - r, y: rect.minY + r), radii: radii, from: 270, to: 360)
        closeSubpath()
    }

    /// A limb: round-capped, `rootWidth` across where it leaves the body and
    /// `tipWidth` where it ends. The twin of `taperD` in `Scripts/hop-art.js`.
    ///
    /// The sides are the two end circles' external tangents, so the outline is
    /// exact rather than a trapezoid poking out of the caps. The asymmetry
    /// matters and is easy to get backwards: with `t` the angle whose sine is
    /// the radius difference over the length, the tip sweeps `180° − 2t` (under
    /// a semicircle) while the root sweeps `180° + 2t` (over one). Give the root
    /// the short sweep and it cuts straight across the joint instead of bulging
    /// behind it — the limb loses its root, and a wide root like a crouched
    /// haunch collapses into a flat-topped slab.
    mutating func addHopTaper(
        from start: CGPoint,
        to end: CGPoint,
        rootWidth: CGFloat,
        tipWidth: CGFloat
    ) {
        let r1 = rootWidth / 2
        let r2 = tipWidth / 2
        guard r1 > 0, r2 > 0 else { return }
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = (dx * dx + dy * dy).squareRoot()
        // One circle swallowing the other has no external tangent; the bigger
        // circle is then the whole limb.
        guard length > abs(r1 - r2) + 0.0001 else {
            addHopCircle(centre: r1 >= r2 ? start : end, radius: max(r1, r2))
            return
        }
        let t = asin(Double(r1 - r2) / Double(length)) * 180 / .pi
        var local = Path()
        let topAngle = t - 90
        let bottomAngle = 90 - t
        let tipCentre = CGPoint(x: length, y: 0)
        local.move(to: CGPoint(
            x: Double(r1) * cos(topAngle * .pi / 180),
            y: Double(r1) * sin(topAngle * .pi / 180)
        ))
        local.addLine(to: CGPoint(
            x: Double(length) + Double(r2) * cos(topAngle * .pi / 180),
            y: Double(r2) * sin(topAngle * .pi / 180)
        ))
        local.addHopArc(
            centre: tipCentre, radii: CGSize(width: r2, height: r2),
            from: topAngle, to: bottomAngle
        )
        local.addLine(to: CGPoint(
            x: Double(r1) * cos(bottomAngle * .pi / 180),
            y: Double(r1) * sin(bottomAngle * .pi / 180)
        ))
        local.addHopArc(
            centre: .zero, radii: CGSize(width: r1, height: r1),
            from: bottomAngle, to: topAngle + 360
        )
        local.closeSubpath()
        addPath(local.applying(
            CGAffineTransform(rotationAngle: atan2(dy, dx))
                .concatenating(CGAffineTransform(translationX: start.x, y: start.y))
        ))
    }

    /// A round-capped segment, filled rather than stroked.
    ///
    /// The generator draws limbs, fingers and toes as `stroke-linecap="round"`
    /// lines. A stroke cannot join into the same filled path as the rest of the
    /// body, so each one is built here as the shape that stroke would have
    /// produced.
    mutating func addHopCapsule(from start: CGPoint, to end: CGPoint, radius: CGFloat) {
        guard radius > 0 else { return }
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0.0001 else {
            addHopCircle(centre: start, radius: radius)
            return
        }
        // The caps sit *beyond* the two points, as a round line cap does — a
        // capsule that stopped at them would leave every hand and every toe one
        // radius short.
        var local = Path()
        local.addHopRoundedRect(
            CGRect(x: -radius, y: -radius, width: length + radius * 2, height: radius * 2),
            radius: radius
        )
        let placed = local.applying(
            CGAffineTransform(rotationAngle: atan2(dy, dx))
                .concatenating(CGAffineTransform(translationX: start.x, y: start.y))
        )
        addPath(placed)
    }
}

// MARK: - Pose transforms

extension HopPoseGeometry {
    /// `translate(0 -lift) translate(75 100) rotate(lean) translate(-75 -100)`
    /// from the generator's `figure`, in the order `CGAffineTransform` applies.
    var bodyTransform: CGAffineTransform {
        CGAffineTransform(translationX: -HopAnatomy.hipCentre.x, y: -HopAnatomy.hipCentre.y)
            .concatenating(CGAffineTransform(rotationAngle: lean * .pi / 180))
            .concatenating(CGAffineTransform(translationX: HopAnatomy.hipCentre.x, y: HopAnatomy.hipCentre.y))
            .concatenating(CGAffineTransform(translationX: 0, y: -lift))
    }

    /// The head's own `rotate(tilt 75 50)`, on its own — the silhouette needs it
    /// separately, because that layer is one path in body space and the head is
    /// the only part of it that carries a rotation of its own.
    var headTilt: CGAffineTransform {
        CGAffineTransform(translationX: -HopAnatomy.faceCentre.x, y: -HopAnatomy.faceCentre.y)
            .concatenating(CGAffineTransform(rotationAngle: tilt * .pi / 180))
            .concatenating(CGAffineTransform(translationX: HopAnatomy.faceCentre.x, y: HopAnatomy.faceCentre.y))
    }

    /// The head's rotation inside the body group.
    var headTransform: CGAffineTransform { headTilt.concatenating(bodyTransform) }

    /// Scales the open mouth about the face centre, as `mouth()` does.
    var mouthTransform: CGAffineTransform {
        CGAffineTransform(translationX: -HopAnatomy.faceCentre.x, y: -HopAnatomy.faceCentre.y)
            .concatenating(CGAffineTransform(scaleX: mouthOpenScale, y: mouthOpenScale))
            .concatenating(CGAffineTransform(translationX: HopAnatomy.faceCentre.x, y: HopAnatomy.faceCentre.y))
            .concatenating(headTransform)
    }
}

// MARK: - The figure

/// One layer of Hop, drawn from a pose.
///
/// Every layer is the same shape type carrying the same ``HopPoseGeometry``, so
/// they all animate off one `animatableData` and cannot fall out of step with
/// each other mid-transition. The layers exist only because the drawing changes
/// colour: the generator emits one flat fill per value in the ramp, in a fixed
/// order, and ``HopCharacterView`` stacks these in exactly that order.
struct HopFigureShape: Shape {
    var geometry: HopPoseGeometry
    var part: Part

    /// In `figure`'s draw order: shadow, silhouette, pack, legs, torso, belly,
    /// arms, head, face, tongue, wiggle.
    ///
    /// **The split is the separation system.** Every limb is its own case
    /// because every limb has to carry its own rim, and a rim only appears
    /// where that part crosses something already drawn. So the order of these
    /// cases *is* the list of boundaries the drawing has: a foot after its own
    /// shin gives foot-against-leg, a hand after its own arm gives
    /// hand-against-arm and hand-against-hand, the torso after both legs gives
    /// leg-against-body, and the head last gives arm-against-head — which is
    /// the failure everybody could name.
    ///
    /// Each leg is finished before the other one starts, creases and all,
    /// because a pose that crosses the feet (`full` brings them together)
    /// otherwise draws both sets of creases over the far foot.
    enum Part {
        case shadow
        /// Every body shape at once, in one path: the exterior edge. Drawn
        /// under everything and in one flat colour, so the union has no
        /// interior seams and only the outside of Hop survives.
        case silhouette
        case pack
        case packStrap
        case shinLeft
        case footLeft
        case shinRight
        case footRight
        case torso
        case belly
        case armLeft
        case handLeft
        case armRight
        case handRight
        case head
        case spots
        case eyeWhites
        case pupils
        case highlights
        case lids
        case closedEyes
        case cheeks
        case nostrils
        case mouthInterior
        case mouthTongue
        case smile
        case tongue
        case wiggle
    }

    var animatableData: HopAnimatableVector {
        get { geometry.animationVector }
        set { geometry.animationVector = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        build(&path)
        let transform: CGAffineTransform = switch part {
        // The shadow sits on the ground, outside the group the lift moves.
        case .shadow: .identity
        case .head, .spots, .eyeWhites, .pupils, .highlights, .lids,
             .closedEyes, .cheeks, .nostrils, .smile, .tongue:
            geometry.headTransform
        case .mouthInterior, .mouthTongue:
            geometry.mouthTransform
        default:
            geometry.bodyTransform
        }
        return HopCanvas.place(path.applying(transform), in: rect)
    }

    // MARK: Parts

    private func build(_ path: inout Path) {
        switch part {
        case .shadow: shadow(&path)
        case .silhouette: silhouette(&path)
        case .pack: pack(&path)
        case .packStrap: packStrap(&path)
        case .shinLeft: shin(geometry.legL, into: &path)
        case .footLeft: foot(geometry.legL, side: -1, into: &path)
        case .shinRight: shin(geometry.legR, into: &path)
        case .footRight: foot(geometry.legR, side: 1, into: &path)
        case .torso: torso(&path)
        case .belly: belly(&path)
        case .armLeft: arm(to: geometry.armL, from: HopAnatomy.shoulderL, into: &path)
        case .handLeft: hand(at: geometry.armL, from: HopAnatomy.shoulderL, into: &path)
        case .armRight: arm(to: geometry.armR, from: HopAnatomy.shoulderR, into: &path)
        case .handRight: hand(at: geometry.armR, from: HopAnatomy.shoulderR, into: &path)
        case .head: head(&path)
        case .spots: spots(&path)
        case .eyeWhites: eyeWhites(&path)
        case .pupils: pupils(&path)
        case .highlights: highlights(&path)
        case .lids: lids(&path)
        case .closedEyes: closedEyes(&path)
        case .cheeks: cheeks(&path)
        case .nostrils: nostrils(&path)
        case .mouthInterior: mouthInterior(&path)
        case .mouthTongue: mouthTongue(&path)
        case .smile: smile(&path)
        case .tongue: tongue(&path)
        case .wiggle: wiggle(&path)
        }
    }

    private func shadow(_ path: inout Path) {
        path.addHopEllipse(
            centre: CGPoint(x: 75, y: HopAnatomy.groundLine - geometry.lift * 0.1),
            radii: CGSize(
                width: max(0, HopAnatomy.shadowRadii.width - geometry.lift * 0.4),
                height: HopAnatomy.shadowRadii.height
            )
        )
    }

    private func pack(_ path: inout Path) {
        path.addHopRoundedRect(CGRect(x: 98, y: 84, width: 22, height: 30), radius: 9)
    }

    private func packStrap(_ path: inout Path) {
        path.move(to: CGPoint(x: 92, y: 78))
        path.addQuadCurve(to: CGPoint(x: 108, y: 98), control: CGPoint(x: 104, y: 82))
    }

    /// Hop's whole outline, as one path.
    ///
    /// Every body shape, in body space, with the head's own tilt folded in —
    /// the head is the only part that carries a rotation the body group does
    /// not. The view strokes this once in `hop-outline` and fills it in the
    /// same colour, which grows it by the stroke's half-width and leaves a
    /// clean exterior edge with no interior seams anywhere.
    ///
    /// The belly and the face are not in it: the belly is inside the torso, and
    /// a silhouette with a mouth in it is not a silhouette. Neither is the
    /// ground shadow, which is not part of Hop.
    private func silhouette(_ path: inout Path) {
        if geometry.withPack {
            pack(&path)
            // The strap is a stroke, not a fill; it contributes nothing the
            // pack's own body does not already cover on the outside.
        }
        shin(geometry.legL, into: &path)
        foot(geometry.legL, side: -1, into: &path)
        shin(geometry.legR, into: &path)
        foot(geometry.legR, side: 1, into: &path)
        torso(&path)
        arm(to: geometry.armL, from: HopAnatomy.shoulderL, into: &path)
        hand(at: geometry.armL, from: HopAnatomy.shoulderL, into: &path)
        arm(to: geometry.armR, from: HopAnatomy.shoulderR, into: &path)
        hand(at: geometry.armR, from: HopAnatomy.shoulderR, into: &path)
        var crown = Path()
        head(&crown)
        path.addPath(crown.applying(geometry.headTilt))
    }

    /// The shin: hip to ankle, one tapered limb.
    ///
    /// The widths come from the pose, not from `HopAnatomy`, because the crouch
    /// draws its folded back leg as this same shape with a much wider root.
    private func shin(_ shape: HopLegGeometry, into path: inout Path) {
        path.addHopTaper(
            from: shape.hip, to: shape.ankle,
            rootWidth: shape.rootWidth, tipWidth: shape.tipWidth
        )
    }

    /// The foot: the sole, and three toes fanned outward and down. `side` −1 is
    /// Hop's right, the viewer's left. It is a part of its own — not part of the
    /// leg — because "the foot is distinguishable from the leg above it" is one
    /// of the things the silhouette check asks, and the answer is this rim.
    private func foot(_ shape: HopLegGeometry, side: Double, into path: inout Path) {
        let foot = footCentre(for: shape, side: side)
        let reachX = Double(HopAnatomy.toeReach.width)
        let reachY = Double(HopAnatomy.toeReach.height)
        path.addHopEllipse(centre: foot, radii: HopAnatomy.soleRadii)
        for toe in HopAnatomy.toes {
            let angle = toeAngle(toe.angle, side: side) * .pi / 180
            path.addHopCapsule(
                from: foot,
                to: CGPoint(
                    x: Double(foot.x) + cos(angle) * reachX * shape.toeSpread,
                    y: Double(foot.y) + sin(angle) * reachY
                ),
                radius: toe.radius
            )
        }
    }


    private func footCentre(for shape: HopLegGeometry, side: Double) -> CGPoint {
        CGPoint(x: Double(shape.ankle.x) - side * 2, y: Double(shape.ankle.y) + 3)
    }

    private func toeAngle(_ degrees: Double, side: Double) -> Double {
        side < 0 ? 180 + degrees : -degrees
    }

    /// Straight sides that run up under the jaw, rounded only at the hips — the
    /// reference has no neck, the body tucks up behind the head.
    private func torso(_ path: inout Path) {
        let width = geometry.torsoWidth
        let x0 = 75 - width / 2
        let x1 = 75 + width / 2
        let top = 58 + geometry.squash * 4
        let bottom = geometry.torsoBottom ?? (127 - geometry.squash * 4)
        let r = min(26, width / 2)
        guard bottom - top > r else { return }
        let radii = CGSize(width: r, height: r)
        path.move(to: CGPoint(x: x0, y: top))
        path.addLine(to: CGPoint(x: x1, y: top))
        path.addLine(to: CGPoint(x: x1, y: bottom - r))
        path.addHopArc(centre: CGPoint(x: x1 - r, y: bottom - r), radii: radii, from: 0, to: 90)
        path.addLine(to: CGPoint(x: x0 + r, y: bottom))
        path.addHopArc(centre: CGPoint(x: x0 + r, y: bottom - r), radii: radii, from: 90, to: 180)
        path.closeSubpath()
    }

    private func belly(_ path: inout Path) {
        if let belly = geometry.belly {
            path.addHopEllipse(
                centre: CGPoint(x: 75, y: belly.cy),
                radii: CGSize(width: belly.rx, height: belly.ry)
            )
            return
        }
        let scale = geometry.bellyScale
        path.addHopEllipse(
            centre: CGPoint(x: 75, y: 104 + (scale - 1) * 4),
            radii: CGSize(width: 24 * scale, height: 23 * scale)
        )
    }

    /// The upper arm: a capsule from a fixed shoulder to the pose's hand point.
    ///
    /// In the generator this is authored in the arm's own space and placed with
    /// `translate(shoulder) rotate(θ)`; here the two ends are enough, because a
    /// `Path` has no group to hang a transform on. The geometry is the same one.
    private func arm(to hand: CGPoint, from shoulder: CGPoint, into path: inout Path) {
        path.addHopTaper(
            from: shoulder, to: hand,
            rootWidth: geometry.armWidth, tipWidth: geometry.armTipWidth
        )
    }

    /// The hand: a palm and three fingers fanned about the direction the arm
    /// ended up pointing. The fingers are what make a hand read as a hand — and
    /// the hand is a part of its own so that it carries a rim against the arm,
    /// against the belly, and against the other hand.
    private func hand(at hand: CGPoint, from shoulder: CGPoint, into path: inout Path) {
        // Planted: a sitting frog puts its forelimbs down the way it puts its
        // hind ones down, so the hand becomes the foot's shape at 0.82 scale,
        // fanned from the horizon rather than from the wrist. Hanging fingers
        // off a vertical arm instead points the longest one straight at the
        // floor, which reads as a spike and — measurably — was the ink that
        // pushed the pose off the bottom of its canvas.
        if geometry.pawSpread > 0 {
            let side: Double = hand.x < 75 ? -1 : 1
            let scale = 0.82
            path.addHopEllipse(
                centre: hand,
                radii: CGSize(
                    width: HopAnatomy.soleRadii.width * scale,
                    height: HopAnatomy.soleRadii.height * scale
                )
            )
            for toe in HopAnatomy.toes {
                let angle = toeAngle(toe.angle, side: side) * .pi / 180
                path.addHopCapsule(
                    from: hand,
                    to: CGPoint(
                        x: Double(hand.x) + cos(angle)
                            * Double(HopAnatomy.toeReach.width) * geometry.pawSpread * scale,
                        y: Double(hand.y) + sin(angle)
                            * Double(HopAnatomy.toeReach.height) * scale
                    ),
                    radius: toe.radius * scale
                )
            }
            return
        }
        path.addHopCircle(centre: hand, radius: HopAnatomy.palmRadius)
        let direction = atan2(Double(hand.y - shoulder.y), Double(hand.x - shoulder.x))
        let reach = Double(HopAnatomy.fingerLength)
        for spread in HopAnatomy.fingerAngles {
            let angle = direction + spread * .pi / 180
            path.addHopCapsule(
                from: hand,
                to: CGPoint(
                    x: Double(hand.x) + cos(angle) * reach,
                    y: Double(hand.y) + sin(angle) * reach
                ),
                radius: HopAnatomy.fingerWidth / 2
            )
        }
    }

    /// Crown, jaw and the two eye sockets — one fill, no seams.
    private func head(_ path: inout Path) {
        path.addHopEllipse(centre: HopAnatomy.crownCentre, radii: HopAnatomy.crownRadii)
        path.addHopEllipse(centre: HopAnatomy.jawCentre, radii: HopAnatomy.jawRadii)
        path.addHopCircle(centre: HopAnatomy.eyeL, radius: HopAnatomy.socketRadius)
        path.addHopCircle(centre: HopAnatomy.eyeR, radius: HopAnatomy.socketRadius)
    }

    private func spots(_ path: inout Path) {
        for spot in HopAnatomy.spots {
            path.addHopEllipse(centre: spot.centre, radii: spot.radii)
        }
    }

    /// The white squashes shut as the blink closes, and everything inside the
    /// eye is clipped to it, so a lowered lid or a rolled pupil can never show
    /// outside the eye. Unclipped, the lid read as a pair of ears.
    private func eyeWhites(_ path: inout Path) {
        let openness = max(0, 1 - geometry.eyes.blink)
        guard openness > 0 else { return }
        for centre in [HopAnatomy.eyeL, HopAnatomy.eyeR] {
            path.addHopEllipse(
                centre: centre,
                radii: CGSize(
                    width: HopAnatomy.whiteRadius,
                    height: HopAnatomy.whiteRadius * openness
                )
            )
        }
    }

    private func pupils(_ path: inout Path) {
        for centre in [HopAnatomy.eyeL, HopAnatomy.eyeR] {
            path.addHopCircle(
                centre: CGPoint(
                    x: centre.x + geometry.eyes.gaze.width,
                    y: centre.y + HopAnatomy.pupilOffset.height + geometry.eyes.gaze.height
                ),
                radius: HopAnatomy.pupilRadius
            )
        }
    }

    private func highlights(_ path: inout Path) {
        for centre in [HopAnatomy.eyeL, HopAnatomy.eyeR] {
            path.addHopCircle(
                centre: CGPoint(
                    x: centre.x + geometry.eyes.gaze.width + HopAnatomy.highlightOffset.width,
                    y: centre.y + geometry.eyes.gaze.height + HopAnatomy.highlightOffset.height
                ),
                radius: HopAnatomy.highlightRadius
            )
        }
    }

    /// The drooping upper lid: a body-green disc lowered over the white.
    private func lids(_ path: inout Path) {
        guard geometry.eyes.lidDrop > 0 else { return }
        let r = HopAnatomy.whiteRadius
        let drop = 2 * r + 1 - 2 * r * geometry.eyes.lidDrop
        for centre in [HopAnatomy.eyeL, HopAnatomy.eyeR] {
            path.addHopCircle(centre: CGPoint(x: centre.x, y: centre.y - drop), radius: r + 1)
        }
    }

    /// The line a shut eye leaves: up for delight, down for rest.
    private func closedEyes(_ path: inout Path) {
        let direction = geometry.eyes.closedArcDirection
        for centre in [HopAnatomy.eyeL, HopAnatomy.eyeR] {
            path.move(to: CGPoint(x: centre.x - 10, y: centre.y + 3))
            path.addQuadCurve(
                to: CGPoint(x: centre.x + 10, y: centre.y + 3),
                control: CGPoint(x: centre.x, y: centre.y + 3 + direction * 9)
            )
        }
    }

    private func cheeks(_ path: inout Path) {
        for centre in HopAnatomy.cheeks {
            path.addHopCircle(centre: centre, radius: HopAnatomy.cheekRadius)
        }
    }

    private func nostrils(_ path: inout Path) {
        for centre in HopAnatomy.nostrils {
            path.addHopCircle(centre: centre, radius: HopAnatomy.nostrilRadius)
        }
    }

    /// The open mouth. Scaled about the face centre by the pose, so `talk` is
    /// the same mouth at 72% and a mouth that is closing shrinks into the face
    /// rather than blinking out.
    private func mouthInterior(_ path: inout Path) {
        path.move(to: CGPoint(x: 53, y: 47.5))
        path.addQuadCurve(to: CGPoint(x: 97, y: 47.5), control: CGPoint(x: 75, y: 52))
        path.addCurve(
            to: CGPoint(x: 75, y: 69.5),
            control1: CGPoint(x: 96, y: 60),
            control2: CGPoint(x: 88, y: 69.5)
        )
        path.addCurve(
            to: CGPoint(x: 53, y: 47.5),
            control1: CGPoint(x: 62, y: 69.5),
            control2: CGPoint(x: 54, y: 60)
        )
        path.closeSubpath()
    }

    /// The tongue inside an open mouth, clipped to the mouth by the view.
    private func mouthTongue(_ path: inout Path) {
        path.addHopEllipse(centre: CGPoint(x: 75, y: 66), radii: CGSize(width: 15, height: 7.5))
    }

    private func smile(_ path: inout Path) {
        path.move(to: CGPoint(x: 58, y: 50))
        path.addQuadCurve(
            to: CGPoint(x: 92, y: 50),
            control: CGPoint(x: 75, y: 50 + geometry.mouthSmileDepth)
        )
    }

    /// A tongue out for a fly: a thick capsule with a rounder tip, so it reads
    /// as a tongue and not a rope.
    private func tongue(_ path: inout Path) {
        path.addHopCapsule(
            from: HopAnatomy.tongueOrigin,
            to: geometry.tongueTip,
            radius: HopAnatomy.tongueStroke / 2
        )
        path.addHopCircle(centre: geometry.tongueTip, radius: HopAnatomy.tongueTipRadius)
    }

    /// Soft motion marks either side of the body, for the "I need to go" wiggle.
    private func wiggle(_ path: inout Path) {
        let marks: [(start: CGPoint, control: CGSize, end: CGSize)] = [
            (start: CGPoint(x: 36, y: 96), control: CGSize(width: -5, height: 6), end: CGSize(width: 0, height: 12)),
            (start: CGPoint(x: 30, y: 92), control: CGSize(width: -7, height: 9), end: CGSize(width: 0, height: 18)),
            (start: CGPoint(x: 114, y: 96), control: CGSize(width: 5, height: 6), end: CGSize(width: 0, height: 12)),
            (start: CGPoint(x: 120, y: 92), control: CGSize(width: 7, height: 9), end: CGSize(width: 0, height: 18)),
        ]
        for mark in marks {
            path.move(to: mark.start)
            path.addQuadCurve(
                to: CGPoint(x: mark.start.x + mark.end.width, y: mark.start.y + mark.end.height),
                control: CGPoint(x: mark.start.x + mark.control.width, y: mark.start.y + mark.control.height)
            )
        }
    }
}
