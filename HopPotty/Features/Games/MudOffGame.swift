import SwiftUI
import HopPottyCore

/// Hop with his hands out, the mud on them, and the tap.
struct MudOffGameView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// The last place the finger was, in unit coordinates, so the board can tell
    /// the model how far a movement travelled rather than how often the system
    /// happened to report it.
    @State private var lastTouch: CGPoint?

    let session: MudOffSession

    var body: some View {
        GameScene(
            key: session.game.illustration,
            label: (session.game.intro ?? session.game.childDescription).localized
        ) { size in
            let patchSide = max(theme.hitTarget.child, min(size.width, size.height) * 0.22)

            ZStack {
                hop(in: size)

                if session.beat == .water {
                    GameBubbleColumn(
                        progress: session.waterProgress,
                        width: size.width * 0.5,
                        height: size.height * 0.45
                    )
                    .position(x: size.width * 0.5, y: size.height * 0.6)
                    .hopAnimation(.childArrive, value: session.waterProgress)
                }

                ForEach(session.patches) { patch in
                    PatchView(patch: patch, side: patchSide) { session.wipeAway(patch.id) }
                        .position(x: size.width * patch.x, y: size.height * patch.y)
                }

                if session.beat == .tapReady {
                    tapControl
                        .position(x: size.width * 0.82, y: size.height * 0.26)
                        .hopTransition(.childArrive)
                }

                if session.sparkleProgress > 0 {
                    HopArtwork("icon.games.sparkle", accessibilityLabel: GameCopy.sparkle.localized)
                        .frame(width: size.width * 0.42, height: size.width * 0.42)
                        .scaleEffect(0.6 + session.sparkleProgress * 0.5)
                        .opacity(1 - session.sparkleProgress * 0.2)
                        .position(x: size.width * 0.5, y: size.height * 0.55)
                        .hopAnimation(.childCelebrate, value: session.sparkleProgress)
                }
            }
            .hopAnimation(.childArrive, value: session.beat)
            .contentShape(Rectangle())
            // Simultaneous, not exclusive: every patch is also a button, and a
            // tap has to keep working while a drag across the same patch wipes it.
            .simultaneousGesture(wipeGesture(in: size))
        }
        .overlay(alignment: .bottom) { spokenLine }
        .gameClock(session)
    }

    // MARK: - Wiping

    private func wipeGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard size.width > 0, size.height > 0 else { return }
                let point = CGPoint(x: value.location.x / size.width, y: value.location.y / size.height)
                defer { lastTouch = point }
                guard let previous = lastTouch else { return }
                let dx = point.x - previous.x
                let dy = point.y - previous.y
                let travelled = (dx * dx + dy * dy).squareRoot()
                guard travelled > 0 else { return }
                session.wipe(at: point, travelled: travelled, angle: atan2(dy, dx))
            }
            .onEnded { _ in lastTouch = nil }
    }

    // MARK: - Hop and the tap

    private func hop(in size: CGSize) -> some View {
        let side = min(min(size.width, size.height) * 0.72, ChildStage.characterSize(for: horizontalSizeClass))
        return HopCharacterStage(pose: .scrub, size: side, describedAs: GameCopy.mudOffHop.localized)
            .position(x: size.width * 0.5, y: size.height * 0.5)
    }

    private var tapControl: some View {
        Button { session.turnOnWater() } label: {
            // The sink the routine's wash step already uses, so the tap a child
            // reaches for here is the one they saw in the bathroom.
            HopArtwork("icon.quiz.sink")
                .frame(width: theme.hitTarget.childPrimary * 0.7, height: theme.hitTarget.childPrimary * 0.7)
        }
        .buttonStyle(.plain)
        .frame(width: theme.hitTarget.childPrimary, height: theme.hitTarget.childPrimary)
        .background(Circle().fill(theme.color.surfaceElevated.opacity(0.92)))
        .contentShape(Circle())
        .hopBreathing(true, amplitude: 0.04)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GameCopy.waterTap.localized)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - What Hop says

    private var spokenLine: some View {
        HopSpokenLine(line, pulse: session.patchesCleared)
            .padding(.horizontal, theme.spacing.l)
            .padding(.bottom, theme.spacing.m)
    }

    private var line: HopPottyCore.HopVoiceLine {
        switch session.beat {
        case .wiping:
            return session.patchesCleared == 0 ? session.game.line("intro") : session.game.line("patchGone")
        case .tapReady:
            return session.game.line("tap")
        case .water, .sparkle, .done:
            return session.game.line("done")
        }
    }
}

/// One patch of mud. Fades and shrinks along the swipe that took it off.
private struct PatchView: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    let patch: MudOffSession.Patch
    let side: CGFloat
    let onWipe: () -> Void

    var body: some View {
        Button(action: onWipe) {
            HopArtwork(patch.kind.illustration)
                .frame(width: side * 0.78 * patch.scale, height: side * 0.78 * patch.scale)
        }
        .buttonStyle(.plain)
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        // Shrink along the swipe: the patch narrows across the finger's line and
        // keeps its length, which is what a smear does.
        .scaleEffect(x: 1 - patch.wipe, y: 1 - patch.wipe * 0.35, anchor: .center)
        .rotationEffect(.radians(patch.wipeAngle))
        .opacity(1 - patch.wipe)
        .hopAnimation(.childTap, value: patch.wipe)
        .allowsHitTesting(!patch.isGone)
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: theme.radius.l)
        .accessibilityHidden(patch.isGone)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(patch.kind.label.localized)
        .accessibilityHint(Text(verbatim: GameCopy.wipeHint.localized))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Previews

private struct MudOffHostPreview: View {
    @State var session: MudOffSession
    var reduceMotion: Bool? = nil

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: {}
        ) {
            MudOffGameView(session: session)
        }
        .hopThemedRoot(reduceMotion: reduceMotion)
    }
}

#Preview("Mud Off · muddy") {
    MudOffHostPreview(session: MudOffSession())
}

#Preview("Mud Off · one patch left") {
    MudOffHostPreview(session: {
        let session = MudOffSession()
        for patch in session.patches.dropLast() { session.wipeAway(patch.id) }
        return session
    }())
}

#Preview("Mud Off · water running") {
    MudOffHostPreview(session: {
        let session = MudOffSession()
        for patch in session.patches { session.wipeAway(patch.id) }
        session.turnOnWater()
        session.advance(by: 1)
        return session
    }())
}

#Preview("Mud Off · Reduce Motion") {
    MudOffHostPreview(session: MudOffSession(), reduceMotion: true)
}

#Preview("Mud Off · iPad") {
    MudOffHostPreview(session: MudOffSession())
        .frame(width: 1024, height: 768)
}

#Preview("Mud Off · AX3") {
    MudOffHostPreview(session: MudOffSession())
        .environment(\.dynamicTypeSize, .accessibility3)
}
