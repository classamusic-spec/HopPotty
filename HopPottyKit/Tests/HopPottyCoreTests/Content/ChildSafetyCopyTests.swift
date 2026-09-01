import Foundation
import Testing
@testable import HopPottyCore

/// The rail under every word HopPotty says.
///
/// A potty-training app talks to a two-year-old about something they cannot
/// fully control, at the exact moment they are most likely to feel bad about it.
/// One careless sentence — "you did it wrong", "don't do that", "hurry up" —
/// lands on a child who has no way to argue back. This suite exists so that
/// sentence cannot ship, whoever writes it and however late.
///
/// A failure here is a product-contract failure (`Docs/CONTRACTS.md` §4.4 and
/// §4.5), not a style note.
@Suite("Child safety: copy")
struct ChildSafetyCopyTests {

    /// The longest a child-facing string may be, measured on what a child
    /// actually sees (placeholders filled with their example values).
    ///
    /// 90 characters, for two independent reasons that happen to agree:
    ///
    /// - **Layout.** Child text renders in `HopTypeScale.childInstruction`
    ///   (24pt, rounded, semibold). On the narrowest supported screen, 375pt
    ///   wide with `HopSpacing.pageCompact` padding on each side, that leaves
    ///   335pt, or roughly 28 characters a line. Three lines is the most the
    ///   illustrated layouts leave above the buttons, and 3 x 28 is 84.
    /// - **Speech.** Hop reads these aloud. 90 characters is about 18 words,
    ///   which at the deliberately slow pace used for pre-readers is six or
    ///   seven seconds — roughly the ceiling for one instruction to a
    ///   two-year-old before it stops being one instruction.
    ///
    /// The limit binds the English source. Translations run longer, which is
    /// exactly why the English is held short.
    static let childCharacterLimit = 90

    // MARK: - Shame language

