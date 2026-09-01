import Foundation
import StoreKit

// MARK: - Purchase domain types
//
// These live with the service rather than in the feature layer because the
// service is what produces them. They were originally declared in
// `Features/Shared/FeatureDependencies.swift` as placeholders while the two
// layers were built in parallel; that copy is deleted.

/// A product as the paywall needs to show it.
///
/// The price is carried as StoreKit's already-formatted `displayPrice` string.
/// No price is ever written down in this codebase: currency, formatting and
/// storefront are Apple's to decide, and a hard-coded "$19.99" is wrong the
/// moment the app is opened outside the US.
struct HopProduct: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let displayPrice: String
    let description: String
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


// MARK: - Product identity

/// The App Store products HopPotty sells. There is one.
enum HopProductID: String, CaseIterable, Sendable {
    /// Non-consumable, one-time, family-shareable. Configured in App Store
    /// Connect; **its price appears nowhere in this codebase**. Every price the
    /// UI shows comes from `Product.displayPrice`, which is already localised,
    /// already carries the right currency, and is already correct after a
    /// storefront change or a price adjustment we did not ship an update for.
    /// A hard-coded "$19.99" would be wrong for most of the world on day one.
    case familyUnlock = "com.hoppotty.family.unlock"
}

/// A product as the UI shows it. No StoreKit types cross this line, so a feature
/// cannot accidentally build a price string of its own.
struct HopProductDisplay: Sendable, Equatable, Identifiable {
    let id: String
    let displayName: String
    let description: String
    /// StoreKit's localised price string. The only price HopPotty ever renders.
    let displayPrice: String
}

/// The name the parent features use for the same value.
typealias HopProduct = HopProductDisplay

// MARK: - Outcomes

enum PurchaseOutcome: Equatable, Sendable {
    case purchased
    /// The caregiver cancelled. Not an error, and nothing is shown about it.
    case cancelled
    /// Ask-to-Buy, or a payment awaiting approval. The entitlement arrives later
    /// through `Transaction.updates`.
    case pending
    case alreadyOwned
    /// Products could not be loaded — usually no network.
    case productUnavailable
    /// StoreKit returned a transaction whose signature did not verify. Treated
    /// as a failure and never as an entitlement.
    case verificationFailed
    case failed
}

enum RestoreOutcome: Equatable, Sendable {
    case restored
    /// StoreKit answered and there was nothing to restore. Worth saying plainly:
    /// "nothing found" is a real answer and a caregiver who paid deserves to
    /// know the app asked properly.
    case nothingToRestore
    case failed
}

// MARK: - Observable state

/// The single source of truth for what is unlocked.
///
/// One `@Observable` object, owned by the service, observed by every screen that
/// gates a feature. Nothing else in the app decides what is unlocked, and no
/// feature caches its own copy — the whole class of "the paywall says locked but
/// the feature works" bugs comes from a second answer to this question.
@Observable
@MainActor
final class EntitlementState {
    private(set) var entitlement: HopEntitlement = .free
    /// Products as the UI shows them. Empty until StoreKit answers.
    private(set) var products: [HopProductDisplay] = []
    /// True while products or entitlements are loading, so a screen can show a
    /// placeholder instead of a price that is about to change.
    var isLoading = false
    /// True while the value on screen came from the offline cache and StoreKit
    /// has not yet answered this launch. The UI can use it to hold back a
    /// paywall for a beat rather than offering to sell something the family
    /// already owns.
    private(set) var isProvisional = true

    var hasFamilyUnlock: Bool { entitlement.hasFamilyUnlock }

    var familyProduct: HopProductDisplay? {
        products.first { $0.id == HopProductID.familyUnlock.rawValue }
    }

    func update(entitlement: HopEntitlement, provisional: Bool) {
        self.entitlement = entitlement
        self.isProvisional = provisional
    }

    func update(products: [HopProductDisplay]) {
        self.products = products
    }
}

// MARK: - Protocol

@MainActor
protocol PurchaseProviding: AnyObject {
    var state: EntitlementState { get }

    /// The current entitlement, for a caller that wants the value rather than
    /// the observable box. Always `state.entitlement`.
    var entitlement: HopEntitlement { get }

    /// The family unlock as the paywall renders it. `nil` until StoreKit
    /// answers — which is also the offline state, and the paywall shows its
    /// features and hides its price rather than inventing one.
    var product: HopProduct? { get }

    /// `loadProducts()` under the singular name the paywall uses.
    func loadProduct() async

    /// Loads products so a price can be shown. Safe to call repeatedly.
    func loadProducts() async

    /// Re-asks StoreKit what this Apple Account owns. Called on launch and on
    /// foreground; also how a refund takes effect.
    func refreshEntitlements() async

