import Foundation
import HopPottyCore

// The states every parent screen has to design for, as one type each, so a
// screen cannot accidentally ship with only "populated" drawn.

/// What a screen is showing.
///
/// `empty` is separate from `loaded` with no rows on purpose: "nothing has
/// happened yet" and "nothing matches this filter" read differently to a
/// caregiver, and only one of them deserves an invitation to log something.
enum ParentLoadState<Value: Equatable>: Equatable {
    /// Before the first read finishes. Distinct from `loading` so a screen can
    /// draw a skeleton the first time and keep its content on a refresh.
    case firstLoad
    case loading(previous: Value?)
    case loaded(Value)
    /// Loaded, and there is genuinely nothing yet.
    case empty
    case failed(ParentFailure)

    var value: Value? {
        switch self {
        case .loaded(let value): value
        case .loading(let previous): previous
        case .firstLoad, .empty, .failed: nil
        }
    }

    var isBusy: Bool {
        switch self {
        case .firstLoad, .loading: true
        case .loaded, .empty, .failed: false
        }
    }
}

/// Everything the parent surfaces can fail at, in terms an adult can act on.
///
/// A raw `NSError` never reaches a caregiver (`Docs/CONTRACTS.md` §8). Each case
/// maps to a title, a sentence about what happened, and at most two buttons.
enum ParentFailure: Equatable, Sendable {
    case screenTime(ScreenTimeFailure)
    case storageUnavailable
    case saveFailed
    case readFailed
    case notificationsDenied
    case purchaseFailed
    case purchasePending
    case exportFailed
    case offline
}

/// A failure rendered for a person: what happened, and what they can do.
struct ParentErrorPresentation: Equatable {
    enum Recovery: Equatable {
        /// HopPotty can try again by itself.
        case retry
        /// The fix is in HopPotty's own settings.
        case reviewSettings
        /// The fix is in the iOS Settings app.
        case openSystemSettings
        /// Nothing to do but acknowledge it.
        case dismissOnly
    }

    var title: String
    var message: String
    var recovery: Recovery
    /// Whether the situation still lets HopPotty do something useful — gentle
    /// reminders keep working without Screen Time, and the screen says so
    /// rather than implying the app is dead.
    var isDegradedNotBroken: Bool

    init(title: String, message: String, recovery: Recovery, isDegradedNotBroken: Bool = false) {
        self.title = title
        self.message = message
        self.recovery = recovery
        self.isDegradedNotBroken = isDegradedNotBroken
    }
}

extension ParentFailure {
    /// The one mapping from a failure to what a caregiver reads.
    ///
    /// It lives here rather than in each screen so the same problem never gets
    /// two different explanations in two places.
    var presentation: ParentErrorPresentation {
        switch self {
        case .screenTime(let failure):
            return failure.parentPresentation
        case .storageUnavailable:
            return ParentErrorPresentation(
                title: HopCopy.errors.storageTitle.localized,
                message: HopCopy.errors.storageBody.localized,
                recovery: .retry
            )
        case .saveFailed:
            return ParentErrorPresentation(
                title: HopCopy.errors.storageTitle.localized,
                message: HopCopy.errors.storageBody.localized,
                recovery: .retry
            )
        case .readFailed:
            return ParentErrorPresentation(
                title: HopCopy.errors.genericTitle.localized,
                message: HopCopy.errors.genericBody.localized,
                recovery: .retry
            )
        case .notificationsDenied:
            return ParentErrorPresentation(
                title: HopCopy.errors.notificationsDeniedTitle.localized,
                message: HopCopy.errors.notificationsDeniedBody.localized,
                recovery: .openSystemSettings,
                isDegradedNotBroken: true
            )
        case .purchaseFailed:
            return ParentErrorPresentation(
                title: HopCopy.purchase.failedTitle.localized,
                message: HopCopy.purchase.failedBody.localized,
                recovery: .retry
            )
        case .purchasePending:
            return ParentErrorPresentation(
                title: HopCopy.purchase.pendingTitle.localized,
                message: HopCopy.purchase.pendingBody.localized,
                recovery: .dismissOnly,
                isDegradedNotBroken: true
            )
        case .exportFailed:
            return ParentErrorPresentation(
                title: HopCopy.errors.storageTitle.localized,
                message: HopCopy.errors.storageBody.localized,
                recovery: .retry
            )
        case .offline:
            return ParentErrorPresentation(
                title: HopCopy.errors.genericTitle.localized,
                message: HopCopy.errors.genericBody.localized,
                recovery: .retry,
                isDegradedNotBroken: true
            )
        }
    }
}

