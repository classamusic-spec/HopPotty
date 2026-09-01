import SwiftUI
import HopPottyCore

/// The basin, the stage picture and the bubbles.
struct BubbleWashGameView: View {
    @Environment(\.hopTheme) private var theme

    let session: BubbleWashSession

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let bubbleSide = max(theme.hitTarget.child, min(size.width, size.height) * 0.16)

            ZStack {
                RoundedRectangle(cornerRadius: theme.radius.hero, style: .continuous)
                    .fill(HopColors.wash(theme.color.brandPrimary, isDark: theme.isDark))

                HopArtwork(session.stage.illustration, accessibilityLabel: session.stage.label.localized)
                    .frame(width: size.width * 0.42, height: size.height * 0.42)
                    .position(x: size.width * 0.5, y: size.height * 0.5)

                ForEach(session.bubbles) { bubble in
                    BubbleView(bubble: bubble, side: bubbleSide) { session.pop(bubble.id) }
                        .position(x: size.width * bubble.x, y: size.height * bubble.y)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: theme.radius.hero, style: .continuous))
            // Simultaneous, not exclusive: the bubbles are buttons and a tap
            // must keep working while a drag across them also pops them.
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard size.width > 0, size.height > 0 else { return }
                        session.rub(
                            at: CGPoint(x: value.location.x / size.width, y: value.location.y / size.height),
                            radius: Double(bubbleSide / min(size.width, size.height)) * 0.6
                        )
                    }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(session.stage.label.localized)
        }
        .overlay(alignment: .top) { stageBanner }
    }

    private var stageBanner: some View {
        Text(session.stage.label.localized)
            .hopTextStyle(.childTitle)
            .foregroundStyle(theme.color.textPrimary)
            .padding(.horizontal, theme.spacing.xl)
            .padding(.vertical, theme.spacing.s)
            .background(Capsule().fill(theme.color.surfaceElevated))
            .padding(.top, theme.spacing.m)
            .hopAnimation(.childArrive, value: session.stageIndex)
            // The banner names the beat; the basin below already carries it as
            // its label, so this is the visible half of the same statement.
            .accessibilityHidden(true)
    }
}

/// One bubble. A button, so a tap works everywhere a drag does.
private struct BubbleView: View {
    @Environment(\.hopTheme) private var theme

    let bubble: BubbleWashSession.Bubble
    let side: CGFloat
    let onPop: () -> Void

    var body: some View {
        Button(action: onPop) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            theme.color.surfaceElevated.opacity(0.95),
                            theme.color.brandPrimary.opacity(0.35),
                        ],
                        center: .init(x: 0.35, y: 0.32),
                        startRadius: 1,
                        endRadius: side * 0.6 * bubble.scale
                    )
                )
                .overlay { Circle().strokeBorder(theme.color.surfaceElevated.opacity(0.9), lineWidth: 2) }
                .frame(width: side * bubble.scale, height: side * bubble.scale)
        }
        .buttonStyle(.plain)
        .frame(width: side, height: side)
        .hopFloating(distance: 3, period: 5.0)
        .scaleEffect(bubble.isPopped ? 0.01 : 1)
        .opacity(bubble.isPopped ? 0 : 1)
        .hopAnimation(.childTap, value: bubble.isPopped)
        .allowsHitTesting(!bubble.isPopped)
        .accessibilityHidden(bubble.isPopped)
        .accessibilityLabel(GameCopy.bubble.localized)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Bubble Wash · first beat") {
    BubbleWashHostPreview(session: BubbleWashSession())
}

#Preview("Bubble Wash · Reduce Motion") {
    BubbleWashHostPreview(session: BubbleWashSession(), reduceMotion: true)
}

#Preview("Bubble Wash · iPad") {
    BubbleWashHostPreview(session: BubbleWashSession())
        .frame(width: 1024, height: 768)
}

/// Shared preview scaffold, so each preview is one line.
private struct BubbleWashHostPreview: View {
    @State var session: BubbleWashSession
    var reduceMotion: Bool? = nil

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: {}
        ) {
            BubbleWashGameView(session: session)
        }
        .hopThemedRoot(reduceMotion: reduceMotion)
    }
}

#Preview("Bubble Wash · AX3") {
    BubbleWashHostPreview(session: BubbleWashSession())
        .environment(\.dynamicTypeSize, .accessibility3)
}
