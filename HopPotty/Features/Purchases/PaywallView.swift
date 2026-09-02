import SwiftUI
import HopPottyCore

/// The paywall.
///
/// It is reachable only from behind the parent gate, and a child never sees it:
/// nothing in the child surfaces links here, and the free tier keeps the whole
/// routine, every reminder and every star already earned. Nothing a child
/// earned is ever behind the purchase — `HopCopy.purchase.freeFooter` states
/// that as a commitment, and this screen is where it has to be true.
struct PaywallView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(ParentEnvironment.self) private var parent

    /// Proof the gate was passed to get here. The screen cannot be constructed
    /// without it, which is stronger than remembering to check.
    let authorization: ParentAuthorization

    @State private var model: PaywallModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    header
                    features
                    priceBlock
                    freeTierFooter
                }
                .hopPageMargins()
                .padding(.vertical, theme.spacing.l)
                .hopReadableWidth()
            }
            .hopBackground(.primary)
            .navigationTitle(Text(hop: HopCopy.purchase.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(HopCopy.common.done.localized) { dismiss() }
                }
            }
        }
        .task { await ensureLoaded() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(hop: HopCopy.purchase.subtitle)
                .font(theme.font(.parentTitle))
                .foregroundStyle(theme.color.textPrimary)
            if model?.isUnlocked == true {
                HopPill(HopFeatureStrings.settingsPurchasedBadge, tint: theme.color.success, glyph: .check)
            }
        }
    }

    private var features: some View {
        let items = model?.features ?? PaywallFeature.allCases
        // The list lifts into place once, top to bottom. It is the only part of
        // this screen that is a list of things, and it is the part a caregiver
        // is actually reading — nothing else here arrives, so the stagger says
        // "here is what you get" rather than decorating the whole page.
        return VStack(alignment: .leading, spacing: theme.spacing.m) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, feature in
                HStack(alignment: .top, spacing: theme.spacing.m) {
                    HopGlyphView(feature.glyph, size: 24)
                        .foregroundStyle(theme.color.brandPrimary)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: feature.title)
                            .font(theme.font(.parentHeadline))
                            .foregroundStyle(theme.color.textPrimary)
                        Text(verbatim: feature.summary)
                            .font(theme.font(.parentCallout))
                            .foregroundStyle(theme.color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .hopArrival(index: index)
            }
        }
    }

    /// The price, the buttons, and whatever StoreKit is doing instead.
    ///
    /// This is the loading-to-content swap on the paywall: the features above
    /// are described from the moment the screen opens, and only this block waits
    /// on the store. It arrives in place, because it never came from anywhere —
    /// the block is already in the layout and the spinner is standing where the
    /// price will be.
    @ViewBuilder
    private var priceBlock: some View {
        Group {
            priceContent
        }
        .hopScreenChange(.cardArrival, value: model?.phase)
    }

    @ViewBuilder
    private var priceContent: some View {
        switch model?.phase {
        case .purchased:
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(hop: HopCopy.purchase.thanksTitle)
                    .font(theme.font(.parentHeadline))
                Text(hop: HopCopy.purchase.thanksBody)
                    .font(theme.font(.parentCallout))
                    .foregroundStyle(theme.color.textSecondary)
            }
            .hopScreenTransition(.cardArrival)
        case .pending:
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(hop: HopCopy.purchase.pendingTitle)
                    .font(theme.font(.parentHeadline))
                Text(hop: HopCopy.purchase.pendingBody)
                    .font(theme.font(.parentCallout))
                    .foregroundStyle(theme.color.textSecondary)
            }
            .hopScreenTransition(.cardArrival)
        case .purchasing, .restoring, .loading, .none:
            HopLoadingState(message: nil)
                .hopScreenTransition(.cardArrival)
        case .unavailable:
            // Offline, or StoreKit did not answer. The features stay described
            // and the button stays disabled; no price is guessed.
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                Text(hop: HopCopy.errors.genericBody)
                    .font(theme.font(.parentCallout))
                    .foregroundStyle(theme.color.textSecondary)
                HopSecondaryButton(HopCopy.errors.retryButton.localized) {
                    Task { await model?.load() }
                }
                restoreButton
            }
            .hopScreenTransition(.cardArrival)
        case .failed(let failure):
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                Text(verbatim: failure.presentation.title)
                    .font(theme.font(.parentHeadline))
                Text(verbatim: failure.presentation.message)
                    .font(theme.font(.parentCallout))
                    .foregroundStyle(theme.color.textSecondary)
                buyButton
                restoreButton
            }
            .hopScreenTransition(.cardArrival)
        case .ready:
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                if let price = model?.displayPrice {
                    Text(verbatim: HopCopy.purchase.price.localized(.text(price)))
                        .font(theme.font(.parentTitle))
                        .foregroundStyle(theme.color.textPrimary)
                }
                buyButton
                restoreButton
            }
            .hopScreenTransition(.cardArrival)
        }
    }

    private var buyButton: some View {
        HopPrimaryButton(HopCopy.purchase.buyButton.localized) {
            Task { await model?.purchase(authorization: authorization) }
        }
        .disabled(model?.displayPrice == nil)
    }

    private var restoreButton: some View {
        HopSecondaryButton(HopCopy.purchase.restoreButton.localized) {
            Task { await model?.restore(authorization: authorization) }
        }
    }

    private var freeTierFooter: some View {
        Text(hop: HopCopy.purchase.freeFooter)
            .font(theme.font(.parentFootnote))
            .foregroundStyle(theme.color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func ensureLoaded() async {
        if model == nil { model = PaywallModel(environment: parent) }
        await model?.load()
    }
}

#if DEBUG
// `@MainActor` because a file-scope `private func` is nonisolated by default,
// while `ParentEnvironment`, the design-system modifiers and the views
// themselves are all main-actor isolated. Every call site is a `#Preview` body,
// which is main-actor anyway, so the annotation states what was already true.
//
// Six file-scope preview helpers across the app have this exact shape. The
// compiler named four of them (one in run 60, three in run 66) and stopped;
// the other two were found by looking for the shape rather than waiting to be
// told. All six are annotated.
@MainActor
private func paywallPreview(_ environment: ParentEnvironment) -> some View {
    PaywallView(authorization: .mint(reason: .purchase))
        .environment(environment)
        .hopThemedRoot()
}

#Preview("Free tier") { paywallPreview(.preview(entitlement: .free)) }
#Preview("Purchased") { paywallPreview(.preview(entitlement: .family)) }
#Preview("StoreKit unavailable") { paywallPreview(.previewOffline()) }
#Preview("AX3 dark") {
    paywallPreview(.preview())
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}
#endif
