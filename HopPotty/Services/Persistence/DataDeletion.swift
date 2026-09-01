import Foundation
import HopPottyCore

// MARK: - Counts

/// Exactly what a destructive action touched.
///
/// Contract rule 6 says every destructive action "states exactly what will be
/// removed, with counts". This is that statement, as a value: the same type is
/// produced *before* the action to fill the confirmation sheet and *after* it to
/// report what actually happened, so the sentence a caregiver reads and the
/// sentence they get back cannot drift apart.
///
/// Every field is a number the caregiver can verify by looking at the app. There
/// is no "other" bucket and no total that includes something unnamed.
struct DeletionCounts: Equatable, Sendable {
    /// Rows on the timeline.
    var pottyEvents = 0
    /// Ledger rows removed. Non-zero only for "Reset rewards" and "Delete
    /// profile" — the two operations that explicitly say so.
    var rewardTransactions = 0
    /// Stars in those removed rows. Reported separately because "12 ledger
    /// entries" means nothing to a parent and "12 stars" means everything to a
    /// child.
    var starsRemoved = 0
    /// Stars kept even though their event was deleted. The number that makes
    /// "deleting this event will not cost Maya any stars" a promise with a
    /// figure attached.
    var starsKept = 0
    /// Reward rows whose link to a deleted event was broken. The stars stayed.
    var rewardsUnlinked = 0
    /// Pond decorations that will disappear from the scene.
    var pondItems = 0
    var schedules = 0
    var screenTimeConfigurations = 0
    /// Quiz *plays*, not rows.
    var quizCompletions = 0
    /// Game *plays*, not rows.
    var gameCompletions = 0
    var profiles = 0
    /// True when device-wide settings go back to their defaults.
    var resetsSettings = false

    /// Whether this action removes anything at all. A confirmation sheet for a
    /// no-op should say so rather than asking a frightening question about
    /// nothing.
    var removesNothing: Bool {
        pottyEvents == 0 && rewardTransactions == 0 && pondItems == 0 && schedules == 0
            && screenTimeConfigurations == 0 && quizCompletions == 0 && gameCompletions == 0
            && profiles == 0 && !resetsSettings
    }

    static func + (lhs: DeletionCounts, rhs: DeletionCounts) -> DeletionCounts {
        var sum = DeletionCounts()
        sum.pottyEvents = lhs.pottyEvents + rhs.pottyEvents
        sum.rewardTransactions = lhs.rewardTransactions + rhs.rewardTransactions
        sum.starsRemoved = lhs.starsRemoved + rhs.starsRemoved
        sum.starsKept = lhs.starsKept + rhs.starsKept
        sum.rewardsUnlinked = lhs.rewardsUnlinked + rhs.rewardsUnlinked
        sum.pondItems = lhs.pondItems + rhs.pondItems
        sum.schedules = lhs.schedules + rhs.schedules
        sum.screenTimeConfigurations = lhs.screenTimeConfigurations + rhs.screenTimeConfigurations
        sum.quizCompletions = lhs.quizCompletions + rhs.quizCompletions
        sum.gameCompletions = lhs.gameCompletions + rhs.gameCompletions
        sum.profiles = lhs.profiles + rhs.profiles
        sum.resetsSettings = lhs.resetsSettings || rhs.resetsSettings
        return sum
    }
}

// MARK: - Scope

/// The four destructive actions HopPotty offers. There are no others, and each
/// one has a different, precisely-worded receipt.
enum DeletionScope: Hashable, Sendable {
    /// **Clear history.** Removes potty events. Keeps the child, their stars,
    /// their pond and their schedule. Stars earned from deleted events are
    /// unlinked, never removed — see `RewardService.reconcile`.
    case childHistory(childID: UUID)

    /// **Reset rewards.** Removes the star ledger and the pond for one child.
    ///
    /// This is the only operation in HopPotty that removes a star, and it is
    /// data deletion rather than a game mechanic: a caregiver exercising control
    /// over records held about their family, on their device, behind the parent
    /// gate, after reading the count. Contract rule 2 governs the reward
    /// *system* — no outcome, no accident, no deleted event and no passage of
    /// time ever costs a child a star. It does not, and could not sensibly,
    /// forbid a family from deleting their own data.
    ///
    /// It is deliberately all-or-nothing. A selective "remove these three stars"
    /// would be a punishment mechanism with a data-management label on it.
    case childRewards(childID: UUID)

    /// **Delete child.** Everything belonging to one child, including the
    /// profile itself.
    case childProfile(childID: UUID)

    /// **Reset app.** Every child, every table, and settings back to defaults.
    case entireApp

    var childID: UUID? {
        switch self {
        case .childHistory(let id), .childRewards(let id), .childProfile(let id): id
        case .entireApp: nil
        }
    }

    /// For the log line. Never carries an identifier.
    var logName: String {
        switch self {
        case .childHistory: "childHistory"
        case .childRewards: "childRewards"
        case .childProfile: "childProfile"
        case .entireApp: "entireApp"
        }
    }
}

