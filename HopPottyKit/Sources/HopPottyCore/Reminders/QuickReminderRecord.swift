import Foundation

// MARK: - The stored shape

/// The on-disk form of a ``QuickReminder``.
///
/// Separate from the domain type for the same reason every other `Stored…`
/// record in HopPotty is separate from its model: the domain type is free to
/// gain an enum case, rename a property or change how something is derived,
/// and none of that may change the bytes already written on a caregiver's
/// device. This record is a wire format, and it is dull on purpose — dates,
/// strings and a version number.
///
/// ## What is *not* here
///
/// - No nickname, no note, no free text of any kind. A Quick Reminder carries
///   nothing a caregiver typed, so there is nothing here to redact on export
///   and nothing to leak into a log line.
/// - No notification identifier. It is derived from `id` at the one place that
///   talks to the system, so the record cannot disagree with what was
///   scheduled.
///
/// ## Decoding is total
///
/// A row written by a build from the future — an unknown label, an unknown
/// state — decodes to a documented default rather than throwing. A caregiver
/// opening the dashboard should never meet an error sheet about a JSON column,
/// and a reminder that cannot be read is a reminder that can at worst be
/// cancelled.
public struct StoredQuickReminder: Identifiable, Hashable, Codable, Sendable {

    /// Bumped when the meaning of a field changes, never when one is added.
    /// Present from the first version so a later migration has something to
    /// branch on rather than guessing from which keys are absent.
    public static let currentSchemaVersion = 1

    public let id: UUID
    /// The child this is about, or `nil` for "anyone" — see ``QuickReminder``
    /// for why a caregiver is not made to pick one.
    public let childID: UUID?
    public let fireAt: Date
    public let createdAt: Date
    /// `QuickReminderLabel.rawValue`, or `nil` when the caregiver gave no
    /// reason. Stored as a raw string so an unknown value from a newer build
    /// degrades to "no reason given" instead of failing the whole decode.
    public let label: String?
    /// `QuickReminderState.rawValue`. An unrecognised value decodes as
    /// `.cancelled`, which is the only safe guess: it schedules nothing, fires
    /// nothing, and holds no slot open.
    public let state: String
    public let schemaVersion: Int

    public init(
        id: UUID,
        childID: UUID?,
        fireAt: Date,
        createdAt: Date,
        label: String?,
        state: String,
        schemaVersion: Int = StoredQuickReminder.currentSchemaVersion
    ) {
        self.id = id
        self.childID = childID
        self.fireAt = fireAt
        self.createdAt = createdAt
        self.label = label
        self.state = state
        self.schemaVersion = schemaVersion
    }

    /// The record for a domain value.
    public init(_ reminder: QuickReminder) {
        self.init(
            id: reminder.id,
            childID: reminder.childID,
            fireAt: reminder.fireAt,
            createdAt: reminder.createdAt,
            label: reminder.label?.rawValue,
            state: reminder.state.rawValue
        )
    }

    /// The domain value for a record. Never fails: see the note above.
    public var reminder: QuickReminder {
        QuickReminder(
            id: id,
            childID: childID,
            fireAt: fireAt,
            createdAt: createdAt,
            label: label.flatMap(QuickReminderLabel.init(rawValue:)),
            state: QuickReminderState(rawValue: state) ?? .cancelled
        )
    }

    /// A missing `schemaVersion` — a row written before this field existed —
    /// reads as version zero rather than as today's version, so a future
    /// migration can tell "old" from "current" instead of assuming.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        childID = try container.decodeIfPresent(UUID.self, forKey: .childID)
        fireAt = try container.decode(Date.self, forKey: .fireAt)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        state = try container.decodeIfPresent(String.self, forKey: .state)
            ?? QuickReminderState.cancelled.rawValue
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
    }
}

// MARK: - Repository

