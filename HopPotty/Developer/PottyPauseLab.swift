#if DEBUG
import SwiftUI
import HopPottyCore

/// The Potty Pause Lab: a diagnostic bench for the Screen Time layer.
///
/// ## What it is for
///
/// Nothing in this layer can be observed from a unit test. Whether the App Group
/// entitlement is right, whether the three extensions are installed and being
/// invoked, whether a shield actually appears, whether a stranded shield really
/// does heal itself — all of it is only knowable by holding a provisioned device
/// and looking. This screen is what makes looking possible, and it is the
/// instrument `Docs/PhysicalDeviceQA.md` tells a tester to read.
///
/// **It cannot ship.** The whole file is inside `#if DEBUG` and the only way in
/// is `View.developerSurface()`, which compiles to `self` in a release build. See
/// `DeveloperSurface.swift` for why the gate is the compiler rather than a flag.
///
/// ## The one privacy rule it keeps
///
/// It shows **counts, never identities**. There is no view here that renders an
/// application token, a bundle identifier, or a display name, and there is no
/// code path that could be extended into one without adding an API to
/// `ScreenTimeProviding` that does not exist. A debug screen is exactly where a
/// "just for testing" identity dump gets added and then forgotten, so the
/// restriction is the same one the shipping app lives under.
struct PottyPauseLab: View {

    let environment: ScreenTimeEnvironment

    @State private var snapshot: AppGroupSnapshot?
    @State private var lastAction: String = "—"
    @State private var registration: MonitoringRegistration?
    @State private var registrationError: ScreenTimeFailure?

    /// The schedule the Lab's own actions exercise. Not the caregiver's — the Lab
    /// must be able to test a 60-second pause without editing a family's settings.
    @State private var testPauseSeconds: Double = 60
    @State private var triggerBasis: PottyTriggerBasis = .screenActivity
    @State private var intervalMinutes: Double = 45

    private var testSchedule: PottySchedule {
        PottySchedule(
            childID: UUID(),
            mode: .pause,
            triggerBasis: triggerBasis,
            interval: PottyInterval(minutes: Int(intervalMinutes)),
            pauseDuration: testPauseSeconds
        )
    }

    var body: some View {
        NavigationStack {
            List {
                environmentSection
                authorizationSection
                selectionSection
                monitoringSection
                shieldSection
                heartbeatSection
                appGroupSection
                dangerSection
            }
            .navigationTitle("Potty Pause Lab")
            .navigationBarTitleDisplayMode(.inline)
            .monospaced()
            .font(.footnote)
            .task { refresh() }
            .refreshable { refresh() }
        }
    }

    // MARK: - Sections

    /// First, above everything, because a missing App Group entitlement makes
    /// every other reading on this screen meaningless.
    private var environmentSection: some View {
        Section("Environment") {
            row("App Group", ScreenTimeIdentifiers.appGroupID)
            row(
                "Container",
                snapshot?.isSharedContainerAvailable == true ? "reachable" : "UNREACHABLE",
                warn: snapshot?.isSharedContainerAvailable != true
            )
            row("ManagedSettings store", ScreenTimeIdentifiers.managedSettingsStoreName)
            row("Last action", lastAction)
        }
    }

    private var authorizationSection: some View {
        Section("Authorization") {
            row("Status", environment.screenTime.authorizationStatus.rawValue)
            row("Can shield", environment.screenTime.authorizationStatus.canShield ? "yes" : "no")
            row("Retry could help", environment.screenTime.authorizationStatus.isRetryable ? "yes" : "no")

            Button("Request authorization") {
                Task {
                    let result = await environment.screenTime.requestAuthorization()
                    lastAction = "requestAuthorization → \(describe(result))"
                    refresh()
                }
            }
            Button("Refresh status") {
                lastAction = "status → \(environment.screenTime.refreshAuthorizationStatus().rawValue)"
                refresh()
            }
            Button("Revoke authorization", role: .destructive) {
                Task {
                    let result = await environment.screenTime.revokeAuthorization()
                    lastAction = "revoke → \(describe(result))"
                    refresh()
                }
            }
        }
    }

    /// Counts only. See the type-level note.
    private var selectionSection: some View {
        Section("Selection (counts only — never identities)") {
            let summary = environment.screenTime.selectionSummary
            row("Applications", "\(summary.applicationCount)")
            row("Categories", "\(summary.categoryCount)")
            row("Web domains", "\(summary.webDomainCount)")
            row("Total", "\(summary.total)")
            row(
                "Within 50-token cap",
                summary.exceedsShieldLimit ? "NO" : "yes",
                warn: summary.exceedsShieldLimit
            )
            row("Payload on disk", snapshot?.hasSelectionData == true ? "present" : "absent")
        }
    }

