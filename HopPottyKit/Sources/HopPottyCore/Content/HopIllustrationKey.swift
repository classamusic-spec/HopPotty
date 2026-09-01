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
}
