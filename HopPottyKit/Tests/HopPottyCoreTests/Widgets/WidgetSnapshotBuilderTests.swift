import Foundation
import Testing
@testable import HopPottyCore

@Suite("Widgets: building a snapshot")
struct WidgetSnapshotBuilderTests {
    typealias F = WidgetFixtures
    typealias S = SchedulingFixtures

    // MARK: The name

    @Test("The child's name is dropped unless the caller asks for it")
    func nameIsOptInByDefault() {
        let snapshot = WidgetSnapshotBuilder.snapshot(
            schedule: S.schedule(),
            projection: F.projection(start: F.at(30)),
            childNickname: "Ellie",
            now: F.now
        )
        #expect(snapshot.childDisplayName == nil)
    }

    @Test("With the flag set, the name is carried and sanitised")
    func nameIsCarriedWhenAsked() {
        let snapshot = WidgetSnapshotBuilder.snapshot(
            schedule: S.schedule(),
            projection: F.projection(start: F.at(30)),
            childNickname: "  Ellie  ",
            includeChildName: true,
            now: F.now
        )
        #expect(snapshot.childDisplayName == "Ellie")
    }

    @Test("A whitespace-only nickname becomes no name at all")
    func blankNameCollapses() {
        let snapshot = WidgetSnapshotBuilder.snapshot(
            schedule: S.schedule(),
            projection: nil,
            childNickname: "   ",
            includeChildName: true,
            now: F.now
        )
        #expect(snapshot.childDisplayName == nil)
    }

    @Test("An over-long nickname is capped the same way it is everywhere else")
    func longNameIsCapped() {
        let long = String(repeating: "a", count: 60)
        let snapshot = WidgetSnapshotBuilder.snapshot(
            schedule: S.schedule(),
            projection: nil,
            childNickname: long,
            includeChildName: true,
            now: F.now
        )
        #expect(snapshot.childDisplayName?.count == ChildProfile.maxNicknameLength)
    }

    // MARK: The pause date

    @Test("A future projection on an enabled schedule becomes the next pause")
    func projectionBecomesNextPause() {
        let snapshot = WidgetSnapshotBuilder.snapshot(
            schedule: S.schedule(),
            projection: F.projection(start: F.at(45)),
            now: F.now
        )
        #expect(snapshot.nextPauseAt == F.at(45))
        #expect(snapshot.isScheduleEnabled)
    }

    @Test("A disabled schedule shows no pause even when one was projected")
    func disabledScheduleShowsNoPause() {
        let snapshot = WidgetSnapshotBuilder.snapshot(
            schedule: S.schedule(isEnabled: false),
            projection: F.projection(start: F.at(45)),
            now: F.now
        )
        #expect(snapshot.nextPauseAt == nil)
        #expect(!snapshot.isScheduleEnabled)
        #expect(snapshot.mood == .sleep)
    }

    @Test("A pause the caregiver has chosen to skip is not counted down to")
    func skippedProjectionIsNotShown() {
        let snapshot = WidgetSnapshotBuilder.snapshot(
            schedule: S.schedule(),
            projection: F.projection(start: F.at(45), willBeSkipped: true),
            now: F.now
        )
        #expect(snapshot.nextPauseAt == nil)
        // The schedule is still on, so this is "waiting", not "asleep".
        #expect(snapshot.isScheduleEnabled)
        #expect(snapshot.mood == .idle)
    }

    @Test("A projection that has already arrived is not shown as upcoming")
    func duePauseIsNotUpcoming() {
        let snapshot = WidgetSnapshotBuilder.snapshot(
            schedule: S.schedule(),
            projection: F.projection(start: F.at(-1)),
            now: F.now
        )
        #expect(snapshot.nextPauseAt == nil)
    }

    @Test("No schedule at all is the empty state")
    func noSchedule() {
        let snapshot = WidgetSnapshotBuilder.emptySnapshot(now: F.now)
        #expect(snapshot.nextPauseAt == nil)
        #expect(!snapshot.isScheduleEnabled)
        #expect(snapshot.childDisplayName == nil)
        #expect(snapshot.mood == .sleep)
        #expect(snapshot.generatedAt == F.now)
    }

    // MARK: The reminder

    @Test("A pending Quick Reminder is carried alongside the pause, not merged")
    func reminderIsCarriedSeparately() {
        let snapshot = WidgetSnapshotBuilder.snapshot(
            schedule: S.schedule(),
            projection: F.projection(start: F.at(45)),
            quickReminder: F.reminder(fireAt: F.at(20)),
            now: F.now
        )
        #expect(snapshot.nextPauseAt == F.at(45))
        #expect(snapshot.quickReminderAt == F.at(20))
        #expect(snapshot.nextEvent(after: F.now) == F.at(20))
    }

    @Test("A fired or cancelled reminder contributes nothing")
    func terminalRemindersAreIgnored() {
        for state in [QuickReminderState.fired, .cancelled] {
            let snapshot = WidgetSnapshotBuilder.snapshot(
                schedule: S.schedule(),
                projection: nil,
                quickReminder: F.reminder(fireAt: F.at(20), state: state),
                now: F.now
            )
            #expect(snapshot.quickReminderAt == nil)
        }
    }

    @Test("A pending reminder whose instant has passed is due, not upcoming")
    func dueReminderIsIgnored() {
        let snapshot = WidgetSnapshotBuilder.snapshot(
            schedule: S.schedule(),
            projection: nil,
            quickReminder: F.reminder(fireAt: F.at(-1), createdAt: F.at(-20)),
            now: F.now
        )
        #expect(snapshot.quickReminderAt == nil)
    }

