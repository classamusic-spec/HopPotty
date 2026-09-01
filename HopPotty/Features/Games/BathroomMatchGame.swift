import SwiftUI
import HopPottyCore

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
        .accessibilityLabel(session.game.childDescription.localized)
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
        .accessibilityLabel(card.label.localized)
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
            content.accessibilityValue(GameCopy.matched.localized)
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
    var reduceMotion: Bool? = nil

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

#Preview("Bathroom Match · Reduce Motion") {
    BathroomMatchHostPreview(session: BathroomMatchSession(), reduceMotion: true)
}
