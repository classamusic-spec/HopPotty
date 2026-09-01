import Foundation
import HopPottyCore
import SwiftData

// MARK: - Base

/// Shared plumbing for the SwiftData repositories.
///
/// Holds the one main-actor `ModelContext` and turns SwiftData's throwing API
/// into HopPotty's four-case `PersistenceError`, logging the real failure under
/// `persistence` with nothing but a domain and a code.
@MainActor
class SwiftDataRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            HopLog.persistence.error("fetch failed error=\(HopLog.safeDescription(error), privacy: .public)")
            throw PersistenceError.readFailed
        }
    }

    func fetchOne<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> T? {
        var limited = descriptor
        limited.fetchLimit = 1
        return try fetch(limited).first
    }

    func fetchCount<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> Int {
        do {
            return try context.fetchCount(descriptor)
        } catch {
            HopLog.persistence.error("count failed error=\(HopLog.safeDescription(error), privacy: .public)")
            throw PersistenceError.readFailed
        }
    }

    /// Saves, or throws `.saveFailed`.
    ///
    /// Autosave is off (see `PersistenceController.mainContext`), so this is the
    /// only moment anything reaches disk. A failure here is a failure the caller
    /// can still tell the caregiver about, which is the whole point of not
    /// letting an autosave fail silently in the background.
    func saveChanges() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            HopLog.persistence.error("save failed error=\(HopLog.safeDescription(error), privacy: .public)")
            throw PersistenceError.saveFailed
        }
    }

    /// Deletes every row a descriptor matches and returns the count.
    ///
    /// Fetch-then-delete rather than `context.delete(model:where:)` for two
    /// reasons: the batch form does not report how many rows it removed, and the
    /// count *is* the product requirement — a confirmation sheet that cannot say
    /// "47 potty events" is not a confirmation, it is a shrug.
    func deleteAll<T: PersistentModel>(matching descriptor: FetchDescriptor<T>) throws -> Int {
        let rows = try fetch(descriptor)
        for row in rows { context.delete(row) }
        try saveChanges()
        return rows.count
    }
}

// MARK: - Child profiles

@MainActor
final class SwiftDataChildProfileRepository: SwiftDataRepository, ChildProfileRepository {

    func allProfiles() async throws -> [ChildProfile] {
        let descriptor = FetchDescriptor<StoredChildProfile>(
            sortBy: [SortDescriptor(\StoredChildProfile.createdAt, order: .forward)]
        )
        return try fetch(descriptor).map(\.domainValue)
    }

    func profile(id: UUID) async throws -> ChildProfile? {
        try storedProfile(id: id)?.domainValue
    }

    func save(_ profile: ChildProfile) async throws {
        if let existing = try storedProfile(id: profile.id) {
            existing.apply(profile)
        } else {
            context.insert(StoredChildProfile(profile))
        }
        try saveChanges()
        // A profile write is worth a line — it is how a support conversation
        // establishes "there are two children on this device" — but the tag is
        // per-launch and the nickname is not in it.
        HopLog.persistence.info("profile saved child=\(HopLog.tag(for: profile.id), privacy: .public)")
    }

    @discardableResult
    func deleteProfile(id: UUID) async throws -> Int {
        guard let existing = try storedProfile(id: id) else { return 0 }
        context.delete(existing)
        try saveChanges()
        return 1
    }

    func profileCount() async throws -> Int {
        try fetchCount(FetchDescriptor<StoredChildProfile>())
    }

    private func storedProfile(id: UUID) throws -> StoredChildProfile? {
        let target = id
        return try fetchOne(
            FetchDescriptor<StoredChildProfile>(predicate: #Predicate { $0.id == target })
        )
    }
}

// MARK: - Potty events

@MainActor
final class SwiftDataPottyEventRepository: SwiftDataRepository, PottyEventRepository {

    func events(matching query: PottyEventQuery) async throws -> [PottyEvent] {
        var descriptor = Self.descriptor(for: query)
        descriptor.sortBy = [
            SortDescriptor(\StoredPottyEvent.timestamp, order: query.newestFirst ? .reverse : .forward)
        ]
        if let limit = query.limit { descriptor.fetchLimit = max(0, limit) }
        return try fetch(descriptor).map(\.domainValue)
    }

