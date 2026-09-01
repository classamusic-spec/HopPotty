import Foundation
import HopPottyCore
import SwiftData

// MARK: - Schedules

@MainActor
final class SwiftDataScheduleRepository: SwiftDataRepository, ScheduleRepository {

    func schedule(for childID: UUID) async throws -> PottySchedule? {
        try storedSchedule(for: childID)?.domainValue
    }

    func allSchedules() async throws -> [PottySchedule] {
        let descriptor = FetchDescriptor<StoredPottySchedule>(
            sortBy: [SortDescriptor(\StoredPottySchedule.createdAt, order: .forward)]
        )
        return try fetch(descriptor).map(\.domainValue)
    }

    func save(_ schedule: PottySchedule) async throws {
        if let existing = try storedSchedule(for: schedule.childID) {
            existing.apply(schedule)
        } else {
            context.insert(StoredPottySchedule(schedule))
        }
        try saveChanges()
        // Mode and basis are configuration, not behaviour about a child, and
        // they are the two values a support conversation always needs first.
        HopLog.scheduling.info(
            "schedule saved child=\(HopLog.tag(for: schedule.childID), privacy: .public) mode=\(schedule.mode.rawValue, privacy: .public) basis=\(schedule.triggerBasis.rawValue, privacy: .public) enabled=\(schedule.isEnabled, privacy: .public)"
        )
    }

    func count(for childID: UUID) async throws -> Int {
        try storedSchedule(for: childID) == nil ? 0 : 1
    }

    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        let child = childID
        return try deleteAll(
            matching: FetchDescriptor<StoredPottySchedule>(predicate: #Predicate { $0.childID == child })
        )
    }

