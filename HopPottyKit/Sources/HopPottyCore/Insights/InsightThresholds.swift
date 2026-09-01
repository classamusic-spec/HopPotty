import Foundation

/// Minimum sample sizes below which an insight is not offered at all.
///
/// Every one of these exists for the same reason: a pattern claimed from thin
/// data is a guess wearing a statistic's clothes, and a parent reading it about
/// their own child will believe it. When a threshold is not met the engine
/// returns `nil` — it does not return a hedged version, because a hedge on a
/// dashboard reads as a finding.
///
/// The numbers are deliberately conservative. Erring high costs a family a few
/// more days before an insight appears; erring low costs them a false belief
/// about their child.
public enum InsightThresholds {

    // MARK: Typical gap between visits

    /// Gaps needed before the interquartile range is reported.
    ///
    /// The reported range is the middle 50% of observations, so each quartile
    /// has to rest on more than one or two numbers to mean anything. Twelve
    /// gaps leaves at least three observations below Q1 and three above Q3, and
    /// is roughly three days of a family logging four or five visits a day — a
    /// span long enough that one unusual afternoon cannot define it.
    public static let minimumGapSamples = 12

    /// Gaps needed before the engine will raise an interval *question*.
    ///
    /// Higher than `minimumGapSamples` on purpose. Describing a pattern is one
    /// thing; inviting a family to change how often their day is interrupted is
    /// another, and it should rest on about a week of real use rather than the
    /// minimum that makes a quartile computable.
    public static let minimumSuggestionGapSamples = 20

    /// How far the observed median has to sit from the configured interval
    /// before a question is worth asking, in minutes.
    ///
    /// Below this the "change" is inside the noise of when a caregiver happened
    /// to tap the button, and a question the family answers "no" to every week
    /// is nagging, not help.
    public static let minimumSuggestionDeltaMinutes = 10

    // MARK: Participation

    /// Recorded visits needed before the period is summarised at all.
    ///
    /// One or two entries is not a period, it is the start of one. A headline
    /// count over a nearly empty log reads to a parent as a verdict on the log
    /// rather than a description of it, so the engine stays quiet instead.
    public static let minimumParticipationVisits = 3

    // MARK: Time-of-day consistency

    /// Distinct days carrying at least one entry, before parts of the day are
    /// compared.
    ///
    /// The comparison is "how many days did this part of the day have an
    /// entry", so the denominator is days. Five is the smallest denominator
    /// where a difference between two parts of the day is not just one day
    /// going differently, and it spans a working week.
    public static let minimumConsistencyDays = 5

    /// Visits a part of the day needs before it is eligible for comparison.
    ///
    /// Keeps a segment with a couple of stray entries — nights, usually — from
    /// being named the least consistent part of a family's day when really it
    /// is the part they do not use the app in.
    public static let minimumSegmentVisits = 5

    /// How far apart two segments' day-coverage rates must be before the
    /// difference is described as a pattern at all.
    ///
    /// 0.2 means one part of the day had an entry on at least one day in five
    /// more than the other. Below that the ordering flips with a single day's
    /// data and is not worth a sentence.
    public static let minimumConsistencyRateDifference = 0.2

    // MARK: Longest dry stretch

    /// Distinct days carrying at least one entry, before the longest stretch
    /// with no accident recorded is reported.
    ///
    /// A "longest stretch" measured inside a single afternoon of logging is an
    /// artefact of when the family opened the app. Three separate days is the
    /// point at which the timeline is describing days rather than one sitting.
    public static let minimumDryStretchDays = 3

    // MARK: Shared shaping constants

    /// Entries this close together describe one trip to the bathroom, not two.
    ///
    /// A child who taps "tried" and then "pee" produces two events seconds
    /// apart. Counting those as two visits would inflate participation and put
    /// a near-zero gap into the interval statistics, so entries inside this
    /// window are collapsed into a single visit.
    public static let visitClusterWindow: TimeInterval = 5 * 60

    /// Reported minute figures are rounded to this step.
    ///
    /// Rounding to five minutes is honesty about resolution: the underlying
    /// timestamps are when someone got round to tapping a button, and a range
    /// printed to the minute would claim a precision the data does not have.
    public static let reportingStepMinutes = 5
}
