import SwiftUI
import HopPottyCore

// Bindings between the form's controls and the model's async setters.
//
// Each one reads from the model's current schedule and writes through the
// setter, which persists and recomputes the plain-language preview. Keeping
// them here rather than inline keeps the screen readable and makes it obvious
// that no control writes to the schedule directly.

extension PottyPauseSettingsView {

    func modeBinding(_ model: PottyPauseSettingsModel) -> Binding<PottyPauseMode> {
        Binding(
            get: { model.schedule.mode },
            set: { mode in Task { await model.setMode(mode) } }
        )
    }

    func basisBinding(_ model: PottyPauseSettingsModel) -> Binding<PottyTriggerBasis> {
        Binding(
            get: { model.schedule.triggerBasis },
            set: { basis in Task { await model.setTriggerBasis(basis) } }
        )
    }

    func intervalBinding(_ model: PottyPauseSettingsModel) -> Binding<PottyInterval> {
        Binding(
            get: { model.schedule.interval },
            set: { interval in Task { await model.setInterval(interval) } }
        )
    }

    func warningBinding(_ model: PottyPauseSettingsModel) -> Binding<TimeInterval> {
        Binding(
            get: { model.schedule.warningOffset },
            set: { offset in Task { await model.setWarningOffset(offset) } }
        )
    }

    func durationBinding(_ model: PottyPauseSettingsModel) -> Binding<TimeInterval> {
        Binding(
            get: { model.schedule.pauseDuration },
            set: { duration in Task { await model.setPauseDuration(duration) } }
        )
    }

    func cooldownBinding(_ model: PottyPauseSettingsModel) -> Binding<TimeInterval> {
        Binding(
            get: { model.schedule.cooldown },
            set: { cooldown in Task { await model.setCooldown(cooldown) } }
        )
    }

    func activeStartBinding(_ model: PottyPauseSettingsModel) -> Binding<LocalTimeOfDay> {
        Binding(
            get: { model.schedule.activeWindowStart },
            set: { start in
                Task { await model.setActiveWindow(start: start, end: model.schedule.activeWindowEnd) }
            }
        )
    }

    func activeEndBinding(_ model: PottyPauseSettingsModel) -> Binding<LocalTimeOfDay> {
        Binding(
            get: { model.schedule.activeWindowEnd },
            set: { end in
                Task { await model.setActiveWindow(start: model.schedule.activeWindowStart, end: end) }
            }
        )
    }

    func activeDaysBinding(_ model: PottyPauseSettingsModel) -> Binding<Set<Weekday>> {
        Binding(
            get: { model.schedule.activeDays },
            set: { days in Task { await model.setActiveDays(days) } }
        )
    }

    func enabledBinding(_ model: PottyPauseSettingsModel) -> Binding<Bool> {
        Binding(
            get: { model.schedule.isEnabled },
            set: { isEnabled in Task { await model.setEnabled(isEnabled) } }
        )
    }
}

/// A duration row: a value and a stepper, with a named zero.
///
/// "No warning" rather than "0 seconds": zero is a meaningful setting here, not
/// a number, and a caregiver reading "0 min" cannot tell whether the feature is
/// off or merely instantaneous.
struct DurationStepperRow: View {
    @Environment(\.hopTheme) private var theme

    let title: String
    @Binding var seconds: TimeInterval
    let range: ClosedRange<TimeInterval>
    let step: TimeInterval
    var zeroTitle: String? = nil

    var body: some View {
        Stepper(value: $seconds, in: range, step: step) {
            HStack {
                Text(verbatim: title)
                    .foregroundStyle(theme.color.textPrimary)
                Spacer()
                Text(verbatim: valueText)
                    .foregroundStyle(theme.color.textSecondary)
                    .monospacedDigit()
            }
        }
        .accessibilityValue(Text(verbatim: valueText))
    }

    private var valueText: String {
        if seconds <= 0, let zeroTitle { return zeroTitle }
        return ParentFormat.shortDuration(seconds)
    }
}
