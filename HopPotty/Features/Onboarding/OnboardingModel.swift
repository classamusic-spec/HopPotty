import Foundation
import Observation
import HopPottyCore

/// Drives onboarding: owns the state machine, persists it, and performs the
/// three side effects the flow has (asking for permissions, saving the child,
/// running a test pause).
@MainActor
@Observable
final class OnboardingModel {

    private(set) var state: OnboardingState
    private(set) var isWorking = false
    private(set) var failure: ParentFailure?
    /// Set when the flow finished and the app should show the dashboard.
    private(set) var isFinished = false
    /// Which way through the flow the last move went.
    ///
    /// The host needs it to pick the push or the pop transition, and only this
    /// object knows: `OnboardingState.goBack()` retraces `visited`, so the step
    /// alone cannot say whether it was reached by going on or by coming back.
    private(set) var isGoingBack = false

    private let environment: ParentEnvironment
    private let store: OnboardingStateStore

    init(
        environment: ParentEnvironment,
        store: OnboardingStateStore = OnboardingStateStore(),
        initialState: OnboardingState? = nil
    ) {
        self.environment = environment
        self.store = store
        // A saved state wins over the default, which is what makes an
        // interrupted setup resume rather than restart. `initialState` exists
        // for previews and tests, which must not read a device's defaults.
        self.state = initialState ?? store.load() ?? .initial
    }

    var step: OnboardingStep { state.step }
    var draft: OnboardingDraft { state.draft }

    // MARK: Navigation

    func advance() {
        isGoingBack = false
        state.advance()
        persist()
    }

    func goBack() {
        isGoingBack = true
        state.goBack()
        persist()
    }

    var canGoBack: Bool { state.previousStep != nil }

    // MARK: Draft edits

    func setNickname(_ nickname: String?) {
        state.draft.nickname = ChildProfile.sanitize(nickname)
        persist()
    }

    func setMode(_ mode: PottyPauseMode) {
        state.draft.mode = mode
        // Choosing gentle after being routed through a denial clears the
        // fallback note: the caregiver has now chosen gentle on purpose.
        if mode == .gentle, state.draft.authorizationStatus.canShield {
            state.draft.fellBackToGentle = false
        }
        persist()
    }

    func setInterval(_ interval: PottyInterval) {
        state.draft.interval = interval
        persist()
    }

    func setQuietWindows(_ windows: [QuietWindow]) {
        state.draft.quietWindows = windows
        persist()
    }

    // MARK: Permissions

    func requestScreenTimeAuthorization() async {
        isWorking = true
        defer { isWorking = false }
        let outcome = await environment.screenTime.requestAuthorization()
        state.apply(outcome)
        if case .failed(let screenTimeFailure) = outcome {
            failure = .screenTime(screenTimeFailure)
        } else {
            failure = nil
        }
        persist()
    }

    /// Re-reads authorization after a trip to the Settings app. Called when the
    /// flow comes back to the foreground, because the answer can change out
    /// from under HopPotty at any time.
    func refreshAuthorization() async {
        let status = environment.screenTime.authorizationStatus
        guard status != state.draft.authorizationStatus else { return }
        state.draft.authorizationStatus = status
        if status.canShield { state.draft.fellBackToGentle = false }
        persist()
    }

    func requestNotifications() async {
        isWorking = true
        defer { isWorking = false }
        state.draft.notificationPermission = await environment.notifications.requestPermission()
        persist()
    }

    func recordAppSelection(hasSelection: Bool) {
        state.draft.hasAppSelection = hasSelection
        persist()
    }

    // MARK: Test pause

    func runTestPause() async {
        guard let childID = await resolvedChildID() else { return }
        isWorking = true
        defer { isWorking = false }
        let schedule = state.draft.schedule(for: childID)
        let screenTimeFailure = environment.screenTime.startPauseNow(for: schedule)
        state.draft.didTestPauseSucceed = screenTimeFailure == nil
        failure = screenTimeFailure.map { ParentFailure.screenTime($0) }
        persist()
    }

    // MARK: Finishing

    /// Writes the child, the schedule and the settings, then clears the saved
    /// onboarding state.
    ///
    /// Everything is written at the end rather than screen by screen so an
    /// abandoned setup leaves no half-built child in the store — the draft is
    /// the record until the caregiver reaches the last screen.
    func finish() async {
        isWorking = true
        defer { isWorking = false }

        do {
            let profile: ChildProfile
            if let existing = environment.children.first {
                var updated = existing
                updated.nickname = state.draft.nickname
                updated.modifiedAt = environment.clock.now
                profile = updated
            } else {
                profile = state.draft.childProfile
            }
            try await environment.repositories.profiles.save(profile)
            try await environment.repositories.schedules.save(state.draft.schedule(for: profile.id))

            await environment.updateSettings { settings in
                settings.activeChildID = profile.id
                settings.hasCompletedOnboarding = true
                settings.warningNotificationsEnabled = state.draft.notificationPermission == .authorized
            }
            _ = environment.screenTime.applySchedule(state.draft.schedule(for: profile.id))
            await environment.reload()
            store.clear()
            isFinished = true
        } catch {
            failure = .saveFailed
        }
    }

    func dismissFailure() { failure = nil }

    /// The child the test pause runs for. During onboarding there may be no
    /// saved profile yet — the draft is the record until the final screen — so
    /// the store is consulted only as a fallback.
    private func resolvedChildID() async -> UUID? {
        if let id = environment.activeChild?.id { return id }
        return try? await environment.repositories.profiles.allProfiles().first?.id
    }

    private func persist() {
        store.save(state)
    }
}

/// Where an interrupted setup is kept.
///
/// `UserDefaults` rather than the SwiftData store on purpose: onboarding has to
/// survive even when the store failed to open, which is precisely the situation
/// where a caregiver most needs to reach a working app.
struct OnboardingStateStore {
    private let defaults: UserDefaults
    private let key = "com.hoppotty.onboarding.state"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> OnboardingState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(OnboardingState.self, from: data)
    }

    func save(_ state: OnboardingState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

#if DEBUG
extension OnboardingModel {
    /// A model pinned to one step, for previews. Uses a scratch `UserDefaults`
    /// suite so a preview never writes over a device's saved setup.
    static func preview(
        step: OnboardingStep,
        authorization: ScreenTimeAuthorizationStatus = .notDetermined,
        nickname: String? = "Maya",
        mode: PottyPauseMode = .pause
    ) -> OnboardingModel {
        var state = OnboardingState()
        state.step = step
        state.draft.nickname = nickname
        state.draft.mode = mode
        state.draft.authorizationStatus = authorization
        state.draft.fellBackToGentle = authorization == .denied || authorization == .restricted
        state.draft.hasAppSelection = authorization.canShield
        // Visited is the path *walked so far*, so "Back" in a preview behaves
        // the way it does on device.
        let path = state.plannedPath
        let index = path.firstIndex(of: step) ?? 0
        state.visited = Array(path.prefix(index + 1))
        return OnboardingModel(
            environment: .preview(authorization: authorization),
            store: OnboardingStateStore(defaults: UserDefaults(suiteName: "hoppotty.preview") ?? .standard),
            initialState: state
        )
    }
}
#endif
