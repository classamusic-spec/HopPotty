import SwiftUI
import HopPottyDesignTokens

/// Hop, drawn.
///
/// Vector paths rather than a raster asset, for three reasons that all matter:
/// the poses interpolate (Hop moves between them instead of cutting), one
/// drawing serves a 28pt dashboard chip and a 320pt celebration without a
/// separate export, and the geometry stays in step with `Scripts/hop-art.js`,
/// which generates the same character for the app icon and the marketing art.
///
/// The style is the reference's: **flat**. No gradients, no outlines, no sheen.
/// Depth is value steps in the green ramp alone — the body green, one step down
/// for spots and toe creases, and the ink green for the three lines (nostrils,
/// shut eyes, closed mouth). Anything softer than that stops reading at 28pt,
/// which is the size Hop appears at most often.
///
/// Ambient motion — the breath and the blink — is owned here and routed through
/// the modifiers in `Motion/`, so it stops under Reduce Motion without this file
/// ever asking whether Reduce Motion is on.
public struct HopCharacterView: View {
    @Environment(\.hopTheme) private var theme
    @State private var ambientBlink: Double = 0

    private let pose: HopPose
    private let size: CGFloat
    private let ambient: Bool
    private let castsShadow: Bool

    public init(pose: HopPose, size: CGFloat, ambient: Bool = true, castsShadow: Bool = true) {
        self.pose = pose
        self.size = size
        self.ambient = ambient
        self.castsShadow = castsShadow
    }

    /// The pose's parameters with the ambient blink folded in. Everything the
    /// drawing reads comes from here, so a single value drives every layer and
    /// they cannot fall out of step mid-transition.
    private var geometry: HopPoseGeometry {
        var resolved = pose.geometry
        // A pose that already has the eyes shut cannot be blinked further closed.
        resolved.eyes.blink = min(1, resolved.eyes.blink + ambientBlink * (1 - resolved.eyes.blink))
        return resolved
    }

    /// Points per reference unit — the conversion every stroke width needs.
    private var unit: CGFloat { HopCanvas.unit(for: size) }

    public var body: some View {
        ZStack {
            Color.clear
            if castsShadow && geometry.showsShadow { groundShadow }
            character
                .hopBreathing(ambient)
        }
        .frame(width: size, height: size)
        .hopBlinking(ambient, phase: $ambientBlink)
        .hopAnimation(pose.arrivalMotion, value: pose)
        .accessibilityHidden(true)
    }

    // MARK: - Layers, in the order `figure()` stacks them
    //
    // shadow, pack, legs, torso, belly, arms, head, face, tongue, wiggle, zzz.
    // The order is what makes limbs read as attached rather than stacked: the
    // belly sits over the torso, the arms over the belly, the head over both.

    private var character: some View {
        ZStack {
            pack
            fill(.legs, HopCharacterPalette.body)
            stroke(.toeCreases, HopCharacterPalette.bodyDeep.opacity(0.8), width: HopAnatomy.creaseStroke)
            fill(.torso, HopCharacterPalette.body)
            fill(.belly, HopCharacterPalette.belly)
            fill(.arms, HopCharacterPalette.body)
            fill(.head, HopCharacterPalette.body)
            face
            wiggleMarks
            sleepMarks
        }
        .frame(width: size, height: size)
    }

    private var face: some View {
        ZStack {
            fill(.spots, HopCharacterPalette.bodyDeep)
            eyes
            fill(.cheeks, HopCharacterPalette.cheek)
            fill(.nostrils, HopCharacterPalette.ink)
            mouth
            // Drawn after the face so the tongue leaves the open mouth rather
            // than sitting under it.
            fill(.tongue, HopCharacterPalette.tongue)
                .opacity(min(1, geometry.tongueExtension * 4))
        }
    }

    /// The white, then everything inside it clipped to it, then the line a shut
    /// eye leaves. The clip is what keeps a lowered lid inside the eye —
    /// unclipped it read as a pair of ears above the head.
    private var eyes: some View {
        ZStack {
            fill(.eyeWhites, HopCharacterPalette.eyeWhite)
            ZStack {
                fill(.pupils, HopCharacterPalette.pupil)
                fill(.highlights, HopCharacterPalette.highlight)
                fill(.lids, HopCharacterPalette.body)
            }
            .frame(width: size, height: size)
            .clipShape(shape(.eyeWhites))
            // The line arrives as the lid closes rather than snapping in at the
            // end, which is what makes a slow blink read as a slow blink.
            stroke(.closedEyes, HopCharacterPalette.ink, width: HopAnatomy.closedEyeStroke)
                .opacity(min(1, geometry.eyes.blink * 1.6))
        }
    }

