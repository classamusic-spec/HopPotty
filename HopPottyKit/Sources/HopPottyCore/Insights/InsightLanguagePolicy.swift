import Foundation

/// The vocabulary rail for every string the insights engine can put in front of
/// a parent.
///
/// HopPotty is not a medical device and this engine is not a clinician. It is
/// allowed to describe what a family recorded; it is not allowed to say what
/// that means, what a child needs, or what anyone ought to do about it. That
/// line is easy to write down and easy to cross by accident three sprints
/// later, so it is enforced mechanically here and asserted by
/// `InsightLanguageTests` over every string the module can emit.
///
/// Two structural rules make the check total:
///
/// 1. Every generated string is assembled in this module from constants and
///    integers. No caregiver note, child nickname or other free text is ever
///    interpolated into an insight, so a family cannot smuggle language past
///    the rail and the rail cannot be defeated by data.
/// 2. Every insight publishes `generatedStrings`, and `InsightsEngine`
///    publishes `allStaticStrings`. Between them, every string with a path to a
///    screen is enumerable and therefore testable.
public enum InsightLanguagePolicy {

    /// Fragments that may never appear in a generated string, matched
    /// case-insensitively as substrings so inflections are caught too
    /// ("cause" catches "caused", "causes" and "because").
    ///
    /// Grouped by the kind of harm each one does. Anything a paediatrician
    /// would object to seeing in a consumer app belongs here.
    public static let forbiddenFragments: [String] = [
        // Prescriptive — turns an observation into an instruction.
        "should", "must", "ought", "need to", "needs to", "required", "require",
        "recommend", "supposed to", "have to", "make sure",

        // Diagnostic — claims to know what is happening inside a child.
        "diagnos", "symptom", "disorder", "condition", "syndrome", "dysfunction",
        "constipat", "infection", "incontinen", "retention", "bladder issue",

        // Normative — implies a correct rate of development or a correct interval.
        "normal", "abnormal", "typical for", "average child", "delay", "behind",
        "on track", "ahead of", "expected for", "regress", "milestone",
        "age-appropriate", "healthy interval", "too long", "too often", "too few",

        // Clinical action — implies HopPotty is part of care.
        "treat", "cure", "prevent", "therapy", "medication", "dose", "clinical",

        // Causal — this engine counts events, it does not explain them.
        "cause", "leads to", "due to", "results in", "proves", "guarantee",
        "means that", "explains why",

        // Shame and loss — barred by the product contract, not only by taste.
        "fail", "wrong", "poor", "worse", "problem", "concern", "lost", "losing",
        "streak", "success rate", "accident rate", "bad",
    ]

    /// Every forbidden fragment found in `text`, case-insensitively.
    ///
    /// Returns all matches rather than the first so a failing test names the
    /// whole problem instead of sending the reader round the loop once per word.
    public static func violations(in text: String) -> [String] {
        let haystack = text.lowercased()
        return forbiddenFragments.filter { haystack.contains($0) }
    }

    /// Whether a string is safe to show a parent.
    public static func isAcceptable(_ text: String) -> Bool {
        violations(in: text).isEmpty
    }

    /// What is shown if a generated string ever trips the rail in a shipping
    /// build. Deliberately empty of claims.
    public static let neutralFallback = "Pattern from recorded entries."

    /// Runtime defence in depth for a string on its way to a screen.
    ///
    /// Traps in debug so a mistake is caught by the test suite the moment it is
    /// written, and degrades to `neutralFallback` in release rather than
    /// showing a parent a sentence this policy forbids.
    static func checked(_ text: String) -> String {
        let found = violations(in: text)
        guard found.isEmpty else {
            assertionFailure("Insight copy contains forbidden language: \(found)")
            return neutralFallback
        }
        return text
    }
}
