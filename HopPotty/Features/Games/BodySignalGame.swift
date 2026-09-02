import SwiftUI
import HopPottyCore

/// Hop, his ball, and the bubble that interrupts them.
struct BodySignalGameView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let session: BodySignalSession

    var body: some View {
        GameScene(
            key: session.game.illustration,
            label: (session.game.intro ?? session.game.childDescription).localized
        ) { size in
            let characterSide = min(min(size.width, size.height) * 0.66, ChildStage.characterSize(for: horizontalSizeClass))
            let ballSide = max(theme.hitTarget.child, min(size.width, size.height) * 0.18)

            ZStack {
                ball(side: ballSide, in: size)

                hop(side: characterSide, in: size)

                if session.isSignalShowing {
                    ThoughtBubbleButton(side: max(theme.hitTarget.childPrimary, characterSide * 0.5)) {
                        session.answerSignal()
                    }
                    .position(
                        x: size.width * (session.hopPosition + 0.26),
                        y: size.height * 0.30
                    )
                    .hopTransition(.childArrive)
                }
            }
            .hopAnimation(.childArrive, value: session.beat)
        }
        .overlay(alignment: .bottom) { spokenLine }
        .gameClock(session)
    }

    // MARK: - Pieces

    /// The ball bounces on its own and is not a control: there is nothing to do
    /// with it, and a target a tap does nothing to is worse than no target.
    private func ball(side: CGFloat, in size: CGSize) -> some View {
        HopArtwork("icon.games.ball")
            .frame(width: side, height: side)
            .position(
                x: size.width * (session.hopPosition + 0.20),
                y: size.height * (0.80 - 0.30 * session.ballHeight)
            )
            .hopAnimation(.childTap, value: session.ballHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(GameCopy.ball.localized)
            .accessibilityAddTraits(.isImage)
    }

    /// Hop is tappable throughout, and tapping him is never a mistake — with a
    /// bubble up it is the same as tapping the bubble, without one it is a
    /// giggle.
    private func hop(side: CGFloat, in size: CGSize) -> some View {
        Button {
            if session.isSignalShowing { session.answerSignal() } else { session.tickle() }
        } label: {
            HopCharacterStage(pose: pose, size: side, describedAs: "")
        }
        .buttonStyle(.plain)
        .frame(width: max(side, theme.hitTarget.childPrimary), height: max(side, theme.hitTarget.childPrimary))
        .contentShape(Rectangle())
        // The giggle: one small bounce, keyed on the count so a second tap
        // giggles again rather than being swallowed by the first.
        .scaleEffect(session.giggles.isMultiple(of: 2) ? 1 : 1.06)
        .hopAnimation(.childTap, value: session.giggles)
        .position(x: size.width * session.hopPosition, y: size.height * 0.62)
        .hopAnimation(.childArrive, value: session.hopPosition)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GameCopy.bodySignalHop.localized)
        .accessibilityAddTraits(.isButton)
    }

    private var pose: HopPose {
        switch session.beat {
        // `full` is the wiggle: bigger belly, a hand on it, knees together. It
        // is the pose the routine uses for "my body is telling me something",
        // which is precisely what the bubble means.
        case .signalling: .full
        case .hoppingOut: .jump
        case .away, .returning: .walk
        case .playing: .idle
        }
    }

    // MARK: - What Hop says

    private var spokenLine: some View {
        HopSpokenLine(line, pulse: session.signalsShown + session.giggles)
            .padding(.horizontal, theme.spacing.l)
            .padding(.bottom, theme.spacing.m)
    }

    private var line: HopPottyCore.HopVoiceLine {
        switch session.beat {
        case .signalling, .hoppingOut, .away, .returning:
            return session.game.line("signal")
        case .playing:
            if session.signalsAnswered >= BodySignalSession.signalCount { return session.game.line("done") }
            return session.giggles > 0 ? session.game.line("giggle") : session.game.line("intro")
        }
    }
}

/// The thought bubble with the drop in it.
private struct ThoughtBubbleButton: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    let side: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HopArtwork("icon.games.thoughtBubble")
                .frame(width: side * 0.82, height: side * 0.82)
        }
        .buttonStyle(.plain)
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        .hopFloating(true, distance: 4, period: 3.0)
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: side / 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GameCopy.thoughtBubble.localized)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Previews

private struct BodySignalHostPreview: View {
    @State var session: BodySignalSession
    var reduceMotion: Bool? = nil

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: {}
        ) {
            BodySignalGameView(session: session)
        }
        .hopThemedRoot(reduceMotion: reduceMotion)
    }
}

#Preview("Listen to Your Body · playing") {
    BodySignalHostPreview(session: BodySignalSession())
}

#Preview("Listen to Your Body · signal showing") {
    BodySignalHostPreview(session: {
        let session = BodySignalSession()
        session.advance(by: BodySignalSession.playGap + 0.1)
        return session
    }())
}

#Preview("Listen to Your Body · hopping off") {
    BodySignalHostPreview(session: {
        let session = BodySignalSession()
        session.advance(by: BodySignalSession.playGap + 0.1)
        session.answerSignal()
        session.advance(by: BodySignalSession.hopOutDuration + 0.1)
        return session
    }())
}

#Preview("Listen to Your Body · Reduce Motion") {
    BodySignalHostPreview(session: BodySignalSession(), reduceMotion: true)
}

#Preview("Listen to Your Body · iPad") {
    BodySignalHostPreview(session: BodySignalSession())
        .frame(width: 1024, height: 768)
}

#Preview("Listen to Your Body · AX3") {
    BodySignalHostPreview(session: BodySignalSession())
        .environment(\.dynamicTypeSize, .accessibility3)
}