    private var monitoringSection: some View {
        Section("Monitoring") {
            Picker("Basis", selection: $triggerBasis) {
                Text("screenActivity").tag(PottyTriggerBasis.screenActivity)
                Text("clockTime").tag(PottyTriggerBasis.clockTime)
            }
            .pickerStyle(.segmented)

            stepperRow("Interval", value: $intervalMinutes, range: 10...240, step: 5, unit: "min")

            row("Registered at", registration.map { stamp($0.registeredAt) } ?? "—")
            row("System reports", "\(environment.monitoring.monitoredActivityNames.count) activity(ies)")

            ForEach(environment.monitoring.monitoredActivityNames, id: \.self) { name in
                row("  ·", name)
            }

            if let registrationError {
                row("Error", registrationError.rawValue, warn: true)
            }

            // Every compromise the plan had to make, spelled out. This is the
            // screen where "your 10-minute clock cadence became 15 minutes" gets
            // noticed, rather than in a support email six weeks later.
            ForEach(Array((registration?.notes ?? []).enumerated()), id: \.offset) { _, note in
                row("  note", describe(note), warn: true)
            }

            Button("Register plan") {
                let plan = MonitoringPlan.make(
                    for: testSchedule,
                    hasSelection: !environment.screenTime.selectionSummary.isEmpty
                )
                environment.appGroup.saveGate(MonitoringGate(schedule: testSchedule))
                switch environment.monitoring.register(plan) {
                case .success(let result):
                    registration = result
                    registrationError = nil
                    lastAction = "register → \(result.activityNames.count) activity(ies)"
                case .failure(let failure):
                    registration = nil
                    registrationError = failure
                    lastAction = "register → \(failure.rawValue)"
                }
                refresh()
            }

            Button("Remove orphaned activities") {
                let removed = environment.monitoring.removeOrphanedMonitoring()
                lastAction = "orphans removed: \(removed.count)"
                refresh()
            }

            Button("Cancel all monitoring", role: .destructive) {
                environment.monitoring.cancelAllMonitoring()
                lastAction = "cancelAllMonitoring"
                refresh()
            }
        }
    }

    private var shieldSection: some View {
        Section("Shield") {
            row("Store requests a shield", environment.screenTime.believesShieldIsUp ? "YES" : "no")
            row("Pause state", snapshot?.pause?.state.rawValue ?? "— none —")
            row("Session", snapshot?.pause?.sessionID ?? "—")
            row("Planned end", snapshot?.pause.map { stamp($0.plannedEndAt) } ?? "—")
            row("Backstop end", snapshot?.pause.map { stamp($0.backstopEndAt) } ?? "—")
            row(
                "Verdict now",
                snapshot.map { describe(ShieldReconciler.decide($0)) } ?? "—"
            )
            row("Shield payload", snapshot?.hasShieldPresentation == true ? "present" : "MISSING (fallback copy)")

            // Copy drift between what the app publishes from `HopCopy` and what
            // the extension falls back to when the payload is missing. Shown
            // because a device with a broken App Group would otherwise display
            // different button labels from a healthy one, and nobody would know.
            row(
                "primary: HopCopy / fallback",
                "\(HopCopy.shield.primaryButton.value) / \(ShieldPresentation.fallback.primaryButtonLabel)",
                warn: HopCopy.shield.primaryButton.value != ShieldPresentation.fallback.primaryButtonLabel
            )
            row(
                "secondary: HopCopy / fallback",
                "\(HopCopy.shield.secondaryButton.value) / \(ShieldPresentation.fallback.secondaryButtonLabel ?? "—")",
                warn: HopCopy.shield.secondaryButton.value != ShieldPresentation.fallback.secondaryButtonLabel
            )

            stepperRow("Test pause", value: $testPauseSeconds, range: 60...600, step: 30, unit: "s")

            // "Trigger test" — the full path a real trigger takes, so the shield,
            // the backstop and the extension callbacks are all exercised together.
            Button("Trigger a pause now") {
                switch environment.screenTime.applyShield(plannedDuration: testPauseSeconds, now: Date()) {
                case .success(let record):
                    environment.monitoring.registerBackstop(for: record)
                    lastAction = "pause \(record.sessionID.prefix(8)) → ends \(stamp(record.plannedEndAt))"
                case .failure(let failure):
                    lastAction = "applyShield → \(failure.rawValue)"
                }
                refresh()
            }

            Button("Shield now (no session)") {
                // Deliberately raises a shield with no App Group record behind it.
                // This is the stranded-shield case, staged on purpose: the correct
                // outcome is that the very next reconciliation — including one
                // from the shield configuration extension, before any tap — clears
                // it. If it does not, the fail-safe is broken and this is how you
                // find out.
                _ = environment.screenTime.applyShield(plannedDuration: 60, now: Date())
                environment.appGroup.clearPause()
                lastAction = "orphan shield staged — expect auto-clear"
                refresh()
            }

            Button("Clear shield") {
                environment.screenTime.clearShield(reason: .manual)
                lastAction = "clearShield(manual)"
                refresh()
            }

            Button("Reconcile now") {
                let verdict = environment.screenTime.reconcile(now: Date())
                lastAction = "reconcile → \(describe(verdict))"
                refresh()
            }

            Button("Restore screen access (emergency path)") {
                environment.screenTime.restoreScreenAccess()
                lastAction = "restoreScreenAccess"
                refresh()
            }
            .tint(.green)
        }
    }

