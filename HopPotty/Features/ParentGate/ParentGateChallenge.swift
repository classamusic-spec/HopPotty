import Foundation
import HopPottyCore

/// The two-part challenge a caregiver passes to reach an adult surface.
///
/// Two parts because either one alone is beatable by the person it is meant to
/// stop. A three-year-old will hold a button down for a second by accident; a
/// six-year-old can read "13 + 24" off the screen and tap the answer if there is
/// no hold. Together they need sustained intent *and* arithmetic, which is the
/// line Apple's own guidance draws for "parental gate".
///
/// It is not a security boundary and is not sold as one. A determined ten-year-old
/// passes it. What it prevents is an accidental purchase, an accidental deletion
/// and a curious tap into Screen Time settings — see `ParentGateStyle.deviceOwner`
/// for the caregiver who wants a real one.
struct ParentGateChallenge: Equatable, Sendable {
    /// Both addends are two digits and the sum stays under 100, so the answer is
    /// always two digits: a wider range would make the gate harder for a
    /// caregiver with a phone in one hand, not harder for a child.
    let first: Int
    let second: Int

    var answer: Int { first + second }

    var question: String {
        HopCopy.parentGate.question.localized(.count(first), .count(second))
    }

    /// How long the button must be held. Long enough that a stray tap does not
    /// start the gate, short enough that it does not read as a stuck button.
    static let holdDuration: TimeInterval = 1.2

    /// Wrong answers before a new sum is generated. There is no lockout: a
    /// caregiver who mistypes twice is not a threat, and locking a parent out of
    /// "Restore Screen Access" would be the worst possible failure mode.
    static let attemptsPerChallenge = 3

    static func random(using generator: inout some RandomNumberGenerator) -> ParentGateChallenge {
        // 11...49 plus 11...49 keeps both addends two-digit and the sum ≤ 98.
        let first = Int.random(in: 11...49, using: &generator)
        let second = Int.random(in: 11...49, using: &generator)
        return ParentGateChallenge(first: first, second: second)
    }

    static func random() -> ParentGateChallenge {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }

    /// A fixed challenge, for previews and snapshot tests.
    static let preview = ParentGateChallenge(first: 13, second: 24)

    func accepts(_ typed: String) -> Bool {
        guard let value = Int(typed.trimmingCharacters(in: .whitespaces)) else { return false }
        return value == answer
    }
}

/// Where the gate is in its own flow.
enum ParentGatePhase: Equatable {
    case holding
    case answering
    case retrying
    case authenticating
    case passed
    /// Device-owner authentication is unavailable on this device, so the gate
    /// fell back to the sum. Stated rather than silently swapped.
    case fellBackToArithmetic
}

/// What the gate was raised for. Maps one-to-one onto `ParentAuthorization.Reason`
/// so the minted authorization records why it exists.
extension ParentAuthorization.Reason {
    /// Whether this reason is destructive, which the gate says out loud before
    /// the challenge rather than after it.
    var isDestructive: Bool {
        switch self {
        case .deleteData: true
        case .openParentArea, .changeSchedule, .exportData, .purchase, .restorePurchase: false
        }
    }
}
