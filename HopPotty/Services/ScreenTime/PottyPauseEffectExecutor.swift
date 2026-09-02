import Foundation
import HopPottyCore

/// Turns `PottyPauseEffect`s into Screen Time calls, and reports back what
/// happened as `PottyPauseEvent`s.
///
/// ## Why this is so dull
///
/// `PottyPauseMachine` decides; this performs. Every branch below is a `switch`
/// arm with no condition of its own, because a decision made here would be a
/// decision that cannot be tested on a machine without Xcode — and the decisions
/// in this feature are the part that must be tested.
///
/// The one thing it *does* decide is what to report. A `ManagedSettings` write
/// has no return value and no error, so "did the shield go up?" has to be turned
/// into an answer by reading back, and the reading is conservative: anything
/// other than a confident "the store is empty" after a clear is reported as
/// `.shieldClearFailed`, which drives the machine into
/// `errorRequiresParent(.shieldClearFailed)` and puts a caregiver in front of the
/// problem rather than leaving a child in front of it.
///
/// ## Effect ordering
///
/// `PottyPauseEffect` guarantees that `.clearShield` comes first in any bundle
/// that contains it, and this executor performs effects strictly in order. A
/// crash part-way through a bundle therefore leaves the child's apps usable. Do
/// not reorder, batch, or parallelise this loop.
@MainActor
public final class PottyPauseEffectExecutor {

    /// Everything a pause needs that is not Screen Time.
    ///
    /// Notifications, rewards, persistence, the routine UI and the parent
    /// dashboard all live behind this. Declared as one protocol rather than four
    /// injected services because the executor's job is to be a switch statement,
    /// and because a pause must still end correctly when any of them is missing —
    /// every method here is allowed to do nothing.
    public protocol Delegate: AnyObject {
        func scheduleWarningNotification(leadTime: TimeInterval)
        func cancelWarningNotification()
        func presentWarning()
        func presentPauseScreen()
        func dismissPauseScreen()
        func persistSession(_ session: PersistedPauseSession)
        func clearPersistedSession()
        func awardParticipation(_ reason: RewardReason)
        func logPauseOutcome(_ outcome: PauseOutcome)
        func beginCooldown(until: Date)
        func notifyParent(_ notice: ParentNotice)
        /// The schedule to build a monitoring plan from, and whether anything is
        /// selected. `nil` means "no live schedule", which registers nothing.
        func currentScheduleForMonitoring() -> (schedule: PottySchedule, hasSelection: Bool)?
    }

    private let screenTime: any ScreenTimeProviding
    private let monitoring: any ActivityMonitoringProviding
    private let appGroup: AppGroupStore
    private weak var delegate: Delegate?

    /// The widget and the Live Activity.
    ///
    /// Optional, defaulted to `nil`, and never consulted before an effect is
    /// performed — only after. Both are conveniences: every method on either is
    /// allowed to do nothing, neither can fail in a way this executor should
    /// react to, and a build that injects neither behaves exactly as it did
    /// before they existed. That is the whole reason they are wired here rather
    /// than through `Delegate`: a `Delegate` method is something a pause needs,
    /// and these are two things a pause merely tells.
    private let widgets: (any WidgetRefreshing)?
    private let liveActivities: (any LiveActivityControlling)?

    /// The ceiling timer. One at a time, always cancelled before a new one is
    /// armed, and never the only thing standing between a child and their apps —
    /// it dies with the process, which is why the backstop activity and
    /// foreground reconciliation exist.
    private var pauseTimer: Task<Void, Never>?

    /// Events produced by performing effects, fed back into the machine by the
    /// caller. Returned rather than dispatched from here so the executor never
    /// re-enters the machine mid-bundle.
    public private(set) var pendingEvents: [PottyPauseEvent] = []

    public init(
        screenTime: any ScreenTimeProviding,
        monitoring: any ActivityMonitoringProviding,
        appGroup: AppGroupStore = .shared,
        delegate: Delegate? = nil,
        widgets: (any WidgetRefreshing)? = nil,
        liveActivities: (any LiveActivityControlling)? = nil
    ) {
        self.screenTime = screenTime
        self.monitoring = monitoring
        self.appGroup = appGroup
        self.delegate = delegate
        self.widgets = widgets
        self.liveActivities = liveActivities
    }

    /// Perform a bundle, in order, and return the events it produced.
    @discardableResult
    public func perform(_ effects: [PottyPauseEffect], now: Date = Date()) -> [PottyPauseEvent] {
        pendingEvents = []
        for effect in effects { perform(effect, now: now) }
        let events = pendingEvents
        pendingEvents = []
        return events
    }

