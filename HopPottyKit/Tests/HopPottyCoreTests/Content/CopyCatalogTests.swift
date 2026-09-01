import Foundation
import Testing
@testable import HopPottyCore

/// Structural guarantees for the copy catalog.
///
/// These are the failures that do not look like failures: a duplicated key that
/// makes one screen quietly show another screen's sentence, a format string with
/// an argument nobody documented, a nickname variant that renders "'s pond" for
/// a family who never typed a name. None of them crash. All of them ship.
@Suite("Copy catalog structure")
struct CopyCatalogTests {

    // MARK: - Keys

    /// A duplicate key means one string silently shadows another: the String
    /// Catalog keeps one value, and which one depends on merge order.
    @Test("Every copy key is unique")
    func everyKeyIsUnique() {
        let duplicates = HopCopy.duplicateKeys
        #expect(duplicates.isEmpty, "duplicated keys: \(duplicates.joined(separator: ", "))")
    }

    /// The naming scheme, re-implemented here rather than borrowed from
    /// `HopCopyKey`, so relaxing the production rule cannot quietly relax the
    /// test: two or more dot-separated segments, each starting with a lowercase
    /// ASCII letter and continuing with ASCII letters or digits.
    static func isDottedKey(_ key: String) -> Bool {
        let segments = key.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else { return false }
        return segments.allSatisfy { segment in
            guard let first = segment.first, first.isASCII, first.isLetter, first.isLowercase else { return false }
            return segment.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
        }
    }

    @Test("Every key follows the dot-separated naming scheme")
    func everyKeyFollowsTheScheme() {
        for entry in HopCopy.allEntries {
            #expect(Self.isDottedKey(entry.key), "\(entry.key) is not a well-formed dotted key")
        }
    }

    @Test("The scheme check rejects what it should")
    func schemeCheckIsMeaningful() {
        #expect(Self.isDottedKey("routine.step.wash.title"))
        #expect(Self.isDottedKey("a11y.pond.scene.named"))
        #expect(!Self.isDottedKey("title"), "a single segment carries no context")
        #expect(!Self.isDottedKey("Routine.Step"), "capitalised segments break catalog tooling")
        #expect(!Self.isDottedKey("routine..step"), "an empty segment is a typo")
        #expect(!Self.isDottedKey("routine.step_wash"), "underscores are not part of the scheme")
        #expect(!Self.isDottedKey("routine.step wash"), "spaces are not part of the scheme")
        #expect(!Self.isDottedKey(".routine.step"))
        #expect(!Self.isDottedKey("routine.step."))
    }

    @Test("Every key names a real surface")
    func everyKeyNamesAKnownSurface() {
        for entry in HopCopy.allEntries {
            #expect(entry.surface != nil, "\(entry.key) starts with a segment that is not a HopCopySurface")
        }
    }