/// Where Quick Reminders live between the moment a caregiver sets one and the
/// moment it is pruned.
///
/// ## Why this is a protocol, and why it is `@MainActor`
///
/// The same reasoning as every other repository in HopPotty: the store is a few
/// dozen small rows, `ModelContext` is not thread-safe, and confining the whole
/// dataset to one actor removes a class of bug at a cost too small to measure.
/// The methods are `async` regardless, so moving a query off the main actor
/// later changes an implementation and no call sites.
///
/// It is declared here rather than in the app target because the in-memory
/// implementation lives in `HopPottyFixtures`, and because the planner's rules
/// are only worth having if the thing that stores their results is testable on
/// the same machine that tests them.
///
/// ## The one invariant an implementation owes
///
/// `save` is an upsert keyed by `id`. A reminder saved twice is one row, which
/// is what makes "cancel then re-save the cancelled copy" idempotent — and the
/// cancel path runs from a chip a caregiver can tap twice.
@MainActor
public protocol QuickReminderRepository: AnyObject {
    /// Every reminder held, in any state, sorted by `fireAt` ascending.
    ///
    /// Unscoped on purpose: a device has one notification centre, the ceiling
    /// on pending reminders is device-wide (`QuickReminderPlanner.maximumPending`),
    /// and launch has to reconcile all of them at once.
    func allReminders() async throws -> [QuickReminder]

    /// The reminders for one child, or — when `childID` is `nil` — the ones set
    /// for nobody in particular. Not "all of them": `nil` is a real scope, the
    /// one a caregiver uses when the timer is about the bathroom rather than
    /// about a person.
    func reminders(for childID: UUID?) async throws -> [QuickReminder]

    func reminder(id: UUID) async throws -> QuickReminder?

    /// Insert or update, keyed by `id`.
    func save(_ reminder: QuickReminder) async throws

    /// Removes one row. Returns whether it was there, so a caller can tell
    /// "cancelled" from "already gone" without a second read.
    @discardableResult
    func delete(id: UUID) async throws -> Bool

    /// Removes every reminder for one child — including, when `childID` is
    /// `nil`, the ones scoped to nobody. Returns how many rows went, because
    /// every deletion in HopPotty counts what it removed.
    @discardableResult
    func deleteAll(for childID: UUID?) async throws -> Int

    /// Removes everything. Used by "Reset app" and by the launch prune when the
    /// whole table has gone stale.
    @discardableResult
    func deleteEverything() async throws -> Int
}

public extension QuickReminderRepository {
    /// Reminders that are pending and still ahead of `now`, soonest first.
    ///
    /// Derived here rather than asked of the store: the rule for "pending"
    /// lives in ``QuickReminderPlanner`` and there must not be a second copy of
    /// it in a predicate somewhere.
    func pendingReminders(at now: Date) async throws -> [QuickReminder] {
        QuickReminderPlanner.pending(try await allReminders(), at: now)
    }

    /// Marks every reminder whose instant has passed as `.fired` and writes the
    /// ones that changed. Returns the reminders that had just come due, which
    /// is what a caller shows a banner for.
    ///
    /// Called on launch and on foreground. The app being closed when the
    /// instant passed changes nothing: the system delivered the notification,
    /// and this is the record catching up (``QuickReminderPlanner`` rule 3).
    @discardableResult
    func reconcile(at now: Date) async throws -> [QuickReminder] {
        var justFired: [QuickReminder] = []
        for reminder in try await allReminders() where QuickReminderPlanner.isDue(reminder, at: now) {
            let fired = reminder.firedCopy()
            try await save(fired)
            justFired.append(fired)
        }
        return justFired
    }

    /// Removes finished reminders older than `QuickReminderPlanner.staleAfter`.
    /// Returns how many went.
    @discardableResult
    func prune(at now: Date) async throws -> Int {
        let doomed = QuickReminderPlanner.partitionForPruning(try await allReminders(), at: now).pruned
        for reminder in doomed { try await delete(id: reminder.id) }
        return doomed.count
    }
}
