import Testing
@testable import HopPottyDesignTokens

/// Contrast is a launch requirement, not a review note. These tests fail the
/// build if a palette edit drops any text/background pairing below WCAG AA.
@Suite("Palette contrast")
struct ContrastTests {

    /// WCAG 2.1 AA for body text.
    static let normalTextMinimum = 4.5
    /// WCAG 2.1 AA for text at 24pt+, or 18.66pt+ bold.
    static let largeTextMinimum = 3.0
    /// WCAG 2.1 AA for meaningful non-text (icons, focus rings, dividers that carry meaning).
    static let nonTextMinimum = 3.0

    private func check(
        _ foreground: HopColorValue,
        on background: HopColorValue,
        atLeast minimum: Double,
        _ label: String,
        _ appearance: HopAppearance
    ) {
        let fg = foreground.composited(over: background)
        let ratio = fg.contrastRatio(against: background)
        #expect(
            ratio >= minimum,
            "\(appearance.rawValue): \(label) is \(String(format: "%.2f", ratio)):1, needs \(minimum):1 (\(fg.hexString) on \(background.hexString))"
        )
    }

    @Test("Body text meets AA on every ground in every appearance", arguments: HopAppearance.allCases)
    func bodyTextContrast(appearance: HopAppearance) {
        let p = HopSemanticPalette.resolved(for: appearance)
        let grounds: [(String, HopColorValue)] = [
            ("backgroundPrimary", p.backgroundPrimary),
            ("backgroundSecondary", p.backgroundSecondary),
            ("surface", p.surface),
            ("surfaceElevated", p.surfaceElevated),
            ("surfaceSunken", p.surfaceSunken),
        ]
        for (name, ground) in grounds {
            check(p.textPrimary, on: ground, atLeast: Self.normalTextMinimum, "textPrimary on \(name)", appearance)
            check(p.textSecondary, on: ground, atLeast: Self.normalTextMinimum, "textSecondary on \(name)", appearance)
            // Tertiary text is only ever used at large sizes or as a de-emphasised
            // label beside a primary-text value, so it is held to the large-text bar.
            check(p.textTertiary, on: ground, atLeast: Self.largeTextMinimum, "textTertiary on \(name)", appearance)
        }
    }

    @Test("Primary action label is legible on the action fill", arguments: HopAppearance.allCases)
    func actionButtonContrast(appearance: HopAppearance) {
        let p = HopSemanticPalette.resolved(for: appearance)
        check(p.textOnBrand, on: p.brandAction, atLeast: Self.normalTextMinimum, "textOnBrand on brandAction", appearance)
    }

    @Test("Status and event accents are distinguishable as non-text marks", arguments: HopAppearance.allCases)
    func accentContrast(appearance: HopAppearance) {
        let p = HopSemanticPalette.resolved(for: appearance)
        let accents: [(String, HopColorValue)] = [
            ("success", p.success), ("warning", p.warning), ("celebration", p.celebration),
            // A control that deletes a child's history has to be unmistakable
            // as a mark, not only as a word.
            ("destructive", p.destructive),
            ("eventTried", p.eventTried), ("eventPee", p.eventPee),
            ("eventPoop", p.eventPoop), ("eventAccident", p.eventAccident),
        ]
        for (name, accent) in accents {
            check(accent, on: p.surface, atLeast: Self.nonTextMinimum, "\(name) on surface", appearance)
            check(accent, on: p.backgroundPrimary, atLeast: Self.nonTextMinimum, "\(name) on backgroundPrimary", appearance)
        }
    }

    @Test("Focus ring is visible against every ground", arguments: HopAppearance.allCases)
    func focusRingContrast(appearance: HopAppearance) {
        let p = HopSemanticPalette.resolved(for: appearance)
        check(p.focusRing, on: p.backgroundPrimary, atLeast: Self.nonTextMinimum, "focusRing on backgroundPrimary", appearance)
        check(p.focusRing, on: p.surface, atLeast: Self.nonTextMinimum, "focusRing on surface", appearance)
    }

    @Test("High-contrast appearances beat their standard counterparts")
    func highContrastIsActuallyHigherContrast() {
        let pairs: [(HopAppearance, HopAppearance)] = [(.light, .lightHighContrast), (.dark, .darkHighContrast)]
        for (standard, boosted) in pairs {
            let s = HopSemanticPalette.resolved(for: standard)
            let b = HopSemanticPalette.resolved(for: boosted)
            let sRatio = s.textSecondary.contrastRatio(against: s.backgroundPrimary)
            let bRatio = b.textSecondary.contrastRatio(against: b.backgroundPrimary)
            #expect(bRatio > sRatio, "\(boosted.rawValue) secondary text (\(bRatio)) should exceed \(standard.rawValue) (\(sRatio))")
        }
    }
}

@Suite("Colour value maths")
struct HopColorValueTests {
    @Test("Hex round-trips through the string form")
    func hexRoundTrip() {
        #expect(HopColorValue(hex: 0x63C88A).hexString == "#63C88A")
        #expect(HopColorValue(hex: 0xFFF9F2).hexString == "#FFF9F2")
        #expect(HopColorValue(hex: 0x000000).hexString == "#000000")
    }

    @Test("Contrast ratio matches WCAG reference values")
    func knownContrastRatios() {
        let white = HopColorValue(hex: 0xFFFFFF)
        let black = HopColorValue(hex: 0x000000)
        #expect(abs(white.contrastRatio(against: black) - 21.0) < 0.01)
        #expect(abs(white.contrastRatio(against: white) - 1.0) < 0.01)
        // #767676 on white is the canonical 4.54:1 AA boundary case.
        #expect(abs(HopColorValue(hex: 0x767676).contrastRatio(against: white) - 4.54) < 0.02)
    }

    @Test("Contrast is symmetric")
    func contrastIsSymmetric() {
        let a = HopPalette.hopGreen
        let b = HopPalette.midnight
        #expect(abs(a.contrastRatio(against: b) - b.contrastRatio(against: a)) < 0.0001)
    }

    @Test("Compositing a translucent colour lands between the two inputs")
    func compositing() {
        let half = HopColorValue(hex: 0x000000, alpha: 0.5)
        let result = half.composited(over: HopColorValue(hex: 0xFFFFFF))
        #expect(abs(result.red - 0.5) < 0.001)
        #expect(result.alpha == 1)
    }

    @Test("Channels clamp instead of wrapping")
    func clamping() {
        let c = HopColorValue(red: 2, green: -1, blue: 0.5, alpha: 5)
        #expect(c.red == 1 && c.green == 0 && c.alpha == 1)
    }
}
