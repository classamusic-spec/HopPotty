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
/// The style is soft storybook, not comic book: no gradients and no sheen, and a
/// **subtle dark-green structural outline** rather than a black keyline. Three
/// levels of separation hold him together and none of them is allowed to carry
/// it alone — the exterior silhouette (``silhouette``), the internal overlap
/// rims (``part(_:_:)``), and the four-step green ramp in
/// ``HopCharacterPalette``. Hop was one flat green for everything before this,
/// and that single fact produced every complaint about him: arms disappearing
/// into the head, hands into the torso, two legs mid-jump reading as one.
///
/// The outline is **anatomical** — head, body, each arm, each hand, each leg,
/// each foot — and never per sub-path: outlining a cheek or an eye fragments him
/// into a sticker sheet. Its weight comes from ``HopOutlineStyle`` and is chosen
/// from what Hop has to survive (his size, his ground, the accessibility
/// appearance), not from the screen he is on.
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
/// anticipation, the recovery, the legal-transition table and the parts of the
/// body that arrive late (``HopSecondary``), and it publishes one absolute frame
/// at a time, which is what makes interrupting it safe.
///
/// This view renders whatever frame it is handed and adds the ambient life —
/// breath, weight shift, blink, micro-settle — through the modifiers in
/// `Motion/`, all of which stop under Reduce Motion without this file ever
/// asking whether Reduce Motion is on.
///
/// ## Three clocks on one drawing
///
/// Everything Hop is made of animates off one ``HopPoseGeometry``, so the layers
/// can never fall out of step with each other. But not everything that changes
/// it should be *timed* the same way, and the three sources are kept on separate
/// springs:
///
/// * the **beat** carries the pose, the expression and the secondary motion;
/// * the **gaze** has its own flat spring, and the head has a slower one that
///   starts after the eyes. Before this they inherited whichever beat had run
///   last, which meant a look could arrive on the landing settle's bounce;
/// * the **ambient** layer brings its own animation with each change it makes.
///
/// When a beat and a look land in the same update the beat wins, which is what
/// the modifier order at the bottom of ``characterLayer`` is for.
public struct HopCharacterView: View {
    @Environment(\.hopTheme) private var theme
    @State private var performer = HopPerformer()
    @State private var ambientBlink: Double = 0
    @State private var ambientSettle: CGSize = .zero
    /// Where the *head* is pointed. It trails ``gaze`` by
    /// ``HopGaze/headFollowDelay``, which is the whole of the effect.
    @State private var headGaze: HopGaze = .forward

