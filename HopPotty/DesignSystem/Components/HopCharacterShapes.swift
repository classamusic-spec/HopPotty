import SwiftUI

/// Hop's 512 × 512 authoring canvas.
///
/// Every path below is written in the same coordinates as
/// `Scripts/hop-art.js`, so a change to the art script can be transcribed here
/// literally. `fit(_:in:)` is the only scaling step, applied once at the edge.
enum HopCanvas {
    static let side: CGFloat = 512

    /// Scales an authored path to fill `rect`, preserving the square aspect.
    static func fit(_ path: Path, in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / side
        let dx = rect.midX - side * scale / 2
        let dy = rect.midY - side * scale / 2
        return path
            .applying(CGAffineTransform(scaleX: scale, y: scale))
            .applying(CGAffineTransform(translationX: dx, y: dy))
    }
}

/// The merged head-and-body egg.
///
/// Frogs have no neck, and giving Hop one would age him up out of his audience.
/// `squash` deforms the silhouette for jump (negative, stretched) and wait
/// (positive, settled) without moving the feet.
struct HopBodyShape: Shape {
    var squash: Double

    var animatableData: Double {
        get { squash }
        set { squash = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let s = squash
        var path = Path()
        path.move(to: CGPoint(x: 256, y: 186 + s * 14))
        path.addCurve(
            to: CGPoint(x: 400 + s * 16, y: 292 + s * 4),
            control1: CGPoint(x: 330 + s * 10, y: 186 + s * 14),
            control2: CGPoint(x: 392 + s * 14, y: 232 + s * 8)
        )
        path.addCurve(
            to: CGPoint(x: 340, y: 418),
            control1: CGPoint(x: 408 + s * 18, y: 350),
            control2: CGPoint(x: 396 + s * 12, y: 400)
        )
        path.addCurve(
            to: CGPoint(x: 172, y: 418),
            control1: CGPoint(x: 300, y: 430),
            control2: CGPoint(x: 212, y: 430)
        )
        path.addCurve(
            to: CGPoint(x: 112 - s * 16, y: 292 + s * 4),
            control1: CGPoint(x: 116 - s * 12, y: 400),
            control2: CGPoint(x: 104 - s * 18, y: 350)
        )
        path.addCurve(
            to: CGPoint(x: 256, y: 186 + s * 14),
            control1: CGPoint(x: 120 - s * 14, y: 232 + s * 8),
            control2: CGPoint(x: 182 - s * 10, y: 186 + s * 14)
        )
        path.closeSubpath()
        return HopCanvas.fit(path, in: rect)
    }
}

/// An arm: a tapered capsule with a rounded hand, pinned at the shoulder and
/// rotated by the pose.
struct HopArmShape: Shape {
    var origin: CGPoint
    /// Degrees clockwise from pointing right, matching the SVG `rotate()`.
    var angle: Double
    var length: Double
    var width: Double = 30
    /// Draws only the lighter knuckle highlight instead of the whole arm.
    var isHighlight: Bool = false

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get {
            AnimatablePair(
                AnimatablePair(Double(origin.x), Double(origin.y)),
                AnimatablePair(angle, length)
            )
        }
        set {
            origin = CGPoint(x: newValue.first.first, y: newValue.first.second)
            angle = newValue.second.first
            length = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let handRadius = width / 2 + 4

        if isHighlight {
            let r = width / 2 - 2
            path.addEllipse(in: CGRect(x: length - 4 - r, y: -4 - r, width: r * 2, height: r * 2))
        } else {
            path.addRoundedRect(
                in: CGRect(x: -width / 2, y: -width / 2, width: length + width / 2, height: width),
                cornerSize: CGSize(width: width / 2, height: width / 2)
            )
            path.addEllipse(
                in: CGRect(x: length - handRadius, y: -handRadius, width: handRadius * 2, height: handRadius * 2)
            )
        }

        let placed = path.applying(
            CGAffineTransform(translationX: origin.x, y: origin.y)
                .rotated(by: angle * .pi / 180)
        )
        return HopCanvas.fit(placed, in: rect)
    }
}

/// A frog foot: a rounded sole with three toe pads. Legible down to icon size,
/// which is why the toes are separate discs rather than a scalloped outline.
struct HopFootShape: Shape {
    var centre: CGPoint
    var flip: Double = 1
    /// `sole` and `toes` together, `highlight` alone, or the sole outline.
    var part: Part = .body

