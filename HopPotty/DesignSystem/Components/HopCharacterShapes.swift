import SwiftUI

/// Hop's authoring spaces.
///
/// He is drawn in the 150-wide reference space `Scripts/hop-art.js` works in —
/// the head is 122 units across, x 13.5…136.5 — exactly as the generator draws
/// him, so every number in ``HopPoseGeometry`` and ``HopAnatomy`` can be checked
/// against it line for line. That space is then placed onto the 512 × 512
/// canvas the art files ship in, and the canvas is fitted to whatever rectangle
/// the view was given. Two steps, both at the edge, so nothing in between has to
/// know how big Hop is on screen.
///
/// ## The placement is not a preference, it is a fit
///
/// It used to be `scale 3.2, offset (16, 0)`, which was hand-written and wrong:
/// fourteen of the fifteen poses were clipped, and `jump` lost the top of its
/// head, which is what a caregiver reported. `Scripts/check-hop-fit.js` now
/// measures the rendered alpha bounds of every pose and fails on any content
/// that touches an edge.
///
/// These numbers are the generator's, solved rather than chosen: the stage
/// rectangle the pose set occupies is `x −6…156`, `y −3…164`, so a 512 canvas
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

    /// The reference y a grounded pose's toes touch, and the ankle of a
    /// standing leg that puts them there. Every crouch pose in `hop-art.js`
    /// carries `lift: -6` so its four contact points land on the same line —
    /// which is what lets a screen place any pose with one constant.
    static let groundLine: CGFloat = 163.6
    static let groundAnkle: CGFloat = 150

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

/// How heavy Hop's outline is.
///
/// One number: the visible width of **every** boundary in the drawing, in
/// reference units. The exterior edge, the belly's edge, each limb, each finger
/// and toe, the eye whites and the mouth are all drawn at exactly this width in
/// the same opaque colour. The reference is a flat sticker with one outline; an
/// internal line lighter or thinner than the outside one is the thing it does
/// not have, and the thing this type no longer carries.
///
/// The width is multiplied by ``HopCanvas/unit(for:)`` at the one place it is
/// used, so the outline scales with Hop exactly as every other line in the
/// drawing does. That is deliberate and it is why the SVG side rejects
/// `vector-effect="non-scaling-stroke"`: a stroke pinned to device pixels would
/// be eight times heavier relative to the body at 64pt than at 512pt.
///
/// The numbers are `OUTLINE` in `Scripts/hop-art.js`. `hero` is the reference
/// exactly — 14 px on a 765 px head is 2.24 units — and the others step up as
/// Hop gets smaller, because a width that is right at 320pt is under a pixel
/// on a chip. `highContrast` is capped at 3.0 by the canvas rather than by
/// taste: `jump`'s domes and every standing pose's toes are the ink nearest an
/// edge, and `check-hop-fit.js` fails below 6 units of air.
struct HopOutlineStyle: Equatable, Sendable {
    var width: CGFloat

    /// No outline at all. Not a shipping state — it is the test that the pose
    /// and the depth order hold Hop up on their own.
    static let off = HopOutlineStyle(width: 0)
    /// 200pt and up: the reference's own weight.
    static let hero = HopOutlineStyle(width: 2.2)
    /// The everyday state, and what `Art/character/hop-*.svg` ships with.
    static let standard = HopOutlineStyle(width: 2.4)
    /// Over illustration — pond water, vegetation green, a dark sky — where the
    /// background is Hop's own hue and the silhouette is all that is left.
    static let scene = HopOutlineStyle(width: 2.6)
    /// 96pt and below, where the everyday edge is under a pixel.
    static let small = HopOutlineStyle(width: 2.8)
    /// Increase Contrast, and any accessibility appearance.
    static let highContrast = HopOutlineStyle(width: 3.0)

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

/// Which of the owner's two reference bodies a pose is drawn on.
///
/// The head is identical on both. `standing` is reference 2 — a rounded torso,
/// a circle belly, ta-da arms, two leg columns. `crouch` is reference 1 — a
/// tall oval belly, a haunch either side of it, back feet at the outer corners
/// and the front arms straight down to hands on the ground. Every pose on the
/// ground or a lily pad uses the crouch.
enum HopBodyKind: Equatable, Sendable {
    case standing
    case crouch
}

/// Hop's left or right, from the viewer's side: `left` is the viewer's left.
enum HopSide: Hashable, Sendable {
    case left
    case right

