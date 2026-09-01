import Foundation
import HopPottyCore
import DeviceActivity

/// HopPotty's one adapter onto `DeviceActivity`.
///
/// ## Conflict resolution when re-registering
///
/// A caregiver can change the interval, the trigger basis, the active window or
/// the quiet hours at any moment, including while a pause is running. Each change
/// means the set of activities the system should be running has changed. The
/// resolution is deterministic and always the same four steps:
///
/// 1. **Compute the desired end state** — `MonitoringPlan`, a pure function of
///    the schedule. Nothing about the current registration influences it.
/// 2. **Ask the system what it is actually running.** `DeviceActivityCenter`'s
///    `activities` is the truth; HopPotty's memory of what it registered is not,
///    because an app update, a crash mid-registration, or a previous build's
///    naming scheme can all leave the two disagreeing.
/// 3. **Stop every HopPotty activity that is not in the plan** — by name, one at
///    a time. This is what makes an orphan impossible: a name from a previous
///    build carries the `hoppotty.` prefix, is not in the plan, and is therefore
///    stopped. The backstop is exempt, because its lifetime belongs to a pause
///    rather than to a schedule.
/// 4. **Start every activity in the plan.** Apple: "Monitoring a second activity
///    with the same name as a previous activity overwrites the schedule for the
///    first one" — so re-registering an unchanged name is the documented update
///    path, not a duplicate.
///
/// Stop-then-start rather than start-then-stop, because the failure between the
/// two steps should leave a family with *no* monitoring rather than with two
/// contradictory schedules. No monitoring is visible in the parent UI and
/// recoverable with one tap; a double schedule interrupts a child twice and looks
/// like a broken product.
///
/// **`stopMonitoring()` with no arguments is never called anywhere in HopPotty.**
/// It stops everything the app has registered, including activities that a future
/// feature may own. Every call site passes explicit names.
@MainActor
@Observable
public final class ActivityMonitoringService: ActivityMonitoringProviding {

    public private(set) var lastRegistration: Date?
    public private(set) var lastPlan: MonitoringPlan?
    public private(set) var lastFailure: ScreenTimeFailure?

    private let center: DeviceActivityCenter
    private let appGroup: AppGroupStore

    public init(center: DeviceActivityCenter = DeviceActivityCenter(), appGroup: AppGroupStore = .shared) {
        self.center = center
        self.appGroup = appGroup
    }

    public var monitoredActivityNames: [String] {
        center.activities.map(\.rawValue)
    }

    private var hopPottyActivityNames: [String] {
        monitoredActivityNames.filter(ScreenTimeIdentifiers.isHopPottyActivity)
    }

    // MARK: - Registration

    @discardableResult
    public func register(_ plan: MonitoringPlan) -> Result<MonitoringRegistration, ScreenTimeFailure> {
        let now = Date()
        let desired = plan.activityNames

        // Step 3. Everything of ours that the plan does not want, except the
        // backstop, whose lifetime is a pause rather than a schedule.
        let stale = hopPottyActivityNames.filter {
            $0 != ScreenTimeIdentifiers.backstopActivityName && !desired.contains($0)
        }
        stop(names: stale)

        // Step 4.
        var registered: [String] = []
        for activity in plan.activities {
            switch start(activity) {
            case .success:
                registered.append(activity.name)
            case .failure(let failure):
                // Partial success is not left standing. A schedule that fires at
                // 09:00 and 10:00 but not at 11:00 is worse than one that does
                // not fire at all, because a caregiver cannot tell the difference
                // between it and a working one until the day is half over.
                stop(names: registered)
                lastFailure = failure
                lastPlan = nil
                return .failure(failure)
            }
        }

        lastPlan = plan
        lastRegistration = registered.isEmpty ? nil : now
        lastFailure = nil
        return .success(
            MonitoringRegistration(
                registeredAt: now,
                activityNames: registered,
                stoppedNames: stale,
                notes: plan.notes
            )
        )
    }

