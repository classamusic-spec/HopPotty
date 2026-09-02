import Foundation
import HopPottyCore
import UserNotifications
import Observation

// MARK: - What this service is for
//
// A Quick Reminder is a caregiver's one-off timer. This service is the only
// thing in the app that turns one into a scheduled local notification, and the
// only thing that takes one back.
//
// Three properties are worth stating before the code, because each of them is a
// bug that would be invisible on a happy path:
//
// 1. **The notification and the record move together.** Setting a reminder
//    schedules a notification *and* writes a row; cancelling removes both;
//    replacing cancels the old notification before it schedules the new one. A
//    row with no notification is a chip counting down to nothing. A
//    notification with no row is worse: it arrives for a caregiver the app has
//    already told it was gone, and there is no surface in HopPotty from which
//    they can cancel it. `refresh()` closes the remaining gap by rebuilding
//    missing rows from what the notification centre is actually holding.
// 2. **Nothing here shields an app.** No ManagedSettings, no DeviceActivity, no
//    Family Controls. That is what lets a Quick Reminder work in `.gentle`
//    mode with no Screen Time permission at all.
// 3. **It fires once.** There is no snooze, no repeat, no second nudge if
//    nobody acted on the first one. See `QuickReminder` in HopPottyCore for why
//    that is a product rule and not an omission.

/// What happened when a caregiver asked for a reminder.
///
/// `refused` carries the planner's reason so the sheet can say which limit was
/// reached; `notificationsUnavailable` is separate because it is the one outcome
/// the caregiver fixes outside HopPotty.
enum QuickReminderResult: Equatable, Sendable {
    /// Set. The reminder is scheduled and saved; `replaced` is the pending
    /// reminder it took the place of, if any.
    case scheduled(QuickReminder, replaced: QuickReminder?)
    /// The planner refused it. Not an error: the caregiver picks again.
    case refused(QuickReminderRejection)
    /// Notification permission is missing, so a reminder could be recorded but
    /// never delivered. Nothing is written — a chip promising a nudge that
    /// cannot arrive is worse than no chip.
    case notificationsUnavailable
    /// The notification could not be scheduled, or the row could not be
    /// written. Either way nothing is left half-done: a notification that was
    /// scheduled before the write failed is taken back.
    case failed

    var reminder: QuickReminder? {
        guard case .scheduled(let reminder, _) = self else { return nil }
        return reminder
    }
}

// MARK: - Protocol

/// The seam every caller holds.
///
/// `@MainActor` for the same reason the repositories are: the store behind it
/// is main-actor confined, the state below is observed by SwiftUI, and the
/// whole feature does a handful of small reads. The methods are `async`, so a
/// later move off the main actor changes this file and no call sites.
@MainActor
protocol QuickReminderProviding: AnyObject {
    /// Observable state for the chip and the sheet.
    var state: QuickReminderStatus { get }

    /// Reads what is stored, marks anything that came due while the app was
    /// closed as fired, and prunes what has gone stale. Call on launch and on
    /// foreground.
    func refresh() async

    /// Sets one, replacing any reminder already waiting for the same child.
    @discardableResult
    func schedule(_ request: QuickReminderRequest) async -> QuickReminderResult

    /// Takes one back: the notification and the row together.
    func cancel(_ reminderID: UUID) async

    /// Removes every reminder for one child. Called when a profile is deleted.
    func cancelAll(for childID: UUID?) async

    /// Removes everything. Called by "Reset app".
    func cancelEverything() async
}

// MARK: - Observable state

