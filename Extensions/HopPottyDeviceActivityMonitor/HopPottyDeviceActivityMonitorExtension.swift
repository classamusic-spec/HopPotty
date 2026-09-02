import Foundation
import DeviceActivity
import ManagedSettings
import HopPottyCore

/// HopPotty's `DeviceActivityMonitor`.
///
/// ## What this process is
///
/// The system wakes it, hands it one `DeviceActivityName`, and expects it to
/// finish. It has no UI, no `ModelContainer`, no network, and no way to ask the
/// app anything — the app is usually not running, which is the entire reason the
/// extension exists. Apple documents no memory ceiling and no time budget for it
/// (`Docs/ScreenTimeArchitecture.md` §4), so it is engineered as if both were
/// tiny, which costs nothing.
///
/// **The rules this file keeps:**
///
/// - No SwiftUI, no SwiftData, no design tokens, no image decoding, no `HopCopy`
///   lookups, no FamilyControls. The only frameworks are the two it cannot avoid
///   plus Foundation-only `HopPottyCore`.
/// - Every callback does the same three things in the same order: stamp a
///   heartbeat, reconcile, then at most one decision. Nothing is computed that
///   could have been computed in the app.
/// - **Every callback must be correct if it is never called.** Apple gates
///   `intervalDidStart` and `intervalDidEnd` on the device being in use, and
///   documents nothing about the warning callbacks. Nothing here is the only
///   thing standing between a child and their apps: `Docs/ScreenTimeArchitecture.md`
///   §9 lists four independent end-paths and this file is two of them.
/// - `super` is called first in every override, because Apple's base class is
///   documented as requiring it and the consequences of skipping it are not.
///
/// ## Why reconciliation runs on every callback
///
/// This process is frequently the first HopPotty code to run after a crash, a
/// force-quit, or a reboot. If a shield outlived its session, this is often the
/// earliest moment anything can notice. `ShieldReconciler.reconcile` is cheap, is
/// idempotent, and resolves every ambiguity toward clearing.
final class HopPottyDeviceActivityMonitorExtension: DeviceActivityMonitor {

    // Constructed per call rather than stored. A stored property would be state
    // in a process that is supposed to have none, and `AppGroupStore` is a value
    // whose construction is two `FileManager` calls.
    private var store: AppGroupStore { AppGroupStore.shared }

    /// The widget's own corner of the App Group.
    ///
    /// A second store rather than more methods on the first, because the two
    /// boundaries have nothing in common: `AppGroupStore` carries the pause
    /// record that decides whether a shield stands, and this carries a countdown
    /// somebody might glance at. See the note at the top of
    /// `WidgetSnapshotStore.swift`.
    private var widgets: WidgetSnapshotStore { WidgetSnapshotStore.shared }

    private func now() -> Date { Date() }

    /// Tell the widget the pause it is about to draw is over.
    ///
    /// Called on every path that clears a shield from inside this process. Both
    /// calls are best-effort and neither is allowed to fail the clear: this runs
    /// *after* `ShieldReconciler` has done the thing that matters, and a widget
    /// left showing a stale countdown is a cosmetic defect, while a shield left
    /// standing is not.
    private func widgetPauseEnded() {
        widgets.markPauseEnded(now: now())
        widgets.reloadTimelines()
    }

    /// Stamp, reconcile, and report where we were woken from.
    ///
    /// Returns the reconciliation verdict so a caller can tell "there was a live
    /// pause" from "there was a stranded shield and it is now gone".
    @discardableResult
    private func begin(_ kind: ExtensionReport.Kind, activity: DeviceActivityName?) -> ShieldReconciler.Verdict {
        let instant = now()
        let verdict = ShieldReconciler.reconcile(
            store: store, source: .monitor, beating: .monitor, now: instant
        )
        store.appendReport(
            ExtensionReport(
                source: .monitor,
                kind: kind,
                at: instant,
                sessionID: store.loadPause()?.sessionID,
                activityRole: activity.map { ScreenTimeIdentifiers.role(of: $0.rawValue) }
            )
        )
        return verdict
    }

    /// Stop an activity HopPotty does not recognise.
    ///
    /// Only ever an orphan: a name from a previous build, or one left behind by a
    /// registration that was interrupted. Left alone it would call this extension
    /// forever. Stopping it from here — rather than waiting for the app to notice
    /// on next foreground — matters because a family may not open HopPotty for
    /// days, and an orphaned clock activity would start a pause every day in the
    /// meantime with no record explaining why.
    private func stopOrphan(_ activity: DeviceActivityName) {
        DeviceActivityCenter().stopMonitoring([activity])
        store.appendReport(
            ExtensionReport(
                source: .monitor,
                kind: .monitoringStopped,
                at: now(),
                activityRole: .unrecognised
            )
        )
    }

    // MARK: - Intervals

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        begin(.intervalDidStart, activity: activity)

