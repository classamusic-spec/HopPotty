import Foundation

// MARK: - Audience

/// Who a piece of copy is written for.
///
/// This is not a styling hint — it selects which safety rules apply. Child copy
/// is scanned for shame language and held to a pre-reader length ceiling; the
/// whole catalog is scanned for medical framing. A string that appears on a
/// child's screen but is written for the caregiver reading over their shoulder
/// is `.parent`: the audience is who the *words* are for, not who is looking.
public enum HopCopyAudience: String, CaseIterable, Sendable, Codable {
    case child
    case parent
}

// MARK: - Surface

/// The part of the product a string belongs to.
///
/// The raw value is also the first segment of every key on that surface, which
/// is what lets a test prove that no entry has drifted into the wrong section
/// and what lets a translator see the context of a string from its key alone.
public enum HopCopySurface: String, CaseIterable, Sendable {
    /// Product name and tagline. Fixed wording; translators localise the tagline
    /// only where a market requires it.
    case brand
    /// Buttons and words that appear on more than one surface. Kept in one place
    /// so "Done" is translated once and stays consistent.
    case common
    case onboarding
    case parentHome
    case timerSettings
    /// The Screen Time shield: the only HopPotty surface rendered by an app
    /// extension, so its copy has to stand alone with no app context.
    case shield
    /// Local notification titles and bodies.
    case notification
    /// The guided potty routine. Populated by `PottyRoutineContent`.
    case routine
    case celebration
    case pond
    /// Mini-games. Populated by `MiniGameCatalog`.
    case games
    /// Hop's questions. Populated by `QuizContent`.
    case quizzes
    case settings
    case errors
    case parentGate
    case purchase
    /// VoiceOver labels for surfaces that are mostly illustration. These are
    /// user-visible strings like any other and are translated like any other.
    case a11y

    /// The key prefix every entry on this surface carries, including the dot.
    public var keyPrefix: String { rawValue + "." }
}

// MARK: - Keys

/// Rules for copy keys.
///
/// Keys are dot-separated so the catalog can be lifted into an Apple String
/// Catalog (`Localizable.xcstrings`) without renaming anything: the app layer
/// writes `LocalizedStringResource(entry.localizationKey)` and Xcode groups the
/// strings by the same hierarchy shown here.
public enum HopCopyKey {
    /// A segment is lowerCamelCase: it starts with a lowercase letter and
    /// continues with letters or digits. No underscores, no spaces, no dashes —
    /// those are the characters that break `.strings` tooling and shell scripts
    /// that grep for keys.
    public static func isWellFormedSegment(_ segment: String) -> Bool {
        guard let first = segment.unicodeScalars.first else { return false }
        guard ("a"..."z").contains(String(first)) else { return false }
        return segment.unicodeScalars.allSatisfy { scalar in
            CharacterSet.alphanumerics.contains(scalar) && scalar.isASCII
        }
    }

    /// A key is two or more well-formed segments joined by dots. Two segments is
    /// the floor because a bare `title` says nothing at a translation desk.
    public static func isWellFormed(_ key: String) -> Bool {
        let segments = key.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard segments.count >= 2 else { return false }
        return segments.allSatisfy(isWellFormedSegment)
    }

    /// The surface a key claims to belong to, or `nil` if its first segment is
    /// not a known surface.
    public static func surface(of key: String) -> HopCopySurface? {
        guard let first = key.split(separator: ".").first else { return nil }
        return HopCopySurface(rawValue: String(first))
    }
}

// MARK: - Placeholders

/// The conversion a placeholder uses in the format string.
///
/// Only two exist on purpose. Anything with a locale-sensitive shape — a
/// duration, a time of day, a price — is formatted by the caller and passed in
/// as `.text`, because `DateComponentsFormatter` and friends know things a
/// format string does not.
public enum HopCopyPlaceholderKind: String, Hashable, Sendable {
    /// `%N$@` — an already-formatted string.
    case text
    /// `%N$lld` — an integer the string catalog can pluralise on.
    case count

    public var conversion: String {
        switch self {
        case .text: "@"
        case .count: "lld"
        }
    }
}

