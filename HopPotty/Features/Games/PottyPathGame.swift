import SwiftUI
import HopPottyCore

/// The walk to the bathroom, over an illustrated home.
///
/// ## A place, not a board
///
/// The whole view is `scene.games.pottyPath` — a room a child recognises, with a
/// hall runner drawn through it — and Hop stands on it. The route's stops are
/// **lily pads** laid along the runner, which is what the game has always called
/// them ("Hop along the lily pads all the way to the potty!") and what the
/// render draws: a pad is a thing Hop stands on in a world a child already
/// knows, and a tile is a game piece. Nothing is drawn as a grid, nothing is
/// drawn as a wall, and there is no square the child is forbidden.
///
/// ## Two ways to move him, and they are the same way
///
/// * **Drag Hop.** The finger is projected onto the route, so he follows it
///   along the path and never leaves it — smooth, continuous, and impossible to
///   get wrong.
/// * **Tap the next pad.** He walks one whole step, animated by the child-facing
///   motion token, which is what makes the tap and the drag land in the same
///   place with the same feel.
///
/// The next pad is the only one that breathes, and Hop looks at it. That is the
/// entire instruction system: no arrows blinking, no hand animation, no "tap
/// here!" — one thing is alive, and Hop is looking at it.
///
/// ## No failure, and no clock
///
/// Nothing counts, nothing is timed, nothing chases him and nothing can be lost.
/// Dragging him backwards is allowed and says nothing. The round ends exactly
/// once, when he reaches the potty: he waves, and `GameHostView` gives the same
/// short celebration every game ends on.
struct PottyPathGameView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.hopButtonFeedback) private var buttonFeedback

    let session: PottyPathSession

    /// Where the finger is while a drag is in flight, so the cue can stand down
    /// while the child is already doing it.
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                home
                trail(in: size)
                pads(in: size)
                hop(in: size)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(in: size))
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.hero, style: .continuous))
        .overlay(alignment: .top) { nudge }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(session.game.title.localized)
    }

    // MARK: - The room

    /// The illustrated home. Decorative: the route on top of it is what carries
    /// the meaning, and it is individually labelled.
    private var home: some View {
        HopArtwork(session.game.illustration)
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .accessibilityHidden(true)
    }

    // MARK: - The route

    /// The path Hop has already walked, drawn behind the pads.
    ///
    /// A single soft stroke that fills in as he goes — the visible answer to
    /// "how far have we got?", with no number anywhere near it.
    private func trail(in size: CGSize) -> some View {
        Canvas(rendersAsynchronously: false) { context, _ in
            let route = PottyPathSession.route
            guard route.count > 1 else { return }

            var whole = Path()
            whole.move(to: point(route[0].point, in: size))
            for stop in route.dropFirst() { whole.addLine(to: point(stop.point, in: size)) }
            context.stroke(
                whole,
                with: .color(theme.color.textOnBrand.opacity(0.55)),
                style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
            )

            var walked = Path()
            walked.move(to: point(route[0].point, in: size))
            let done = session.progress
            for index in 1..<route.count {
                if Double(index) <= done {
                    walked.addLine(to: point(route[index].point, in: size))
                } else {
                    walked.addLine(to: point(session.position, in: size))
                    break
                }
            }
            context.stroke(
                walked,
                with: .color(theme.color.brandAction.opacity(0.75)),
                style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// One lily pad per stop. Only the next one is a control.
    @ViewBuilder
    private func pads(in size: CGSize) -> some View {
        ForEach(PottyPathSession.route) { stop in
            PottyPathStopView(
                stop: stop,
                isNext: session.nextStop?.index == stop.index,
                isReached: Double(stop.index) <= session.progress + 0.001,
                isGoal: stop.index == PottyPathSession.route.count - 1,
                side: max(theme.hitTarget.child, size.width * 0.13),
                onTap: { walk(to: stop) }
            )
            .position(point(stop.point, in: size))
        }
    }

    /// Hop, on the path.
    ///
    /// He looks at the next stop while he is walking and waves the moment he
    /// arrives — which is the whole of §30's ending: he reaches the potty, he
    /// waves, and the host does the short celebration.
    private func hop(in size: CGSize) -> some View {
        let side = max(88, size.width * 0.26)
        return HopCharacterStage(
            act: session.hasArrived ? .greeting : .idle,
            size: side,
            gaze: gaze,
            describedAs: GameCopy.pathHop.localized
        )
        .position(
            x: point(session.position, in: size).x,
            y: point(session.position, in: size).y - side * 0.34
        )
        // A tap moves him a whole step and the token draws the walk; a drag
        // moves him every frame and must not animate, or he lags the finger.
        .hopAnimation(.childArrive, value: isDragging ? 0 : session.progress)
    }

    /// Where Hop is looking: at the next stop, or straight out once he arrives.
    private var gaze: HopGaze {
        guard let next = session.nextStop else { return .forward }
        let here = session.position
        // The stops are a fraction of the scene apart and Hop is about a fifth
        // of it wide, so the offset is scaled into his own frame.
        return HopGaze(
            x: CGFloat(0.5 + (next.x - Double(here.x)) * 2.5),
            y: CGFloat(0.5 + (next.y - Double(here.y)) * 2.5)
        )
    }

    /// The one sentence on the board.
    private var nudge: some View {
        Text((session.hasArrived ? GameCopy.pathArrived : GameCopy.pathNudge).localized)
            .hopTextStyle(.childInstruction)
            .foregroundStyle(theme.color.textPrimary)
            .padding(.horizontal, theme.spacing.l)
            .padding(.vertical, theme.spacing.s)
            .background(Capsule().fill(theme.color.surface.opacity(0.92)))
            .padding(.top, theme.spacing.m)
            .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Moving him

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                isDragging = true
                session.drag(to: unit(value.location, in: size))
            }
            .onEnded { _ in
                isDragging = false
                if session.hasArrived { buttonFeedback.play(.confirmation) }
            }
    }

    private func walk(to stop: PottyPathSession.Stop) {
        session.step(to: stop)
        if session.hasArrived { buttonFeedback.play(.confirmation) }
    }

    // MARK: - Geometry

    private func point(_ unit: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }

    private func unit(_ point: CGPoint, in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGPoint(x: point.x / size.width, y: point.y / size.height)
    }
}

/// One place to put a foot: a lily pad on the hall runner.
///
/// Three states, and none of them is a failure: reached, next, or still ahead. A
/// pad that is still ahead is drawn faintly rather than crossed out or locked —
/// the child has not got there yet, which is not the same as being refused.
private struct PottyPathStopView: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    let stop: PottyPathSession.Stop
    let isNext: Bool
    let isReached: Bool
    let isGoal: Bool
    let side: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                LilyPadShape()
                    .fill(fill)
                    .overlay {
                        LilyPadShape().strokeBorder(
                            isNext ? theme.color.brandAction : theme.color.textOnBrand.opacity(0.65),
                            lineWidth: isNext ? 4 : 2
                        )
                    }

                if isGoal {
                    HopArtwork("icon.quiz.potty")
                        .frame(width: side * 0.52, height: side * 0.52)
                }
            }
            .frame(width: side * 0.86, height: side * 0.62)
        }
        .buttonStyle(.plain)
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        // Only the next stop does anything. The rest are scenery, and scenery a
        // child taps by accident should stay quiet rather than say no.
        .disabled(!isNext)
        .hopBreathing(isNext, amplitude: 0.05)
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: side / 2)
        .accessibilityHidden(!isNext)
        .accessibilityLabel(stop.name.localized)
        .accessibilityAddTraits(.isButton)
    }

    /// State is carried by fill, by border weight and by the accessibility
    /// label, so none of it rests on colour alone.
    private var fill: Color {
        if isGoal { return HopColors.wash(theme.color.celebration, isDark: theme.isDark) }
        if isReached { return theme.color.success.opacity(0.75) }
        return theme.color.success.opacity(isNext ? 0.5 : 0.28)
    }
}

