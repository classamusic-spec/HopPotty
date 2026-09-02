import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

/// The three answers to "How did it go?".
///
/// ## Why this file is one loop and no branches
///
/// "I tried" is not the consolation option. It is the option the product is
/// *about*: a child who sat down and nothing happened did the entire skill the
/// app teaches, and rewarding them less would teach them that their body's
/// timetable is a thing they can be bad at.
///
/// Keeping that true in code, not just in a design review, is why the three
/// choices are built from one array by one view with no per-case geometry:
///
/// * one `RoutineOutcomeChoice` view draws all three — there is no second,
///   quieter style for the third one to fall into;
/// * every card takes the same width (`maxWidth: .infinity` inside an equal
///   spacing stack), the same minimum height, the same corner radius, the same
///   elevation, the same glyph diameter and the same text style;
/// * the only per-case values are the glyph, the tint and the words, and each
///   is a *peer* difference — three kinds of thing, not three grades;
/// * they all call `recordOutcome(_:)`, which maps to one `RewardReason` and
///   one star (`RewardService.reason(for:)`).
///
/// Adding an `if kind == .tried` to this file is how the regression would
/// happen, so there is nowhere for one to go.
struct RoutineOutcomeChoices: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let onChoose: (PottyEventKind) -> Void

    /// The three answers, in the order they are drawn. The row on screen is
    /// built from this, and so is the only thing that varies between the three
    /// anywhere in the app — see ``hopDrift(for:)``.
    ///
    /// **"I tried" is first.** Every card is the same size, the same shape, the
    /// same type and the same elevation, so first is not bigger — but it is
    /// where a two-year-old's hand lands, and the option this product is *about*
    /// should not be the one they have to read past. `Docs/ChildSafety.md` asks
    /// for equal; the brief asks for equal or primary; this is both.
    static let order: [PottyEventKind] = [.tried, .pee, .poop]

    /// The answers, in reading order. Peers in a list, not a ranking.
    private var choices: [Choice] {
        [
            Choice(kind: .tried, copy: HopCopy.routine.outcomeNothing, tint: theme.color.eventTried),
            Choice(kind: .pee, copy: HopCopy.routine.outcomePee, tint: theme.color.eventPee),
            Choice(kind: .poop, copy: HopCopy.routine.outcomePoop, tint: theme.color.eventPoop),
        ]
    }

    // MARK: - How Hop celebrates an answer
    //
    // `Docs/ChildSafety.md` §2: the star is for going and trying, and "I tried"
    // is not the consolation option. So Hop's celebration has to be the same
    // *size* for all three — same number of hops, same height, same squash,
    // same duration — or the animation would say what the reward system is
    // built never to say.
    //
    // That is enforced here by construction rather than by a review comment.
    // The magnitude lives in two constants that take no arguments. An outcome
    // reaches the hop through exactly one door, `HopJump.drifting(_:)`, which is
    // the only method on `HopJump` that cannot change how big or how long it
    // is. There is nowhere in this file for an `if kind == .tried` to go.

    /// The hop the instant an answer is tapped, on the step the child lands on.
    private static let acknowledgementBase = HopJump(hops: 1)
    /// The hop in the celebration at the end of the routine.
    private static let celebrationBase = HopJump(hops: 2)

    /// Which way Hop leans when he hops, for an answer.
    ///
    /// A *spatial echo of where the child's finger was*, never a grade: the
    /// left card hops left, the middle card hops straight up, the right card
    /// hops right. `inPlace` is the hop that goes straight up, not a smaller
    /// one — every direction is the same height and the same length — so no
    /// reading of this maps the three answers onto a scale.
    static func hopDrift(for kind: PottyEventKind?) -> HopJumpDrift {
        let drifts: [HopJumpDrift] = [.left, .inPlace, .right]
        guard let kind, let index = order.firstIndex(of: kind), index < drifts.count else {
            return .inPlace
        }
        return drifts[index]
    }

    /// Hop's immediate "I saw that" hop. Identical for all three answers.
    static func acknowledgementHop(for kind: PottyEventKind?) -> HopJump {
        acknowledgementBase.drifting(hopDrift(for: kind))
    }

    /// Hop's celebration hop at the end of the routine. Identical for all three
    /// answers.
    static func celebrationHop(for kind: PottyEventKind?) -> HopJump {
        celebrationBase.drifting(hopDrift(for: kind))
    }

    /// Three side by side on a phone was a row of narrow cards with the words
    /// wrapped inside them. On the question's own screen there is room to make
    /// each answer a full-width object with its picture and its word on one
    /// line, which is easier to hit and easier to read aloud — so a phone
    /// stacks, and only a regular-width screen puts them in a row.
    private var isStacked: Bool {
        horizontalSizeClass != .regular || dynamicTypeSize >= .accessibility2
    }

    var body: some View {
        VStack(spacing: theme.spacing.l) {
            Text(HopCopy.routine.outcomeQuestion.localized)
                .hopTextStyle(.childTitle)
                .foregroundStyle(theme.color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            layout
        }
        .frame(maxWidth: ChildStage.contentWidth)
        // One container, so VoiceOver reads the question and then the three
        // answers as a single group in the order they are drawn.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(HopCopy.routine.outcomeQuestion.localized)
    }

    @ViewBuilder
    private var layout: some View {
        if isStacked {
            VStack(spacing: theme.spacing.m) {
                ForEach(choices) { choice in
                    RoutineOutcomeChoice(choice: choice, isStacked: true) { onChoose(choice.kind) }
                }
            }
        } else {
            HStack(spacing: theme.spacing.m) {
                ForEach(choices) { choice in
                    RoutineOutcomeChoice(choice: choice, isStacked: false) { onChoose(choice.kind) }
                }
            }
        }
    }

    struct Choice: Identifiable {
        let kind: PottyEventKind
        let copy: HopCopyEntry
        let tint: Color

        var id: String { kind.rawValue }
        var glyph: HopGlyph { HopGlyph(kind) }
    }
}