/// One documented slot in a format string.
///
/// Every interpolated string in HopPotty declares its slots. A translator who
/// only sees `%1$@ has %2$lld stars` cannot know whether slot 1 is a name or a
/// date, and languages that reorder arguments need to know before they can move
/// them. Positions are explicit (`%1$@`, never `%@`) for the same reason.
public struct HopCopyPlaceholder: Hashable, Sendable {
    /// 1-based, matching the number in `%1$@`.
    public let position: Int
    /// A short name used in documentation and tests, e.g. `nickname`.
    public let name: String
    public let kind: HopCopyPlaceholderKind
    /// What the value means, in a sentence a translator can act on.
    public let describes: String
    /// A realistic value, so a translator can read the sentence filled in.
    public let example: String

    public init(position: Int, name: String, kind: HopCopyPlaceholderKind, describes: String, example: String) {
        self.position = position
        self.name = name
        self.kind = kind
        self.describes = describes
        self.example = example
    }

    /// The exact token expected in the format string.
    public var token: String { "%\(position)$\(kind.conversion)" }

    /// The child's nickname. Always position 1 where it appears, so the "named"
    /// and "unnamed" halves of a `HopNameVariants` pair never disagree about
    /// which argument the caller passes first.
    public static func nickname(_ position: Int = 1) -> HopCopyPlaceholder {
        HopCopyPlaceholder(
            position: position,
            name: "nickname",
            kind: .text,
            describes: "The child's nickname, exactly as the caregiver typed it.",
            example: "Maya"
        )
    }

    public static func count(
        _ position: Int,
        _ name: String,
        _ describes: String,
        example: String = "3"
    ) -> HopCopyPlaceholder {
        HopCopyPlaceholder(position: position, name: name, kind: .count, describes: describes, example: example)
    }

    public static func text(
        _ position: Int,
        _ name: String,
        _ describes: String,
        example: String
    ) -> HopCopyPlaceholder {
        HopCopyPlaceholder(position: position, name: name, kind: .text, describes: describes, example: example)
    }
}

// MARK: - Format parsing and filling

/// Minimal reader for the `%N$@` / `%N$lld` subset HopPotty allows.
///
/// This exists so a test can prove that every slot in a format string is
/// documented and every documented slot is actually used. It is deliberately
/// strict: an undocumented `%@` with no position is not recognised as a token,
/// which makes it fail the "declared placeholders match the format" test rather
/// than pass silently.
public enum HopCopyFormat {
    public struct Token: Hashable, Sendable {
        public let position: Int
        public let conversion: String
        public var raw: String { "%\(position)$\(conversion)" }
    }

    public static func tokens(in format: String) -> [Token] {
        var tokens: [Token] = []
        let characters = Array(format)
        var index = 0
        while index < characters.count {
            guard characters[index] == "%" else {
                index += 1
                continue
            }
            var cursor = index + 1
            // "%%" is a literal percent sign and carries no argument.
            if cursor < characters.count, characters[cursor] == "%" {
                index = cursor + 1
                continue
            }
            var digits = ""
            while cursor < characters.count, characters[cursor].isNumber {
                digits.append(characters[cursor])
                cursor += 1
            }
            guard !digits.isEmpty, cursor < characters.count, characters[cursor] == "$", let position = Int(digits) else {
                index += 1
                continue
            }
            cursor += 1
            let remainder = String(characters[cursor...])
            if remainder.hasPrefix("@") {
                tokens.append(Token(position: position, conversion: "@"))
                index = cursor + 1
            } else if remainder.hasPrefix("lld") {
                tokens.append(Token(position: position, conversion: "lld"))
                index = cursor + 3
            } else {
                index = cursor
            }
        }
        return tokens
    }

    /// Substitutes documented tokens by position.
    ///
    /// A token with no supplied value is left in place rather than replaced with
    /// an empty string: a visible `%2$@` in a screenshot is a bug report, an
    /// invisible gap is a mystery. On Apple platforms the app layer resolves the
    /// same keys through the String Catalog; this exists for previews, tests,
    /// the fixtures module and the app extensions.
    public static func filling(_ format: String, with values: [Int: String]) -> String {
        var result = format
        // Longest position first so "%10$@" is not clipped by the "%1$@" pass.
        for (position, value) in values.sorted(by: { $0.key > $1.key }) {
            for conversion in ["@", "lld"] {
                result = result.replacingOccurrences(of: "%\(position)$\(conversion)", with: value)
            }
        }
        return result
    }
}

/// A value substituted into a format string.
public enum HopCopyArgument: Hashable, Sendable {
    case text(String)
    case count(Int)

    public var stringValue: String {
        switch self {
        case .text(let value): value
        case .count(let value): String(value)
        }
    }
}

