import SwiftUI
import HopPottyCore

/// One picture answer.
///
/// The picture *is* the answer. A three-year-old cannot read "front to back", so
/// the illustration carries the whole meaning and `QuizOption.label` exists for
/// VoiceOver and for the caregiver sitting alongside — which is why the label is
/// on the button rather than under it, and why the drawing itself is hidden from
/// assistive technology as a duplicate of it.
///
/// All three cards are this one view at one size. Nothing marks the correct
/// answer before it is found, nothing marks the others afterwards, and no card
/// is ever disabled: the board a child sees after a redirect is the board they
/// saw before it.
struct QuizOptionCard: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool
    @State private var isPressed = false

    let option: QuizOption
    /// True once this card turned out to be the one the question teaches.
    /// Nothing marks a card that did not.
    let isAffirmed: Bool
    let action: () -> Void

    /// Comfortably past `HopHitTarget.childPrimary` (96pt): a picture answer is
    /// the primary action of the screen it is on.
    private var minimumSide: CGFloat { max(theme.hitTarget.childPrimary, 120) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                HopArtwork(option.illustration)
                    .padding(theme.spacing.l)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: minimumSide)

                if isAffirmed {
                    // Found, not "correct": a check mark on the picture the
                    // question was about. The other two get no mark at all.
                    HopGlyphView(.check, size: 26)
                        .foregroundStyle(theme.color.success)
                        .padding(theme.spacing.m)
                }
            }
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
        .scaleEffect(isPressed ? 0.955 : 1)
        .hopAnimation(.childTap, value: isPressed)
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
    return HStack(spacing: 12) {
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
