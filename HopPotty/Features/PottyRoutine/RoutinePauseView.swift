import SwiftUI
import HopPottyCore

/// The Potty Pause, in the app's own voice.
///
/// ## Why the pause and the first step are one screen
///
/// A child taps "Let's Go" on the Screen Time shield, the app comes forward, and
/// this is what they land on. It says the same four things the shield said —
/// `HopCopy.shield` — because they are the same moment, and repeating them here
/// in HopPotty's own type, at HopPotty's own size, is what turns a system sheet
/// into a place. It is also the routine's first step: Hop is walking up the path
/// to the bathroom door, which is the picture "let's hop to the potty" needs in
/// order to mean anything to a two-year-old.
///
/// ## What is not on it
///
/// Everything. There is no step indicator, no strip of what is coming, no star
/// count, no timer, no settings and no game list — one drawing, two sentences, a
/// promise, and two buttons. The brief calls this an Apple system interruption
/// redesigned through Hop's personality, and the thing an interruption must not
/// do is decorate itself.
///
/// The secondary is the same "Need a grown-up?" the shield offers, and it does
/// the same thing: raises the parent gate. It is not an escape hatch and it is
/// not styled as one.
struct RoutinePauseView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.childContext) private var context

    /// Starts the routine. The child's own word for it is "Let's Go".
    let onGo: () -> Void
    /// Hands the device to an adult. Never a dead end.
    let onAskForHelp: () -> Void

    /// Which beat Hop is on: waiting in the wings, walking on the path, or on
    /// his way through the door.
    ///
    /// Under Reduce Motion the entrance and the exit both resolve to a
    /// cross-fade — `HopFrame.resolved(reduceMotion:)` zeroes every travelling
    /// quantity — so there is no branch here for the *drawing*. There is one for
    /// the *waiting*: a screen that held a child for the length of an animation
    /// that is no longer playing would be a delay with nothing in it.
    @State private var beat: Beat = .arriving

    private enum Beat: Equatable {
        case arriving
        case walking
        case leaving
    }

    private var act: HopAct {
        switch beat {
        case .arriving: .entering(from: .left, restingOn: .walk)
        case .walking: .holding(.walk)
        // §46: the screen change is character-led. Hop hops off toward the door
        // he has been walking to, and the next screen is the other side of it.
        case .leaving: .exiting(toward: .right, from: .walk)
        }
    }

    private var characterSide: CGFloat {
        ChildStage.characterSize(for: horizontalSizeClass) * 1.3
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: theme.spacing.xl) {
                    Spacer(minLength: theme.spacing.xxl)

                    HopCharacterStage(act: act, size: characterSide, gaze: .right)
                    .frame(
                        height: characterSide + HopJump.headroom(for: characterSide),
                        alignment: .bottom
                    )
                    // The words below say all of this; a mascot that announces
                    // itself first takes the focus off them.
                    .accessibilityHidden(true)

                    words

                    Spacer(minLength: theme.spacing.xxl)

                    buttons
                }
                .frame(maxWidth: ChildStage.contentWidth)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                .hopPageMargins()
                .padding(.bottom, theme.spacing.l)
            }
            .scrollIndicators(.hidden)
            .background { ChildMeadow(showsDoor: true) }
        }
        .task { beat = .walking }
        .accessibilityElement(children: .contain)
    }

    /// "Let's Go": Hop leaves through the door, and the routine starts behind
    /// him.
    ///
    /// The wait is exactly the length of the exit the motion layer says it is
    /// playing, so it shortens itself when Reduce Motion shortens the beat and
    /// disappears entirely when there is nothing to wait for. It is also
    /// cancel-safe: this view going away lands him rather than leaving the
    /// routine waiting on a `Task` that no longer has a screen.
    private func leave() {
        guard !theme.reduceMotion else {
            onGo()
            return
        }
        beat = .leaving
        Task {
            try? await Task.sleep(
                for: .seconds(HopAct.exiting(toward: .right, from: .walk).duration(reduceMotion: false))
            )
            guard !Task.isCancelled else { return }
            onGo()
        }
    }

    // MARK: - Parts

    /// The headline, and the sentence that carries the promise.
    ///
    /// `shield.body` is one entry holding both halves — "Let's hop to the potty.
    /// Your game will be here when you get back." — and it stays one entry.
    /// The second half is what makes the interruption safe, a translator has to
    /// see it beside the first half to keep the tone, and a child who does not
    /// believe their game is coming back negotiates instead of going.
    private var words: some View {
        VStack(spacing: theme.spacing.m) {
            Text(HopCopy.shield.greeting.localized(forNickname: context.nickname))
                .hopTextStyle(.childTitle)
                .foregroundStyle(theme.color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(HopCopy.shield.body.localized)
                .hopTextStyle(.childInstruction)
                .foregroundStyle(theme.color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var buttons: some View {
        VStack(spacing: theme.spacing.m) {
            HopPrimaryButton(
                HopCopy.shield.primaryButton.localized,
                icon: "figure.walk",
                size: .childPrimary,
                action: leave
            )

            HopSecondaryButton(
                HopCopy.shield.secondaryButton.localized,
                icon: "hand.raised.fill",
                action: onAskForHelp
            )
        }
    }
}

#Preview("Potty Pause · in the app") {
    RoutinePauseView(onGo: {}, onAskForHelp: {})
        .hopThemedRoot()
}

#Preview("Potty Pause · named") {
    RoutinePauseView(onGo: {}, onAskForHelp: {})
        .childContext(ChildContext(child: ChildProfile(nickname: "Maya")))
        .hopThemedRoot()
}

#Preview("Potty Pause · Reduce Motion") {
    RoutinePauseView(onGo: {}, onAskForHelp: {})
        .hopThemedRoot(reduceMotion: true)
}

#Preview("Potty Pause · AX3") {
    RoutinePauseView(onGo: {}, onAskForHelp: {})
        .environment(\.dynamicTypeSize, .accessibility3)
        .hopThemedRoot()
}

#Preview("Potty Pause · iPad") {
    RoutinePauseView(onGo: {}, onAskForHelp: {})
        .frame(width: 1024, height: 768)
        .hopThemedRoot()
}
