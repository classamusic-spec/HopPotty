import SwiftUI
import HopPottyCore

/// The toilet, the flusher, the swirl and Hop's wave.
struct FlushWaveGameView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let session: FlushWaveSession

    var body: some View {
        GameScene(
            key: session.game.illustration,
            label: (session.game.intro ?? session.game.childDescription).localized
        ) { size in
            ZStack {
                swirl(in: size)

                if session.washProgress > 0 {
                    GameBubbleColumn(
                        progress: session.washProgress,
                        width: size.width * 0.42,
                        height: size.height * 0.4
                    )
                    .position(x: size.width * 0.74, y: size.height * 0.62)
                    .hopAnimation(.childArrive, value: session.washProgress)
                }

                hop(in: size)

                if session.isFlusherOffered {
                    flusher
                        .position(x: size.width * 0.30, y: size.height * 0.24)
                        .hopTransition(.childArrive)
                }

                if session.isTapOffered {
                    tapControl
                        .position(x: size.width * 0.78, y: size.height * 0.24)
                        .hopTransition(.childArrive)
                }
            }
            .hopAnimation(.childArrive, value: session.beat)
        }
        .overlay(alignment: .bottom) { spokenLine }
        .gameClock(session)
    }

    // MARK: - Pieces

    /// The water going round. Two full turns over the two seconds, drawn by
    /// mapping the model's progress onto an angle — so under Reduce Motion the
    /// token cross-fades between the quarter-turns the clock reports instead of
    /// spinning a wheel on a child's screen.
    private func swirl(in size: CGSize) -> some View {
        HopArtwork("icon.games.swirl", accessibilityLabel: GameCopy.swirl.localized)
            .frame(width: size.width * 0.46, height: size.width * 0.46)
            .rotationEffect(.degrees(session.swirlProgress * 720))
            .scaleEffect(0.7 + session.swirlProgress * 0.3)
            .opacity(session.swirlProgress > 0 ? 1 : 0)
            .position(x: size.width * 0.5, y: size.height * 0.42)
            .hopAnimation(.childArrive, value: session.swirlProgress)
            .accessibilityHidden(session.swirlProgress == 0)
    }

    private func hop(in size: CGSize) -> some View {
        let side = min(min(size.width, size.height) * 0.58, ChildStage.characterSize(for: horizontalSizeClass))
        return HopCharacterStage(pose: pose, size: side, describedAs: GameCopy.flushWaveHop.localized)
            .position(x: size.width * 0.5, y: size.height * 0.74)
    }

    private var pose: HopPose {
        switch session.beat {
        case .waving: .wave
        case .washing: .scrub
        case .ready, .swirling, .washReady, .done: .idle
        }
    }

    private var flusher: some View {
        GameTapTarget(
            illustration: "icon.games.flusher",
            label: GameCopy.flusher.localized,
            invites: session.beat == .ready,
            action: { session.flush() }
        )
    }

    private var tapControl: some View {
        GameTapTarget(
            illustration: "icon.quiz.sink",
            label: GameCopy.flushWaveTap.localized,
            invites: true,
            action: { session.wash() }
        )
    }

    // MARK: - What Hop says

    private var spokenLine: some View {
        HopSpokenLine(line, pulse: session.flushes)
            .padding(.horizontal, theme.spacing.l)
            .padding(.bottom, theme.spacing.m)
    }

    private var line: HopPottyCore.HopVoiceLine {
        switch session.beat {
        case .ready: return session.game.line("intro")
        case .swirling: return session.game.line("flush")
        case .waving: return session.game.line("wave")
        case .washReady, .washing, .done: return session.game.line("wash")
        }
    }
}

/// A big, round, obvious thing to press.
///
/// Used for the flusher and the tap, so the two controls in this game are the
/// same control at the same size — there is nothing here to learn twice.
private struct GameTapTarget: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    let illustration: HopIllustrationKey
    let label: String
    /// Whether this is the thing the board is currently asking for. The breath
    /// is the invitation; nothing flashes and nothing nags.
    let invites: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HopArtwork(illustration)
                .frame(width: theme.hitTarget.childPrimary * 0.68, height: theme.hitTarget.childPrimary * 0.68)
        }
        .buttonStyle(.plain)
        .frame(width: theme.hitTarget.childPrimary, height: theme.hitTarget.childPrimary)
        .background(Circle().fill(theme.color.surfaceElevated.opacity(0.92)))
        .contentShape(Circle())
        .hopBreathing(invites, amplitude: 0.05)
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: theme.hitTarget.childPrimary / 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Previews

private struct FlushWaveHostPreview: View {
    @State var session: FlushWaveSession
    var reduceMotion: Bool? = nil

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: {}
        ) {
            FlushWaveGameView(session: session)
        }
        .hopThemedRoot(reduceMotion: reduceMotion)
    }
}

#Preview("Flush and Wave · ready") {
    FlushWaveHostPreview(session: FlushWaveSession())
}

#Preview("Flush and Wave · swirling") {
    FlushWaveHostPreview(session: {
        let session = FlushWaveSession()
        session.flush()
        session.advance(by: FlushWaveSession.swirlDuration * 0.6)
        return session
    }())
}

#Preview("Flush and Wave · waving") {
    FlushWaveHostPreview(session: {
        let session = FlushWaveSession()
        session.flush()
        session.advance(by: FlushWaveSession.swirlDuration + 0.1)
        return session
    }())
}

#Preview("Flush and Wave · Reduce Motion") {
    FlushWaveHostPreview(session: FlushWaveSession(), reduceMotion: true)
}

#Preview("Flush and Wave · iPad") {
    FlushWaveHostPreview(session: FlushWaveSession())
        .frame(width: 1024, height: 768)
}

#Preview("Flush and Wave · AX3") {
    FlushWaveHostPreview(session: FlushWaveSession())
        .environment(\.dynamicTypeSize, .accessibility3)
}