    /// Buys the family unlock.
    ///
    /// Takes a `ParentAuthorization` because **the child must never see a
    /// purchase surface**. The requirement is not "hide the button" — it is that
    /// the code path to a payment sheet begins at the parent gate. A signature
    /// that cannot be satisfied without one makes that checkable.
    func purchase(authorization: ParentAuthorization) async -> PurchaseOutcome

    /// Restores a previous purchase on a new device or after a reinstall.
    func restore(authorization: ParentAuthorization) async -> RestoreOutcome
}

// MARK: - Service

/// StoreKit 2, one non-consumable, no pressure.
///
/// ## What this file deliberately cannot do
///
/// There is no API here for any of the following, and adding one would be a
/// contract violation (§4.7), not a product decision:
///
/// - **A countdown.** No "offer ends in", no timer, no expiring discount. The
///   price is the price.
/// - **A limited-time or introductory offer.** The product is a permanent
///   unlock and is never dressed as a deal that might vanish.
/// - **A repeated prompt.** The paywall is shown when a caregiver opens a paid
///   feature or the upgrade row. It is never shown on launch, never on a timer,
///   and never after a dismissal.
/// - **A dark-patterned dismissal.** No tiny X, no "No thanks, I don't want my
///   child to succeed" decline copy. The dismiss control is a normal control
///   with a normal word on it.
/// - **Any child-facing surface.** Every entry point is behind the parent gate.
@MainActor
final class PurchaseService: PurchaseProviding {
    let state = EntitlementState()
    var entitlement: HopEntitlement { state.entitlement }
    var product: HopProduct? { state.familyProduct }

    private let cache: EntitlementCache
    private let clock: any HopClock
    private var products: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?

    init(cache: EntitlementCache = EntitlementCache(), clock: any HopClock = SystemClock()) {
        self.cache = cache
        self.clock = clock

        // Seed from the cache *before* StoreKit answers, so an owning family
        // never sees a locked app flash on launch. Marked provisional until the
        // first real answer replaces it.
        state.update(entitlement: cache.entitlement, provisional: true)

        startTransactionListener()
    }

    // The listener runs for the life of the app. It is not cancelled in
    // `deinit`: `deinit` on a `@MainActor` class is non-isolated, and this
    // service is created once by the dependency container.

    // MARK: Products

    func loadProducts() async {
        state.isLoading = true
        defer { state.isLoading = false }
        do {
            let loaded = try await Product.products(for: HopProductID.allCases.map(\.rawValue))
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            state.update(
                products: loaded.map {
                    HopProductDisplay(
                        id: $0.id,
                        displayName: $0.displayName,
                        description: $0.description,
                        // Straight from StoreKit, localised and current.
                        displayPrice: $0.displayPrice
                    )
                }
            )
            HopLog.purchase.info("products loaded count=\(loaded.count, privacy: .public)")
        } catch {
            // No prices to show. The paywall must say so rather than render an
            // empty price or a placeholder that looks like a number.
            HopLog.purchase.error(
                "product load failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
        }
    }

    // MARK: Entitlements

    /// Re-derives the entitlement from StoreKit.
    ///
    /// `Transaction.currentEntitlements` is served from the device's own
    /// StoreKit cache, so it answers offline as well as online — which is why
    /// this treats it as authoritative rather than second-guessing an empty
    /// result. That matters most for the case where guessing would be actively
    /// wrong: after a **refund or a Family Sharing removal**, the entitlement is
    /// simply absent, and a service that kept a cached "family" on the grounds
    /// that "the store might be unreachable" would never let go of a purchase
    /// that no longer exists.
    ///
    /// `EntitlementCache` is therefore only a launch-time seed to stop the UI
    /// flashing "locked" before this runs. Once this method completes, the
    /// cache is whatever StoreKit just said.
    func refreshEntitlements() async {
        var entitled = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = Self.verified(result) else { continue }
            // `currentEntitlements` already omits revoked transactions; the
            // explicit check costs nothing and documents the intent for anyone
            // reading this in a year.
            guard transaction.revocationDate == nil else { continue }
            if transaction.productID == HopProductID.familyUnlock.rawValue { entitled = true }
        }

        let entitlement: HopEntitlement = entitled ? .family : .free
        cache.store(entitlement, verifiedAt: clock.now)
        state.update(entitlement: entitlement, provisional: false)
        HopLog.purchase.info(
            "entitlement verified value=\(entitlement.rawValue, privacy: .public)"
        )
    }

    // MARK: Purchase

