import SwiftUI
import HopPottyCore

/// The child's game chooser, and the runner that plays one.
///
/// Navigation is one step deep and it is a swap, not a stack: pictures, tap
/// one, play it, come back. There is no lock icon, no "coming soon" and no
/// ordering that implies one game is the reward for another — the catalog's own
/// order is the order here, and every entry in it is offered.
///
/// Eight of them no longer fit one screen at every type size, so the chooser
/// scrolls when it has to and does not when it does not. That is the only thing
/// the count changed: nothing is behind a page, a category or a "more".
///
/// Whether games are offered at all is `AppSettings.miniGamesEnabled`, which the
/// caller checks before presenting this screen — the child-facing surface has no
/// business drawing a door it then refuses to open.
struct GamesScreen: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Called with the round a child finished, so the caller can award through
    /// `RewardService`. One star, whatever happened on the board.
    ///
    /// The result carries `MiniGameRoundResult.handOffStep`, which is how Fly
    /// Snack's ending reaches the caller: a round that filled Hop's tummy asks
    /// for the routine to be opened on its first step instead of returning here.
    let onFinishRound: (MiniGameRoundResult) -> Void
    let onLeave: () -> Void

    @State private var playing: MiniGameID?

    var body: some View {
        // Picking a game and coming back out of one are the two screen changes
        // this surface has, and they get the child-facing page transition: one
        // picture hands over to another rather than cutting.
        HopPageSwitch(.childPage, value: playing) { game in
            if let game {
                runner(for: game)
            } else {
                menu
            }
        }
        .hopBackground(.secondary)
    }

    // MARK: - Menu

    private var menu: some View {
        VStack(alignment: .leading, spacing: theme.spacing.l) {
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
            .hopPageMargins()

            ScrollView {
                layout
                    .hopPageMargins()
                    .padding(.bottom, theme.spacing.xl)
            }
            // Only scrolls when the cards actually overflow, so at a default
            // type size the chooser is still a still picture rather than a list
            // that bounces under a child's finger.
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: ChildStage.contentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, theme.spacing.xl)
    }

    /// One column on a phone, two on an iPad. The card is the same card either
    /// way: an iPad gets more games in view, not bigger ones.
    private var layout: some View {
        LazyVGrid(columns: columns, spacing: theme.spacing.l) {
            ForEach(MiniGameCatalog.all) { game in
                GameChoiceCard(game: game) { playing = game.id }
            }
        }
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: theme.spacing.l),
            count: horizontalSizeClass == .regular ? 2 : 1
        )
    }

    // MARK: - Running one

    /// Every entry in the catalog, in the catalog's order. No `default`: a ninth
    /// game must fail to compile here rather than quietly become unreachable.
    @ViewBuilder
    private func runner(for id: MiniGameID) -> some View {
        switch id {
        case .bubbleWash:
            BubbleWashRunner(onLeave: leaveGame, onFinish: finishGame)
        case .pottyPath:
            PottyPathRunner(onLeave: leaveGame, onFinish: finishGame)
        case .bathroomMatch:
            BathroomMatchRunner(onLeave: leaveGame, onFinish: finishGame)
        case .flySnack:
            FlySnackRunner(onLeave: leaveGame, onFinish: finishGame)
        case .mudOff:
            MudOffRunner(onLeave: leaveGame, onFinish: finishGame)
        case .bodySignal:
            BodySignalRunner(onLeave: leaveGame, onFinish: finishGame)
        case .flushWave:
            FlushWaveRunner(onLeave: leaveGame, onFinish: finishGame)
        case .pottyOrder:
            PottyOrderRunner(onLeave: leaveGame, onFinish: finishGame)
        }
    }

    /// Backing out of a game the child never finished. No star, no comment, no
    /// "are you sure" — leaving is a legitimate thing to do.
    private func leaveGame() {
        playing = nil
    }

    /// A finished round, reported whole.
    ///
    /// The result is built from the *session* rather than from the catalog
    /// entry, which is what keeps `MiniGameRoundResult.handOffStep` alive: a
    /// round rebuilt from the game alone would know Fly Snack *can* hand off
    /// and not whether this round did.
    private func finishGame(_ result: MiniGameRoundResult) {
        onFinishRound(result)
        playing = nil
    }
}