    @Test("A Quick Reminder alone wakes the widget even with the schedule off")
    func reminderWithoutSchedule() {
        let snapshot = WidgetSnapshotBuilder.snapshot(
            schedule: S.schedule(isEnabled: false),
            projection: nil,
            quickReminder: F.reminder(fireAt: F.at(5)),
            now: F.now
        )
        #expect(snapshot.quickReminderAt == F.at(5))
        #expect(!snapshot.isScheduleEnabled)
        #expect(snapshot.mood == .wave)
    }

    // MARK: A pause in progress

    @Test("A running pause is carried, and outranks the schedule for the mood")
    func runningPause() {
        let snapshot = WidgetSnapshotBuilder.snapshot(
            schedule: S.schedule(isEnabled: false),
            projection: nil,
            pauseEndsAt: F.at(3),
            now: F.now
        )
        #expect(snapshot.pauseEndsAt == F.at(3))
        #expect(snapshot.mood == .cheer)
        #expect(snapshot.isPauseRunning(at: F.now))
    }

    @Test("A pause whose end has passed is not running")
    func expiredPauseIsNotRunning() {
        let snapshot = WidgetSnapshotBuilder.snapshot(
            schedule: S.schedule(),
            projection: F.projection(start: F.at(45)),
            pauseEndsAt: F.at(-1),
            now: F.now
        )
        #expect(snapshot.pauseEndsAt == nil)
        #expect(snapshot.mood == .idle)
    }

    // MARK: Mood

    @Test(
        "Mood tracks how close the next appointment is",
        arguments: [
            (60.0, HopWidgetMood.idle),
            (10.5, HopWidgetMood.idle),
            (10.0, HopWidgetMood.wave),
            (5.0, HopWidgetMood.wave),
            (2.0, HopWidgetMood.jump),
            (0.5, HopWidgetMood.jump),
        ]
    )
    func moodByDistance(minutes: Double, expected: HopWidgetMood) {
        let snapshot = WidgetSnapshotBuilder.snapshot(
            schedule: S.schedule(),
            projection: F.projection(start: F.at(minutes)),
            now: F.now
        )
        #expect(snapshot.mood == expected)
    }

    @Test("The approach window and the fine timeline window are the same number")
    func windowsAgree() {
        // Stated as a test because the two constants are read by different
        // processes and a drift between them is invisible until a widget starts
        // spending its refresh budget on frames that do not change.
        #expect(WidgetSnapshotBuilder.approachWindow == WidgetTimelinePlan.fineWindow)
    }

    @Test("An enabled schedule with nothing projected is waiting, not asleep")
    func enabledButIdle() {
        let mood = WidgetSnapshotBuilder.mood(
            isScheduleEnabled: true,
            nextPauseAt: nil,
            quickReminderAt: nil,
            pauseEndsAt: nil,
            now: F.now
        )
        #expect(mood == .idle)
    }

    @Test("The mood picks the sooner of the two appointments")
    func moodUsesTheSooner() {
        let mood = WidgetSnapshotBuilder.mood(
            isScheduleEnabled: true,
            nextPauseAt: F.at(45),
            quickReminderAt: F.at(1),
            pauseEndsAt: nil,
            now: F.now
        )
        #expect(mood == .jump)
    }

    // MARK: The ScheduleState convenience

    @Test("Building from a ScheduleState projects through the real engine")
    func buildsFromScheduleState() throws {
        let state = ScheduleState(
            schedule: S.schedule(basis: .clockTime, interval: .minutes45),
            now: S.wednesday(9, 0)
        )
        let snapshot = WidgetSnapshotBuilder.snapshot(state: state, using: S.ny)

        let expected = try #require(S.ny.nextPause(after: state))
        #expect(snapshot.nextPauseAt == expected.start)
        #expect(snapshot.generatedAt == S.wednesday(9, 0))
        #expect(snapshot.isScheduleEnabled)
        #expect(snapshot.childDisplayName == nil)
    }

    // MARK: Privacy, restated as a test

    @Test("Nothing about the child's history can reach the snapshot")
    func snapshotCarriesNoHistory() throws {
        let snapshot = WidgetSnapshotBuilder.snapshot(
            schedule: S.schedule(),
            projection: F.projection(start: F.at(30)),
            quickReminder: F.reminder(fireAt: F.at(10)),
            childNickname: "Ellie",
            includeChildName: true,
            pauseEndsAt: nil,
            now: F.now
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let object = try #require(
            try JSONSerialization.jsonObject(with: encoder.encode(snapshot)) as? [String: Any]
        )

        // The whole field list, asserted by name. A new key has to be added here
        // deliberately, which is the point: `Docs/PrivacyArchitecture.md` §5 is a
        // boundary, and boundaries are kept by things that break when crossed.
        #expect(
            Set(object.keys) == [
                "schemaVersion",
                "nextPauseAt",
                "childDisplayName",
                "hopPoseName",
                "quickReminderAt",
                "isScheduleEnabled",
                "generatedAt",
            ]
        )
        for forbidden in [
            "childID", "events", "successes", "accidents", "stars", "streak",
            "applications", "shieldedAppCount", "selection", "outcome", "note",
        ] {
            #expect(object[forbidden] == nil)
        }
    }
}