    /// The open mouth and the smile line cross-fade rather than swap, so a pose
    /// change that opens Hop's mouth is one continuous movement. The open mouth
    /// also scales about the face centre, so it shrinks into the face as it goes.
    private var mouth: some View {
        ZStack {
            ZStack {
                fill(.mouthInterior, HopCharacterPalette.mouthInterior)
                fill(.mouthTongue, HopCharacterPalette.tongue)
                    .frame(width: size, height: size)
                    .clipShape(shape(.mouthInterior))
            }
            .opacity(openMouthOpacity)

            stroke(.smile, HopCharacterPalette.ink, width: HopAnatomy.smileStroke)
                .opacity(1 - openMouthOpacity)
        }
    }

    private var openMouthOpacity: Double {
        min(1, geometry.mouthOpenScale * 3)
    }

    private var pack: some View {
        ZStack {
            fill(.pack, HopCharacterPalette.bagBody)
            stroke(.packStrap, HopCharacterPalette.bagStrap, width: HopAnatomy.strapStroke)
        }
        .opacity(geometry.withPack ? 1 : 0)
    }

    private var wiggleMarks: some View {
        stroke(.wiggle, HopCharacterPalette.bodyDeep, width: HopAnatomy.wiggleStroke)
            .opacity(geometry.wiggling ? 0.6 : 0)
    }

    /// The two `z`s. Type rather than paths, because they are lettering — and
    /// because at 28pt they are two dots either way.
    private var sleepMarks: some View {
        ZStack {
            sleepMark("z", size: 9, baseline: CGPoint(x: 122, y: 14))
            sleepMark("z", size: 12, baseline: CGPoint(x: 131, y: 6))
        }
        .opacity(geometry.sleeping ? 0.7 : 0)
        .frame(width: size, height: size)
    }

    private func sleepMark(_ text: String, size fontSize: CGFloat, baseline: CGPoint) -> some View {
        // `position` centres, the SVG places a baseline: nudge up by roughly a
        // third of the em and right by a quarter, which lands a lowercase `z`
        // where the generator draws it.
        let centre = CGPoint(x: baseline.x + fontSize * 0.25, y: baseline.y - fontSize * 0.34)
        let placed = centre.applying(geometry.bodyTransform)
        return Text(text)
            .font(.system(size: fontSize * unit, weight: .heavy, design: .rounded))
            .foregroundStyle(HopCharacterPalette.ink)
            .position(HopCanvas.viewPoint(placed, forSize: size))
    }

    /// The ground shadow shrinks and fades as Hop leaves the ground, which is
    /// most of what sells a jump.
    private var groundShadow: some View {
        fill(.shadow, HopCharacterPalette.groundShadow)
            .opacity(max(0, 0.12 - geometry.lift * 0.002))
    }

    // MARK: - Layer plumbing

    private func shape(_ part: HopFigureShape.Part) -> HopFigureShape {
        HopFigureShape(geometry: geometry, part: part)
    }

    private func fill(_ part: HopFigureShape.Part, _ color: Color) -> some View {
        shape(part)
            .fill(color)
            .frame(width: size, height: size)
    }

    /// Stroke widths are authored in reference units, like everything else, and
    /// converted here — a stroke does not scale with the path it is applied to.
    private func stroke(_ part: HopFigureShape.Part, _ color: Color, width: CGFloat) -> some View {
        shape(part)
            .stroke(color, style: StrokeStyle(lineWidth: width * unit, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

extension HopCanvas {
    /// A point authored in reference space, in the coordinates of a
    /// `size` × `size` view — for the few pieces that are not paths.
    static func viewPoint(_ point: CGPoint, forSize size: CGFloat) -> CGPoint {
        let scale = size / side
        let onCanvas = point.applying(referenceTransform)
        return CGPoint(x: onCanvas.x * scale, y: onCanvas.y * scale)
    }
}