    enum Part { case body, highlight, outline }

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(Double(centre.x), Double(centre.y)) }
        set { centre = CGPoint(x: newValue.first, y: newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch part {
        case .body:
            path.addEllipse(in: CGRect(x: -44, y: 2 - 21, width: 88, height: 42))
            path.addEllipse(in: CGRect(x: -27 - 17, y: -11 - 17, width: 34, height: 34))
            path.addEllipse(in: CGRect(x: -17, y: -16 - 17, width: 34, height: 34))
            path.addEllipse(in: CGRect(x: 27 - 17, y: -11 - 17, width: 34, height: 34))
        case .highlight:
            path.addEllipse(in: CGRect(x: -29, y: 4 - 12, width: 58, height: 24))
        case .outline:
            path.addEllipse(in: CGRect(x: -44, y: 2 - 21, width: 88, height: 42))
        }

        let placed = path.applying(
            CGAffineTransform(translationX: centre.x, y: centre.y)
                .scaledBy(x: flip, y: 1)
        )
        return HopCanvas.fit(placed, in: rect)
    }
}

/// An open mouth. Kept small and soft — it reads as speech or delight, never as
/// a gape.
struct HopMouthShape: Shape {
    var open: Double
    /// The tongue, drawn in the cheek colour behind the lower lip.
    var isTongue: Bool = false

    var animatableData: Double {
        get { open }
        set { open = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if isTongue {
            path.move(to: CGPoint(x: 232, y: 322 + open * 20))
            path.addQuadCurve(
                to: CGPoint(x: 280, y: 322 + open * 20),
                control: CGPoint(x: 256, y: 336 + open * 24)
            )
            path.addQuadCurve(
                to: CGPoint(x: 232, y: 322 + open * 20),
                control: CGPoint(x: 256, y: 330 + open * 22)
            )
        } else {
            path.move(to: CGPoint(x: 202, y: 292))
            path.addQuadCurve(to: CGPoint(x: 310, y: 292), control: CGPoint(x: 256, y: 300 + open * 8))
            path.addQuadCurve(to: CGPoint(x: 256, y: 332 + open * 28), control: CGPoint(x: 300, y: 330 + open * 26))
            path.addQuadCurve(to: CGPoint(x: 202, y: 292), control: CGPoint(x: 212, y: 330 + open * 26))
        }
        path.closeSubpath()
        return HopCanvas.fit(path, in: rect)
    }
}

/// The closed smile, as a stroked curve.
struct HopSmileShape: Shape {
    var smile: Double

    var animatableData: Double {
        get { smile }
        set { smile = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 202, y: 294))
        path.addQuadCurve(to: CGPoint(x: 310, y: 294), control: CGPoint(x: 256, y: 294 + 44 * smile))
        return HopCanvas.fit(path, in: rect)
    }
}

/// The lash line that appears where the lid meets when Hop's eyes close.
struct HopEyeLashShape: Shape {
    var centre: CGPoint
    var radius: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: centre.x - radius * 0.66, y: centre.y + 2))
        path.addQuadCurve(
            to: CGPoint(x: centre.x + radius * 0.66, y: centre.y + 2),
            control: CGPoint(x: centre.x, y: centre.y + radius * 0.42)
        )
        return HopCanvas.fit(path, in: rect)
    }
}

/// The adventure bag Hop wears on the walk pose.
struct HopBagShape: Shape {
    enum Part { case body, flap, buckle, strap }
    var part: Part

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch part {
        case .body:
            path.addRoundedRect(
                in: CGRect(x: 374, y: 282, width: 66, height: 78),
                cornerSize: CGSize(width: 24, height: 24)
            )
        case .flap:
            path.move(to: CGPoint(x: 374, y: 304))
            path.addQuadCurve(to: CGPoint(x: 398, y: 282), control: CGPoint(x: 374, y: 282))
            path.addLine(to: CGPoint(x: 416, y: 282))
            path.addQuadCurve(to: CGPoint(x: 440, y: 304), control: CGPoint(x: 440, y: 282))
            path.addLine(to: CGPoint(x: 440, y: 312))
            path.addQuadCurve(to: CGPoint(x: 374, y: 312), control: CGPoint(x: 407, y: 323))
            path.closeSubpath()
        case .buckle:
            path.addRoundedRect(
                in: CGRect(x: 399, y: 306, width: 17, height: 13),
                cornerSize: CGSize(width: 5, height: 5)
            )
        case .strap:
            // Drawn in front of the body so the pack reads as worn, not carried.
            path.move(to: CGPoint(x: 352, y: 236))
            path.addQuadCurve(to: CGPoint(x: 390, y: 294), control: CGPoint(x: 382, y: 256))
        }
        return HopCanvas.fit(path, in: rect)
    }
}
