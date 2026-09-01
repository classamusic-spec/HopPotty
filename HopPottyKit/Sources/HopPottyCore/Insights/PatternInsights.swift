import Foundation

/// What every insight in this module has in common.
///
/// The name is the contract: these are patterns in recorded data, and each one
/// carries the evidence it rests on and the label it has to travel with. There
/// is no `advice` or `recommendation` member here and there is not meant to be
/// one — an insight describes, and stops.
public protocol PatternInsight: Hashable, Sendable {
    /// How much data this rests on.
    var confidence: InsightConfidence { get }
    /// The one-sentence observation a parent reads.
    var patternStatement: String { get }
    /// Secondary line explaining what was counted.
    var supportingDetail: String { get }
    /// Every string this value can put on screen, for the language test.
    var generatedStrings: [String] { get }
}

public extension PatternInsight {
    /// Always true. See `InsightConfidence.disclaimerRequired`.
    var disclaimerRequired: Bool { confidence.disclaimerRequired }
    var disclaimer: String { InsightConfidence.disclaimer }
    var generatedStrings: [String] {
        [patternStatement, supportingDetail, confidence.level.label, disclaimer]
    }
}

/// How far apart recorded visits have been, as a range.
///
/// Reported as the interquartile range — the middle 50% of observed gaps —
/// because a single three-hour car journey would drag a mean somewhere no
/// family would recognise. Gaps are measured within a local day only: the span
/// from bedtime to breakfast is sleep, not a pattern of visits.
public struct TypicalGapInsight: PatternInsight {
    /// Lower edge of the middle 50%, rounded down to the reporting step.
    public let lowerMinutes: Int
    /// Upper edge, rounded up.
    public let upperMinutes: Int
    /// Middle observed gap, rounded to the nearest step.
    public let medianMinutes: Int
    /// Gaps the range was computed from.
    public let sampleCount: Int
    public let confidence: InsightConfidence

    init(lowerMinutes: Int, upperMinutes: Int, medianMinutes: Int, sampleCount: Int, confidence: InsightConfidence) {
        self.lowerMinutes = lowerMinutes
        self.upperMinutes = upperMinutes
        self.medianMinutes = medianMinutes
        self.sampleCount = sampleCount
        self.confidence = confidence
    }

    /// "45–55 minutes".
    public var rangeText: String { InsightPhrasing.minuteRange(lower: lowerMinutes, upper: upperMinutes) }

    public var patternStatement: String {
        InsightPhrasing.typicalGap(lower: lowerMinutes, upper: upperMinutes)
    }

    public var supportingDetail: String {
        InsightPhrasing.typicalGapDetail(sampleCount: sampleCount, medianMinutes: medianMinutes)
    }

    public var generatedStrings: [String] {
        [patternStatement, supportingDetail, rangeText, confidence.level.label, disclaimer]
    }
}

/// How many visits a family recorded, set beside the period before.
///
/// The only "how it went" number this engine reports, and it counts taking
/// part. `tried` weighs exactly as much as `pee`, per `PottyEventKind`, so the
/// figure cannot be read as how often a child produced something.
public struct ParticipationInsight: PatternInsight {
    /// Visits, after entries within five minutes of each other are collapsed
    /// into the single trip to the bathroom they describe.
    public let visitCount: Int
    /// Raw participation entries, before that collapsing. Exposed so a caller
    /// can show a timeline count that matches the list.
    public let eventCount: Int
    public let previousVisitCount: Int
    public let observedDayCount: Int
    public let confidence: InsightConfidence

    init(visitCount: Int, eventCount: Int, previousVisitCount: Int, observedDayCount: Int, confidence: InsightConfidence) {
        self.visitCount = visitCount
        self.eventCount = eventCount
        self.previousVisitCount = previousVisitCount
        self.observedDayCount = observedDayCount
        self.confidence = confidence
    }

    /// Difference against the previous period. Direction only, no wording.
    public var difference: Int { visitCount - previousVisitCount }
    public var direction: ChangeDirection { ChangeDirection(difference: difference) }

    public var patternStatement: String {
        InsightPhrasing.participation(
            visitCount: visitCount,
            observedDays: observedDayCount,
            previousVisitCount: previousVisitCount
        )
    }

