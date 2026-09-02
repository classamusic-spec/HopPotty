import Foundation

/// Appearance variants the design system resolves against.
public enum HopAppearance: String, CaseIterable, Sendable {
    case light
    case dark
    case lightHighContrast
    case darkHighContrast

    /// Whether this appearance sits on a dark ground.
    public var isDark: Bool { self == .dark || self == .darkHighContrast }
    /// Whether the OS has asked for increased contrast.
    public var isHighContrast: Bool { self == .lightHighContrast || self == .darkHighContrast }
}

/// The semantic colour contract every HopPotty surface reads from.
///
/// Views name intent (`textSecondary`) rather than hue (`sand600`), so the same
/// view renders correctly in all four appearances with no conditional code.
public struct HopSemanticPalette: Sendable, Hashable {
    // Grounds
    public let backgroundPrimary: HopColorValue
    public let backgroundSecondary: HopColorValue
    public let surface: HopColorValue
    public let surfaceElevated: HopColorValue
    public let surfaceSunken: HopColorValue

    // Text
    public let textPrimary: HopColorValue
    public let textSecondary: HopColorValue
    public let textTertiary: HopColorValue
    public let textOnBrand: HopColorValue

    // Brand
    public let brandPrimary: HopColorValue
    public let brandSecondary: HopColorValue
    /// The fill behind `textOnBrand` on primary calls to action. Deeper than
    /// `brandPrimary`, which is a decorative hue that cannot legally carry white text.
    public let brandAction: HopColorValue

    // Status
    public let success: HopColorValue
    public let warning: HopColorValue
    public let neutral: HopColorValue
    public let celebration: HopColorValue

    // Potty event accents. Each is paired with a distinct glyph so meaning is
    // never carried by colour alone.
    public let eventTried: HopColorValue
    public let eventPee: HopColorValue
    public let eventPoop: HopColorValue
    public let eventAccident: HopColorValue

    // Structure
    public let divider: HopColorValue
    public let focusRing: HopColorValue
    public let shadow: HopColorValue
    public let scrim: HopColorValue

    public init(
        backgroundPrimary: HopColorValue,
        backgroundSecondary: HopColorValue,
        surface: HopColorValue,
        surfaceElevated: HopColorValue,
        surfaceSunken: HopColorValue,
        textPrimary: HopColorValue,
        textSecondary: HopColorValue,
        textTertiary: HopColorValue,
        textOnBrand: HopColorValue,
        brandPrimary: HopColorValue,
        brandSecondary: HopColorValue,
        brandAction: HopColorValue,
        success: HopColorValue,
        warning: HopColorValue,
        neutral: HopColorValue,
        celebration: HopColorValue,
        eventTried: HopColorValue,
        eventPee: HopColorValue,
        eventPoop: HopColorValue,
        eventAccident: HopColorValue,
        divider: HopColorValue,
        focusRing: HopColorValue,
        shadow: HopColorValue,
        scrim: HopColorValue
    ) {
        self.backgroundPrimary = backgroundPrimary
        self.backgroundSecondary = backgroundSecondary
        self.surface = surface
        self.surfaceElevated = surfaceElevated
        self.surfaceSunken = surfaceSunken
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.textTertiary = textTertiary
        self.textOnBrand = textOnBrand
        self.brandPrimary = brandPrimary
        self.brandSecondary = brandSecondary
        self.brandAction = brandAction
        self.success = success
        self.warning = warning
        self.neutral = neutral
        self.celebration = celebration
        self.eventTried = eventTried
        self.eventPee = eventPee
        self.eventPoop = eventPoop
        self.eventAccident = eventAccident
        self.divider = divider
        self.focusRing = focusRing
        self.shadow = shadow
        self.scrim = scrim
    }

    /// Resolves the palette for an appearance.
    public static func resolved(for appearance: HopAppearance) -> HopSemanticPalette {
        switch appearance {
        case .light: .light
        case .dark: .dark
        case .lightHighContrast: .lightHighContrast
        case .darkHighContrast: .darkHighContrast
        }
    }
}

public extension HopSemanticPalette {
    static let light = HopSemanticPalette(
        backgroundPrimary: HopPalette.cloud,
        backgroundSecondary: HopPalette.sand100,
        surface: HopPalette.white,
        surfaceElevated: HopPalette.white,
        surfaceSunken: HopPalette.sand100,
        textPrimary: HopPalette.night700,
        textSecondary: HopPalette.sand600,
        textTertiary: HopPalette.sand500,
        textOnBrand: HopPalette.white,
        brandPrimary: HopPalette.hopGreen,
        brandSecondary: HopPalette.pondBlue,
        // #2A7F4E measured 4.41:1 against `surfaceSunken` — the grouped
        // background every settings screen stands on — and 4.95:1 against
        // `surface`. Every green link in the app ("Settings" in a nav bar,
        // "Show all", "Add a quiet time", "Test Potty Pause") was therefore
        // *below* the 4.5:1 floor on the ground it is most often drawn on, and
        // white on it was a hair above. Darkening by one step fixes both
        // directions at once and cannot hurt anything: 5.44:1 on the sunken
        // ground, 6.10:1 on white, and 6.10:1 for white text on the filled
        // primary button. Dark appearance is unchanged.
        brandAction: HopColorValue(hex: 0x256F46),
        success: HopPalette.hopGreenDeep,
        warning: HopPalette.sunshineDeep,
        neutral: HopPalette.sand500,
        celebration: HopPalette.sunshineDeep,
        eventTried: HopPalette.lavenderDeep,
        eventPee: HopPalette.pondBlueDeep,
        eventPoop: HopPalette.peachDeep,
        eventAccident: HopPalette.sand500,
        divider: HopPalette.sand200,
        focusRing: HopColorValue(hex: 0x1C6FA8),
        shadow: HopPalette.night700.opacity(0.10),
        scrim: HopPalette.night900.opacity(0.45)
    )

