import SwiftUI
import Observation
import HopPottyCore

/// Bubble Wash: the five beats of hand-washing, one screenful of bubbles each.
///
/// The child rubs across the basin and the bubbles under their finger pop; when
/// the last one goes, the next beat arrives — water, soap, rub, rinse, dry.
/// After the fifth the round ends itself, which is what
/// `MiniGameCompletion.whenTaskComplete` means for this game.
///
/// Every bubble is *also* a button, at `HopHitTarget.childMinimum`. That is not
/// a fallback bolted on for VoiceOver: a two-year-old who cannot yet drag can
/// play the whole game by tapping, and a child using Switch Control or VoiceOver
/// gets the same board rather than a described one.
@MainActor
@Observable
final class BubbleWashSession: MiniGameSession {

    struct Bubble: Identifiable, Hashable {
        let id: Int
        /// Unit position inside the basin, 0...1 on both axes.
        let x: Double
        let y: Double
        let scale: Double
        var isPopped = false
    }

    let game = MiniGameCatalog.bubbleWash

    private(set) var stageIndex = 0
    private(set) var bubbles: [Bubble] = []
    private(set) var isFinished = false

    private let stages = GameCopy.WashStage.allCases
    /// Six is enough to feel like a handful of bubbles and few enough that a
    /// beat is over before a three-year-old's attention is.
    private static let bubblesPerStage = 6

    init(seed: UInt64 = 20_240_601) {
        self.seed = seed
        bubbles = Self.makeBubbles(stage: 0, seed: seed)
    }

    private let seed: UInt64

    var stage: GameCopy.WashStage { stages[min(stageIndex, stages.count - 1)] }

    var completion: Double {
        let done = Double(stageIndex * Self.bubblesPerStage + poppedCount)
        return min(1, done / Double(stages.count * Self.bubblesPerStage))
    }

    private var poppedCount: Int { bubbles.filter(\.isPopped).count }

    // MARK: - Playing

    /// Pops one bubble. Idempotent: popping an already-popped bubble is not a
    /// mistake, it is a child tapping the same nice spot twice.
    func pop(_ id: Int) {
        guard let index = bubbles.firstIndex(where: { $0.id == id }), !bubbles[index].isPopped else { return }
        bubbles[index].isPopped = true
        if bubbles.allSatisfy(\.isPopped) { advanceStage() }
    }

    /// Pops everything the finger is currently over. `radius` is in the same
    /// unit space as the bubbles, so the view passes a size-relative value and
    /// the model stays free of points.
    func rub(at point: CGPoint, radius: Double) {
        for bubble in bubbles where !bubble.isPopped {
            let dx = bubble.x - point.x
            let dy = bubble.y - point.y
            if (dx * dx + dy * dy).squareRoot() <= radius * bubble.scale { pop(bubble.id) }
        }
    }

    private func advanceStage() {
        guard stageIndex + 1 < stages.count else {
            isFinished = true
            return
        }
        stageIndex += 1
        bubbles = Self.makeBubbles(stage: stageIndex, seed: seed)
    }

    // MARK: - Round

    func restart() {
        stageIndex = 0
        isFinished = false
        bubbles = Self.makeBubbles(stage: 0, seed: seed)
    }

    func finish() { isFinished = true }

    /// A seeded scatter, kept away from the edges so no bubble is half off the
    /// basin and none is too small to hit.
    private static func makeBubbles(stage: Int, seed: UInt64) -> [Bubble] {
        var shuffler = GameShuffler(seed: seed &+ UInt64(stage) &* 7919)
        return (0..<bubblesPerStage).map { index in
            Bubble(
                id: stage * 100 + index,
                x: 0.16 + Double(shuffler.next(upperBound: 69)) / 100,
                y: 0.18 + Double(shuffler.next(upperBound: 65)) / 100,
                scale: 0.85 + Double(shuffler.next(upperBound: 40)) / 100
            )
        }
    }
}

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

                HopArtwork(session.stage.illustration, accessibilityLabel: session.stage.label.value)
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
            .accessibilityLabel(session.stage.label.value)
        }
        .overlay(alignment: .top) { stageBanner }
    }

    private var stageBanner: some View {
        Text(session.stage.label.value)
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
        .accessibilityLabel(GameCopy.bubble.value)
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
    var reduceMotion: Bool?

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