        switch ScreenTimeIdentifiers.role(of: activity.rawValue) {
        case .clock:
            // A wall-clock slot came round. This *is* the trigger for a clockTime
            // schedule — there is no separate event, because a schedule describes
            // an interval and the interval's start is the appointment.
            startPause(trigger: .clock)

        case .usage:
            // The active window opened. Nothing happens here: for a screenActivity
            // schedule the trigger is a usage threshold inside this interval, not
            // the interval itself. Registering the window is what starts the
            // clock on accumulating that usage.
            break

        case .backstop:
            // Registered at pause start, so its interval is already running when
            // it is registered — Apple: the extension "may begin receiving
            // callbacks as soon as the system calls this method if the activity's
            // scheduled interval is ongoing." Expected, and nothing to do.
            break

        case .unrecognised:
            stopOrphan(activity)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        begin(.intervalDidEnd, activity: activity)

        switch ScreenTimeIdentifiers.role(of: activity.rawValue) {
        case .backstop:
            // **The guaranteed ceiling.** Path (C) in
            // `Docs/ScreenTimeArchitecture.md` §9: fifteen minutes after the pause
            // began, whatever else did or did not happen. Cleared unconditionally
            // and without consulting the record — reaching this callback means
            // every other end-path missed, so the record is the last thing to
            // trust about whether a shield should still be up.
            ShieldReconciler.forceClear(reason: .backstopElapsed, store: store, source: .monitor)
            DeviceActivityCenter().stopMonitoring([activity])
            widgetPauseEnded()

        case .clock, .usage:
            // The caregiver's active window closed. A pause must not outlive it —
            // a shield that persists past bedtime is exactly the "indefinite
            // lockout" this layer exists to prevent.
            ShieldReconciler.forceClear(reason: .scheduleDisabled, store: store, source: .monitor)
            widgetPauseEnded()

        case .unrecognised:
            stopOrphan(activity)
        }
    }

    // MARK: - Warnings
    //
    // UNVERIFIED — confirm on device: whether these are gated on "device in use"
    // the way `intervalDidStart`/`intervalDidEnd` explicitly are, and how punctual
    // they are. Apple documents the gate only for the `did` callbacks. The
    // intended pause duration rides on `intervalWillEndWarning`, so this is the
    // single most important measurement in `Docs/PhysicalDeviceQA.md`.

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        begin(.intervalWillStartWarning, activity: activity)
        // The approach cue for a clock schedule. Recorded and nothing more: this
        // extension deliberately posts no notifications. Warning notifications are
        // the notification service's job and are pre-scheduled by the app, which
        // can do it with the child's name, the right language, and Contract §4.7's
        // rules about what HopPotty is allowed to interrupt a family for.
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        begin(.intervalWillEndWarning, activity: activity)

        guard ScreenTimeIdentifiers.role(of: activity.rawValue) == .backstop else { return }

