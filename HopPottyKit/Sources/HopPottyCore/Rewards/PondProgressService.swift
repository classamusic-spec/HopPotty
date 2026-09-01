import Foundation

/// Turns a star total into a pond, and works out what a single star just did.
///
/// The service is stateless: give it a number of stars and it tells you what the
/// pond looks like. That is what makes the pond safe — it is a *view* of the
/// ledger, so it inherits the ledger's guarantee that stars only ever go up, and
/// there is nowhere for a separate, driftable "unlocked items" number to live.
///
/// Nothing here can take an item away. `apply(stars:to:at:)` unions; it never
/// subtracts. Passing a *lower* star total than last time — which happens for
/// real, when a caregiver deletes events and the app recounts — leaves the pond
/// exactly as it was. See `RewardService.reconcile` for why that is the rule.
public struct PondProgressService: Sendable {

    public init() {}

    // MARK: - Building a pond

    /// The pond for a child with `stars` stars, dating every unlock to `date`.
    ///
    /// Use this for a first build or a rebuild from scratch. To keep the real
    /// unlock dates a child already has, use `apply(stars:to:at:)`.
    public func progress(forStars stars: Int, childID: UUID, at date: Date = Date()) -> PondProgress {
        var unlocked: [PondItemID: Date] = [:]
        for item in PondCatalog.unlockedItems(atStars: stars) {
            unlocked[item.id] = date
        }
        return PondProgress(childID: childID, unlocked: unlocked)
    }

    /// Applies a star total to an existing pond and reports what is new.
    ///
    /// Items already unlocked keep their original unlock date, so the pond
    /// remembers when each thing arrived. Items the total no longer covers are
    /// **kept** — there is no branch in this method that removes a key.
    public func apply(
        stars: Int,
        to progress: PondProgress,
        at date: Date = Date()
    ) -> PondUnlockOutcome {
        var updated = progress
        var newlyUnlocked: [PondItem] = []

        for item in PondCatalog.unlockedItems(atStars: stars) where updated.unlocked[item.id] == nil {
            updated.unlocked[item.id] = date
            newlyUnlocked.append(item)
        }

        return PondUnlockOutcome(
            progress: updated,
            newlyUnlocked: newlyUnlocked,
            nextUp: PondCatalog.progressTowardNext(stars: stars)
        )
    }

    // MARK: - "What did this star just unlock?"

    /// Items that crossed their threshold between two totals, in unlock order.
    ///
    /// Half-open on the low side and closed on the high side: an item priced
    /// exactly at `newStars` counts as unlocked, an item priced exactly at
    /// `previousStars` was already theirs.
    public func newlyUnlocked(from previousStars: Int, to newStars: Int) -> [PondItem] {
        guard newStars > previousStars else { return [] }
        return PondCatalog.items.filter { $0.starCost > previousStars && $0.starCost <= newStars }
    }

    /// What the star in `transaction` unlocked, given the total *after* it landed.
    ///
    /// Usually empty — most stars move the bar without finishing it, and that is
    /// fine. When it is non-empty the caller plays the celebration once, for the
    /// items returned here.
    public func unlocked(by transaction: RewardTransaction, totalAfter: Int) -> [PondItem] {
        newlyUnlocked(from: totalAfter - max(0, transaction.quantity), to: totalAfter)
    }

    /// The celebration payload for one award: the updated pond, what appeared,
    /// and what is coming next.
    public func celebrate(
        _ transaction: RewardTransaction,
        totalAfter: Int,
        pond: PondProgress
    ) -> PondUnlockOutcome {
        apply(stars: totalAfter, to: pond, at: transaction.timestamp)
    }

    // MARK: - Convenience

    /// How far this child is toward the next unlock.
    public func progressTowardNext(stars: Int) -> PondUnlockProgress {
        PondCatalog.progressTowardNext(stars: stars)
    }

    /// The next item, or `nil` when the pond is complete.
    public func nextUnlock(after stars: Int) -> PondItem? {
        PondCatalog.nextUnlock(after: stars)
    }

    /// The pond a child would have from their whole ledger.
    public func progress(from ledger: RewardLedger, childID: UUID, at date: Date = Date()) -> PondProgress {
        progress(forStars: ledger.totalStars(for: childID), childID: childID, at: date)
    }
}

/// The result of applying a star total to a pond.
public struct PondUnlockOutcome: Hashable, Sendable {
    /// The pond after the total was applied. Never smaller than the one in.
    public let progress: PondProgress
    /// Items that appeared just now, in unlock order. Drives the celebration.
    public let newlyUnlocked: [PondItem]
    /// What the child is working toward next.
    public let nextUp: PondUnlockProgress

    public init(progress: PondProgress, newlyUnlocked: [PondItem], nextUp: PondUnlockProgress) {
        self.progress = progress
        self.newlyUnlocked = newlyUnlocked
        self.nextUp = nextUp
    }

    /// Whether there is anything to celebrate. A quiet star is still a star.
    public var hasCelebration: Bool { !newlyUnlocked.isEmpty }

    /// The single item to build the celebration around when several landed at
    /// once — the last one, which is the most expensive and the most surprising.
    public var headlineItem: PondItem? { newlyUnlocked.last }
}
