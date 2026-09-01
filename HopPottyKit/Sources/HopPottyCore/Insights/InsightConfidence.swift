import Foundation

/// How much data an insight rests on, carried with the insight itself.
///
/// This exists so the UI never has to guess. An insight that reached a parent
/// has already passed its minimum sample size — the engine returns `nil` below
/// it — but "just cleared the bar" and "a month of entries" are different
/// things to read, and the reader is entitled to know which one they are
/// looking at.
///
/// There is no `.high` and no percentage. This engine counts events in one
/// family's log; it has no population to compare against and no basis for a
/// number that would look like statistical power.
public struct InsightConfidence: Hashable, Sendable {

    /// How many observations the insight was computed from, in whatever unit
    /// the insight counts (gaps, visits, days).
    public let sampleSize: Int
    /// The threshold this insight had to clear to exist.
    public let minimumSampleSize: Int
    /// Distinct local days carrying at least one entry inside the period.
    public let observedDays: Int

    init(sampleSize: Int, minimumSampleSize: Int, observedDays: Int) {
        self.sampleSize = sampleSize
        self.minimumSampleSize = minimumSampleSize
        self.observedDays = observedDays
    }

    /// Whether the insight cleared its own threshold. Always true for an
    /// insight the engine actually returned; exposed so a caller can assert it.
    public var meetsMinimum: Bool { sampleSize >= minimumSampleSize }

    /// Coarse banding, used to choose emphasis in the UI.
    public var level: Level {
        guard meetsMinimum else { return .insufficient }
        return sampleSize >= minimumSampleSize * 2 ? .supported : .provisional
    }

    /// Whether the "Pattern, not medical advice" label has to be attached.
    ///
    /// Computed and constant on purpose. There is no initialiser parameter, no
    /// setter and no code path that yields `false`, so no future caller can
    /// produce an insight that travels without its label.
    public var disclaimerRequired: Bool { true }

    /// The label the UI attaches to every insight, without exception.
    public static let disclaimer = "Pattern, not medical advice."

    /// Banding for `level`.
    public enum Level: String, CaseIterable, Hashable, Sendable, Identifiable {
        /// Below the threshold. Unreachable for a returned insight; present so
        /// the type is total.
        case insufficient
        /// Cleared the threshold, but not by much.
        case provisional
        /// Comfortably past the threshold — at least twice the minimum.
        case supported

        public var id: String { rawValue }

        /// Short parent-facing wording. Describes the evidence, never the child.
        public var label: String {
            switch self {
            case .insufficient: "Not enough entries yet"
            case .provisional: "Based on a few days of entries"
            case .supported: "Based on several days of entries"
            }
        }
    }
}
