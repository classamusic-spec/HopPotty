import Foundation

/// Awards Hop Stars and answers questions about them.
///
/// The service owns a `RewardLedger` and never a running total. Every number it
/// reports is derived from the rows, so a crash mid-write can lose *an award*
/// (which the next attempt re-adds) but can never corrupt *a balance*.
///
/// Three rules are structural here rather than checked at runtime:
///
/// 1. There is no method that removes, reduces or expires a star.
/// 2. `RewardReason` has no case an accident could map to, and
///    `RewardService.reason(for:)` returns `nil` for `.accident`, so the reward
///    path cannot be reached from an accident even by mistake.
/// 3. Awarding is keyed, not counted, so retries collapse.
public struct RewardService: Sendable {
    /// The ledger this service reads and appends to.
    public private(set) var ledger: RewardLedger

    /// Calendar used for day-scoped idempotency keys. Injectable so tests are
    /// not at the mercy of the machine's time zone.
    public let calendar: Calendar

    public init(ledger: RewardLedger = RewardLedger(), calendar: Calendar = .current) {
        self.ledger = ledger
        self.calendar = calendar
    }

    // MARK: - Awarding

    /// Awards one star for `reason`, returning `nil` when this exact award has
    /// already been recorded.
    ///
    /// The idempotency key is derived (see `RewardIdempotency`): from
    /// `sourceEventID` when there is one, otherwise from the local calendar day.
    /// Nothing about the key depends on *when the attempt happens*, so a routine
    /// that completes, crashes the app, and is retried on relaunch produces one
    /// star, not two.
    ///
    /// `nil` is the normal, quiet answer for a duplicate. The caller that wants
    /// to re-show the celebration for the already-awarded star should use
    /// `awardResult(...)` and read `.duplicate(existing:)`.
    @discardableResult
    public mutating func award(
        reason: RewardReason,
        childID: UUID,
        sourceEventID: UUID? = nil,
        at date: Date = Date()
    ) -> RewardTransaction? {
        let scope: RewardScope = sourceEventID.map { RewardScope.event($0) } ?? .day(date)
        let result = awardResult(reason: reason, childID: childID, scope: scope, at: date)
        guard case .awarded(let transaction) = result else { return nil }
        return transaction
    }

    /// Awarding with the full outcome, an explicit scope, and an optional
    /// override quantity.
    ///
    /// `quantity` defaults to `reason.defaultQuantity`. A caller that passes
    /// zero or a negative number gets `.rejectedNonPositiveQuantity` and nothing
    /// is written: stars are a currency that only ever goes up, so a
    /// "zero-star award" and a "negative award" are both malformed, not a way of
    /// expressing a penalty.
    @discardableResult
    public mutating func awardResult(
        reason: RewardReason,
        childID: UUID,
        scope: RewardScope,
        quantity: Int? = nil,
        at date: Date = Date(),
        id: UUID = UUID()
    ) -> RewardAppendResult {
        let amount = quantity ?? reason.defaultQuantity
        guard amount > 0 else { return .rejectedNonPositiveQuantity }

        let key = RewardIdempotency.key(
            reason: reason,
            childID: childID,
            scope: scope,
            calendar: calendar
        )
        if let existing = ledger.transaction(forKey: key) { return .duplicate(existing: existing) }

        let transaction = RewardTransaction(
            id: id,
            childID: childID,
            timestamp: date,
            reason: reason,
            quantity: amount,
            sourceEventID: scope.eventID,
            idempotencyKey: key
        )
        return ledger.append(transaction)
    }

    /// Awards the star a potty event earns, if it earns one.
    ///
    /// This is the only place event kinds meet the reward system, and it is
    /// where contract rule 3 lives: `.accident` maps to no reason, so it returns
    /// `nil` and nothing is written. An accident is a neutral timeline fact —
    /// the child is neither rewarded nor un-rewarded for it.
    @discardableResult
    public mutating func award(for event: PottyEvent, at date: Date? = nil) -> RewardTransaction? {
        guard let reason = Self.reason(for: event.kind) else { return nil }
        return award(
            reason: reason,
            childID: event.childID,
            sourceEventID: event.id,
            at: date ?? event.timestamp
        )
    }

    /// The reward a potty event earns, or `nil` when it earns none.
    ///
    /// `tried`, `pee` and `poop` all map to the same reason and the same single
    /// star. Paying more for `pee` than for `tried` would make the star a reward
    /// for a biological outcome, which contract rule 1 forbids: the child is
    /// rewarded for going and trying, full stop.
    public static func reason(for kind: PottyEventKind) -> RewardReason? {
        switch kind {
        case .tried, .pee, .poop: .triedThePotty
        case .accident: nil
        }
    }

    // MARK: - Totals

