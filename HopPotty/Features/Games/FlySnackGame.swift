import SwiftUI
import HopPottyCore

/// The lily pad, the sky, three flies and a tummy that fills.
///
/// The board is drawn in unit coordinates the model owns, so the same round
/// plays identically on a phone held in one hand and on an iPad flat on a table:
/// the play area grows, the flies stay finger-sized.
struct FlySnackGameView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let session: FlySnackSession

    var body: some View {
        GameScene(
            key: session.game.illustration,
            label: (session.game.intro ?? session.game.childDescription).localized
        ) { size in
            let flySide = max(theme.hitTarget.child, min(size.width, size.height) * 0.20)

            ZStack {
                hop(in: size)

                ForEach(session.puffs) { puff in
                    GamePuff(progress: puff.progress, side: flySide * 0.8)
                        .position(x: size.width * puff.x, y: size.height * puff.y)
                }

                ForEach(session.flies) { fly in
                    FlyView(fly: fly, side: flySide) { session.catchFly(fly.id) }
                        .position(x: size.width * fly.x, y: size.height * fly.drawnY)
                        // The distance between two ticks is covered by the token,
                        // which is a spring when motion is on and a cross-fade
                        // when Reduce Motion is: the fly still moves, but it
                        // never travels across the screen.
                        .hopAnimation(.childArrive, value: CGPoint(x: fly.x, y: fly.drawnY))
                        .hopTransition(.childArrive)
                }
            }
            .hopAnimation(.childArrive, value: session.flies.map(\.id))
        }
        .overlay(alignment: .topLeading) { TummyMeter(filled: session.caught) }
        .overlay(alignment: .bottom) { spokenLine }
        .gameClock(session)
    }

    // MARK: - Hop

    private func hop(in size: CGSize) -> some View {
        let side = min(min(size.width, size.height) * 0.62, ChildStage.characterSize(for: horizontalSizeClass))
        return HopCharacterStage(
            pose: pose,
            size: side,
            describedAs: session.isTummyFull ? GameCopy.flySnackHopFull.localized : GameCopy.flySnackHop.localized
        )
        // The `catch` pose's tongue leaves the mouth up and to the right, and
        // nothing outside the design system may change that. Turning the whole
        // frog is the honest way to point it at the fly, and a character facing
        // what he is reaching for is what a picture book would do anyway.
        .scaleEffect(x: facesLeft ? -1 : 1)
        .hopAnimation(.childTap, value: facesLeft)
        .position(x: size.width * 0.5, y: size.height * 0.78)
    }

    private var pose: HopPose {
        switch session.beat {
        case .hunting: .sit
        case .snapping: .`catch`
        case .full, .done: .full
        }
    }

    /// Hop only turns for a fly he is actually catching; he does not track them
    /// while they drift, which would read as anxiety rather than patience.
    private var facesLeft: Bool {
        if case .snapping(let towards) = session.beat { return towards < 0.5 }
        return false
    }

    // MARK: - What Hop says

    private var spokenLine: some View {
        HopSpokenLine(line, pulse: session.catches)
            .padding(.horizontal, theme.spacing.l)
            .padding(.bottom, theme.spacing.m)
    }

    private var line: HopPottyCore.HopVoiceLine {
        if session.isTummyFull { return session.game.line("tummyFull") }
        return session.catches == 0 ? session.game.line("intro") : session.game.line("catch")
    }
}

/// One fly. A button, because tapping is the only verb this game has.
private struct FlyView: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    let fly: FlySnackSession.Fly
    let side: CGFloat
    let onCatch: () -> Void

    var body: some View {
        Button(action: onCatch) {
            HopArtwork(fly.kind.illustration)
                .frame(width: side * 0.66, height: side * 0.66)
        }
        .buttonStyle(.plain)
        // The drawing is small; the target is not. `contentShape` is what makes
        // the difference real rather than decorative.
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: side / 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GameCopy.fly.localized)
        .accessibilityAddTraits(.isButton)
    }
}

/// Hop's tummy, as six segments.
///
/// Six friendly segments rather than a bar, because a bar has an empty part that
/// can look like something running out. It only ever fills, and it carries a
/// name but no value: a running tally read aloud after every catch would be a
/// score, and this game does not have one.
private struct TummyMeter: View {
    @Environment(\.hopTheme) private var theme

    let filled: Int

    var body: some View {
        HStack(spacing: theme.spacing.xxs) {
            ForEach(0..<FlySnackSession.tummySegments, id: \.self) { index in
                Capsule()
                    .fill(index < filled ? theme.color.brandAction : theme.color.surfaceSunken)
                    .frame(width: 18, height: 12)
            }
        }
        .padding(.horizontal, theme.spacing.s)
        .padding(.vertical, theme.spacing.xs)
        .background(Capsule().fill(theme.color.surfaceElevated.opacity(0.92)))
        .padding(theme.spacing.m)
        .hopAnimation(.childArrive, value: filled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GameCopy.tummyMeter.localized)
    }
}

// MARK: - Previews

private struct FlySnackHostPreview: View {
    @State var session: FlySnackSession
    var reduceMotion: Bool? = nil

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: {}
        ) {
            FlySnackGameView(session: session)
        }
        .hopThemedRoot(reduceMotion: reduceMotion)
    }
}

#Preview("Fly Snack · sitting") {
    FlySnackHostPreview(session: FlySnackSession())
}

#Preview("Fly Snack · mid-catch") {
    FlySnackHostPreview(session: {
        let session = FlySnackSession()
        if let fly = session.flies.first { session.catchFly(fly.id) }
        return session
    }())
}

#Preview("Fly Snack · tummy full") {
    FlySnackHostPreview(session: {
        let session = FlySnackSession()
        // Six catches, each one settled by a step of the clock, so the board is
        // in exactly the state a played round reaches.
        for _ in 0..<FlySnackSession.tummySegments {
            if let fly = session.flies.first { session.catchFly(fly.id) }
            session.advance(by: FlySnackSession.snapDuration + 0.1)
            session.advance(by: FlySnackSession.respawnDelay + 0.1)
        }
        return session
    }())
}

#Preview("Fly Snack · Reduce Motion") {
    FlySnackHostPreview(session: FlySnackSession(), reduceMotion: true)
}

#Preview("Fly Snack · iPad") {
    FlySnackHostPreview(session: FlySnackSession())
        .frame(width: 1024, height: 768)
}

#Preview("Fly Snack · AX3") {
    FlySnackHostPreview(session: FlySnackSession())
        .environment(\.dynamicTypeSize, .accessibility3)
}
