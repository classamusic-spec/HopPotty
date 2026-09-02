import Foundation
import Testing
@testable import HopPottyCore
import HopPottyFixtures

/// Storing a one-off reminder.
///
/// The store is small and the rules are few, which is exactly why they are
/// worth pinning: an upsert that inserted instead would leave two rows for one
/// notification, a `nil` child treated as a wildcard would delete a sibling's
/// reminder along with the bathroom timer, and a prune that took a pending row
/// would silently cancel something the caregiver is still waiting for.
@Suite("Quick Reminder: storage")
@MainActor
struct QuickReminderRepositoryTests {

    static let now = Date(timeIntervalSince1970: 1_773_133_200)
    static let sam = UUID(uuidString: "5A11D000-0000-4000-8000-000000000001")!
    static let maya = UUID(uuidString: "5A11D000-0000-4000-8000-000000000002")!

    static func reminder(
        at offset: TimeInterval,
        childID: UUID? = nil,
        state: QuickReminderState = .pending
    ) -> QuickReminder {
        QuickReminder(
            childID: childID,
            fireAt: now.addingTimeInterval(offset),
            createdAt: now,
            state: state
        )
    }

    // MARK: - The stored record

    @Test("A reminder survives a round trip through the stored record")
    func recordRoundTrips() {
        let reminder = QuickReminder(
            childID: Self.sam,
            fireAt: Self.now.addingTimeInterval(1_200),
            createdAt: Self.now,
            label: .afterADrink,
            state: .pending
        )
        #expect(StoredQuickReminder(reminder).reminder == reminder)
    }

    @Test("Every state and every reason round trips")
    func everyEnumRoundTrips() {
        for state in QuickReminderState.allCases {
            for label in QuickReminderLabel.allCases.map(Optional.some) + [nil] {
                let reminder = QuickReminder(
                    childID: nil,
                    fireAt: Self.now.addingTimeInterval(600),
                    createdAt: Self.now,
                    label: label,
                    state: state
                )
                #expect(StoredQuickReminder(reminder).reminder == reminder, "\(state) / \(String(describing: label))")
            }
        }
    }

    @Test("A reminder survives a round trip through JSON")
    func recordEncodesAndDecodes() throws {
        let record = StoredQuickReminder(Self.reminder(at: 900, childID: Self.maya))
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(StoredQuickReminder.self, from: data)
        #expect(decoded == record)
        #expect(decoded.schemaVersion == StoredQuickReminder.currentSchemaVersion)
    }

    /// A row from a build that knows something this one does not must not take
    /// the dashboard down with it.
    @Test("An unknown state decodes to cancelled rather than throwing")
    func unknownStateDegrades() throws {
        let json = """
        {
          "id": "5A11D000-0000-4000-8000-0000000000FF",
          "fireAt": 0,
          "createdAt": 0,
          "state": "snoozed",
          "schemaVersion": 99
        }
        """
        let decoded = try JSONDecoder().decode(StoredQuickReminder.self, from: Data(json.utf8))
        // Cancelled is the only safe guess: it schedules nothing, fires nothing
        // and holds no slot open.
        #expect(decoded.reminder.state == .cancelled)
        #expect(decoded.reminder.childID == nil)
        #expect(decoded.reminder.label == nil)
    }

    @Test("An unknown reason decodes as no reason given")
    func unknownLabelDegrades() throws {
        let json = """
        {
          "id": "5A11D000-0000-4000-8000-0000000000FE",
          "fireAt": 0,
          "createdAt": 0,
          "label": "afterSwimming",
          "state": "pending"
        }
        """
        let decoded = try JSONDecoder().decode(StoredQuickReminder.self, from: Data(json.utf8))
        #expect(decoded.reminder.label == nil)
        #expect(decoded.reminder.state == .pending, "an unknown reason took the state with it")
        // A row written before `schemaVersion` existed reads as version zero,
        // so a later migration can tell it apart from a current one.
        #expect(decoded.schemaVersion == 0)
    }

    // MARK: - Reading and writing

    @Test("Saving the same id twice leaves one row")
    func saveIsAnUpsert() async throws {
        let store = InMemoryQuickReminderRepository()
        let reminder = Self.reminder(at: 600, childID: Self.sam)
        try await store.save(reminder)
        try await store.save(reminder.cancelledCopy())
        let all = try await store.allReminders()
        #expect(all.count == 1)
        #expect(all.first?.state == .cancelled)
    }

