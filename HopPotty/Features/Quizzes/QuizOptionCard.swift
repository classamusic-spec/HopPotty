import SwiftUI
import HopPottyCore

/// One picture answer, drawn as large as the screen will let it be.
///
/// ## The picture is the answer
///
/// A three-year-old cannot read "front to back", so the illustration carries the
/// whole meaning and `QuizOption.label` exists for VoiceOver and for the
/// caregiver sitting alongside — which is why the label is on the button rather
/// than printed under it, and why the drawing itself is hidden from assistive
/// technology as a duplicate of it.
///
/// ## Giant, and that is a requirement rather than a preference
///
/// The tile is square-ish, at least 132pt on a side, and the picture is inset by
/// a hair rather than by a margin: a quiz answer is the primary action of the
/// screen it is on, and three small cards with an icon in the middle of each is
/// the shape this screen must not take (§32). An earlier version padded the
/// drawing by `spacing.l` inside a 120pt box, which left a 72pt picture — a
/// thumbnail, not a choice.
///
/// ## Nothing here marks anyone wrong
///
/// Nothing marks the correct answer before it is found, nothing marks the others
/// afterwards, and no card is ever disabled: the board a child sees after a
/// redirect is the board they saw before it. A card that is picked and is not
/// the one being taught gives one gentle bounce and nothing else — no red, no
/// cross, no shake, no sound.
struct QuizOptionCard: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool
    @State private var isPressed = false

    let option: QuizOption
    /// True once this card turned out to be the one the question teaches.
    /// Nothing marks a card that did not.
    let isAffirmed: Bool
    /// True for one beat after this card was picked and turned out not to be the
    /// one being taught. It bounces, gently, and says nothing.
    var isNudging: Bool = false
    let action: () -> Void

    /// Comfortably past `HopHitTarget.childPrimary` (96pt).
    private var minimumSide: CGFloat { max(theme.hitTarget.childPrimary, 132) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                HopArtwork(option.illustration)
                    .padding(theme.spacing.s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isAffirmed {
                    // Found, not "correct": a check mark on the picture the
                    // question was about. The other two get no mark at all.
                    HopGlyphView(.check, size: 30)
                        .foregroundStyle(theme.color.success)
                        .padding(theme.spacing.m)
                }
            }
            .frame(minWidth: minimumSide, minHeight: minimumSide)
            .background {
                RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                    .fill(theme.color.surfaceElevated)
            }
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                    .strokeBorder(
                        isAffirmed ? theme.color.success : theme.color.divider,
                        lineWidth: isAffirmed ? 4 : (theme.isHighContrast ? 2 : 1)
                    )
            }
        }
        .buttonStyle(.plain)
        .modifier(theme.elevation(.resting))
        // The nudge and the press are the same small scale in opposite
        // directions, so a bounce reads as "that one moved" rather than as an
        // error state. `hopAnimation` is what makes both stop under Reduce
        // Motion while the card stays exactly where it was.
        .scaleEffect(isPressed ? 0.955 : (isNudging ? 1.045 : 1))
        .hopAnimation(.childTap, value: isPressed)
        .hopAnimation(.childTap, value: isNudging)
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: theme.radius.xl)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.label.localized)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Quiz option cards") {
    let question = QuizContent.washSoap
    HStack(spacing: 12) {
        ForEach(question.options) { option in
            QuizOptionCard(
                option: option,
                isAffirmed: option.id == question.correctOptionID,
                action: {}
            )
        }
    }
    .padding()
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Quiz option cards · high contrast") {
    HStack(spacing: 12) {
        ForEach(QuizContent.wipeDirection.options) { option in
            QuizOptionCard(option: option, isAffirmed: false, action: {})
        }
    }
    .padding()
    .hopBackground()
    .hopThemedRoot(appearance: .lightHighContrast)
}
