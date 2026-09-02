import SwiftUI
import HopPottyDesignTokens

/// Hop, placed on a surface and described to assistive technology.
///
/// The drawing itself is decorative — ``HopCharacterView`` hides it — and the
/// stage is what carries the label, because the label depends on what Hop is
/// doing here, not on how he is drawn.
///
/// **The label follows the act's resting pose, never the beat.** Hop hopping,
/// waving or speaking is the same element saying the same thing: a mascot that
/// re-announced itself every time it moved would take VoiceOver focus away from
/// the thing the child is actually being asked to do.
public struct HopCharacterStage: View {
    private let act: HopAct
    private let size: CGFloat
    private let ambient: Bool
    private let gaze: HopGaze
    private let accessibilityLabel: String?

    /// Hop holding a pose, optionally hopping and optionally looking somewhere.
    public init(
        pose: HopPose,
        size: CGFloat,
        ambient: Bool = true,
        jumping jump: HopJump? = nil,
        gaze: HopGaze = .forward
    ) {
        self.act = jump.map { HopAct(pose: pose, beat: .hop($0)) } ?? HopAct(pose: pose)
        self.size = size
        self.ambient = ambient
        self.gaze = gaze
        self.accessibilityLabel = nil
    }

    /// Overrides the spoken description, for the cases where the surrounding
    /// screen has already said what Hop is doing and repeating it is noise.
    /// Pass an empty string to make the illustration purely decorative.
    ///
    /// A distinct argument label, not a defaulted parameter, so this never
    /// competes with the primary initialiser at a two-argument call site.
    public init(
        pose: HopPose,
        size: CGFloat,
        ambient: Bool = true,
        jumping jump: HopJump? = nil,
        gaze: HopGaze = .forward,
        describedAs description: String
    ) {
        self.act = jump.map { HopAct(pose: pose, beat: .hop($0)) } ?? HopAct(pose: pose)
        self.size = size
        self.ambient = ambient
        self.gaze = gaze
        self.accessibilityLabel = description
    }

    /// Hop performing an act — greeting, delighting, speaking, celebrating,
    /// arriving, leaving. One line at a call site; safe to change at any moment.
    public init(
        act: HopAct,
        size: CGFloat,
        ambient: Bool = true,
        gaze: HopGaze = .forward
    ) {
        self.act = act
        self.size = size
        self.ambient = ambient
        self.gaze = gaze
        self.accessibilityLabel = nil
    }

    /// An act, with the spoken description overridden. Empty makes it decorative.
    public init(
        act: HopAct,
        size: CGFloat,
        ambient: Bool = true,
        gaze: HopGaze = .forward,
        describedAs description: String
    ) {
        self.act = act
        self.size = size
        self.ambient = ambient
        self.gaze = gaze
        self.accessibilityLabel = description
    }

    public var body: some View {
        HopCharacterView(act: act, size: size, ambient: ambient, gaze: gaze)
            .frame(width: size, height: size)
            .modifier(HopStageLabel(label: accessibilityLabel ?? act.pose.accessibilityDescription))
    }
}

/// Applies the label, or removes the element entirely when the caller has said
/// the illustration is decorative here.
private struct HopStageLabel: ViewModifier {
    let label: String

    func body(content: Content) -> some View {
        if label.isEmpty {
            content.accessibilityHidden(true)
        } else {
            content
                .accessibilityElement()
                .accessibilityLabel(label)
                .accessibilityAddTraits(.isImage)
        }
    }
}

/// A small, circular Hop for a row or a toolbar. Always `idle`, never ambient:
/// a chip that breathes in a settings list is a distraction.
///
/// This is the app's use of the generator's `face` entry. Rather than a second
/// drawing, it is `idle` scaled and shifted so that
/// ``HopPoseGeometry/faceCrop`` — the rectangle Hop's head occupies — fills the
/// circle. One drawing, one set of numbers, and a head that cannot drift out of
/// step with the body it belongs to.
public struct HopChip: View {
    private let diameter: CGFloat

    public init(diameter: CGFloat = 32) {
        self.diameter = diameter
    }

    /// How big the whole 512 canvas has to be for the head to fill the circle,
    /// with a tenth of the head's width left as breathing room.
    private var renderSize: CGFloat {
        diameter * HopCanvas.side / (HopPoseGeometry.faceCrop.width * 1.1)
    }

    /// Moves the head's centre onto the circle's centre.
    private var faceOffset: CGFloat {
        (HopCanvas.side / 2 - HopPoseGeometry.faceCrop.midY) * renderSize / HopCanvas.side
    }

    public var body: some View {
        HopCharacterView(pose: .idle, size: renderSize, ambient: false, castsShadow: false)
            .offset(y: faceOffset)
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .background {
                Circle().fill(HopCharacterPalette.belly)
            }
            .accessibilityHidden(true)
    }
}

