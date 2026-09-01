import SwiftUI
import HopPottyCore

/// The child's game chooser, and the runner that plays one.
///
/// Navigation is one step deep and it is a swap, not a stack: three pictures,
/// tap one, play it, come back. There is no list to scroll, no lock icon, no
/// "coming soon" and no ordering that implies one game is the reward for
/// another.
///
/// Whether games are offered at all is `AppSettings.miniGamesEnabled`, which the
/// caller checks before presenting this screen — the child-facing surface has no
/// business drawing a door it then refuses to open.
struct GamesScreen: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Called with the round a child finished, so the caller can award through
    /// `RewardService`. One star, whatever happened on the board.
    let onFinishRound: (MiniGameRoundResult) -> Void
    let onLeave: () -> Void

    @State private var playing: MiniGameID?

    var body: some View {
        ZStack {
            if let playing {
                runner(for: playing)
                    .hopTransition(.childArrive)
            } else {
                menu
                    .hopTransition(.childArrive)
            }
        }
        .hopAnimation(.childArrive, value: playing)
        .hopBackground(.secondary)
    }

    // MARK: - Menu

    private var menu: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xl) {
            HStack {
                Text(HopCopy.games.title.localized)
                    .hopTextStyle(.childTitle)
                    .foregroundStyle(theme.color.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: theme.spacing.s)

                HopIconButton(
                    systemImage: "xmark",
                    accessibilityLabel: HopCopy.celebration.resumeButton.localized,
                    action: onLeave
                )
            }

            layout
        }
        .frame(maxWidth: ChildStage.contentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .hopPageMargins()
        .padding(.vertical, theme.spacing.xl)
    }

    @ViewBuilder
    private var layout: some View {
        if horizontalSizeClass == .regular {
            HStack(spacing: theme.spacing.l) {
                ForEach(MiniGameCatalog.all) { game in
                    GameChoiceCard(game: game) { playing = game.id }
                }
            }
        } else {
            VStack(spacing: theme.spacing.l) {
                ForEach(MiniGameCatalog.all) { game in
                    GameChoiceCard(game: game) { playing = game.id }
                }
            }
        }
    }

    // MARK: - Running one

    @ViewBuilder
    private func runner(for id: MiniGameID) -> some View {
        switch id {
        case .bubbleWash:
            BubbleWashRunner(onLeave: leaveGame, onFinish: finishGame)
        case .pottyPath:
            PottyPathRunner(onLeave: leaveGame, onFinish: finishGame)
        case .bathroomMatch:
            BathroomMatchRunner(onLeave: leaveGame, onFinish: finishGame)
        }
    }

    /// Backing out of a game the child never finished. No star, no comment, no
    /// "are you sure" — leaving is a legitimate thing to do.
    private func leaveGame() {
        playing = nil
    }

    private func finishGame(_ game: MiniGame) {
        onFinishRound(MiniGameRoundResult(game: game))
        playing = nil
    }
}

/// One game on the chooser. All three are drawn by this one view, at one size.
private struct GameChoiceCard: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    let game: MiniGame
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: theme.spacing.l) {
                HopArtwork(game.illustration)
                    .frame(width: 84, height: 84)

                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    Text(game.title.localized)
                        .hopTextStyle(.buttonLarge)
                        .foregroundStyle(theme.color.textPrimary)
                    Text(game.childDescription.localized)
                        .hopTextStyle(.parentCallout)
                        .foregroundStyle(theme.color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(theme.spacing.l)
            .frame(maxWidth: .infinity, minHeight: theme.hitTarget.childPrimary, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                    .fill(theme.color.surfaceElevated)
            }
        }
        .buttonStyle(.plain)
        .modifier(theme.elevation(.resting))
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: theme.radius.xl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(game.title.localized)
        .accessibilityHint(game.childDescription.localized)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Runners
//
// One tiny view per game, each owning its own session. Three of these rather
// than one generic runner because `@State` has to be declared against a
// concrete type — and because three eight-line structs are cheaper to read than
// the abstraction that would remove them.

private struct BubbleWashRunner: View {
    @State private var session = BubbleWashSession()
    let onLeave: () -> Void
    let onFinish: (MiniGame) -> Void

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: { session.isFinished ? onFinish(session.game) : onLeave() }
        ) {
            BubbleWashGameView(session: session)
        }
    }
}

private struct PottyPathRunner: View {
    @State private var session = PottyPathSession()
    let onLeave: () -> Void
    let onFinish: (MiniGame) -> Void

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: { session.isFinished ? onFinish(session.game) : onLeave() }
        ) {
            PottyPathGameView(session: session)
        }
    }
}

private struct BathroomMatchRunner: View {
    @State private var session = BathroomMatchSession()
    let onLeave: () -> Void
    let onFinish: (MiniGame) -> Void

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            // Bathroom Match has no ending of its own, so tapping "All done"
            // *is* how it finishes — and it earns the same star as a board that
            // ran itself out.
            onLeave: { onFinish(session.game) }
        ) {
            BathroomMatchGameView(session: session)
        }
    }
}

#Preview("Games · chooser") {
    GamesScreen(onFinishRound: { _ in }, onLeave: {})
        .hopThemedRoot()
}

#Preview("Games · chooser AX3") {
    ScrollView {
        GamesScreen(onFinishRound: { _ in }, onLeave: {})
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopThemedRoot()
}

#Preview("Games · chooser iPad") {
    GamesScreen(onFinishRound: { _ in }, onLeave: {})
        .frame(width: 1024, height: 768)
        .hopThemedRoot()
}

#Preview("Games · chooser Reduce Motion") {
    GamesScreen(onFinishRound: { _ in }, onLeave: {})
        .hopThemedRoot(reduceMotion: true)
}
