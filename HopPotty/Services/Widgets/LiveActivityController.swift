import Foundation
import HopPottyCore
#if canImport(ActivityKit)
import ActivityKit
#endif

/// The port for the lock screen / Dynamic Island presentation of a running
/// pause.
///
/// Like `WidgetRefreshing`, **every method is allowed to do nothing.** A Live
/// Activity is a courtesy to the caregiver: it says "a pause is running and here
/// is how long is left". Nothing about the pause depends on it. The family may
/// have Live Activities switched off in Settings, the system may refuse the
/// request, the device may be an iPad with no Dynamic Island — and in every one
/// of those cases the shield still goes up, the routine still runs, and the four
/// end-paths in `Docs/ScreenTimeArchitecture.md` §9 still end it.
///
/// ## Why start and end are not symmetric
///
/// ``start(sessionID:isGuidedRoutine:startedAt:expectedEndAt:mood:)`` is
/// best-effort. ``end(at:)`` is not: an activity left running after a pause has
/// finished is a lock screen telling a family their child's apps are still held
/// when they are not, which is the one failure this layer can actually cause. So
/// `end` is called from every path that ends a pause, is idempotent, and ends
/// *any* activity it can find rather than only the one it started — a process
/// that was killed mid-pause leaves an activity behind that this instance never
/// requested.
@MainActor
protocol LiveActivityControlling: AnyObject {

    /// Whether the system will accept a request right now. Read-only, and never
    /// a reason to change what the pause does.
    var areActivitiesEnabled: Bool { get }

    /// Whether this controller currently has one running.
    var isRunning: Bool { get }

    func start(
        sessionID: String,
        isGuidedRoutine: Bool,
        startedAt: Date,
        expectedEndAt: Date,
        mood: HopWidgetMood
    )

    /// Move the running activity on: a routine step advanced, or the expected
    /// end moved. A no-op when nothing is running.
    func update(
        stepIndex: Int?,
        stepCount: Int?,
        expectedEndAt: Date?,
        mood: HopWidgetMood
    )

    /// End it now and take it off the lock screen.
    func end(at instant: Date)
}

// MARK: - Live

#if canImport(ActivityKit)

/// ActivityKit, wrapped so the rest of the app never imports it.
///
/// ## No pushes, ever
///
/// `Activity.request` is called with `pushType: nil`. HopPotty holds no
/// `aps-environment` entitlement and has no server (`Docs/PrivacyArchitecture.md`
/// §1), so there is nothing to push from and nothing that could. Every update
/// below happens in this process, while the app is running, which is exactly the
/// window a pause occupies.
///
/// ## Why the countdown is not updated per second
///
/// It is not updated at all. `PottyPauseAttributes.ContentState.range` is handed
/// to `Text(timerInterval:countsDown:)` and `ProgressView(timerInterval:)`, both
/// of which the system tickers on its own. ActivityKit budgets updates; spending
/// one per second on a number the system already draws would spend the whole
/// budget on the one thing that did not need it, and leave nothing for the
/// routine step actually changing.
@MainActor
final class LiveActivityController: LiveActivityControlling {

    private var activity: Activity<PottyPauseAttributes>?

    /// How long after the expected end the system may keep showing the activity
    /// as out-of-date before dismissing it itself.
    ///
    /// Two minutes past the end. A `staleDate` is the promise "after this, do not
    /// trust what is on screen", and for a pause that promise has to be short:
    /// the thing on screen is a claim about whether a child's apps are held.
    private static let staleGrace: TimeInterval = 2 * 60

    init() {}

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var isRunning: Bool { activity != nil }