#if DEBUG
private struct HopPoseSheet: View {
    var ambient: Bool = false

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 24) {
                ForEach(HopPose.allCases) { pose in
                    VStack(spacing: 8) {
                        HopCharacterStage(pose: pose, size: 140, ambient: ambient)
                        Text(pose.rawValue)
                            .hopTextStyle(.parentCaption)
                    }
                }
            }
            .padding()
        }
    }
}

/// Steps through the poses on a timer so the interpolation between them can be
/// checked, which a static grid cannot show.
private struct HopPoseTransitionPreview: View {
    @State private var index = 0

    var body: some View {
        VStack(spacing: 24) {
            HopCharacterStage(pose: HopPose.allCases[index], size: 220)
            HopSecondaryButton("Next pose") {
                index = (index + 1) % HopPose.allCases.count
            }
            Text(HopPose.allCases[index].rawValue)
                .hopTextStyle(.parentCaption)
        }
        .padding()
    }
}

/// Replays one hop on a loop, because the things worth checking in a jump all
/// happen inside two thirds of a second and none of them can be seen once.
///
/// In order: the crouch shifting weight *against* the drift, the hands still up
/// while the body drops, the arms trailing the rise and arriving at the apex,
/// the fall handing off to a much shorter spring so he accelerates into the
/// floor, the compression happening only at the floor, and the hands swinging
/// down past the pose on contact before the settle brings them home.
private struct HopJumpLoopPreview: View {
    var hops: Int = 1
    var drift: HopJumpDrift = .inPlace
    var pose: HopPose = .idle
    var size: CGFloat = 220

    @State private var replay = 0

    var body: some View {
        HopCharacterStage(
            act: .hopping(HopJump(hops: hops, drift: drift, replay: replay), restingOn: pose),
            size: size
        )
        .frame(height: size + HopJump.headroom(for: size), alignment: .bottom)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(HopJump.duration(hops: hops) + 0.9))
                guard !Task.isCancelled else { return }
                replay += 1
            }
        }
    }
}

/// Cycles the gaze and changes nothing else.
///
/// That is the whole test: a look has its own spring, so it must not inherit the
/// bounce of whatever beat happened to run last, and the head has to arrive
/// after the eyes rather than with them.
private struct HopGazePreview: View {
    private static let targets: [(name: String, gaze: HopGaze)] = [
        ("forward", .forward),
        ("left", .left),
        ("up", .up),
        ("right", .right),
        ("down", .down),
    ]

    @State private var index = 0

    var body: some View {
        VStack(spacing: 16) {
            HopCharacterStage(pose: .idle, size: 220, gaze: HopGazePreview.targets[index].gaze)
            Text(verbatim: HopGazePreview.targets[index].name)
                .hopTextStyle(.parentCaption)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.6))
                guard !Task.isCancelled else { return }
                index = (index + 1) % HopGazePreview.targets.count
            }
        }
    }
}

/// Alternates an entrance and an exit, which is where the off-stage handling has
/// to hold. Two things to watch for, both of which used to happen: Hop standing
/// on his mark for a frame *before* an entrance and then sliding off to start
/// it, and Hop sliding back on from the wings after an exit instead of fading in
/// on his mark.
private struct HopEntrancePreview: View {
    @State private var isEntering = true

    var body: some View {
        VStack(spacing: 16) {
            HopCharacterStage(
                act: isEntering ? .entering(from: .left) : .exiting(toward: .right),
                size: 180
            )
            .frame(height: 180 + HopJump.headroom(for: 180), alignment: .bottom)
            Text(verbatim: isEntering ? "entering" : "exiting")
                .hopTextStyle(.parentCaption)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.2))
                guard !Task.isCancelled else { return }
                isEntering.toggle()
            }
        }
    }
}

/// Drives one act at a time so the beats, the anticipation and the recovery can
/// be watched, and so an interrupt can be forced by tapping a second act
/// mid-beat — which is the thing that has to land cleanly.
private struct HopActPreview: View {
    struct Option: Identifiable {
        let name: String
        let act: HopAct
        var id: String { name }
    }

    @State private var act: HopAct = .idle
    @State private var replay = 0
    @State private var label = "idle"

    private var options: [Option] {
        [
            Option(name: "idle", act: .idle),
            Option(name: "wave", act: .greeting),
            Option(name: "delight", act: .delighted()),
            Option(name: "speak 2s", act: .speaking(for: 2)),
            Option(name: "hop x1", act: .hopping(HopJump(hops: 1, drift: .inPlace, replay: replay))),
            Option(name: "hop x3", act: .hopping(HopJump(hops: 3, drift: .right, replay: replay))),
            Option(name: "celebrate", act: .celebrating(HopJump(hops: 2, drift: .left, replay: replay))),
            Option(name: "enter", act: .entering(from: .left)),
            Option(name: "exit", act: .exiting(toward: .right)),
            Option(name: "sleep", act: .holding(.sleep)),
            Option(name: "wait", act: .holding(.wait)),
        ]
    }

