import Foundation
import HopPottyCore

// MARK: - Why these exist
//
// Three jobs, one implementation:
//
// 1. **Previews.** An Xcode preview must never touch the family's real store.
// 2. **Tests.** Every repository test runs against this stack, so a test can
//    assert behaviour without a container, a file, or a migration.
// 3. **Survival.** If the on-disk store cannot be opened at all — see
//    `PersistenceController.Outcome.unavailable` — the app runs on these. The
//    child can still tap the big button and still earn a star; the caregiver is
//    told, calmly, that this session will not be saved.
//
// They are held to the same rules as the SwiftData stack, not a looser set:
// every query is scoped by child, the reward store collapses duplicate
// idempotency keys, deletions return counts, and nothing removes a star except
// an explicit, counted, parent-gated wipe.

@MainActor
final class InMemoryChildProfileRepository: ChildProfileRepository {
    private var storage: [UUID: ChildProfile] = [:]

    init(profiles: [ChildProfile] = []) {
        for profile in profiles { storage[profile.id] = profile }
    }

    func allProfiles() async throws -> [ChildProfile] {
        storage.values.sorted { $0.createdAt < $1.createdAt }
    }

    func profile(id: UUID) async throws -> ChildProfile? { storage[id] }

    func save(_ profile: ChildProfile) async throws { storage[profile.id] = profile }

    @discardableResult
    func deleteProfile(id: UUID) async throws -> Int {
        storage.removeValue(forKey: id) == nil ? 0 : 1
    }

    func profileCount() async throws -> Int { storage.count }
}

@MainActor
final class InMemoryPottyEventRepository: PottyEventRepository {
    private var storage: [UUID: PottyEvent] = [:]

    init(events: [PottyEvent] = []) {
        for event in events { storage[event.id] = event }
    }

    func events(matching query: PottyEventQuery) async throws -> [PottyEvent] {
        var rows = storage.values.filter { event in
            guard event.childID == query.childID else { return false }
            guard let window = query.window else { return true }
            return window.contains(event.timestamp)
        }
        rows.sort {
            query.newestFirst ? $0.timestamp > $1.timestamp : $0.timestamp < $1.timestamp
        }
        if let limit = query.limit { rows = Array(rows.prefix(max(0, limit))) }
        return rows
    }

    func event(id: UUID) async throws -> PottyEvent? { storage[id] }

    func save(_ event: PottyEvent) async throws { storage[event.id] = event }

    @discardableResult
    func delete(ids: [UUID]) async throws -> Int {
        var removed = 0
        for id in ids where storage.removeValue(forKey: id) != nil { removed += 1 }
        return removed
    }

    func count(for childID: UUID) async throws -> Int {
        storage.values.filter { $0.childID == childID }.count
    }

    func count(for childID: UUID, in window: DateWindow) async throws -> Int {
        storage.values.filter { $0.childID == childID && window.contains($0.timestamp) }.count
    }

    func eventIDs(for childID: UUID) async throws -> Set<UUID> {
        Set(storage.values.filter { $0.childID == childID }.map(\.id))
    }

    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        let doomed = storage.values.filter { $0.childID == childID }.map(\.id)
        for id in doomed { storage.removeValue(forKey: id) }
        return doomed.count
    }
}

@MainActor
final class InMemoryRewardRepository: RewardRepository {
    /// Keyed by idempotency key, which is what makes the duplicate collapse
    /// structural here just as the unique index makes it structural on disk.
    private var storage: [String: RewardTransaction] = [:]

    init(transactions: [RewardTransaction] = []) {
        for transaction in transactions where transaction.quantity > 0 {
            if storage[transaction.idempotencyKey] == nil {
                storage[transaction.idempotencyKey] = transaction
            }
        }
    }

    func ledger(for childID: UUID) async throws -> RewardLedger {
        RewardLedger(
            storage.values
                .filter { $0.childID == childID }
                .sorted { $0.timestamp < $1.timestamp }
        )
    }

