import Foundation

/// One entry in a child's Hop Star ledger.
///
/// Stars are an append-only ledger rather than a mutable total. A running total
/// can drift, can be corrupted by a crash mid-write, and cannot answer "why do I
/// have 34 stars?". A ledger can, and it makes the one rule that matters
/// enforceable: nothing ever *removes* stars a child has earned.
public struct RewardTransaction: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let childID: UUID
    public let timestamp: Date
    public let reason: RewardReason
    /// Always positive. There is no such thing as a negative reward in HopPotty.
    public let quantity: Int
    /// The event that earned this, when there was one. Used to reconcile the
    /// ledger if a caregiver deletes an event.
    public let sourceEventID: UUID?
    /// Stable key used to make awarding idempotent. Two attempts to award the
    /// same routine completion collapse to one entry.
    public let idempotencyKey: String

    public init(
        id: UUID = UUID(),
        childID: UUID,
        timestamp: Date = Date(),
        reason: RewardReason,
        quantity: Int = 1,
        sourceEventID: UUID? = nil,
        idempotencyKey: String
    ) {
        self.id = id
        self.childID = childID
        self.timestamp = timestamp
        self.reason = reason
        self.quantity = max(0, quantity)
        self.sourceEventID = sourceEventID
        self.idempotencyKey = idempotencyKey
    }
}

/// Why a star was awarded.
///
/// Every case rewards an *action the child chose to take*. None of them reward a
/// biological outcome, and none of them can be triggered by an accident.
public enum RewardReason: String, Codable, CaseIterable, Sendable, Identifiable {
    /// The child went and tried. The core reward of the product.
    case triedThePotty
    /// The child finished the full guided routine.
    case completedRoutine
    /// Hand washing, specifically.
    case washedHands
    /// The child told a grown-up they needed to go.
    case toldAGrownUp
    /// Finished a quiz.
    case completedQuiz
    /// Finished a mini-game.
    case completedGame
    /// Answered the door when Hop knocked — responded to a Potty Pause at all.
    case answeredPottyPause

    public var id: String { rawValue }

    /// Stars granted by default for this reason.
    public var defaultQuantity: Int {
        switch self {
        case .triedThePotty: 1
        case .completedRoutine: 1
        case .washedHands: 1
        case .toldAGrownUp: 1
        case .completedQuiz: 1
        case .completedGame: 1
        case .answeredPottyPause: 1
        }
    }
}
