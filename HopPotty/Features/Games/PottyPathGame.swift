import SwiftUI
import Observation
import HopPottyCore

/// Potty Path: hop along the lily pads to the bathroom.
///
/// One path, the same one every time. There are no levels, no difficulty ramp
/// and no branching, because the game is a *rehearsal* — the trip to the
/// bathroom as a short, friendly journey with a beginning and an end — and a
/// rehearsal that changes under you rehearses nothing. A child who has done it
/// four times knows where the corners are, and knowing is the point.
///
/// There is also nothing to fall off. Only the next pad accepts a tap, so the
/// path cannot be lost, cannot be walked backwards into a dead end, and cannot
/// end anywhere except the bathroom.
@MainActor
@Observable
final class PottyPathSession: MiniGameSession {

    /// A pad's place on the little grid. Column and row, from the top-left.
    struct Pad: Identifiable, Hashable {
        let index: Int
        let column: Int
        let row: Int
        var id: Int { index }
    }

    static let columns = 4
    static let rows = 5

    /// The path, start to bathroom. Authored rather than generated: eight pads
    /// with two turns is a journey a two-year-old can see the whole of.
    static let path: [Pad] = [
        Pad(index: 0, column: 0, row: 4),
        Pad(index: 1, column: 1, row: 4),
        Pad(index: 2, column: 1, row: 3),
        Pad(index: 3, column: 1, row: 2),
        Pad(index: 4, column: 2, row: 2),
        Pad(index: 5, column: 2, row: 1),
        Pad(index: 6, column: 3, row: 1),
        Pad(index: 7, column: 3, row: 0),
    ]

    let game = MiniGameCatalog.pottyPath

    /// Where Hop is standing, as an index into `path`.
    private(set) var position = 0
    private(set) var isFinished = false

    var completion: Double {
        Double(position) / Double(max(1, Self.path.count - 1))
    }

    /// The only pad that accepts a tap. `nil` once Hop has arrived.
    var nextPad: Pad? {
        position + 1 < Self.path.count ? Self.path[position + 1] : nil
    }

    func isGoal(_ pad: Pad) -> Bool { pad.index == Self.path.count - 1 }

    // MARK: - Playing

    /// Hops forward one pad. Anything else is ignored rather than corrected —
    /// a stray tap on scenery is not a mistake worth telling a child about.
    func hop(to pad: Pad) {
        guard pad.index == position + 1 else { return }
        position = pad.index
        if position == Self.path.count - 1 { isFinished = true }
    }

    func restart() {
        position = 0
        isFinished = false
    }

    func finish() { isFinished = true }
}

/// The pond crossing, drawn as a grid of lily pads.
struct PottyPathGameView: View {
    @Environment(\.hopTheme) private var theme

    let session: PottyPathSession

    var body: some View {
        GeometryReader { proxy in
            let cell = cellSize(in: proxy.size)

            ZStack {
                RoundedRectangle(cornerRadius: theme.radius.hero, style: .continuous)
                    .fill(HopColors.wash(theme.color.brandPrimary, isDark: theme.isDark))

                ForEach(PottyPathSession.path) { pad in
                    padView(pad, cell: cell)
                        .position(center(of: pad, cell: cell, in: proxy.size))
                }

                HopCharacterStage(pose: .jump, size: cell * 0.72)
                    .position(center(of: PottyPathSession.path[session.position], cell: cell, in: proxy.size))
                    // Hop travels between pads rather than teleporting; under
                    // Reduce Motion the token collapses to a cross-fade and he
                    // simply appears on the next pad.
                    .hopAnimation(.childArrive, value: session.position)
                    // Not decorative: where Hop is standing is the state of the
                    // game, and a VoiceOver user has to be able to find him.
                    .accessibilityLabel(GameCopy.pathHop.value)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(session.game.title.value)
    }

    // MARK: - Geometry

    /// A pad is never smaller than `HopHitTarget.childMinimum`, whatever the
    /// grid has to do to fit around it.
    private func cellSize(in size: CGSize) -> CGFloat {
        let byWidth = size.width / CGFloat(PottyPathSession.columns + 1)
        let byHeight = size.height / CGFloat(PottyPathSession.rows + 1)
        return max(theme.hitTarget.child, min(byWidth, byHeight))
    }

    private func center(of pad: PottyPathSession.Pad, cell: CGFloat, in size: CGSize) -> CGPoint {
        let gridWidth = cell * CGFloat(PottyPathSession.columns)
        let gridHeight = cell * CGFloat(PottyPathSession.rows)
        let originX = (size.width - gridWidth) / 2 + cell / 2
        let originY = (size.height - gridHeight) / 2 + cell / 2
        return CGPoint(x: originX + cell * CGFloat(pad.column), y: originY + cell * CGFloat(pad.row))
    }

    // MARK: - Pads

    @ViewBuilder
    private func padView(_ pad: PottyPathSession.Pad, cell: CGFloat) -> some View {
        let isNext = session.nextPad == pad
        let isGoal = session.isGoal(pad)

        Button {
            session.hop(to: pad)
        } label: {
            ZStack {
                Ellipse()
                    .fill(isGoal ? HopColors.wash(theme.color.celebration, isDark: theme.isDark) : theme.color.success.opacity(0.55))
                    .overlay {
                        Ellipse().strokeBorder(
                            isNext ? theme.color.brandAction : theme.color.divider,
                            lineWidth: isNext ? 4 : 1
                        )
                    }

                if isGoal {
                    HopArtwork("icon.quiz.potty")
                        .frame(width: cell * 0.5, height: cell * 0.5)
                }
            }
            .frame(width: cell * 0.86, height: cell * 0.66)
        }
        .buttonStyle(.plain)
        .frame(width: cell, height: cell)
        .contentShape(Rectangle())
        // Only the next pad does anything, so it is the only thing that reads as
        // a control. The rest are scenery, and scenery a child taps by accident
        // should stay quiet rather than say no.
        .disabled(!isNext)
        .hopBreathing(isNext, amplitude: 0.03)
        .accessibilityHidden(!isNext)
        .accessibilityLabel(isGoal ? GameCopy.pathGoal.value : GameCopy.pathStep.value)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Potty Path · start") {
    PottyPathHostPreview(session: PottyPathSession())
}

#Preview("Potty Path · part way") {
    PottyPathHostPreview(session: {
        let session = PottyPathSession()
        for pad in PottyPathSession.path.prefix(5).dropFirst() { session.hop(to: pad) }
        return session
    }())
}

#Preview("Potty Path · Reduce Motion") {
    PottyPathHostPreview(session: PottyPathSession(), reduceMotion: true)
}

#Preview("Potty Path · iPad") {
    PottyPathHostPreview(session: PottyPathSession())
        .frame(width: 1024, height: 768)
}

private struct PottyPathHostPreview: View {
    @State var session: PottyPathSession
    var reduceMotion: Bool?

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: {}
        ) {
            PottyPathGameView(session: session)
        }
        .hopThemedRoot(reduceMotion: reduceMotion)
    }
}