    /// No child-facing string contains shame language.
    ///
    /// The check runs on the raw value *and* on the example rendering, so a
    /// forbidden word cannot hide inside a placeholder's example.
    @Test("No child-facing string contains shame language")
    func noShameLanguageInChildCopy() {
        for entry in HopCopy.entries(for: .child) {
            let matches = CopySafetyScanner.shameMatches(in: entry.value)
                + CopySafetyScanner.shameMatches(in: entry.exampleRendering)
            #expect(
                matches.isEmpty,
                "\(entry.key) says \"\(entry.value)\" — shame language: \(matches.joined(separator: ", "))"
            )
        }
    }

    /// Spoken lines are checked as well as written ones. A caption and its
    /// recording can drift apart, and the recording is the one a child hears.
    @Test("No spoken line contains shame language")
    func noShameLanguageInSpokenLines() {
        for line in HopVoiceCatalog.allLines {
            let matches = CopySafetyScanner.shameMatches(in: line.text)
                + CopySafetyScanner.shameMatches(in: line.caption)
            #expect(
                matches.isEmpty,
                "\(line.id) says \"\(line.text)\" — shame language: \(matches.joined(separator: ", "))"
            )
        }
    }

    // MARK: - Medical language

    /// No string anywhere claims or implies a medical role — parent copy
    /// included. HopPotty describes what a caregiver logged. It does not
    /// prevent, treat, diagnose or call anything normal.
    @Test("No string in the catalog uses medical claim language")
    func noMedicalLanguageAnywhere() {
        for entry in HopCopy.allEntries {
            let matches = CopySafetyScanner.medicalMatches(in: entry.value)
            #expect(
                matches.isEmpty,
                "\(entry.key) says \"\(entry.value)\" — medical language: \(matches.joined(separator: ", "))"
            )
        }
    }

    /// Caregiver copy observes; it does not instruct. "You should go every 45
    /// minutes" is the sentence this test exists to stop.
    @Test("No parent-facing string tells a caregiver what they should do")
    func noPrescriptiveLanguageInParentCopy() {
        for entry in HopCopy.entries(for: .parent) {
            let matches = CopySafetyScanner.prescriptiveMatches(in: entry.value)
            #expect(
                matches.isEmpty,
                "\(entry.key) says \"\(entry.value)\" — prescriptive language: \(matches.joined(separator: ", "))"
            )
        }
    }

    // MARK: - Length

    @Test("Child-facing strings stay short enough for a pre-reader")
    func childCopyIsShortEnough() {
        for entry in HopCopy.entries(for: .child) {
            let rendered = entry.exampleRendering
            #expect(
                rendered.count <= Self.childCharacterLimit,
                "\(entry.key) renders \(rendered.count) characters, over the \(Self.childCharacterLimit) limit: \"\(rendered)\""
            )
        }
    }

    @Test("Spoken lines stay short enough to hold attention")
    func spokenLinesAreShortEnough() {
        for line in HopVoiceCatalog.allLines {
            #expect(
                line.text.count <= Self.childCharacterLimit,
                "\(line.id) is \(line.text.count) characters: \"\(line.text)\""
            )
            #expect(
                line.caption.count <= Self.childCharacterLimit,
                "\(line.id) caption is \(line.caption.count) characters: \"\(line.caption)\""
            )
        }
    }

    // MARK: - Emptiness

    /// Nothing in the catalog is blank.
    ///
    /// An empty value ships as an invisible button; an empty key cannot be
    /// looked up; an empty comment is worse than none, because a translator
    /// reads it as "no context needed".
    @Test("No empty strings anywhere in the catalog")
    func noEmptyStrings() {
        for entry in HopCopy.allEntries {
            #expect(!entry.key.trimmed.isEmpty, "an entry has a blank key")
            #expect(!entry.value.trimmed.isEmpty, "\(entry.key) has a blank value")
            if let comment = entry.comment {
                #expect(!comment.trimmed.isEmpty, "\(entry.key) has a blank translator comment")
            }
            for placeholder in entry.placeholders {
                #expect(!placeholder.name.trimmed.isEmpty, "\(entry.key) has an unnamed placeholder")
                #expect(!placeholder.describes.trimmed.isEmpty, "\(entry.key) placeholder \(placeholder.name) is undocumented")
                #expect(!placeholder.example.trimmed.isEmpty, "\(entry.key) placeholder \(placeholder.name) has no example")
            }
        }
    }

    @Test("No empty strings in the spoken content")
    func noEmptyVoiceStrings() {
        for line in HopVoiceCatalog.allLines {
            #expect(!line.id.rawValue.trimmed.isEmpty, "a voice line has a blank id")
            #expect(!line.text.trimmed.isEmpty, "\(line.id) has no spoken text")
            #expect(!line.caption.trimmed.isEmpty, "\(line.id) has no caption")
            #expect(!line.asset.key.rawValue.trimmed.isEmpty, "\(line.id) has no asset key")
        }
    }

    @Test("No empty illustration keys")
    func noEmptyIllustrationKeys() {
        let keys = PottyRoutineContent.illustrations
            + QuizContent.illustrations
            + MiniGameCatalog.illustrations
        for key in keys {
            #expect(!key.rawValue.trimmed.isEmpty, "an illustration key is blank")
            #expect(key.isWellFormed, "illustration key \(key) is not a dotted key in a known art family")
        }
    }

    /// "No stars" is banned outright, in parent copy too.
    ///
    /// The star ledger is append-only by contract (`Docs/CONTRACTS.md` §4.2):
    /// stars are never removed, never decay and never expire. A sentence that
    /// describes a total as an absence teaches the opposite, and a caregiver who
    /// reads "no stars today" is the person who repeats it to the child.
    @Test("The phrase \"no stars\" appears nowhere in the catalog")
    func noStarsPhraseIsAbsentEverywhere() {
        for entry in HopCopy.allEntries {
            #expect(
                !CopySafetyScanner.containsPhrase("no stars", in: entry.value),
                "\(entry.key) says \"\(entry.value)\""
            )
        }
    }

    // MARK: - The scanner itself

    /// The matcher is only worth having if it is precise in both directions, so
    /// it is tested before it is trusted.
    ///
    /// The false-positive cases are the ones that matter: a scanner that fires
    /// on "close" gets narrowed by the next engineer in a hurry, and the
    /// narrowed version is the one that misses "you failed".
    @Test("The shame scanner does not fire on innocent words")
    func scannerAvoidsFalsePositives() {
        let innocent = [
            "Close the lid.",            // contains "lose"
            "Put it on the plate.",      // contains "late"
            "See you later!",            // "later" is not "late"
            "Here is your badge.",       // contains "bad"
            "A dab of mustard.",         // contains "must"
            "The door stopper.",         // contains "stopper", not "stop"
            "A shoulder to lean on.",    // contains "should"
            "Wash the bandage.",         // contains "band", "bad" adjacent
            "Never-ending is one word?", // hyphen splits: "never" IS a word here
        ]
        for sentence in innocent.dropLast() {
            #expect(
                CopySafetyScanner.shameMatches(in: sentence).isEmpty,
                "false positive on \"\(sentence)\": \(CopySafetyScanner.shameMatches(in: sentence))"
            )
        }
        // The last case is deliberately a true positive: hyphens split words, so
        // "Never-ending" really does contain the word "never". Documented here
        // so nobody later "fixes" it.
        #expect(CopySafetyScanner.shameMatches(in: innocent.last!) == ["never"])
    }

    @Test("The shame scanner catches what it is for")
    func scannerCatchesShameLanguage() {
        let offending: [(String, String)] = [
            ("You failed.", "failed"),
            ("That is the wrong one.", "wrong"),
            ("You lost a star.", "lost"),
            ("No stars today.", "no stars"),
            ("Hop is disappointed.", "disappointed"),
            ("That was bad.", "bad"),
            ("Do not be naughty.", "naughty"),
            ("Don't do that.", "don't"),
            ("You can't play now.", "can't"),
            ("Stop playing.", "stop"),
            ("You never try.", "never"),
            ("You must go now.", "must"),
            ("You should have gone.", "should"),
            ("Hurry up!", "hurry"),
            ("You are late.", "late"),
        ]
        for (sentence, expected) in offending {
            #expect(
                CopySafetyScanner.shameMatches(in: sentence).contains(expected),
                "missed \"\(expected)\" in \"\(sentence)\""
            )
        }
    }

    /// Copy edited outside a code editor arrives with typographic apostrophes.
    /// "Don’t" must not walk past a check written for "Don't".
    @Test("The shame scanner folds typographic apostrophes")
    func scannerHandlesCurlyApostrophes() {
        #expect(CopySafetyScanner.shameMatches(in: "Don\u{2019}t worry.").contains("don't"))
        #expect(CopySafetyScanner.shameMatches(in: "You can\u{2019}t go.").contains("can't"))
    }

    @Test("The medical scanner matches word beginnings, not substrings")
    func medicalScannerIsStemBased() {
        #expect(CopySafetyScanner.medicalMatches(in: "A diagnosis of something.") == ["diagnos"])
        #expect(CopySafetyScanner.medicalMatches(in: "The treatment plan.") == ["treat"])
        #expect(CopySafetyScanner.medicalMatches(in: "This prevents accidents.") == ["prevent"])
        // "secure" begins with "sec", not "cure".
        #expect(CopySafetyScanner.medicalMatches(in: "Your data is secure.").isEmpty)
        // "conditioner" would be a false positive worth knowing about, so it is
        // asserted rather than assumed: the stem list is intentionally blunt
        // here, because every word in this family is one HopPotty avoids.
        #expect(CopySafetyScanner.medicalMatches(in: "Hair conditioner.") == ["condition"])
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
