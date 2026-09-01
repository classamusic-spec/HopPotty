import Foundation
import HopPottyCore

// The ports the parent-facing features talk to.
//
// INTEGRATION NOTE. `Services/ScreenTime/`, `Services/Purchases/` and
// `Services/Notifications/` are being written in parallel. These protocols are
// the *feature* side of that boundary: they describe only what the parent
// screens need, in Core types plus opaque `Data`, and deliberately mention no
// Apple framework. When the concrete services land they should adopt these
// protocols; if the services layer declares protocols of its own with the same
// names, delete this file and keep theirs — no view here reads anything but the
// members below.

// MARK: - Screen Time

/// What a caregiver's Screen Time setup looks like to the parent UI.
///
/// The app selection travels as `Data` — a `Codable` `FamilyActivitySelection`
/// blob — because the feature layer is not entitled to know what is in it, and
/// because `Docs/ScreenTimeArchitecture.md` §3 records that the whole selection
/// round-trips, `includeEntireCategory` and all, while loose token sets do not.
struct ScreenTimeSnapshot: Equatable, Sendable {
    var configuration: ScreenTimeConfiguration
    /// Encoded `FamilyActivitySelection`, or `nil` when nothing is picked.
    var selectionData: Data?
    /// Whether a shield is standing right now, as far as the app can tell.
    var mayHaveShieldUp: Bool

    init(configuration: ScreenTimeConfiguration, selectionData: Data? = nil, mayHaveShieldUp: Bool = false) {
        self.configuration = configuration
        self.selectionData = selectionData
        self.mayHaveShieldUp = mayHaveShieldUp
    }
}

/// The result of asking iOS for Family Controls authorization.
///
/// Modelled as an outcome rather than a thrown error because "the caregiver
/// cancelled" is not a failure and must not be presented as one — see
/// `Docs/ScreenTimeArchitecture.md` §3, `FamilyControlsError.authorizationCanceled`.
enum ScreenTimeAuthorizationOutcome: Equatable, Sendable {
    case approved
    /// The caregiver declined at the system prompt.
    case denied
    /// The caregiver dismissed the prompt without answering.
    case cancelled
    /// The device cannot use Family Controls at all.
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

@MainActor
protocol ScreenTimeProviding: AnyObject {
    /// Current authorization, read on the main queue as Apple requires.
    var authorizationStatus: ScreenTimeAuthorizationStatus { get }

    /// Presents the system prompt. Safe to call when already approved: an
    /// authorized app gets no UI, which is why the app asks before deciding
    /// anything from `.notDetermined`.
    func requestAuthorization() async -> ScreenTimeAuthorizationOutcome

    func snapshot(for childID: UUID) async -> ScreenTimeSnapshot

    /// Persists an encoded `FamilyActivitySelection` and returns the counts the
    /// parent UI is allowed to show.
    @discardableResult
    func saveSelection(_ data: Data?, for childID: UUID) async throws -> ScreenTimeConfiguration

    /// (Re-)registers `DeviceActivity` monitoring for a schedule.
    func applySchedule(_ schedule: PottySchedule) async -> ScreenTimeFailure?

    /// Runs one pause immediately, for "Test Potty Pause" and "Start now".
    func startPauseNow(for schedule: PottySchedule) async -> ScreenTimeFailure?

    /// The emergency exit. Clears every store HopPotty owns and reports whether
    /// the clear was confirmed. Never gated on anything the child did.
    func restoreScreenAccess() async -> ScreenTimeFailure?
}

// MARK: - Notifications

enum NotificationPermission: Equatable, Sendable {
    case notDetermined, authorized, denied, provisional
}

@MainActor
protocol NotificationProviding: AnyObject {
    var permission: NotificationPermission { get }
    func requestPermission() async -> NotificationPermission
    /// Re-reads the system state, which can change while the app is backgrounded.
    func refreshPermission() async
}

// MARK: - Purchases

/// One purchasable thing, priced by StoreKit.
///
/// `displayPrice` is whatever `Product.displayPrice` returned. It is never
/// composed in HopPotty: a hard-coded price is wrong in every storefront but
/// one, and wrong in all of them the day a price changes.
struct HopProduct: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let displayPrice: String
    let description: String
}

enum PurchaseOutcome: Equatable, Sendable {
    case purchased
    case cancelled
    /// Ask to Buy: the family organiser has to approve.
    case pending
    case failed
}

/// What the family has unlocked. One non-consumable, no tiers, no expiry.
enum ParentEntitlement: Equatable, Sendable {
    case free
    case family

    var isUnlocked: Bool { self == .family }

    /// Children a free family can keep. The second child is the paid feature;
    /// the first child's whole experience is not.
    static let freeChildLimit = 1
}

@MainActor
protocol PurchaseProviding: AnyObject {
    var entitlement: ParentEntitlement { get }
    /// `nil` until StoreKit answers, which is also the "offline" state: the
    /// paywall shows its features and hides its price rather than inventing one.
    var product: HopProduct? { get }
    func loadProduct() async
    func purchase() async -> PurchaseOutcome
    func restore() async -> PurchaseOutcome
}

// MARK: - Data export and deletion

/// Exactly what a destructive action will remove, counted before it runs.
///
/// `Docs/CONTRACTS.md` §4.6: every destructive action states what it removes,
/// with counts. This value is what the confirmation sheet quotes; it is
/// gathered by counting rows, never estimated.
struct DeletionReceipt: Equatable, Sendable {
    var childName: String?
    var events: Int
    var stars: Int
    var decorations: Int
    var children: Int

    init(childName: String? = nil, events: Int = 0, stars: Int = 0, decorations: Int = 0, children: Int = 0) {
        self.childName = childName
        self.events = events
        self.stars = stars
        self.decorations = decorations
        self.children = children
    }

    var isEmpty: Bool { events == 0 && stars == 0 && decorations == 0 && children == 0 }
}

@MainActor
protocol DataExportProviding: AnyObject {
    /// Writes a file into the app's own container and returns its URL, for the
    /// caregiver to move wherever they like. Nothing leaves the device.
    func exportArchive(for childID: UUID?, authorization: ParentAuthorization) async throws -> URL
}

@MainActor
protocol DataDeletionProviding: AnyObject {
    func receipt(forChild childID: UUID) async throws -> DeletionReceipt
    func receiptForEverything() async throws -> DeletionReceipt
    func deleteChild(_ childID: UUID, authorization: ParentAuthorization) async throws -> DeletionReceipt
    func deleteEverything(authorization: ParentAuthorization) async throws -> DeletionReceipt
}
