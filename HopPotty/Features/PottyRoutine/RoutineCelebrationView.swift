import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

/// The end of a routine: Hop cheering, the star that was just earned, and the
/// way back to play.
///
/// ## The cap is the design
///
/// The whole product is a *short* interruption. A reward animation that outlives
/// its welcome turns the bathroom trip into the price of a cartoon, so the
/// entire sequence is bounded by `HopMotion.celebrationMaxDuration` (3.5s) and
/// the way back is on screen and tappable from the first frame. Nothing here
/// waits for an animation to finish before the child is allowed to leave.
///
/// Reduce Motion is handled entirely by the design system's motion layer: this
/// file names tokens (`.childCelebrate`, `.childArrive`) and asks the theme for
/// their duration, so the sequence shortens itself without a branch here.
struct RoutineCelebrationView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.childContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// What the child said happened. Chooses which sentence Hop says — and
    /// nothing else. Both sentences are praise, and the star is the same star.
    let outcome: PottyEventKind?
    /// Stars earned in this run.
    let starsEarned: Int
    /// Lifetime total after this run.
    let totalStars: Int
    /// The decoration this run unlocked, if one landed.
    let unlocked: PondItem?
    let onSeeThePond: () -> Void
    let onFinish: () -> Void

    @State private var hasArrived = false

    /// `producedOutput` picks the wording, never the reward. A child who sat
    /// down and nothing happened did the whole skill; `celebration.tried.title`
    /// is warmth first and praise second, and it is exactly as large on screen
    /// as the other line.
    private var headline: String {
        outcome?.producedOutput == true
            ? HopCopy.celebration.successTitle.value
            : HopCopy.celebration.triedTitle.value
    }

    private var spokenLine: HopPottyCore.HopVoiceLine {
        outcome?.producedOutput == true
            ? HopVoice.shared.routineSuccess
            : HopVoice.shared.routineNoOutput
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.xxl) {
                cheer
                headlineText
                stars
                if let unlocked { unlockedRow(unlocked) }
                buttons
            }
            .frame(maxWidth: ChildStage.contentWidth)
            .frame(maxWidth: .infinity)
            .hopPageMargins()
            .padding(.vertical, theme.spacing.xxxl)
        }
        .scrollIndicators(.hidden)
        .task { await runSequence() }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Parts

    private var cheer: some View {
        HopCharacterStage(pose: .cheer, size: ChildStage.characterSize(for: horizontalSizeClass))
            .scaleEffect(hasArrived ? 1 : 0.86)
            .hopAnimation(.childCelebrate, value: hasArrived)
            // Hop cheering repeats what the headline says; one reading is enough.
            .accessibilityHidden(true)
    }

    private var headlineText: some View {
        VStack(spacing: theme.spacing.m) {
            Text(headline)
                .hopTextStyle(.celebration)
                .foregroundStyle(theme.color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(HopCopy.celebration.greeting.resolved(forNickname: context.nickname))
                .hopTextStyle(.childInstruction)
                .foregroundStyle(theme.color.textSecondary)
                .multilineTextAlignment(.center)

            HopSpokenLine(spokenLine)
        }
    }

    private var stars: some View {
        VStack(spacing: theme.spacing.s) {
            HopStarBadge(count: starsEarned, animatesArrival: true)
                .accessibilityHidden(true)

            Text(HopCopy.celebration.starsEarned.resolved(for: starsEarned))
                .hopTextStyle(.childTitle)
                .foregroundStyle(theme.color.textPrimary)
                .multilineTextAlignment(.center)

            Text(HopCopy.celebration.starTotal.resolved(for: totalStars))
                .hopTextStyle(.parentBody)
                .foregroundStyle(theme.color.textSecondary)
        }
        .scaleEffect(hasArrived ? 1 : 0.9)
        .opacity(hasArrived ? 1 : 0)
        .hopAnimation(.childArrive, value: hasArrived)
    }

    private func unlockedRow(_ item: PondItem) -> some View {
        VStack(spacing: theme.spacing.m) {
            HopArtwork(.pondItem(item.id), accessibilityLabel: PondItemNaming.name(for: item.id).value)
                .frame(width: 120, height: 120)

            Text(HopCopy.celebration.pondUnlock.value)
                .hopTextStyle(.childInstruction)
                .foregroundStyle(theme.color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(theme.spacing.xl)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                .fill(HopColors.wash(theme.color.celebration, isDark: theme.isDark))
        }
        .hopTransition(.childArrive)
    }

    private var buttons: some View {
        VStack(spacing: theme.spacing.m) {
            // Present and tappable from the first frame. The celebration is
            // something the child may watch, never something they must sit out.
            HopPrimaryButton(HopCopy.celebration.resumeButton.value, icon: "arrow.uturn.backward", size: .childPrimary, action: onFinish)

            HopPrimaryButton(HopCopy.celebration.seeThePond.value, icon: "leaf.fill", size: .child, action: onSeeThePond)
        }
    }

    // MARK: - Sequencing

    /// Plays the arrival beat, then stops. The sleep is the theme's own duration
    /// for the token, so Reduce Motion shortens it to a cross-fade without this
    /// function knowing that Reduce Motion exists.
    private func runSequence() async {
        hasArrived = true
        let beat = min(theme.duration(.childCelebrate), HopMotion.celebrationMaxDuration)
        try? await Task.sleep(for: .seconds(beat))
        // Nothing follows. The sequence has a last frame and holds it; there is
        // no loop, no confetti that keeps falling and nothing that flashes.
    }
}

#Preview("Celebration · output, star, no unlock") {
    RoutineCelebrationView(
        outcome: .pee,
        starsEarned: 3,
        totalStars: 12,
        unlocked: nil,
        onSeeThePond: {},
        onFinish: {}
    )
    .childContext(ChildContext(child: ChildProfile(nickname: "Maya"), totalStars: 12))
    .hopBackground(.secondary)
    .hopThemedRoot()
}

#Preview("Celebration · nothing happened, with unlock") {
    RoutineCelebrationView(
        outcome: .tried,
        starsEarned: 1,
        totalStars: 3,
        unlocked: PondCatalog.item(.lilyPadSmall),
        onSeeThePond: {},
        onFinish: {}
    )
    .hopBackground(.secondary)
    .hopThemedRoot()
}

#Preview("Celebration · Reduce Motion") {
    RoutineCelebrationView(
        outcome: .tried,
        starsEarned: 1,
        totalStars: 3,
        unlocked: PondCatalog.item(.lilyPadSmall),
        onSeeThePond: {},
        onFinish: {}
    )
    .hopBackground(.secondary)
    .hopThemedRoot(reduceMotion: true)
}

#Preview("Celebration · AX3") {
    RoutineCelebrationView(
        outcome: .poop,
        starsEarned: 2,
        totalStars: 34,
        unlocked: nil,
        onSeeThePond: {},
        onFinish: {}
    )
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopBackground(.secondary)
    .hopThemedRoot()
}

#Preview("Celebration · iPad") {
    RoutineCelebrationView(
        outcome: .pee,
        starsEarned: 3,
        totalStars: 48,
        unlocked: PondCatalog.item(.rainbow),
        onSeeThePond: {},
        onFinish: {}
    )
    .frame(width: 1024, height: 768)
    .hopBackground(.secondary)
    .hopThemedRoot()
}