// MARK: - Plan and receipt

/// What a destructive action *will* do. Built before anything is touched.
struct DeletionPlan: Sendable {
    let scope: DeletionScope
    /// The nickname, for the confirmation sentence. `nil` when the child has no
    /// nickname or the scope is the whole app, and the copy layer falls back to
    /// a neutral phrasing. Held in memory only — never logged, never exported.
    let childNickname: String?
    let counts: DeletionCounts
    /// When the plan was built. A plan is quoted back in a sheet; if the user
    /// leaves it open for an hour and a routine adds four events, the counts are
    /// stale and `DataDeletionService.perform` re-counts before acting.
    let preparedAt: Date
}

/// What a destructive action *did*. Returned from `perform`.
struct DeletionReceipt: Sendable {
    let scope: DeletionScope
    let childNickname: String?
    /// Actual rows removed, recounted at the moment of deletion.
    let counts: DeletionCounts
    let completedAt: Date
    /// True when the plan the caregiver approved described different numbers
    /// than the deletion performed — because something was logged in between.
    /// The UI can mention it; nothing is wrong, but a receipt that silently
    /// disagrees with the sheet is how trust is lost.
    let differedFromPlan: Bool
}

// MARK: - Service

/// Performs the four destructive actions, and counts everything.
@MainActor
final class DataDeletionService {
    private let repositories: RepositorySet
    private let clock: any HopClock

    init(repositories: RepositorySet, clock: any HopClock = SystemClock()) {
        self.repositories = repositories
        self.clock = clock
    }

    // MARK: Planning

    /// Counts what `scope` would remove, without removing anything.
    func plan(for scope: DeletionScope) async throws -> DeletionPlan {
        let counts: DeletionCounts
        switch scope {
        case .childHistory(let childID):
            counts = try await historyCounts(for: childID)
        case .childRewards(let childID):
            counts = try await rewardCounts(for: childID)
        case .childProfile(let childID):
            counts = try await profileCounts(for: childID)
        case .entireApp:
            counts = try await appCounts()
        }
        return DeletionPlan(
            scope: scope,
            childNickname: try await nickname(for: scope.childID),
            counts: counts,
            preparedAt: clock.now
        )
    }

    private func historyCounts(for childID: UUID) async throws -> DeletionCounts {
        var counts = DeletionCounts()
        counts.pottyEvents = try await repositories.events.count(for: childID)
        // Nothing is removed from the ledger, so the interesting numbers are the
        // ones that reassure: how many stars stay, and how many links break.
        let ledger = try await repositories.rewards.ledger(for: childID)
        let survivingIDs: Set<UUID> = [] // every event goes
        let reconciliation = RewardService.reconcile(ledger: ledger, against: survivingIDs)
        counts.rewardsUnlinked = reconciliation.orphanedCount
        counts.starsKept = reconciliation.starsAfter
        return counts
    }

    private func rewardCounts(for childID: UUID) async throws -> DeletionCounts {
        var counts = DeletionCounts()
        counts.rewardTransactions = try await repositories.rewards.count(for: childID)
        counts.starsRemoved = try await repositories.rewards.totalStars(for: childID)
        counts.pondItems = try await repositories.pond.unlockedCount(for: childID)
        return counts
    }

    private func profileCounts(for childID: UUID) async throws -> DeletionCounts {
        var counts = DeletionCounts()
        counts.pottyEvents = try await repositories.events.count(for: childID)
        counts.rewardTransactions = try await repositories.rewards.count(for: childID)
        counts.starsRemoved = try await repositories.rewards.totalStars(for: childID)
        counts.pondItems = try await repositories.pond.unlockedCount(for: childID)
        counts.schedules = try await repositories.schedules.count(for: childID)
        counts.screenTimeConfigurations = try await repositories.screenTime.count(for: childID)
        counts.quizCompletions = try await repositories.quizzes.count(for: childID)
        counts.gameCompletions = try await repositories.games.count(for: childID)
        counts.profiles = try await repositories.profiles.profile(id: childID) == nil ? 0 : 1
        return counts
    }

    private func appCounts() async throws -> DeletionCounts {
        var total = DeletionCounts()
        for profile in try await repositories.profiles.allProfiles() {
            total = total + (try await profileCounts(for: profile.id))
        }
        total.resetsSettings = true
        return total
    }

    private func nickname(for childID: UUID?) async throws -> String? {
        guard let childID else { return nil }
        return try await repositories.profiles.profile(id: childID)?.nickname
    }

    // MARK: Performing

