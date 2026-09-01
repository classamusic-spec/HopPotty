#if DEBUG
import Foundation
import SwiftUI
import HopPottyCore

// In-memory stand-ins for every dependency the parent features have.
//
// `#if DEBUG` so the shipping binary does not contain them — the same rule
// `AppBuildConfiguration` states for mock services. They exist so a `#Preview`
// can pin a state that is hard to reach on a device: a denied permission, an
// empty log, a family that has not bought the unlock.

@MainActor
final class InMemoryChildProfileRepository: ChildProfileRepository {
    var profiles: [ChildProfile]
    init(_ profiles: [ChildProfile] = []) { self.profiles = profiles }

    func allProfiles() async throws -> [ChildProfile] { profiles.sorted { $0.createdAt < $1.createdAt } }
    func profile(id: UUID) async throws -> ChildProfile? { profiles.first { $0.id == id } }
    func save(_ profile: ChildProfile) async throws {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
    }
    @discardableResult
    func deleteProfile(id: UUID) async throws -> Int {
        let before = profiles.count
        profiles.removeAll { $0.id == id }
        return before - profiles.count
    }
    func profileCount() async throws -> Int { profiles.count }
}

@MainActor
final class InMemoryPottyEventRepository: PottyEventRepository {
    var events: [PottyEvent]
    init(_ events: [PottyEvent] = []) { self.events = events }

    func events(matching query: PottyEventQuery) async throws -> [PottyEvent] {
        var rows = events.filter { $0.childID == query.childID }
        if let window = query.window { rows = rows.filter { window.contains($0.timestamp) } }
        rows.sort { query.newestFirst ? $0.timestamp > $1.timestamp : $0.timestamp < $1.timestamp }
        if let limit = query.limit { rows = Array(rows.prefix(limit)) }
        return rows
    }
    func event(id: UUID) async throws -> PottyEvent? { events.first { $0.id == id } }
    func save(_ event: PottyEvent) async throws {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
        }
    }
    @discardableResult
    func delete(ids: [UUID]) async throws -> Int {
        let set = Set(ids)
        let before = events.count
        events.removeAll { set.contains($0.id) }
        return before - events.count
    }
    func count(for childID: UUID, in window: DateWindow) async throws -> Int {
        events.filter { $0.childID == childID && window.contains($0.timestamp) }.count
    }
    func eventIDs(for childID: UUID) async throws -> Set<UUID> {
        Set(events.filter { $0.childID == childID }.map(\.id))
    }
    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        let before = events.count
        events.removeAll { $0.childID == childID }
        return before - events.count
    }
    func count(for childID: UUID) async throws -> Int { events.filter { $0.childID == childID }.count }
}

@MainActor
final class InMemoryRewardRepository: RewardRepository {
    var transactions: [RewardTransaction]
    init(_ transactions: [RewardTransaction] = []) { self.transactions = transactions }

    func ledger(for childID: UUID) async throws -> RewardLedger {
        RewardLedger(transactions.filter { $0.childID == childID })
    }
    @discardableResult
    func append(_ transaction: RewardTransaction) async throws -> RewardAppendResult {
        var ledger = RewardLedger(transactions)
        let result = ledger.append(transaction)
        transactions = ledger.transactions
        return result
    }
    func transaction(forKey key: String) async throws -> RewardTransaction? {
        transactions.first { $0.idempotencyKey == key }
    }
    func totalStars(for childID: UUID) async throws -> Int {
        transactions.filter { $0.childID == childID }.reduce(0) { $0 + $1.quantity }
    }
    /// Never removes a row and never changes a quantity — contract rule 2.
    @discardableResult
    func orphanTransactions(forDeletedEventIDs eventIDs: Set<UUID>) async throws -> Int {
        var broken = 0
        transactions = transactions.map { transaction in
            guard let source = transaction.sourceEventID, eventIDs.contains(source) else { return transaction }
            broken += 1
            return RewardTransaction(
                id: transaction.id,
                childID: transaction.childID,
                timestamp: transaction.timestamp,
                reason: transaction.reason,
                quantity: transaction.quantity,
                sourceEventID: nil,
                idempotencyKey: transaction.idempotencyKey
            )
        }
        return broken
    }
    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        let before = transactions.count
        transactions.removeAll { $0.childID == childID }
        return before - transactions.count
    }
    func count(for childID: UUID) async throws -> Int { transactions.filter { $0.childID == childID }.count }
}

