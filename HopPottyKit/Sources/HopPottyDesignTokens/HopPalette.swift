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
    // Hop is the brand's most important visual asset, and the thing that decides
    // whether he reads is not his hue — it is whether one part of him can be
    // told from another. These are the tokens that answer that, and they are the
    // *same* values `Scripts/hop-art.js` emits, under the same names, so the
    // shipped SVGs and the live SwiftUI drawing cannot describe different frogs.
    //
    // They are separation tokens, not decoration. Three levels do the work
    // together and no one of them is allowed to carry it alone:
    //
    //  1. the exterior silhouette, in ``hopOutline``, so Hop holds his shape on
    //     cream, pond blue, vegetation green, white and night;
    //  2. internal overlap separation, the same colour at ``hopOutlineSoft`` or
    //     ``hopOutlineSubtle``, only where similarly coloured parts cross;
    //  3. tonal separation, the four fills below, assigned by depth — which is
    //     what keeps the character readable when the outline is turned down.
    //
    // ``hopOutline`` is deliberately a dark *green*, not black or grey: a black
    // keyline turns a soft storybook character into a sticker.

    /// Front surfaces — Hop's head and torso. The same value as ``hopGreen``,
    /// named for its role in the drawing rather than for the brand hue.
    public static let hopFill = hopGreen
    /// A limb crossing in front of the body. One step up, so the nearer thing is
    /// the lit one; the old `hopGreenLight` was so far up that a hand in front of
    /// the tummy read as a reflection rather than as a hand.
    public static let hopFillHighlight = HopColorValue(hex: 0x71D397)
    /// Arms and hands at rest, and the top of a foot. One step back from the head.
    public static let hopFillShadow = HopColorValue(hex: 0x52B77A)
    /// Legs, and the forehead spots and toe creases. The deepest body value.
    public static let hopFillDeep = HopColorValue(hex: 0x45A971)

    /// Hop's structural outline.
    public static let hopOutline = HopColorValue(hex: 0x356B50)
    /// The outline where two similarly coloured parts overlap: lighter and
    /// thinner than the exterior edge, because an internal boundary as strong as
    /// the outside one reads as a cut-out rather than as an arm in front.
    public static let hopOutlineSoft = hopOutline.opacity(0.62)
    /// The faintest separation the system uses.
    public static let hopOutlineSubtle = hopOutline.opacity(0.38)
}
