import SwiftUI
import HopPottyDesignTokens

/// Hop, drawn and performed.
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
/// ## Two layers, and why they are separate
///
/// **The drawing** is ``HopPose`` plus ``HopExpression``: which of the fourteen
/// authored poses, and the small adjustments — gaze, a happy squint, a mouth
/// mid-word — that no pose can carry because the poses have to stay one-to-one
/// with the generator.
///
/// **The performance** is ``HopPerformer``: a state machine that turns a
/// ``HopAct`` into a sequence of complete ``HopFrame``s. It owns the beats, the
/// anticipation, the recovery and the legal-transition table, and it publishes
/// one absolute frame at a time, which is what makes interrupting it safe.
///
/// This view renders whatever frame it is handed and adds the ambient life —
/// breath, weight shift, blink, micro-settle — through the modifiers in
/// `Motion/`, all of which stop under Reduce Motion without this file ever
/// asking whether Reduce Motion is on.
public struct HopCharacterView: View {
    @Environment(\.hopTheme) private var theme
    @State private var performer = HopPerformer()
    @State private var ambientBlink: Double = 0
    @State private var ambientSettle: CGSize = .zero

    private let act: HopAct
    private let size: CGFloat
    private let ambient: Bool
    private let castsShadow: Bool
    private let gaze: HopGaze

    /// Hop holding a pose, optionally hopping.
    ///
    /// The original three-argument form still means exactly what it did; `jumping`
    /// and `gaze` are additions with defaults. Passing a `HopJump` plays a hop
    /// and comes back to `pose`; passing `nil` cancels one in flight and lands
    /// him cleanly.
    public init(
        pose: HopPose,
        size: CGFloat,
        ambient: Bool = true,
        castsShadow: Bool = true,
        jumping jump: HopJump? = nil,
        gaze: HopGaze = .forward
    ) {
        self.init(
            act: jump.map { HopAct(pose: pose, beat: .hop($0)) } ?? HopAct(pose: pose),
            size: size,
            ambient: ambient,
            castsShadow: castsShadow,
            gaze: gaze
        )
    }

    /// Hop performing an act — waving, delighting, speaking, hopping, arriving
    /// or leaving. Changing the act at any moment is safe, including mid-beat.
    public init(
        act: HopAct,
        size: CGFloat,
        ambient: Bool = true,
        castsShadow: Bool = true,
        gaze: HopGaze = .forward
    ) {
        self.act = act
        self.size = size
        self.ambient = ambient
        self.castsShadow = castsShadow
        self.gaze = gaze
    }

    // MARK: - What is being drawn right now

    /// The performer's frame, with every travelling quantity zeroed if Reduce
    /// Motion is on. Resolved here rather than when the beat was scheduled, so
    /// switching the setting on mid-hop grounds Hop on the very next frame.
    private var frame: HopFrame { performer.frame.resolved(reduceMotion: theme.reduceMotion) }

    /// The frame's own expression, plus where the caller has pointed Hop, plus
    /// the ambient micro-settle. Three sources, one value, so the eyes cannot
    /// end up fighting over who owns them.
    private var expression: HopExpression {
        var combined = frame.expression
        let look = gaze.expression
        combined.gaze.width += look.gaze.width + ambientSettle.width
        combined.gaze.height += look.gaze.height + ambientSettle.height
        combined.tilt += look.tilt
        return combined
    }

    /// The pose's parameters with the expression and the ambient blink folded
    /// in. Everything the drawing reads comes from here, so a single value
    /// drives every layer and they cannot fall out of step mid-transition.
    private var geometry: HopPoseGeometry {
        var resolved = frame.pose.geometry
        resolved.apply(expression)
        // A pose that already has the eyes shut cannot be blinked further closed.
        resolved.close(eyesBy: ambientBlink)
        return resolved
    }

    /// The spring carrying Hop into the current frame, already degraded if
    /// Reduce Motion is on.
    private var beatAnimation: Animation {
        performer.frame.spring.animation(reduceMotion: theme.reduceMotion)
    }

    /// What the *drawing* animates on. Deliberately excludes the ambient blink
    /// and micro-settle: those carry their own animations, and folding them in
    /// here would re-time them to whatever beat happened to be running.
    private var drawKey: HopDrawKey {
        HopDrawKey(pose: frame.pose, expression: frame.expression, gaze: gaze)
    }

    private var performanceKey: HopPerformanceKey {
        HopPerformanceKey(act: act, reduceMotion: theme.reduceMotion)
    }

    /// Points per reference unit — the conversion every stroke width needs.
    private var unit: CGFloat { HopCanvas.unit(for: size) }

    /// How far a full-height hop lifts Hop, in points.
    private var riseUnit: CGFloat { HopJump.headroom(for: size) }
    /// One unit of sideways drift — Hop's own height — in points.
    private var strideUnit: CGFloat { size * HopCanvas.figureHeightRatio }

