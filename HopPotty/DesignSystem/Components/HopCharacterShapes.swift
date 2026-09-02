import SwiftUI

/// Hop's authoring spaces.
///
/// He is drawn in the 150 × 160 space of the approved reference
/// (`hop_mascot.svg`), exactly as `Scripts/hop-art.js` draws him, so every
/// number in ``HopPoseGeometry`` and ``HopAnatomy`` can be checked against the
/// generator line for line. That space is then placed onto the 512 × 512 canvas
/// the art files ship in — scale 3.2, offset (16, 0) — and the canvas is fitted
/// to whatever rectangle the view was given. Two steps, both at the edge, so
/// nothing in between has to know how big Hop is on screen.
enum HopCanvas {
    /// The side of the shipped canvas, which `Art/character/hop-*.svg` uses.
    static let side: CGFloat = 512
    /// The reference space, in which all anatomy is authored.
    static let referenceSize = CGSize(width: 150, height: 160)
    /// `transform="translate(16 0) scale(3.2)"` from the generator's `wrap`.
    static let referenceScale: CGFloat = 3.2
    static let referenceOrigin = CGPoint(x: 16, y: 0)

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

/// The fixed numbers of Hop's body — the ones a pose never changes.
///
/// Transcribed from the constants and part functions at the top of
/// `Scripts/hop-art.js`. A pose sets where the hands and feet are; this sets
/// what a hand and a foot *are*.
enum HopAnatomy {
    static let eyeL = CGPoint(x: 42.4, y: 25.7)
    static let eyeR = CGPoint(x: 108.4, y: 25.7)
    /// The socket is the bump in the head silhouette, drawn in body green.
    static let socketRadius: CGFloat = 19.5
    static let whiteRadius: CGFloat = 15.5
    static let pupilRadius: CGFloat = 11.5
    static let highlightRadius: CGFloat = 3.4
    /// The pupil sits a unit below the socket centre; the catchlight above it.
    static let pupilOffset = CGSize(width: 0, height: 1)
    static let highlightOffset = CGSize(width: 3.2, height: -4)

    /// Shoulders are fixed: the pose moves the hand and the arm follows.
    static let shoulderL = CGPoint(x: 50, y: 90)
    static let shoulderR = CGPoint(x: 100, y: 90)
    static let armWidth: CGFloat = 13
    static let palmRadius: CGFloat = 8.4
    static let fingerLength: CGFloat = 11
    static let fingerWidth: CGFloat = 9
    /// Three fingers, fanned about the arm's own direction.
    static let fingerAngles: [Double] = [-50, 0, 50]

    static let legWidth: CGFloat = 16
    static let soleRadii = CGSize(width: 9.5, height: 7)
    /// Toe angle (relative to the foot's outward direction) and half-width.
    static let toes: [(angle: Double, radius: CGFloat)] = [
        (angle: -8, radius: 5.4), (angle: -46, radius: 5.4), (angle: -84, radius: 5),
    ]
    static let creaseAngles: [Double] = [-30, -70]

    /// The point the head rotates about, and the mouth scales about.
    static let faceCentre = CGPoint(x: 75, y: 50)
    /// The point the body leans about.
    static let hipCentre = CGPoint(x: 75, y: 100)
    /// Where a tongue leaves the mouth.
    static let tongueOrigin = HopPoseGeometry.tongueOrigin

    static let crownCentre = CGPoint(x: 75, y: 42)
    static let crownRadii = CGSize(width: 46, height: 31)
    static let jawCentre = CGPoint(x: 75, y: 54)
    static let jawRadii = CGSize(width: 65, height: 26)

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
    static let creaseStroke: CGFloat = 1.6
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
        var local = Path()
        local.addHopRoundedRect(
            CGRect(x: 0, y: -radius, width: length, height: radius * 2),
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

    /// The head's own `rotate(tilt 75 50)`, inside the body group.
    var headTransform: CGAffineTransform {
        CGAffineTransform(translationX: -HopAnatomy.faceCentre.x, y: -HopAnatomy.faceCentre.y)
            .concatenating(CGAffineTransform(rotationAngle: tilt * .pi / 180))
            .concatenating(CGAffineTransform(translationX: HopAnatomy.faceCentre.x, y: HopAnatomy.faceCentre.y))
            .concatenating(bodyTransform)
    }

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

    /// In `figure`'s draw order: shadow, pack, legs, torso, belly, arms, head,
    /// face, tongue, wiggle.
    enum Part {
        case shadow
        case pack
        case packStrap
        case legs
        case toeCreases
        case torso
        case belly
        case arms
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
        case .pack: pack(&path)
        case .packStrap: packStrap(&path)
        case .legs: legs(&path)
        case .toeCreases: toeCreases(&path)
        case .torso: torso(&path)
        case .belly: belly(&path)
        case .arms: arms(&path)
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
            centre: CGPoint(x: 75, y: 159 - geometry.lift * 0.1),
            radii: CGSize(width: max(0, 40 - geometry.lift * 0.4), height: 4)
        )
    }