// MARK: - Entry

/// One user-visible string.
///
/// The English value lives beside the key so the catalog is readable as prose
/// and reviewable as a diff. Translation replaces the value, never the key.
public struct HopCopyEntry: Identifiable, Hashable, Sendable {
    /// Dot-separated, stable forever. Renaming a key is a breaking change for
    /// every translation that already exists.
    public let key: String
    /// The English string, or the English format string.
    public let value: String
    public let audience: HopCopyAudience
    /// A note for whoever translates this. Required wherever the string is
    /// ambiguous out of context — an isolated "Try" could be a verb or a noun.
    public let comment: String?
    /// Documentation for every slot in `value`. Empty for plain strings.
    public let placeholders: [HopCopyPlaceholder]

    public init(
        key: String,
        value: String,
        audience: HopCopyAudience,
        comment: String? = nil,
        placeholders: [HopCopyPlaceholder] = []
    ) {
        self.key = key
        self.value = value
        self.audience = audience
        self.comment = comment
        self.placeholders = placeholders
    }

    public var id: String { key }

    /// The key as handed to `LocalizedStringResource` in the app layer. Identical
    /// to `key`; named separately so the call site reads as an intention.
    public var localizationKey: String { key }

    /// The surface this key claims, derived from the key rather than stored, so
    /// the two can never disagree.
    public var surface: HopCopySurface? { HopCopyKey.surface(of: key) }

    public var isFormat: Bool { !placeholders.isEmpty }

    /// Fills documented slots by position, in the order given.
    public func formatted(_ arguments: HopCopyArgument...) -> String {
        formatted(arguments)
    }

    public func formatted(_ arguments: [HopCopyArgument]) -> String {
        var values: [Int: String] = [:]
        for (offset, argument) in arguments.enumerated() {
            values[offset + 1] = argument.stringValue
        }
        return HopCopyFormat.filling(value, with: values)
    }

    /// Fills documented slots by explicit position, for strings where the caller
    /// has some values but not others (a plural variant supplies its own count).
    public func filled(_ values: [Int: HopCopyArgument]) -> String {
        HopCopyFormat.filling(value, with: values.mapValues(\.stringValue))
    }

    /// The string with every documented slot replaced by its example value.
    /// Used by previews and by the length test, which has to measure what a
    /// child actually sees rather than the raw `%1$@`.
    public var exampleRendering: String {
        var values: [Int: String] = [:]
        for placeholder in placeholders {
            values[placeholder.position] = placeholder.example
        }
        return HopCopyFormat.filling(value, with: values)
    }
}

public extension HopCopyEntry {
    /// Shorthand for a child-facing string.
    static func child(
        _ key: String,
        _ value: String,
        comment: String? = nil,
        placeholders: [HopCopyPlaceholder] = []
    ) -> HopCopyEntry {
        HopCopyEntry(key: key, value: value, audience: .child, comment: comment, placeholders: placeholders)
    }

    /// Shorthand for a caregiver-facing string.
    static func parent(
        _ key: String,
        _ value: String,
        comment: String? = nil,
        placeholders: [HopCopyPlaceholder] = []
    ) -> HopCopyEntry {
        HopCopyEntry(key: key, value: value, audience: .parent, comment: comment, placeholders: placeholders)
    }
}

// MARK: - Nickname variants

/// A pair of strings for the same idea, one that names the child and one that
/// does not.
///
/// A nickname is optional in HopPotty, so every sentence that could carry a name
/// exists twice. The alternative — interpolating an empty string — produces
/// "'s pond" and " earned a star!", which is exactly the kind of defect that
/// ships because nobody tested the empty case. Modelling it as two authored
/// sentences also lets a translator write the nameless form idiomatically
/// instead of surgically removing a possessive.
public struct HopNameVariants: Hashable, Sendable {
    /// Names the child. Carries the nickname placeholder at position 1.
    public let named: HopCopyEntry
    /// Says the same thing without a name. Carries no nickname placeholder.
    public let unnamed: HopCopyEntry

    public init(named: HopCopyEntry, unnamed: HopCopyEntry) {
        self.named = named
        self.unnamed = unnamed
    }

    public var entries: [HopCopyEntry] { [named, unnamed] }

    /// The shared part of both keys, e.g. `pond.title` for `pond.title.named`.
    public var baseKey: String {
        String(named.key.dropLast(".named".count))
    }

