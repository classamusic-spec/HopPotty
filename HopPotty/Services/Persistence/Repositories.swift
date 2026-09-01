import Foundation
import HopPottyCore

// MARK: - Errors

/// What can go wrong at the storage boundary, in terms a caller can act on.
///
/// Deliberately small. A repository either has no store to talk to, could not
/// write, or was asked for something that is not there. Everything else — a
/// malformed blob, an enum raw value from the future — is handled *inside* the
/// mapping layer by degrading to a documented default, because a caregiver
/// opening the timeline should never see an error sheet about a JSON column.
enum PersistenceError: Error, Equatable {
    /// The store could not be opened at all. See `PersistenceController.Outcome`.
    case storeUnavailable
    /// A write failed. The underlying error is logged, never surfaced.
    case saveFailed
    /// A read failed.
    case readFailed
    /// The row the caller named does not exist.
    case notFound
}

// MARK: - Shared shapes

/// Everything a caller can vary about a timeline query.
///
/// A struct rather than four defaulted parameters because the same query is
/// built by the dashboard, the insights engine and the export, and a shared
/// value makes "did the export use the same window as the chart?" answerable.
struct PottyEventQuery: Hashable, Sendable {
    /// Always required. There is no query in HopPotty that reads across
    /// children: a sibling's timeline is not the caregiver's *current* subject,
    /// and an unscoped fetch is the bug that shows Maya's accidents on Sam's
    /// dashboard.
    let childID: UUID
    /// Half-open `[start, end)`. `nil` means the whole history.
    var window: DateWindow?
    /// Newest first by default — every screen that shows events shows recent
    /// ones first.
    var newestFirst: Bool
    /// Cap on rows returned. `nil` means everything.
    var limit: Int?

    init(childID: UUID, window: DateWindow? = nil, newestFirst: Bool = true, limit: Int? = nil) {
        self.childID = childID
        self.window = window
        self.newestFirst = newestFirst
        self.limit = limit
    }
}

/// A repository that can be emptied for one child.
///
/// Every child-scoped table conforms, which is what lets `DataDeletionService`
/// delete a profile by iterating a list instead of by remembering nine method
/// names — and what makes "we forgot to delete the quiz rows" a compile error
/// when a tenth table is added.
@MainActor
protocol ChildScopedRepository: AnyObject {
    /// Removes every row belonging to `childID` and returns **how many rows were
    /// actually removed**. The count is not a nicety: it is what the
    /// confirmation sheet quotes back to the caregiver before they tap.
    @discardableResult
    func deleteAll(for childID: UUID) async throws -> Int

    /// Rows currently held for `childID`, without deleting anything. Drives the
    /// preview the caregiver sees *before* the destructive action.
    func count(for childID: UUID) async throws -> Int
}

// MARK: - Repositories
//
// Every protocol is `@MainActor`. HopPotty's whole dataset is a few thousand
// small rows — a busy family logs a dozen events a day — and SwiftData's
// `ModelContext` is not thread-safe. Confining the store to one actor removes an
// entire class of bug at a cost that is not measurable at this data volume. The
// methods are `async` anyway, so moving a specific query to a background
// `@ModelActor` later changes one implementation and no call sites.

@MainActor
protocol ChildProfileRepository: AnyObject {
    /// Every profile, oldest first, so the profile switcher's order is stable
    /// rather than dependent on who was edited last.
    func allProfiles() async throws -> [ChildProfile]
    func profile(id: UUID) async throws -> ChildProfile?
    /// Insert or update. The caller owns `modifiedAt`.
    func save(_ profile: ChildProfile) async throws
    /// Removes the profile row only. Everything belonging to the child is
    /// removed by `DataDeletionService`, which counts as it goes.
    @discardableResult
    func deleteProfile(id: UUID) async throws -> Int
    func profileCount() async throws -> Int
}

@MainActor
protocol PottyEventRepository: ChildScopedRepository {
    func events(matching query: PottyEventQuery) async throws -> [PottyEvent]
    func event(id: UUID) async throws -> PottyEvent?
    func save(_ event: PottyEvent) async throws
    /// Deletes specific rows, returning how many existed and were removed.
    @discardableResult
    func delete(ids: [UUID]) async throws -> Int
    func count(for childID: UUID, in window: DateWindow) async throws -> Int
    /// Every surviving event id for a child. Feeds `RewardService.reconcile`
    /// after a caregiver deletes rows, so orphaned stars can be unlinked
    /// without being removed.
    func eventIDs(for childID: UUID) async throws -> Set<UUID>
}