/// One game on the chooser. All eight are drawn by this one view, at one size.
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
// One tiny view per game, each owning its own session. Eight of these rather
// than one generic runner because `@State` has to be declared against a
// concrete type — and because eight ten-line structs are cheaper to read, and
// far cheaper to get wrong, than the abstraction that would remove them.
//
// They differ in exactly two places, and both differences come from the game's
// `MiniGameCompletion`:
//
// * a `.whenChildIsDone` game has no ending of its own, so tapping "All done"
//   *is* how it finishes and it earns the same star as a board that ran itself
//   out;
// * a `.handOffToRoutine` game tells the host so, and hands the caller a result
//   carrying the routine step to open next.

private struct BubbleWashRunner: View {
    @State private var session = BubbleWashSession()
    let onLeave: () -> Void
    let onFinish: (MiniGameRoundResult) -> Void

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: { session.isFinished ? onFinish(MiniGameRoundResult(session: session)) : onLeave() }
        ) {
            BubbleWashGameView(session: session)
        }
    }
}

private struct PottyPathRunner: View {
    @State private var session = PottyPathSession()
    let onLeave: () -> Void
    let onFinish: (MiniGameRoundResult) -> Void

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: { session.isFinished ? onFinish(MiniGameRoundResult(session: session)) : onLeave() }
        ) {
            PottyPathGameView(session: session)
        }
    }
}

private struct BathroomMatchRunner: View {
    @State private var session = BathroomMatchSession()
    let onLeave: () -> Void
    let onFinish: (MiniGameRoundResult) -> Void

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            // Bathroom Match has no ending of its own, so tapping "All done"
            // *is* how it finishes — and it earns the same star as a board that
            // ran itself out.
            onLeave: { onFinish(MiniGameRoundResult(session: session)) }
        ) {
            BathroomMatchGameView(session: session)
        }
    }
}

private struct FlySnackRunner: View {
    @State private var session = FlySnackSession()
    let onLeave: () -> Void
    let onFinish: (MiniGameRoundResult) -> Void

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            // The one game that ends somewhere other than here. The host says
            // where it is going; the result carries the step to open.
            handsOffToRoutine: session.reachedHandOff,
            onPlayAgain: { session.restart() },
            onLeave: { session.isFinished ? onFinish(MiniGameRoundResult(session: session)) : onLeave() }
        ) {
            FlySnackGameView(session: session)
        }
    }
}

private struct MudOffRunner: View {
    @State private var session = MudOffSession()
    let onLeave: () -> Void
    let onFinish: (MiniGameRoundResult) -> Void

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: { session.isFinished ? onFinish(MiniGameRoundResult(session: session)) : onLeave() }
        ) {
            MudOffGameView(session: session)
        }
    }
}

private struct BodySignalRunner: View {
    @State private var session = BodySignalSession()
    let onLeave: () -> Void
    let onFinish: (MiniGameRoundResult) -> Void

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: { session.isFinished ? onFinish(MiniGameRoundResult(session: session)) : onLeave() }
        ) {
            BodySignalGameView(session: session)
        }
    }
}

private struct FlushWaveRunner: View {
    @State private var session = FlushWaveSession()
    let onLeave: () -> Void
    let onFinish: (MiniGameRoundResult) -> Void

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: { session.isFinished ? onFinish(MiniGameRoundResult(session: session)) : onLeave() }
        ) {
            FlushWaveGameView(session: session)
        }
    }
}

private struct PottyOrderRunner: View {
    @State private var session = PottyOrderSession()
    let onLeave: () -> Void
    let onFinish: (MiniGameRoundResult) -> Void

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: { session.isFinished ? onFinish(MiniGameRoundResult(session: session)) : onLeave() }
        ) {
            PottyOrderGameView(session: session)
        }
    }
}

#Preview("Games · chooser") {
    GamesScreen(onFinishRound: { _ in }, onLeave: {})
        .hopThemedRoot()
}

#Preview("Games · chooser AX3") {
    GamesScreen(onFinishRound: { _ in }, onLeave: {})
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