    func purchase(authorization: ParentAuthorization) async -> PurchaseOutcome {
        guard authorization.isValid(at: clock.now), authorization.reason == .purchase else {
            HopLog.purchase.error("purchase refused: parent gate missing or stale")
            return .failed
        }
        if state.hasFamilyUnlock { return .alreadyOwned }

        if products.isEmpty { await loadProducts() }
        guard let product = products[HopProductID.familyUnlock.rawValue] else {
            return .productUnavailable
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard let transaction = Self.verified(verification) else {
                    HopLog.purchase.error("purchase verification failed")
                    return .verificationFailed
                }
                await transaction.finish()
                await refreshEntitlements()
                HopLog.purchase.notice("purchase completed")
                return .purchased

            case .userCancelled:
                // Silent by design. A cancelled purchase gets no follow-up
                // prompt, no "are you sure?", no discount offer.
                return .cancelled

            case .pending:
                // Ask-to-Buy. The entitlement will arrive through
                // `Transaction.updates` if a parent approves it, possibly days
                // later, possibly on another device.
                HopLog.purchase.info("purchase pending approval")
                return .pending

            @unknown default:
                return .failed
            }
        } catch {
            HopLog.purchase.error(
                "purchase failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            return .failed
        }
    }

    // MARK: Restore

    func restore(authorization: ParentAuthorization) async -> RestoreOutcome {
        guard authorization.isValid(at: clock.now), authorization.reason == .restorePurchase else {
            return .failed
        }
        do {
            // Prompts for the Apple Account password, which is why it is only
            // ever behind an explicit "Restore purchase" control and never run
            // automatically on launch.
            try await AppStore.sync()
            await refreshEntitlements()
            return state.hasFamilyUnlock ? .restored : .nothingToRestore
        } catch {
            HopLog.purchase.error(
                "restore failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            return .failed
        }
    }

    // MARK: Transaction listener

    /// Watches for entitlement changes that did not start in this app: a
    /// purchase on another device, an Ask-to-Buy approval, a Family Sharing
    /// change, and — the one that matters most — a **refund or revocation**.
    ///
    /// A refunded family must lose the unlock, promptly and without drama. The
    /// listener re-derives entitlement from StoreKit rather than toggling a
    /// flag, so revocation, expiry and sharing all take the same path.
    private func startTransactionListener() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                guard let transaction = Self.verified(update) else {
                    HopLog.purchase.error("unverified transaction ignored")
                    continue
                }
                await transaction.finish()
                await self.refreshEntitlements()
                if transaction.revocationDate != nil {
                    HopLog.purchase.notice("transaction revoked; entitlement re-derived")
                }
            }
        }
    }

    /// Unwraps a verification result. An unverified transaction is **never**
    /// treated as an entitlement — a signature that does not check out is the
    /// one case where refusing is unambiguously right.
    private nonisolated static func verified(
        _ result: VerificationResult<Transaction>
    ) -> Transaction? {
        switch result {
        case .verified(let transaction): transaction
        case .unverified: nil
        }
    }
}

// MARK: - Mock

/// A purchase service with no App Store behind it.
///
/// Previews and tests use this; so does any build where hitting StoreKit would
/// be wrong. The prices are obviously fake strings rather than plausible ones,
/// so a screenshot taken from a preview can never be mistaken for the real
/// price of the product.
@MainActor
final class MockPurchaseService: PurchaseProviding {
    let state = EntitlementState()
    var entitlement: HopEntitlement { state.entitlement }
    var product: HopProduct? { state.familyProduct }
    private(set) var purchaseAttempts = 0
    private(set) var restoreAttempts = 0
    /// What the next purchase should do, so a test can drive every branch.
    var nextOutcome: PurchaseOutcome = .purchased

    init(entitlement: HopEntitlement = .free) {
        state.update(entitlement: entitlement, provisional: false)
        state.update(
            products: [
                HopProductDisplay(
                    id: HopProductID.familyUnlock.rawValue,
                    displayName: "HopPotty Family",
                    description: "Every feature, for every child in the family, once.",
                    displayPrice: "$—.—"
                )
            ]
        )
    }

    func loadProducts() async {}

    func refreshEntitlements() async {}

    func purchase(authorization: ParentAuthorization) async -> PurchaseOutcome {
        purchaseAttempts += 1
        if nextOutcome == .purchased {
            state.update(entitlement: .family, provisional: false)
        }
        return nextOutcome
    }

    func restore(authorization: ParentAuthorization) async -> RestoreOutcome {
        restoreAttempts += 1
        return state.hasFamilyUnlock ? .restored : .nothingToRestore
    }
}

// MARK: - Feature-layer spelling

extension PurchaseProviding {
    /// The paywall's singular name for `loadProducts()`.
    func loadProduct() async { await loadProducts() }
}