extension ScreenTimeFailure {
    /// Recovery is derived from the failure's own two questions — can HopPotty
    /// fix this itself, and does the fix live outside the app — rather than from
    /// a second hand-maintained switch that could disagree with Core.
    var parentPresentation: ParentErrorPresentation {
        let recovery: ParentErrorPresentation.Recovery = {
            if requiresActionOutsideApp { return .openSystemSettings }
            if isSelfRecoverable { return .retry }
            return .reviewSettings
        }()

        switch self {
        case .authorizationRevoked, .authorizationConflict, .invalidAccountType,
             .authenticationMethodUnavailable:
            return ParentErrorPresentation(
                title: HopCopy.errors.screenTimeDeniedTitle.localized,
                message: HopCopy.errors.screenTimeDeniedBody.localized,
                recovery: recovery,
                isDegradedNotBroken: true
            )
        case .noSelection:
            return ParentErrorPresentation(
                title: HopCopy.errors.screenTimeNoSelectionTitle.localized,
                message: HopCopy.errors.screenTimeNoSelectionBody.localized,
                recovery: .reviewSettings,
                isDegradedNotBroken: true
            )
        case .monitoringRegistrationFailed, .monitoringLimitReached, .scheduleInvalid,
             .extensionUnavailable, .networkError:
            return ParentErrorPresentation(
                title: HopCopy.errors.screenTimeRegistrationTitle.localized,
                message: HopCopy.errors.screenTimeRegistrationBody.localized,
                recovery: recovery,
                isDegradedNotBroken: true
            )
        case .shieldApplyFailed:
            return ParentErrorPresentation(
                title: HopCopy.errors.shieldApplyTitle.localized,
                message: HopCopy.errors.shieldApplyBody.localized,
                recovery: recovery
            )
        case .shieldClearFailed:
            // The one failure where the recovery is a button the caregiver can
            // press right now, so it never points at the Settings app.
            return ParentErrorPresentation(
                title: HopCopy.errors.shieldClearTitle.localized,
                message: HopCopy.errors.shieldClearBody.localized,
                recovery: .reviewSettings
            )
        case .unknown:
            return ParentErrorPresentation(
                title: HopCopy.errors.genericTitle.localized,
                message: HopCopy.errors.genericBody.localized,
                recovery: recovery
            )
        }
    }
}

extension ScreenTimeAuthorizationStatus {
    /// What the caregiver reads when authorization itself is the problem.
    /// `.restricted` gets its own sentence because retrying cannot help.
    var deniedPresentation: ParentErrorPresentation? {
        switch self {
        case .approved, .notDetermined:
            return nil
        case .denied:
            return ParentErrorPresentation(
                title: HopCopy.errors.screenTimeDeniedTitle.localized,
                message: HopCopy.errors.screenTimeDeniedBody.localized,
                recovery: .openSystemSettings,
                isDegradedNotBroken: true
            )
        case .restricted:
            return ParentErrorPresentation(
                title: HopCopy.errors.screenTimeRestrictedTitle.localized,
                message: HopCopy.errors.screenTimeRestrictedBody.localized,
                recovery: .dismissOnly,
                isDegradedNotBroken: true
            )
        }
    }
}