    /// The only way to know an extension is installed, signed, and being invoked.
    /// A dash here after a shield has been drawn means the extension is not
    /// running at all — a provisioning or target-membership problem, not a logic
    /// one.
    private var heartbeatSection: some View {
        Section("Extension heartbeats") {
            ForEach(AppGroupStore.HeartbeatTarget.allCases, id: \.rawValue) { target in
                let beat = snapshot?.heartbeats[target] ?? nil
                row(
                    target.rawValue,
                    beat.map { stamp($0) } ?? "— never —",
                    warn: beat == nil && target != .app
                )
            }
            row("Outbox", "\(snapshot?.reportCount ?? 0) report(s)")
            row("Grown-up requested", environment.appGroup.hasGrownUpRequest() ? "YES" : "no")

            Button("Drain reports") {
                let reports = environment.screenTime.drainExtensionReports()
                lastAction = "drained \(reports.count): "
                    + reports.map { "\($0.source.rawValue)/\($0.kind.rawValue)" }.joined(separator: ", ")
                refresh()
            }
        }
    }

    private var appGroupSection: some View {
        Section("App Group dump") {
            ForEach(Array((snapshot?.debugDump ?? []).enumerated()), id: \.offset) { _, line in
                Text(line).font(.caption2.monospaced())
            }
        }
    }

    private var dangerSection: some View {
        Section("Reset") {
            Button("Reset Screen Time environment", role: .destructive) {
                // Order matters even here: the shield comes down before the record
                // that describes it is destroyed. Wiping the container first would
                // leave a live shield that nothing on the device can explain, which
                // is the exact situation the Lab exists to prevent.
                environment.screenTime.restoreScreenAccess()
                environment.monitoring.cancelAllMonitoring()
                environment.appGroup.reset()
                registration = nil
                registrationError = nil
                lastAction = "environment reset"
                refresh()
            }
            Text("Clears the shield, stops every HopPotty activity, and empties the App Group container. Does not touch the caregiver's selection in Settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func refresh() {
        snapshot = environment.screenTime.appGroupSnapshot(now: Date())
    }

    private func row(_ label: String, _ value: String, warn: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(warn ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
        }
    }

    private func stepperRow(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String
    ) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)")
            }
        }
    }

    private func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func describe(_ verdict: ShieldReconciler.Verdict) -> String {
        switch verdict {
        case .leaveShieldUp: "leave up"
        case .clearShield(let reason): "clear(\(reason.rawValue))"
        }
    }

    private func describe<T>(_ result: Result<T, ScreenTimeFailure>) -> String {
        switch result {
        case .success: "ok"
        case .failure(let failure): failure.rawValue
        }
    }

    private func describe(_ note: MonitoringPlan.Note) -> String {
        switch note {
        case .nothingToMonitor: "nothing to monitor"
        case .selectionRequired: "selection required"
        case .cadenceRaisedToPlatformMinimum(let requested, let actual):
            "cadence \(requested)m → \(actual)m (platform floor)"
        case .clockSlotsTruncated(let requested, let registered):
            "slots \(requested) → \(registered)"
        case .usageLadderTruncated(let requested, let registered):
            "ladder \(requested) → \(registered)"
        case .activeWindowTooShort(let minutes):
            "active window \(minutes)m < 15m"
        }
    }
}

#Preview("Authorized") {
    PottyPauseLab(environment: .preview(.authorized))
}

#Preview("Shield stuck") {
    PottyPauseLab(environment: .preview(.shieldStuck))
}

#Preview("Broken App Group") {
    PottyPauseLab(environment: .preview(.brokenAppGroup))
}
#endif