    /// −1 for the viewer's left, +1 for the right: the direction "outward".
    var sign: Double {
        self == .left ? -1 : 1
    }
}

/// The fixed numbers of Hop's body — the ones a pose never changes.
///
/// Transcribed from the constants and part functions at the top of
/// `Scripts/hop-art.js`, which converted the owner's reference drawings at
/// 6.25 px per unit. A pose sets where the hands and feet are; this sets what
/// a hand and a foot *are*.
enum HopAnatomy {
    // The head: two big domes on a wide jaw, with the crown between them well
    // below the domes' tops — that dip is the "M" of the silhouette.
    static let eyeL = CGPoint(x: 41.5, y: 27)
    static let eyeR = CGPoint(x: 108.5, y: 27)
    static let domeRadius: CGFloat = 21.5
    static let crownCentre = CGPoint(x: 75, y: 40)
    static let crownRadii = CGSize(width: 36, height: 23)
    static let jawCentre = CGPoint(x: 75, y: 55)
    static let jawRadii = CGSize(width: 61.5, height: 30)

    static let whiteRadius: CGFloat = 11.2
    /// 83% of the white. Very large, and it leaves 1.9 units of gaze travel.
    static let pupilRadius: CGFloat = 9.3
    /// The pupil sits slightly inward (`width`, toward the face's centre) and
    /// slightly low (`height`) of the white's centre.
    static let pupilOffset = CGSize(width: 0.6, height: 1)
    /// One catchlight, top-left of the pupil, about 30% of its diameter.
    static let highlightOffset = CGSize(width: -3, height: -3.2)
    static let highlightRadius: CGFloat = 2.8

    // Limbs.
    static let armWidth: CGFloat = 11.2
    /// Three fingers fan about the arm's own direction — up, out, down — and
    /// are drawn in this order so the middle one lands on top with a clean
    /// line either side.
    static let fingerAngles: [Double] = [-60, 60, 0]
    static let fingerLength: CGFloat = 9.5
    static let fingerWidth: CGFloat = 9.6
    static let legWidth: CGFloat = 15.2
    static let toeLength: CGFloat = 7.5
    static let toeWidth: CGFloat = 9.5
    /// The toes fan from a point just outward (`width`) and below (`height`)
    /// the ankle.
    static let footOffset = CGSize(width: 2, height: 1)
    /// The crouch haunch: a fat lobe centred on the pose's hip, tilted so its
    /// bottom swings outward.
    static let haunchRadii = CGSize(width: 18.5, height: 25)
    static let haunchTilt: Double = 15

    /// What differs between the two bodies besides the poses that use them.
    struct Body {
        var shoulderL: CGPoint
        var shoulderR: CGPoint
        /// Toe angles from straight down, outward positive, in draw order.
        var toes: [Double]
        /// Fixed torso sides, or `nil` to centre the pose's `torsoWidth`.
        var torsoSides: (x0: CGFloat, x1: CGFloat)?
        var torsoTop: CGFloat
        var torsoBottom: CGFloat
        var torsoRadius: CGFloat
        /// Whether the arms are drawn over the torso and belly. Standing, they
        /// attach behind the torso's sides so its edge is their boundary and no
        /// shoulder seam lands on the chest; crouching, the front legs are in
        /// front of the belly, as a sitting frog's are.
        var armsInFront: Bool
    }

    static let standing = Body(
        shoulderL: CGPoint(x: 50.5, y: 94.5), shoulderR: CGPoint(x: 99.5, y: 94.5),
        toes: [-40, 70, 15],
        torsoSides: nil, torsoTop: 70, torsoBottom: 139, torsoRadius: 16,
        armsInFront: false
    )
    static let crouch = Body(
        shoulderL: CGPoint(x: 44, y: 90), shoulderR: CGPoint(x: 106, y: 90),
        toes: [0, 80, 40],
        torsoSides: (x0: 51, x1: 99), torsoTop: 70, torsoBottom: 144, torsoRadius: 20,
        armsInFront: true
    )

    static func body(_ kind: HopBodyKind) -> Body {
        kind == .crouch ? crouch : standing
    }

    /// The point the head rotates about, and the mouth scales about.
    static let faceCentre = CGPoint(x: 75, y: 50)
    /// The point the body leans about.
    static let hipCentre = CGPoint(x: 75, y: 100)
    /// Where a tongue leaves the mouth.
    static let tongueOrigin = HopPoseGeometry.tongueOrigin