    @Test("Reminders come back soonest first")
    func readsAreSorted() async throws {
        let store = InMemoryQuickReminderRepository([
            Self.reminder(at: 1_800),
            Self.reminder(at: 600),
            Self.reminder(at: 1_200),
        ])
        let fireDates = try await store.allReminders().map(\.fireAt)
        #expect(fireDates == fireDates.sorted())
    }

    /// `nil` is a scope, not a wildcard: a caregiver timing the bathroom for
    /// two children in the bath has a reminder that belongs to neither of them.
    @Test("A nil child is its own scope, not everything")
    func nilChildIsAScope() async throws {
        let unscoped = Self.reminder(at: 600, childID: nil)
        let samsReminder = Self.reminder(at: 900, childID: Self.sam)
        let store = InMemoryQuickReminderRepository([unscoped, samsReminder])

        #expect(try await store.reminders(for: nil) == [unscoped])
        #expect(try await store.reminders(for: Self.sam) == [samsReminder])
        #expect(try await store.reminders(for: Self.maya).isEmpty)
        #expect(try await store.allReminders().count == 2)
    }

    @Test("Deleting reports whether the row was there")
    func deleteReportsWhatItDid() async throws {
        let reminder = Self.reminder(at: 600)
        let store = InMemoryQuickReminderRepository([reminder])
        #expect(try await store.delete(id: reminder.id))
        #expect(try await store.delete(id: reminder.id) == false)
        #expect(try await store.reminder(id: reminder.id) == nil)
    }

    @Test("Deleting for a child counts what it removed and spares the others")
    func scopedDeletionCounts() async throws {
        let store = InMemoryQuickReminderRepository([
            Self.reminder(at: 600, childID: Self.sam),
            Self.reminder(at: 900, childID: Self.sam),
            Self.reminder(at: 1_200, childID: Self.maya),
            Self.reminder(at: 1_500, childID: nil),
        ])
        #expect(try await store.deleteAll(for: Self.sam) == 2)
        #expect(try await store.allReminders().count == 2)
        #expect(try await store.deleteAll(for: nil) == 1)
        #expect(try await store.reminders(for: Self.maya).count == 1)
        #expect(try await store.deleteEverything() == 1)
        #expect(try await store.allReminders().isEmpty)
    }

    // MARK: - Derived reads

    @Test("Pending means waiting and still ahead")
    func pendingExcludesOverdueAndFinished() async throws {
        let waiting = Self.reminder(at: 600)
        let store = InMemoryQuickReminderRepository([
            waiting,
            Self.reminder(at: -60),
            Self.reminder(at: 900, state: .cancelled),
            Self.reminder(at: 1_200, state: .fired),
        ])
        #expect(try await store.pendingReminders(at: Self.now) == [waiting])
    }

    @Test("Reconciling writes the reminders that came due and returns them")
    func reconcileWritesThrough() async throws {
        let due = Self.reminder(at: -30, childID: Self.sam)
        let waiting = Self.reminder(at: 600, childID: Self.maya)
        let store = InMemoryQuickReminderRepository([due, waiting])

        let fired = try await store.reconcile(at: Self.now)
        #expect(fired.map(\.id) == [due.id])
        #expect(try await store.reminder(id: due.id)?.state == .fired)
        #expect(try await store.reminder(id: waiting.id)?.state == .pending)

        // Idempotent: running it again finds nothing new, because a fired
        // reminder is never due again.
        #expect(try await store.reconcile(at: Self.now).isEmpty)
    }

    @Test("Pruning takes stale rows and leaves everything else")
    func pruneIsNarrow() async throws {
        let store = InMemoryQuickReminderRepository(HopFixtures.quickReminders)
        let before = try await store.allReminders().count
        let removed = try await store.prune(at: HopFixtures.referenceDate)
        #expect(removed == 1, "the two-day-old fired reminder is the only stale one")
        #expect(try await store.allReminders().count == before - 1)
        // And a second prune at the same instant is a no-op.
        #expect(try await store.prune(at: HopFixtures.referenceDate) == 0)
    }

    @Test("The fixtures describe the three states a preview needs")
    func fixturesCoverTheStates() async throws {
        let store = HopFixtures.quickReminderRepository()
        let all = try await store.allReminders()
        #expect(all.contains { $0.state == .pending })
        #expect(all.contains { $0.state == .fired })
        #expect(HopFixtures.pendingQuickReminderForSam.childID == HopFixtures.samChildID)
        #expect(store.storedCount == all.count)
    }
}
