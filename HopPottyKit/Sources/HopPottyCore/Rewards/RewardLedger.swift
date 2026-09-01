import Foundation

/// The append-only store of a family's `RewardTransaction`s.
///
/// It is a value type on purpose: a ledger can be handed to the insights engine,
/// a preview or a test without anyone being able to mutate the copy the app is
/// holding. The only mutation it offers is `append`, and `append` cannot remove,
/// reduce or reorder anything.
///
/// There is deliberately **no** `remove`, `subtract`, `clear`, `expire` or
/// `decay` on this type. Contract rule 2 ("stars are never removed") is easiest
/// to keep when the API that would break it does not exist.
public struct RewardLedger: Hashable, Codable, Sendable {
    /// Every transaction, in the order it was appended.
    public private(set) var transactions: [RewardTransaction]

    /// Idempotency key -> transaction id, so a duplicate award is O(1) to spot.
    /// Derived state: rebuilt on decode rather than encoded, so it can never
    /// disagree with `transactions`.
    private var keyIndex: [String: UUID]

    public init() {
        self.transactions = []
        self.keyIndex = [:]
    }

    /// Builds a ledger from stored rows, dropping anything that violates the
    /// ledger's invariants.
    ///
    /// First writer wins on a duplicate key: the earliest row is the one the
    /// child was actually shown a celebration for. Non-positive quantities are
    /// dropped because a zero-star row is noise that makes "why do I have 34
    /// stars?" harder to answer, and a negative row is not representable in the
    /// product at all.
    public init(_ transactions: some Sequence<RewardTransaction>) {
        self.transactions = []
        self.keyIndex = [:]
        for transaction in transactions {
            _ = append(transaction)
        }
    }

    // MARK: - Reading

    public var count: Int { transactions.count }
    public var isEmpty: Bool { transactions.isEmpty }

    public func contains(key: String) -> Bool { keyIndex[key] != nil }

    public func transaction(forKey key: String) -> RewardTransaction? {
        guard let id = keyIndex[key] else { return nil }
        return transactions.first { $0.id == id }
    }

    public func transactions(for childID: UUID) -> [RewardTransaction] {
        transactions.filter { $0.childID == childID }
    }

    /// Transactions that still point at an event that exists.
    public func transactions(linkedTo sourceEventID: UUID) -> [RewardTransaction] {
        transactions.filter { $0.sourceEventID == sourceEventID }
    }

    /// Transactions whose source event has been deleted by a caregiver. They
    /// keep their stars; see `RewardService.reconcile`.
    public var orphanedTransactions: [RewardTransaction] {
        transactions.filter { $0.sourceEventID == nil && $0.reason.isEventLinked }
    }

    /// Total stars in the ledger, summed rather than stored.
    public var totalStars: Int {
        transactions.reduce(0) { $0 + max(0, $1.quantity) }
    }

    /// Total stars for one child, summed rather than stored.
    public func totalStars(for childID: UUID) -> Int {
        transactions.reduce(0) { $0 + ($1.childID == childID ? max(0, $1.quantity) : 0) }
    }

    // MARK: - Appending

    /// Appends a transaction unless its key is already present.
    ///
    /// The return value distinguishes "already had it" from "refused it", which
    /// matters at the call site: a duplicate is a normal, expected retry and
    /// must not surface as an error, while a non-positive quantity is a caller
    /// bug worth logging.
    @discardableResult
    public mutating func append(_ transaction: RewardTransaction) -> RewardAppendResult {
        guard transaction.quantity > 0 else { return .rejectedNonPositiveQuantity }
        if let existing = self.transaction(forKey: transaction.idempotencyKey) {
            return .duplicate(existing: existing)
        }
        transactions.append(transaction)
        keyIndex[transaction.idempotencyKey] = transaction.id
        return .awarded(transaction)
    }

    /// Rebuilds the ledger from a transformed copy of its rows.
    ///
    /// Used by reconciliation, which rewrites `sourceEventID` links without ever
    /// touching `quantity`. Kept `internal` so no caller outside the reward
    /// system can use it as a back door to drop rows.
    func replacingRows(_ transform: (RewardTransaction) -> RewardTransaction) -> RewardLedger {
        RewardLedger(transactions.map(transform))
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case transactions }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rows = try container.decode([RewardTransaction].self, forKey: .transactions)
        self.init(rows)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(transactions, forKey: .transactions)
    }
}

/// What happened when a star was offered to the ledger.
public enum RewardAppendResult: Hashable, Sendable {
    /// A new transaction was written.
    case awarded(RewardTransaction)
    /// The key was already present. The existing transaction is returned so the
    /// caller can show the same celebration it would have shown the first time.
    case duplicate(existing: RewardTransaction)
    /// A quantity of zero or less was offered. Nothing was written.
    case rejectedNonPositiveQuantity

    /// The transaction the child ends up with, whether it was just written or
    /// was already there. `nil` only when nothing was written at all.
    public var transaction: RewardTransaction? {
        switch self {
        case .awarded(let transaction): transaction
        case .duplicate(let existing): existing
        case .rejectedNonPositiveQuantity: nil
        }
    }

    /// True only for a first write, so the celebration animation plays once.
    public var isNewlyAwarded: Bool {
        if case .awarded = self { return true }
        return false
    }
}

extension RewardReason {
    /// Whether a star for this reason normally carries a `sourceEventID`.
    ///
    /// Used to tell "this reward never had an event" apart from "this reward's
    /// event was deleted", which the ledger otherwise represents identically.
    public var isEventLinked: Bool {
        switch self {
        case .triedThePotty, .completedRoutine, .washedHands, .toldAGrownUp: true
        case .completedQuiz, .completedGame, .answeredPottyPause: false
        }
    }
}