    /// The top of Hop's head, in reference units: the domes.
    static let crownTop: CGFloat = eyeL.y - domeRadius

    /// The floor Hop stands on, in reference units — the line the ground shadow
    /// is centred on in `figure()`, which is ``HopCanvas/groundLine`` less the
    /// shadow's own height so that the toes touch the shadow rather than pierce
    /// it. Motion anchors here rather than at the bottom of the view, because
    /// the view is a square and Hop is not.
    static let shadowRadii = CGSize(width: 40, height: 3.6)
    static let groundLine: CGFloat = HopCanvas.groundLine - shadowRadii.height

    /// The head's bounding box in reference space: the jaw sets the width, the
    /// domes the top, the jaw the bottom.
    static let headBoundsInReference = CGRect(
        x: jawCentre.x - jawRadii.width,
        y: eyeL.y - domeRadius,
        width: jawRadii.width * 2,
        height: (jawCentre.y + jawRadii.height) - (eyeL.y - domeRadius)
    )

    /// The same box on the 512 canvas — what ``HopPoseGeometry/faceCrop`` is.
    static let headBoundsOnCanvas = headBoundsInReference.applying(HopCanvas.referenceTransform)

    /// The three darker spots on the forehead. No outline.
    static let spots: [(centre: CGPoint, radius: CGFloat)] = [
        (centre: CGPoint(x: 75, y: 23), radius: 3.8),
        (centre: CGPoint(x: 70.5, y: 28.5), radius: 2.4),
        (centre: CGPoint(x: 79.5, y: 28.5), radius: 2.4),
    ]
    static let nostrils = [CGPoint(x: 66.5, y: 43.5), CGPoint(x: 83.5, y: 43.5)]
    static let nostrilRadius: CGFloat = 1.9
    /// Low and wide on the jaw. No outline.
    static let cheeks = [CGPoint(x: 31.5, y: 54.5), CGPoint(x: 118.5, y: 54.5)]
    static let cheekRadius: CGFloat = 7.2

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

    /// An ellipse rotated about its own centre by `degrees`, as the generator's
    /// `ellipseD(…, deg)` draws the haunches.
    mutating func addHopEllipse(centre: CGPoint, radii: CGSize, rotated degrees: Double) {
        var local = Path()
        local.addHopEllipse(centre: .zero, radii: radii)
        addPath(local.applying(
            CGAffineTransform(rotationAngle: degrees * .pi / 180)
                .concatenating(CGAffineTransform(translationX: centre.x, y: centre.y))
        ))
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

    /// A round-capped segment from `start` toward `degrees`, `length` long.
    mutating func addHopRay(from start: CGPoint, degrees: Double, length: CGFloat, radius: CGFloat) {
        let angle = degrees * .pi / 180
        addHopCapsule(
            from: start,
            to: CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length),
            radius: radius
        )
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

    /// Which body the drawing is on right now. `crouch` travels in the
    /// animation vector, so a tween between a standing and a crouching pose
    /// swaps bodies at its midpoint rather than at either end.
    var isCrouch: Bool { crouch >= 0.5 }
}

// MARK: - The figure

/// One layer of Hop, drawn from a pose.
///
/// Every layer is the same shape type carrying the same ``HopPoseGeometry``, so
/// they all animate off one `animatableData` and cannot fall out of step with
/// each other mid-transition. The layers exist because every part carries its
/// own outline: ``HopCharacterView`` strokes and fills each one in the order
/// `figure()` draws them, so a part's outline lands exactly where it crosses
/// something already drawn.
struct HopFigureShape: Shape {
    var geometry: HopPoseGeometry
    var part: Part

    /// In `figure()`'s draw order: shadow, silhouette, pack, legs and toes,
    /// then — standing — arms, torso, belly; or — crouching — torso, belly,
    /// arms; then fingers, head, face, tongue, wiggle.
    ///
    /// **The split is the outline system.** Every limb, finger and toe is its
    /// own case because every one carries its own outline, and an outline only
    /// appears where that part crosses something already drawn. So the list of
    /// cases *is* the list of boundaries the drawing has: a toe after its leg
    /// gives toe-against-leg and toe-against-toe, a finger after its arm gives
    /// the wrist arc and the lines between fingers, the torso after both legs
    /// gives leg-against-body, the belly after the torso gives the belly's
    /// edge, and the head last gives head-against-everything.
    enum Part: Hashable {
        case shadow
        /// Every body shape at once, in one path: the exterior edge. Drawn
        /// under everything and in one flat colour, so the union has no
        /// interior seams and only the outside of Hop survives.
        case silhouette
        case pack
        case packStrap
        /// The leg column standing, the haunch crouching.
        case leg(HopSide)
        case toe(HopSide, Int)
        case torso
        case belly
        case arm(HopSide)
        case finger(HopSide, Int)
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

