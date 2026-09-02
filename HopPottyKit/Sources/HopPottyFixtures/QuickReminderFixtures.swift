import Foundation
import HopPottyCore

// MARK: - In-memory store

/// A ``QuickReminderRepository`` held entirely in memory.
///
/// Three jobs, the same three the app's in-memory repositories do: previews get
/// a store that cannot touch a real family's data, tests get one that needs no
/// container and no migration, and a build whose on-disk store failed to open
/// still lets a caregiver set a reminder for the next twenty minutes.
///
/// It is held to the same rules as a persistent implementation, not a looser
/// set: `save` upserts by `id`, deletions return counts, `nil` is a real child
/// scope rather than a wildcard, and reads come back sorted so two runs of the
/// same test see the same order.
@MainActor
public final class InMemoryQuickReminderRepository: QuickReminderRepository {

    private var storage: [UUID: QuickReminder] = [:]

    public init(_ reminders: [QuickReminder] = []) {
        for reminder in reminders { storage[reminder.id] = reminder }
    }

    public func allReminders() async throws -> [QuickReminder] {
        storage.values.sorted { lhs, rhs in
            // `fireAt` first, then `id`, so reminders set for the same instant
            // still have one stable order rather than dictionary order.
            lhs.fireAt == rhs.fireAt
                ? lhs.id.uuidString < rhs.id.uuidString
                : lhs.fireAt < rhs.fireAt
        }
    }

    public func reminders(for childID: UUID?) async throws -> [QuickReminder] {
        try await allReminders().filter { $0.childID == childID }
    }

    public func reminder(id: UUID) async throws -> QuickReminder? { storage[id] }

    public func save(_ reminder: QuickReminder) async throws {
        storage[reminder.id] = reminder
    }

    @discardableResult
    public func delete(id: UUID) async throws -> Bool {
        storage.removeValue(forKey: id) != nil
    }

    @discardableResult
    public func deleteAll(for childID: UUID?) async throws -> Int {
        let doomed = storage.values.filter { $0.childID == childID }.map(\.id)
        for id in doomed { storage.removeValue(forKey: id) }
        return doomed.count
    }

    @discardableResult
    public func deleteEverything() async throws -> Int {
        let count = storage.count
        storage.removeAll()
        return count
    }

    /// How many rows are held, without going through `async`. Previews only —
    /// tests read through the protocol so they exercise the same path the app
    /// does.
    public var storedCount: Int { storage.count }
}

// MARK: - Sample data

public extension HopFixtures {

    /// A reminder waiting twenty minutes out from the reference date, set for
    /// nobody in particular — the commonest real shape, a caregiver timing the
    /// bathroom rather than a child.
    static var pendingQuickReminder: QuickReminder {
        QuickReminder(
            id: UUID(uuidString: "5A11D000-0000-4000-8000-00000000A001")!,
            childID: nil,
            fireAt: referenceDate.addingTimeInterval(20 * 60),
            createdAt: referenceDate,
            label: .afterADrink,
            state: .pending
        )
    }

    /// A reminder for Sam, forty-five minutes out. Exercises the child-scoped
    /// path and the "one pending per child" rule.
    static var pendingQuickReminderForSam: QuickReminder {
        QuickReminder(
            id: UUID(uuidString: "5A11D000-0000-4000-8000-00000000A002")!,
            childID: samChildID,
            fireAt: referenceDate.addingTimeInterval(45 * 60),
            createdAt: referenceDate,
            label: .beforeLeaving,
            state: .pending
        )
    }

    /// One that already arrived, an hour before the reference date. Not stale:
    /// the dashboard still has it, and the prune leaves it alone for a day.
    static var firedQuickReminder: QuickReminder {
        QuickReminder(
            id: UUID(uuidString: "5A11D000-0000-4000-8000-00000000A003")!,
            childID: samChildID,
            fireAt: referenceDate.addingTimeInterval(-60 * 60),
            createdAt: referenceDate.addingTimeInterval(-90 * 60),
            label: .beforeNap,
            state: .fired
        )
    }

    /// A finished reminder from two days ago — the one the launch prune removes.
    static var staleQuickReminder: QuickReminder {
        QuickReminder(
            id: UUID(uuidString: "5A11D000-0000-4000-8000-00000000A004")!,
            childID: nil,
            fireAt: referenceDate.addingTimeInterval(-2 * 24 * 60 * 60),
            createdAt: referenceDate.addingTimeInterval(-2 * 24 * 60 * 60 - 600),
            label: nil,
            state: .fired
        )
    }

    /// The mixed set a preview shows: one waiting, one arrived, one stale.
    static var quickReminders: [QuickReminder] {
        [pendingQuickReminder, firedQuickReminder, staleQuickReminder]
    }

    /// A store carrying `quickReminders`.
    @MainActor
    static func quickReminderRepository(
        _ reminders: [QuickReminder] = HopFixtures.quickReminders
    ) -> InMemoryQuickReminderRepository {
        InMemoryQuickReminderRepository(reminders)
    }
}
