import Foundation
import HopPottyDesignTokens

// Exports the design tokens as JSON so non-Swift tooling — the screen render
// harness, the art pipeline, documentation — reads the same values the app
// compiles against. Anything that consumes this cannot drift from the source of
// truth, because there is only one source of truth.

struct TokenExport: Encodable {
    var appearances: [String: [String: String]]
    var spacing: [String: Double]
    var radius: [String: Double]
    var hitTarget: [String: Double]
    var typography: [String: TypeStyleExport]
    var motion: [String: MotionExport]
    var palette: [String: String]
}

struct TypeStyleExport: Encodable {
    var family: String
    var size: Double
    var weight: String
    var lineHeight: Double
    var tracking: Double
    var scales: Bool
}

struct MotionExport: Encodable {
    var duration: Double
    var bounce: Double
}

func colors(_ p: HopSemanticPalette) -> [String: String] {
    [
        "backgroundPrimary": p.backgroundPrimary.hexString,
        "backgroundSecondary": p.backgroundSecondary.hexString,
        "surface": p.surface.hexString,
        "surfaceElevated": p.surfaceElevated.hexString,
        "surfaceSunken": p.surfaceSunken.hexString,
        "textPrimary": p.textPrimary.hexString,
        "textSecondary": p.textSecondary.hexString,
        "textTertiary": p.textTertiary.hexString,
        "textOnBrand": p.textOnBrand.hexString,
        "brandPrimary": p.brandPrimary.hexString,
        "brandSecondary": p.brandSecondary.hexString,
        "brandAction": p.brandAction.hexString,
        "success": p.success.hexString,
        "warning": p.warning.hexString,
        "neutral": p.neutral.hexString,
        "celebration": p.celebration.hexString,
        "eventTried": p.eventTried.hexString,
        "eventPee": p.eventPee.hexString,
        "eventPoop": p.eventPoop.hexString,
        "eventAccident": p.eventAccident.hexString,
        "divider": p.divider.hexString,
        "focusRing": p.focusRing.hexString,
        "shadow": p.shadow.hexString,
        "scrim": p.scrim.hexString,
    ]
}

let export = TokenExport(
    appearances: Dictionary(uniqueKeysWithValues: HopAppearance.allCases.map {
        ($0.rawValue, colors(HopSemanticPalette.resolved(for: $0)))
    }),
    spacing: [
        "xxs": HopSpacing.xxs, "xs": HopSpacing.xs, "s": HopSpacing.s, "m": HopSpacing.m,
        "l": HopSpacing.l, "xl": HopSpacing.xl, "xxl": HopSpacing.xxl, "xxxl": HopSpacing.xxxl,
        "huge": HopSpacing.huge, "giant": HopSpacing.giant,
        "pageCompact": HopSpacing.pageCompact, "pageRegular": HopSpacing.pageRegular,
    ],
    radius: [
        "xs": HopRadius.xs, "s": HopRadius.s, "m": HopRadius.m, "l": HopRadius.l,
        "xl": HopRadius.xl, "xxl": HopRadius.xxl, "hero": HopRadius.hero,
    ],
    hitTarget: [
        "parentMinimum": HopHitTarget.parentMinimum,
        "childMinimum": HopHitTarget.childMinimum,
        "childPrimary": HopHitTarget.childPrimary,
    ],
    typography: Dictionary(uniqueKeysWithValues: HopTypography.all.map {
        ($0.name, TypeStyleExport(
            family: $0.family.rawValue, size: $0.size, weight: $0.weight.rawValue,
            lineHeight: $0.lineHeightMultiple, tracking: $0.tracking,
            scales: $0.scalesWithDynamicType
        ))
    }),
    motion: [
        "parentTap": MotionExport(duration: HopMotion.parentTap.duration, bounce: HopMotion.parentTap.bounce),
        "parentTransition": MotionExport(duration: HopMotion.parentTransition.duration, bounce: HopMotion.parentTransition.bounce),
        "childTap": MotionExport(duration: HopMotion.childTap.duration, bounce: HopMotion.childTap.bounce),
        "childArrive": MotionExport(duration: HopMotion.childArrive.duration, bounce: HopMotion.childArrive.bounce),
        "childCelebrate": MotionExport(duration: HopMotion.childCelebrate.duration, bounce: HopMotion.childCelebrate.bounce),
    ],
    palette: [
        "hopGreen": HopPalette.hopGreen.hexString,
        "hopGreenSoft": HopPalette.hopGreenSoft.hexString,
        "hopGreenLight": HopPalette.hopGreenLight.hexString,
        "hopGreenDeep": HopPalette.hopGreenDeep.hexString,
        "hopGreenInk": HopPalette.hopGreenInk.hexString,
        "pondBlue": HopPalette.pondBlue.hexString,
        "pondBlueSoft": HopPalette.pondBlueSoft.hexString,
        "pondBlueLight": HopPalette.pondBlueLight.hexString,
        "pondBlueDeep": HopPalette.pondBlueDeep.hexString,
        "sunshine": HopPalette.sunshine.hexString,
        "sunshineSoft": HopPalette.sunshineSoft.hexString,
        "sunshineBright": HopPalette.sunshineBright.hexString,
        "sunshineDeep": HopPalette.sunshineDeep.hexString,
        "peachPop": HopPalette.peachPop.hexString,
        "peachSoft": HopPalette.peachSoft.hexString,
        "peachDeep": HopPalette.peachDeep.hexString,
        "lavender": HopPalette.lavender.hexString,
        "lavenderSoft": HopPalette.lavenderSoft.hexString,
        "lavenderDeep": HopPalette.lavenderDeep.hexString,
        "midnight": HopPalette.midnight.hexString,
        "cloud": HopPalette.cloud.hexString,
        "sand100": HopPalette.sand100.hexString,
        "sand200": HopPalette.sand200.hexString,
        "sand300": HopPalette.sand300.hexString,
        "sand500": HopPalette.sand500.hexString,
        "sand600": HopPalette.sand600.hexString,
    ]
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
FileHandle.standardOutput.write(try encoder.encode(export))
