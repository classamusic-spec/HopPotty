import Foundation

/// Word-level scanner used by the child-safety tests.
///
/// Deliberately implemented here rather than in `HopPottyCore`. If the catalog
/// and the thing that checks the catalog shared an implementation, a bug in the
/// matcher would hide the very strings it exists to find. This is the second
/// opinion.
///
/// Matching is word-level, not substring-level, because substring matching is
/// wrong in both directions. It fires on innocent words — "close" contains
/// "lose", "plate" contains "late", "badge" contains "bad", "mustard" contains
/// "must", "stopper" contains "stop" — and a list tuned to avoid those false
/// positives ends up so narrow it misses the real thing. So: split into words,
/// compare whole words, and enumerate the inflections that matter explicitly.
enum CopySafetyScanner {

    // MARK: Tokenising

    /// Splits text into lowercased words.
    ///
    /// A word is letters, digits and apostrophes. Everything else is a
    /// separator, so "grown-up" is two words and "Flush, wash, high five!" is
    /// four. Typographic apostrophes are folded to ASCII first: "don’t" and
    /// "don't" are the same word, and copy edited in a word processor must not
    /// slip past the check because of a curly quote.
    static func words(in text: String) -> [String] {
        let normalised = text
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{02BC}", with: "'")
            .lowercased()
        var words: [String] = []
        var current = ""
        for character in normalised {
            if character.isLetter || character.isNumber || character == "'" {
                current.append(character)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
        }
        if !current.isEmpty { words.append(current) }
        // A leading or trailing apostrophe is punctuation, not part of the word.
        return words.map { word in
            var trimmed = Substring(word)
            while trimmed.first == "'" { trimmed = trimmed.dropFirst() }
            while trimmed.last == "'" { trimmed = trimmed.dropLast() }
            return String(trimmed)
        }
        .filter { !$0.isEmpty }
    }

    // MARK: Matching

    /// Whole-word match. "late" matches "late" but not "later" or "plate".
    static func containsWord(_ term: String, in text: String) -> Bool {
        words(in: text).contains(term)
    }

    /// Whole-word match for a multi-word phrase, e.g. "no stars".
    static func containsPhrase(_ phrase: String, in text: String) -> Bool {
        let needle = words(in: phrase)
        guard !needle.isEmpty else { return false }
        let haystack = words(in: text)
        guard haystack.count >= needle.count else { return false }
        for start in 0...(haystack.count - needle.count)
        where Array(haystack[start..<(start + needle.count)]) == needle {
            return true
        }
        return false
    }

    /// Matches a word that *begins* with the stem: "diagnos" catches "diagnosis"
    /// and "diagnose", "treat" catches "treatment". Used only for the medical
    /// vocabulary, where the whole family of a root word is the problem and
    /// where the roots are distinctive enough not to collide ("cure" does not
    /// match "secure", because "secure" does not start with "cure").
    static func containsWordBeginning(with stem: String, in text: String) -> Bool {
        words(in: text).contains { $0.hasPrefix(stem) }
    }

    // MARK: Vocabularies

    /// Shame language. Nothing a child hears from Hop may contain any of these.
    ///
    /// The base list is fixed by `Docs/CONTRACTS.md` §4. The inflections beside
    /// each base word are listed explicitly rather than derived, because
    /// suffix-stripping produces exactly the false positives whole-word matching
    /// was chosen to avoid: "late" + "r" is "later", which is a perfectly kind
    /// word.
    static let shameWords: [String] = [
        "fail", "fails", "failed", "failing", "failure", "failures",
        "wrong", "wrongly",
        "lost", "lose", "loses", "losing", "loser",
        "disappoint", "disappoints", "disappointed", "disappointing", "disappointment",
        "bad", "badly", "worse", "worst",
        "naughty",
        "don't", "dont",
        "can't", "cant", "cannot",
        "stop", "stops", "stopped",
        "never",
        "must", "mustn't",
        "should", "shouldn't",
        "hurry", "hurries", "hurried", "hurrying",
        "late",
    ]

    /// Shame phrases: several words that are each innocent alone.
    static let shamePhrases: [String] = [
        "no stars",
        "do not",
        "did not",
        "too slow",
        "too late",
    ]

    /// Medical vocabulary. Banned across the whole catalog, parent copy
    /// included: HopPotty observes and describes, and it is not qualified to do
    /// anything else. Matched as word beginnings so "treatment", "prevention"
    /// and "diagnosis" are caught with their roots.
    static let medicalStems: [String] = [
        "prevent", "treat", "cure", "diagnos", "condition", "disorder",
        "normal", "abnormal", "delayed",
    ]

    /// Words that turn a caregiver-facing observation into an instruction.
    /// `Docs/CONTRACTS.md` §5: insights describe what was logged and say so.
    static let prescriptiveWords: [String] = ["should", "shouldn't", "must", "ought"]

    // MARK: Reporting

    static func shameMatches(in text: String) -> [String] {
        shameWords.filter { containsWord($0, in: text) }
            + shamePhrases.filter { containsPhrase($0, in: text) }
    }

    static func medicalMatches(in text: String) -> [String] {
        medicalStems.filter { containsWordBeginning(with: $0, in: text) }
    }

    static func prescriptiveMatches(in text: String) -> [String] {
        prescriptiveWords.filter { containsWord($0, in: text) }
    }
}
