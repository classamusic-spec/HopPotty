import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import HopPottyCore

/// The iOS Settings app, when the fix for a problem lives outside HopPotty.
enum ParentSystemSettings {
    static var url: URL? {
        #if canImport(UIKit)
        return URL(string: UIApplication.openSettingsURLString)
        #else
        return nil
        #endif
    }
}

/// A wall-clock picker for a `LocalTimeOfDay`.
///
/// The binding converts through today's date and throws the date away again.
/// That is the whole point of `LocalTimeOfDay`: "naps start at 12:30" must stay
/// 12:30 across a daylight-saving boundary and across a time zone, and storing
/// the `Date` the picker produced would silently move it.
struct LocalTimePicker: View {
    // `@ViewBuilder` because the two branches are different concrete types.
    @Binding var time: LocalTimeOfDay
    var label: String? = nil
    var calendar: Calendar = .current

    @ViewBuilder
    var body: some View {
        if let label {
            DatePicker(label, selection: dateBinding, displayedComponents: .hourAndMinute)
        } else {
            DatePicker("", selection: dateBinding, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { calendar.resolving(time, on: Date()) ?? Date() },
            set: { newDate in
                let components = calendar.dateComponents([.hour, .minute], from: newDate)
                time = LocalTimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0)
            }
        )
    }
}

/// The seven-day selector.
///
/// Days are drawn in the locale's own order starting from `calendar.firstWeekday`,
/// and labelled from the locale's own symbols. A hard-coded "M T W T F S S" is
/// wrong in most of the world and unreadable in several writing systems.
struct WeekdaySelector: View {
    @Environment(\.hopTheme) private var theme
    @Binding var selection: Set<Weekday>
    var calendar: Calendar = .current

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            ForEach(ParentFormat.weekdayInitials(calendar: calendar), id: \.0) { day, symbol in
                let isOn = selection.isEmpty || selection.contains(day)
                Button {
                    toggle(day)
                } label: {
                    Text(verbatim: symbol)
                        .font(theme.font(.parentCallout))
                        .frame(maxWidth: .infinity)
                        .frame(height: theme.hitTarget.parent)
                        .background(
                            RoundedRectangle(cornerRadius: theme.radius.s, style: .continuous)
                                .fill(isOn ? theme.color.brandAction : theme.color.surfaceSunken)
                        )
                        .foregroundStyle(isOn ? theme.color.textOnBrand : theme.color.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: ParentFormat.weekdayName(day, calendar: calendar)))
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    /// An empty set means every day everywhere in HopPotty, so turning the last
    /// day off falls back to every day rather than to a schedule that can never
    /// run. A caregiver who wants nothing to run uses the master switch, which
    /// says what it does.
    private func toggle(_ day: Weekday) {
        var updated = selection.isEmpty ? Weekday.everyDay : selection
        if updated.contains(day) {
            updated.remove(day)
        } else {
            updated.insert(day)
        }
        selection = updated.isEmpty ? Weekday.everyDay : updated
    }
}

/// The label every insight travels with.
///
/// A view rather than a string at each call site, so no surface can render an
/// observation without it — `Docs/CONTRACTS.md` §4.5, and
/// `InsightConfidence.disclaimerRequired`, which has no code path returning
/// `false`.
struct InsightDisclaimerLabel: View {
    @Environment(\.hopTheme) private var theme

    var body: some View {
        Text(verbatim: InsightConfidence.disclaimer)
            .font(theme.font(.parentFootnote))
            .foregroundStyle(theme.color.textSecondary)
            .accessibilityAddTraits(.isStaticText)
    }
}

/// A labelled value row for a read-only fact. The shape Apple's own settings
/// screens use for "Version 1.0 (12)".
struct ParentValueRow: View {
    @Environment(\.hopTheme) private var theme
    let title: String
    let value: String?

    var body: some View {
        HStack {
            Text(verbatim: title)
                .foregroundStyle(theme.color.textPrimary)
            Spacer()
            if let value {
                Text(verbatim: value)
                    .foregroundStyle(theme.color.textSecondary)
            }
        }
        .font(theme.font(.parentBody))
        .accessibilityElement(children: .combine)
    }
}