    private func pack(_ path: inout Path) {
        path.addHopRoundedRect(CGRect(x: 98, y: 84, width: 22, height: 30), radius: 9)
    }

    private func packStrap(_ path: inout Path) {
        path.move(to: CGPoint(x: 92, y: 78))
        path.addQuadCurve(to: CGPoint(x: 108, y: 98), control: CGPoint(x: 104, y: 82))
    }

    /// A leg is the shin capsule, the sole, and three toes fanned outward and
    /// down. `side` −1 is Hop's right, the viewer's left.
    private func legs(_ path: inout Path) {
        for (leg, side) in [(geometry.legL, -1.0), (geometry.legR, 1.0)] as [(HopLegGeometry, Double)] {
            let foot = footCentre(for: leg, side: side)
            path.addHopCapsule(from: leg.hip, to: leg.ankle, radius: HopAnatomy.legWidth / 2)
            path.addHopEllipse(centre: foot, radii: HopAnatomy.soleRadii)
            for toe in HopAnatomy.toes {
                let angle = toeAngle(toe.angle, side: side) * .pi / 180
                path.addHopCapsule(
                    from: foot,
                    to: CGPoint(
                        x: foot.x + cos(angle) * 12 * leg.toeSpread,
                        y: foot.y + sin(angle) * 10
                    ),
                    radius: toe.radius
                )
            }
        }
    }

    /// The two creases between the toes. Stroked, and the only place in the
    /// drawing where a second green appears on the body.
    private func toeCreases(_ path: inout Path) {
        for (leg, side) in [(geometry.legL, -1.0), (geometry.legR, 1.0)] as [(HopLegGeometry, Double)] {
            let foot = footCentre(for: leg, side: side)
            for crease in HopAnatomy.creaseAngles {
                let angle = toeAngle(crease, side: side) * .pi / 180
                path.move(to: CGPoint(x: foot.x + cos(angle) * 5, y: foot.y + sin(angle) * 5))
                path.addLine(to: CGPoint(
                    x: foot.x + cos(angle) * 14 * leg.toeSpread,
                    y: foot.y + sin(angle) * 12
                ))
            }
        }
    }

    private func footCentre(for leg: HopLegGeometry, side: Double) -> CGPoint {
        CGPoint(x: leg.ankle.x - side * 2, y: leg.ankle.y + 3)
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
        let bottom = 130 - geometry.squash * 4
        let r = min(27, width / 2)
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
        let scale = geometry.bellyScale
        path.addHopEllipse(
            centre: CGPoint(x: 75, y: 104 + (scale - 1) * 4),
            radii: CGSize(width: 24 * scale, height: 23 * scale)
        )
    }

    /// An arm reaches from a fixed shoulder to the pose's hand point, and the
    /// three fingers fan about the direction it ended up pointing. The fingers
    /// are what make the hands read as hands.
    private func arms(_ path: inout Path) {
        for (shoulder, hand) in [
            (HopAnatomy.shoulderL, geometry.armL),
            (HopAnatomy.shoulderR, geometry.armR),
        ] {
            path.addHopCapsule(from: shoulder, to: hand, radius: HopAnatomy.armWidth / 2)
            path.addHopCircle(centre: hand, radius: HopAnatomy.palmRadius)
            let direction = atan2(hand.y - shoulder.y, hand.x - shoulder.x)
            for spread in HopAnatomy.fingerAngles {
                let angle = direction + spread * .pi / 180
                path.addHopCapsule(
                    from: hand,
                    to: CGPoint(
                        x: hand.x + cos(angle) * HopAnatomy.fingerLength,
                        y: hand.y + sin(angle) * HopAnatomy.fingerLength
                    ),
                    radius: HopAnatomy.fingerWidth / 2
                )
            }
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
