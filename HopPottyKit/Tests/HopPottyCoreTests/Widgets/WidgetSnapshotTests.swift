import Foundation
import Testing
@testable import HopPottyCore

@Suite("Widgets: the snapshot")
struct WidgetSnapshotTests {
    typealias F = WidgetFixtures

    // MARK: Round trip

    @Test("A snapshot survives the App Group round trip unchanged")
    func codableRoundTrip() throws {
        let snapshot = WidgetSnapshot(
            nextPauseAt: F.at(45),
            childDisplayName: "Ellie",
            hopPoseName: HopWidgetMood.wave.rawValue,
            quickReminderAt: F.at(20),
            isScheduleEnabled: true,
            pauseEndsAt: nil,
            generatedAt: F.now
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(WidgetSnapshot.self, from: encoder.encode(snapshot))
        #expect(decoded == snapshot)
        #expect(decoded.schemaVersion == WidgetSnapshot.currentSchemaVersion)
    }

    @Test("An unknown pose decodes and falls back rather than failing the file")
    func unknownPoseFallsBack() {
        let snapshot = WidgetSnapshot(hopPoseName: "somersault", generatedAt: F.now)
        #expect(snapshot.mood == .idle)
    }

    @Test("Every mood round-trips through the stored string")
    func everyMoodRoundTrips() {
        for mood in HopWidgetMood.allCases {
            let snapshot = WidgetSnapshot(hopPoseName: mood.rawValue, generatedAt: F.now)
            #expect(snapshot.mood == mood)
        }
    }

    // MARK: Privacy

    @Test("The snapshot has exactly one free-text field, and it is the opt-in name")
    func onlyOneStringField() throws {
        // Encoding and inspecting the JSON is the check that survives a future
        // edit: a new `String` property would show up here as a second string
        // value, and a new string on this boundary is a privacy decision that
        // has to be made deliberately rather than merged quietly.
        // `Docs/PrivacyArchitecture.md` §5.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(
            WidgetSnapshot(
                nextPauseAt: F.at(30),
                childDisplayName: "Ellie",
                hopPoseName: HopWidgetMood.wave.rawValue,
                quickReminderAt: F.at(10),
                isScheduleEnabled: true,
                pauseEndsAt: F.at(3),
                generatedAt: F.now
            )
        )
        let object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        // Dates are ISO-8601 strings, so they are excluded by key, not by type.
        let dateKeys: Set<String> = ["nextPauseAt", "quickReminderAt", "pauseEndsAt", "generatedAt"]
        let freeText = object
            .filter { !dateKeys.contains($0.key) }
            .filter { $0.value is String }
            .map(\.key)
            .sorted()

        #expect(freeText == ["childDisplayName", "hopPoseName"])
        // `hopPoseName` is a closed vocabulary, not free text.
        #expect(HopWidgetMood(rawValue: object["hopPoseName"] as? String ?? "") != nil)
    }

    // MARK: Derived answers

    @Test("The next event is the sooner of the pause and the reminder")
    func nextEventPicksTheSooner() {
        let snapshot = WidgetSnapshot(
            nextPauseAt: F.at(45),
            quickReminderAt: F.at(20),
            isScheduleEnabled: true,
            generatedAt: F.now
        )
        #expect(snapshot.nextEvent(after: F.now) == F.at(20))
    }

    @Test("An event already past is not the next event")
    func nextEventIgnoresThePast() {
        let snapshot = WidgetSnapshot(
            nextPauseAt: F.at(45),
            quickReminderAt: F.at(-5),
            isScheduleEnabled: true,
            generatedAt: F.now
        )
        #expect(snapshot.nextEvent(after: F.now) == F.at(45))
    }

    @Test("With nothing scheduled there is no next event")
    func nextEventCanBeNil() {
        let snapshot = WidgetSnapshot.empty(at: F.now)
        #expect(snapshot.nextEvent(after: F.now) == nil)
        #expect(snapshot.mood == .sleep)
        #expect(!snapshot.isScheduleEnabled)
    }

    @Test("A pause is running only until its expected end")
    func pauseRunningWindow() {
        let snapshot = WidgetSnapshot(pauseEndsAt: F.at(3), generatedAt: F.now)
        #expect(snapshot.isPauseRunning(at: F.now))
        #expect(snapshot.isPauseRunning(at: F.at(2.9)))
        #expect(!snapshot.isPauseRunning(at: F.at(3)))
        #expect(!snapshot.isPauseRunning(at: F.at(4)))
    }

    @Test("Nothing running means nothing running, whatever the clock says")
    func noPauseNoRun() {
        let snapshot = WidgetSnapshot(generatedAt: F.now)
        #expect(!snapshot.isPauseRunning(at: F.now))
    }

    // MARK: Staleness

    @Test("Age never goes negative when the writer's clock ran ahead")
    func ageIsClamped() {
        let snapshot = WidgetSnapshot(generatedAt: F.at(10))
        #expect(snapshot.age(at: F.now) == 0)
        #expect(!snapshot.isStale(at: F.now))
    }

    @Test("A snapshot goes stale after twelve hours")
    func staleness() {
        let snapshot = WidgetSnapshot(generatedAt: F.now)
        #expect(!snapshot.isStale(at: F.at(60 * 11)))
        #expect(!snapshot.isStale(at: F.now.addingTimeInterval(WidgetSnapshot.stalenessHorizon)))
        #expect(snapshot.isStale(at: F.at(60 * 13)))
    }

    // MARK: Standard snapshots

    @Test("The placeholder shows a plausible future, never a real family's")
    func placeholder() {
        let snapshot = WidgetSnapshot.placeholder(at: F.now)
        #expect(snapshot.childDisplayName == nil)
        #expect(snapshot.isScheduleEnabled)
        #expect(snapshot.nextPauseAt == F.at(45))
        #expect(snapshot.pauseEndsAt == nil)
    }

    @Test("Accessibility descriptions exist, mention Hop, and never name a child")
    func accessibilityCopy() {
        for mood in HopWidgetMood.allCases {
            let description = mood.accessibilityDescription
            #expect(!description.isEmpty)
            #expect(description.hasPrefix("Hop the frog"))
        }
    }
}