    private func perform(_ effect: PottyPauseEffect, now: Date) {
        switch effect {

        // MARK: Authorization

        case .requestAuthorization:
            Task { [screenTime] in
                let result = await screenTime.requestAuthorization()
                // Deliberately not folded into `pendingEvents`: this is
                // asynchronous and the bundle has long since finished. The caller
                // observes `authorizationUpdates` and feeds the machine from there.
                _ = result
            }

        // MARK: Monitoring

        case .registerMonitoring:
            guard let context = delegate?.currentScheduleForMonitoring() else {
                monitoring.cancelAllMonitoring()
                pendingEvents.append(.monitoringRegistrationFailed)
                return
            }
            let plan = MonitoringPlan.make(for: context.schedule, hasSelection: context.hasSelection)
            appGroup.saveGate(MonitoringGate(schedule: context.schedule))
            switch monitoring.register(plan) {
            case .success(let registration):
                // An empty registration is not a success. A caregiver who has
                // switched Potty Pause on and had nothing registered must be told,
                // not left with a screen that says "armed".
                pendingEvents.append(registration.isEmpty ? .monitoringRegistrationFailed : .monitoringRegistered)
            case .failure:
                pendingEvents.append(.monitoringRegistrationFailed)
            }
            // Whatever happened, the schedule the widget draws has just been
            // re-derived. Fire-and-forget: a widget must never make a pause wait.
            widgets?.scheduleDidChange()

        case .cancelMonitoring:
            monitoring.cancelAllMonitoring()
            appGroup.clearGate()
            widgets?.scheduleDidChange()

        // MARK: Warnings

        case .scheduleWarningNotification(let leadTime):
            delegate?.scheduleWarningNotification(leadTime: leadTime)

        case .cancelWarningNotification:
            delegate?.cancelWarningNotification()

        case .presentWarning:
            delegate?.presentWarning()

        // MARK: The shield

        case .applyShield:
            guard let duration = delegate?.currentScheduleForMonitoring()?.schedule.pauseDuration else {
                pendingEvents.append(.shieldApplyFailed)
                return
            }
            switch screenTime.applyShield(plannedDuration: duration, now: now) {
            case .success(let record):
                // The safety net goes up immediately after the shield, never
                // before: a backstop for a pause that failed to start would end a
                // pause that does not exist, which is harmless but confusing in
                // the logs, whereas a shield without a backstop is the thing worth
                // avoiding by a matter of milliseconds.
                monitoring.registerBackstop(for: record)

                // The two courtesy surfaces, in that order and after the
                // backstop. A pause that is real but unannounced is a small
                // problem; an announcement of a pause that failed to start is a
                // caregiver told their child's apps are held when they are not.
                //
                // `plannedEndAt`, not `backstopEndAt`: the backstop is the
                // fifteen-minute ceiling under the worst case, and putting it on
                // a lock screen would tell a family a three-minute pause lasts a
                // quarter of an hour.
                liveActivities?.start(
                    sessionID: record.sessionID,
                    isGuidedRoutine: delegate?.currentScheduleForMonitoring()?.schedule.mode == .routine,
                    startedAt: record.startedAt,
                    expectedEndAt: record.plannedEndAt,
                    mood: .cheer
                )
                widgets?.pauseDidStart(endingAt: record.plannedEndAt)

                pendingEvents.append(.shieldApplied)
            case .failure:
                // Belt and braces. The apply may have half-succeeded — a partially
                // applied store is indistinguishable from a full one from the
                // outside — so the failure path clears before reporting.
                screenTime.clearShield(reason: .malformedSession)
                pendingEvents.append(.shieldApplyFailed)
            }

        case .clearShield:
            performClear(reason: .pauseEnded)

        // MARK: Timers

        case .startPauseTimer(let expiresAt):
            startPauseTimer(expiringAt: expiresAt, now: now)

        case .cancelPauseTimer:
            pauseTimer?.cancel()
            pauseTimer = nil

        // MARK: UI

        case .presentPauseScreen:
            delegate?.presentPauseScreen()

        case .dismissPauseScreen:
            delegate?.dismissPauseScreen()

        // MARK: Persistence and bookkeeping

        case .persistSession(let session):
            delegate?.persistSession(session)

        case .clearPersistedSession:
            delegate?.clearPersistedSession()

        case .awardParticipation(let reason):
            delegate?.awardParticipation(reason)

        case .logPauseOutcome(let outcome):
            delegate?.logPauseOutcome(outcome)

        case .beginCooldown(let until):
            appGroup.setCooldown(until: until)
            delegate?.beginCooldown(until: until)

        case .notifyParent(let notice):
            delegate?.notifyParent(notice)
        }
    }