    /// A string declared in the settings section but keyed `pond.something`
    /// would be findable, translatable, and in the wrong place forever.
    @Test("Every declared entry sits under its own section's prefix")
    func sectionsOwnTheirKeys() {
        for section in HopCopy.sections {
            for entry in section.entries {
                #expect(
                    entry.key.hasPrefix(section.surface.keyPrefix),
                    "\(entry.key) is declared in the \(section.surface.rawValue) section but keyed elsewhere"
                )
            }
        }
    }

    // MARK: - Reflection

    /// The catalog is derived by reflection. If that ever stops working the
    /// safety tests above would pass over an empty list and prove nothing, so
    /// the emptiness is what gets asserted.
    @Test("Every declared section contributes strings")
    func everySectionIsNonEmpty() {
        for section in HopCopy.sections {
            #expect(!section.entries.isEmpty, "the \(section.surface.rawValue) section reflected to nothing")
        }
    }

    @Test("Every surface has copy")
    func everySurfaceHasCopy() {
        for surface in HopCopySurface.allCases {
            #expect(!HopCopy.entries(on: surface).isEmpty, "no strings on the \(surface.rawValue) surface")
        }
    }

    @Test("The catalog covers both audiences and is not trivially small")
    func catalogIsSubstantial() {
        #expect(HopCopy.entries(for: .child).count > 40)
        #expect(HopCopy.entries(for: .parent).count > 80)
    }

    // MARK: - Formats

    /// Every slot in a format string is documented, and every documented slot
    /// exists. A translator reordering arguments needs both halves to be true.
    @Test("Declared placeholders match the tokens in the format string")
    func placeholdersMatchFormats() {
        for entry in HopCopy.allEntries {
            let tokens = HopCopyFormat.tokens(in: entry.value)
            let tokenPositions = Set(tokens.map(\.position))
            let declaredPositions = Set(entry.placeholders.map(\.position))
            #expect(
                tokenPositions == declaredPositions,
                "\(entry.key): format has \(tokenPositions.sorted()), declares \(declaredPositions.sorted())"
            )
            for placeholder in entry.placeholders {
                #expect(
                    entry.value.contains(placeholder.token),
                    "\(entry.key) declares \(placeholder.name) as \(placeholder.token), which is not in the string"
                )
            }
        }
    }

    /// Positions are explicit (`%1$@`) so translations can reorder arguments.
    /// A bare `%@` cannot be moved without changing meaning.
    @Test("No format uses a positionless placeholder")
    func noPositionlessPlaceholders() {
        for entry in HopCopy.allEntries {
            #expect(!entry.value.contains("%@"), "\(entry.key) uses a positionless %@")
            #expect(!entry.value.contains("%lld"), "\(entry.key) uses a positionless %lld")
        }
    }

    @Test("Filling a format substitutes every slot")
    func formattingSubstitutesSlots() {
        let entry = HopCopy.parentGate.question
        let filled = entry.formatted(.count(13), .count(24))
        #expect(filled == "What is 13 plus 24?")
        #expect(!filled.contains("%"))
    }

    /// A missing argument leaves its token visible. A screenshot with a stray
    /// `%2$@` gets reported; a silent gap does not.
    @Test("A missing argument leaves its token in place rather than vanishing")
    func missingArgumentsStayVisible() {
        let entry = HopCopy.parentGate.question
        let filled = entry.filled([1: .count(13)])
        #expect(filled == "What is 13 plus %2$lld?")
    }

    // MARK: - Nickname variants

    /// The nickname is optional, so every sentence that could carry a name has a
    /// version that does not. This checks the pair, not the strings.
    @Test("Every nickname-optional pair covers the nameless case")
    func nameVariantsCoverTheNamelessCase() {
        let variants = HopCopy.allNameVariants
        #expect(!variants.isEmpty, "no nickname variants found; reflection may be broken")
        for pair in variants {
            #expect(pair.named.key.hasSuffix(".named"), "\(pair.named.key) should end in .named")
            #expect(pair.unnamed.key.hasSuffix(".unnamed"), "\(pair.unnamed.key) should end in .unnamed")
            #expect(pair.named.audience == pair.unnamed.audience, "\(pair.baseKey) variants disagree about audience")
            #expect(
                pair.named.placeholders.contains { $0.name == "nickname" && $0.position == 1 },
                "\(pair.named.key) is the named variant but has no nickname at position 1"
            )
            #expect(
                !pair.unnamed.placeholders.contains { $0.name == "nickname" },
                "\(pair.unnamed.key) takes a nickname it is supposed to do without"
            )
        }
    }

    /// The bug this models away: interpolating an empty nickname to produce
    /// "'s pond".
    @Test("A missing nickname renders the nameless sentence, not a gap")
    func namelessRenderingHasNoHoles() {
        for pair in HopCopy.allNameVariants {
            for nickname in [nil, "", "   "] as [String?] {
                let rendered = pair.resolved(forNickname: nickname)
                #expect(rendered == pair.unnamed.value, "\(pair.baseKey) rendered \"\(rendered)\" for a blank nickname")
                #expect(!rendered.contains("%"), "\(pair.baseKey) left a format token in \"\(rendered)\"")
                #expect(!rendered.hasPrefix("'"), "\(pair.baseKey) rendered a dangling possessive")
            }
            let named = pair.resolved(forNickname: "Maya")
            #expect(named.contains("Maya"), "\(pair.baseKey) dropped the nickname it was given")
            #expect(!named.contains("%"), "\(pair.baseKey) left a format token in \"\(named)\"")
        }
    }

    @Test("The pond title is the canonical example, both ways")
    func pondTitleVariants() {
        #expect(HopCopy.pond.title.resolved(forNickname: "Maya") == "Maya's pond")
        #expect(HopCopy.pond.title.resolved(forNickname: nil) == "Your pond")
        #expect(HopCopy.pond.title.resolved(for: ChildProfile(nickname: "Sam")) == "Sam's pond")
        #expect(HopCopy.pond.title.resolved(for: ChildProfile()) == "Your pond")
    }

    // MARK: - Plural variants

    /// Plural forms are authored, never assembled. This checks that the forms
    /// agree with each other, which is what lets a caller pass the same
    /// arguments whichever form is picked.
    @Test("Plural groups are keyed and documented consistently")
    func pluralVariantsAreConsistent() {
        let groups = HopCopy.allPluralVariants
        #expect(!groups.isEmpty, "no plural groups found; reflection may be broken")
        for group in groups {
            #expect(group.one.key.hasSuffix(".one"), "\(group.one.key) should end in .one")
            #expect(group.other.key.hasSuffix(".other"), "\(group.other.key) should end in .other")
            if let zero = group.zero {
                #expect(zero.key.hasSuffix(".zero"), "\(zero.key) should end in .zero")
                #expect(zero.key.hasPrefix(group.baseKey), "\(zero.key) is not part of \(group.baseKey)")
            }
            #expect(group.other.key.hasPrefix(group.baseKey), "\(group.other.key) is not part of \(group.baseKey)")
            #expect(group.one.audience == group.other.audience, "\(group.baseKey) forms disagree about audience")

            // A placeholder position means the same thing in every form.
            var namesByPosition: [Int: String] = [:]
            for entry in group.entries {
                for placeholder in entry.placeholders {
                    if let existing = namesByPosition[placeholder.position] {
                        #expect(
                            existing == placeholder.name,
                            "\(group.baseKey) uses position \(placeholder.position) for both \(existing) and \(placeholder.name)"
                        )
                    } else {
                        namesByPosition[placeholder.position] = placeholder.name
                    }
                }
            }
        }
    }

    @Test("Plural resolution picks the right form and fills the count")
    func pluralResolution() {
        let stars = HopCopy.pond.starCount
        #expect(stars.resolved(for: 0) == "No stars yet")
        #expect(stars.resolved(for: 1) == "1 star")
        #expect(stars.resolved(for: 12) == "12 stars")

        // The interesting case: the "one" form spells the count out, so the item
        // name stays at position 2 in both forms and the caller passes the same
        // arguments either way.
        let next = HopCopy.pond.nextUnlock
        #expect(next.resolved(for: 1, additional: [2: .text("a dragonfly")]) == "1 more star and a dragonfly hops in!")
        #expect(next.resolved(for: 3, additional: [2: .text("a dragonfly")]) == "3 more stars and a dragonfly hops in!")
    }

    // MARK: - Lookup

    @Test("Canonical strings are exactly as specified")
    func canonicalVoiceIsIntact() {
        #expect(HopCopy.brand.name.value == "HopPotty")
        #expect(HopCopy.brand.tagline.value == "Pause. Potty. Play.")
        #expect(HopCopy.notification.warningTitle.value == "Potty break coming soon!")
        #expect(HopCopy.shield.title.value == "Potty time!")
        #expect(HopCopy.shield.body.value == "Let's hop to the potty. Your game will be here when you get back.")
        #expect(HopCopy.routine.introTitle.value == "Let's give it a try.")
        #expect(HopCopy.celebration.triedTitle.value == "Nothing happened? That's okay. Nice trying!")
        #expect(HopCopy.celebration.successTitle.value == "You listened to your body!")
        #expect(HopCopy.celebration.hygieneTitle.value == "Flush, wash, high five!")
        #expect(HopCopy.celebration.resumeButton.value == "Back to play!")
        #expect(HopCopy.parentHome.heroTitle.value == "Next Potty Pause")
        #expect(HopCopy.timerSettings.disableButton.value == "Disable Potty Pause")
        #expect(HopCopy.shield.restoreButton.value == "Restore Screen Access")
        #expect(HopCopy.settings.emergencyTitle.value == "Restore Screen Access")
    }

    @Test("Lookup finds a declared key and misses an undeclared one")
    func lookupWorks() {
        #expect(HopCopy.lookup("shield.title")?.value == "Potty time!")
        #expect(HopCopy.lookup("shield.titel") == nil)
    }
}
