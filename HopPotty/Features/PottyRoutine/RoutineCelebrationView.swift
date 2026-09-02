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
    ///
    /// This run's star, and nothing about any other run. The lifetime total used
    /// to be printed under it — "13 stars in your pond" — and it is gone: a
    /// running tally on the last screen of a bathroom trip is a performance
    /// metric, and this screen is praise for a thing the child controls. The
    /// total still exists, in the pond, where a child goes to look at it because
    /// they want to.
    let starsEarned: Int
    /// The decoration this run unlocked, if one landed.
    let unlocked: PondItem?
    let onSeeThePond: () -> Void
    let onFinish: () -> Void

    @State private var isHopping = false

    /// The hop Hop does here. Only its *direction* comes from the outcome:
    /// `RoutineOutcomeChoices.celebrationHop(for:)` builds all three from one
    /// constant, so "I tried" gets the same number of hops, the same height and
    /// the same duration as "I peed". See `Docs/ChildSafety.md` §2.
    private var celebrationHop: HopJump {
        RoutineOutcomeChoices.celebrationHop(for: outcome)
    }

    private var characterSize: CGFloat {
        ChildStage.characterSize(for: horizontalSizeClass)
    }

    /// `producedOutput` picks the wording, never the reward. A child who sat
    /// down and nothing happened did the whole skill; `celebration.tried.title`
    /// is warmth first and praise second, and it is exactly as large on screen
    /// as the other line.
    private var headline: String {
        outcome?.producedOutput == true
            ? HopCopy.celebration.successTitle.localized
            : HopCopy.celebration.triedTitle.localized
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
        .background { ChildMeadow(horizonFraction: 0.62) }
        .task { await runSequence() }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Parts

    /// Hop, arriving and then physically celebrating.
    ///
    /// The act is what changes, not a pile of modifiers: `HopCharacterView`'s
    /// performer owns the crouch, the rise, the hang, the landing squash and
    /// the settle, and it is cancel-safe — this screen going away lands him
    /// rather than leaving him in the air.
    private var cheer: some View {
        HopCharacterStage(
            act: isHopping ? .celebrating(celebrationHop) : .holding(.cheer),
            size: characterSize
        )
        // Headroom for the apex, reserved whether or not he is hopping, so the
        // hop never pushes the rest of the screen around and never overruns the
        // space above it.
        .frame(height: characterSize + HopJump.headroom(for: characterSize), alignment: .bottom)
        // No arrival scale here. The screen itself arrives on
        // `HopScreenTransition.celebration`, which scales this whole view; a
        // second scale on Hop multiplied with it and started him at roughly
        // half size.
        // Hop cheering repeats what the headline says; one reading is enough.
        // The hop adds no announcement and takes no focus.
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

            Text(HopCopy.celebration.greeting.localized(forNickname: context.nickname))
                .hopTextStyle(.childInstruction)
                .foregroundStyle(theme.color.textSecondary)
                .multilineTextAlignment(.center)

            HopSpokenLine(spokenLine)
        }
    }

    /// One star, said once.
    private var stars: some View {
        HStack(spacing: theme.spacing.m) {
            HopStarBadge(count: starsEarned, animatesArrival: true)
                .accessibilityHidden(true)

            Text(HopCopy.celebration.starsEarned.localized(for: starsEarned))
                .hopTextStyle(.childTitle)
                .foregroundStyle(theme.color.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        // Arrives with the screen, for the same reason Hop does.
    }

    /// The one thing this run unlocked, if anything did.
    ///
    /// It used to sit inside a tinted card, which made the celebration a page
    /// with two panels on it. The item is a thing in the pond, so it is drawn as
    /// a thing standing in the meadow with a sentence under it — the same
    /// treatment the star above it gets, and no second reward carousel.
    private func unlockedRow(_ item: PondItem) -> some View {
        VStack(spacing: theme.spacing.s) {
            HopArtwork(.pondItem(item.id), accessibilityLabel: PondItemNaming.name(for: item.id).localized)
                .frame(width: 108, height: 108)

            Text(HopCopy.celebration.pondUnlock.localized)
                .hopTextStyle(.childInstruction)
                .foregroundStyle(theme.color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .hopTransition(.childArrive)
    }

    private var buttons: some View {
        VStack(spacing: theme.spacing.m) {
            // Present and tappable from the first frame. The celebration is
            // something the child may watch, never something they must sit out.
            HopPrimaryButton(HopCopy.celebration.resumeButton.localized, icon: "arrow.uturn.backward", size: .childPrimary, action: onFinish)

            HopPrimaryButton(HopCopy.celebration.seeThePond.localized, icon: "leaf.fill", size: .child, action: onSeeThePond)
        }
    }

    // MARK: - Sequencing

    /// Two beats: the screen arrives, then Hop hops. The first beat is not
    /// animated here — `HopScreenTransition.celebration` brings the whole view
    /// in — so this function only waits out that arrival before the hop, using
    /// the theme's own duration for the token, which means Reduce Motion
    /// shortens it to a cross-fade without this function knowing Reduce Motion
    /// exists.
    private func runSequence() async {
        let arrival = min(theme.duration(.childCelebrate), HopMotion.celebrationMaxDuration)

        #if DEBUG
        // The ceiling is the design (`Docs/ChildSafety.md`, `Docs/Accessibility.md`
        // §3.8). Asserted rather than commented, so retuning a beat that pushes
        // the celebration past 3.5s fails in a preview instead of shipping.
        assert(
            arrival + celebrationHop.duration(reduceMotion: theme.reduceMotion)
                <= HopMotion.celebrationMaxDuration,
            "The celebration must fit inside HopMotion.celebrationMaxDuration."
        )
        #endif

        try? await Task.sleep(for: .seconds(arrival))
        guard !Task.isCancelled else { return }
        isHopping = true
        // Nothing follows. The hop has a last frame and holds it; there is no
        // loop, no confetti that keeps falling and nothing that flashes.
    }
}

// The three answers, side by side and identical.
//
// This preview exists to be *looked at* when someone changes the celebration:
// three hops of the same height, the same count and the same length, differing
// only in which way they lean. If one of them ever looks bigger than the other
// two, the change that did it is the bug.

#Preview("Celebration · the three answers, hopping identically") {
    HStack(alignment: .bottom, spacing: 20) {
        ForEach(RoutineOutcomeChoices.order) { kind in
            let hop = RoutineOutcomeChoices.celebrationHop(for: kind)
            VStack(spacing: 8) {
                HopCharacterStage(act: .celebrating(hop), size: 140)
                    .frame(height: 140 + HopJump.headroom(for: 140), alignment: .bottom)
                Text(verbatim: kind.rawValue).hopTextStyle(.parentCaption)
                Text(verbatim: "\(hop.hops) hops · \(Int(hop.duration(reduceMotion: false) * 1000)) ms")
                    .hopTextStyle(.parentCaption)
            }
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground(.secondary)
    .hopThemedRoot()
}

#Preview("Celebration · I peed") {
    RoutineCelebrationView(
        outcome: .pee,
        starsEarned: 1,
        unlocked: nil,
        onSeeThePond: {},
        onFinish: {}
    )
    .hopBackground(.secondary)
    .hopThemedRoot()
}

#Preview("Celebration · I pooped") {
    RoutineCelebrationView(
        outcome: .poop,
        starsEarned: 1,
        unlocked: nil,
        onSeeThePond: {},
        onFinish: {}
    )
    .hopBackground(.secondary)
    .hopThemedRoot()
}

#Preview("Celebration · I tried") {
    RoutineCelebrationView(
        outcome: .tried,
        starsEarned: 1,
        unlocked: nil,
        onSeeThePond: {},
        onFinish: {}
    )
    .hopBackground(.secondary)
    .hopThemedRoot()
}

#Preview("Celebration · output, star, no unlock") {
    RoutineCelebrationView(
        outcome: .pee,
        starsEarned: 3,
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
        unlocked: PondCatalog.item(.rainbow),
        onSeeThePond: {},
        onFinish: {}
    )
    .frame(width: 1024, height: 768)
    .hopBackground(.secondary)
    .hopThemedRoot()
}