@MainActor
final class InMemoryPondProgressRepository: PondProgressRepository {
    var stored: [UUID: PondProgress] = [:]
    func progress(for childID: UUID) async throws -> PondProgress {
        stored[childID] ?? PondProgress(childID: childID)
    }
    func save(_ progress: PondProgress) async throws { stored[progress.childID] = progress }
    func unlockedCount(for childID: UUID) async throws -> Int { (stored[childID]?.unlockedCount) ?? 0 }
    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        let count = stored[childID]?.unlockedCount ?? 0
        stored[childID] = nil
        return count
    }
    func count(for childID: UUID) async throws -> Int { try await unlockedCount(for: childID) }
}

@MainActor
final class InMemoryScheduleRepository: ScheduleRepository {
    var stored: [UUID: PottySchedule]
    init(_ schedules: [PottySchedule] = []) {
        stored = Dictionary(uniqueKeysWithValues: schedules.map { ($0.childID, $0) })
    }
    func schedule(for childID: UUID) async throws -> PottySchedule? { stored[childID] }
    func allSchedules() async throws -> [PottySchedule] { Array(stored.values) }
    func save(_ schedule: PottySchedule) async throws { stored[schedule.childID] = schedule }
    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int { stored.removeValue(forKey: childID) == nil ? 0 : 1 }
    func count(for childID: UUID) async throws -> Int { stored[childID] == nil ? 0 : 1 }
}

@MainActor
final class InMemoryScreenTimeConfigurationRepository: ScreenTimeConfigurationRepository {
    var stored: [UUID: ScreenTimeConfiguration] = [:]
    func configuration(for childID: UUID) async throws -> ScreenTimeConfiguration? { stored[childID] }
    func save(_ configuration: ScreenTimeConfiguration) async throws { stored[configuration.childID] = configuration }
    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int { stored.removeValue(forKey: childID) == nil ? 0 : 1 }
    func count(for childID: UUID) async throws -> Int { stored[childID] == nil ? 0 : 1 }
}

@MainActor
final class InMemoryQuizProgressRepository: QuizProgressRepository {
    var stored: [UUID: QuizProgress] = [:]
    func progress(for childID: UUID) async throws -> QuizProgress { stored[childID] ?? QuizProgress(childID: childID) }
    func save(_ progress: QuizProgress) async throws { stored[progress.childID] = progress }
    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int { stored.removeValue(forKey: childID) == nil ? 0 : 1 }
    func count(for childID: UUID) async throws -> Int { stored[childID]?.totalCompletions ?? 0 }
}

@MainActor
final class InMemoryGameProgressRepository: GameProgressRepository {
    var stored: [UUID: GameProgress] = [:]
    func progress(for childID: UUID) async throws -> GameProgress { stored[childID] ?? GameProgress(childID: childID) }
    func save(_ progress: GameProgress) async throws { stored[progress.childID] = progress }
    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int { stored.removeValue(forKey: childID) == nil ? 0 : 1 }
    func count(for childID: UUID) async throws -> Int { stored[childID]?.totalCompletions ?? 0 }
}

@MainActor
final class InMemorySettingsRepository: SettingsRepository {
    var stored: AppSettings
    init(_ settings: AppSettings = AppSettings()) { stored = settings }
    func settings() async throws -> AppSettings { stored }
    func save(_ settings: AppSettings) async throws { stored = settings }
    func reset() async throws { stored = AppSettings() }
}
#endif