    /// Total stars for a child, derived from the ledger. Never stored.
    public static func totalStars(for childID: UUID, in ledger: RewardLedger) -> Int {
        ledger.totalStars(for: childID)
    }

    /// Total stars for a child across any sequence of transactions, so callers
    /// holding a filtered slice do not have to build a ledger to count it.
    public static func totalStars(
        for childID: UUID,
        in transactions: some Sequence<RewardTransaction>
    ) -> Int {
        transactions.reduce(0) { $0 + ($1.childID == childID ? max(0, $1.quantity) : 0) }
    }

    /// Total stars for a child in this service's own ledger.
    public func totalStars(for childID: UUID) -> Int { ledger.totalStars(for: childID) }

    // MARK: - Reconciliation

    /// Reconciles the ledger after a caregiver deletes potty events.
    ///
    /// **The star earned from a deleted event is not removed.** This is a hard
    /// product rule, not an implementation convenience:
    ///
    /// * The star was earned by something the child actually did. The parent is
    ///   correcting *their own record* — a mis-tap, a duplicate row, a visit
    ///   logged against the wrong sibling — and the child's effort did not
    ///   un-happen because the row did.
    /// * A pond that shrinks is a punishment the child cannot attribute to
    ///   anything they did, delivered by an adult they trust, in an app they
    ///   were told is theirs. That is loss aversion aimed at a three-year-old.
    /// * Contract rule 2 makes the ledger append-only, so "take the star back"
    ///   is not representable here anyway, and rule 7 forbids the loss-aversion
    ///   mechanic that would motivate it.
    ///
    /// So the link is broken and the star stays. The transaction keeps its id,
    /// its timestamp, its quantity and — importantly — its idempotency key, so a
    /// queued retry for the deleted event still collapses instead of re-awarding.
    /// A `nil` `sourceEventID` on an event-linked reason *is* the orphan marker.
    public static func reconcile(
        ledger: RewardLedger,
        against survivingEventIDs: Set<UUID>
    ) -> RewardReconciliation {
        var orphaned: [UUID] = []
        let reconciled = ledger.replacingRows { transaction in
            guard let source = transaction.sourceEventID, !survivingEventIDs.contains(source) else {
                return transaction
            }
            orphaned.append(transaction.id)
            return RewardTransaction(
                id: transaction.id,
                childID: transaction.childID,
                timestamp: transaction.timestamp,
                reason: transaction.reason,
                // Unchanged, deliberately. Orphaning breaks a link; it never
                // touches the star.
                quantity: transaction.quantity,
                sourceEventID: nil,
                idempotencyKey: transaction.idempotencyKey
            )
        }
        return RewardReconciliation(
            ledger: reconciled,
            orphanedTransactionIDs: orphaned,
            starsBefore: ledger.totalStars,
            starsAfter: reconciled.totalStars
        )
    }

    /// Reconciles against the events that still exist.
    public static func reconcile(
        ledger: RewardLedger,
        against survivingEvents: some Sequence<PottyEvent>
    ) -> RewardReconciliation {
        reconcile(ledger: ledger, against: Set(survivingEvents.map(\.id)))
    }

    /// Reconciles this service's ledger in place and reports what changed.
    @discardableResult
    public mutating func reconcile(against survivingEventIDs: Set<UUID>) -> RewardReconciliation {
        let result = Self.reconcile(ledger: ledger, against: survivingEventIDs)
        ledger = result.ledger
        return result
    }
}

/// The outcome of reconciling a ledger against the surviving potty events.
public struct RewardReconciliation: Hashable, Sendable {
    /// The ledger after orphaning. Same rows, same stars, fewer links.
    public let ledger: RewardLedger
    /// Transactions whose `sourceEventID` was cleared because the event is gone.
    public let orphanedTransactionIDs: [UUID]
    public let starsBefore: Int
    public let starsAfter: Int

    public init(
        ledger: RewardLedger,
        orphanedTransactionIDs: [UUID],
        starsBefore: Int,
        starsAfter: Int
    ) {
        self.ledger = ledger
        self.orphanedTransactionIDs = orphanedTransactionIDs
        self.starsBefore = starsBefore
        self.starsAfter = starsAfter
    }

    /// Always zero. Exposed so the invariant is visible in a debugger and
    /// assertable in a test, rather than being an unwritten promise.
    public var starsRemoved: Int { starsBefore - starsAfter }

    public var orphanedCount: Int { orphanedTransactionIDs.count }
}

extension RewardScope {
    /// The event this scope refers to, if it refers to one. Lets `awardResult`
    /// fill `sourceEventID` without the caller passing it twice.
    var eventID: UUID? {
        if case .event(let id) = self { return id }
        return nil
    }
}
