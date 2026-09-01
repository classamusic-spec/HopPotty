import Foundation
import SwiftUI
import HopPottyCore

/// How a logged event is named and coloured on the parent surfaces.
///
/// `accident` has an entry here like every other kind, and it is drawn from the
/// same neutral vocabulary: a label, a glyph and a tint. There is deliberately
/// no "isNegative", no severity and no ordering that puts it last — it is a
/// fact on a timeline (`Docs/CONTRACTS.md` §4.3).
extension PottyEventKind {
    var parentLabel: String {
        switch self {
        case .tried: HopCopy.parentHome.eventTried.localized
        case .pee: HopCopy.parentHome.eventPee.localized
        case .poop: HopCopy.parentHome.eventPoop.localized
        case .accident: HopCopy.parentHome.eventAccident.localized
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .tried: HopCopy.a11y.eventGlyphTried.localized
        case .pee: HopCopy.a11y.eventGlyphPee.localized
        case .poop: HopCopy.a11y.eventGlyphPoop.localized
        case .accident: HopCopy.a11y.eventGlyphAccident.localized
        }
    }

    /// The tint is decoration. Meaning always rides on `glyph` as well, so a
    /// caregiver who cannot separate the peach from the blue still reads the
    /// timeline (`Docs/CONTRACTS.md` §6).
    func tint(_ theme: HopTheme) -> Color {
        switch self {
        case .tried: theme.color.eventTried
        case .pee: theme.color.eventPee
        case .poop: theme.color.eventPoop
        case .accident: theme.color.eventAccident
        }
    }

    /// Display order for the metric row and the log sheet. `tried` leads
    /// because it is the primary event, not the consolation one.
    static var parentDisplayOrder: [PottyEventKind] { [.tried, .pee, .poop, .accident] }
}

extension PottyEventSource {
    /// Who wrote the entry down. Descriptive only — the source changes how much
    /// the insights engine trusts a timestamp, never how the event is judged.
    var parentLabel: String {
        switch self {
        case .childRoutine: HopCopy.parentHome.eventSourceChild.localized
        case .parentManual: HopCopy.parentHome.eventSourceParent.localized
        case .pauseCompletion: HopCopy.parentHome.eventSourcePause.localized
        case .restored: HopCopy.parentHome.eventSourcePause.localized
        }
    }
}

extension PottyPauseMode {
    var parentTitle: String {
        switch self {
        case .gentle: HopCopy.timerSettings.modeGentle.localized
        case .pause: HopCopy.timerSettings.modePause.localized
        case .routine: HopCopy.timerSettings.modeRoutine.localized
        }
    }

    var parentDetail: String {
        switch self {
        case .gentle: HopCopy.onboarding.modeGentleBody.localized
        case .pause: HopCopy.onboarding.modePauseBody.localized
        case .routine: HopCopy.onboarding.modeRoutineBody.localized
        }
    }
}

extension PottyTriggerBasis {
    var parentTitle: String {
        switch self {
        case .screenActivity: HopCopy.timerSettings.basisScreenActivity.localized
        case .clockTime: HopCopy.timerSettings.basisClockTime.localized
        }
    }

    var parentDetail: String {
        switch self {
        case .screenActivity: HopCopy.timerSettings.basisScreenActivityFooter.localized
        case .clockTime: HopCopy.timerSettings.basisClockTimeFooter.localized
        }
    }
}

extension QuietWindowLabel {
    var parentTitle: String {
        switch self {
        case .nap: HopCopy.timerSettings.quietLabelNap.localized
        case .bedtime: HopCopy.timerSettings.quietLabelBedtime.localized
        case .school: HopCopy.timerSettings.quietLabelSchool.localized
        case .mealtime: HopCopy.timerSettings.quietLabelMealtime.localized
        case .custom: HopCopy.timerSettings.quietLabelCustom.localized
        }
    }

    var systemImage: String {
        switch self {
        case .nap: "moon.zzz.fill"
        case .bedtime: "bed.double.fill"
        case .school: "backpack.fill"
        case .mealtime: "fork.knife"
        case .custom: "moon.fill"
        }
    }
}

/// One day's worth of timeline rows, grouped for a sectioned list.
struct TimelineDay: Identifiable, Equatable {
    let id: Date
    let title: String
    let events: [PottyEvent]

    /// Groups events into local days, newest day first and newest event first
    /// inside each day — the order a caregiver scans.
    static func group(
        _ events: [PottyEvent],
        calendar: Calendar,
        locale: Locale = .current
    ) -> [TimelineDay] {
        let buckets = Dictionary(grouping: events) { calendar.startOfDay(for: $0.timestamp) }
        return buckets.keys.sorted(by: >).map { day in
            TimelineDay(
                id: day,
                title: ParentFormat.relativeDay(day, calendar: calendar, locale: locale),
                events: (buckets[day] ?? []).sorted { $0.timestamp > $1.timestamp }
            )
        }
    }
}