    var body: some View {
        VStack(spacing: 16) {
            HopCharacterStage(act: act, size: 200)
                .frame(height: 200 + HopJump.headroom(for: 200), alignment: .bottom)

            Text(verbatim: label).hopTextStyle(.parentCaption)

            // Tap one, then tap another before it finishes: the interrupt has to
            // land Hop cleanly, never leave him mid-air or mid-squash.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 8) {
                ForEach(options) { option in
                    HopSecondaryButton(option.name) {
                        replay += 1
                        label = option.name
                        act = option.act
                    }
                }
            }
        }
        .padding()
    }
}

#Preview("Hop · all poses") {
    HopPoseSheet()
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Hop · idle (breath, blink, weight, settle)") {
    VStack(spacing: 32) {
        HopCharacterStage(pose: .idle, size: 240)
        HopCharacterStage(pose: .wait, size: 160)
        Text("Never perfectly still, never busy.").hopTextStyle(.parentCaption)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Hop · one jump") {
    VStack(spacing: 24) {
        HopCharacterStage(pose: .idle, size: 220, jumping: HopJump())
            .frame(height: 220 + HopJump.headroom(for: 220), alignment: .bottom)
        Text("Crouch, rise, hang, fall, impact, settle.").hopTextStyle(.parentCaption)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Hop · jump on a loop (weight, follow-through)") {
    VStack(spacing: 24) {
        HopJumpLoopPreview()
        Text("Hands lag the body, arrive at the apex, and swing past on contact.")
            .hopTextStyle(.parentCaption)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Hop · jump on a loop · Reduce Motion") {
    VStack(spacing: 24) {
        HopJumpLoopPreview()
        Text("One cross-fade, no travel, no lag: there is nothing for a hand to trail.")
            .hopTextStyle(.parentCaption)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot(reduceMotion: true)
}

#Preview("Hop · repeated jump") {
    VStack(spacing: 24) {
        HopCharacterStage(pose: .cheer, size: 220, jumping: HopJump(hops: 3, drift: .right))
            .frame(height: 220 + HopJump.headroom(for: 220), alignment: .bottom)
        Text("One burst, not a queue.").hopTextStyle(.parentCaption)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Hop · burst on a loop (no dead beat)") {
    VStack(spacing: 24) {
        HopJumpLoopPreview(hops: 3, drift: .right, pose: .cheer)
        Text("Each landing is the next crouch. Nothing holds still in the middle.")
            .hopTextStyle(.parentCaption)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Hop · acts and interrupts") {
    HopActPreview()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Hop · gaze") {
    HStack(spacing: 24) {
        HopCharacterStage(pose: .idle, size: 150, gaze: .left)
        HopCharacterStage(pose: .idle, size: 150, gaze: .forward)
        HopCharacterStage(pose: .idle, size: 150, gaze: .right)
        HopCharacterStage(pose: .scrub, size: 150, gaze: .down)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Hop · gaze tracking (eyes lead, head follows)") {
    VStack(spacing: 24) {
        HopGazePreview()
        Text("Flat springs, and the head starts after the eyes.")
            .hopTextStyle(.parentCaption)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Hop · gaze tracking · Reduce Motion") {
    VStack(spacing: 24) {
        HopGazePreview()
        Text("The look still lands; it cross-fades there.")
            .hopTextStyle(.parentCaption)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot(reduceMotion: true)
}

#Preview("Hop · entrance and exit") {
    VStack(spacing: 24) {
        HopEntrancePreview()
        Text("Never on his mark before an entrance, never sliding back after an exit.")
            .hopTextStyle(.parentCaption)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Hop · entrance and exit · Reduce Motion") {
    VStack(spacing: 24) {
        HopEntrancePreview()
        Text("He fades in and out on his mark. Nothing crosses the screen.")
            .hopTextStyle(.parentCaption)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot(reduceMotion: true)
}

#Preview("Hop · Reduce Motion (must be still)") {
    VStack(spacing: 32) {
        HopCharacterStage(pose: .idle, size: 200, jumping: HopJump(hops: 3))
        HopCharacterStage(act: .greeting, size: 160)
        Text("No breath, no blink, no travel — the beats are cross-fades.")
            .hopTextStyle(.parentCaption)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot(reduceMotion: true)
}

#Preview("Hop · pose transitions") {
    HopPoseTransitionPreview()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Hop · dark stage") {
    HopPoseSheet()
        .hopBackground()
        .hopThemedRoot()
        .preferredColorScheme(.dark)
}

#Preview("Hop · sizes and chip") {
    VStack(spacing: 24) {
        HStack(alignment: .bottom, spacing: 20) {
            HopCharacterStage(pose: .idle, size: 44, ambient: false)
            HopCharacterStage(pose: .idle, size: 88, ambient: false)
            HopCharacterStage(pose: .idle, size: 160, ambient: false)
        }
        HStack(spacing: 12) {
            HopChip()
            HopChip(diameter: 48)
            Text("Sam").hopTextStyle(.parentBody)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
}
#endif
