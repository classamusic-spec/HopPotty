import Foundation
import HopPottyCore

/// Everything the app layer may ask of `DeviceActivity`.
///
/// Registration is the operation in this feature with the worst failure mode
/// after the shield itself: an orphaned activity keeps calling an extension
/// forever, and a failed re-registration leaves a family with a Potty Pause that
/// silently never fires. So the surface is small, the semantics are stated, and
/// every method says what it guarantees when it fails.
@MainActor
public protocol ActivityMonitoringProviding: AnyObject {

    /// Activity names the system currently reports as monitored — HopPotty's and
    /// anyone else's. The Lab shows this verbatim.
    var monitoredActivityNames: [String] { get }

    /// When registration last succeeded, for `ScreenTimeConfiguration`.
    var lastRegistration: Date? { get }

    /// The plan behind the current registration.
    var lastPlan: MonitoringPlan? { get }

    var lastFailure: ScreenTimeFailure? { get }

    /// Make the system's monitoring match this plan exactly.
    ///
    /// Deterministic and idempotent: registering the same plan twice leaves the
    /// same activities running. Guarantees that no HopPotty activity outside the
    /// plan survives the call, *except* the backstop, which has its own lifetime
    /// and is never touched here.
    @discardableResult
    func register(_ plan: MonitoringPlan) -> Result<MonitoringRegistration, ScreenTimeFailure>

    /// Arm the 15-minute safety net for a pause that has just started.
    ///
    /// Separate from `register` on purpose. The backstop's job is to end a pause
    /// when everything else has failed, so it must not be a casualty of a
    /// caregiver editing the schedule while a pause is running.
    @discardableResult
    func registerBackstop(for record: SharedPauseRecord) -> Result<Void, ScreenTimeFailure>

    /// Stand the safety net down. Called when a pause ends by any other path.
    func cancelBackstop()

    /// Stop every HopPotty activity, including the backstop, and leave anything
    /// registered by other code alone.
    func cancelAllMonitoring()

    /// Stop any HopPotty activity the system reports that the last plan does not
    /// account for. Called on every foreground.
    @discardableResult
    func removeOrphanedMonitoring() -> [String]
}

/// What a registration actually achieved.
///
/// Returned rather than discarded because "we registered your schedule" and "we
/// registered six of the nine slots your schedule implies" are different
/// sentences, and a caregiver is entitled to the second one when it is true.
public struct MonitoringRegistration: Equatable, Sendable {
    public let registeredAt: Date
    public let activityNames: [String]
    public let stoppedNames: [String]
    public let notes: [MonitoringPlan.Note]

    public init(
        registeredAt: Date,
        activityNames: [String],
        stoppedNames: [String],
        notes: [MonitoringPlan.Note]
    ) {
        self.registeredAt = registeredAt
        self.activityNames = activityNames
        self.stoppedNames = stoppedNames
        self.notes = notes
    }

    public var isEmpty: Bool { activityNames.isEmpty }
}
