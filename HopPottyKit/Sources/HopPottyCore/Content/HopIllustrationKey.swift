import Foundation

/// A stable name for a drawing.
///
/// Content refers to art by key, never by file name. The art pipeline in `Art/`
/// exports whatever raster and vector variants a platform needs; the content
/// layer only promises that a key exists and that nothing else claims it. That
/// separation is what lets a quiz answer be "the picture of a towel" in code
/// while the towel is redrawn three times before launch.
///
/// Keys follow the same dot-separated, lowerCamelCase scheme as copy keys, with
/// a first segment naming the art family so the exporter can route them:
/// `scene.` for full illustrations, `icon.` for small symbols, `character.` for
/// Hop's poses, `pond.` for pond decorations.
public struct HopIllustrationKey: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: StringLiteralType) { self.rawValue = value }
    public var description: String { rawValue }

    /// The art family, i.e. the first segment.
    public var family: String {
        String(rawValue.split(separator: ".").first ?? "")
    }

    public var isWellFormed: Bool {
        HopCopyKey.isWellFormed(rawValue) && HopIllustrationKey.families.contains(family)
    }

    /// Every family the exporter knows how to route. A key in an unknown family
    /// is a typo, and the content test says so.
    public static let families: Set<String> = ["scene", "icon", "character", "pond"]

    /// The exported asset name for this key.
    ///
    /// The rule is mechanical so nobody has to maintain a lookup table: drop the
    /// family segment, join what remains with hyphens. `icon.quiz.washHands`
    /// becomes `quiz-washHands`, which is the basename of both the source SVG in
    /// `Art/icons/` and the asset-catalog entry the app loads.
    ///
    /// Case is preserved deliberately. Lowercasing would collapse
    /// `quiz.toiletPaper` and a hypothetical `quiz.toilet.paper` onto the same
    /// file, and asset catalogs are case-sensitive on the platforms that matter.
    public var assetName: String {
        rawValue.split(separator: ".").dropFirst().joined(separator: "-")
    }

    /// Art that more than one surface draws, and that therefore belongs to no
    /// single one of them.
    ///
    /// A mini-game's `sprites` cannot hold these: the catalog requires a
    /// sprite to be keyed under `icon.games.` and forbids two games from
    /// claiming the same key, and both rules are right — a sprite list says
    /// *this game's* art. The child's hands are drawn by Bubble Wash and by
    /// Mud Off, so they are declared here instead, which is also what
    /// `Scripts/check-art.sh` reads to know they must exist.
    public static let shared: [HopIllustrationKey] = [
        // `Art/source/wash-hands.svg`, split and recoloured by
        // `Scripts/hop-art.js`. A genuine left and right, not one mirrored.
        "icon.wash.handLeft",
        "icon.wash.handRight",
    ]

    /// The directory under `Art/` that holds this key's source drawing.
    public var artDirectory: String {
        switch family {
        case "scene": "scenes"
        case "icon": "icons"
        case "character": "character"
        case "pond": "pond"
        default: "unknown"
        }
    }
}