/// A lily pad: a squashed disc with a wedge cut out of it.
///
/// The same silhouette `Scripts/scene-art.js` draws with its `pad` primitive, so
/// a pad in this game and a pad in the pond are recognisably the same object.
/// `InsettableShape` because it is stroked as well as filled, and a plain
/// `Shape` would put half the stroke outside the pad.
private struct LilyPadShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: inset, dy: inset)
        var path = Path(ellipseIn: box)
        // The notch: a wedge from the centre to the upper-right rim.
        path.move(to: CGPoint(x: box.midX, y: box.midY))
        path.addLine(to: CGPoint(x: box.maxX - box.width * 0.08, y: box.midY - box.height * 0.30))
        path.addLine(to: CGPoint(x: box.maxX - box.width * 0.22, y: box.midY - box.height * 0.42))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> LilyPadShape {
        LilyPadShape(inset: inset + amount)
    }
}

#Preview("Potty Path · start") {
    PottyPathHostPreview(session: PottyPathSession())
}

#Preview("Potty Path · part way") {
    PottyPathHostPreview(session: {
        let session = PottyPathSession()
        session.drag(to: CGPoint(x: 0.47, y: 0.72))
        return session
    }())
}

#Preview("Potty Path · arrived") {
    PottyPathHostPreview(session: {
        let session = PottyPathSession()
        session.drag(to: CGPoint(x: 0.86, y: 0.50))
        return session
    }())
}

#Preview("Potty Path · Reduce Motion") {
    PottyPathHostPreview(session: PottyPathSession(), reduceMotion: true)
}

#Preview("Potty Path · iPad") {
    PottyPathHostPreview(session: PottyPathSession())
        .frame(width: 1024, height: 768)
}

private struct PottyPathHostPreview: View {
    @State var session: PottyPathSession
    var reduceMotion: Bool? = nil

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: {}
        ) {
            PottyPathGameView(session: session)
        }
        .hopThemedRoot(reduceMotion: reduceMotion)
    }
}

#Preview("Potty Path · AX3") {
    PottyPathHostPreview(session: PottyPathSession())
        .environment(\.dynamicTypeSize, .accessibility3)
}
