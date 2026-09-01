import SwiftUI
import HopPottyCore

/// The chrome every mini-game sits inside.
///
/// It owns the four things the games must all agree about, so that no
/// individual game can quietly disagree:
///
/// * **the way out is always there** — "All done" is on screen from the first
///   frame of every game, at `HopHitTarget.childMinimum`, in the same corner;
/// * **there is no clock** — nothing here counts down, counts up, or is drawn
///   from elapsed time. `MiniGame.targetDuration` is a caregiver-facing
///   estimate on the game list and never reaches the child's screen;
/// * **there is no score** — `MiniGameSession.completion` draws quiet dots and
///   is never rendered as a number;
/// * **every ending is the same ending** — one cheer, one star, whether the
///   board finished itself or the child said when.
struct GameHostView<Board: View>: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let game: MiniGame
    let isFinished: Bool
    let completion: Double
    let onPlayAgain: () -> Void
    let onLeave: () -> Void
    @ViewBuilder var board: () -> Board

    var body: some View {
        VStack(spacing: theme.spacing.l) {
            chrome
            boardArea
        }
        .hopBackground(.secondary)
        .overlay { if isFinished { finishedOverlay } }
    }

    // MARK: - Chrome

    private var chrome: some View {
        HStack(alignment: .center, spacing: theme.spacing.m) {
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(game.title.localized)
                    .hopTextStyle(.parentTitle)
                    .foregroundStyle(theme.color.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text(game.childDescription.localized)
                    .hopTextStyle(.parentCallout)
                    .foregroundStyle(theme.color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: theme.spacing.s)

            GameProgressDots(completion: completion)

            HopIconButton(
                systemImage: "checkmark",
                accessibilityLabel: HopCopy.games.doneButton.localized,
                tint: theme.color.brandAction,
                minimumTarget: theme.hitTarget.child,
                action: onLeave
            )
        }
        .hopPageMargins()
        .padding(.top, theme.spacing.m)
    }

    /// The board gets the room. On iPad it gets more room, not a bigger version
    /// of the phone board: the play area grows, the pieces stay hand-sized.
    private var boardArea: some View {
        board()
            .frame(maxWidth: horizontalSizeClass == .regular ? 900 : .infinity, maxHeight: .infinity)
            .frame(maxWidth: .infinity)
            .hopPageMargins()
            .padding(.bottom, theme.spacing.xl)
    }

    // MARK: - Ending

    private var finishedOverlay: some View {
        ZStack {
            theme.color.scrim.ignoresSafeArea()

            VStack(spacing: theme.spacing.xl) {
                HopCharacterStage(pose: .cheer, size: ChildStage.characterSize(for: horizontalSizeClass))
                    .accessibilityHidden(true)

                Text(HopCopy.games.finished.localized)
                    .hopTextStyle(.celebration)
                    .foregroundStyle(theme.color.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                HopSpokenLine(HopVoice.shared.gameFinished)

                HopPrimaryButton(HopCopy.games.doneButton.localized, icon: "checkmark", size: .childPrimary, action: onLeave)
                HopPrimaryButton(HopCopy.games.againButton.localized, icon: "arrow.clockwise", size: .child, action: onPlayAgain)
            }
            .padding(theme.spacing.xxxl)
            .frame(maxWidth: ChildStage.contentWidth)
            .background {
                RoundedRectangle(cornerRadius: theme.radius.hero, style: .continuous)
                    .fill(theme.color.surfaceElevated)
            }
            .modifier(theme.elevation(.floating))
            .hopPageMargins()
        }
        .hopTransition(.childCelebrate)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

/// How much of the board is done, as dots.
///
/// Dots rather than a number, a bar or a percentage: a pre-reader reads "some
/// left" from three filled circles and nothing at all from "60%". It is
/// decorative for assistive technology — the board itself announces what
/// changed, and a running tally read aloud after every tap would be a score.
private struct GameProgressDots: View {
    @Environment(\.hopTheme) private var theme

    let completion: Double

    private static let count = 5

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            ForEach(0..<Self.count, id: \.self) { index in
                Circle()
                    .fill(isFilled(index) ? theme.color.brandAction : theme.color.surfaceSunken)
                    .frame(width: 10, height: 10)
            }
        }
        .hopAnimation(.childTap, value: completion)
        .accessibilityHidden(true)
    }

    private func isFilled(_ index: Int) -> Bool {
        Double(index + 1) / Double(Self.count) <= min(1, max(0, completion)) + 0.0001
    }
}

#Preview("Game host · playing") {
    GameHostView(
        game: MiniGameCatalog.bubbleWash,
        isFinished: false,
        completion: 0.4,
        onPlayAgain: {},
        onLeave: {}
    ) {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(.thinMaterial)
    }
    .hopThemedRoot()
}

#Preview("Game host · finished") {
    GameHostView(
        game: MiniGameCatalog.pottyPath,
        isFinished: true,
        completion: 1,
        onPlayAgain: {},
        onLeave: {}
    ) {
        Color.clear
    }
    .hopThemedRoot()
}