    /// Carries out a planned deletion.
    ///
    /// Takes the plan and a `ParentAuthorization` rather than a `Bool`: the
    /// signature is the reminder that a destructive action needs both a gate and
    /// a sentence the caregiver has read.
    ///
    /// The counts are recomputed here, not taken from the plan, so the receipt
    /// describes what was actually removed even if the app logged an event while
    /// the sheet was open.
    @discardableResult
    func perform(
        _ plan: DeletionPlan,
        authorization: ParentAuthorization
    ) async throws -> DeletionReceipt {
        guard authorization.isValid(at: clock.now) else { throw DeletionError.authorizationExpired }
        guard authorization.reason == .deleteData else { throw DeletionError.wrongAuthorization }

        let counts: DeletionCounts
        switch plan.scope {
        case .childHistory(let childID):
            counts = try await deleteHistory(for: childID)
        case .childRewards(let childID):
            counts = try await resetRewards(for: childID)
        case .childProfile(let childID):
            counts = try await deleteProfile(childID)
        case .entireApp:
            counts = try await resetApp()
        }

        HopLog.persistence.notice(
            "deletion performed scope=\(plan.scope.logName, privacy: .public) events=\(counts.pottyEvents, privacy: .public) rewards=\(counts.rewardTransactions, privacy: .public) unlinked=\(counts.rewardsUnlinked, privacy: .public) profiles=\(counts.profiles, privacy: .public)"
        )

        return DeletionReceipt(
            scope: plan.scope,
            childNickname: plan.childNickname,
            counts: counts,
            completedAt: clock.now,
            differedFromPlan: counts != plan.counts
        )
    }

    /// Removes the timeline, keeps the stars.
    ///
    /// Order matters: the event ids are captured *before* the rows go, because
    /// once they are gone there is nothing left to reconcile the ledger against.
    private func deleteHistory(for childID: UUID) async throws -> DeletionCounts {
        var counts = DeletionCounts()
        let eventIDs = try await repositories.events.eventIDs(for: childID)
        counts.pottyEvents = try await repositories.events.deleteAll(for: childID)
        counts.rewardsUnlinked = try await repositories.rewards
            .orphanTransactions(forDeletedEventIDs: eventIDs)
        counts.starsKept = try await repositories.rewards.totalStars(for: childID)
        // Stated explicitly rather than left implicit: this operation removes no
        // stars, and the receipt says so with a zero.
        counts.starsRemoved = 0
        return counts
    }

    private func resetRewards(for childID: UUID) async throws -> DeletionCounts {
        var counts = DeletionCounts()
        counts.starsRemoved = try await repositories.rewards.totalStars(for: childID)
        counts.pondItems = try await repositories.pond.unlockedCount(for: childID)
        counts.rewardTransactions = try await repositories.rewards.deleteAll(for: childID)
        // The pond is a view of the ledger, so it has to go with it. Leaving a
        // pond standing over an empty ledger would rebuild itself as empty on
        // the next award and the decorations would vanish later, unexplained.
        _ = try await repositories.pond.deleteAll(for: childID)
        return counts
    }

    private func deleteProfile(_ childID: UUID) async throws -> DeletionCounts {
        var counts = DeletionCounts()
        counts.starsRemoved = try await repositories.rewards.totalStars(for: childID)
        counts.pondItems = try await repositories.pond.unlockedCount(for: childID)
        counts.quizCompletions = try await repositories.quizzes.count(for: childID)
        counts.gameCompletions = try await repositories.games.count(for: childID)

        counts.pottyEvents = try await repositories.events.deleteAll(for: childID)
        counts.rewardTransactions = try await repositories.rewards.deleteAll(for: childID)
        _ = try await repositories.pond.deleteAll(for: childID)
        counts.schedules = try await repositories.schedules.deleteAll(for: childID)
        counts.screenTimeConfigurations = try await repositories.screenTime.deleteAll(for: childID)
        _ = try await repositories.quizzes.deleteAll(for: childID)
        _ = try await repositories.games.deleteAll(for: childID)
        counts.profiles = try await repositories.profiles.deleteProfile(id: childID)

        // Safety net for the table somebody adds next year and forgets to name
        // above. `childScoped` is the full list; if anything still holds rows
        // for a child who was just deleted, that is a leak of exactly the data
        // a caregiver asked to be rid of, and it must be loud.
        try await assertNothingRemains(for: childID)
        return counts
    }

    /// Verifies that no child-scoped table still holds rows. Logs a fault and
    /// sweeps rather than throwing: failing the deletion after it has mostly
    /// happened would leave the caregiver worse off than finishing it.
    private func assertNothingRemains(for childID: UUID) async throws {
        for repository in repositories.childScoped {
            let remaining = try await repository.count(for: childID)
            guard remaining > 0 else { continue }
            HopLog.persistence.fault(
                "residual rows after profile deletion count=\(remaining, privacy: .public)"
            )
            _ = try await repository.deleteAll(for: childID)
        }
    }

    private func resetApp() async throws -> DeletionCounts {
        var total = DeletionCounts()
        for profile in try await repositories.profiles.allProfiles() {
            total = total + (try await deleteProfile(profile.id))
        }
        try await repositories.settings.reset()
        total.resetsSettings = true
        return total
    }
}

enum DeletionError: Error, Equatable {
    /// The parent gate was passed too long ago. Ask again rather than acting on
    /// an approval given before a nap.
    case authorizationExpired
    /// The gate was passed for something else — opening the parent area, say.
    /// A destructive action needs an approval that was about destruction.
    case wrongAuthorization
}