    func event(id: UUID) async throws -> PottyEvent? {
        try storedEvent(id: id)?.domainValue
    }

    func save(_ event: PottyEvent) async throws {
        if let existing = try storedEvent(id: event.id) {
            existing.apply(event)
        } else {
            context.insert(StoredPottyEvent(event))
        }
        try saveChanges()
        // The *kind* is not logged. "poop at 14:03" with a stable child tag is a
        // health record; "an event was written for this child" is a diagnostic.
        HopLog.persistence.debug("event saved child=\(HopLog.tag(for: event.childID), privacy: .public)")
    }

    @discardableResult
    func delete(ids: [UUID]) async throws -> Int {
        var removed = 0
        // One fetch per id rather than a `contains` predicate: the batch here is
        // whatever a caregiver selected by hand, so it is tens of rows at most,
        // and a per-id fetch has no predicate-translation surprises.
        for id in ids {
            guard let row = try storedEvent(id: id) else { continue }
            context.delete(row)
            removed += 1
        }
        try saveChanges()
        return removed
    }

    func count(for childID: UUID) async throws -> Int {
        try fetchCount(Self.descriptor(for: PottyEventQuery(childID: childID)))
    }

    func count(for childID: UUID, in window: DateWindow) async throws -> Int {
        try fetchCount(Self.descriptor(for: PottyEventQuery(childID: childID, window: window)))
    }

    func eventIDs(for childID: UUID) async throws -> Set<UUID> {
        let rows = try fetch(Self.descriptor(for: PottyEventQuery(childID: childID)))
        return Set(rows.map(\.id))
    }

    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        try deleteAll(matching: Self.descriptor(for: PottyEventQuery(childID: childID)))
    }

    private func storedEvent(id: UUID) throws -> StoredPottyEvent? {
        let target = id
        return try fetchOne(
            FetchDescriptor<StoredPottyEvent>(predicate: #Predicate { $0.id == target })
        )
    }

    /// The one place a child-scoped event predicate is built.
    ///
    /// Every read, count and delete goes through here, so "is this query scoped
    /// to one child?" has a single answer, and a future workaround for a
    /// predicate-translation bug is a change to one function.
    private static func descriptor(for query: PottyEventQuery) -> FetchDescriptor<StoredPottyEvent> {
        let child = query.childID
        guard let window = query.window else {
            return FetchDescriptor<StoredPottyEvent>(predicate: #Predicate { $0.childID == child })
        }
        // Half-open, matching `DateWindow`: an event at exactly midnight belongs
        // to the day starting there and to no other.
        let start = window.start
        let end = window.end
        return FetchDescriptor<StoredPottyEvent>(
            predicate: #Predicate {
                $0.childID == child && $0.timestamp >= start && $0.timestamp < end
            }
        )
    }
}

// MARK: - Rewards

@MainActor
final class SwiftDataRewardRepository: SwiftDataRepository, RewardRepository {

    func ledger(for childID: UUID) async throws -> RewardLedger {
        let child = childID
        let descriptor = FetchDescriptor<StoredRewardTransaction>(
            predicate: #Predicate { $0.childID == child },
            sortBy: [SortDescriptor(\StoredRewardTransaction.timestamp, order: .forward)]
        )
        // `RewardLedger.init(_:)` re-applies the ledger's own invariants —
        // first-writer-wins on a duplicate key, non-positive quantities dropped —
        // so a hand-edited or partially-migrated store cannot produce a ledger
        // that violates them.
        return RewardLedger(try fetch(descriptor).map(\.domainValue))
    }

    @discardableResult
    func append(_ transaction: RewardTransaction) async throws -> RewardAppendResult {
        guard transaction.quantity > 0 else { return .rejectedNonPositiveQuantity }
        if let existing = try storedTransaction(forKey: transaction.idempotencyKey) {
            // The normal, expected outcome of a retry after a crash. Not an
            // error, and the caller shows the same celebration it would have.
            return .duplicate(existing: existing.domainValue)
        }
        context.insert(StoredRewardTransaction(transaction))
        try saveChanges()
        HopLog.persistence.debug(
            "star written child=\(HopLog.tag(for: transaction.childID), privacy: .public) reason=\(transaction.reason.rawValue, privacy: .public)"
        )
        return .awarded(transaction)
    }