    @discardableResult
    public func registerBackstop(for record: SharedPauseRecord) -> Result<Void, ScreenTimeFailure> {
        // Registered under a fixed name, so a second pause overwrites the first
        // one's backstop rather than accumulating. Two pauses cannot overlap —
        // the state machine forbids it — so overwriting is always correct here.
        switch start(MonitoringPlan.backstop(for: record)) {
        case .success:
            return .success(())
        case .failure(let failure):
            // A missing backstop does not stop the pause: paths (A), (D) and (E)
            // in `Docs/ScreenTimeArchitecture.md` §9 are all still live, and the
            // app's own timer ends it while HopPotty is in the foreground. It is
            // recorded so the Lab shows a pause running without its safety net,
            // which is exactly the condition worth noticing on a test device.
            lastFailure = failure
            appGroup.appendReport(
                ExtensionReport(
                    source: .app,
                    kind: .failure,
                    at: Date(),
                    sessionID: record.sessionID,
                    activityRole: .backstop,
                    failureCode: failure.rawValue
                )
            )
            return .failure(failure)
        }
    }

    public func cancelBackstop() {
        stop(names: [ScreenTimeIdentifiers.backstopActivityName])
    }

    public func cancelAllMonitoring() {
        stop(names: hopPottyActivityNames)
        lastPlan = nil
        lastRegistration = nil
    }

    @discardableResult
    public func removeOrphanedMonitoring() -> [String] {
        let known = (lastPlan?.activityNames ?? []).union([ScreenTimeIdentifiers.backstopActivityName])
        let orphans = hopPottyActivityNames.filter { !known.contains($0) }
        guard !orphans.isEmpty else { return [] }
        stop(names: orphans)
        return orphans
    }

    /// Best-effort teardown for the emergency path.
    ///
    /// Static, and takes no instance, because `restoreScreenAccess()` must work
    /// even if the monitoring service failed to initialise or was never created —
    /// the emergency exit cannot depend on the health of the object graph.
    public static func cancelEverythingBestEffort() {
        let center = DeviceActivityCenter()
        let ours = center.activities.filter { ScreenTimeIdentifiers.isHopPottyActivity($0.rawValue) }
        guard !ours.isEmpty else { return }
        center.stopMonitoring(ours)
    }

    // MARK: - Primitives

    private func stop(names: [String]) {
        guard !names.isEmpty else { return }
        center.stopMonitoring(names.map { DeviceActivityName(hopPotty: $0) })
    }

    private func start(_ activity: MonitoringPlan.Activity) -> Result<Void, ScreenTimeFailure> {
        let schedule = DeviceActivitySchedule(
            intervalStart: activity.intervalStart,
            intervalEnd: activity.intervalEnd,
            repeats: activity.repeats,
            warningTime: activity.warningTime
        )

        let events = Dictionary(
            uniqueKeysWithValues: activity.events.map { event in
                (
                    DeviceActivityEvent.Name(hopPotty: event.name),
                    // Threshold is accumulated *foreground usage*, not wall clock.
                    // `applications`/`categories`/`webDomains` are left unset, which
                    // Apple documents as "the event includes all applications,
                    // categories, and web domains" — deliberately: HopPotty measures
                    // how long the child has been on the device, not how long they
                    // have been in the specific apps a caregiver chose to pause.
                    // Those are different products, and the second one would let a
                    // child avoid every pause by switching to an unselected app.
                    //
                    // UNVERIFIED — confirm on device: that an event with no
                    // applications, categories or web domains does accumulate
                    // across all apps as documented, and that its threshold
                    // resolution is fine enough for a 10-minute interval. Apple
                    // documents no minimum threshold.
                    DeviceActivityEvent(threshold: DateComponents(minute: event.thresholdMinutes))
                )
            }
        )

        do {
            try center.startMonitoring(
                DeviceActivityName(hopPotty: activity.name),
                during: schedule,
                events: events
            )
            return .success(())
        } catch {
            return .failure(Self.map(error))
        }
    }

    /// `DeviceActivityCenter.MonitoringError` → a caregiver-actionable failure.
    ///
    /// UNVERIFIED — confirm on device: the exact case spellings. They come from
    /// Apple's documentation (`Docs/ScreenTimeArchitecture.md` §4) rather than a
    /// compiled SDK. The `default` branch maps anything unexpected to
    /// `.monitoringRegistrationFailed`, so a wrong guess here degrades to a vaguer
    /// caregiver message and never to a wrong behaviour.
    static func map(_ error: Error) -> ScreenTimeFailure {
        guard let monitoringError = error as? DeviceActivityCenter.MonitoringError else {
            return .monitoringRegistrationFailed
        }
        switch monitoringError {
        case .unauthorized: return .authorizationRevoked
        case .excessiveActivities: return .monitoringLimitReached
        case .intervalTooShort, .intervalTooLong, .invalidDateComponents: return .scheduleInvalid
        default: return .monitoringRegistrationFailed
        }
    }
}