    public var supportingDetail: String { InsightPhrasing.participationDetail() }
}

/// One part of the day, and how many of the family's logged days had an entry
/// in it.
public struct SegmentConsistency: Hashable, Sendable {
    public let segment: DaySegment
    /// Days with at least one entry in this part of the day.
    public let daysWithVisit: Int
    /// Denominator: days with at least one entry anywhere.
    public let observedDays: Int
    public let visitCount: Int

    init(segment: DaySegment, daysWithVisit: Int, observedDays: Int, visitCount: Int) {
        self.segment = segment
        self.daysWithVisit = daysWithVisit
        self.observedDays = observedDays
        self.visitCount = visitCount
    }

    /// Share of logged days that had an entry in this part of the day, 0...1.
    public var rate: Double {
        observedDays > 0 ? Double(daysWithVisit) / Double(observedDays) : 0
    }
}

/// Which parts of the day have looked most alike from one day to the next.
///
/// "Consistency" here means one thing and is stated in the supporting detail:
/// how many of the days with entries had an entry in that part of the day. It
/// is a statement about the log, not about a child's body.
public struct TimeOfDayConsistencyInsight: PatternInsight {
    /// Eligible segments, most consistent first, ties broken by time of day so
    /// the same input always produces the same order.
    public let segments: [SegmentConsistency]
    public let mostConsistent: SegmentConsistency
    public let leastConsistent: SegmentConsistency
    public let observedDayCount: Int
    public let confidence: InsightConfidence

    init(
        segments: [SegmentConsistency],
        mostConsistent: SegmentConsistency,
        leastConsistent: SegmentConsistency,
        observedDayCount: Int,
        confidence: InsightConfidence
    ) {
        self.segments = segments
        self.mostConsistent = mostConsistent
        self.leastConsistent = leastConsistent
        self.observedDayCount = observedDayCount
        self.confidence = confidence
    }

    public var patternStatement: String {
        InsightPhrasing.timeOfDayConsistency(
            higher: mostConsistent.segment,
            higherDays: mostConsistent.daysWithVisit,
            lower: leastConsistent.segment,
            lowerDays: leastConsistent.daysWithVisit,
            observedDays: observedDayCount
        )
    }

    public var supportingDetail: String { InsightPhrasing.timeOfDayDetail() }

    public var generatedStrings: [String] {
        [patternStatement, supportingDetail, confidence.level.label, disclaimer]
            + segments.map(\.segment.pluralLabel)
            + segments.map(\.segment.pluralLabelLowercased)
    }
}

/// The longest span inside the period with no accident recorded.
///
/// Framing notes, because they are load-bearing:
///
/// - It is bounded by recorded entries, never by `now`. It does not tick
///   upward while a parent watches, so there is no live number to lose.
/// - Adding entries after the last recorded one can only make a previously
///   reported stretch longer or leave it alone. It shrinks only if someone
///   backdates an accident into the middle of it, which is a correction to the
///   log rather than something that happened to the child.
/// - There is deliberately no "current stretch" property, no best-ever record
///   across periods, and no notification. A number that can be broken is a
///   streak, and the product contract bars streaks.
public struct DryStretchInsight: PatternInsight {
    public let duration: TimeInterval
    /// First instant of the stretch — the entry it started from.
    public let start: Date
    /// Last instant of the stretch — the entry it ran to.
    public let end: Date
    /// Accidents recorded in the period. A plain count, never a denominator.
    public let accidentCount: Int
    public let observedDayCount: Int
    public let confidence: InsightConfidence

    init(
        duration: TimeInterval,
        start: Date,
        end: Date,
        accidentCount: Int,
        observedDayCount: Int,
        confidence: InsightConfidence
    ) {
        self.duration = duration
        self.start = start
        self.end = end
        self.accidentCount = accidentCount
        self.observedDayCount = observedDayCount
        self.confidence = confidence
    }

    public var durationText: String { InsightPhrasing.duration(duration) }

    public var patternStatement: String { InsightPhrasing.dryStretch(duration: duration) }

    public var supportingDetail: String { InsightPhrasing.dryStretchDetail() }

    public var generatedStrings: [String] {
        [patternStatement, supportingDetail, durationText, confidence.level.label, disclaimer]
    }
}