    static let dark = HopSemanticPalette(
        backgroundPrimary: HopPalette.night900,
        backgroundSecondary: HopPalette.night800,
        surface: HopPalette.night800,
        surfaceElevated: HopPalette.night700,
        surfaceSunken: HopColorValue(hex: 0x0E1220),
        textPrimary: HopColorValue(hex: 0xF3F1ED),
        textSecondary: HopColorValue(hex: 0xB4BCCB),
        textTertiary: HopColorValue(hex: 0x8B94A6),
        textOnBrand: HopPalette.night900,
        brandPrimary: HopPalette.hopGreenLight,
        brandSecondary: HopPalette.pondBlueLight,
        brandAction: HopPalette.hopGreenLight,
        success: HopPalette.hopGreenLight,
        warning: HopPalette.sunshine,
        neutral: HopColorValue(hex: 0x8B94A6),
        celebration: HopPalette.sunshine,
        eventTried: HopColorValue(hex: 0xC3BAFA),
        eventPee: HopPalette.pondBlueLight,
        eventPoop: HopColorValue(hex: 0xFFB3A3),
        eventAccident: HopColorValue(hex: 0x9AA3B4),
        divider: HopColorValue(hex: 0x33415C),
        focusRing: HopColorValue(hex: 0x7CC4F0),
        shadow: HopPalette.black.opacity(0.45),
        scrim: HopPalette.black.opacity(0.60)
    )

    /// Increased-contrast light appearance. Text darkens, dividers strengthen,
    /// decorative tints stay put so the brand does not visually collapse.
    static let lightHighContrast = HopSemanticPalette(
        backgroundPrimary: HopPalette.white,
        backgroundSecondary: HopPalette.sand50,
        surface: HopPalette.white,
        surfaceElevated: HopPalette.white,
        surfaceSunken: HopPalette.sand100,
        textPrimary: HopPalette.night900,
        textSecondary: HopColorValue(hex: 0x413B34),
        textTertiary: HopColorValue(hex: 0x4F4840),
        textOnBrand: HopPalette.white,
        brandPrimary: HopPalette.hopGreenDeep,
        brandSecondary: HopPalette.pondBlueDeep,
        brandAction: HopPalette.hopGreenInk,
        success: HopPalette.hopGreenInk,
        warning: HopPalette.sunshineInk,
        neutral: HopPalette.sand600,
        celebration: HopPalette.sunshineInk,
        eventTried: HopPalette.lavenderInk,
        eventPee: HopPalette.pondBlueInk,
        eventPoop: HopPalette.peachInk,
        eventAccident: HopPalette.sand600,
        divider: HopPalette.sand400,
        focusRing: HopColorValue(hex: 0x0B4E7C),
        shadow: HopPalette.night900.opacity(0.20),
        scrim: HopPalette.night900.opacity(0.60)
    )

    static let darkHighContrast = HopSemanticPalette(
        backgroundPrimary: HopPalette.black,
        backgroundSecondary: HopColorValue(hex: 0x0E1220),
        surface: HopColorValue(hex: 0x11172A),
        surfaceElevated: HopPalette.night800,
        surfaceSunken: HopPalette.black,
        textPrimary: HopPalette.white,
        textSecondary: HopColorValue(hex: 0xD7DDE8),
        textTertiary: HopColorValue(hex: 0xB4BCCB),
        textOnBrand: HopPalette.black,
        brandPrimary: HopColorValue(hex: 0xA8E8C2),
        brandSecondary: HopColorValue(hex: 0xB0E4F7),
        brandAction: HopColorValue(hex: 0xA8E8C2),
        success: HopColorValue(hex: 0xA8E8C2),
        warning: HopColorValue(hex: 0xFFE49A),
        neutral: HopColorValue(hex: 0xB4BCCB),
        celebration: HopColorValue(hex: 0xFFE49A),
        eventTried: HopColorValue(hex: 0xD5CFFF),
        eventPee: HopColorValue(hex: 0xB0E4F7),
        eventPoop: HopColorValue(hex: 0xFFC8BB),
        eventAccident: HopColorValue(hex: 0xC3CAD8),
        divider: HopColorValue(hex: 0x5A6780),
        focusRing: HopColorValue(hex: 0xA5D8F7),
        shadow: HopPalette.black.opacity(0.70),
        scrim: HopPalette.black.opacity(0.75)
    )
}
