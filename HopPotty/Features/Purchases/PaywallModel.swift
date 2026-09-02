import Foundation
import Observation
import HopPottyCore

/// The purchase screen's state.
///
/// What is deliberately absent is as important as what is here: there is no
/// countdown, no "offer ends", no A/B variant, no trial that converts, no
/// discount that expires and no upsell that reappears. HopPotty sells one
/// non-consumable once. A caregiver who says no is not asked again by anything
/// other than their own tap on the same row in Settings.
@MainActor
@Observable
final class PaywallModel {

    enum Phase: Equatable {
        case loading
        case ready
        case purchasing
        case restoring
        case purchased
        /// Ask to Buy sent the request to the family organiser. Not a failure.
        case pending
        case failed(ParentFailure)
        /// StoreKit could not be reached. The features are still described; the
        /// price is not invented.
        case unavailable
    }

    private(set) var phase: Phase = .loading
    private(set) var product: HopProduct?

    private let environment: ParentEnvironment

    init(environment: ParentEnvironment) {
        self.environment = environment
    }

    var entitlement: ParentEntitlement { environment.purchases.entitlement }
    var isUnlocked: Bool { entitlement.isUnlocked }

    /// The price, exactly as StoreKit formatted it for this storefront, or
    /// `nil`. Never composed, never cached across launches, never defaulted.
    var displayPrice: String? { product?.displayPrice }

    func load() async {
        phase = .loading
        await environment.purchases.loadProduct()
        product = environment.purchases.product
        if isUnlocked {
            phase = .purchased
        } else if product == nil {
            phase = .unavailable
        } else {
            phase = .ready
        }
    }

    /// Requires proof the gate was passed. A purchase is never one tap away
    /// from a child's hands.
    func purchase(authorization: ParentAuthorization) async {
        guard authorization.isValid(at: environment.clock.now) else {
            phase = .failed(.purchaseFailed)
            return
        }
        phase = .purchasing
        switch await environment.purchases.purchase(authorization: authorization) {
        case .purchased, .alreadyOwned: phase = .purchased
        case .pending: phase = .pending
        case .cancelled: phase = .ready
        case .productUnavailable: phase = .unavailable
        case .verificationFailed, .failed: phase = .failed(.purchaseFailed)
        }
    }

    func restore(authorization: ParentAuthorization) async {
        guard authorization.isValid(at: environment.clock.now) else {
            phase = .failed(.purchaseFailed)
            return
        }
        phase = .restoring
        switch await environment.purchases.restore(authorization: authorization) {
        case .restored: phase = .purchased
        case .nothingToRestore, .failed:
            // Nothing to restore is not an error worth an alert; the screen
            // simply returns to offering the purchase.
            phase = product == nil ? .unavailable : .ready
        }
    }

    /// Everything the unlock adds, in the order the paywall lists it.
    var features: [PaywallFeature] { PaywallFeature.allCases }
}