/// One answer. The only view that draws an outcome, so all three are the same
/// object with different contents.
private struct RoutineOutcomeChoice: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var isFocused: Bool
    @State private var isPressed = false

    let choice: RoutineOutcomeChoices.Choice
    let isStacked: Bool
    let action: () -> Void

    /// Well above `HopHitTarget.childPrimary` (96pt): these are the primary
    /// actions of the whole routine and a two-year-old aims with a whole hand.
    private var minimumHeight: CGFloat {
        isStacked ? 112 : 168
    }

    private var glyphDiameter: CGFloat {
        isStacked ? 70 : 76
    }

    private var cornerRadius: CGFloat {
        isStacked ? theme.radius.hero : theme.radius.xl
    }

    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(minHeight: minimumHeight)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(HopColors.wash(choice.tint, isDark: theme.isDark))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                // A visible edge in every appearance: the wash alone is not a
                // boundary at increased contrast, and the three cards have to
                // read as three equal objects rather than one tinted band.
                .strokeBorder(choice.tint.opacity(theme.isHighContrast ? 0.95 : 0.45), lineWidth: theme.isHighContrast ? 2.5 : 1.5)
        }
        .modifier(theme.elevation(.resting))
        .scaleEffect(isPressed ? 0.955 : 1)
        .hopAnimation(.childTap, value: isPressed)
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: cornerRadius)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(choice.copy.localized)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var content: some View {
        if isStacked {
            HStack(spacing: theme.spacing.xl) {
                HopGlyphBadge(choice.glyph, tint: choice.tint, diameter: glyphDiameter)
                Text(choice.copy.localized)
                    .hopTextStyle(.buttonLarge)
                    .foregroundStyle(theme.color.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, theme.spacing.l)
            .padding(.horizontal, theme.spacing.xl)
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: theme.spacing.s) {
                HopGlyphBadge(choice.glyph, tint: choice.tint, diameter: glyphDiameter)
                Text(choice.copy.localized)
                    .hopTextStyle(.buttonLarge)
                    .foregroundStyle(theme.color.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, theme.spacing.l)
            .padding(.horizontal, theme.spacing.s)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview("Outcome choices · three equal answers") {
    RoutineOutcomeChoices { _ in }
        .padding()
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Outcome choices · AX3 stacked") {
    ScrollView {
        RoutineOutcomeChoices { _ in }
            .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Outcome choices · high contrast dark") {
    RoutineOutcomeChoices { _ in }
        .padding()
        .hopBackground()
        .hopThemedRoot(appearance: .darkHighContrast)
}