/// What the dashboard and the sheet watch.
///
/// A small `@Observable` box rather than making the service observable, for the
/// same reason `NotificationState` is one: features hold
/// `any QuickReminderProviding`, and SwiftUI cannot observe through an
/// existential. The real service and the mock both own one, so a preview walks
/// the same code paths as the shipping app.
///
/// Named `Status` rather than `State` because `QuickReminderState` is already
/// taken, in HopPottyCore, by the three-case enum that says where a single
/// reminder is in its life. Declaring a second type by that name in the app
/// target would shadow the first at every unqualified use — the kind of
/// collision that compiles and then means the wrong thing.
@Observable
@MainActor
final class QuickReminderStatus {
    /// Everything held, in any state, soonest first.
    var reminders: [QuickReminder] = []
    /// Reminders that came due while the app was away, newest first. The
    /// dashboard drains this to show its banner; it is never persisted.
    var justFired: [QuickReminder] = []
    /// Set when a write failed, so the sheet can explain itself. Never carries
    /// an underlying error message.
    var lastWriteFailed = false

    init(reminders: [QuickReminder] = []) {
        self.reminders = reminders
    }

    /// The reminders still waiting at `now`, soonest first.
    func pending(at now: Date) -> [QuickReminder] {
        QuickReminderPlanner.pending(reminders, at: now)
    }

    /// The one a chip draws: the soonest reminder still waiting.
    func soonest(at now: Date) -> QuickReminder? { pending(at: now).first }
}

// MARK: - Storage

/// The app's own in-memory ``QuickReminderRepository``.
///
/// Not `HopPottyFixtures.InMemoryQuickReminderRepository`, which is the same
/// shape and lives in a module the shipping app deliberately does not link —
/// sample children must never be reachable from a real family's build. This is
/// the twenty lines that would otherwise be borrowed across that boundary.
///
/// In-memory is the right store for this feature today, not a placeholder.
/// A Quick Reminder lives for at most a day, the notification centre is what
/// actually survives process death, and `QuickReminderService.refresh()`
/// reconciles against the clock on every foreground. What would be lost by
/// dying mid-flight is a row saying a reminder was set — while the notification
/// behind it, which is the part a caregiver cares about, is already the
/// system's. If that changes, this is one line in `ServiceContainer.live`,
/// because the protocol is the seam.
@MainActor
final class QuickReminderMemoryStore: QuickReminderRepository {

    private var storage: [UUID: QuickReminder] = [:]

    init(_ reminders: [QuickReminder] = []) {
        for reminder in reminders { storage[reminder.id] = reminder }
    }

    func allReminders() async throws -> [QuickReminder] {
        storage.values.sorted { lhs, rhs in
            lhs.fireAt == rhs.fireAt
                ? lhs.id.uuidString < rhs.id.uuidString
                : lhs.fireAt < rhs.fireAt
        }
    }

    func reminders(for childID: UUID?) async throws -> [QuickReminder] {
        try await allReminders().filter { $0.childID == childID }
    }

    func reminder(id: UUID) async throws -> QuickReminder? { storage[id] }

    /// Upsert, keyed by id — see the protocol for why that is the one invariant
    /// an implementation owes.
    func save(_ reminder: QuickReminder) async throws { storage[reminder.id] = reminder }

    @discardableResult
    func delete(id: UUID) async throws -> Bool { storage.removeValue(forKey: id) != nil }

    @discardableResult
    func deleteAll(for childID: UUID?) async throws -> Int {
        let doomed = storage.values.filter { $0.childID == childID }.map(\.id)
        for id in doomed { storage.removeValue(forKey: id) }
        return doomed.count
    }

    @discardableResult
    func deleteEverything() async throws -> Int {
        let count = storage.count
        storage.removeAll()
        return count
    }
}

/// One pending Quick Reminder, as the notification centre knows it.
///
/// File scope rather than nested in the service, so it carries no actor
/// isolation of its own and can be built from the `nonisolated` read below.
private struct PendingQuickReminder: Sendable {
    let id: UUID
    let fireAt: Date
}

// MARK: - Service

@MainActor
final class QuickReminderService: QuickReminderProviding {

    let state: QuickReminderStatus