    func start(
        sessionID: String,
        isGuidedRoutine: Bool,
        startedAt: Date,
        expectedEndAt: Date,
        mood: HopWidgetMood
    ) {
        // Never two at once. A second request would leave the first on the lock
        // screen counting down to a pause that is over.
        guard activity == nil else {
            update(stepIndex: nil, stepCount: nil, expectedEndAt: expectedEndAt, mood: mood)
            return
        }
        guard areActivitiesEnabled else {
            HopLog.shield.info("live activity skipped reason=disabled")
            return
        }

        let attributes = PottyPauseAttributes(sessionID: sessionID, isGuidedRoutine: isGuidedRoutine)
        let state = PottyPauseAttributes.ContentState(
            startedAt: startedAt,
            expectedEndAt: expectedEndAt,
            stepIndex: isGuidedRoutine ? 0 : nil,
            stepCount: isGuidedRoutine ? PottyRoutineContent.steps.count : nil,
            hopPoseName: mood.rawValue
        )

        do {
            activity = try Activity<PottyPauseAttributes>.request(
                attributes: attributes,
                content: ActivityContent(
                    state: state,
                    staleDate: expectedEndAt.addingTimeInterval(Self.staleGrace)
                ),
                pushType: nil
            )
            HopLog.shield.info("live activity started guided=\(isGuidedRoutine, privacy: .public)")
        } catch {
            // Every documented reason to fail here — activities disabled, the
            // budget spent, the app in the background — is a reason to carry on
            // without one. Reduced to `domain#code` because an ActivityKit error
            // description can interpolate the attributes into the message.
            HopLog.shield.error(
                "live activity request failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
        }
    }

    func update(
        stepIndex: Int?,
        stepCount: Int?,
        expectedEndAt: Date?,
        mood: HopWidgetMood
    ) {
        guard let activity else { return }
        var state = activity.content.state
        if let stepIndex { state.stepIndex = stepIndex }
        if let stepCount { state.stepCount = stepCount }
        if let expectedEndAt { state.expectedEndAt = expectedEndAt }
        state.hopPoseName = mood.rawValue

        let content = ActivityContent(
            state: state,
            staleDate: state.expectedEndAt.addingTimeInterval(Self.staleGrace)
        )
        Task { await activity.update(content) }
    }

    func end(at instant: Date) {
        // Not `guard let activity` — see the protocol note. Anything this
        // process can see gets ended, including an activity a previous launch
        // requested and never cleaned up.
        let running = activity
        activity = nil

        Task {
            if let running {
                var closing = running.content.state
                closing.expectedEndAt = min(closing.expectedEndAt, instant)
                closing.hopPoseName = HopWidgetMood.idle.rawValue
                await running.end(
                    ActivityContent(state: closing, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
            for orphan in Activity<PottyPauseAttributes>.activities {
                await orphan.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

#endif

// MARK: - Fake

/// Starts nothing and ends nothing, and remembers being asked.
///
/// Previews, UI tests, and the DebugMock scheme. Also the live type on any build
/// where `ActivityKit` is unavailable, which is why it is not inside `#if DEBUG`
/// — the same reasoning as `NoOpWidgetRefresher`.
@MainActor
final class NoOpLiveActivityController: LiveActivityControlling {
    private(set) var startCount = 0
    private(set) var updateCount = 0
    private(set) var endCount = 0
    private(set) var lastSessionID: String?
    private(set) var lastExpectedEnd: Date?

    var areActivitiesEnabled: Bool { false }
    private(set) var isRunning = false

    init() {}

    func start(
        sessionID: String,
        isGuidedRoutine: Bool,
        startedAt: Date,
        expectedEndAt: Date,
        mood: HopWidgetMood
    ) {
        startCount += 1
        lastSessionID = sessionID
        lastExpectedEnd = expectedEndAt
        isRunning = true
    }

    func update(stepIndex: Int?, stepCount: Int?, expectedEndAt: Date?, mood: HopWidgetMood) {
        updateCount += 1
        if let expectedEndAt { lastExpectedEnd = expectedEndAt }
    }

    func end(at instant: Date) {
        endCount += 1
        isRunning = false
    }
}

// MARK: - Selection

enum LiveActivityControllerFactory {
    /// The controller this build should use.
    ///
    /// `.mock` gets the fake for the same reason every other service does: a
    /// preview canvas must not put a Live Activity on the developer's own lock
    /// screen every time it refreshes.
    @MainActor
    static func resolved(_ configuration: AppBuildConfiguration) -> any LiveActivityControlling {
        #if canImport(ActivityKit)
        switch configuration {
        case .live: return LiveActivityController()
        case .mock: return NoOpLiveActivityController()
        }
        #else
        return NoOpLiveActivityController()
        #endif
    }
}
