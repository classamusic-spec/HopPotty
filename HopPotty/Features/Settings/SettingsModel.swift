import Foundation
import Observation
import HopPottyCore

/// Settings' own state: the receipts for destructive actions, and the results
/// of the two actions that touch the filesystem.
///
/// Every destructive path here follows the same three steps, in this order:
/// count what will go, state it in a sentence with those counts, and only then
/// accept a gated confirmation. The counts come from the repositories rather
/// than from anything remembered, because the sentence a caregiver reads has to
/// be true at the moment they read it.
@MainActor
@Observable
final class SettingsModel {

    enum DestructiveAction: Equatable, Identifiable {
        case deleteChild(UUID)
        case deleteEverything

        var id: String {
            switch self {
            case .deleteChild(let id): "child-\(id.uuidString)"
            case .deleteEverything: "everything"
            }
        }

        var reason: ParentAuthorization.Reason { .deleteData }
    }

    private(set) var receipt: DeletionReceipt?
    private(set) var pendingAction: DestructiveAction?
    private(set) var exportURL: URL?
    private(set) var isWorking = false
    private(set) var failure: ParentFailure?
    private(set) var didRestoreAccess = false

    private let environment: ParentEnvironment

    init(environment: ParentEnvironment) {
        self.environment = environment
    }

    var settings: AppSettings { environment.settings }
    var children: [ChildProfile] { environment.children }
    var entitlement: ParentEntitlement { environment.purchases.entitlement }
    var isStoreAvailable: Bool { environment.isStoreAvailable }

    var appVersion: String {
        let bundle = Bundle.main
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return HopCopy.settings.aboutVersion.localized(.text("\(version) (\(build))"))
    }

    // MARK: Destructive actions

    /// Loads the counts *before* the confirmation is shown, so the sheet can
    /// name them. A confirmation that says "this cannot be undone" without
    /// saying what "this" is, is the manipulative kind this product bars.
    func prepare(_ action: DestructiveAction) async {
        isWorking = true
        defer { isWorking = false }
        do {
            switch action {
            case .deleteChild(let childID):
                // The nickname is not patched in here. `DeletionReceipt.childName`
                // is a read accessor over a `let` -- the receipt is immutable on
                // purpose, because a receipt that can be edited after the fact is
                // not a receipt. The line that used to be here assigned to it:
                //
                //     error: cannot assign to property: 'childName' is a get-only
                //            property
                //
                // and it was redundant besides. `DataDeletionService` already
                // resolves the nickname from `repositories.profiles` while it
                // counts, which is the same fact from a more authoritative place
                // at a better moment -- read from the store as the numbers are
                // taken, rather than from this screen's in-memory copy afterwards.
                receipt = try await environment.deletion.receipt(forChild: childID)
            case .deleteEverything:
                receipt = try await environment.deletion.receiptForEverything()
            }
            pendingAction = action
        } catch {
            failure = .readFailed
        }
    }

    func cancelPendingAction() {
        pendingAction = nil
        receipt = nil
    }

    func confirm(_ action: DestructiveAction, authorization: ParentAuthorization) async {
        guard authorization.isValid(at: environment.clock.now) else {
            failure = .saveFailed
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            switch action {
            case .deleteChild(let childID):
                receipt = try await environment.deletion.deleteChild(childID, authorization: authorization)
            case .deleteEverything:
                receipt = try await environment.deletion.deleteEverything(authorization: authorization)
            }
            pendingAction = nil
            await environment.reload()
        } catch {
            failure = .saveFailed
        }
    }

    // MARK: Export

    func export(childID: UUID?, authorization: ParentAuthorization) async {
        isWorking = true
        defer { isWorking = false }
        do {
            exportURL = try await environment.export.exportArchive(for: childID, authorization: authorization)
        } catch {
            failure = .exportFailed
        }
    }

    func clearExport() { exportURL = nil }

    // MARK: Screen access

    func restoreScreenAccess() async {
        isWorking = true
        defer { isWorking = false }
        if let screenTimeFailure = environment.screenTime.restoreScreenAccess() {
            failure = .screenTime(screenTimeFailure)
            didRestoreAccess = false
        } else {
            didRestoreAccess = true
        }
    }

    // MARK: Settings writes

    func update(_ mutate: @escaping (inout AppSettings) -> Void) {
        Task { await environment.updateSettings(mutate) }
    }

    func dismissFailure() { failure = nil }
}
