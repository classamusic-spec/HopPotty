import SwiftUI
import Observation
import HopPottyCore
import HopPottyDesignTokens

/// Sequences the celebration and hands control back.
///
/// It exists mainly to enforce one number: the whole thing is over within
/// ``HopMotion/celebrationMaxDuration``. The product's premise is a *short*
/// interruption, so a reward animation that outlasts the bathroom trip is
/// working against the thing it is rewarding.
@MainActor
@Observable
final class HopCelebrationSequencer {
    enum Beat: Int, Comparable {
        case waiting, hopArrives, starsArrive, unlockArrives, done

        static func < (lhs: Beat, rhs: Beat) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private(set) var beat: Beat = .waiting

    /// Runs the sequence. Under Reduce Motion every beat lands at once and the
    /// screen simply appears, held for long enough to read.
    func run(reduceMotion: Bool, hasUnlock: Bool) async {
        guard !reduceMotion else {
            beat = .done
            try? await Task.sleep(for: .seconds(HopMotion.celebrationMaxDuration * 0.6))
            return
        }

        // Absolute offsets from the start, not gaps, so the last beat is
        // pinned to the ceiling however the earlier ones are retuned.
        let beats: [(Beat, Double)] = [
            (.hopArrives, 0.05),
            (.starsArrive, 0.45),
            (.unlockArrives, hasUnlock ? 0.95 : 0.45),
            (.done, HopMotion.celebrationMaxDuration - 0.4),
        ]

        var elapsed: Double = 0
        for (next, at) in beats {
            let delay = max(0, at - elapsed)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            elapsed = at
            beat = next
        }
        try? await Task.sleep(for: .seconds(0.4))
    }
}

/// The awarded-a-star moment.
///
/// Calm on purpose: no confetti storm, no coin shower, no escalating fanfare.
/// Hop cheers, the stars settle in, and if the pond gained something it is
/// shown once. Nothing here is randomised and nothing is withheld to create a
/// reason to come back (`Docs/CONTRACTS.md` §4.7).
public struct HopCelebrationView: View {
    @Environment(\.hopTheme) private var theme
    @State private var sequencer = HopCelebrationSequencer()
    @State private var hasHandedBack = false

    private let stars: Int
    private let unlocked: PondItemID?
    private let onComplete: () -> Void

    /// How big Hop is drawn here. Named because the headroom the hop needs is
    /// derived from it, and the two must not drift apart.
    private static let characterSize: CGFloat = 240

    public init(stars: Int, unlocked: PondItemID?, onComplete: @escaping () -> Void) {
        self.stars = stars
        self.unlocked = unlocked
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            theme.color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: theme.spacing.xl) {
                Spacer(minLength: 0)

                // Hop arrives and then physically hops. The beats belong to
                // the performer inside `HopCharacterView`, which is cancel-safe:
                // handing back early lands him rather than leaving him airborne.
                HopCharacterStage(
                    act: sequencer.beat >= .hopArrives ? .celebrating() : .holding(.cheer),
                    size: HopCelebrationView.characterSize,
                    describedAs: ""
                )
                .frame(
                    height: HopCelebrationView.characterSize
                        + HopJump.headroom(for: HopCelebrationView.characterSize),
                    alignment: .bottom
                )
                .opacity(sequencer.beat >= .hopArrives ? 1 : 0)
                .scaleEffect(sequencer.beat >= .hopArrives ? 1 : 0.8)
                .hopAnimation(.childCelebrate, value: sequencer.beat)

                Text(HopStrings.celebrationTitle)
                    .hopTextStyle(.celebration, allowsTightening: false)
                    .foregroundStyle(theme.color.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(sequencer.beat >= .hopArrives ? 1 : 0)

                HopStarBadge(count: stars, animatesArrival: true, size: 44)
                    .opacity(sequencer.beat >= .starsArrive ? 1 : 0)
                    .hopAnimation(.childArrive, value: sequencer.beat)

                if let unlocked {
                    unlockCard(unlocked)
                        .opacity(sequencer.beat >= .unlockArrives ? 1 : 0)
                        .hopAnimation(.childArrive, value: sequencer.beat)
                }

                Spacer(minLength: 0)

                HopPrimaryButton(HopStrings.celebrationContinue, size: .childPrimary) { handBack() }
                    .opacity(sequencer.beat >= .starsArrive ? 1 : 0)
                    .padding(.bottom, theme.spacing.xxxl)
            }
            .hopPageMargins()
            .hopReadableWidth(HopLayout.childContentWidth)
        }
        .task {
            await sequencer.run(reduceMotion: theme.reduceMotion, hasUnlock: unlocked != nil)
            handBack()
        }
        // One announcement for the whole screen, spoken as soon as it appears
        // rather than beat by beat.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(spokenSummary)
    }

    /// The sequence and the button race each other to finish; whichever gets
    /// there first hands control back, and the other becomes a no-op. A child
    /// tapping through must not fire the completion twice.
    private func handBack() {
        guard !hasHandedBack else { return }
        hasHandedBack = true
        onComplete()
    }

    private var spokenSummary: String {
        var parts = [HopStrings.celebrationTitle, HopStrings.celebrationStars(stars)]
        if let unlocked {
            parts.append(HopStrings.celebrationUnlocked(unlocked.displayName))
        }
        return parts.joined(separator: ". ")
    }

    private func unlockCard(_ item: PondItemID) -> some View {
        HStack(spacing: theme.spacing.m) {
            HopGlyphBadge(.pond, tint: theme.color.brandSecondary, diameter: 48)
            Text(HopStrings.celebrationUnlocked(item.displayName))
                .hopTextStyle(.childInstruction, allowsTightening: false)
                .foregroundStyle(theme.color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(theme.spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                .fill(theme.color.surface)
        }
        .modifier(theme.elevation(.resting))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HopStrings.celebrationUnlocked(item.displayName))
    }
}

#Preview("Celebration") {
    HopCelebrationView(stars: 3, unlocked: .lilyFlower, onComplete: {})
        .hopThemedRoot()
}

#Preview("Celebration · no unlock, dark") {
    HopCelebrationView(stars: 1, unlocked: nil, onComplete: {})
        .hopThemedRoot()
        .preferredColorScheme(.dark)
}

#Preview("Celebration · AX3") {
    HopCelebrationView(stars: 12, unlocked: .waterLilyCluster, onComplete: {})
        .environment(\.dynamicTypeSize, .accessibility3)
        .hopThemedRoot()
}

#Preview("Celebration · Reduce Motion") {
    HopCelebrationView(stars: 3, unlocked: .rainbow, onComplete: {})
        .hopThemedRoot(reduceMotion: true)
}

#Preview("Celebration · iPad high contrast") {
    HopCelebrationView(stars: 3, unlocked: .dragonfly, onComplete: {})
        .frame(width: 834, height: 1_112)
        .hopThemedRoot(appearance: .lightHighContrast)
}