    // MARK: - Ambient life

    /// Ambient motion stands down while a beat is moving Hop's body: a breath
    /// swelling against a landing squash is two animations arguing.
    private var breathes: Bool { ambient && !performer.suspendsAmbient }
    private var blinks: Bool { breathes && frame.pose.blinks }

    public var body: some View {
        ZStack {
            Color.clear
            if castsShadow && geometry.showsShadow { shadowLayer }
            characterLayer
        }
        .frame(width: size, height: size)
        .hopBlinking(blinks, phase: $ambientBlink)
        .hopMicroSettle(breathes, offset: $ambientSettle)
        // One task, keyed on the act. A new act cancels the old one, and the
        // performer's generation guard stops the cancelled run from writing a
        // frame over the live one.
        .task(id: performanceKey) {
            await performer.perform(act, reduceMotion: theme.reduceMotion)
        }
        // The drawing is decorative; ``HopCharacterStage`` carries the label,
        // because the label depends on what Hop is *for* on this screen. No
        // performance changes it: a mascot that hops must never take VoiceOver
        // focus or announce anything new.
        .accessibilityHidden(true)
    }

    /// Hop himself, with the ambient life on the inside of the beat transforms
    /// and the beat transforms anchored at his feet.
    ///
    /// Order matters. The squash is applied about ``HopCanvas/groundAnchor``
    /// rather than the view's centre, which is the difference between a
    /// character flattening *onto the floor* and one being squeezed in mid-air.
    private var characterLayer: some View {
        character
            .hopBreathing(
                breathes,
                period: frame.pose.breathPeriod,
                amplitude: frame.pose.breathAmplitude,
                anchor: HopCanvas.groundAnchor
            )
            .hopWeightShift(breathes, anchor: HopCanvas.groundAnchor)
            // The drawing's own animation, innermost, so a pose change is timed
            // by the beat that caused it.
            .animation(beatAnimation, value: drawKey)
            .rotationEffect(.degrees(frame.lean), anchor: HopCanvas.groundAnchor)
            .scaleEffect(x: frame.horizontalScale, y: frame.squash, anchor: HopCanvas.groundAnchor)
            .offset(x: frame.drift * strideUnit, y: -frame.elevation * riseUnit)
            .opacity(frame.opacity)
            .animation(beatAnimation, value: frame)
    }

    // MARK: - Layers, in the order `figure()` stacks them
    //
    // shadow, pack, legs, torso, belly, arms, head, face, tongue, wiggle, zzz.
    // The order is what makes limbs read as attached rather than stacked: the
    // belly sits over the torso, the arms over the belly, the head over both.

    private var character: some View {
        ZStack {
            pack
            legs
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

    /// One whole leg, then the other — shin, sole and toes in body green, then
    /// that foot's two darker creases — because that is the order `figure()`
    /// draws them in, and it is the order that keeps a crease under the far
    /// foot when a pose brings the feet together.
    private var legs: some View {
        ZStack {
            fill(.legLeft, HopCharacterPalette.body)
            stroke(.toeCreasesLeft, HopCharacterPalette.bodyDeep.opacity(0.8), width: HopAnatomy.creaseStroke)
            fill(.legRight, HopCharacterPalette.body)
            stroke(.toeCreasesRight, HopCharacterPalette.bodyDeep.opacity(0.8), width: HopAnatomy.creaseStroke)
        }
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

    /// The ground shadow does not travel with Hop.
    ///
    /// It is drawn outside the beat transforms on purpose: a shadow that rises
    /// with the character is a sticker with a smudge under it. Instead it stays
    /// on the ground line and shrinks and fades as he leaves it, which is most
    /// of what sells a jump.
    private var shadowLayer: some View {
        fill(.shadow, HopCharacterPalette.groundShadow)
            .opacity(shadowOpacity)
            .scaleEffect(1 - 0.42 * frame.elevation, anchor: HopCanvas.groundAnchor)
            .animation(beatAnimation, value: frame)
    }

    private var shadowOpacity: Double {
        let base = max(0, 0.12 - geometry.lift * 0.002)
        return base * (1 - 0.55 * Double(frame.elevation)) * frame.opacity
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

/// What a pose change animates on: the authored drawing and the deliberate
/// adjustments to it, and nothing that the ambient layer drives.
private struct HopDrawKey: Equatable {
    let pose: HopPose
    let expression: HopExpression
    let gaze: HopGaze
}

/// What restarts the performer. Reduce Motion is part of it because the whole
/// script is different when it is on — not merely faster.
private struct HopPerformanceKey: Equatable {
    let act: HopAct
    let reduceMotion: Bool
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