    private let repository: any QuickReminderRepository
    private let notifications: any NotificationProviding
    private let center: UNUserNotificationCenter
    private let clock: any HopClock

    init(
        repository: any QuickReminderRepository = QuickReminderMemoryStore(),
        notifications: any NotificationProviding,
        center: UNUserNotificationCenter = .current(),
        clock: any HopClock = SystemClock(),
        state: QuickReminderStatus = QuickReminderStatus()
    ) {
        self.repository = repository
        self.notifications = notifications
        self.center = center
        self.clock = clock
        self.state = state
    }

    // MARK: Reading

    func refresh() async {
        let now = clock.now
        do {
            // Order matters, three times over.
            //
            // Rehydrate first: the notification centre is the thing that
            // actually survives process death, so anything it is still holding
            // has to become a row before the rules are applied to the rows.
            try await rehydrateFromNotificationCentre(at: now)
            // Reconcile second, so a reminder that arrived while the app was
            // closed is recorded as fired before the prune decides what is
            // stale — pruning first would leave a due-but-pending row looking
            // like a reminder still waiting.
            let fired = try await repository.reconcile(at: now)
            _ = try await repository.prune(at: now)
            state.reminders = try await repository.allReminders()
            state.justFired = fired.sorted { $0.fireAt > $1.fireAt }
            state.lastWriteFailed = false
        } catch {
            state.lastWriteFailed = true
            HopLog.notification.error(
                "quick reminder refresh failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
        }
    }

    /// Rebuilds rows for reminders the system is still going to deliver.
    ///
    /// The store may be in memory, and the process may have died between the
    /// caregiver tapping Set and today. What did *not* die is the scheduled
    /// notification, so it is the source of truth for "what is still coming",
    /// and a reminder it is holding must appear on the dashboard — otherwise it
    /// arrives with no chip that could have cancelled it.
    ///
    /// A rebuilt row is scoped to "anyone" and dated from now. The child scope
    /// and the original `createdAt` are not recoverable from a notification
    /// request, and neither changes what the reminder does: the scope affects
    /// only which reminder a later one replaces, and "anyone" is the scope that
    /// replaces nothing by surprise.
    private func rehydrateFromNotificationCentre(at now: Date) async throws {
        for entry in await Self.pendingQuickReminders(center: center) {
            guard try await repository.reminder(id: entry.id) == nil else { continue }
            try await repository.save(
                QuickReminder(
                    id: entry.id,
                    childID: nil,
                    fireAt: entry.fireAt,
                    createdAt: now,
                    label: nil,
                    state: .pending
                )
            )
            HopLog.notification.info("quick reminder row rebuilt from a pending notification")
        }
    }

    /// Reads the pending Quick Reminders without letting a
    /// `UNNotificationRequest` cross an isolation boundary — the same reasoning
    /// as `NotificationService.pendingCount`.
    private nonisolated static func pendingQuickReminders(
        center: UNUserNotificationCenter
    ) async -> [PendingQuickReminder] {
        let prefix = HopNotificationKind.quickReminder.identifierPrefix
        return await center.pendingNotificationRequests().compactMap { request in
            guard request.identifier.hasPrefix(prefix),
                  let id = UUID(uuidString: String(request.identifier.dropFirst(prefix.count))),
                  let trigger = request.trigger as? UNTimeIntervalNotificationTrigger,
                  let fireAt = trigger.nextTriggerDate()
            else { return nil }
            return PendingQuickReminder(id: id, fireAt: fireAt)
        }
    }

    // MARK: Setting one

    @discardableResult
    func schedule(_ request: QuickReminderRequest) async -> QuickReminderResult {
        // Permission first. A reminder that is recorded but can never be
        // delivered is a promise the app cannot keep, and the caregiver is
        // better told now than at the moment nothing happens.
        await notifications.refreshPermission()
        guard notifications.permission.canDeliver else {
            HopLog.notification.info("quick reminder not set: notifications cannot be delivered")
            return .notificationsUnavailable
        }

        let now = clock.now
        // Read through the store rather than trusting the published copy: the
        // ceiling and the one-per-child rule are only correct against every row
        // there is, and `state.reminders` is a snapshot from the last refresh.
        let existing = (try? await repository.allReminders()) ?? state.reminders
        let plan: QuickReminderPlan
        switch QuickReminderPlanner.plan(request, existing: existing, at: now) {
        case .refused(let rejection):
            return .refused(rejection)
        case .planned(let planned):
            plan = planned
        }

        // The replaced reminder's notification goes before the new one is
        // scheduled: if the app dies between the two, the caregiver is left
        // with nothing waiting rather than with two.
        if let replaced = plan.replaces {
            removeNotification(for: replaced.id)
        }

        guard await add(plan.reminder) else {
            state.lastWriteFailed = true
            return .failed
        }

        do {
            for reminder in QuickReminderPlanner.writes(for: plan) {
                try await repository.save(reminder)
            }
            state.reminders = try await repository.allReminders()
            state.lastWriteFailed = false
        } catch {
            // The row could not be written, so the notification is taken back.
            // A notification with no row is the one failure a caregiver cannot
            // undo from inside the app.
            removeNotification(for: plan.reminder.id)
            state.lastWriteFailed = true
            HopLog.notification.error(
                "quick reminder save failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            return .failed
        }

        HopLog.notification.info("quick reminder scheduled")
        return .scheduled(plan.reminder, replaced: plan.replaces)
    }

    // MARK: Taking one back

    func cancel(_ reminderID: UUID) async {
        // The notification goes first and unconditionally. Whatever the store
        // does next, nothing arrives for a reminder the caregiver cancelled.
        removeNotification(for: reminderID)
        do {
            if let reminder = try await repository.reminder(id: reminderID) {
                try await repository.save(reminder.cancelledCopy())
            }
            state.reminders = try await repository.allReminders()
            state.lastWriteFailed = false
        } catch {
            state.lastWriteFailed = true
            HopLog.notification.error(
                "quick reminder cancel failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
        }
    }

    func cancelAll(for childID: UUID?) async {
        do {
            let doomed = try await repository.reminders(for: childID)
            for reminder in doomed { removeNotification(for: reminder.id) }
            _ = try await repository.deleteAll(for: childID)
            state.reminders = try await repository.allReminders()
        } catch {
            state.lastWriteFailed = true
            HopLog.notification.error(
                "quick reminder bulk cancel failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
        }
    }

    func cancelEverything() async {
        do {
            for reminder in try await repository.allReminders() { removeNotification(for: reminder.id) }
            _ = try await repository.deleteEverything()
        } catch {
            HopLog.notification.error(
                "quick reminder wipe failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
        }
        state.reminders = []
        state.justFired = []
    }

    // MARK: The system

    /// Schedules the one notification behind a reminder.
    ///
    /// The content and the trigger come from `HopNotificationRequest`, which is
    /// the app's single gate on what HopPotty may send — see the note at the
    /// top of `NotificationService.swift`. This service owns the *when*; it does
    /// not get its own opinion about badges or interruption levels.
    private func add(_ reminder: QuickReminder) async -> Bool {
        let request = HopNotificationRequest.quickReminder(id: reminder.id, fireAt: reminder.fireAt)
        guard request.hasPermittedIdentifier,
              let trigger = request.makeTrigger(now: clock.now, minimumLead: NotificationService.minimumLeadTime)
        else {
            HopLog.notification.fault("refused a quick reminder with no trigger or an unrecognised identifier")
            return false
        }
        do {
            try await center.add(
                UNNotificationRequest(
                    identifier: request.identifier,
                    content: request.makeContent(),
                    trigger: trigger
                )
            )
            return true
        } catch {
            HopLog.notification.error(
                "quick reminder schedule failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            return false
        }
    }

    /// Removes both the pending request and anything already delivered for this
    /// reminder. A cancelled reminder should leave nothing in Notification
    /// Centre either.
    private func removeNotification(for reminderID: UUID) {
        let identifier = HopNotificationKind.quickReminder.identifierPrefix + reminderID.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

// MARK: - Mock

/// Records what would have been scheduled. Previews, tests, and any build where
/// asking for notification permission would be rude.
///
/// It is held to the same rules as the real service: replacement cancels the
/// reminder it replaces, a refusal leaves the store untouched, and nothing is
/// recorded when notifications cannot be delivered. A mock that is more
/// permissive than the thing it stands in for is a preview that proves nothing.
@MainActor
final class MockQuickReminderService: QuickReminderProviding {

    let state: QuickReminderStatus

    /// Every identifier the real service would have handed to the notification
    /// centre and not taken back.
    private(set) var scheduledIdentifiers: Set<UUID> = []
    private(set) var cancelledIdentifiers: [UUID] = []

    /// Whether a reminder can be delivered at all. Flip it to walk the
    /// permission-denied path in a preview.
    var canDeliver: Bool

    private var storage: [UUID: QuickReminder] = [:]
    private let clock: any HopClock

    init(
        reminders: [QuickReminder] = [],
        canDeliver: Bool = true,
        clock: any HopClock = SystemClock()
    ) {
        self.canDeliver = canDeliver
        self.clock = clock
        self.state = QuickReminderStatus()
        for reminder in reminders {
            storage[reminder.id] = reminder
            if reminder.isPending { scheduledIdentifiers.insert(reminder.id) }
        }
        publish()
    }

    func refresh() async {
        let now = clock.now
        var fired: [QuickReminder] = []
        for reminder in Array(storage.values) where QuickReminderPlanner.isDue(reminder, at: now) {
            let updated = reminder.firedCopy()
            storage[updated.id] = updated
            fired.append(updated)
        }
        for reminder in Array(storage.values) where QuickReminderPlanner.isStale(reminder, at: now) {
            storage.removeValue(forKey: reminder.id)
        }
        state.justFired = fired.sorted { $0.fireAt > $1.fireAt }
        publish()
    }

    @discardableResult
    func schedule(_ request: QuickReminderRequest) async -> QuickReminderResult {
        guard canDeliver else { return .notificationsUnavailable }
        let now = clock.now
        switch QuickReminderPlanner.plan(request, existing: Array(storage.values), at: now) {
        case .refused(let rejection):
            return .refused(rejection)
        case .planned(let plan):
            if let replaced = plan.replaces {
                scheduledIdentifiers.remove(replaced.id)
                cancelledIdentifiers.append(replaced.id)
            }
            for reminder in QuickReminderPlanner.writes(for: plan) { storage[reminder.id] = reminder }
            scheduledIdentifiers.insert(plan.reminder.id)
            publish()
            return .scheduled(plan.reminder, replaced: plan.replaces)
        }
    }

    func cancel(_ reminderID: UUID) async {
        scheduledIdentifiers.remove(reminderID)
        cancelledIdentifiers.append(reminderID)
        if let reminder = storage[reminderID] { storage[reminderID] = reminder.cancelledCopy() }
        publish()
    }

    func cancelAll(for childID: UUID?) async {
        for reminder in Array(storage.values) where reminder.childID == childID {
            scheduledIdentifiers.remove(reminder.id)
            cancelledIdentifiers.append(reminder.id)
            storage.removeValue(forKey: reminder.id)
        }
        publish()
    }

    func cancelEverything() async {
        cancelledIdentifiers.append(contentsOf: storage.keys)
        scheduledIdentifiers.removeAll()
        storage.removeAll()
        state.justFired = []
        publish()
    }

    private func publish() {
        state.reminders = storage.values.sorted { $0.fireAt < $1.fireAt }
    }
}
