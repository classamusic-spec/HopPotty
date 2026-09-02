import SwiftUI
import HopPottyCore

/// The heartbeat the moving boards run on, and the ground they are drawn on.
///
/// Five of the games have something that keeps going while the child watches —
/// flies drifting, a ball bouncing, water going round. All five step the same
/// way, from one place, so there is one answer to "how often does a board move"
/// rather than five.
enum GameClock {
    /// Twice a second.
    ///
    /// Deliberately coarse. A board that stepped at sixty hertz would have to
    /// draw its own movement, and movement a game draws itself is movement that
    /// has to remember Reduce Motion. At two hertz the *model* only says where
    /// things are, and the distance between two of those answers is covered by a
    /// motion token — `.hopAnimation(.childArrive, value:)` — which is already a
    /// spring when motion is on and a two-tenths cross-fade when it is not.
    /// One Reduce Motion reader in the app, and no game can forget it.
    ///
    /// It also happens to be right for the subject: a fly does not glide, it
    /// darts and settles, which is exactly what a spring between two waypoints
    /// half a second apart looks like.
    static let tick: Duration = .milliseconds(500)

    /// The most time a single step may claim, however long the app was away.
    ///
    /// Coming back from four minutes in someone's pocket should resume the game,
    /// not fast-forward through the whole story in one frame.
    static let maximumStep: TimeInterval = 2
}

private extension Duration {
    /// Seconds as a `TimeInterval`, which is what the models count in.
    var gameSeconds: TimeInterval {
        let parts = components
        return TimeInterval(parts.seconds) + TimeInterval(parts.attoseconds) / 1e18
    }
}

private struct GameClockModifier<Session: TimedMiniGameSession>: ViewModifier {
    let session: Session

    func body(content: Content) -> some View {
        // Keyed on `isFinished` so the loop is torn down the moment a board is
        // over and started again by "Play again", without the modifier having to
        // own any state of its own.
        content.task(id: session.isFinished) {
            guard !session.isFinished else { return }
            var previous = ContinuousClock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: GameClock.tick)
                guard !Task.isCancelled else { return }
                let now = ContinuousClock.now
                let step = min((now - previous).gameSeconds, GameClock.maximumStep)
                previous = now
                session.advance(by: step)
                if session.isFinished { return }
            }
        }
    }
}

extension View {
    /// Steps a moving board forward for as long as it is on screen.
    func gameClock(_ session: some TimedMiniGameSession) -> some View {
        modifier(GameClockModifier(session: session))
    }
}

// MARK: - The ground a board is drawn on

/// The illustrated scene, with the board's own pieces laid over it.
///
/// Every board is a picture first: `scene.games.<id>` fills the space, the
/// pieces sit on top in unit coordinates, and until the drawing ships
/// `HopArtwork` puts its soft placeholder there instead so the game is still
/// playable on a half-drawn catalog.
struct GameScene<Content: View>: View {
    @Environment(\.hopTheme) private var theme

    let key: HopIllustrationKey
    /// What the whole board is, for a child arriving on it with VoiceOver.
    let label: String
    @ViewBuilder var content: (CGSize) -> Content

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: theme.radius.hero, style: .continuous)
                    .fill(HopColors.wash(theme.color.brandPrimary, isDark: theme.isDark))

                // Decorative: the scene is the room, and the room is not a
                // control. Everything a child can act on carries its own label.
                HopArtwork(key)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                content(proxy.size)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.hero, style: .continuous))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// The little cloud a caught fly leaves behind.
///
/// Three soft circles that grow and fade. Drawn rather than named as an
/// illustration key because it is a *movement*, not a picture: at any single
/// moment it is three circles, and asking the art pipeline for a drawing of the
/// middle of a puff would produce a sticker.
struct GamePuff: View {
    @Environment(\.hopTheme) private var theme

    /// 0 at the moment of the catch, 1 when the puff has gone.
    let progress: Double
    let side: CGFloat

    var body: some View {
        ZStack {
            circle(dx: -0.22, dy: 0.10, scale: 0.55)
            circle(dx: 0.20, dy: -0.06, scale: 0.48)
            circle(dx: 0.02, dy: -0.26, scale: 0.62)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }

    private func circle(dx: Double, dy: Double, scale: Double) -> some View {
        Circle()
            .fill(theme.color.surfaceElevated.opacity(0.85 * (1 - progress)))
            .frame(width: side * scale, height: side * scale)
            .offset(x: side * dx * (0.6 + progress), y: side * dy * (0.6 + progress))
    }
}

/// A row of soft, rising bubbles for the two water games.
///
/// The rise is a position the *model* holds, so this view only maps a phase to
/// an offset; that keeps the motion on the token that already knows about
/// Reduce Motion rather than on a repeating animation this file would own.
struct GameBubbleColumn: View {
    @Environment(\.hopTheme) private var theme

    /// 0...1 through one rise.
    let progress: Double
    let width: CGFloat
    let height: CGFloat

    private static let bubbles: [(x: Double, size: Double, lead: Double)] = [
        (0.22, 0.13, 0.00),
        (0.46, 0.19, 0.18),
        (0.68, 0.11, 0.34),
        (0.84, 0.16, 0.52),
        (0.35, 0.09, 0.66),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(Array(Self.bubbles.enumerated()), id: \.offset) { _, bubble in
                let travel = min(1, max(0, progress + bubble.lead))
                Circle()
                    .fill(theme.color.surfaceElevated.opacity(0.75 * (1 - travel)))
                    .frame(width: width * bubble.size, height: width * bubble.size)
                    .offset(x: width * (bubble.x - 0.5), y: -height * travel)
            }
        }
        .frame(width: width, height: height, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