    // MARK: - Clearing, and how failure is detected

    /// Clear, then check.
    ///
    /// `ManagedSettingsStore` writes return nothing, so the only available
    /// evidence is a read-back. Two things follow:
    ///
    /// - The read-back is of HopPotty's own store, which records what was *asked
    ///   for*. Apple is explicit that "the system doesn't guarantee that the
    ///   settings you specify govern the device's behavior", so a clean read-back
    ///   is not proof the child's apps work. It is only proof HopPotty is no
    ///   longer asking for them to be shielded, which is the whole of what
    ///   HopPotty controls.
    /// - A dirty read-back is reported as `.shieldClearFailed` even though the
    ///   clear may in fact have worked and the read may be stale. Over-reporting
    ///   here costs a caregiver one alarming-but-actionable screen with a
    ///   "Restore Screen Access" button on it. Under-reporting costs a child
    ///   their apps with nobody told. The asymmetry decides it.
    ///
    /// ## The `errorAccessRestored` path specifically
    ///
    /// `parentRestoredAccess` is accepted from every state, including every error
    /// state, and lands in `errorAccessRestored(failure)` — "the failure is still
    /// unresolved, but a clear has been issued and the child's apps are back".
    /// That state reports `mayHaveShieldUp == false`, which is only true if the
    /// clear actually took.
    ///
    /// This method is what makes that claim honest. When the read-back still
    /// shows a shield, `.shieldClearFailed` is emitted, the machine leaves
    /// `errorAccessRestored` and re-enters `errorRequiresParent(.shieldClearFailed)`,
    /// and a caregiver is put in front of the problem. The state machine is never
    /// allowed to assert that a child has their apps back on the strength of a
    /// write nobody checked.
    ///
    /// UNVERIFIED — confirm on device: whether `ManagedSettingsStore` reads
    /// reflect writes made moments earlier in the same process. If they are
    /// eventually-consistent, this check will occasionally report a false
    /// `.shieldClearFailed`. That is the failure direction chosen above, and
    /// `Docs/PhysicalDeviceQA.md` §9.3.2 measures it.
    private func performClear(reason: ShieldReconciler.ClearReason) {
        pauseTimer?.cancel()
        pauseTimer = nil
        monitoring.cancelBackstop()

        // Taken down *before* the clear is attempted, and unconditionally.
        //
        // The asymmetry with the start path is deliberate and is the same
        // asymmetry the rest of this file is built on: an announcement is
        // published only when a pause is certainly running, and it is retracted
        // the moment a pause might be ending. A Live Activity that outlives its
        // pause tells a family their child's apps are still held when they are
        // not — and if the clear then fails, the caregiver is put in front of
        // `errorRequiresParent` a few lines below, which is a screen with a
        // "Restore Screen Access" button on it rather than a countdown.
        liveActivities?.end(at: Date())
        widgets?.pauseDidEnd()

        screenTime.clearShield(reason: reason)

        if screenTime.believesShieldIsUp {
            // One more attempt before giving up on it, because the cheapest
            // possible fix for a write that did not land is the same write again.
            screenTime.clearShield(reason: reason)
        }

        pendingEvents.append(screenTime.believesShieldIsUp ? .shieldClearFailed : .shieldCleared)
    }

    /// The in-app ceiling timer.
    ///
    /// Scheduled against an absolute instant, so a timezone change or a DST
    /// transition cannot move it. Not scheduled against `Timer` with a wall-clock
    /// fire date, and not the only mechanism ending the pause: it dies when the
    /// process does, which is exactly the case the backstop activity and cold-start
    /// reconciliation exist to cover.
    ///
    /// If the deadline has already passed — a clock jumped forward, or the app was
    /// suspended across it — the event fires immediately rather than being skipped.
    private func startPauseTimer(expiringAt expiresAt: Date, now: Date) {
        pauseTimer?.cancel()
        let interval = max(0, expiresAt.timeIntervalSince(now))
        pauseTimer = Task { [weak self] in
            if interval > 0 {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                self.pendingEvents.append(.pauseTimerExpired)
                self.timerDidExpire?(.pauseTimerExpired)
            }
        }
    }

    /// Called when the ceiling timer fires outside a `perform` bundle. The owner
    /// wires this to feed the machine.
    public var timerDidExpire: ((PottyPauseEvent) -> Void)?
}
