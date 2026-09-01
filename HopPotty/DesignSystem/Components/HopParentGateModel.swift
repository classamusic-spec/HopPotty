import Foundation
import Observation
import HopPottyCore
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

/// A two-digit sum. Trivial for an adult, out of reach for a preschooler, and
/// solvable without a passcode by a caregiver holding a child in one arm.
public struct HopArithmeticChallenge: Equatable, Sendable {
    public let left: Int
    public let right: Int

    public init(left: Int, right: Int) {
        self.left = left
        self.right = right
    }

    public var answer: Int { left + right }
    public var question: String { "\(left) + \(right)" }

    /// Both operands are two digits and the sum carries, so the answer cannot be
    /// reached by reading digits off the screen.
    public static func random() -> HopArithmeticChallenge {
        let left = Int.random(in: 12...48)
        let right = Int.random(in: 12...48)
        return HopArithmeticChallenge(left: left, right: right)
    }
}

/// Drives the parent gate.
///
/// Separate from the view so the state machine — hold, then answer, then pass —
/// can be exercised without a UI, and so a preview can pin the challenge and
/// stay deterministic.
@MainActor
@Observable
public final class HopParentGateModel {
    public enum Stage: Equatable {
        case holding
        case answering
        case authenticating
        case passed
        case unavailable
    }

    public private(set) var stage: Stage
    public private(set) var challenge: HopArithmeticChallenge
    public private(set) var entry: String = ""
    /// Set after a wrong answer. Phrased as "here is another one", never as a
    /// mistake — a caregiver mistyping is not a failure worth naming.
    public private(set) var retryMessage: String?

    private let style: ParentGateStyle

    public init(style: ParentGateStyle, challenge: HopArithmeticChallenge = .random()) {
        self.style = style
        self.challenge = challenge
        self.stage = style == .deviceOwner ? .authenticating : .holding
    }

    public var maximumEntryLength: Int { 3 }

    public func completeHold() {
        guard stage == .holding else { return }
        stage = .answering
    }

    public func append(_ digit: Int) {
        guard stage == .answering, entry.count < maximumEntryLength else { return }
        entry.append(String(digit))
        retryMessage = nil
    }

    public func deleteLast() {
        guard stage == .answering, !entry.isEmpty else { return }
        entry.removeLast()
    }

    /// Returns `true` when the answer was right, so the view can call `onPass`.
    @discardableResult
    public func submit() -> Bool {
        guard stage == .answering, let value = Int(entry) else { return false }
        guard value == challenge.answer else {
            // A fresh challenge every time, so repeated guessing gains nothing.
            challenge = .random()
            entry = ""
            retryMessage = HopStrings.gateRetry
            return false
        }
        stage = .passed
        return true
    }

    /// Runs device-owner authentication. Falls back to `.unavailable` rather
    /// than silently letting anyone through.
    @discardableResult
    public func authenticateDeviceOwner() async -> Bool {
        stage = .authenticating
        let passed = await HopDeviceOwnerAuthentication.authenticate(reason: HopStrings.gateFaceIDReason)
        stage = passed ? .passed : .unavailable
        return passed
    }

    /// Switches a device-owner gate to the arithmetic challenge, for a device
    /// with no passcode set or a caregiver whose biometrics are not enrolled.
    public func fallBackToArithmetic() {
        challenge = .random()
        entry = ""
        retryMessage = nil
        stage = .answering
    }
}

/// Device-owner authentication, isolated so the `LocalAuthentication` import
/// does not spread into view code.
public enum HopDeviceOwnerAuthentication {
    /// `.deviceOwnerAuthentication`, not `.deviceOwnerAuthenticationWithBiometrics`:
    /// a caregiver whose Face ID fails with a toddler's hand over the camera
    /// still has the passcode, and a device with no biometrics still has a gate.
    public static func authenticate(reason: String) async -> Bool {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return false }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
}