    private let act: HopAct
    private let size: CGFloat
    private let ambient: Bool
    private let castsShadow: Bool
    private let gaze: HopGaze
    private let ground: HopGround

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
        gaze: HopGaze = .forward,
        ground: HopGround = .surface
    ) {
        self.init(
            act: jump.map { HopAct(pose: pose, beat: .hop($0)) } ?? HopAct(pose: pose),
            size: size,
            ambient: ambient,
            castsShadow: castsShadow,
            gaze: gaze,
            ground: ground
        )
    }

    /// Hop performing an act — waving, delighting, speaking, hopping, arriving
    /// or leaving. Changing the act at any moment is safe, including mid-beat.
    public init(
        act: HopAct,
        size: CGFloat,
        ambient: Bool = true,
        castsShadow: Bool = true,
        gaze: HopGaze = .forward,
        ground: HopGround = .surface
    ) {
        self.act = act
        self.size = size
        self.ambient = ambient
        self.castsShadow = castsShadow
        self.gaze = gaze
        self.ground = ground
    }

    // MARK: - What is being drawn right now

    /// The performer's frame, with every travelling quantity zeroed if Reduce
    /// Motion is on. Resolved here rather than when the beat was scheduled, so
    /// switching the setting on mid-hop grounds Hop on the very next frame.
    private var frame: HopFrame { performer.frame.resolved(reduceMotion: theme.reduceMotion) }

    /// The frame's own expression, plus where the caller has pointed Hop, plus
    /// the ambient micro-settle. Three sources, one value, so the eyes cannot
    /// end up fighting over who owns them.
    ///
    /// The eyes read ``gaze`` and the head reads ``headGaze``, which is the same
    /// value a fraction of a second later. Splitting them is what turns "the
    /// drawing is pointed at the button" into "he looked at the button".
    private var expression: HopExpression {
        var combined = frame.expression
        let look = gaze.expression
        combined.gaze.width += look.gaze.width + ambientSettle.width
        combined.gaze.height += look.gaze.height + ambientSettle.height
        combined.tilt += headGaze.expression.tilt
        return combined
    }

    /// The pose's parameters with the expression, the trailing parts of the body
    /// and the ambient blink folded in. Everything the drawing reads comes from
    /// here, so a single value drives every layer and they cannot fall out of
    /// step mid-transition.
    private var geometry: HopPoseGeometry {
        var resolved = frame.pose.geometry
        resolved.apply(expression)
        resolved.apply(frame.secondary)
        // A pose that already has the eyes shut cannot be blinked further
        // closed, and an idle blink shuts on the *resting* line — the upward
        // arc is what eyes do when they close because Hop is pleased, which a
        // blink every four seconds is not.
        resolved.close(eyesBy: ambientBlink, toward: .rest)
        return resolved
    }

    /// The spring carrying Hop into the current frame, already degraded if
    /// Reduce Motion is on.
    private var beatAnimation: Animation {
        performer.frame.spring.animation(reduceMotion: theme.reduceMotion)
    }

    /// The eyes' and the head's own springs, degraded through the same gate.
    private var eyeAnimation: Animation {
        HopGaze.eyeSpring.animation(reduceMotion: theme.reduceMotion)
    }

    private var headAnimation: Animation {
        HopGaze.headSpring.animation(reduceMotion: theme.reduceMotion)
    }

    /// What the *drawing* animates on. Deliberately excludes the gaze, the
    /// ambient blink and the micro-settle: each of those carries its own
    /// animation, and folding them in here would re-time them to whatever beat
    /// happened to be running.
    private var drawKey: HopDrawKey {
        HopDrawKey(pose: frame.pose, expression: frame.expression, secondary: frame.secondary)
    }

    /// Hop's opacity.
    ///
    /// An act that opens off-stage has him invisible on its very first frame —
    /// but the performer cannot publish that frame until its task runs, one
    /// render after the view appears. For that single render the view holds him
    /// back itself, rather than showing him standing on his mark and then
    /// sliding him off the side of the screen.
    private var stageOpacity: Double {
        guard !performer.hasStarted, act.beat.opensOffStage else { return frame.opacity }
        return 0
    }

    private var performanceKey: HopPerformanceKey {
        HopPerformanceKey(act: act, reduceMotion: theme.reduceMotion)
    }

    /// Points per reference unit — the conversion every stroke width needs.
    private var unit: CGFloat { HopCanvas.unit(for: size) }

    /// How strongly Hop is separated from his background and from himself.
    ///
    /// Resolved from three semantic facts and nothing else — how big he is, what
    /// kind of ground he is on, and whether the OS has asked for more contrast.
    /// No screen passes a stroke width, which is the whole point of §18: a state
    /// that means something, not a per-screen override that means whatever the
    /// last person to look at that screen thought.
    private var outline: HopOutlineStyle {
        HopOutlineStyle.resolved(
            forSize: size,
            onScenery: ground == .scenery,
            highContrast: theme.appearance.isHighContrast
        )
    }

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
        // The head starts after the eyes. Cancelled and restarted by a new
        // target, so a gaze that changes twice quickly turns the head once.
        .task(id: gaze) {
            try? await Task.sleep(for: .seconds(HopGaze.headFollowDelay))
            guard !Task.isCancelled else { return }
            headGaze = gaze
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
            // by the beat that caused it — and so that when a beat and a look
            // land in the same update, the beat wins. The gaze springs sit
            // outside it and take over only when nothing else moved.
            .animation(beatAnimation, value: drawKey)
            .animation(eyeAnimation, value: gaze)
            .animation(headAnimation, value: headGaze)
            .rotationEffect(.degrees(frame.lean), anchor: HopCanvas.groundAnchor)
            .scaleEffect(x: frame.horizontalScale, y: frame.squash, anchor: HopCanvas.groundAnchor)
            .offset(x: frame.drift * strideUnit, y: -frame.elevation * riseUnit)
            .opacity(stageOpacity)
            .animation(beatAnimation, value: frame)
    }

    // MARK: - Layers, in the order `figure()` stacks them
    //
    // shadow, silhouette, pack, legs, torso, belly, arms, head, face, tongue,
    // wiggle, zzz.
    //
    // The order is not stacking, it is depth, and depth is what the separation
    // system runs on. Every part is drawn as a *rim then a fill*, so a part's
    // rim lands exactly where it crosses something already drawn and nowhere
    // else: the torso's rim over the legs, an arm's rim over the torso, the
    // head's rim over the arms. The three failures this replaced — arms into the
    // head, hands into the torso, legs into each other — are all boundaries that
    // did not exist, and this is where they exist now.

    private var character: some View {
        ZStack {
            silhouette
            pack
            legs
            part(.torso, HopCharacterPalette.body)
            fill(.belly, HopCharacterPalette.belly)
            arms
            part(.head, HopCharacterPalette.body)
            face
            wiggleMarks
            sleepMarks
        }
        .frame(width: size, height: size)
    }

    /// The exterior edge: every body shape at once, stroked and filled in the
    /// same opaque `hop-outline`, underneath everything.
    ///
    /// One flat colour is what makes it work — the union has no interior seams
    /// to show, so all that survives is the outside of Hop. This is the layer
    /// that keeps him legible on pond blue, on vegetation green and on a night
    /// sky, where his own hue is the background.
    private var silhouette: some View {
        ZStack {
            shape(.silhouette)
                .stroke(
                    HopCharacterPalette.outline,
                    style: StrokeStyle(lineWidth: 2 * outline.exterior * unit, lineCap: .round, lineJoin: .round)
                )
            shape(.silhouette).fill(HopCharacterPalette.outline)
        }
        .frame(width: size, height: size)
        .opacity(outline.exterior > 0 ? 1 : 0)
    }

    /// One whole leg, then the other — shin, then that foot, then that foot's
    /// two darker creases — because that is the order `figure()` draws them in,
    /// and it is the order that keeps a crease under the far foot when a pose
    /// brings the feet together.
    ///
    /// The legs are the deepest green in the character and the feet come back up
    /// a step, which is the tonal half of "the legs did not merge with the body,
    /// or with each other, mid-jump".
    private var legs: some View {
        ZStack {
            part(.shinLeft, HopCharacterPalette.leg)
            part(.footLeft, HopCharacterPalette.foot)
            stroke(.toeCreasesLeft, HopCharacterPalette.bodyDeep.opacity(0.8), width: HopAnatomy.creaseStroke)
            part(.shinRight, HopCharacterPalette.leg)
            part(.footRight, HopCharacterPalette.foot)
            stroke(.toeCreasesRight, HopCharacterPalette.bodyDeep.opacity(0.8), width: HopAnatomy.creaseStroke)
        }
    }

    /// One whole arm, then the other, each with its hand drawn after it so the
    /// hand has a boundary against its own forearm and against the other hand.
    ///
    /// The green comes from ``HopPoseGeometry/armsForward``, which travels in the
    /// animation vector: an arm that moves in front of the tummy brightens as it
    /// arrives rather than switching colour under itself.
    private var arms: some View {
        let tone = HopCharacterPalette.arm(forward: geometry.armsForward)
        return ZStack {
            part(.armLeft, tone)
            part(.handLeft, tone)
            part(.armRight, tone)
            part(.handRight, tone)
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
            part(.pack, HopCharacterPalette.bagBody)
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

    /// The ground shadow does not *rise* with Hop, but it does follow him.
    ///
    /// It is drawn outside the beat transforms on purpose: a shadow that goes up
    /// with the character is a sticker with a smudge under it. So it keeps the
    /// ground line and only shrinks and fades as he leaves it, which is most of
    /// what sells a jump.
    ///
    /// The sideways drift is a different matter and it does apply, because a
    /// shadow is cast by a body that is *there*. Without it a drifting hop
    /// leaves its shadow behind, and an entrance — which crosses the whole stage
    /// — puts a shadow on the mark for the entire time Hop is still off it.
    private var shadowLayer: some View {
        fill(.shadow, HopCharacterPalette.groundShadow)
            .opacity(shadowOpacity)
            .scaleEffect(1 - 0.42 * frame.elevation, anchor: HopCanvas.groundAnchor)
            .offset(x: frame.drift * strideUnit)
            .animation(beatAnimation, value: frame)
    }

    private var shadowOpacity: Double {
        let base = max(0, 0.12 - geometry.lift * 0.002)
        return base * (1 - 0.55 * Double(frame.elevation)) * stageOpacity
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

    /// One anatomical part: its own rim, then its fill.
    ///
    /// The rim is a stroke centred on the part's edge, so the fill drawn over it
    /// covers the inner half and leaves exactly ``HopOutlineStyle/inner`` units
    /// showing on the outside — the same construction the generator uses, where
    /// a shape is grown by stroking it at twice the amount it should grow by.
    /// Being underneath is what makes it *internal* separation: on Hop's outside
    /// edge it disappears into the darker silhouette and costs nothing, and it
    /// only becomes visible where this part crosses something already drawn.
    private func part(_ part: HopFigureShape.Part, _ color: Color) -> some View {
        ZStack {
            shape(part)
                .stroke(
                    HopCharacterPalette.outline.opacity(outline.innerOpacity),
                    style: StrokeStyle(lineWidth: 2 * outline.inner * unit, lineCap: .round, lineJoin: .round)
                )
            shape(part).fill(color)
        }
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

/// What a pose change animates on: the authored drawing, the deliberate
/// adjustments to it, and the parts of the body still catching up with it.
/// Nothing the ambient layer or the caller's gaze drives is in here — those have
/// their own springs, and folding them in would re-time them to the beat.
private struct HopDrawKey: Equatable {
    let pose: HopPose
    let expression: HopExpression
    let secondary: HopSecondary
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
