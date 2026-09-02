import Foundation
import Observation
import HopPottyCore

/// Potty Order: four cards, one path, and all the time in the world.
///
/// The routine's order is a thing a child can rehearse anywhere, and rehearsing
/// it away from the bathroom is far easier than rehearsing it with a full
/// bladder. So the whole game is the order, laid out flat, with nothing else
/// going on.
///
/// ## A card in the wrong spot is not a mistake
///
/// It springs back and Hop says the same warm sentence the quizzes use — the
/// one about trying another spot, never about being wrong. Nothing is counted,
/// the card returns to the tray exactly as it was, and it may be tried again
/// immediately, as many times as a child likes. There is no state in this type
/// that a wrong drop makes worse.
///
/// ## Two ways to place a card
///
/// Drag it, or pick it up and tap a spot. Both go through ``place(_:intoSlot:)``,
/// so a child who cannot yet drag, and a child using VoiceOver or Switch
/// Control, play the same board.
@MainActor
@Observable
final class PottyOrderSession: TimedMiniGameSession {

    /// The four steps, in the order they belong on the path.
    static let cards = GameCopy.OrderCard.allCases

    // MARK: - Shape of a round

    /// How long a sprung-back card keeps saying so.
    static let rebuffLifetime: TimeInterval = 1.4
    /// The beat between the last card landing and the round ending, so the
    /// finished path is something a child gets to look at.
    static let finishDelay: TimeInterval = 1.2
    /// After this, any card still in the tray settles onto its own spot, one at
    /// a time, and the child watches the path finish itself. Not a deadline:
    /// nothing is withdrawn and nothing counts down on screen.
    static let settleAfter: TimeInterval = 60
    /// One card settles every this often, once settling has started.
    static let settleInterval: TimeInterval = 2
    static let roundLimit: TimeInterval = 75

    let game = MiniGameCatalog.pottyOrder

    /// What is on each spot of the path, by the spot's own index.
    private(set) var placed: [GameCopy.OrderCard?]
    /// The cards not yet on the path, in the order they were dealt.
    private(set) var tray: [GameCopy.OrderCard]
    /// The card the child has picked up, for the tap-then-tap route. One at a
    /// time, so there is never a board with three things half-lifted.
    private(set) var held: GameCopy.OrderCard?
    /// The card that just sprang back, if the invitation is still on screen.
    private(set) var rebuffed: GameCopy.OrderCard?
    /// Bumped by every spring-back, so the view can pulse the line without
    /// having to diff which card it was.
    private(set) var nudges = 0
    private(set) var placements = 0
    private(set) var isFinished = false

    private let seed: UInt64
    private var rebuffAge: TimeInterval = 0
    private var finishAge: TimeInterval = 0
    private var elapsed: TimeInterval = 0
    private var settleAge: TimeInterval = 0

    init(seed: UInt64 = 2_718_281) {
        self.seed = seed
        placed = Array(repeating: nil, count: Self.cards.count)
        tray = Self.deal(seed: seed)
    }

    var completion: Double {
        Double(placements) / Double(Self.cards.count)
    }

    var isPathComplete: Bool { placed.allSatisfy { $0 != nil } }

    /// The card that belongs on a spot. The path is drawn with its spots named,
    /// not numbered, so this is how a spot knows what to call itself.
    func card(forSlot index: Int) -> GameCopy.OrderCard {
        Self.cards[min(max(0, index), Self.cards.count - 1)]
    }

    // MARK: - Playing

    /// Picks a card up, or puts it back down. Tapping the held card again is a
    /// child changing their mind, which is not an error.
    func pickUp(_ card: GameCopy.OrderCard) {
        guard !isFinished, tray.contains(card) else { return }
        held = (held == card) ? nil : card
    }

    /// Places the held card, if the child tapped a spot rather than dragging.
    func placeHeld(intoSlot index: Int) {
        guard let held else { return }
        place(held, intoSlot: index)
    }

    /// The one rule of the game, and the only place it is written down.
    func place(_ card: GameCopy.OrderCard, intoSlot index: Int) {
        guard !isFinished, tray.contains(card) else { return }
        guard index == card.order, placed[index] == nil else {
            // Springs back. Nothing else at all happens: no counter moves, the
            // card stays exactly where it was, and it can be tried again now.
            rebuffed = card
            rebuffAge = 0
            nudges += 1
            held = nil
            return
        }
        settle(card, intoSlot: index)
        held = nil
        rebuffed = nil
    }

    private func settle(_ card: GameCopy.OrderCard, intoSlot index: Int) {
        placed[index] = card
        tray.removeAll { $0 == card }
        placements += 1
    }

    // MARK: - The board moving on its own

    func advance(by seconds: TimeInterval) {
        guard !isFinished else { return }
        elapsed += seconds

        if rebuffed != nil {
            rebuffAge += seconds
            if rebuffAge >= Self.rebuffLifetime { rebuffed = nil }
        }

        if isPathComplete {
            finishAge += seconds
            if finishAge >= Self.finishDelay { isFinished = true }
            return
        }

        // The outer edge: the path finishes itself, one card at a time, so a
        // child who has stopped playing still sees the order they came for.
        guard elapsed >= Self.settleAfter || elapsed >= Self.roundLimit else { return }
        settleAge += seconds
        guard settleAge >= Self.settleInterval || elapsed >= Self.roundLimit else { return }
        settleAge = 0
        if let next = tray.min(by: { $0.order < $1.order }) {
            settle(next, intoSlot: next.order)
            held = nil
        }
    }

    // MARK: - Round

    func restart() {
        placed = Array(repeating: nil, count: Self.cards.count)
        tray = Self.deal(seed: seed)
        held = nil
        rebuffed = nil
        nudges = 0
        placements = 0
        rebuffAge = 0
        finishAge = 0
        settleAge = 0
        elapsed = 0
        isFinished = false
    }

    func finish() { isFinished = true }

    // MARK: - Layout

    /// A seeded shuffle that never deals the answer. A tray that happens to come
    /// out already in order is not a bug, but it is a wasted round.
    private static func deal(seed: UInt64) -> [GameCopy.OrderCard] {
        var shuffler = GameShuffler(seed: seed)
        var dealt = shuffler.shuffled(cards)
        if dealt == cards { dealt.reverse() }
        return dealt
    }
}