    /// Picks the variant, running the nickname through the same sanitiser the
    /// profile uses so a nickname of `"   "` takes the nameless path.
    public func entry(forNickname nickname: String?) -> HopCopyEntry {
        ChildProfile.sanitize(nickname) == nil ? unnamed : named
    }

    public func resolved(forNickname nickname: String?, additional: [Int: HopCopyArgument] = [:]) -> String {
        guard let name = ChildProfile.sanitize(nickname) else {
            return unnamed.filled(additional)
        }
        var values = additional
        values[1] = .text(name)
        return named.filled(values)
    }

    public func resolved(for child: ChildProfile, additional: [Int: HopCopyArgument] = [:]) -> String {
        resolved(forNickname: child.nickname, additional: additional)
    }
}

// MARK: - Plural variants

/// The plural forms of one sentence.
///
/// English needs two forms and sometimes a nicer zero; other languages need up
/// to six. Authoring the forms as separate entries — rather than assembling
/// "%lld star" + "s" — is what lets Apple's String Catalog carry a full CLDR
/// plural rule set for every language without the app changing.
///
/// Placeholder positions are shared across the forms: if the count is `%1$lld`
/// in `other`, then `one` either uses `%1$lld` or spells the number out, and any
/// second argument stays at position 2 in both. Callers pass the same arguments
/// whichever form is chosen.
public struct HopPluralVariants: Hashable, Sendable {
    /// A distinct sentence for zero, where "0 potty visits" reads badly.
    public let zero: HopCopyEntry?
    public let one: HopCopyEntry
    public let other: HopCopyEntry

    public init(zero: HopCopyEntry? = nil, one: HopCopyEntry, other: HopCopyEntry) {
        self.zero = zero
        self.one = one
        self.other = other
    }

    public var entries: [HopCopyEntry] {
        var all = [one, other]
        if let zero { all.append(zero) }
        return all
    }

    /// The shared part of the keys, e.g. `pond.starCount`.
    public var baseKey: String {
        String(one.key.dropLast(".one".count))
    }

    public func entry(for count: Int) -> HopCopyEntry {
        if count == 0, let zero { return zero }
        return count == 1 ? one : other
    }

    /// Renders the right form with the count in its documented position.
    /// `additional` supplies any other slots, keyed by position.
    public func resolved(for count: Int, additional: [Int: HopCopyArgument] = [:]) -> String {
        let entry = entry(for: count)
        var values = additional
        for placeholder in entry.placeholders where placeholder.kind == .count {
            values[placeholder.position] = .count(count)
        }
        return entry.filled(values)
    }
}

// MARK: - Sections

/// A named group of copy belonging to one surface.
///
/// Sections are structs with stored properties rather than enums with statics so
/// that `Mirror` can enumerate them. That is not a stylistic choice: it means
/// `HopCopy.allEntries` is *derived* from the declarations, and a string cannot
/// be added to the app while being invisible to the child-safety tests. A
/// hand-maintained array would eventually miss one, and the one it missed would
/// be the one that mattered.
public protocol HopCopySection: Sendable {
    static var surface: HopCopySurface { get }
    var entries: [HopCopyEntry] { get }
}

public extension HopCopySection {
    var entries: [HopCopyEntry] { HopCopyReflection.entries(in: self) }
}

/// Walks a section's stored properties and collects the strings in it.
///
/// Reflection is the point: it makes the catalog self-describing, so the tests
/// see exactly what the app sees and a newly declared string is covered by them
/// the moment it is typed.
public enum HopCopyReflection {
    public static func entries(in section: Any) -> [HopCopyEntry] {
        Mirror(reflecting: section).children.flatMap { child -> [HopCopyEntry] in
            switch child.value {
            case let entry as HopCopyEntry: [entry]
            case let variants as HopNameVariants: variants.entries
            case let variants as HopPluralVariants: variants.entries
            case let list as [HopCopyEntry]: list
            case let nested as any HopCopySection: nested.entries
            default: []
            }
        }
    }

    /// Every name-variant pair declared in a section, so the nickname-optional
    /// rule can be checked pair by pair rather than string by string.
    public static func nameVariants(in section: Any) -> [HopNameVariants] {
        Mirror(reflecting: section).children.compactMap { $0.value as? HopNameVariants }
    }

    /// Every plural group declared in a section.
    public static func pluralVariants(in section: Any) -> [HopPluralVariants] {
        Mirror(reflecting: section).children.compactMap { $0.value as? HopPluralVariants }
    }
}
