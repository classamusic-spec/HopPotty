import Foundation

/// The HopPotty brand palette.
///
/// These are raw brand hues. Views must not reference them directly — they read
/// ``HopSemanticPalette`` instead, so that light, dark and high-contrast
/// appearances can diverge without touching call sites.
public enum HopPalette {
    // MARK: Brand

    public static let hopGreen = HopColorValue(hex: 0x63C88A)
    public static let pondBlue = HopColorValue(hex: 0x6FC7E8)
    public static let sunshine = HopColorValue(hex: 0xFFD769)
    public static let peachPop = HopColorValue(hex: 0xFF9F8F)
    public static let lavender = HopColorValue(hex: 0xAFA5EF)
    public static let midnight = HopColorValue(hex: 0x243047)
    public static let cloud = HopColorValue(hex: 0xFFF9F2)

    // MARK: Derived ramps
    //
    // Hand-tuned rather than programmatically darkened: the brand hues shift hue
    // slightly as they deepen so they stay warm instead of turning muddy. Deep
    // variants exist specifically to carry text at accessible contrast.

    public static let hopGreenSoft = HopColorValue(hex: 0xE3F5EA)
    public static let hopGreenLight = HopColorValue(hex: 0x8FDCAC)
    public static let hopGreenDeep = HopColorValue(hex: 0x2F8C57)
    public static let hopGreenInk = HopColorValue(hex: 0x1B5E39)

    public static let pondBlueSoft = HopColorValue(hex: 0xE0F4FC)
    public static let pondBlueLight = HopColorValue(hex: 0x9BDCF1)
    public static let pondBlueDeep = HopColorValue(hex: 0x2A87AC)
    public static let pondBlueInk = HopColorValue(hex: 0x15566F)

    public static let sunshineSoft = HopColorValue(hex: 0xFFF3D4)
    /// Decorative only — star fills and illustration accents, always paired with
    /// a stroke or a label. Too light to carry meaning on its own; use
    /// ``sunshineDeep`` for anything a caregiver has to read.
    public static let sunshineBright = HopColorValue(hex: 0xFFC53D)
    public static let sunshineDeep = HopColorValue(hex: 0xA87A0C)
    public static let sunshineInk = HopColorValue(hex: 0x7A5A08)

    public static let peachSoft = HopColorValue(hex: 0xFFE8E3)
    public static let peachDeep = HopColorValue(hex: 0xC96755)
    public static let peachInk = HopColorValue(hex: 0x8A3F30)

    public static let lavenderSoft = HopColorValue(hex: 0xEFEDFB)
    public static let lavenderDeep = HopColorValue(hex: 0x6F63C0)
    public static let lavenderInk = HopColorValue(hex: 0x453B85)

    // MARK: Neutrals
    //
    // A warm-tinted grey ramp. Pure greys next to the warm Cloud background read
    // as dirty, so every step carries a little of the brand's warmth.

    public static let sand50 = HopColorValue(hex: 0xFFFCF8)
    public static let sand100 = HopColorValue(hex: 0xF7F1E9)
    public static let sand200 = HopColorValue(hex: 0xEBE3D8)
    public static let sand300 = HopColorValue(hex: 0xD8CEC1)
    public static let sand400 = HopColorValue(hex: 0xAFA69B)
    public static let sand500 = HopColorValue(hex: 0x7D766D)
    public static let sand600 = HopColorValue(hex: 0x5A544D)

    public static let night900 = HopColorValue(hex: 0x14192A)
    public static let night800 = HopColorValue(hex: 0x1B2337)
    public static let night700 = HopColorValue(hex: 0x243047)
    public static let night600 = HopColorValue(hex: 0x33415C)
    public static let night500 = HopColorValue(hex: 0x4C5A76)

    public static let white = HopColorValue(hex: 0xFFFFFF)
    public static let black = HopColorValue(hex: 0x000000)

    // MARK: Hop
    //
    // Hop is the brand's most important visual asset, and the owner's reference
    // drawings are flat sticker art: one green, a cream belly, and one deep
    // green outline on every boundary. These two tokens are the *same* values
    // `Scripts/hop-art.js` emits, under the same names, so the shipped SVGs, the
    // widget's head and the live SwiftUI drawing cannot describe different
    // frogs; `node Scripts/hop-lab.js --contracts` checks them.
    //
    // There is deliberately no tonal ramp here any more. Hop used to carry four
    // greens and a lighter internal rim, and every part of him is now the one
    // brand green with the outline doing all of the separating, exactly as the
    // reference does. The belly, cheeks, pupils, mouth and tongue are the
    // reference's own colours and live with the character
    // (`HopCharacterPalette`), not in the brand ramp.

    /// Hop's body — head, torso, every limb. The same value as ``hopGreen``,
    /// named for its role in the drawing rather than for the brand hue.
    public static let hopFill = hopGreen
    /// Hop's outline, on every boundary. A saturated deep green, not black:
    /// a black keyline turns a soft storybook character into a sticker sheet.
    public static let hopOutline = HopColorValue(hex: 0x1E7A32)
}