@MainActor
protocol RewardRepository: ChildScopedRepository {
    /// The child's ledger, rebuilt from rows. Never a stored total.
    func ledger(for childID: UUID) async throws -> RewardLedger
    /// Persists a star, or reports that its idempotency key was already there.
    ///
    /// Returns the same `RewardAppendResult` the in-memory ledger returns, so
    /// the caller's celebration logic does not care whether the collapse
    /// happened in memory or at the unique index.
    @discardableResult
    func append(_ transaction: RewardTransaction) async throws -> RewardAppendResult
    func transaction(forKey key: String) async throws -> RewardTransaction?
    /// Summed from rows every time. See `RewardLedger` for why no total is stored.
    func totalStars(for childID: UUID) async throws -> Int
    /// Clears `sourceEventID` on rows pointing at events that no longer exist.
    ///
    /// **Never removes a row and never changes a quantity** — contract rule 2.
    /// Returns how many links were broken, for the deletion receipt.
    @discardableResult
    func orphanTransactions(forDeletedEventIDs eventIDs: Set<UUID>) async throws -> Int
}

@MainActor
protocol PondProgressRepository: ChildScopedRepository {
    func progress(for childID: UUID) async throws -> PondProgress
    func save(_ progress: PondProgress) async throws
    func unlockedCount(for childID: UUID) async throws -> Int
}

@MainActor
protocol ScheduleRepository: ChildScopedRepository {
    func schedule(for childID: UUID) async throws -> PottySchedule?
    /// Every child's schedule. The only intentionally unscoped read in the app:
    /// re-arming monitoring on launch has to consider all children at once.
    func allSchedules() async throws -> [PottySchedule]
    func save(_ schedule: PottySchedule) async throws
}

@MainActor
protocol ScreenTimeConfigurationRepository: ChildScopedRepository {
    func configuration(for childID: UUID) async throws -> ScreenTimeConfiguration?
    func save(_ configuration: ScreenTimeConfiguration) async throws
}

@MainActor
protocol QuizProgressRepository: ChildScopedRepository {
    func progress(for childID: UUID) async throws -> QuizProgress
    func save(_ progress: QuizProgress) async throws
}

@MainActor
protocol GameProgressRepository: ChildScopedRepository {
    func progress(for childID: UUID) async throws -> GameProgress
    func save(_ progress: GameProgress) async throws
}

/// Device-wide settings. Not child-scoped, so not a `ChildScopedRepository` —
/// which is exactly why "Reset app" and "Delete profile" are different
/// operations with different receipts.
@MainActor
protocol SettingsRepository: AnyObject {
    /// Always returns something: a store with no settings row yields
    /// `AppSettings()`, whose defaults are the shipped defaults.
    func settings() async throws -> AppSettings
    func save(_ settings: AppSettings) async throws
    /// Back to first-launch defaults. Used only by "Reset app".
    func reset() async throws
}

// MARK: - The set

/// Every repository, in one value.
///
/// Passed around rather than a `ModelContainer`, so a feature can be handed the
/// two repositories it needs and no feature ever holds the container. It is also
/// the seam that makes "the store failed to open" survivable: the in-memory set
/// satisfies the same protocols, so the app runs with no store at all.
@MainActor
struct RepositorySet {
    let profiles: any ChildProfileRepository
    let events: any PottyEventRepository
    let rewards: any RewardRepository
    let pond: any PondProgressRepository
    let schedules: any ScheduleRepository
    let screenTime: any ScreenTimeConfigurationRepository
    let quizzes: any QuizProgressRepository
    let games: any GameProgressRepository
    let settings: any SettingsRepository

    /// Every child-scoped table, in deletion order.
    ///
    /// Ordered deliberately: events go first so that by the time the reward rows
    /// are considered, `eventIDs` is already empty and reconciliation has a
    /// coherent view. Adding a child-scoped table means adding it here, and the
    /// deletion test asserts this list covers every `ChildScopedRepository` the
    /// set holds.
    var childScoped: [any ChildScopedRepository] {
        [events, rewards, pond, schedules, screenTime, quizzes, games]
    }
}
