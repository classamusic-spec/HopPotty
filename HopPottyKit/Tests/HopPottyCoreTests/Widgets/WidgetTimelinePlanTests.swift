import Foundation
import Testing
@testable import HopPottyCore

@Suite("Widgets: the timeline plan")
struct WidgetTimelinePlanTests {
    typealias F = WidgetFixtures
    typealias Plan = WidgetTimelinePlan

    // MARK: Invariants that hold for every plan

    @Test(
        "Every plan starts at now, increases strictly, and stays inside the ceiling",
        arguments: [nil, -5.0, 0.0, 0.5, 3.0, 9.0, 10.0, 11.0, 45.0, 239.0, 240.0, 600.0]
    )
    func universalInvariants(minutes: Double?) {
        let dates = Plan.entryDates(from: F.now, nextEvent: minutes.map(F.at))

        #expect(dates.first == F.now)
        #expect(!dates.isEmpty)
        #expect(dates.count <= Plan.maximumEntries)
        #expect(dates == dates.sorted())
        #expect(Set(dates).count == dates.count)
        #expect(dates.allSatisfy { $0 >= F.now })
        #expect(F.gaps(dates).allSatisfy { $0 > 0 })
    }

    // MARK: No appointment

    @Test("With nothing coming, entries are a quarter of an hour apart to the horizon")
    func lazyCadence() {
        let dates = Plan.entryDates(from: F.now, nextEvent: nil)
        #expect(F.gaps(dates).allSatisfy { $0 == Plan.coarseStep })
        // Four hours at fifteen minutes: now plus fifteen steps.
        #expect(dates.count == 16)
        #expect(dates.last == F.now.addingTimeInterval(Plan.horizon - Plan.coarseStep))
    }

    @Test("An appointment past the horizon is treated as no appointment")
    func beyondHorizon() {
        let far = Plan.entryDates(from: F.now, nextEvent: F.now.addingTimeInterval(Plan.horizon + 1))
        #expect(far == Plan.entryDates(from: F.now, nextEvent: nil))
    }

    @Test("An appointment already in the past is treated as no appointment")
    func pastEvent() {
        let past = Plan.entryDates(from: F.now, nextEvent: F.at(-1))
        #expect(past == Plan.entryDates(from: F.now, nextEvent: nil))
    }

    // MARK: An appointment far enough out to have both phases

    @Test("A distant appointment gets coarse entries, then a minute at a time")
    func twoPhases() throws {
        let event = F.at(45)
        let dates = Plan.entryDates(from: F.now, nextEvent: event)

        #expect(dates.contains(event))
        #expect(dates.last == event.addingTimeInterval(Plan.settleStep))

        // The last ten minutes are a minute apart, boundary included.
        let fineStart = event.addingTimeInterval(-Plan.fineWindow)
        let fine = dates.filter { $0 >= fineStart && $0 <= event }
        #expect(F.gaps(fine).allSatisfy { $0 == Plan.fineStep })
        #expect(fine.count == 11) // 35 through 45 minutes inclusive.
        #expect(fine.first == F.at(35))

        // Everything before the window is a quarter of an hour apart.
        let coarse = dates.filter { $0 < fineStart }
        #expect(F.gaps(coarse).allSatisfy { $0 == Plan.coarseStep })
        #expect(coarse == [F.now, F.at(15), F.at(30)])
    }

    @Test("The appointment itself is always an entry, whatever the arithmetic")
    func eventIsAlwaysAnEntry() {
        // 45 minutes divides by neither step cleanly once the fine window is
        // subtracted; 7 minutes is inside the window from the start; 15 minutes
        // lands exactly on a coarse boundary.
        for minutes in [1.0, 7.0, 15.0, 22.5, 45.0, 100.0, 239.0] {
            let event = F.at(minutes)
            #expect(Plan.entryDates(from: F.now, nextEvent: event).contains(event))
        }
    }

    // MARK: An appointment already inside the fine window

    @Test("An appointment inside ten minutes skips the coarse phase entirely")
    func alreadyClose() {
        let event = F.at(4)
        let dates = Plan.entryDates(from: F.now, nextEvent: event)
        #expect(dates == [F.now, F.at(1), F.at(2), F.at(3), F.at(4), F.at(5)])
    }

