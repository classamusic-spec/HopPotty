import Foundation
import Observation
import HopPottyCore

/// The timer screen's state.
///
/// The schedule is edited as a value and written on every change, then handed
/// straight back to `PottyScheduleService.summarize` so the plain-language
/// preview on screen is derived from the same object that will be persisted.
/// A preview computed from the *pending* edit rather than the saved one is the
/// only way a caregiver can trust it.
@MainActor
@Observable
final class PottyPauseSettingsModel {

    private(set) var schedule: PottySchedule
    private(set) var summary: ScheduleSummary?
    private(set) var screenTime: ScreenTimeConfiguration
    private(set) var failure: ParentFailure?
    private(set) var isWorking = false
    /// Set after a successful "Restore Screen Access", so the row can confirm
    /// rather than leaving the caregiver wondering whether it did anything.
    private(set) var didRestoreAccess = false
    private(set) var testPauseSucceeded: Bool?

    private let environment: ParentEnvironment
    private let childID: UUID

    init(environment: ParentEnvironment, childID: UUID) {
        self.environment = environment
        self.childID = childID
        self.schedule = PottySchedule(childID: childID)
        self.screenTime = ScreenTimeConfiguration(childID: childID)
    }

    var authorizationStatus: ScreenTimeAuthorizationStatus { screenTime.authorizationStatus }

    /// Whether the settings below can do anything. Gentle mode needs no
    /// permission at all, so the screen does not nag about one.
    var needsAuthorization: Bool {
        schedule.mode.requiresScreenTimeAuthorization && !authorizationStatus.canShield
    }

    var canTestPause: Bool {
        schedule.mode.shieldsApps && authorizationStatus.canShield && screenTime.hasSelection
    }

    func load() async {
        schedule = await environment.schedule(for: childID)
        screenTime = await environment.screenTime.snapshot(for: childID).configuration
        recomputeSummary()
    }

    // MARK: Edits
    //
    // Each setter mutates, recomputes the preview, and persists. Persisting on
    // every change rather than behind a Save button is deliberate: this screen
    // has no "discard", and a caregiver who backs out mid-edit should not find
    // half a schedule.

    func setMode(_ mode: PottyPauseMode) async {
        await update { $0.mode = mode }
    }

    func setTriggerBasis(_ basis: PottyTriggerBasis) async {
        await update { $0.triggerBasis = basis }
    }

    func setInterval(_ interval: PottyInterval) async {
        await update { $0.interval = interval }
    }

    func setWarningOffset(_ offset: TimeInterval) async {
        await update { $0.warningOffset = offset }
    }

    func setPauseDuration(_ duration: TimeInterval) async {
        await update {
            // Clamped to the model's own bounds: below the floor a pause is not
            // long enough to reach a bathroom, above the ceiling it stops being
            // a routine and becomes a lockout.
            $0.pauseDuration = min(
                max(duration, PottySchedule.minimumPauseDuration),
                PottySchedule.maximumPauseDuration
            )
        }
    }

    func setCooldown(_ cooldown: TimeInterval) async {
        await update { $0.cooldown = cooldown }
    }

    func setActiveDays(_ days: Set<Weekday>) async {
        await update { $0.activeDays = days }
    }

    func setActiveWindow(start: LocalTimeOfDay, end: LocalTimeOfDay) async {
        await update {
            $0.activeWindowStart = start
            $0.activeWindowEnd = end
        }
    }

    func setEnabled(_ isEnabled: Bool) async {
        await update {
            $0.isEnabled = isEnabled
            // Turning it back on clears any hold, so "Enable" means enabled
            // rather than "enabled but still suspended until Tuesday".
            if isEnabled, $0.suspension != .none { $0.suspension = .none }
        }
    }

    func setQuietWindows(_ windows: [QuietWindow]) async {
        await update { $0.quietWindows = windows }
    }

    func addQuietWindow(_ window: QuietWindow) async {
        await update { $0.quietWindows.append(window) }
    }

    func removeQuietWindow(id: UUID) async {
        await update { $0.quietWindows.removeAll { $0.id == id } }
    }

    // MARK: Actions

    func runTestPause() async {
        isWorking = true
        defer { isWorking = false }
        let result = await environment.screenTime.startPauseNow(for: schedule)
        testPauseSucceeded = result == nil
        failure = result.map { ParentFailure.screenTime($0) }
    }

    /// The emergency exit.
    ///
    /// Unconditional and always available — never gated on a biological
    /// outcome, never gated on the schedule being enabled, and it stays on this
    /// screen even when nothing appears to be shielded, because "appears" is
    /// exactly the case it exists for.
    func restoreScreenAccess() async {
        isWorking = true
        defer { isWorking = false }
        if let screenTimeFailure = await environment.screenTime.restoreScreenAccess() {
            failure = .screenTime(screenTimeFailure)
            didRestoreAccess = false
        } else {
            failure = nil
            didRestoreAccess = true
        }
        await load()
    }

    func refreshScreenTime() async {
        screenTime = await environment.screenTime.snapshot(for: childID).configuration
        recomputeSummary()
    }

    func dismissFailure() { failure = nil }

    private func update(_ mutate: (inout PottySchedule) -> Void) async {
        var updated = schedule
        mutate(&updated)
        guard updated != schedule else { return }
        schedule = updated
        recomputeSummary()
        failure = await environment.saveSchedule(updated)
    }

    private func recomputeSummary() {
        summary = environment.scheduleService.summarize(schedule, at: environment.clock.now)
    }
}
