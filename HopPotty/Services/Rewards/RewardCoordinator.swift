import Foundation
import HopPottyCore

/// What happened when a star was offered.
struct RewardOutcome: Sendable {
    /// The transaction the child ends up with — newly written or already there.
    /// `nil` only when nothing was awarded at all.
    let transaction: RewardTransaction?
    /// True only for a first write, so the celebration plays once.
    let isNewlyAwarded: Bool
    /// The child's star total after this award, summed from rows.
    let totalStars: Int
    /// The pond after the total was applied, and anything that just appeared.
    let pond: PondUnlockOutcome?

    /// Nothing was awarded — an accident, or a zero quantity.
    static let none = RewardOutcome(
        transaction: nil, isNewlyAwarded: false, totalStars: 0, pond: nil
    )

    var hasCelebration: Bool { isNewlyAwarded && (pond?.hasCelebration ?? false) }
}

/// Joins the pure reward logic in `HopPottyCore` to the store.
///
/// The rules all live in Core — `RewardService` decides what earns a star,
/// `RewardIdempotency` decides what makes two awards the same award, and
/// `PondProgressService` decides what a total buys. This type does the two
/// things Core cannot: read the ledger from disk and write the new row back.
///
/// It deliberately has no `remove`, `spend`, `reset` or `recalculate` method.
/// The only code in HopPotty that deletes a star is
/// `SwiftDataRewardRepository.deleteAll(for:)`, reachable solely from the two
/// parent-gated data-deletion actions.
@MainActor
final class RewardCoordinator {
    private let rewards: any RewardRepository
    private let pondStore: any PondProgressRepository
    private let clock: any HopClock
    private let pondService = PondProgressService()

    init(
        rewards: any RewardRepository,
        pond: any PondProgressRepository,
        clock: any HopClock = SystemClock()
    ) {
        self.rewards = rewards
        self.pondStore = pond
        self.clock = clock
    }

    // MARK: Awarding

    /// Awards the star a potty event earns, if it earns one.
    ///
    /// An `.accident` earns none: `RewardService.reason(for:)` returns `nil`,
    /// this returns `.none`, and no row is written. The event still appears on
    /// the timeline — it is a neutral fact, and it neither adds nor removes
    /// anything (contract rule 3).
    @discardableResult
    func award(for event: PottyEvent) async throws -> RewardOutcome {
        guard let reason = RewardService.reason(for: event.kind) else { return .none }
        return try await award(
            reason: reason,
            childID: event.childID,
            scope: .event(event.id),
            at: event.timestamp
        )
    }

    /// Awards one star for a reason, collapsing retries.
    ///
    /// The scope is what makes a retry safe: it is derived from something
    /// already on disk (an event id, a session id) or from the calendar day, so
    /// an award attempted, crashed and retried produces one star rather than
    /// two. See `RewardIdempotency`.
    @discardableResult
    func award(
        reason: RewardReason,
        childID: UUID,
        scope: RewardScope,
        at date: Date? = nil
    ) async throws -> RewardOutcome {
        let when = date ?? clock.now
        var service = RewardService(
            ledger: try await rewards.ledger(for: childID),
            calendar: clock.calendar
        )
        let result = service.awardResult(reason: reason, childID: childID, scope: scope, at: when)

        switch result {
        case .rejectedNonPositiveQuantity:
            return .none

        case .duplicate(let existing):
            // The normal outcome of a retry. Report the same transaction so the
            // caller can re-show what it showed the first time, but with
            // `isNewlyAwarded` false so it does not celebrate twice.
            let total = try await rewards.totalStars(for: childID)
            return RewardOutcome(
                transaction: existing,
                isNewlyAwarded: false,
                totalStars: total,
                pond: try await applyPond(stars: total, childID: childID, at: existing.timestamp)
            )

        case .awarded(let transaction):
            // The store is the authority on duplication, not the in-memory
            // ledger: two devices are impossible here, but two rapid taps on
            // one device are not, and the unique index settles it.
            let stored = try await rewards.append(transaction)
            let isNew = stored.isNewlyAwarded
            let total = try await rewards.totalStars(for: childID)
            let pond = try await applyPond(stars: total, childID: childID, at: transaction.timestamp)
            if isNew {
                HopLog.persistence.info(
                    "star awarded child=\(HopLog.tag(for: childID), privacy: .public) reason=\(reason.rawValue, privacy: .public) total=\(total, privacy: .public)"
                )
            }
            return RewardOutcome(
                transaction: stored.transaction,
                isNewlyAwarded: isNew,
                totalStars: total,
                pond: pond
            )
        }
    }

    // MARK: Reading

    func totalStars(for childID: UUID) async throws -> Int {
        try await rewards.totalStars(for: childID)
    }

    func ledger(for childID: UUID) async throws -> RewardLedger {
        try await rewards.ledger(for: childID)
    }

    func pond(for childID: UUID) async throws -> PondProgress {
        try await pondStore.progress(for: childID)
    }

    /// How far the child is from the next decoration.
    func progressTowardNext(for childID: UUID) async throws -> PondUnlockProgress {
        pondService.progressTowardNext(stars: try await rewards.totalStars(for: childID))
    }

    /// Rebuilds a child's pond from their ledger.
    ///
    /// Used after a store recovery, when the pond row was lost but the ledger
    /// survived. The unlock *dates* cannot be recovered — they were only in the
    /// pond row — so everything is dated now. The child sees their whole pond,
    /// which is what matters; a caregiver sees today's date on decorations that
    /// arrived in July, which is a small, honest inaccuracy.
    @discardableResult
    func rebuildPond(for childID: UUID) async throws -> PondProgress {
        let total = try await rewards.totalStars(for: childID)
        let rebuilt = pondService.progress(forStars: total, childID: childID, at: clock.now)
        try await pondStore.save(rebuilt)
        HopLog.persistence.info(
            "pond rebuilt from ledger child=\(HopLog.tag(for: childID), privacy: .public) items=\(rebuilt.unlockedCount, privacy: .public)"
        )
        return rebuilt
    }

    // MARK: Pond

    /// Applies a star total to the stored pond and saves it if anything changed.
    ///
    /// `PondProgressService.apply` unions and never subtracts, so a *lower*
    /// total than last time — which happens for real, when a caregiver deletes
    /// events and the app recounts — leaves the pond exactly as it was.
    private func applyPond(stars: Int, childID: UUID, at date: Date) async throws -> PondUnlockOutcome {
        let current = try await pondStore.progress(for: childID)
        let outcome = pondService.apply(stars: stars, to: current, at: date)
        if outcome.progress != current {
            try await pondStore.save(outcome.progress)
        }
        return outcome
    }
}
