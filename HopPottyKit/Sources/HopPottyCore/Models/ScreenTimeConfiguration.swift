import Foundation

/// What HopPotty knows about a child's Screen Time setup.
///
/// The actual app and category selection is **not** here. Apple hands those to us
/// as opaque `ApplicationToken`/`ActivityCategoryToken` values that we are not
/// permitted to inspect, and they live in the `FamilyActivitySelection` the app
/// layer persists separately. This type carries only the counts and status the
/// parent UI needs to explain itself — which is all it is entitled to know.
public struct ScreenTimeConfiguration: Hashable, Codable, Sendable {
    public let childID: UUID
    /// Number of individual apps the caregiver picked. A count, never an identity.
    public var selectedApplicationCount: Int
    public var selectedCategoryCount: Int
    public var selectedWebDomainCount: Int
    public var authorizationStatus: ScreenTimeAuthorizationStatus
    /// When monitoring was last successfully registered with `DeviceActivityCenter`.
    public var lastMonitoringRegistration: Date?
    /// Set when registration failed, so the parent dashboard can explain the
    /// problem instead of silently doing nothing.
    public var lastRegistrationFailure: ScreenTimeFailure?

    public init(
        childID: UUID,
        selectedApplicationCount: Int = 0,
        selectedCategoryCount: Int = 0,
        selectedWebDomainCount: Int = 0,
        authorizationStatus: ScreenTimeAuthorizationStatus = .notDetermined,
        lastMonitoringRegistration: Date? = nil,
        lastRegistrationFailure: ScreenTimeFailure? = nil
    ) {
        self.childID = childID
        self.selectedApplicationCount = selectedApplicationCount
        self.selectedCategoryCount = selectedCategoryCount
        self.selectedWebDomainCount = selectedWebDomainCount
        self.authorizationStatus = authorizationStatus
        self.lastMonitoringRegistration = lastMonitoringRegistration
        self.lastRegistrationFailure = lastRegistrationFailure
    }

    /// Total things selected across all three kinds.
    public var totalSelectionCount: Int {
        selectedApplicationCount + selectedCategoryCount + selectedWebDomainCount
    }

    public var hasSelection: Bool { totalSelectionCount > 0 }
}

/// Mirrors `FamilyControls.AuthorizationStatus` without importing it, so Core
/// stays buildable off Apple platforms and testable without entitlements.
public enum ScreenTimeAuthorizationStatus: String, Codable, CaseIterable, Sendable {
    case notDetermined
    case denied
    case approved
    /// Screen Time is unavailable on this device — a management profile, a
    /// restriction, or a device that is already a managed child device.
    case restricted

    public var canShield: Bool { self == .approved }
}

/// A Screen Time failure, in terms a caregiver can act on.
///
/// Raw `NSError`s are logged for diagnostics but never surfaced; every case here
/// maps to a specific recovery sentence in the UI.
public enum ScreenTimeFailure: String, Codable, CaseIterable, Sendable {
    case authorizationRevoked
    case noSelection
    case monitoringRegistrationFailed
    case scheduleInvalid
    case shieldApplyFailed
    case shieldClearFailed
    case extensionUnavailable
    case unknown

    /// Whether HopPotty can retry on its own, or needs the caregiver to change
    /// something first.
    public var isSelfRecoverable: Bool {
        switch self {
        case .monitoringRegistrationFailed, .shieldApplyFailed, .shieldClearFailed, .unknown: true
        case .authorizationRevoked, .noSelection, .scheduleInvalid, .extensionUnavailable: false
        }
    }
}
