import Foundation
import SwiftUI
import HopPottyCore

// Resolving `HopCopy` entries into strings a view can draw.
//
// `Docs/CONTRACTS.md` §5: no string literals in views. Every parent-facing
// string in `Features/` comes through here, which is what keeps the copy
// catalog the single place a wording change happens.
//
// `NSLocalizedString(_:value:)` rather than `LocalizedStringResource` on
// purpose. The `value:` parameter is an authored fallback: before the String
// Catalog is generated the app renders the English that lives beside the key in
// `HopCopy`, instead of rendering the key itself. A screenshot that says
// "settings.title" is a bug nobody notices until review.

public extension HopCopyEntry {
    /// The localized string, falling back to the English authored in `HopCopy`.
    var localized: String {
        NSLocalizedString(
            localizationKey,
            tableName: nil,
            bundle: .main,
            value: value,
            comment: comment ?? ""
        )
    }

    /// The localized format with its documented slots filled, in order.
    ///
    /// Substitution runs on the *localized* format, so a translation that
    /// reorders `%1$@` and `%2$@` is honoured.
    func localized(_ arguments: HopCopyArgument...) -> String {
        localized(arguments)
    }

    func localized(_ arguments: [HopCopyArgument]) -> String {
        var values: [Int: String] = [:]
        for (offset, argument) in arguments.enumerated() {
            values[offset + 1] = argument.stringValue
        }
        return HopCopyFormat.filling(localized, with: values)
    }

    /// Fills slots by explicit position, for strings where the caller supplies
    /// some arguments and the variant supplies others.
    func localized(filling values: [Int: HopCopyArgument]) -> String {
        HopCopyFormat.filling(localized, with: values.mapValues(\.stringValue))
    }
}

public extension HopNameVariants {
    /// Picks the named or nameless sentence, then localizes it.
    ///
    /// The nickname runs through `ChildProfile.sanitize` inside `entry(forNickname:)`,
    /// so `"  "` takes the nameless path rather than producing "Hi,  !".
    func localized(forNickname nickname: String?, additional: [Int: HopCopyArgument] = [:]) -> String {
        let entry = entry(forNickname: nickname)
        var values = additional
        if let name = ChildProfile.sanitize(nickname) {
            values[1] = .text(name)
        }
        return entry.localized(filling: values)
    }

    func localized(for child: ChildProfile?, additional: [Int: HopCopyArgument] = [:]) -> String {
        localized(forNickname: child?.nickname, additional: additional)
    }
}

public extension HopPluralVariants {
    /// Renders the plural form for `count`, with the count in its documented
    /// position.
    func localized(for count: Int, additional: [Int: HopCopyArgument] = [:]) -> String {
        let entry = entry(for: count)
        var values = additional
        for placeholder in entry.placeholders where placeholder.kind == .count {
            values[placeholder.position] = .count(count)
        }
        return entry.localized(filling: values)
    }
}

// MARK: - SwiftUI sugar

public extension Text {
    /// `Text(hop: HopCopy.settings.title)`.
    init(hop entry: HopCopyEntry) {
        self.init(verbatim: entry.localized)
    }

    init(hop entry: HopCopyEntry, _ arguments: HopCopyArgument...) {
        self.init(verbatim: entry.localized(arguments))
    }
}

public extension Label where Title == Text, Icon == Image {
    init(hop entry: HopCopyEntry, systemImage: String) {
        self.init {
            Text(verbatim: entry.localized)
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

public extension View {
    /// Accessibility label from a copy entry, so VoiceOver strings are
    /// catalogued like every other string.
    func hopAccessibilityLabel(_ entry: HopCopyEntry) -> some View {
        accessibilityLabel(Text(verbatim: entry.localized))
    }
}
