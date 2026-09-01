import Foundation
import Testing
@testable import HopPottyCore

@Suite("Scheduling: schedule summary")
struct SchedulingSummaryTests {
    typealias F = SchedulingFixtures
    let service = SchedulingFixtures.ny
    let now = SchedulingFixtures.wednesday(9, 0)

    @Test("The headline sentence reads the way a caregiver would say it")
    func headlineSentence() {
        let schedule = F.schedule(quietWindows: [F.nap, F.bedtime], days: Weekday.weekdays)
        let summary = service.summarize(schedule, at: now)
        #expect(summary.english == """
            On weekdays, Hop will watch selected screen activity and trigger a \
            3-minute Potty Pause after 45 minutes of qualifying use, except \
            between 12:30–2:30 PM and after 7:30 PM.
            """)
    }

    @Test("The sentence is assembled from parts that survive without it")
    func structuredParts() {
        let schedule = F.schedule(quietWindows: [F.nap, F.bedtime], days: Weekday.weekdays)
        let summary = service.summarize(schedule, at: now)
        #expect(summary.days == .weekdays)
        #expect(summary.action == .pause(minutes: 3))
        #expect(summary.cadence == .afterQualifyingUse(minutes: 45))
        #expect(summary.activeWindow.start == LocalTimeOfDay(hour: 7, minute: 0))
        #expect(summary.activeWindow.end == LocalTimeOfDay(hour: 19, minute: 30))
        #expect(summary.status == .active)
        #expect(summary.exceptions == [
            .between(
                start: LocalTimeOfDay(hour: 12, minute: 30),
                end: LocalTimeOfDay(hour: 14, minute: 30),
                label: .nap,
                days: .weekdays
            ),
            // Bedtime and the closed active window describe the same stretch of
            // clock, so they collapse into one phrase — and the phrase keeps the
            // more specific label.
            .after(
                from: LocalTimeOfDay(hour: 19, minute: 30),
                until: LocalTimeOfDay(hour: 7, minute: 0),
                label: .bedtime,
                days: .weekdays
            ),
        ])
    }

    @Test("The two trigger bases read differently")
    func cadencePhrasing() {
        let clock = F.schedule(basis: .clockTime, interval: .minutes60)
        let summary = service.summarize(clock, at: now)
        #expect(summary.cadence == .everyClockInterval(minutes: 60))
        #expect(summary.english == """
            Every day, Hop will trigger a 3-minute Potty Pause every hour, \
            except after 7:30 PM.
            """)
    }

    @Test("Interval nouns read naturally at every scale")
    func intervalNouns() {
        #expect(ScheduleSummary.intervalNoun(45) == "45 minutes")
        #expect(ScheduleSummary.intervalNoun(60) == "1 hour")
        #expect(ScheduleSummary.intervalNoun(90) == "90 minutes")
        #expect(ScheduleSummary.intervalNoun(120) == "2 hours")
        // English drops the "1" after "every".
        #expect(ScheduleSummary.recurrenceNoun(60) == "hour")
        #expect(ScheduleSummary.recurrenceNoun(120) == "2 hours")
        #expect(ScheduleSummary.recurrenceNoun(45) == "45 minutes")

        let twoHourly = F.schedule(basis: .clockTime, interval: .custom(minutes: 120))
        #expect(service.summarize(twoHourly, at: now).english.contains("every 2 hours"))
        let ninety = F.schedule(interval: .minutes90)
        #expect(service.summarize(ninety, at: now).english.contains("after 90 minutes of qualifying use"))
    }

    @Test("Each pause mode names what actually happens")
    func modePhrasing() {
        let gentle = service.summarize(F.schedule(mode: .gentle), at: now)
        #expect(gentle.action == .reminder)
        #expect(gentle.english.contains("send a gentle reminder"))
        // Gentle mode never holds a screen, so the sentence carries no duration.
        #expect(!gentle.english.contains("3-minute"))

        let routine = service.summarize(F.schedule(mode: .routine), at: now)
        #expect(routine.action == .guidedRoutine(minutes: 3))
        #expect(routine.english.contains("start a 3-minute Potty Pause with the full routine"))

        let pause = service.summarize(F.schedule(mode: .pause), at: now)
        #expect(pause.english.contains("trigger a 3-minute Potty Pause"))
    }

    @Test("Day coverage collapses to the phrase a caregiver uses")
    func dayPhrases() {
        #expect(service.summarize(F.schedule(), at: now).english.hasPrefix("Every day, Hop will"))
        #expect(service.summarize(F.schedule(days: Weekday.weekdays), at: now).english.hasPrefix("On weekdays,"))
        #expect(service.summarize(F.schedule(days: Weekday.weekend), at: now).english.hasPrefix("On weekends,"))
        #expect(service.summarize(F.schedule(days: [.monday, .thursday]), at: now).english
            .hasPrefix("On Mondays and Thursdays,"))
        #expect(service.summarize(F.schedule(days: [.monday, .wednesday, .friday]), at: now).english
            .hasPrefix("On Mondays, Wednesdays, and Fridays,"))

        var decoded = F.schedule()
        decoded.activeDays = []
        #expect(service.summarize(decoded, at: now).days == .everyDay)
    }

    @Test("A quiet window narrower than the schedule says which days it applies on")
    func exceptionDayClause() {
        let schedule = F.schedule(quietWindows: [F.school, F.nap])
        let summary = service.summarize(schedule, at: now)
        #expect(summary.english == """
            Every day, Hop will watch selected screen activity and trigger a \
            3-minute Potty Pause after 45 minutes of qualifying use, except \
            between 9 AM–3 PM on weekdays, between 12:30–2:30 PM, and after 7:30 PM.
            """)
        #expect(summary.exceptions.first?.days == .weekdays)
        #expect(summary.exceptions.first?.label == .school)
    }

    @Test("A quiet window on days the schedule never runs is not mentioned")
    func irrelevantQuietWindowDropped() {
        let schedule = F.schedule(quietWindows: [F.school], days: Weekday.weekend)
        let summary = service.summarize(schedule, at: now)
        #expect(summary.exceptions.allSatisfy { $0.label != .school })
        #expect(!summary.english.contains("9 AM"))
    }

    @Test("A window swallowed by another is not repeated")
    func redundantWindowDropped() {
        // 20:00–22:00 sits inside the stretch the active window already closes.
        let evening = F.window(70, 20, 0, 22, 0, label: .custom)
        let summary = service.summarize(F.schedule(quietWindows: [evening]), at: now)
        #expect(summary.exceptions.count == 1)
        #expect(summary.english.hasSuffix("except after 7:30 PM."))
    }

    @Test("A whole-day active window with no quiet hours has no exceptions")
    func noExceptions() {
        let summary = service.summarize(F.allDaySchedule(), at: now)
        #expect(summary.exceptions.isEmpty)
        #expect(summary.english == """
            Every day, Hop will watch selected screen activity and trigger a \
            3-minute Potty Pause after 45 minutes of qualifying use.
            """)
    }

    @Test("Exception phrases are ordered the way the day runs")
    func exceptionOrdering() {
        let morning = F.window(71, 0, 0, 8, 0, label: .bedtime)
        let midday = F.window(72, 12, 0, 13, 0, label: .mealtime)
        let schedule = F.allDaySchedule(quietWindows: [midday, morning])
        let summary = service.summarize(schedule, at: now)
        #expect(summary.exceptions == [
            .before(LocalTimeOfDay(hour: 8, minute: 0), label: .bedtime, days: .everyDay),
            .between(
                start: LocalTimeOfDay(hour: 12, minute: 0),
                end: LocalTimeOfDay(hour: 13, minute: 0),
                label: .mealtime,
                days: .everyDay
            ),
        ])
        #expect(summary.english.hasSuffix("except before 8 AM and between 12–1 PM."))
    }

    @Test("Times are written the way they are read aloud")
    func clockFormatting() {
        #expect(ScheduleSummary.clock(LocalTimeOfDay(hour: 0, minute: 0)) == "12 AM")
        #expect(ScheduleSummary.clock(LocalTimeOfDay(hour: 12, minute: 0)) == "12 PM")
        #expect(ScheduleSummary.clock(LocalTimeOfDay(hour: 7, minute: 0)) == "7 AM")
        #expect(ScheduleSummary.clock(LocalTimeOfDay(hour: 19, minute: 30)) == "7:30 PM")
        #expect(ScheduleSummary.clock(LocalTimeOfDay(hour: 0, minute: 5)) == "12:05 AM")
        // A range shares one meridiem when both ends agree, and spells out both
        // when they do not.
        #expect(ScheduleSummary.clockRange(
            LocalTimeOfDay(hour: 12, minute: 30), LocalTimeOfDay(hour: 14, minute: 30)
        ) == "12:30–2:30 PM")
        #expect(ScheduleSummary.clockRange(
            LocalTimeOfDay(hour: 11, minute: 30), LocalTimeOfDay(hour: 13, minute: 0)
        ) == "11:30 AM–1 PM")
    }

    @Test("A quiet window covering the whole day is stated, not swallowed")
    func allDayQuietWindow() {
        // Equal start and end means 24 hours of quiet. It is almost certainly a
        // mistake, and a settings screen can only offer to fix what it can see.
        let allDay = F.window(73, 8, 0, 8, 0, label: .custom)
        let summary = service.summarize(F.schedule(quietWindows: [allDay]), at: now)
        #expect(summary.exceptions == [.allDay(label: .custom, days: .everyDay)])
        #expect(summary.english.hasSuffix("except at any time."))
    }

    @Test("An active window that wraps midnight is described by its daytime gap")
    func wrappingActiveWindow() {
        let schedule = F.schedule(
            start: LocalTimeOfDay(hour: 20, minute: 0),
            end: LocalTimeOfDay(hour: 6, minute: 0)
        )
        let summary = service.summarize(schedule, at: now)
        #expect(summary.exceptions == [
            .between(
                start: LocalTimeOfDay(hour: 6, minute: 0),
                end: LocalTimeOfDay(hour: 20, minute: 0),
                label: .custom,
                days: .everyDay
            ),
        ])
        #expect(summary.english.hasSuffix("except between 6 AM–8 PM."))
    }

    // MARK: Status

    @Test("A schedule that is off is not described as if it were running")
    func disabledStatus() {
        let summary = service.summarize(F.schedule(isEnabled: false), at: now)
        #expect(summary.status == .disabled)
        #expect(summary.english == "Potty Pause is off.")
        // The description is still there for a settings screen to show.
        #expect(summary.sentence.contains("trigger a 3-minute Potty Pause"))
    }

    @Test("A hold is appended, not substituted")
    func suspendedStatuses() {
        let indefinite = service.summarize(F.schedule(suspension: .indefinite), at: now)
        #expect(indefinite.status == .suspendedIndefinitely)
        #expect(indefinite.english.hasSuffix("Potty Pause is paused until you turn it back on."))

        let tomorrow = service.summarize(
            F.schedule(suspension: .untilTomorrow(from: F.wednesday(8, 0))), at: now
        )
        #expect(tomorrow.status == .suspendedUntilTomorrow(resumesAt: F.nyAt(2025, 6, 12, 0, 0)))
        #expect(tomorrow.english.hasSuffix("Paused until tomorrow."))

        let sameDay = service.summarize(F.schedule(suspension: .until(F.wednesday(15, 0))), at: now)
        #expect(sameDay.english.hasSuffix("Paused until 3 PM."))

        let otherDay = service.summarize(F.schedule(suspension: .until(F.friday(15, 0))), at: now)
        #expect(otherDay.english.hasSuffix("Paused until Friday at 3 PM."))

        let skip = service.summarize(F.schedule(suspension: .skipNext), at: now)
        #expect(skip.status == .skippingNextPause)
        #expect(skip.english.hasSuffix("The next Potty Pause will be skipped."))
    }

    @Test("An expired hold is not reported as still holding")
    func expiredHoldStatus() {
        let summary = service.summarize(F.schedule(suspension: .until(F.wednesday(8, 0))), at: now)
        #expect(summary.status == .active)
        #expect(!summary.english.contains("Paused"))
    }

    @Test("The status clause follows the wall clock of the zone it is read in")
    func statusFollowsZone() {
        // 15:00 in New York is 00:30 the next morning in Kolkata, so the same hold
        // reads differently — correctly — on each side of the flight.
        let schedule = F.schedule(suspension: .until(F.wednesday(15, 0)))
        #expect(SchedulingFixtures.ny.summarize(schedule, at: now).english.hasSuffix("Paused until 3 PM."))
        #expect(SchedulingFixtures.kol.summarize(schedule, at: now).english.hasSuffix("Paused until Thursday at 12:30 AM."))
    }

    // MARK: Copy safety

    @Test("No summary contains shame language")
    func noShameLanguage() {
        // `Docs/CONTRACTS.md` §4.4. These summaries are parent-facing, but the
        // vocabulary rule is the product's, not the screen's.
        let banned = ["failed", "fail", "wrong", "lost", "disappointed", "no stars", "accident", "bad"]
        let schedules = [
            F.schedule(quietWindows: [F.nap, F.bedtime], days: Weekday.weekdays),
            F.schedule(mode: .gentle),
            F.schedule(mode: .routine, basis: .clockTime),
            F.schedule(isEnabled: false),
            F.schedule(suspension: .skipNext),
            F.schedule(suspension: .indefinite),
            F.allDaySchedule(quietWindows: [F.school]),
        ]
        for schedule in schedules {
            let english = service.summarize(schedule, at: now).english.lowercased()
            for word in banned {
                #expect(!english.contains(word), "\"\(word)\" in: \(english)")
            }
        }
    }

    @Test("Summarising is deterministic regardless of stored window order")
    func deterministicAcrossWindowOrder() {
        let forwards = F.schedule(quietWindows: [F.nap, F.bedtime, F.school])
        let backwards = F.schedule(quietWindows: [F.school, F.bedtime, F.nap])
        #expect(service.summarize(forwards, at: now).english == service.summarize(backwards, at: now).english)
        #expect(service.summarize(forwards, at: now).exceptions == service.summarize(backwards, at: now).exceptions)
    }
}
