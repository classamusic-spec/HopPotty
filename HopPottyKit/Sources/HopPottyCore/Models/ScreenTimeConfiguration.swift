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

/// HopPotty's view of Family Controls authorization, kept free of the framework
/// so Core stays buildable off Apple platforms and testable without entitlements.
///
/// This is deliberately **not** a one-to-one mirror of
/// `FamilyControls.AuthorizationStatus`, which has only `.notDetermined`,
/// `.denied`, `.approved` and (iOS 26.4+) `.approvedWithDataAccess`. The extra
/// case here is derived by the app layer from a thrown `FamilyControlsError`,
/// because the caregiver-facing distinction we need — "you declined" versus
/// "this device cannot do this at all" — does not exist in the status enum.
public enum ScreenTimeAuthorizationStatus: String, Codable, CaseIterable, Sendable {
    case notDetermined
    case denied
    case approved
    /// Screen Time cannot be used on this device: a management profile, a
    /// parental-controls restriction, or a device already managed as a child
    /// device. Derived from `FamilyControlsError.restricted`, never from
    /// `AuthorizationStatus`.
    case restricted

    public var canShield: Bool { self == .approved }

    /// Whether asking again could plausibly change the answer. A restricted
    /// device will never approve, so the UI must not offer a retry that cannot work.
    public var isRetryable: Bool { self == .notDetermined || self == .denied }
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
    /// Another parental-controls app already holds Family Controls authorization
    /// on this device. In practice the most likely real-world failure, and one
    /// the caregiver can only resolve outside HopPotty.
    case authorizationConflict
    /// The signed-in Apple Account cannot use Family Controls — for example an
    /// adult account where a child account is required, or no account at all.
    case invalidAccountType
    /// Authorization needs the network and it was unavailable.
    case networkError
    /// The device cannot present the authentication Family Controls requires.
    case authenticationMethodUnavailable
    /// Monitoring could not be registered because the device is already at
    /// Apple's cap on concurrently monitored activities.
    case monitoringLimitReached
    case unknown

    /// Whether HopPotty can retry on its own, or needs the caregiver to change
    /// something first.
    public var isSelfRecoverable: Bool {
        switch self {
        case .monitoringRegistrationFailed, .shieldApplyFailed, .shieldClearFailed,
             .networkError, .unknown:
            true
        case .authorizationRevoked, .noSelection, .scheduleInvalid, .extensionUnavailable,
             .authorizationConflict, .invalidAccountType, .authenticationMethodUnavailable,
             .monitoringLimitReached:
            false
        }
    }

    /// Whether the caregiver must leave HopPotty to fix this — Settings, a
    /// different Apple Account, or removing another parental-controls app.
    public var requiresActionOutsideApp: Bool {
        switch self {
        case .authorizationRevoked, .authorizationConflict, .invalidAccountType,
             .authenticationMethodUnavailable:
            true
        default:
            false
        }
    }
}
