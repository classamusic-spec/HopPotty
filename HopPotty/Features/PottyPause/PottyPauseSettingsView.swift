import SwiftUI
import HopPottyCore
#if DEBUG
// Sample children live in their own module so they can never reach a real
// family's data. Previews are the only callers.
import HopPottyFixtures
#endif

/// The Potty Pause settings screen.
///
/// A `Form`, on purpose. This is the screen that most resembles Screen Time's
/// own settings, and a caregiver who has set an app limit in iOS already knows
/// how to read grouped rows with footers. The one thing that is not a standard
/// row is the schedule preview, which sits at the top: the settings below only
/// make sense once you can see the sentence they produce.
struct PottyPauseSettingsView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(ParentEnvironment.self) private var parent

    let childID: UUID

    @State private var model: PottyPauseSettingsModel?
    @State private var isRestoreGatePresented = false
    @State private var isScreenTimeGatePresented = false

    var body: some View {
        Form {
            if let model {
                previewSection(model)
                if model.needsAuthorization { authorizationSection(model) }
                modeSection(model)
                cadenceSection(model)
                pauseSection(model)
                windowSection(model)
                quietSection(model)
                appsSection(model)
                testSection(model)
                restoreSection(model)
                masterSwitchSection(model)
            } else {
                HopLoadingState(message: nil)
            }
        }
        .navigationTitle(Text(hop: HopCopy.timerSettings.title))
        .navigationBarTitleDisplayMode(.inline)
        .task { await ensureLoaded() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await model?.refreshScreenTime() }
        }
        .alert(
            model?.failure?.presentation.title ?? "",
            isPresented: Binding(
                get: { model?.failure != nil },
                set: { if !$0 { model?.dismissFailure() } }
            )
        ) {
            Button(HopCopy.errors.dismissButton.localized) { model?.dismissFailure() }
        } message: {
            Text(verbatim: model?.failure?.presentation.message ?? "")
        }
    }

    // MARK: Sections

    @ViewBuilder
    private func previewSection(_ model: PottyPauseSettingsModel) -> some View {
        if let summary = model.summary {
            Section {
                SchedulePreviewCard(summary: summary, calendar: parent.clock.calendar)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }

    /// Shown only when the chosen mode actually needs permission. Gentle mode
    /// never does, so this section disappears rather than nagging.
    private func authorizationSection(_ model: PottyPauseSettingsModel) -> some View {
        Section {
            if let presentation = model.authorizationStatus.deniedPresentation {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text(verbatim: presentation.title)
                        .font(theme.font(.parentHeadline))
                    Text(verbatim: presentation.message)
                        .font(theme.font(.parentFootnote))
                        .foregroundStyle(theme.color.textSecondary)
                }
                if presentation.recovery == .openSystemSettings, let url = ParentSystemSettings.url {
                    // Leaving the app is behind the gate: it is an external
                    // destination, and the gate exists for exactly that.
                    Button(HopCopy.common.openSettings.localized) { isScreenTimeGatePresented = true }
                        .hopParentGated(isPresented: $isScreenTimeGatePresented, reason: .changeSchedule) { _ in
                            openURL(url)
                        }
                }
            }
        }
    }

    private func modeSection(_ model: PottyPauseSettingsModel) -> some View {
        Section {
            Picker(HopCopy.timerSettings.modeLabel.localized, selection: modeBinding(model)) {
                ForEach(PottyPauseMode.allCases) { mode in
                    Text(verbatim: mode.parentTitle).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(hop: HopCopy.timerSettings.modeLabel)
        } footer: {
            Text(verbatim: model.schedule.mode.parentDetail)
        }
    }

    private func cadenceSection(_ model: PottyPauseSettingsModel) -> some View {
        Section {
            Picker(HopCopy.timerSettings.basisLabel.localized, selection: basisBinding(model)) {
                ForEach(PottyTriggerBasis.allCases) { basis in
                    Text(verbatim: basis.parentTitle).tag(basis)
                }
            }
            .pickerStyle(.segmented)

            IntervalPicker(interval: intervalBinding(model))
        } header: {
            Text(hop: HopCopy.timerSettings.basisLabel)
        } footer: {
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(verbatim: model.schedule.triggerBasis.parentDetail)
                Text(verbatim: HopFeatureStrings.intervalDisclaimer)
            }
        }
    }

    private func pauseSection(_ model: PottyPauseSettingsModel) -> some View {
        Section {
            DurationStepperRow(
                title: HopCopy.timerSettings.warningLabel.localized,
                seconds: warningBinding(model),
                range: 0...600,
                step: 30,
                zeroTitle: HopCopy.timerSettings.warningOff.localized
            )
            DurationStepperRow(
                title: HopCopy.timerSettings.durationLabel.localized,
                seconds: durationBinding(model),
                range: PottySchedule.minimumPauseDuration...PottySchedule.maximumPauseDuration,
                step: 30
            )
            DurationStepperRow(
                title: HopCopy.timerSettings.cooldownLabel.localized,
                seconds: cooldownBinding(model),
                range: 0...1800,
                step: 60
            )
        } footer: {
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(hop: HopCopy.timerSettings.warningFooter)
                // The product guarantee, stated where the dial that could
                // appear to contradict it lives.
                Text(hop: HopCopy.timerSettings.durationFooter)
                Text(hop: HopCopy.timerSettings.cooldownFooter)
            }
        }
    }

    private func windowSection(_ model: PottyPauseSettingsModel) -> some View {
        Section {
            LocalTimePicker(
                time: activeStartBinding(model),
                label: HopFeatureStrings.activeHoursStart,
                calendar: parent.clock.calendar
            )
            LocalTimePicker(
                time: activeEndBinding(model),
                label: HopFeatureStrings.activeHoursEnd,
                calendar: parent.clock.calendar
            )
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(hop: HopCopy.timerSettings.activeDaysLabel)
                    .font(theme.font(.parentFootnote))
                    .foregroundStyle(theme.color.textSecondary)
                WeekdaySelector(selection: activeDaysBinding(model), calendar: parent.clock.calendar)
            }
        } header: {
            Text(hop: HopCopy.timerSettings.activeHoursLabel)
        }
    }

    private func quietSection(_ model: PottyPauseSettingsModel) -> some View {
        Section {
            NavigationLink {
                QuietHoursEditor(
                    windows: model.schedule.quietWindows,
                    calendar: parent.clock.calendar
                ) { windows in
                    Task { await model.setQuietWindows(windows) }
                }
            } label: {
                ParentValueRow(
                    title: HopCopy.timerSettings.quietTitle.localized,
                    value: model.schedule.quietWindows.isEmpty
                        ? HopCopy.timerSettings.quietEmpty.localized
                        : ParentFormat.count(model.schedule.quietWindows.count)
                )
            }
        } footer: {
            Text(hop: HopCopy.timerSettings.quietFooter)
        }
    }

    @ViewBuilder
    private func appsSection(_ model: PottyPauseSettingsModel) -> some View {
        if model.schedule.mode.shieldsApps || model.schedule.triggerBasis.requiresAppSelection {
            Section {
                AppSelectionSection(childID: childID) { _ in
                    Task { await model.refreshScreenTime() }
                }
            } header: {
                Text(hop: HopCopy.onboarding.appsTitle)
            } footer: {
                Text(hop: HopCopy.onboarding.appsBody)
            }
        }
    }

    @ViewBuilder
    private func testSection(_ model: PottyPauseSettingsModel) -> some View {
        Section {
            Button(HopFeatureStrings.testPauseRun) {
                Task { await model.runTestPause() }
            }
            .disabled(!model.canTestPause || model.isWorking)
            if model.testPauseSucceeded == true {
                Text(verbatim: HopFeatureStrings.testPauseSucceeded)
                    .font(theme.font(.parentFootnote))
                    .foregroundStyle(theme.color.success)
            }
        } footer: {
            Text(verbatim: HopFeatureStrings.testPauseBody)
        }
    }

    private func restoreSection(_ model: PottyPauseSettingsModel) -> some View {
        Section {
            Button(HopCopy.settings.emergencyTitle.localized) { isRestoreGatePresented = true }
                .hopParentGated(isPresented: $isRestoreGatePresented, reason: .changeSchedule) { _ in
                    Task { await model.restoreScreenAccess() }
                }
            if model.didRestoreAccess {
                Text(verbatim: HopFeatureStrings.restoreConfirmed)
                    .font(theme.font(.parentFootnote))
                    .foregroundStyle(theme.color.success)
            }
        } footer: {
            Text(hop: HopCopy.settings.emergencyFooter)
        }
    }

    private func masterSwitchSection(_ model: PottyPauseSettingsModel) -> some View {
        Section {
            Toggle(isOn: enabledBinding(model)) {
                Text(
                    hop: model.schedule.isEnabled
                        ? HopCopy.timerSettings.disableButton
                        : HopCopy.timerSettings.enableButton
                )
            }
        } footer: {
            Text(hop: HopCopy.timerSettings.disableFooter)
        }
    }

    private func ensureLoaded() async {
        if model == nil { model = PottyPauseSettingsModel(environment: parent, childID: childID) }
        await model?.load()
    }
}

#if DEBUG
// `@MainActor` because a file-scope `private func` is nonisolated by default,
// while `ParentEnvironment`, the design-system modifiers and the views
// themselves are all main-actor isolated. Every call site is a `#Preview` body,
// which is main-actor anyway, so the annotation states what was already true.
//
// Six file-scope preview helpers across the app have this exact shape. The
// compiler named four of them (one in run 60, three in run 66) and stopped;
// the other two were found by looking for the shape rather than waiting to be
// told. All six are annotated.
@MainActor
private func timerPreview(_ environment: ParentEnvironment) -> some View {
    NavigationStack { PottyPauseSettingsView(childID: HopFixtures.mayaChildID) }
        .environment(environment)
        .hopThemedRoot()
}

#Preview("Pause mode") { timerPreview(.preview()) }
#Preview("Permission denied") { timerPreview(.preview(authorization: .denied)) }
#Preview("Restricted device") { timerPreview(.preview(authorization: .restricted)) }
#Preview("AX3 dark") {
    timerPreview(.preview())
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}
#endif
