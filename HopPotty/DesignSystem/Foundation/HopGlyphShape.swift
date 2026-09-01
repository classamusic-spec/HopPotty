import SwiftUI

/// The drawn form of a ``HopGlyph`` that has no honest SF Symbol.
///
/// Every mark is authored in a 100 × 100 box and scaled to the frame, so the
/// same path serves a 13pt timeline dot and a 96pt empty-state illustration.
/// Paths are resolved to fills here (rings and folds become even-odd holes,
/// strokes become `strokedPath`) so one `fill(style:eoFill:)` renders them all.
public struct HopGlyphShape: Shape {
    public let glyph: HopGlyph

    public init(_ glyph: HopGlyph) {
        self.glyph = glyph
    }

    public func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let scale = side / 100
        let origin = CGPoint(
            x: rect.midX - side / 2,
            y: rect.midY - side / 2
        )
        var path = unitPath()
        path = path.applying(CGAffineTransform(scaleX: scale, y: scale))
        return path.applying(CGAffineTransform(translationX: origin.x, y: origin.y))
    }

    // MARK: - Authoring space

    private func unitPath() -> Path {
        switch glyph {
        case .tried: Self.triedPath
        case .pee: Self.dropPath(scale: 1, offset: .zero)
        case .poop: Self.poopPath
        case .accident: Self.accidentPath
        case .wash: Self.washPath
        case .flush: Self.flushPath
        case .wipe: Self.wipePath
        case .pond: Self.pondPath
        // Symbol-backed glyphs never reach the shape; a dot is a visible,
        // non-crashing marker if one ever does.
        default: Path(ellipseIn: CGRect(x: 34, y: 34, width: 32, height: 32))
        }
    }

    /// A potty seat from above: a ring with the lid hinge behind it.
    private static var triedPath: Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 12, y: 24, width: 76, height: 60))
        path.addEllipse(in: CGRect(x: 30, y: 40, width: 40, height: 28))
        path.addRoundedRect(
            in: CGRect(x: 36, y: 8, width: 28, height: 11),
            cornerSize: CGSize(width: 5, height: 5)
        )
        return path
    }

    /// A teardrop. The single most legible potty mark at 13pt.
    private static func dropPath(scale: CGFloat, offset: CGSize) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 50, y: 6))
        path.addCurve(to: CGPoint(x: 86, y: 62), control1: CGPoint(x: 64, y: 26), control2: CGPoint(x: 86, y: 44))
        path.addCurve(to: CGPoint(x: 50, y: 96), control1: CGPoint(x: 86, y: 81), control2: CGPoint(x: 70, y: 96))
        path.addCurve(to: CGPoint(x: 14, y: 62), control1: CGPoint(x: 30, y: 96), control2: CGPoint(x: 14, y: 81))
        path.addCurve(to: CGPoint(x: 50, y: 6), control1: CGPoint(x: 14, y: 44), control2: CGPoint(x: 36, y: 26))
        path.closeSubpath()
        guard scale != 1 || offset != .zero else { return path }
        // Scale about the box centre so a shrunk drop stays optically centred.
        let transform = CGAffineTransform(translationX: 50 + offset.width, y: 50 + offset.height)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -50, y: -50)
        return path.applying(transform)
    }

    /// Three stacked layers. Left just apart so even-odd filling reads them as
    /// distinct bands rather than merging them into a blob.
    private static var poopPath: Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 16, y: 66, width: 68, height: 28))
        path.addEllipse(in: CGRect(x: 26, y: 44, width: 48, height: 20))
        path.addEllipse(in: CGRect(x: 34, y: 25, width: 32, height: 17))
        path.addEllipse(in: CGRect(x: 44, y: 10, width: 12, height: 12))
        return path
    }

    /// A drop above a shallow puddle. Reads as a spill, not as a failure.
    private static var accidentPath: Path {
        var path = dropPath(scale: 0.62, offset: CGSize(width: 0, height: -16))
        path.addEllipse(in: CGRect(x: 14, y: 78, width: 72, height: 16))
        return path
    }

    /// Soap bubbles, deliberately non-overlapping.
    private static var washPath: Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 14, y: 44, width: 38, height: 38))
        path.addEllipse(in: CGRect(x: 58, y: 56, width: 26, height: 26))
        path.addEllipse(in: CGRect(x: 50, y: 20, width: 22, height: 22))
        return path
    }

    /// A spiral, stroked and then filled.
    private static var flushPath: Path {
        var path = Path()
        let centre = CGPoint(x: 50, y: 52)
        let turns = 1.85
        let steps = 120
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let angle = t * turns * 2 * .pi
            let radius = 8 + t * 34
            let point = CGPoint(
                x: centre.x + CGFloat(cos(angle) * radius),
                y: centre.y + CGFloat(sin(angle) * radius)
            )
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path.strokedPath(StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
    }

    /// A sheet with a folded corner. The fold is an even-odd hole.
    private static var wipePath: Path {
        var path = Path()
        path.move(to: CGPoint(x: 24, y: 14))
        path.addLine(to: CGPoint(x: 62, y: 14))
        path.addLine(to: CGPoint(x: 80, y: 32))
        path.addLine(to: CGPoint(x: 80, y: 88))
        path.addLine(to: CGPoint(x: 24, y: 88))
        path.closeSubpath()
        path.move(to: CGPoint(x: 62, y: 18))
        path.addLine(to: CGPoint(x: 76, y: 32))
        path.addLine(to: CGPoint(x: 62, y: 32))
        path.closeSubpath()
        return path
    }

    /// A lily pad: a disc with the classic wedge taken out.
    private static var pondPath: Path {
        var path = Path()
        let centre = CGPoint(x: 50, y: 52)
        let radius: CGFloat = 36
        path.move(to: centre)
        path.addArc(
            center: centre,
            radius: radius,
            startAngle: .degrees(24),
            endAngle: .degrees(336),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
