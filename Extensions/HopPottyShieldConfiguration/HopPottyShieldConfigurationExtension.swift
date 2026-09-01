import Foundation
import UIKit
import ManagedSettings
import ManagedSettingsUI

/// The HopPotty-branded shield.
///
/// ## What is customisable, and what the OS fixes
///
/// `ShieldConfiguration` has **nine properties and no others**. Everything else
/// about the screen belongs to iOS. This is worth stating precisely, because it
/// is the one child-facing surface where HopPotty's design system does not apply
/// and a designer will otherwise ask for things that cannot exist.
///
/// **Customisable — the whole list:**
///
/// | Property | Type | What it controls |
/// | --- | --- | --- |
/// | `backgroundBlurStyle` | `UIBlurEffect.Style?` | The blur behind everything |
/// | `backgroundColor` | `UIColor?` | Tint applied with that blur |
/// | `icon` | `UIImage?` | One static image, centred |
/// | `title` | `Label?` | Text + colour |
/// | `subtitle` | `Label?` | Text + colour |
/// | `primaryButtonLabel` | `Label?` | Text + colour |
/// | `primaryButtonBackgroundColor` | `UIColor?` | Fill of the primary button |
/// | `secondaryButtonLabel` | `Label?` | Text + colour; `nil` removes the button |
/// | `secondaryButtonSubmenuItems` | `[String]?` | iOS 26.4+, max 3 |
///
/// **Fixed by the OS, and not negotiable:**
///
/// - Layout, spacing, alignment and the order of the elements.
/// - Button shapes, sizes, corner radii and hit targets. Contract §6's 72pt/96pt
///   minimums cannot be enforced here; whatever iOS draws is what a child taps.
/// - Fonts, weights and sizes. `ShieldConfiguration.Label` carries a `String` and
///   a `UIColor` — there is no attributed string and no font parameter.
/// - The icon's size and position; it is centred and scaled by the system.
/// - There is no third button, no custom view, no input, no scroll view.
/// - **No animation of any kind.** Contract §6's Reduce Motion requirement is
///   satisfied trivially, because motion is not available to violate it with.
/// - Dark mode: HopPotty supplies one colour per role, and iOS does not resolve
///   `UIColor` dynamic providers here in any documented way. The palette below is
///   the light-appearance one in both appearances.
///   UNVERIFIED — confirm on device: whether a dynamic `UIColor` resolves against
///   the system appearance inside this extension. If it does, the subtitle and
///   title colours should become dynamic; if it does not, Cloud-on-Midnight is
///   legible in both and stays.
///
/// ## Why this extension computes nothing
///
/// Apple: return a configuration "as quickly as possible … The system provides a
/// default appearance for any methods that your subclass doesn't override, **or
/// if it takes too long**." The default appearance carries Apple's copy, which is
/// the vocabulary of restriction — "limit", "blocked", "not available". That is
/// the exact framing HopPotty exists to avoid, so a slow data source is not a
/// cosmetic defect: it is a copy failure that puts words in front of a
/// three-year-old that no one on this project wrote.
///
/// So: no localisation lookup, no colour arithmetic, no asset decoding, no
/// network (the sandbox forbids it anyway), and no work that could have been done
/// in the app. Four strings and five colours are read from the App Group. If that
/// read fails for any reason, a compiled-in fallback carrying the same copy is
/// used — never the system default.
///
/// ## The privacy rule this extension has to keep alone
///
/// This is the **only** place in the whole system where app identity is legible:
/// `Application.bundleIdentifier` and `Application.localizedDisplayName` are
/// non-`nil` here and `nil` everywhere else. They may be used to compose the
/// sentence on screen and for nothing else. They are never written to the App
/// Group, never logged, never put in a report, and never sent anywhere. The
/// `ExtensionReport` type has no free-text field precisely so that this rule
/// cannot be broken by accident.
final class HopPottyShieldConfigurationExtension: ShieldConfigurationDataSource {

    private var store: AppGroupStore { AppGroupStore.shared }