    private var anatomy: HopAnatomy.Body {
        HopAnatomy.body(geometry.isCrouch ? .crouch : .standing)
    }

    private func build(_ path: inout Path) {
        switch part {
        case .shadow: shadow(&path)
        case .silhouette: silhouette(&path)
        case .pack: pack(&path)
        case .packStrap: packStrap(&path)
        case .leg(let side): leg(side, into: &path)
        case .toe(let side, let index): toe(side, index, into: &path)
        case .torso: torso(&path)
        case .belly: belly(&path)
        case .arm(let side): arm(side, into: &path)
        case .finger(let side, let index): finger(side, index, into: &path)
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
        for side in [HopSide.left, .right] {
            leg(side, into: &path)
            for index in 0..<3 { toe(side, index, into: &path) }
        }
        for side in [HopSide.left, .right] {
            arm(side, into: &path)
            for index in 0..<3 { finger(side, index, into: &path) }
        }
        torso(&path)
        var crown = Path()
        head(&crown)
        path.addPath(crown.applying(geometry.headTilt))
    }

    private func legGeometry(_ side: HopSide) -> HopLegGeometry {
        side == .left ? geometry.legL : geometry.legR
    }

    private func hand(_ side: HopSide) -> CGPoint {
        side == .left ? geometry.armL : geometry.armR
    }

    private func shoulder(_ side: HopSide) -> CGPoint {
        side == .left ? anatomy.shoulderL : anatomy.shoulderR
    }

    /// Standing, a straight column from a hip inside the torso to the ankle.
    /// Crouching, a haunch: a fat lobe centred on the hip, tilted so its bottom
    /// swings outward.
    private func leg(_ side: HopSide, into path: inout Path) {
        let shape = legGeometry(side)
        if geometry.isCrouch {
            path.addHopEllipse(
                centre: shape.hip,
                radii: HopAnatomy.haunchRadii,
                rotated: -side.sign * HopAnatomy.haunchTilt
            )
        } else {
            path.addHopCapsule(from: shape.hip, to: shape.ankle, radius: HopAnatomy.legWidth / 2)
        }
    }

    /// One toe: a lobe from the foot point, fanned from straight down by the
    /// body's own toe angles, outward positive. The foot has no sole and no
    /// creases — three of these and nothing else.
    private func toe(_ side: HopSide, _ index: Int, into path: inout Path) {
        let shape = legGeometry(side)
        let foot = footCentre(for: shape, side: side)
        let degrees = 90 - side.sign * anatomy.toes[index]
        let angle = degrees * .pi / 180
        path.addHopCapsule(
            from: foot,
            to: CGPoint(
                x: Double(foot.x) + cos(angle) * Double(HopAnatomy.toeLength) * shape.toeSpread,
                y: Double(foot.y) + sin(angle) * Double(HopAnatomy.toeLength)
            ),
            radius: HopAnatomy.toeWidth / 2
        )
    }

    private func footCentre(for shape: HopLegGeometry, side: HopSide) -> CGPoint {
        CGPoint(
            x: Double(shape.ankle.x) + side.sign * Double(HopAnatomy.footOffset.width),
            y: Double(shape.ankle.y) + Double(HopAnatomy.footOffset.height)
        )
    }

    /// Straight sides that run up under the jaw, rounded at the hips — neither
    /// reference has a neck; the body tucks up behind the head. Crouching it
    /// is narrower than the belly's outline and all but hidden.
    private func torso(_ path: inout Path) {
        let body = anatomy
        let x0 = body.torsoSides?.x0 ?? 75 - geometry.torsoWidth / 2
        let x1 = body.torsoSides?.x1 ?? 75 + geometry.torsoWidth / 2
        let top = body.torsoTop + geometry.squash * 4
        let bottom = body.torsoBottom - geometry.squash * 4
        let r = min(body.torsoRadius, (x1 - x0) / 2)
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

    /// The cream belly: a circle standing, a tall oval crouching.
    private func belly(_ path: inout Path) {
        let scale = geometry.bellyScale
        if geometry.isCrouch {
            path.addHopEllipse(
                centre: CGPoint(x: 75, y: 114),
                radii: CGSize(width: 22.5 * scale, height: 27.2 * scale)
            )
        } else {
            path.addHopCircle(centre: CGPoint(x: 75, y: 110 + (scale - 1) * 3), radius: 24 * scale)
        }
    }

    /// The arm: a capsule from the body's shoulder to the pose's hand point.
    private func arm(_ side: HopSide, into path: inout Path) {
        path.addHopCapsule(from: shoulder(side), to: hand(side), radius: HopAnatomy.armWidth / 2)
    }

    /// One finger, fanned about the direction the arm arrived from. A part of
    /// its own so it carries an outline against its neighbour, against the arm
    /// (the wrist arc) and against whatever the hand rests on.
    private func finger(_ side: HopSide, _ index: Int, into path: inout Path) {
        let at = hand(side)
        let from = shoulder(side)
        let direction = atan2(Double(at.y - from.y), Double(at.x - from.x)) * 180 / .pi
        path.addHopRay(
            from: at,
            degrees: direction + HopAnatomy.fingerAngles[index],
            length: HopAnatomy.fingerLength,
            radius: HopAnatomy.fingerWidth / 2
        )
    }

    /// Crown, jaw and the two domes — one fill, no seams.
    private func head(_ path: inout Path) {
        path.addHopEllipse(centre: HopAnatomy.crownCentre, radii: HopAnatomy.crownRadii)
        path.addHopEllipse(centre: HopAnatomy.jawCentre, radii: HopAnatomy.jawRadii)
        path.addHopCircle(centre: HopAnatomy.eyeL, radius: HopAnatomy.domeRadius)
        path.addHopCircle(centre: HopAnatomy.eyeR, radius: HopAnatomy.domeRadius)
    }

    private func spots(_ path: inout Path) {
        for spot in HopAnatomy.spots {
            path.addHopCircle(centre: spot.centre, radius: spot.radius)
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

    /// Where each pupil sits: the white's centre, nudged inward and down, plus
    /// the gaze. `inward` is toward the face's centre, so it flips per eye.
    private func pupilCentres() -> [CGPoint] {
        [(HopAnatomy.eyeL, 1.0), (HopAnatomy.eyeR, -1.0)].map { centre, inward in
            CGPoint(
                x: centre.x + inward * HopAnatomy.pupilOffset.width + geometry.eyes.gaze.width,
                y: centre.y + HopAnatomy.pupilOffset.height + geometry.eyes.gaze.height
            )
        }
    }

    private func pupils(_ path: inout Path) {
        for centre in pupilCentres() {
            path.addHopCircle(centre: centre, radius: HopAnatomy.pupilRadius)
        }
    }

    private func highlights(_ path: inout Path) {
        for centre in pupilCentres() {
            path.addHopCircle(
                centre: CGPoint(
                    x: centre.x + HopAnatomy.highlightOffset.width,
                    y: centre.y + HopAnatomy.highlightOffset.height
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

    /// The open mouth: corners high, a deep U. Scaled about the face centre by
    /// the pose, so `talk` is the same mouth at 72% and a mouth that is closing
    /// shrinks into the face rather than blinking out. This is `MOUTH_D` in the
    /// generator.
    private func mouthInterior(_ path: inout Path) {
        path.move(to: CGPoint(x: 49.5, y: 48.5))
        path.addQuadCurve(to: CGPoint(x: 100.5, y: 48.5), control: CGPoint(x: 75, y: 52))
        path.addCurve(
            to: CGPoint(x: 75, y: 72.2),
            control1: CGPoint(x: 100, y: 62),
            control2: CGPoint(x: 90, y: 72.2)
        )
        path.addCurve(
            to: CGPoint(x: 49.5, y: 48.5),
            control1: CGPoint(x: 60, y: 72.2),
            control2: CGPoint(x: 50, y: 62)
        )
        path.closeSubpath()
    }

    /// The tongue inside an open mouth, clipped to the mouth by the view.
    private func mouthTongue(_ path: inout Path) {
        path.addHopEllipse(centre: CGPoint(x: 75, y: 67.5), radii: CGSize(width: 16, height: 8.8))
    }

    private func smile(_ path: inout Path) {
        path.move(to: CGPoint(x: 56, y: 52))
        path.addQuadCurve(
            to: CGPoint(x: 94, y: 52),
            control: CGPoint(x: 75, y: 52 + geometry.mouthSmileDepth)
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
