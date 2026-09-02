import SwiftUI
import HopPottyCore

/// The child's game chooser, and the runner that plays one.
///
/// Navigation is one step deep and it is a swap, not a stack: pictures, tap
/// one, play it, come back. There is no lock icon, no "coming soon" and no
/// ordering that implies one game is the reward for another — the catalog's own
/// order is the order here, and every entry in it is offered.
///
/// ## Eight, and all eight are the offer
///
/// There is no featured row, no "more games" section, no disclosure and no
/// second tier. Every game gets the same tile at the same size in the same grid,
/// because a child who wants Flush and Wave is not choosing a lesser thing than
/// a child who wants Bubble Wash — and a chooser that ranked them would teach
/// exactly that. What holding eight well actually needs is not fewer of them but
/// *bigger pictures*: the tile leads with the game's own illustration, at the
/// aspect it was drawn, so a child who cannot read picks by looking. Two columns
/// on a phone, three on an iPad, and it scrolls when it has to.
///
/// Whether games are offered at all is `AppSettings.miniGamesEnabled`, which the
/// caller checks before presenting this screen — the child-facing surface has no
/// business drawing a door it then refuses to open.
struct GamesScreen: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

    /// Two columns on a phone, three on an iPad. The tile is the same tile either
    /// way: an iPad gets more games in view, not bigger ones.
    ///
    /// At an accessibility type size the titles need the whole width, so the
    /// grid collapses to one column rather than letting eight names wrap to four
    /// lines each in a 160pt box.
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
            count: columnCount
        )
    }

    private var columnCount: Int {
        if dynamicTypeSize >= .accessibility1 { return 1 }
        return horizontalSizeClass == .regular ? 3 : 2
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
///
/// The tile *is* the picture: the illustration fills it at the 4:3 it was drawn
/// at, and the game's name sits over the bottom of it on a scrim. A
/// three-year-old chooses by recognising the bathroom, the pond or the muddy
/// hands, so nothing is allowed to shrink the picture — which is what a caption
/// block under it does, and what the one-line description used to do.
///
/// The description is still there; it is the accessibility hint. A caregiver
/// reading the list with VoiceOver hears "Bubble Wash. Pop every bubble to get
/// your hands sparkly clean." — the same words, at the moment they are useful,
/// rather than as four lines of small type under every one of eight tiles.
///
/// Nothing on the tile ranks it. No badge, no "new", no order number, no
/// progress, no best score — there is no score anywhere in this app, and a
/// chooser is the easiest place to accidentally invent one.
private struct GameChoiceCard: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    let game: MiniGame
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            GameChoiceTile(game: game)
        }
        .buttonStyle(HopSurfaceButtonStyle())
        .modifier(theme.elevation(.resting))
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: theme.radius.xl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(game.title.localized)
        .accessibilityHint(game.childDescription.localized)
        .accessibilityAddTraits(.isButton)
    }
}

/// The tile's face.
///
/// A view of its own so it can read ``EnvironmentValues/hopIsPressed``, which
/// `HopSurfaceButtonStyle` publishes into the *label's* environment — a press
/// scale read beside the `.buttonStyle` would be reading a value that never
/// changes.
private struct GameChoiceTile: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.hopIsPressed) private var isPressed

    let game: MiniGame

    var body: some View {
        HopArtwork(game.illustration)
            .aspectRatio(4.0 / 3.0, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(minHeight: theme.hitTarget.childPrimary)
            .clipped()
            .overlay(alignment: .bottomLeading) { nameplate }
            .background {
                RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                    .fill(theme.color.surfaceElevated)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                    .strokeBorder(
                        theme.color.divider.opacity(theme.isHighContrast ? 1 : 0.35),
                        lineWidth: theme.isHighContrast ? 1.5 : 0.75
                    )
            }
            .scaleEffect(isPressed ? 0.975 : 1)
            .hopAnimation(.childTap, value: isPressed)
    }

    /// The name, over the bottom of the picture.
    ///
    /// The scrim is `HopSemanticPalette/scrim` rather than a hand-picked black,
    /// which is the one thing that keeps the name legible over eight different
    /// illustrations — a bright pond, a white bathroom, a wooden hallway —
    /// without a per-tile decision. It fades to nothing over the top half, so it
    /// darkens the caption and not the picture.
    private var nameplate: some View {
        Text(game.title.localized)
            .hopTextStyle(.buttonLarge)
            .foregroundStyle(theme.color.textOnBrand)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, theme.spacing.l)
            .padding(.bottom, theme.spacing.m)
            .padding(.top, theme.spacing.xxl)
            .background {
                LinearGradient(
                    stops: [
                        .init(color: scrim(0), location: 0),
                        .init(color: scrim(0.42), location: 0.55),
                        .init(color: scrim(0.72), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }

    private func scrim(_ opacity: Double) -> Color {
        Color(theme.color.values.scrim.opacity(opacity))
    }
}

// MARK: - Runners
//
// One tiny view per game, each owning its own session. Eight of these rather
// than one generic runner because `@State` has to be declared against a
// concrete type — and because eight ten-line structs are cheaper to read, and
// far cheaper to get wrong, than the abstraction that would remove them.
//
// Seven of them differ in exactly two places, and both differences come from the
// game's `MiniGameCompletion`:
//
// * a `.whenChildIsDone` game has no ending of its own, so tapping "All done"
//   *is* how it finishes and it earns the same star as a board that ran itself
//   out;
// * a `.handOffToRoutine` game tells the host so, and hands the caller a result
//   carrying the routine step to open next.
//
// Bubble Wash is the eighth, and it does not use `GameHostView` at all.

/// Bubble Wash, without game chrome.
///
/// Hand washing is not a scored round. It is the last step of going to the
/// toilet, and §23 rules out the two things `GameHostView` would put around it:
/// a row of progress dots, and a "Play again" button on the ending. Twenty
/// seconds of scrubbing that offers itself again the moment it finishes is a
/// loop, and dots that fill up turn a rinse into a level.
///
/// So this runner presents ``BubbleWashScreen`` exactly as `PottyRoutineView`
/// does — the screen brings its own line, runs its own beats and finishes
/// itself — and adds the one piece of chrome that is *not* negotiable: the way
/// out. It is the same control in the same corner as every other game's, so
/// leaving works the same way wherever a child is. `GameHostView` is untouched;
/// the other seven still want it.
private struct BubbleWashRunner: View {
    @Environment(\.hopTheme) private var theme
    let onLeave: () -> Void
    let onFinish: (MiniGameRoundResult) -> Void

    var body: some View {
        BubbleWashScreen(
            // The screen finishes when the hands are clean, and that ending
            // earns the same one star every other game earns.
            onFinish: { onFinish(MiniGameRoundResult(game: MiniGameCatalog.bubbleWash)) }
        )
        .overlay(alignment: .topTrailing) { leaveButton }
    }

    /// Leaving partway through. No star, no comment, no "are you sure" — and no
    /// `onAskForHelp`, because the game list is already inside Child Space and
    /// the grown-up door is on the hub behind the gate.
    private var leaveButton: some View {
        HopIconButton(
            systemImage: "checkmark",
            accessibilityLabel: HopCopy.games.doneButton.localized,
            tint: theme.color.brandAction,
            minimumTarget: theme.hitTarget.child,
            action: onLeave
        )
        .hopPageMargins()
        .padding(.top, theme.spacing.m)
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
