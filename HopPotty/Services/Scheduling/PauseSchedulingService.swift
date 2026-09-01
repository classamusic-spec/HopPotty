import Foundation
import HopPottyCore

/// Turns a stored schedule into the one notification HopPotty schedules ahead of
/// time, and keeps a suspension's expiry from rotting on disk.
///
/// ## Division of labour
///
/// - `PottyScheduleService` (Core) does all the arithmetic. It reads no clock,
///   no locale and no time zone of its own, which is what makes it testable on
///   a Linux CI box at 1:30 AM on the first Sunday in November.
/// - `ScreenTimeCoordinator` (another agent's file) owns registration,
///   shielding and the App Group record.
/// - This type is the small piece in between: read the schedule, ask Core when
///   the warning is, tell `NotificationService`, and write back a suspension
///   that has expired.
///
/// It deliberately does not decide *whether a pause may start*. That answer has
/// to be the same in the app and in the monitor extension, so it stays in Core
/// where both can call it.
@MainActor
final class PauseSchedulingService {
    private let schedules: any ScheduleRepository
    private let profiles: any ChildProfileRepository
    private let notifications: any NotificationProviding
    private let settingsStore: any SettingsRepository
    private let clock: any HopClock

    init(
        schedules: any ScheduleRepository,
        profiles: any ChildProfileRepository,
        notifications: any NotificationProviding,
        settings: any SettingsRepository,
        clock: any HopClock = SystemClock()
    ) {
        self.schedules = schedules
        self.profiles = profiles
        self.notifications = notifications
        self.settingsStore = settings
        self.clock = clock
    }

    private var engine: PottyScheduleService {
        PottyScheduleService(calendar: clock.calendar)
    }

    // MARK: Projections

    /// When the next pause could happen, and what pushed it there.
    ///
    /// `accumulatedActivity` comes from `DeviceActivity` for a `.screenActivity`
    /// schedule and is ignored for a `.clockTime` one. It is a parameter rather
    /// than state because the only process that really knows it is the monitor
    /// extension.
    func nextPause(
        for childID: UUID,
        lastPauseEnd: Date? = nil,
        accumulatedActivity: TimeInterval = 0
    ) async throws -> PauseProjection? {
        guard let state = try await scheduleState(
            childID: childID,
            lastPauseEnd: lastPauseEnd,
            accumulatedActivity: accumulatedActivity
        ) else { return nil }
        return engine.nextPause(after: state)
    }

    /// Whether a pause may start right now, and if not, why not.
    func canStartPause(
        for childID: UUID,
        lastPauseEnd: Date? = nil,
        accumulatedActivity: TimeInterval = 0
    ) async throws -> PauseStartDecision? {
        guard let state = try await scheduleState(
            childID: childID,
            lastPauseEnd: lastPauseEnd,
            accumulatedActivity: accumulatedActivity
        ) else { return nil }
        return engine.canStartPause(at: state)
    }

    // MARK: Warnings

    /// Brings the scheduled heads-up in line with the schedule as it stands now.
    ///
    /// Called on foreground, after a schedule edit, and after a pause ends.
    /// Idempotent: the notification identifier is derived from the child, so
    /// re-arming replaces rather than stacks.
    func refreshWarning(
        for childID: UUID,
        lastPauseEnd: Date? = nil,
        accumulatedActivity: TimeInterval = 0
    ) async throws {
        let settings = try await settingsStore.settings()
        guard settings.warningNotificationsEnabled else {
            await notifications.cancelWarning(childID: childID)
            return
        }
        guard let state = try await scheduleState(
            childID: childID,
            lastPauseEnd: lastPauseEnd,
            accumulatedActivity: accumulatedActivity
        ) else {
            await notifications.cancelWarning(childID: childID)
            return
        }

        guard let warning = engine.nextWarning(for: state), warning.shouldNotify else {
            // Either there is no next pause, the warning instant has already
            // passed, or it would land inside quiet hours. Core has already
            // made that judgement; the service does not second-guess it.
            await notifications.cancelWarning(childID: childID)
            return
        }

        let nickname = try await profiles.profile(id: childID)?.nickname
        await notifications.scheduleWarning(
            childID: childID,
            nickname: nickname,
            fireAt: warning.fireAt
        )
        HopLog.scheduling.info(
            "warning armed child=\(HopLog.tag(for: childID), privacy: .public) leadSeconds=\(Int(warning.leadTime), privacy: .public)"
        )
    }

    /// Re-arms every child's warning. Launch and foreground.
    func refreshAllWarnings() async throws {
        for schedule in try await schedules.allSchedules() {
            try await refreshWarning(for: schedule.childID)
        }
    }

    /// Cancels everything for a child. Called when a profile is deleted or
    /// Potty Pause is switched off.
    func cancelWarnings(for childID: UUID) async {
        await notifications.cancelWarning(childID: childID)
    }

    // MARK: Suspensions

    /// Collapses an expired hold to `.none` and writes it back.
    ///
    /// A "suspended until 3pm" that is still on disk at 6pm makes every screen
    /// that reads the schedule describe a state the family is no longer in.
    /// Resolving on read and persisting only when it actually changed keeps the
    /// stored value honest without writing on every dashboard refresh.
    ///
    /// `consumingSkip` is `false` here on purpose: spending the caregiver's
    /// "skip the next one" belongs to the code that actually suppresses a pause,
    /// not to a refresh.
    @discardableResult
    func resolveSuspension(for childID: UUID) async throws -> SuspensionResolution? {
        guard var schedule = try await schedules.schedule(for: childID) else { return nil }
        let resolution = engine.resolveSuspension(schedule.suspension, at: clock.now)
        guard resolution.didChange else { return resolution }
        schedule.suspension = resolution.suspension
        schedule.modifiedAt = clock.now
        try await schedules.save(schedule)
        HopLog.scheduling.info("suspension resolved child=\(HopLog.tag(for: childID), privacy: .public)")
        return resolution
    }

    // MARK: Settings

    /// Applies the caregiver's notification preferences: the daily summary, and
    /// the master switch for warnings.
    func applyNotificationSettings(_ settings: AppSettings) async throws {
        await notifications.applySummarySettings(settings)
        if settings.warningNotificationsEnabled {
            try await refreshAllWarnings()
        } else {
            for schedule in try await schedules.allSchedules() {
                await notifications.cancelWarning(childID: schedule.childID)
            }
        }
    }

    // MARK: Helpers

    private func scheduleState(
        childID: UUID,
        lastPauseEnd: Date?,
        accumulatedActivity: TimeInterval
    ) async throws -> ScheduleState? {
        guard let schedule = try await schedules.schedule(for: childID) else { return nil }
        return ScheduleState(
            schedule: schedule,
            now: clock.now,
            lastPauseEnd: lastPauseEnd,
            accumulatedActivity: accumulatedActivity
        )
    }
}
