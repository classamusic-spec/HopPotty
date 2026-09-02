import Foundation
import Observation
import HopPottyCore

/// The dashboard's data.
///
/// Everything on the screen is derived from three reads — the child's schedule,
/// today's events, and the star ledger — plus the pure scheduling engine. There
/// is no sample data path and no "demo mode": a family with an empty log sees an
/// empty state that says so.
@MainActor
@Observable
final class ParentHomeModel {

    struct Snapshot: Equatable {
        var child: ChildProfile
        var schedule: PottySchedule
        var todayEvents: [PottyEvent]
        var starsToday: Int
        var projection: PauseProjection?
        var blockReason: PauseBlockReason?
        var screenTime: ScreenTimeConfiguration
        var pauseState: PottyPauseState
        var insight: Insight?

        var participationToday: Int {
            todayEvents.filter { $0.kind.countsAsParticipation }.count
        }
        /// A count, never a rate. See `DayTotal` — the moment an accident count
        /// gets a denominator it becomes a score.
        var accidentsToday: Int {
            todayEvents.filter { $0.kind == .accident }.count
        }
    }

    private(set) var state: ParentLoadState<Snapshot> = .firstLoad
    private(set) var actionFailure: ParentFailure?

    private let environment: ParentEnvironment

    init(environment: ParentEnvironment) {
        self.environment = environment
    }

    var calendar: Calendar { environment.clock.calendar }
    var now: Date { environment.clock.now }

    // MARK: Loading

    func load(childID: UUID?) async {
        guard let child = environment.resolvedChild(childID) else {
            state = .empty
            return
        }
        state = .loading(previous: state.value)

        do {
            let today = InsightWindow.day.interval(containing: now, calendar: calendar)
            let schedule = await environment.schedule(for: child.id)
            let events = try await environment.repositories.events.events(
                matching: PottyEventQuery(childID: child.id, window: today)
            )
            let ledger = try await environment.repositories.rewards.ledger(for: child.id)
            let snapshotScreenTime = environment.screenTime.snapshot(for: child.id)

            let scheduleState = ScheduleState(schedule: schedule, now: now)
            let decision = environment.scheduleService.canStartPause(at: scheduleState)
            let projection = environment.scheduleService.nextPause(after: scheduleState)

            // The report is computed over a trailing window rather than today
            // alone: every threshold in `InsightThresholds` counts days, and one
            // day can never clear them.
            let report = InsightsEngine.report(
                events: try await environment.repositories.events.events(
                    matching: PottyEventQuery(childID: child.id)
                ),
                childID: child.id,
                window: .week,
                currentInterval: schedule.interval,
                calendar: calendar,
                now: now
            )

            state = .loaded(
                Snapshot(
                    child: child,
                    schedule: schedule,
                    todayEvents: events,
                    starsToday: starsToday(in: ledger, childID: child.id),
                    projection: projection,
                    blockReason: decision.reason,
                    screenTime: snapshotScreenTime.configuration,
                    pauseState: derivedPauseState(
                        schedule: schedule,
                        configuration: snapshotScreenTime.configuration,
                        mayHaveShieldUp: snapshotScreenTime.mayHaveShieldUp,
                        decision: decision
                    ),
                    insight: InsightPresentation.headline(from: report)
                )
            )
        } catch {
            state = .failed(environment.isStoreAvailable ? .readFailed : .storageUnavailable)
        }
    }

    private func starsToday(in ledger: RewardLedger, childID: UUID) -> Int {
        let start = calendar.startOfDay(for: now)
        return ledger.transactions(for: childID)
            .filter { $0.timestamp >= start }
            .reduce(0) { $0 + $1.quantity }
    }

    /// What the hero card is showing, derived rather than stored.
    ///
    /// The dashboard is not the state machine — the machine lives in the pause
    /// runtime and the extensions. This derives the *display* state from facts
    /// the app can see, and it is deliberately conservative about only one
    /// thing: a registration failure that is still unresolved reports
    /// `errorAccessRestored`, which says "Potty Pause is not running" without
    /// claiming a shield is standing.
    private func derivedPauseState(
        schedule: PottySchedule,
        configuration: ScreenTimeConfiguration,
        mayHaveShieldUp: Bool,
        decision: PauseStartDecision
    ) -> PottyPauseState {
        if let failure = configuration.lastRegistrationFailure {
            return mayHaveShieldUp ? .errorRequiresParent(failure) : .errorAccessRestored(failure)
        }
        if mayHaveShieldUp { return .shieldActive }
        guard schedule.isEnabled else { return .disabled }
        if schedule.mode.requiresScreenTimeAuthorization,
           !configuration.authorizationStatus.canShield {
            return .authorizationRequired
        }
        if let reason = decision.reason {
            switch reason {
            case .scheduleDisabled, .suspendedIndefinitely: return .disabled
            case .cooldown: return .cooldown
            default: return .ready
            }
        }
        return .monitoring
    }

    // MARK: Actions

    func skipNextPause() async {
        await mutateSchedule { $0.suspension = .skipNext }
    }

    func pauseUntilTomorrow() async {
        let from = now
        await mutateSchedule { $0.suspension = .untilTomorrow(from: from) }
    }

    func resume() async {
        await mutateSchedule { $0.suspension = .none }
    }

    func startPauseNow() async {
        guard let snapshot = state.value else { return }
        if let failure = environment.screenTime.startPauseNow(for: snapshot.schedule) {
            actionFailure = .screenTime(failure)
        }
        await load(childID: snapshot.child.id)
    }

    func restoreScreenAccess() async {
        if let failure = environment.screenTime.restoreScreenAccess() {
            actionFailure = .screenTime(failure)
        }
        await load(childID: state.value?.child.id)
    }

    func logEvent(kind: PottyEventKind, at timestamp: Date, note: String?) async {
        guard let snapshot = state.value else { return }
        let event = PottyEvent(
            childID: snapshot.child.id,
            timestamp: timestamp,
            kind: kind,
            source: .parentManual,
            note: note
        )
        do {
            try await environment.repositories.events.save(event)
            await load(childID: snapshot.child.id)
        } catch {
            actionFailure = .saveFailed
        }
    }

    func dismissActionFailure() { actionFailure = nil }

    private func mutateSchedule(_ mutate: (inout PottySchedule) -> Void) async {
        guard let snapshot = state.value else { return }
        var schedule = snapshot.schedule
        mutate(&schedule)
        actionFailure = await environment.saveSchedule(schedule)
        await load(childID: snapshot.child.id)
    }
}
