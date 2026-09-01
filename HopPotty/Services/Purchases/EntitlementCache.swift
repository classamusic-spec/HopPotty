import Foundation

/// What the family has unlocked.
///
/// Two states, because there are two: the free app, and the one-time
/// **HopPotty Family** unlock. There is no subscription, no tier above this, no
/// consumable and nothing that expires.
enum HopEntitlement: String, Sendable, CaseIterable {
    case free
    case family

    var hasFamilyUnlock: Bool { self == .family }
}

/// The last entitlement StoreKit verified, kept for when StoreKit cannot be
/// reached.
///
/// ## Why a cache at all
///
/// `Transaction.currentEntitlements` needs the App Store. A family on a plane, on
/// a school iPad behind a filter, or simply in a house with bad wifi will
/// otherwise open a paid app and find their features gone. That is the single
/// most common way a legitimate purchase is made to feel like a scam.
///
/// ## The rules that keep it honest
///
/// 1. **Write only after verification.** The cache is written from a
///    `VerificationResult.verified` transaction, or from a verified *absence*
///    (StoreKit answered, and the entitlement was not there). A network failure
///    writes nothing.
/// 2. **No expiry.** The unlock is permanent, so a cache with a timeout would
///    be a paid feature that stops working after a fortnight offline. The
///    timestamp is kept for diagnostics only.
/// 3. **Revocation wins immediately.** A refund or a family-sharing removal
///    clears the cache the moment StoreKit says so, with no grace period. The
///    cache exists to survive *silence*, never to argue with an answer.
/// 4. **It is not a receipt.** It proves nothing to anyone; it is a local hint
///    that stops the UI flickering. Someone editing it can unlock the app on
///    their own device, which is a trade every offline-tolerant app makes and
///    which costs a family nothing.
struct EntitlementCache {
    private let defaults: UserDefaults

    private enum Key {
        static let entitlement = "hop.entitlement.v1"
        static let verifiedAt = "hop.entitlement.verifiedAt.v1"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The cached entitlement, or `.free` when nothing has ever been verified.
    var entitlement: HopEntitlement {
        guard let raw = defaults.string(forKey: Key.entitlement),
              let value = HopEntitlement(rawValue: raw)
        else { return .free }
        return value
    }

    /// When StoreKit last answered. Diagnostics only — never used to expire the
    /// entitlement.
    var lastVerifiedAt: Date? {
        defaults.object(forKey: Key.verifiedAt) as? Date
    }

    /// Records a verified answer, whichever way it went.
    func store(_ entitlement: HopEntitlement, verifiedAt: Date) {
        defaults.set(entitlement.rawValue, forKey: Key.entitlement)
        defaults.set(verifiedAt, forKey: Key.verifiedAt)
        HopLog.purchase.info(
            "entitlement cached value=\(entitlement.rawValue, privacy: .public)"
        )
    }

    /// Used by "Reset app". A device being handed on should not carry an
    /// entitlement hint for the previous family.
    func clear() {
        defaults.removeObject(forKey: Key.entitlement)
        defaults.removeObject(forKey: Key.verifiedAt)
    }
}