    /// One schedule per child. If a store somehow holds two — a migration bug, a
    /// restored backup merged badly — the oldest wins, because that is the one
    /// the caregiver configured first and the newer row is the artefact.
    private func storedSchedule(for childID: UUID) throws -> StoredPottySchedule? {
        let child = childID
        var descriptor = FetchDescriptor<StoredPottySchedule>(
            predicate: #Predicate { $0.childID == child },
            sortBy: [SortDescriptor(\StoredPottySchedule.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }
}

// MARK: - Screen Time configuration

@MainActor
final class SwiftDataScreenTimeConfigurationRepository:
    SwiftDataRepository, ScreenTimeConfigurationRepository {

    func configuration(for childID: UUID) async throws -> ScreenTimeConfiguration? {
        try storedConfiguration(for: childID)?.domainValue
    }

    func save(_ configuration: ScreenTimeConfiguration) async throws {
        if let existing = try storedConfiguration(for: configuration.childID) {
            existing.apply(configuration)
        } else {
            context.insert(StoredScreenTimeConfiguration(configuration))
        }
        try saveChanges()
        // Counts and a status. Never which apps: the selection is the most
        // revealing thing HopPotty touches, and `ScreenTimeConfiguration` does
        // not carry it precisely so that no log line can.
        HopLog.authorization.info(
            "screen time config saved child=\(HopLog.tag(for: configuration.childID), privacy: .public) status=\(configuration.authorizationStatus.rawValue, privacy: .public) selections=\(configuration.totalSelectionCount, privacy: .public)"
        )
    }

    func count(for childID: UUID) async throws -> Int {
        try storedConfiguration(for: childID) == nil ? 0 : 1
    }

    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        let child = childID
        return try deleteAll(
            matching: FetchDescriptor<StoredScreenTimeConfiguration>(
                predicate: #Predicate { $0.childID == child }
            )
        )
    }

    private func storedConfiguration(for childID: UUID) throws -> StoredScreenTimeConfiguration? {
        let child = childID
        return try fetchOne(
            FetchDescriptor<StoredScreenTimeConfiguration>(predicate: #Predicate { $0.childID == child })
        )
    }
}

// MARK: - Quiz progress

@MainActor
final class SwiftDataQuizProgressRepository: SwiftDataRepository, QuizProgressRepository {

    func progress(for childID: UUID) async throws -> QuizProgress {
        try storedProgress(for: childID)?.domainValue ?? QuizProgress(childID: childID)
    }

    func save(_ progress: QuizProgress) async throws {
        if let existing = try storedProgress(for: progress.childID) {
            existing.apply(progress)
        } else {
            context.insert(StoredQuizProgress(progress))
        }
        try saveChanges()
    }

    func count(for childID: UUID) async throws -> Int {
        try storedProgress(for: childID)?.totalCompletions ?? 0
    }

    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        // The receipt counts *completions*, not rows: "removes 12 quiz plays"
        // is what a caregiver understands, and "removes 1 quiz progress record"
        // is not.
        let completions = try storedProgress(for: childID)?.totalCompletions ?? 0
        let child = childID
        _ = try deleteAll(
            matching: FetchDescriptor<StoredQuizProgress>(predicate: #Predicate { $0.childID == child })
        )
        return completions
    }

    private func storedProgress(for childID: UUID) throws -> StoredQuizProgress? {
        let child = childID
        return try fetchOne(
            FetchDescriptor<StoredQuizProgress>(predicate: #Predicate { $0.childID == child })
        )
    }
}

// MARK: - Game progress

@MainActor
final class SwiftDataGameProgressRepository: SwiftDataRepository, GameProgressRepository {

    func progress(for childID: UUID) async throws -> GameProgress {
        try storedProgress(for: childID)?.domainValue ?? GameProgress(childID: childID)
    }

    func save(_ progress: GameProgress) async throws {
        if let existing = try storedProgress(for: progress.childID) {
            existing.apply(progress)
        } else {
            context.insert(StoredGameProgress(progress))
        }
        try saveChanges()
    }

    func count(for childID: UUID) async throws -> Int {
        try storedProgress(for: childID)?.totalCompletions ?? 0
    }

    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int {
        let completions = try storedProgress(for: childID)?.totalCompletions ?? 0
        let child = childID
        _ = try deleteAll(
            matching: FetchDescriptor<StoredGameProgress>(predicate: #Predicate { $0.childID == child })
        )
        return completions
    }

    private func storedProgress(for childID: UUID) throws -> StoredGameProgress? {
        let child = childID
        return try fetchOne(
            FetchDescriptor<StoredGameProgress>(predicate: #Predicate { $0.childID == child })
        )
    }
}

// MARK: - Settings

@MainActor
final class SwiftDataSettingsRepository: SwiftDataRepository, SettingsRepository {

    func settings() async throws -> AppSettings {
        // No row means first launch. `AppSettings()` carries the shipped
        // defaults, so a missing row and a fresh install are the same thing.
        try storedSettings()?.domainValue ?? AppSettings()
    }

    func save(_ settings: AppSettings) async throws {
        if let existing = try storedSettings() {
            existing.apply(settings)
        } else {
            context.insert(StoredAppSettings(settings))
        }
        try saveChanges()
    }

    func reset() async throws {
        if let existing = try storedSettings() {
            context.delete(existing)
        }
        try saveChanges()
        HopLog.persistence.info("settings reset to defaults")
    }

    private func storedSettings() throws -> StoredAppSettings? {
        let id = StoredAppSettings.singletonID
        return try fetchOne(
            FetchDescriptor<StoredAppSettings>(predicate: #Predicate { $0.id == id })
        )
    }
}

// MARK: - Assembly

extension RepositorySet {
    /// The real, SwiftData-backed set.
    ///
    /// Every repository shares one `ModelContext`. That is deliberate: two
    /// contexts on the same actor means two sets of unsaved changes, and a
    /// deletion that spans seven tables has to be one unit of work or it is not
    /// a deletion at all — it is a half-deleted child.
    static func swiftData(context: ModelContext) -> RepositorySet {
        RepositorySet(
            profiles: SwiftDataChildProfileRepository(context: context),
            events: SwiftDataPottyEventRepository(context: context),
            rewards: SwiftDataRewardRepository(context: context),
            pond: SwiftDataPondProgressRepository(context: context),
            schedules: SwiftDataScheduleRepository(context: context),
            screenTime: SwiftDataScreenTimeConfigurationRepository(context: context),
            quizzes: SwiftDataQuizProgressRepository(context: context),
            games: SwiftDataGameProgressRepository(context: context),
            settings: SwiftDataSettingsRepository(context: context)
        )
    }
}