    @discardableResult
    func append(_ transaction: RewardTransaction) async throws -> RewardAppendResult {
        guard transaction.quantity > 0 else { return .rejectedNonPositiveQuantity }
        if let existing = storage[transaction.idempotencyKey] {
            return .duplicate(existing: existing)
        }
        storage[transaction.idempotencyKey] = transaction
        return .awarded(transaction)
    }

    func transaction(forKey key: String) async throws -> RewardTransaction? { storage[key] }

    func totalStars(for childID: UUID) async throws -> Int {
        storage.values.reduce(0) { $0 + ($1.childID == childID ? max(0, $1.quantity) : 0) }
    }

    @discardableResult
    func orphanTransactions(forDeletedEventIDs eventIDs: Set<UUID>) async throws -> Int {
        guard !eventIDs.isEmpty else { return 0 }
        var orphaned = 0
        for (key, transaction) in storage {
            guard let source = transaction.sourceEventID, eventIDs.contains(source) else { continue }
            // Rebuilt with the same id, timestamp, reason, quantity and key.
            // Only the link changes.
            storage[key] = RewardTransaction(
                id: transaction.id,
                childID: transaction.childID,
                timestamp: transaction.timestamp,
                reason: transaction.reason,
                quantity: transaction.quantity,
                sourceEventID: nil,
                idempotencyKey: transaction.idempotencyKey
            )
            orphaned += 1
        }
        return orphaned
    }

    func count(for childID: UUID) async throws -> Int {
        storage.values.filter { $0.childID == childID }.count
    }

    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        let doomed = storage.filter { $0.value.childID == childID }.map(\.key)
        for key in doomed { storage.removeValue(forKey: key) }
        return doomed.count
    }
}

@MainActor
final class InMemoryPondProgressRepository: PondProgressRepository {
    private var storage: [UUID: PondProgress] = [:]

    init(progress: [PondProgress] = []) {
        for entry in progress { storage[entry.childID] = entry }
    }

    func progress(for childID: UUID) async throws -> PondProgress {
        storage[childID] ?? PondProgress(childID: childID)
    }

    func save(_ progress: PondProgress) async throws { storage[progress.childID] = progress }

    func unlockedCount(for childID: UUID) async throws -> Int {
        storage[childID]?.unlockedCount ?? 0
    }

    func count(for childID: UUID) async throws -> Int { storage[childID] == nil ? 0 : 1 }

    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        storage.removeValue(forKey: childID) == nil ? 0 : 1
    }
}

@MainActor
final class InMemoryScheduleRepository: ScheduleRepository {
    private var storage: [UUID: PottySchedule] = [:]

    init(schedules: [PottySchedule] = []) {
        for schedule in schedules { storage[schedule.childID] = schedule }
    }

    func schedule(for childID: UUID) async throws -> PottySchedule? { storage[childID] }

    func allSchedules() async throws -> [PottySchedule] {
        storage.values.sorted { $0.createdAt < $1.createdAt }
    }

    func save(_ schedule: PottySchedule) async throws { storage[schedule.childID] = schedule }

    func count(for childID: UUID) async throws -> Int { storage[childID] == nil ? 0 : 1 }

    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        storage.removeValue(forKey: childID) == nil ? 0 : 1
    }
}

@MainActor
final class InMemoryScreenTimeConfigurationRepository: ScreenTimeConfigurationRepository {
    private var storage: [UUID: ScreenTimeConfiguration] = [:]

    init(configurations: [ScreenTimeConfiguration] = []) {
        for configuration in configurations { storage[configuration.childID] = configuration }
    }

    func configuration(for childID: UUID) async throws -> ScreenTimeConfiguration? {
        storage[childID]
    }

    func save(_ configuration: ScreenTimeConfiguration) async throws {
        storage[configuration.childID] = configuration
    }