    @Test("An appointment less than a minute away is two entries and no countdown spam")
    func almostHere() {
        let event = F.at(0.5)
        let dates = Plan.entryDates(from: F.now, nextEvent: event)
        #expect(dates == [F.now, event, event.addingTimeInterval(Plan.settleStep)])
    }

    @Test("An appointment exactly at the window edge is still fully covered")
    func exactlyAtTheEdge() {
        let event = F.now.addingTimeInterval(Plan.fineWindow)
        let dates = Plan.entryDates(from: F.now, nextEvent: event)
        #expect(F.gaps(dates).allSatisfy { $0 == Plan.fineStep })
        #expect(dates.count == 12) // now, nine minute-steps, the event, the settle.
    }

    // MARK: The ceiling

    @Test("No plan can exceed the entry ceiling")
    func ceilingHolds() {
        for minutes in stride(from: 0.5, through: 240.0, by: 0.5) {
            let dates = Plan.entryDates(from: F.now, nextEvent: F.at(minutes))
            #expect(dates.count <= Plan.maximumEntries)
        }
    }

    @Test("The realistic worst case stays well under the ceiling")
    func worstCaseBudget() {
        // The most entries the shape can produce is an appointment far enough
        // away to fill the coarse phase and still reach the fine one.
        let worst = (1...480)
            .map { Plan.entryDates(from: F.now, nextEvent: F.at(Double($0) / 2)).count }
            .max() ?? 0
        #expect(worst <= 30)
        #expect(worst < Plan.maximumEntries)
    }

    // MARK: Snapshots

    @Test("A snapshot's plan pivots on the sooner of its two appointments")
    func snapshotPivot() {
        let snapshot = WidgetSnapshot(
            nextPauseAt: F.at(45),
            quickReminderAt: F.at(12),
            isScheduleEnabled: true,
            generatedAt: F.now
        )
        #expect(Plan.pivot(for: snapshot, at: F.now) == F.at(12))
        #expect(Plan.entryDates(for: snapshot, from: F.now).contains(F.at(12)))
    }

    @Test("While a pause is running the plan pivots on its end, not on the next one")
    func runningPausePivot() {
        let snapshot = WidgetSnapshot(
            nextPauseAt: F.at(45),
            quickReminderAt: F.at(12),
            isScheduleEnabled: true,
            pauseEndsAt: F.at(3),
            generatedAt: F.now
        )
        #expect(Plan.pivot(for: snapshot, at: F.now) == F.at(3))
    }

    @Test("An empty snapshot still produces a plan, on the lazy cadence")
    func emptySnapshotPlan() {
        let snapshot = WidgetSnapshot.empty(at: F.now)
        #expect(Plan.pivot(for: snapshot, at: F.now) == nil)
        #expect(Plan.entryDates(for: snapshot, from: F.now).count == 16)
    }

    // MARK: Refresh

    @Test("The refresh instant is the last entry, so a timeline is renewed as it runs out")
    func refreshIsTheLastEntry() {
        for minutes in [nil, 2.0, 12.0, 45.0, 300.0] as [Double?] {
            let event = minutes.map(F.at)
            let dates = Plan.entryDates(from: F.now, nextEvent: event)
            #expect(Plan.refreshDate(from: F.now, nextEvent: event) == dates.last)
        }
    }

    @Test("A refresh instant is always in the future")
    func refreshIsAlwaysAhead() {
        for minutes in [nil, -30.0, 0.0, 0.1, 1.0, 600.0] as [Double?] {
            #expect(Plan.refreshDate(from: F.now, nextEvent: minutes.map(F.at)) > F.now)
        }
    }

    @Test("An appointment at exactly now is already happening, so the plan goes lazy")
    func eventAtNow() {
        // Not a countdown to zero and not an empty timeline: the moment has
        // arrived, some other process is acting on it, and the widget's job is
        // to keep checking back on the ordinary cadence until it hears
        // otherwise.
        #expect(Plan.entryDates(from: F.now, nextEvent: F.now) == Plan.entryDates(from: F.now, nextEvent: nil))
        #expect(Plan.refreshDate(from: F.now, nextEvent: F.now) > F.now)
    }
}
