#if DEBUG
import Foundation
import HopPottyCore

/// Deterministic sample entries for previews.
///
/// Seeded from a fixed generator, so a preview looks the same on every run and
/// the insights engine's thresholds are either met or not met reproducibly —
/// `InsightThresholds.minimumGapSamples` is twelve, and a randomly-sized log
/// would make the insight card appear and disappear between builds.
enum PreviewData {

    /// Two weeks of a plausible family log: four to six entries a day, a couple
    /// of accidents, nothing on one weekend day.
    static func fortnight(for childID: UUID, endingAt now: Date, calendar: Calendar) -> [PottyEvent] {
        var generator = SeededGenerator(seed: 0x484F5050)
        var events: [PottyEvent] = []
        let today = calendar.startOfDay(for: now)

        for dayOffset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            // One quiet day, so `observedDayCount` is not simply the day count —
            // the distinction matters to every insight's denominator.
            if dayOffset == 5 { continue }

            let entryCount = Int.random(in: 4...6, using: &generator)
            var hour = 7
            for index in 0..<entryCount {
                hour += Int.random(in: 1...3, using: &generator)
                guard hour < 21 else { break }
                let minute = Int.random(in: 0...59, using: &generator)
                guard let timestamp = calendar.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: 0,
                    of: day
                ) else { continue }

                let kind: PottyEventKind
                if dayOffset % 4 == 1 && index == 2 {
                    kind = .accident
                } else if index % 3 == 0 {
                    kind = .tried
                } else if index % 3 == 1 {
                    kind = .pee
                } else {
                    kind = .poop
                }

                events.append(
                    PottyEvent(
                        childID: childID,
                        timestamp: timestamp,
                        kind: kind,
                        source: kind == .accident ? .parentManual : .childRoutine
                    )
                )
            }
        }
        return events.sorted { $0.timestamp > $1.timestamp }
    }

    /// One star per participation entry. Accidents earn nothing and are not
    /// even looked at — `Docs/CONTRACTS.md` §4.3.
    static func stars(for childID: UUID, events: [PottyEvent]) -> [RewardTransaction] {
        events
            .filter { $0.kind.countsAsParticipation }
            .map { event in
                RewardTransaction(
                    childID: childID,
                    timestamp: event.timestamp,
                    reason: .triedThePotty,
                    quantity: 1,
                    sourceEventID: event.id,
                    idempotencyKey: "preview-\(event.id.uuidString)"
                )
            }
    }

    /// Today only, for the dashboard's populated preview.
    static func today(for childID: UUID, now: Date, calendar: Calendar) -> [PottyEvent] {
        let day = calendar.startOfDay(for: now)
        let offsets: [(Int, Int, PottyEventKind, PottyEventSource)] = [
            (7, 20, .pee, .childRoutine),
            (9, 5, .tried, .childRoutine),
            (10, 40, .pee, .pauseCompletion),
            (12, 15, .accident, .parentManual),
            (14, 0, .poop, .childRoutine),
        ]
        return offsets.compactMap { hour, minute, kind, source in
            guard let timestamp = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else {
                return nil
            }
            return PottyEvent(childID: childID, timestamp: timestamp, kind: kind, source: source)
        }
    }
}

/// A tiny linear-congruential generator, so previews are reproducible without
/// depending on the platform's RNG.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x4d595df4d0f33173 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
#endif