    func count(for childID: UUID) async throws -> Int { storage[childID] == nil ? 0 : 1 }

    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        storage.removeValue(forKey: childID) == nil ? 0 : 1
    }
}

@MainActor
final class InMemoryQuizProgressRepository: QuizProgressRepository {
    private var storage: [UUID: QuizProgress] = [:]

    init(progress: [QuizProgress] = []) {
        for entry in progress { storage[entry.childID] = entry }
    }

    func progress(for childID: UUID) async throws -> QuizProgress {
        storage[childID] ?? QuizProgress(childID: childID)
    }

    func save(_ progress: QuizProgress) async throws { storage[progress.childID] = progress }

    func count(for childID: UUID) async throws -> Int {
        storage[childID]?.totalCompletions ?? 0
    }

    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        let completions = storage[childID]?.totalCompletions ?? 0
        storage.removeValue(forKey: childID)
        return completions
    }
}

@MainActor
final class InMemoryGameProgressRepository: GameProgressRepository {
    private var storage: [UUID: GameProgress] = [:]

    init(progress: [GameProgress] = []) {
        for entry in progress { storage[entry.childID] = entry }
    }

    func progress(for childID: UUID) async throws -> GameProgress {
        storage[childID] ?? GameProgress(childID: childID)
    }

    func save(_ progress: GameProgress) async throws { storage[progress.childID] = progress }

    func count(for childID: UUID) async throws -> Int {
        storage[childID]?.totalCompletions ?? 0
    }

    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        let completions = storage[childID]?.totalCompletions ?? 0
        storage.removeValue(forKey: childID)
        return completions
    }
}

@MainActor
final class InMemorySettingsRepository: SettingsRepository {
    private var stored: AppSettings

    init(settings: AppSettings = AppSettings()) {
        self.stored = settings
    }

    func settings() async throws -> AppSettings { stored }
    func save(_ settings: AppSettings) async throws { stored = settings }
    func reset() async throws { stored = AppSettings() }
}

// MARK: - Assembly

extension RepositorySet {
    /// An empty in-memory set.
    static func inMemory() -> RepositorySet {
        RepositorySet(
            profiles: InMemoryChildProfileRepository(),
            events: InMemoryPottyEventRepository(),
            rewards: InMemoryRewardRepository(),
            pond: InMemoryPondProgressRepository(),
            schedules: InMemoryScheduleRepository(),
            screenTime: InMemoryScreenTimeConfigurationRepository(),
            quizzes: InMemoryQuizProgressRepository(),
            games: InMemoryGameProgressRepository(),
            settings: InMemorySettingsRepository()
        )
    }

    /// An in-memory set carrying whatever a preview or test wants to show.
    ///
    /// Everything is a parameter with an empty default, so a test that cares
    /// about one table does not have to build the other eight.
    static func inMemory(
        profiles: [ChildProfile] = [],
        events: [PottyEvent] = [],
        transactions: [RewardTransaction] = [],
        pond: [PondProgress] = [],
        schedules: [PottySchedule] = [],
        screenTime: [ScreenTimeConfiguration] = [],
        quizzes: [QuizProgress] = [],
        games: [GameProgress] = [],
        settings: AppSettings = AppSettings()
    ) -> RepositorySet {
        RepositorySet(
            profiles: InMemoryChildProfileRepository(profiles: profiles),
            events: InMemoryPottyEventRepository(events: events),
            rewards: InMemoryRewardRepository(transactions: transactions),
            pond: InMemoryPondProgressRepository(progress: pond),
            schedules: InMemoryScheduleRepository(schedules: schedules),
            screenTime: InMemoryScreenTimeConfigurationRepository(configurations: screenTime),
            quizzes: InMemoryQuizProgressRepository(progress: quizzes),
            games: InMemoryGameProgressRepository(progress: games),
            settings: InMemorySettingsRepository(settings: settings)
        )
    }
}
