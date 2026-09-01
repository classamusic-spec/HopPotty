import SwiftUI
import HopPottyCore

// Screens 4–5: how assertively HopPotty interrupts, and how often.

/// 4. Choose Routine — Gentle / Pause / Guided routine.
///
/// The three modes are presented as equals. Gentle is not "the lesser option"
/// and is not styled as one: a family that only ever wants a reminder is using
/// HopPotty correctly, and it is also the only mode that needs no permission at
/// all.
struct ChooseRoutineScreen: View {
    @Environment(\.hopTheme) private var theme
    let model: OnboardingModel

    var body: some View {
        OnboardingScaffold(
            title: HopCopy.onboarding.modeTitle.localized,
            message: nil,
            primaryTitle: HopCopy.common.next.localized,
            canGoBack: model.canGoBack,
            onPrimary: model.advance,
            onBack: model.goBack
        ) {
            VStack(spacing: theme.spacing.s) {
                ForEach(PottyPauseMode.allCases) { mode in
                    ModeOptionRow(
                        mode: mode,
                        isSelected: model.draft.mode == mode,
                        action: { model.setMode(mode) }
                    )
                }
            }
        }
    }
}

/// One selectable mode. A radio row rather than a card grid: a caregiver has to
/// be able to read three paragraphs and compare them, and three columns of
/// truncated text does not let them.
struct ModeOptionRow: View {
    @Environment(\.hopTheme) private var theme
    let mode: PottyPauseMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: theme.spacing.m) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? theme.color.brandAction : theme.color.textTertiary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    Text(verbatim: mode.parentTitle)
                        .font(theme.font(.parentHeadline))
                        .foregroundStyle(theme.color.textPrimary)
                    Text(verbatim: mode.parentDetail)
                        .font(theme.font(.parentCallout))
                        .foregroundStyle(theme.color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(theme.spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                    .fill(theme.color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                    .strokeBorder(
                        isSelected ? theme.color.brandAction : theme.color.divider,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// 5. Timer interval.
struct IntervalScreen: View {
    @Environment(\.hopTheme) private var theme
    let model: OnboardingModel

    var body: some View {
        OnboardingScaffold(
            title: HopCopy.onboarding.rhythmTitle.localized,
            message: HopCopy.onboarding.rhythmBody.localized,
            primaryTitle: HopCopy.common.next.localized,
            canGoBack: model.canGoBack,
            onPrimary: model.advance,
            onBack: model.goBack
        ) {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                IntervalPicker(
                    interval: Binding(
                        get: { model.draft.interval },
                        set: { model.setInterval($0) }
                    )
                )

                // The required sentence. It is not a footnote in small grey
                // type: a parent choosing "how often should my child go" is
                // exactly the person who might read a number here as advice.
                Text(verbatim: HopFeatureStrings.intervalDisclaimer)
                    .font(theme.font(.parentCallout))
                    .foregroundStyle(theme.color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(theme.spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radius.m, style: .continuous)
                            .fill(theme.color.surfaceSunken)
                    )
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }
}

/// The preset row plus a custom stepper, shared by onboarding and the timer
/// settings screen so the two can never offer different choices.
struct IntervalPicker: View {
    @Environment(\.hopTheme) private var theme
    @Binding var interval: PottyInterval

    private var isCustom: Bool { !PottyInterval.presets.contains(interval) }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            Picker(HopCopy.timerSettings.intervalLabel.localized, selection: presetSelection) {
                ForEach(PottyInterval.presets, id: \.minutes) { preset in
                    Text(verbatim: ParentFormat.count(preset.minutes)).tag(preset.minutes)
                }
                Text(hop: HopCopy.timerSettings.intervalCustom).tag(-1)
            }
            .pickerStyle(.segmented)

            if isCustom {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Stepper(
                        value: customBinding,
                        in: PottyInterval.customRange,
                        step: 5
                    ) {
                        Text(verbatim: ParentFormat.minutes(interval.minutes))
                            .font(theme.font(.parentHeadline))
                            .monospacedDigit()
                    }
                    Text(
                        verbatim: HopCopy.timerSettings.intervalCustomRange.localized(
                            .count(PottyInterval.customRange.lowerBound),
                            .count(PottyInterval.customRange.upperBound)
                        )
                    )
                    .font(theme.font(.parentFootnote))
                    .foregroundStyle(theme.color.textSecondary)
                }
            } else {
                Text(verbatim: ParentFormat.minutes(interval.minutes))
                    .font(theme.font(.parentHeadline))
                    .foregroundStyle(theme.color.textPrimary)
            }
        }
    }

    /// `-1` is the custom sentinel. Selecting it seeds the custom value from
    /// whatever preset was showing, so the stepper never starts from a number
    /// the caregiver did not choose.
    private var presetSelection: Binding<Int> {
        Binding(
            get: { isCustom ? -1 : interval.minutes },
            set: { minutes in
                if minutes == -1 {
                    let seeded = min(
                        max(interval.minutes + 5, PottyInterval.customRange.lowerBound),
                        PottyInterval.customRange.upperBound
                    )
                    interval = .custom(minutes: seeded)
                } else {
                    interval = PottyInterval(minutes: minutes)
                }
            }
        )
    }

    private var customBinding: Binding<Int> {
        Binding(
            get: { interval.minutes },
            set: { interval = PottyInterval(minutes: $0) }
        )
    }
}

#if DEBUG
#Preview("Choose routine") {
    ChooseRoutineScreen(model: .preview(step: .chooseRoutine))
        .hopThemedRoot()
}

#Preview("Interval, AX3") {
    IntervalScreen(model: .preview(step: .interval))
        .environment(\.dynamicTypeSize, .accessibility3)
        .hopThemedRoot()
}

#Preview("Interval, dark") {
    IntervalScreen(model: .preview(step: .interval))
        .preferredColorScheme(.dark)
        .hopThemedRoot()
}
#endif
