import Foundation
import HopPottyCore

// The feature layer's view of Screen Time.
//
// INTEGRATION NOTE. This file used to declare placeholder protocols for Screen
// Time, notifications, purchases, export and deletion while the two layers were
// built in parallel. `Services/` now owns all of those, and they win: the
// declarations here are deleted and the parent screens call the service
// protocols directly.
//
// What remains is the one thing the services layer deliberately does *not*
// provide — a per-child, task-shaped facade over `ScreenTimeProviding`. The
// service is correctly device-shaped (one selection, one shield, one
// authorization, because the device has one of each). The parent screens are
// child-shaped: "what is set up for Maya", "run a pause for this schedule".
// `ParentScreenTimeAdapter` is where those two shapes meet, and it is the only
// place in `Features/` that knows the difference.

/// What a caregiver's Screen Time setup looks like to the parent UI.
///
/// Counts, a status, and whether a shield may be standing. Never an identity:
/// `SelectionSummary` is three integers because Apple hands out opaque tokens
/// precisely so an app cannot learn what a family uses.
struct ScreenTimeSnapshot: Equatable, Sendable {
    var configuration: ScreenTimeConfiguration
    /// Whether HopPotty *believes* a shield is up. The word is load-bearing:
    /// this is a record of what was asked for, not an observation of the device
    /// (`Docs/ScreenTimeArchitecture.md` §11 item 12).
    var mayHaveShieldUp: Bool

    init(configuration: ScreenTimeConfiguration, mayHaveShieldUp: Bool = false) {
        self.configuration = configuration
        self.mayHaveShieldUp = mayHaveShieldUp
    }
}

/// The result of asking iOS for Family Controls authorization.
///
/// Cancelling is not denial and must never be presented as one — Apple's
/// `FamilyControlsError.authorizationCanceled` means the caregiver dismissed the
/// sheet, and the correct response is to leave them on the explainer screen.
enum ScreenTimeAuthorizationOutcome: Equatable, Sendable {
    case approved
    case denied
    case cancelled
    case restricted
    case failed(ScreenTimeFailure)

    var status: ScreenTimeAuthorizationStatus {
        switch self {
        case .approved: .approved
        case .denied: .denied
        case .cancelled: .notDetermined
        case .restricted: .restricted
        case .failed(let failure): failure == .authorizationRevoked ? .denied : .notDetermined
        }
    }
}

/// The parent screens' entry point to Screen Time.
///
/// A concrete class rather than a protocol: there is nothing to swap here. The
/// seam that makes previews and tests possible is `any ScreenTimeProviding`
/// underneath, which the services layer already provides in real and mock forms.
/// Adding a second protocol on top would be a seam with nothing on the other
/// side of it.
@MainActor
final class ParentScreenTimeAdapter {

    private let service: any ScreenTimeProviding
    private let monitoring: (any ActivityMonitoringProviding)?
    private let clock: any HopClock

    init(
        service: any ScreenTimeProviding,
        monitoring: (any ActivityMonitoringProviding)? = nil,
        clock: any HopClock = SystemClock()
    ) {
        self.service = service
        self.monitoring = monitoring
        self.clock = clock
    }

    /// The underlying service, for the one view that genuinely needs it: the app
    /// picker, which must bind to `selection` because `FamilyActivityPicker`
    /// takes a binding.
    var underlying: any ScreenTimeProviding { service }

    var authorizationStatus: ScreenTimeAuthorizationStatus { service.authorizationStatus }

    /// Presents the system prompt and reduces the answer to something the UI can
    /// branch on. A `.restricted` device is separated out here because asking
    /// again can never change it, and the screen must not offer a retry.
    func requestAuthorization() async -> ScreenTimeAuthorizationOutcome {
        let before = service.authorizationStatus
        switch await service.requestAuthorization() {
        case .success(let status):
            switch status {
            case .approved: return .approved
            case .denied: return .denied
            case .restricted: return .restricted
            case .notDetermined:
                // Unchanged and no error: the caregiver dismissed the sheet.
                return before == .notDetermined ? .cancelled : .denied
            }
        case .failure(let failure):
            return failure == .restricted ? .restricted : .failed(failure)
        }
    }

    /// Counts and status for one child.
    ///
    /// The device holds one selection, so every child on this device shares it
    /// until per-child selections exist. Folding it into a per-child
    /// `ScreenTimeConfiguration` here keeps that fact in one file rather than in
    /// every screen.
    func snapshot(for childID: UUID) -> ScreenTimeSnapshot {
        ScreenTimeSnapshot(
            configuration: service.selectionSummary.configuration(
                childID: childID,
                authorizationStatus: service.authorizationStatus,
                lastMonitoringRegistration: monitoring?.lastRegistration,
                lastRegistrationFailure: monitoring?.lastFailure
            ),
            mayHaveShieldUp: service.believesShieldIsUp
        )
    }

    /// Persists whatever the picker left in `selection`.
    @discardableResult
    func commitSelection(for childID: UUID) -> Result<ScreenTimeConfiguration, ScreenTimeFailure> {
        service.commitSelection().map { summary in
            summary.configuration(
                childID: childID,
                authorizationStatus: service.authorizationStatus
            )
        }
    }

    /// Registers monitoring for a schedule.
    ///
    /// Returns the failure rather than throwing, because every caller's response
    /// is the same: show the caregiver a sentence and leave the settings saved.
    func applySchedule(_ schedule: PottySchedule) -> ScreenTimeFailure? {
        guard let monitoring else { return nil }
        guard schedule.mode.shieldsApps else {
            // Gentle mode shields nothing, so there is nothing to register — and
            // leaving a stale registration running would interrupt a family who
            // just asked it not to.
            monitoring.cancelAllMonitoring()
            return nil
        }
        switch monitoring.register(MonitoringPlan(schedule: schedule, now: clock.now)) {
        case .success: return nil
        case .failure(let failure): return failure
        }
    }

    /// Runs one pause now — "Test Potty Pause", and "Start a pause now".
    func startPauseNow(for schedule: PottySchedule) -> ScreenTimeFailure? {
        switch service.applyShield(plannedDuration: schedule.pauseDuration, now: clock.now) {
        case .success(let record):
            // The 15-minute backstop is what guarantees the pause ends even if
            // every other path fails. A manually started pause needs it exactly
            // as much as a scheduled one.
            _ = monitoring?.registerBackstop(for: record)
            return nil
        case .failure(let failure):
            return failure
        }
    }

    /// The emergency exit. Unconditional, idempotent, and never gated on
    /// anything the child did.
    func restoreScreenAccess() {
        service.restoreScreenAccess()
        monitoring?.cancelBackstop()
    }
}
