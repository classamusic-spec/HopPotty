import Foundation
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

/// Face ID / Touch ID / passcode, for the caregiver who wants the gate to be a
/// real one.
///
/// `deviceOwnerAuthentication` rather than `deviceOwnerAuthenticationWithBiometrics`
/// on purpose: the passcode fallback is the point. A parent whose hands are wet,
/// whose face is behind a mask, or whose device has no biometrics still has to
/// be able to reach "Restore Screen Access" — a gate that can lock a caregiver
/// out of lifting a shield is worse than no gate.
@MainActor
final class DeviceOwnerAuthenticator {

    enum Result: Equatable {
        case passed
        /// The caregiver cancelled. Not an error; the sheet simply stays.
        case cancelled
        /// No passcode set, no biometrics enrolled, or the policy is
        /// unavailable. The caller falls back to the arithmetic challenge and
        /// says so rather than appearing broken.
        case unavailable
        case failed
    }

    /// Whether device-owner authentication can be offered at all. Read before
    /// showing the option in Settings, so a caregiver cannot select a gate style
    /// their device cannot satisfy.
    static var isAvailable: Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        #else
        return false
        #endif
    }

    func authenticate(reason: String) async -> Result {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .unavailable
        }
        // The callback form wrapped by hand rather than the generated `async`
        // overload: the continuation is resumed exactly once here, and the
        // mapping from `LAError` to our three outcomes is visible.
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evaluationError in
                if success {
                    continuation.resume(returning: .passed)
                    return
                }
                let code = (evaluationError as? LAError)?.code
                switch code {
                case .userCancel, .appCancel, .systemCancel:
                    continuation.resume(returning: .cancelled)
                case .passcodeNotSet, .biometryNotAvailable, .biometryNotEnrolled:
                    continuation.resume(returning: .unavailable)
                default:
                    continuation.resume(returning: .failed)
                }
            }
        }
        #else
        return .unavailable
        #endif
    }
}