    // MARK: - Data source

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // `application.localizedDisplayName` is deliberately unused. HopCopy has a
        // `shield.bodyWithApp` variant that names the app, and it is not wired up
        // here on purpose: naming the app requires resolving a format string in
        // this extension, which is the computation this whole file exists to
        // avoid. If the copy team wants it, the app must pre-resolve the sentence
        // per shielded app, which is a real design change with a real cost.
        build()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        build()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        build()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        build()
    }

    // MARK: - Building

    /// Reconcile, then draw.
    ///
    /// The reconciliation is the most valuable line in this file. iOS calls this
    /// extension **whenever it needs to draw the shield**, which is the exact
    /// moment a child is looking at a blocked app — and it requires no tap, no
    /// timer, and no running app. After a reboot or a crash it is frequently the
    /// first HopPotty code to run at all, so a stranded shield begins healing
    /// before the child has touched anything.
    ///
    /// UNVERIFIED — confirm on device: whether a `ManagedSettingsStore` write from
    /// inside a shield configuration extension is honoured. Apple documents the
    /// sandbox as preventing network access and "moving sensitive content outside
    /// the extension's address space", neither of which describes a settings
    /// write, but it is not documented as permitted either. The design does not
    /// depend on the answer — the shield action extension, the monitor and the app
    /// all repeat the clear — so this is a free improvement if it works and
    /// harmless if it does not.
    private func build() -> ShieldConfiguration {
        let instant = Date()
        ShieldReconciler.reconcile(
            store: store, source: .shieldConfiguration, beating: .shieldConfiguration, now: instant
        )
        store.appendReport(
            ExtensionReport(
                source: .shieldConfiguration,
                kind: .shieldDrawn,
                at: instant,
                sessionID: store.loadPause()?.sessionID
            )
        )

        // The fallback is not a placeholder. It carries the shipping copy, so a
        // missing or unreadable payload still produces a HopPotty shield rather
        // than Apple's. See `ShieldPresentation.fallback`.
        let presentation = store.loadShieldPresentation() ?? .fallback
        return configuration(from: presentation)
    }

    private func configuration(from presentation: ShieldPresentation) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: presentation.backgroundBlurStyleRawValue
                .flatMap(UIBlurEffect.Style.init(rawValue:)),
            backgroundColor: color(presentation.backgroundColor),
            icon: Self.icon,
            title: ShieldConfiguration.Label(
                text: presentation.title,
                color: color(presentation.titleColor)
            ),
            subtitle: ShieldConfiguration.Label(
                text: presentation.subtitle,
                color: color(presentation.subtitleColor)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: presentation.primaryButtonLabel,
                color: color(presentation.primaryButtonTextColor)
            ),
            primaryButtonBackgroundColor: color(presentation.primaryButtonColor),
            // `nil` removes the secondary button entirely, which is what Apple's
            // API means by a nil label — not "a button with no text".
            secondaryButtonLabel: presentation.secondaryButtonLabel.map {
                ShieldConfiguration.Label(text: $0, color: color(presentation.titleColor))
            }
        )
    }

    private func color(_ rgba: ShieldPresentation.RGBA) -> UIColor {
        UIColor(
            red: CGFloat(rgba.red),
            green: CGFloat(rgba.green),
            blue: CGFloat(rgba.blue),
            alpha: CGFloat(rgba.alpha)
        )
    }

    // MARK: - Icon

    /// Hop, as a single flat image.
    ///
    /// Drawn in code rather than loaded from an asset catalogue only because this
    /// repository has no Xcode project yet and therefore no asset catalogue to put
    /// one in. **Before shipping, replace this with a pre-rendered PNG in the
    /// extension's own bundle** — `Art/` already holds the vector source and
    /// `Scripts/render.js` already rasterises it. A drawing this simple is cheap,
    /// but decoding a correctly sized PNG is cheaper still, and the real Hop is
    /// warmer than two circles and an arc.
    ///
    /// Rendered once and cached for the process lifetime. The process is short,
    /// so in practice this is once per shield draw; the `static let` exists so
    /// that a system that calls all four data-source methods in a row pays for it
    /// once.
    ///
    /// Colours are `HopPalette.hopGreen` and `HopPalette.cloud`, repeated as
    /// literals rather than imported: linking `HopPottyDesignTokens` into a
    /// latency-critical extension for two constants is a bad trade.
    private static let icon: UIImage = {
        let side: CGFloat = 96
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { context in
            let ctx = context.cgContext
            let hopGreen = UIColor(red: 0x63 / 255, green: 0xC8 / 255, blue: 0x8A / 255, alpha: 1)
            let cloud = UIColor(red: 1, green: 0xF9 / 255, blue: 0xF2 / 255, alpha: 1)

            ctx.setFillColor(hopGreen.cgColor)
            ctx.fillEllipse(in: CGRect(x: 4, y: 4, width: side - 8, height: side - 8))

            // Two ears and a smile: enough to read as a face at shield size, and
            // no more, because every extra path is time spent before the system's
            // patience runs out and it substitutes its own screen.
            ctx.setFillColor(cloud.cgColor)
            ctx.fillEllipse(in: CGRect(x: 26, y: 30, width: 12, height: 16))
            ctx.fillEllipse(in: CGRect(x: 58, y: 30, width: 12, height: 16))

            ctx.setStrokeColor(cloud.cgColor)
            ctx.setLineWidth(5)
            ctx.setLineCap(.round)
            ctx.addArc(
                center: CGPoint(x: side / 2, y: 52),
                radius: 16,
                startAngle: 0.15 * .pi,
                endAngle: 0.85 * .pi,
                clockwise: false
            )
            ctx.strokePath()
        }
    }()
}