        // **The intended end of the pause.** Path (B) in §9. `warningTime` was set
        // to `backstopEnd − plannedEnd` precisely so this lands here.
        //
        // Cleared without checking whether `plannedEndAt` has arrived. If the
        // callback is early, the pause ends early, which the product permits;
        // if it is late, the record has already expired and the reconciliation at
        // the top of this method cleared it a moment ago. Both directions are
        // safe, and neither can extend a pause.
        ShieldReconciler.forceClear(reason: .pauseEnded, store: store, source: .monitor)
        DeviceActivityCenter().stopMonitoring([activity])
        widgetPauseEnded()
    }

    override func eventWillReachThresholdWarning(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        begin(.eventWillReachThresholdWarning, activity: activity)
        // Recorded only. See the note in `intervalWillStartWarning`, and the
        // honest limitation in `Docs/PhysicalDeviceQA.md`: for a usage-based
        // schedule the app cannot know in advance when a threshold will be
        // crossed, so a pre-pause warning cannot currently be delivered while
        // HopPotty is not running. That is a product decision waiting to be made,
        // not a bug to be worked around here.
    }

    // MARK: - Thresholds

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        begin(.eventDidReachThreshold, activity: activity)

        guard ScreenTimeIdentifiers.eventRole(of: event.rawValue) == .threshold else { return }
        guard ScreenTimeIdentifiers.role(of: activity.rawValue) == .usage else { return }

        // A rung of the usage ladder was reached: the child has now spent another
        // interval's worth of foreground time on the device.
        startPause(trigger: .usage)
    }

    // MARK: - Starting a pause

    /// Open a pause from inside the extension.
    ///
    /// This is the only place in HopPotty where a shield goes up without the app
    /// running, so every guard is stated rather than assumed, and every one of
    /// them fails toward **not** shielding. A missed pause is a reminder that did
    /// not happen. An unwanted pause is a child's device that stops working during
    /// a nap, a meal, or a school day, with nobody around who knows why.
    private func startPause(trigger: ScreenTimeIdentifiers.ActivityRole) {
        let instant = now()

        func refuse(_ failure: ScreenTimeFailure) {
            store.appendReport(
                ExtensionReport(
                    source: .monitor,
                    kind: .failure,
                    at: instant,
                    activityRole: trigger,
                    failureCode: failure.rawValue
                )
            )
        }

        // 1. Never start a second pause on top of a first. `mayHaveShieldUp` is
        //    the conservative reading, so a half-written record also blocks.
        if let existing = store.loadPause(), existing.state.mayHaveShieldUp { return }

        // 2. The gate. No gate means the app has never registered a schedule, or
        //    the container is unreachable. Either way this process does not know
        //    how long a pause should last, and inventing a duration would be the
        //    single most dangerous thing it could do.
        guard let gate = store.loadGate() else {
            refuse(.extensionUnavailable)
            return
        }

        // 3. Active day, active window, quiet hours. Evaluated on the wall clock,
        //    in the device's current zone, which is what "not during his nap"
        //    means to the family that configured it.
        guard gate.permitsPause(at: instant) else { return }

        // 4. The post-pause quiet period, so a child is not re-interrupted the
        //    moment they get back to what they were doing.
        guard store.isCooldownElapsed(at: instant, limit: gate.cooldownSeconds) else { return }

        // 5. Something to shield. A usage trigger with no tokens can only produce
        //    a shield over nothing, which would show the child a Potty Pause
        //    screen they cannot dismiss by leaving the app.
        guard let tokens = store.loadShieldTokens(), !tokens.isEmpty else {
            refuse(.noSelection)
            return
        }

        // 6. Record first, shield second — the same ordering the app uses, for the
        //    same reason. A crash between the two leaves a record saying "a shield
        //    may be up", which every reconciliation path resolves by clearing. The
        //    reverse would leave a shield no record claims.
        let record = SharedPauseRecord.starting(
            at: instant,
            uptime: ProcessInfo.processInfo.systemUptime,
            plannedDuration: gate.safePauseDuration
        )
        guard store.savePause(record) else {
            refuse(.extensionUnavailable)
            return
        }

        guard ShieldApplier.apply(tokens) else {
            store.clearPause()
            refuse(.shieldApplyFailed)
            return
        }

        store.advancePause(to: .shielded)

        // 7. Arm the safety net before reporting success, so a crash in the
        //    reporting step still leaves a bounded pause.
        registerBackstop(for: record)

        store.appendReport(
            ExtensionReport(
                source: .monitor,
                kind: .pauseStarted,
                at: instant,
                sessionID: record.sessionID,
                activityRole: trigger
            )
        )

        // 8. Last of all, the widget. This process is often the only HopPotty
        //    code that will run for hours — a clock schedule fires at 10:00 with
        //    the app closed and stays closed until bedtime — so without this the
        //    home screen would count down to a pause that already happened, and
        //    keep counting down through the pause itself.
        //
        //    `WidgetCenter` is available to app extensions, which is what makes
        //    this possible at all. It is a *request* for a redraw, and the system
        //    decides whether to honour it; nothing above depends on the answer,
        //    and this is deliberately the last statement in the method so that a
        //    failure here cannot cost a pause its backstop or its report.
        widgets.markPauseStarted(endingAt: record.plannedEndAt, now: instant)
        widgets.reloadTimelines()
    }

    /// Register the 15-minute backstop from inside the extension.
    ///
    /// The *call* is duplicated from `ActivityMonitoringService`; the *decision*
    /// is not. Both ask `SharedPauseRecord.backstopScheduleComponents()` what to
    /// register, so a pause started by the extension gets a backstop identical to
    /// one started by the app. Sharing the call itself would mean linking the
    /// app's monitoring service — an `@Observable @MainActor` class — into a
    /// process that has no main actor to speak of.
    ///
    /// `repeats: false`, so this activity stops calling back after one interval
    /// and cannot become an orphan that ends future pauses early.
    private func registerBackstop(for record: SharedPauseRecord) {
        let components = record.backstopScheduleComponents()
        let schedule = DeviceActivitySchedule(
            intervalStart: components.start,
            intervalEnd: components.end,
            repeats: false,
            warningTime: components.warning
        )
        do {
            try DeviceActivityCenter().startMonitoring(
                DeviceActivityName(hopPotty: ScreenTimeIdentifiers.backstopActivityName),
                during: schedule
            )
        } catch {
            // A pause without its safety net still ends: on the app's next
            // foreground, on the child's tap, or on a caregiver override. Recorded
            // so the Potty Pause Lab can show a pause running unprotected, which
            // is precisely the condition worth catching on a test device.
            store.appendReport(
                ExtensionReport(
                    source: .monitor,
                    kind: .failure,
                    at: now(),
                    sessionID: record.sessionID,
                    activityRole: .backstop,
                    failureCode: ScreenTimeFailure.monitoringRegistrationFailed.rawValue
                )
            )
        }
    }
}
