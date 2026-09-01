import Foundation
import HopPottyCore

/// Caregiver-facing wording for a Screen Time failure.
///
/// Every case names what HopPotty could not do and what the caregiver can do
/// next. None of them blames the child, and none of them implies a child's apps
/// are being withheld — the pause state, not the failure, decides that.
public extension ScreenTimeFailure {
    var title: String {
        switch self {
        case .authorizationRevoked: "Screen Time permission was turned off"
        case .noSelection: "No apps chosen yet"
        case .monitoringRegistrationFailed: "HopPotty couldn't start watching"
        case .scheduleInvalid: "This schedule can't run"
        case .shieldApplyFailed: "The pause didn't start"
        case .shieldClearFailed: "HopPotty couldn't confirm the apps came back"
        case .extensionUnavailable: "A HopPotty helper isn't running"
        case .unknown: "Something didn't finish"
        }
    }

    var recoveryMessage: String {
        switch self {
        case .authorizationRevoked:
            "HopPotty needs Screen Time permission to pause apps. You can grant it again in Settings."
        case .noSelection:
            "Choose which apps a Potty Pause should cover, then HopPotty can start."
        case .monitoringRegistrationFailed:
            "HopPotty will try again on its own. If it keeps happening, restarting the device usually clears it."
        case .scheduleInvalid:
            "The quiet hours and the interval overlap in a way that leaves no room. Adjust one of them."
        case .shieldApplyFailed:
            "The pause was skipped. HopPotty will try the next one."
        case .shieldClearFailed:
            "HopPotty asked for the apps back but didn't get a confirmation. Check the device — and if anything is still blocked, turn Potty Pause off to clear it."
        case .extensionUnavailable:
            "Reinstalling HopPotty restores the helper. Your data stays on the device."
        case .unknown:
            "HopPotty will try again. If it keeps happening, let us know what you were doing."
        }
    }

    /// Whether the caregiver has something to change, as opposed to HopPotty
    /// retrying by itself. Mirrors ``isSelfRecoverable`` and is what decides
    /// whether the error state offers a settings button.
    var needsCaregiverAction: Bool { !isSelfRecoverable }
}