    func transaction(forKey key: String) async throws -> RewardTransaction? {
        try storedTransaction(forKey: key)?.domainValue
    }

    func totalStars(for childID: UUID) async throws -> Int {
        let child = childID
        let descriptor = FetchDescriptor<StoredRewardTransaction>(
            predicate: #Predicate { $0.childID == child }
        )
        // Summed from rows on every read. A stored total is a number that can
        // drift from the ledger, and the ledger is the thing a child can see.
        return try fetch(descriptor).reduce(0) { $0 + max(0, $1.quantity) }
    }

    @discardableResult
    func orphanTransactions(forDeletedEventIDs eventIDs: Set<UUID>) async throws -> Int {
        guard !eventIDs.isEmpty else { return 0 }
        let descriptor = FetchDescriptor<StoredRewardTransaction>(
            predicate: #Predicate { $0.sourceEventID != nil }
        )
        // Membership is tested in Swift rather than in the predicate: a
        // `Set.contains` on an optional column is the kind of expression that
        // translates differently across OS versions, and this runs at most once
        // per deletion.
        var orphaned = 0
        for row in try fetch(descriptor) {
            guard let source = row.sourceEventID, eventIDs.contains(source) else { continue }
            row.orphanSourceEvent()
            orphaned += 1
        }
        try saveChanges()
        if orphaned > 0 {
            HopLog.persistence.info("stars orphaned count=\(orphaned, privacy: .public) removed=0")
        }
        return orphaned
    }

    func count(for childID: UUID) async throws -> Int {
        let child = childID
        return try fetchCount(
            FetchDescriptor<StoredRewardTransaction>(predicate: #Predicate { $0.childID == child })
        )
    }

    /// Removes a child's whole ledger.
    ///
    /// This is the *only* code in HopPotty that deletes a star, and it is
    /// reachable from exactly two places: "Reset rewards" and "Delete profile",
    /// both parent-gated, both showing a count first. It is data deletion — a
    /// caregiver exercising control over their family's records — and never a
    /// consequence of anything the child did or failed to do. Contract rule 2
    /// governs the reward *system*: nothing in the app takes a star back as an
    /// outcome. See `DataDeletionService` for the full argument.
    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        let child = childID
        return try deleteAll(
            matching: FetchDescriptor<StoredRewardTransaction>(predicate: #Predicate { $0.childID == child })
        )
    }

    private func storedTransaction(forKey key: String) throws -> StoredRewardTransaction? {
        let target = key
        return try fetchOne(
            FetchDescriptor<StoredRewardTransaction>(predicate: #Predicate { $0.idempotencyKey == target })
        )
    }
}

// MARK: - Pond progress

@MainActor
final class SwiftDataPondProgressRepository: SwiftDataRepository, PondProgressRepository {

    func progress(for childID: UUID) async throws -> PondProgress {
        // An absent row is an empty pond, not an error: every child starts with
        // one and it is created lazily on the first unlock.
        try storedProgress(for: childID)?.domainValue ?? PondProgress(childID: childID)
    }

    func save(_ progress: PondProgress) async throws {
        if let existing = try storedProgress(for: progress.childID) {
            existing.apply(progress)
        } else {
            context.insert(StoredPondProgress(progress))
        }
        try saveChanges()
    }

    func unlockedCount(for childID: UUID) async throws -> Int {
        try storedProgress(for: childID)?.unlockedCount ?? 0
    }

    func count(for childID: UUID) async throws -> Int {
        try storedProgress(for: childID) == nil ? 0 : 1
    }

    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        let child = childID
        return try deleteAll(
            matching: FetchDescriptor<StoredPondProgress>(predicate: #Predicate { $0.childID == child })
        )
    }

    private func storedProgress(for childID: UUID) throws -> StoredPondProgress? {
        let child = childID
        return try fetchOne(
            FetchDescriptor<StoredPondProgress>(predicate: #Predicate { $0.childID == child })
        )
    }
}
