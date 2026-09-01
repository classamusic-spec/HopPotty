import Foundation

/// Order statistics used by the insights engine.
///
/// Everything here is rank-based. A mean would be simpler and wrong: one
/// forgotten log resumed three hours later, or one car journey, moves a mean
/// far enough to change what a parent is told. Quartiles move by at most the
/// width of one bucket for the same event, which is the whole reason the
/// engine reports a range instead of a number.
enum RobustStatistics {

    /// Linear-interpolation quantile (the "type 7" definition — R's and NumPy's
    /// default), so a family's numbers do not depend on which library anyone
    /// reimplements this with later.
    ///
    /// Sorts internally: callers pass raw observations and cannot get a wrong
    /// answer by forgetting to sort.
    static func quantile(of values: [Double], probability: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        guard sorted.count > 1 else { return sorted[0] }

        let p = min(max(probability, 0), 1)
        let position = p * Double(sorted.count - 1)
        let lowerIndex = Int(position.rounded(.down))
        let upperIndex = min(lowerIndex + 1, sorted.count - 1)
        let fraction = position - Double(lowerIndex)
        return sorted[lowerIndex] + (sorted[upperIndex] - sorted[lowerIndex]) * fraction
    }

    static func median(of values: [Double]) -> Double? {
        quantile(of: values, probability: 0.5)
    }

    /// The middle 50% of the observations: `(Q1, Q3)`.
    static func interquartileRange(of values: [Double]) -> (low: Double, high: Double)? {
        guard let low = quantile(of: values, probability: 0.25),
              let high = quantile(of: values, probability: 0.75)
        else { return nil }
        return (low, high)
    }

    /// Rounds down to a reporting step, never below the step itself.
    static func floored(_ value: Double, toStep step: Int) -> Int {
        let s = max(1, step)
        let stepped = Int((value / Double(s)).rounded(.down)) * s
        return max(s, stepped)
    }

    /// Rounds up to a reporting step.
    static func ceiled(_ value: Double, toStep step: Int) -> Int {
        let s = max(1, step)
        let stepped = Int((value / Double(s)).rounded(.up)) * s
        return max(s, stepped)
    }

    /// Rounds to the nearest reporting step, halves away from zero so the
    /// result does not depend on the platform's rounding mode.
    static func rounded(_ value: Double, toStep step: Int) -> Int {
        let s = max(1, step)
        let stepped = Int((value / Double(s)).rounded(.toNearestOrAwayFromZero)) * s
        return max(s, stepped)
    }
}
