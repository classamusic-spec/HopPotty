import Foundation
import HopPottyCore

/// The port the rest of the app uses to keep the widget honest.
///
/// One protocol, five methods, and every one of them is allowed to do nothing.
/// That is the whole contract: **the widget is a convenience and nothing depends
/// on it.** A refresh that fails, a WidgetKit budget that is spent, an App Group
/// that is unreachable — none of them may change what happens to a child's
/// device. The shield, the notification and the routine all work with the widget
/// frozen on yesterday's frame.
///
/// Injected as an existential so a preview or a test substitutes
/// `NoOpWidgetRefresher` and no feature knows the difference, in the same way
/// every other service in `ServiceContainer` is injected.
@MainActor
protocol WidgetRefreshing: AnyObject {

    /// Publish a snapshot the caller has already built, and ask for a redraw.
    func publish(_ snapshot: WidgetSnapshot)

    /// Rebuild the snapshot from the stored schedule for the active child.
    ///
    /// The ordinary path: called after a schedule edit, on foreground, and when
    /// a pause ends. `quickReminderAt` is passed in rather than read, because
    /// Quick Reminders are owned by their own feature and this service has no
    /// business reaching into another feature's store to find one.
    func refresh(quickReminderAt: Date?) async

    /// The schedule changed, and the caller cannot wait for a rebuild.
    ///
    /// The path from `PottyPauseEffectExecutor`, which performs a bundle of
    /// effects synchronously and must not be made to `await` a widget. Carries
    /// forward whatever Quick Reminder is already published, because the
    /// executor has no reminder to hand and dropping one would take a caregiver's
    /// timer off their lock screen for no reason.
    func scheduleDidChange()

    /// A pause or routine has begun and is expected to end at `endingAt`.
    ///
    /// Cheap and synchronous: it edits the published snapshot in place rather
    /// than re-projecting a schedule, because the caller is on the path that
    /// just put a shield in front of a child and has better things to do.
    func pauseDidStart(endingAt: Date)

    /// Whatever was running has stopped.
    func pauseDidEnd()

    /// Remove the snapshot entirely. Called by "Delete everything".
    func clear()
}

// MARK: - Live

/// Writes `widget.json` into the App Group and asks WidgetKit to redraw.
///
/// ## Where the numbers come from
///
/// Nowhere in this file. The projection is `PottyScheduleService`'s, the shape of
/// the record is `WidgetSnapshotBuilder`'s, and the refresh cadence is
/// `WidgetTimelinePlan`'s — all three in `HopPottyCore`, all three tested on
/// Linux. What is left here is reading three repositories and handing the answers
/// over, which is exactly as much as a service that cannot be unit-tested without
/// a store should be doing.
///
/// ## The child's name
///
/// ``showsChildName`` is `false` and there is no setting that turns it on yet.
/// A widget is legible from a locked screen by anyone holding the phone, so
/// putting a child's name there is a caregiver's decision to make explicitly, and
/// the switch that lets them make it is a settings-screen change that belongs
/// with the rest of the settings screen. Until it exists the widget uses the
/// neutral phrasing, which is the same fallback every other surface uses for a
/// family who never typed a nickname. `Docs/Widgets.md` §2.
@MainActor
final class WidgetRefreshService: WidgetRefreshing {

    private let schedules: any ScheduleRepository
    private let profiles: any ChildProfileRepository
    private let settingsStore: any SettingsRepository
    private let store: WidgetSnapshotStore
    private let clock: any HopClock

    /// See the type note. Constructor-injected rather than hard-coded so the
    /// switch, when it lands, has somewhere to be wired to.
    private let showsChildName: Bool

    init(
        schedules: any ScheduleRepository,
        profiles: any ChildProfileRepository,
        settings: any SettingsRepository,
        store: WidgetSnapshotStore = .shared,
        clock: any HopClock = SystemClock(),
        showsChildName: Bool = false
    ) {
        self.schedules = schedules
        self.profiles = profiles
        self.settingsStore = settings
        self.store = store
        self.clock = clock
        self.showsChildName = showsChildName
    }

    // MARK: WidgetRefreshing

