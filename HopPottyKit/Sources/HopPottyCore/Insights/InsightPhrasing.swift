import Foundation

/// Builds every sentence the insights engine can produce.
///
/// Kept in one place for two reasons. First, it is the only file anyone has to
/// read to audit what a parent can be shown. Second, nothing here interpolates
/// caregiver or child text — the inputs are integers and this module's own
/// constants — so `InsightLanguagePolicy` can be enforced over the complete set
/// of outputs rather than over a sample of them.
///
/// These strings are the engine's canonical English. When `HopCopy` exists they
/// become its values; the safety test runs against these either way.
enum InsightPhrasing {

    /// "1 minute" / "45 minutes".
    static func minutes(_ value: Int) -> String {
        value == 1 ? "1 minute" : "\(value) minutes"
    }

    /// "45–55 minutes", en dash, no space — the form a range takes in prose.
    static func minuteRange(lower: Int, upper: Int) -> String {
        lower == upper ? minutes(lower) : "\(lower)–\(upper) minutes"
    }

    /// "1 visit" / "12 visits".
    static func visits(_ value: Int) -> String {
        value == 1 ? "1 visit" : "\(value) visits"
    }

    /// "1 day" / "5 days".
    static func days(_ value: Int) -> String {
        value == 1 ? "1 day" : "\(value) days"
    }

    /// "3 days, 4 hours" — coarsened as it gets longer, because nobody reads a
    /// three-day span to the minute.
    static func duration(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int((interval / 60).rounded(.down)))
        let dayPart = totalMinutes / (24 * 60)
        let hourPart = (totalMinutes % (24 * 60)) / 60
        let minutePart = totalMinutes % 60

        if dayPart > 0 {
            let dayText = dayPart == 1 ? "1 day" : "\(dayPart) days"
            guard hourPart > 0 else { return dayText }
            return "\(dayText), \(hourPart == 1 ? "1 hour" : "\(hourPart) hours")"
        }
        if hourPart > 0 {
            let hourText = hourPart == 1 ? "1 hour" : "\(hourPart) hours"
            guard minutePart > 0 else { return hourText }
            return "\(hourText), \(minutes(minutePart))"
        }
        return minutes(minutePart)
    }

    // MARK: Statements
    //
    // Every one of these is an observation about entries a family made. None of
    // them says what the entries mean, what would be better, or what anyone
    // might do next. The interval question in `IntervalSuggestion` is the only
    // string in the module that asks for anything, and it asks — it does not
    // suggest an outcome.

    static func typicalGap(lower: Int, upper: Int) -> String {
        InsightLanguagePolicy.checked(
            "Half of the recorded gaps between potty visits fell within \(minuteRange(lower: lower, upper: upper))."
        )
    }

    static func typicalGapDetail(sampleCount: Int, medianMinutes: Int) -> String {
        InsightLanguagePolicy.checked(
            "Taken from \(sampleCount) gaps between visits on the same day. The middle value was \(minutes(medianMinutes))."
        )
    }

    static func participation(visitCount: Int, observedDays: Int, previousVisitCount: Int) -> String {
        InsightLanguagePolicy.checked(
            "\(visits(visitCount)) recorded across \(days(observedDays)) with entries, "
            + "compared with \(visits(previousVisitCount)) in the period before."
        )
    }

    static func participationDetail() -> String {
        InsightLanguagePolicy.checked(
            "Every entry counts the same here: trying, a pee and a poop are all taking part."
        )
    }

    static func timeOfDayConsistency(
        higher: DaySegment,
        higherDays: Int,
        lower: DaySegment,
        lowerDays: Int,
        observedDays: Int
    ) -> String {
        InsightLanguagePolicy.checked(
            "\(higher.pluralLabel) had an entry on \(higherDays) of \(observedDays) days with entries; "
            + "\(lower.pluralLabelLowercased) on \(lowerDays) of \(observedDays)."
        )
    }

    static func timeOfDayDetail() -> String {
        InsightLanguagePolicy.checked(
            "Counts how many days had at least one entry in each part of the day."
        )
    }

    static func dryStretch(duration interval: TimeInterval) -> String {
        InsightLanguagePolicy.checked(
            "The longest stretch with no accident recorded was \(duration(interval))."
        )
    }

    static func dryStretchDetail() -> String {
        // Spelled out because the framing is the feature: this is a record of
        // something that happened, not a counter a family can watch fall over.
        InsightLanguagePolicy.checked(
            "A note of what happened, kept as part of the timeline. It is not a running count and nothing resets it."
        )
    }

    static func intervalObservation(medianMinutes: Int, lower: Int, upper: Int) -> String {
        InsightLanguagePolicy.checked(
            "Recorded visits have most often been about \(minutes(medianMinutes)) apart, "
            + "with half of the gaps within \(minuteRange(lower: lower, upper: upper))."
        )
    }

    static func intervalQuestion(currentMinutes: Int, suggestedMinutes: Int) -> String {
        InsightLanguagePolicy.checked(
            "Would you like to change the pause interval from \(minutes(currentMinutes)) to \(minutes(suggestedMinutes))?"
        )
    }
}
