import SwiftUI
import HopPottyCore

/// Settings.
///
/// A plain grouped `Form`. Everything a caregiver already knows about iOS
/// settings — where the switches are, what a footer means, that a chevron pushes
/// — applies here unchanged, which is worth more than any bespoke layout.
struct SettingsRootView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(ParentEnvironment.self) private var parent

    @State private var model: SettingsModel?
    @State private var gate: SettingsGateRequest?
    @State private var isRestoreGatePresented = false

    var body: some View {
        Form {
            if let model {
                if !model.isStoreAvailable { storeWarningSection }
                childrenSection(model)
                soundSection(model)
                experienceSection(model)
                notificationsSection(model)
                pauseSection(model)
                purchaseSection(model)
                gateSection(model)
                restoreSection(model)
                privacySection(model)
                aboutSection(model)
                debugSection
            } else {
                HopLoadingState(message: nil)
            }
        }
        .navigationTitle(Text(hop: HopCopy.settings.title))
        .task { if model == nil { model = SettingsModel(environment: parent) } }
        // Applied *outside* the gate host so the host's own sheets read the
        // caregiver's chosen style. An `.environment` set inside would only
        // reach descendants, and the host is not one.
        .modifier(SettingsGateHost(request: $gate, model: model))
        .environment(\.parentGateStyle, parent.settings.parentGateStyle)
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

    private var storeWarningSection: some View {
        Section {
            Text(verbatim: HopFeatureStrings.settingsStoreUnavailable)
                .font(theme.font(.parentCallout))
                .foregroundStyle(theme.color.warning)
        }
    }

    private func childrenSection(_ model: SettingsModel) -> some View {
        Section {
            ForEach(model.children) { child in
                NavigationLink {
                    ChildProfileEditor(childID: child.id)
                } label: {
                    ParentValueRow(
                        title: child.nickname ?? HopCopy.pond.title.unnamed.localized,
                        value: child.id == parent.activeChildID ? HopFeatureStrings.activeChildMarker : nil
                    )
                }
            }
            NavigationLink {
                ChildProfilesView()
            } label: {
                Label(hop: HopCopy.settings.childAdd, systemImage: "person.crop.circle.badge.plus")
            }
        } header: {
            Text(verbatim: HopFeatureStrings.settingsSectionChildren)
        } footer: {
            if !parent.canAddChild {
                Text(verbatim: PaywallFeature.additionalChildren.summary)
            }
        }
    }

    private func soundSection(_ model: SettingsModel) -> some View {
        Section {
            Toggle(HopCopy.settings.soundVoice.localized, isOn: binding(\.hopVoiceEnabled, model))
            Toggle(HopCopy.settings.soundEffects.localized, isOn: binding(\.soundEffectsEnabled, model))
            Toggle(HopCopy.settings.soundAmbient.localized, isOn: binding(\.ambientAudioEnabled, model))
            Toggle(HopCopy.settings.soundHaptics.localized, isOn: binding(\.hapticsEnabled, model))
            Toggle(HopCopy.settings.soundCaptions.localized, isOn: binding(\.spokenTextCaptionsEnabled, model))
        } header: {
            Text(hop: HopCopy.settings.sectionSound)
        } footer: {
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(hop: HopCopy.settings.soundVoiceFooter)
                Text(hop: HopCopy.settings.soundCaptionsFooter)
            }
        }
    }

    private func experienceSection(_ model: SettingsModel) -> some View {
        Section {
            Toggle(HopCopy.settings.experienceGames.localized, isOn: binding(\.miniGamesEnabled, model))
            Toggle(HopCopy.settings.experienceQuizzes.localized, isOn: binding(\.quizzesEnabled, model))
            Toggle(HopCopy.settings.experienceSitTimer.localized, isOn: binding(\.routineSitTimerEnabled, model))
        } header: {
            Text(hop: HopCopy.settings.sectionExperience)
        } footer: {
            Text(hop: HopCopy.settings.experienceSitTimerFooter)
        }
    }

    private func notificationsSection(_ model: SettingsModel) -> some View {
        Section {
            Toggle(
                HopCopy.settings.notificationsWarning.localized,
                isOn: binding(\.warningNotificationsEnabled, model)
            )
            Toggle(HopCopy.settings.notificationsSummary.localized, isOn: binding(\.dailySummaryEnabled, model))
            if model.settings.dailySummaryEnabled {
                LocalTimePicker(
                    time: summaryTimeBinding(model),
                    label: HopCopy.settings.notificationsSummaryTime.localized,
                    calendar: parent.clock.calendar
                )
            }
        } header: {
            Text(hop: HopCopy.settings.sectionNotifications)
        } footer: {
            if parent.notifications.permission == .denied {
                Text(hop: HopCopy.errors.notificationsDeniedBody)
            }
        }
    }

    @ViewBuilder
    private func pauseSection(_ model: SettingsModel) -> some View {
        if let childID = parent.activeChildID {
            Section {
                NavigationLink {
                    PottyPauseSettingsView(childID: childID)
                } label: {
                    Label(hop: HopCopy.timerSettings.title, systemImage: "timer")
                }
            }
        }
    }

    private func purchaseSection(_ model: SettingsModel) -> some View {
        Section {
            Button {
                gate = SettingsGateRequest(kind: .purchase)
            } label: {
                ParentValueRow(
                    title: HopCopy.purchase.title.localized,
                    value: model.entitlement.isUnlocked ? HopFeatureStrings.settingsPurchasedBadge : nil
                )
            }
        } header: {
            Text(verbatim: HopFeatureStrings.settingsSectionPurchase)
        } footer: {
            Text(hop: HopCopy.purchase.freeFooter)
        }
    }

    private func gateSection(_ model: SettingsModel) -> some View {
        Section {
            Picker(HopCopy.settings.sectionGate.localized, selection: gateStyleBinding(model)) {
                Text(hop: HopCopy.settings.gateStyleArithmetic).tag(ParentGateStyle.holdAndArithmetic)
                Text(hop: HopCopy.settings.gateStyleDeviceOwner).tag(ParentGateStyle.deviceOwner)
            }
            .pickerStyle(.inline)
            .disabled(!DeviceOwnerAuthenticator.isAvailable && model.settings.parentGateStyle == .holdAndArithmetic)
        } header: {
            Text(hop: HopCopy.settings.sectionGate)
        } footer: {
            if !DeviceOwnerAuthenticator.isAvailable {
                Text(verbatim: HopStrings.gateBiometricUnavailable)
            }
        }
    }

    private func restoreSection(_ model: SettingsModel) -> some View {
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

    private func privacySection(_ model: SettingsModel) -> some View {
        Section {
            Button(HopCopy.settings.privacyExport.localized) {
                gate = SettingsGateRequest(kind: .export)
            }
            if let childID = parent.activeChildID {
                Button(HopFeatureStrings.deleteChildAction, role: .destructive) {
                    gate = SettingsGateRequest(kind: .deleteChild(childID))
                }
            }
            Button(HopFeatureStrings.deleteEverythingAction, role: .destructive) {
                gate = SettingsGateRequest(kind: .deleteEverything)
            }
        } header: {
            Text(hop: HopCopy.settings.sectionPrivacy)
        } footer: {
            Text(hop: HopCopy.settings.privacyExportFooter)
        }
    }

    private func aboutSection(_ model: SettingsModel) -> some View {
        Section {
            ParentValueRow(title: HopCopy.brand.name.localized, value: model.appVersion)
            ExternalLinkRow(title: HopCopy.settings.aboutPrivacyPolicy.localized, url: HopLegalLinks.privacyPolicy)
            ExternalLinkRow(title: HopFeatureStrings.settingsTerms, url: HopLegalLinks.terms)
            ExternalLinkRow(title: HopCopy.settings.aboutSupport.localized, url: HopLegalLinks.support)
            NavigationLink {
                AcknowledgementsView()
            } label: {
                Text(hop: HopCopy.settings.aboutAcknowledgements)
            }
        } header: {
            Text(hop: HopCopy.settings.sectionAbout)
        }
    }

    @ViewBuilder
    private var debugSection: some View {
        #if DEBUG
        Section {
            NavigationLink {
                DebugLabPlaceholderView()
            } label: {
                Label(HopFeatureStrings.settingsDebugLab, systemImage: "wrench.and.screwdriver")
            }
        } footer: {
            Text(verbatim: HopFeatureStrings.settingsDebugLabFooter)
        }
        #endif
    }

    // MARK: Bindings

    private func binding(
        _ keyPath: WritableKeyPath<AppSettings, Bool>,
        _ model: SettingsModel
    ) -> Binding<Bool> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in model.update { $0[keyPath: keyPath] = newValue } }
        )
    }

    private func summaryTimeBinding(_ model: SettingsModel) -> Binding<LocalTimeOfDay> {
        Binding(
            get: { model.settings.dailySummaryTime },
            set: { newValue in model.update { $0.dailySummaryTime = newValue } }
        )
    }

    private func gateStyleBinding(_ model: SettingsModel) -> Binding<ParentGateStyle> {
        Binding(
            get: { model.settings.parentGateStyle },
            set: { newValue in model.update { $0.parentGateStyle = newValue } }
        )
    }
}