    func publish(_ snapshot: WidgetSnapshot) {
        store.save(snapshot)
        store.reloadTimelines()
    }

    func refresh(quickReminderAt: Date? = nil) async {
        let now = clock.now
        do {
            publish(try await buildSnapshot(quickReminderAt: quickReminderAt, now: now))
        } catch {
            // A store that cannot answer is not a reason to leave a stale answer
            // on a lock screen. Publishing the empty state says "open HopPotty",
            // which is both true and actionable; leaving this morning's countdown
            // up says something false.
            HopLog.scheduling.error(
                "widget refresh failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            publish(.empty(at: now))
        }
    }

    func scheduleDidChange() {
        // Read before the hop off, so the carried reminder is the one that was
        // published at the moment the schedule changed rather than whatever is
        // there when the task happens to run.
        let carried = store.load()?.quickReminderAt
        Task { [weak self] in await self?.refresh(quickReminderAt: carried) }
    }

    func pauseDidStart(endingAt: Date) {
        store.markPauseStarted(endingAt: endingAt, now: clock.now)
        store.reloadTimelines()
    }

    func pauseDidEnd() {
        store.markPauseEnded(now: clock.now)
        store.reloadTimelines()
    }

    func clear() {
        store.clear()
        store.reloadTimelines()
    }

    // MARK: Building

    /// Read the active child's schedule and project it.
    ///
    /// "Active child" comes from `AppSettings`, the same value the rest of the
    /// app uses to decide whose day it is showing. When there is no active child
    /// — a fresh install, every profile deleted — the widget shows the empty
    /// state rather than picking one, because picking one would put a name and a
    /// schedule on a lock screen that nobody chose.
    private func buildSnapshot(quickReminderAt: Date?, now: Date) async throws -> WidgetSnapshot {
        let reminder = quickReminderAt.map { QuickReminder(fireAt: $0, createdAt: now) }

        let settings = try await settingsStore.settings()
        guard
            let childID = settings.activeChildID,
            let schedule = try await schedules.schedule(for: childID)
        else {
            return WidgetSnapshotBuilder.emptySnapshot(quickReminder: reminder, now: now)
        }

        let nickname = showsChildName ? try await profiles.profile(id: childID)?.nickname : nil

        return WidgetSnapshotBuilder.snapshot(
            state: ScheduleState(schedule: schedule, now: now),
            using: PottyScheduleService(calendar: clock.calendar),
            quickReminder: reminder,
            childNickname: nickname,
            includeChildName: showsChildName,
            // A pause the app knows about is published through `pauseDidStart`.
            // Re-deriving it here would mean asking the App Group during a
            // routine schedule refresh, which is a read this path does not need.
            pauseEndsAt: store.load()?.pauseEndsAt
        )
    }
}

// MARK: - Fake

/// Publishes nothing and reloads nothing.
///
/// The set a preview, a UI test and the DebugMock scheme get. Unlike
/// `MockScreenTimeService` this one is **not** inside `#if DEBUG`: a no-op widget
/// refresher in a shipping binary could at worst leave a widget stale, which is
/// the failure the whole layer is already designed to tolerate. A fake Screen
/// Time service is a different kind of object entirely, and that is why it gets a
/// different kind of guarantee.
@MainActor
final class NoOpWidgetRefresher: WidgetRefreshing {
    /// What the fake was last asked to do, so a test can assert on it.
    private(set) var published: [WidgetSnapshot] = []
    private(set) var refreshCount = 0
    private(set) var scheduleChangeCount = 0
    private(set) var pauseStarts: [Date] = []
    private(set) var pauseEndCount = 0
    private(set) var clearCount = 0

    init() {}

    func publish(_ snapshot: WidgetSnapshot) { published.append(snapshot) }
    func refresh(quickReminderAt: Date?) async { refreshCount += 1 }
    func scheduleDidChange() { scheduleChangeCount += 1 }
    func pauseDidStart(endingAt: Date) { pauseStarts.append(endingAt) }
    func pauseDidEnd() { pauseEndCount += 1 }
    func clear() { clearCount += 1 }
}
