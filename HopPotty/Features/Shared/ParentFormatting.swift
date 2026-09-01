import Foundation
import HopPottyCore

/// Number, duration and clock formatting for the parent surfaces.
///
/// Everything here is locale-driven Foundation formatting, deliberately kept out
/// of `HopCopy`: a duration or a time of day has a shape the target language
/// owns, and a format string cannot express it. `HopCopy` supplies the sentence
/// and takes the formatted value as a `%N$@` slot — see
/// `HopCopyPlaceholderKind`.
enum ParentFormat {

    // MARK: Durations

    /// "12 min", "1 hr 5 min" — the compact form for a countdown or a metric.
    ///
    /// Rounded *up* to the next whole minute. A card that reads "0 min" while a
    /// pause is still 40 seconds away is telling a caregiver something untrue.
    static func shortDuration(_ interval: TimeInterval, locale: Locale = .current) -> String {
        let seconds = max(0, interval)
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar(for: locale)
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        if seconds < 60 {
            formatter.allowedUnits = [.second]
        } else if seconds < 3600 {
            formatter.allowedUnits = [.minute]
        } else {
            formatter.allowedUnits = [.hour, .minute]
        }
        let rounded = seconds < 60 ? seconds : (seconds / 60).rounded(.up) * 60
        return formatter.string(from: rounded) ?? ""
    }

    /// "12 minutes", "1 hour 5 minutes" — the form that sits inside a sentence.
    static func spelledDuration(_ interval: TimeInterval, locale: Locale = .current) -> String {
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar(for: locale)
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = interval < 3600 ? [.minute] : [.hour, .minute]
        return formatter.string(from: max(0, interval)) ?? ""
    }

    /// A whole number of minutes, spelled for a settings row.
    static func minutes(_ count: Int) -> String {
        HopCopy.timerSettings.intervalValue.localized(for: count)
    }

    // MARK: Clock and calendar

    /// "2:30 PM" in the caregiver's locale.
    static func clock(_ date: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        date.formatted(
            Date.FormatStyle(date: .none, time: .shortened, locale: locale, timeZone: timeZone)
        )
    }

    /// A wall-clock time with no date attached, resolved against today only so
    /// it can be handed to a formatter. Quiet hours are wall-clock values; see
    /// `LocalTimeOfDay`.
    static func clock(
        _ time: LocalTimeOfDay,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        let reference = calendar.resolving(time, on: Date()) ?? Date()
        return clock(reference, locale: locale, timeZone: calendar.timeZone)
    }

    static func timeSpan(
        _ start: LocalTimeOfDay,
        _ end: LocalTimeOfDay,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        HopCopy.timerSettings.activeHoursValue.localized(
            .text(clock(start, calendar: calendar, locale: locale)),
            .text(clock(end, calendar: calendar, locale: locale))
        )
    }

    /// "Today", "Yesterday", or a date. Used as a timeline section header.
    static func relativeDay(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// A period label for the Day/Week/Month picker's current selection.
    static func windowLabel(
        _ window: DateWindow,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        let lastDay = calendar.date(byAdding: .day, value: -1, to: window.end) ?? window.start
        if calendar.isDate(window.start, inSameDayAs: lastDay) {
            return relativeDay(window.start, calendar: calendar, locale: locale)
        }
        let interval = DateInterval(start: window.start, end: lastDay)
        let formatter = DateIntervalFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: interval) ?? ""
    }

    /// The locale's own day names, in the locale's own order, for the active-day
    /// picker. Never a hard-coded "Mon Tue Wed": the week does not start on
    /// Monday everywhere.
    static func weekdayInitials(calendar: Calendar = .current, locale: Locale = .current) -> [(Weekday, String)] {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? []
        let ordered = orderedWeekdays(firstWeekday: calendar.firstWeekday)
        return ordered.map { day in
            let index = day.rawValue - 1
            let symbol = index < symbols.count ? symbols[index] : ""
            return (day, symbol)
        }
    }

    static func weekdayName(_ day: Weekday, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        let symbols = formatter.standaloneWeekdaySymbols ?? []
        let index = day.rawValue - 1
        return index < symbols.count ? symbols[index] : ""
    }

    /// `Weekday` is Sunday-first because `Calendar` is; the *display* order
    /// rotates to the locale's first weekday.
    static func orderedWeekdays(firstWeekday: Int) -> [Weekday] {
        let start = max(1, min(7, firstWeekday))
        return (0..<7).compactMap { offset in
            Weekday(rawValue: ((start - 1 + offset) % 7) + 1)
        }
    }

    // MARK: Counts

    static func count(_ value: Int, locale: Locale = .current) -> String {
        value.formatted(.number.locale(locale))
    }

    private static func calendar(for locale: Locale) -> Calendar {
        var calendar = Calendar.current
        calendar.locale = locale
        return calendar
    }
}
