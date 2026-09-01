import SwiftUI
import Observation
import HopPottyCore

/// Bathroom Match: find the two that go together.
///
/// Soap goes with washing hands, paper goes with wiping, towel goes with
/// drying — the three pairings the routine has already taught, so the game is
/// recognition rather than instruction.
///
/// The calm one of the three. `MiniGameCompletion.whenChildIsDone` means it has
/// no ending of its own: when the last pair lands the board quietly offers
/// another set, and the round ends when the child taps "All done". There is
/// nothing to get wrong — two cards that do not go together simply let go of
/// each other, with no sound, no shake and nothing counted.
@MainActor
@Observable
final class BathroomMatchSession: MiniGameSession {

    /// One side of a pair on the board.
    struct Card: Identifiable, Hashable {
        enum Side: Hashable { case tool, use }

        let pairID: String
        let side: Side
        let illustration: HopIllustrationKey
        let label: HopCopyEntry
        var isMatched = false

        var id: String { pairID + "." + (side == .tool ? "tool" : "use") }
    }

    let game = MiniGameCatalog.bathroomMatch

    private(set) var tools: [Card] = []
    private(set) var uses: [Card] = []
    /// The card the child has picked up, if any. One at a time, so there is no
    /// state where three things are half-selected.
    private(set) var selected: Card?
    private(set) var isFinished = false
    /// How many boards the child has cleared. Drives nothing but the reshuffle.
    private(set) var boardsCleared = 0

    private var shuffleSeed: UInt64

    init(seed: UInt64 = 424_242) {
        shuffleSeed = seed
        deal()
    }

    var completion: Double {
        let matched = tools.filter(\.isMatched).count
        return Double(matched) / Double(max(1, tools.count))
    }

    // MARK: - Playing

    /// Picks a card up, or tries it against the one already held.
    func choose(_ card: Card) {
        guard !card.isMatched else { return }

        guard let held = selected else {
            selected = card
            return
        }

        // Tapping the same card again puts it back down. A child changing their
        // mind is not a wrong answer.
        if held.id == card.id {
            selected = nil
            return
        }

        if held.side != card.side, held.pairID == card.pairID {
            match(held.pairID)
        }
        // Anything else: both cards are simply released. Nothing is recorded,
        // nothing is said, and the same two can be tried again immediately.
        selected = nil
    }

    private func match(_ pairID: String) {
        for index in tools.indices where tools[index].pairID == pairID { tools[index].isMatched = true }
        for index in uses.indices where uses[index].pairID == pairID { uses[index].isMatched = true }

        if tools.allSatisfy(\.isMatched) {
            boardsCleared += 1
            // A fresh board rather than an ending: this game finishes when the
            // child says so, and taking the toy away mid-play is not a reward.
            shuffleSeed = shuffleSeed &+ 7_919
            deal()
        }
    }

    func restart() {
        boardsCleared = 0
        isFinished = false
        deal()
    }

    func finish() { isFinished = true }

    private func deal() {
        selected = nil
        var shuffler = GameShuffler(seed: shuffleSeed)
        let pairs = GameCopy.matchPairs
        tools = shuffler.shuffled(pairs).map {
            Card(pairID: $0.id, side: .tool, illustration: $0.toolIllustration, label: $0.toolLabel)
        }
        uses = shuffler.shuffled(pairs).map {
            Card(pairID: $0.id, side: .use, illustration: $0.useIllustration, label: $0.useLabel)
        }
    }
}

/// Two columns of pictures.
struct BathroomMatchGameView: View {
    @Environment(\.hopTheme) private var theme

    let session: BathroomMatchSession

    var body: some View {
        HStack(alignment: .center, spacing: theme.spacing.xl) {
            column(session.tools)
            column(session.uses)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(theme.spacing.l)
        .background {
            RoundedRectangle(cornerRadius: theme.radius.hero, style: .continuous)
                .fill(HopColors.wash(theme.color.brandSecondary, isDark: theme.isDark))
        }
        .hopAnimation(.childArrive, value: session.boardsCleared)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(session.game.childDescription.value)
    }

    private func column(_ cards: [BathroomMatchSession.Card]) -> some View {
        VStack(spacing: theme.spacing.m) {
            ForEach(cards) { card in
                MatchCardView(
                    card: card,
                    isSelected: session.selected?.id == card.id,
                    onTap: { session.choose(card) }
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// One picture card.
private struct MatchCardView: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    let card: BathroomMatchSession.Card
    let isSelected: Bool
    let onTap: () -> Void

    /// State is drawn three ways — border weight, a check mark and the
    /// accessibility value — so no part of it rests on colour alone.
    private var borderColor: Color {
        if card.isMatched { return theme.color.success }
        return isSelected ? theme.color.brandAction : theme.color.divider
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                HopArtwork(card.illustration)
                    .padding(theme.spacing.m)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: theme.hitTarget.childPrimary)

                if card.isMatched {
                    HopGlyphView(.check, size: 22)
                        .foregroundStyle(theme.color.success)
                        .padding(theme.spacing.s)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                    .fill(theme.color.surfaceElevated)
            }
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected || card.isMatched ? 4 : 1)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.04 : 1)
        .hopAnimation(.childTap, value: isSelected)
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: theme.radius.xl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.label.value)
        .modifier(MatchedStateValue(isMatched: card.isMatched))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Adds the matched announcement only when there is one to make, rather than
/// attaching an empty value to every card.
private struct MatchedStateValue: ViewModifier {
    let isMatched: Bool

    func body(content: Content) -> some View {
        if isMatched {
            content.accessibilityValue(GameCopy.matched.value)
        } else {
            content
        }
    }
}

#Preview("Bathroom Match · fresh board") {
    BathroomMatchHostPreview(session: BathroomMatchSession())
}

#Preview("Bathroom Match · one pair found") {
    BathroomMatchHostPreview(session: {
        let session = BathroomMatchSession()
        if let tool = session.tools.first, let use = session.uses.first(where: { $0.pairID == tool.pairID }) {
            session.choose(tool)
            session.choose(use)
        }
        return session
    }())
}

#Preview("Bathroom Match · AX3") {
    BathroomMatchHostPreview(session: BathroomMatchSession())
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Bathroom Match · iPad") {
    BathroomMatchHostPreview(session: BathroomMatchSession())
        .frame(width: 1024, height: 768)
}

private struct BathroomMatchHostPreview: View {
    @State var session: BathroomMatchSession
    var reduceMotion: Bool?

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: {}
        ) {
            BathroomMatchGameView(session: session)
        }
        .hopThemedRoot(reduceMotion: reduceMotion)
    }
}
