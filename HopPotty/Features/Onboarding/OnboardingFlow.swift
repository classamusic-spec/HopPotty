import Foundation
import HopPottyCore

/// The twelve screens of first-run setup, as an explicit machine.
///
/// Explicit because onboarding is the one flow that is guaranteed to be
/// interrupted. A caregiver sets HopPotty up while a toddler is in the room:
/// the app is backgrounded at the Screen Time prompt, the phone rings during
/// the app picker, the parent taps "Don't Allow" and has to land somewhere that
/// still works. A stack of `NavigationLink`s cannot express any of that. A step
/// plus a draft can: the step is persisted, the draft is persisted, and
/// `resume` puts the caregiver back exactly where they were.
///
/// The second reason is denial. Permission is asked for in the middle of the
/// flow, and the answer changes which screens exist at all — see
/// `nextStep(after:)`, which is the only place that decision is made.
enum OnboardingStep: String, CaseIterable, Codable, Identifiable, Sendable {
    case meetHop
    case theIdea
    case nickname
    case chooseRoutine
    case interval
    case whyScreenTime
    case authorization
    case chooseApps
    case quietHours
    case notifications
    case testPause
    case ready

    var id: String { rawValue }

    /// Whether the caregiver can move on without answering. A skippable step
    /// still shows its skip control explicitly; a "Next" that quietly means
    /// "no thanks" is a dark pattern in the other direction.
    var isSkippable: Bool {
        switch self {
        case .nickname, .quietHours, .notifications, .testPause: true
        case .meetHop, .theIdea, .chooseRoutine, .interval, .whyScreenTime,
             .authorization, .chooseApps, .ready: false
        }
    }

    /// Steps that count toward the progress indicator. The permission screens
    /// are included: hiding them would make the bar jump when they are skipped,
    /// which reads as the app losing its place.
    static var indicatorSteps: [OnboardingStep] { allCases }
}

/// Everything the caregiver has chosen so far.
///
/// A value, persisted after every change, so an interrupted setup resumes with
/// the nickname already typed rather than an empty field.
struct OnboardingDraft: Equatable, Codable, Sendable {
    var nickname: String?
    var mode: PottyPauseMode = .pause
    var interval: PottyInterval = .minutes45
    var quietWindows: [QuietWindow] = []
    var authorizationStatus: ScreenTimeAuthorizationStatus = .notDetermined
    var hasAppSelection = false
    var notificationPermission: NotificationPermission = .notDetermined
    /// Whether the caregiver ran the test pause and it worked. Recorded so the
    /// final screen can say what is actually armed.
    var didTestPauseSucceed: Bool?
    /// Set when the caregiver declined Screen Time and HopPotty moved them to
    /// gentle mode. Drives the honest wording on the final screen.
    var fellBackToGentle = false

    /// The schedule this draft describes, ready to persist.
    ///
    /// Warning offset and pause length keep `PottySchedule`'s own defaults:
    /// onboarding asks about rhythm, not about every dial, and the timer screen
    /// is where the rest lives.
    func schedule(for childID: UUID) -> PottySchedule {
        PottySchedule(
            childID: childID,
            mode: mode,
            triggerBasis: mode.shieldsApps ? .screenActivity : .clockTime,
            interval: interval,
            quietWindows: quietWindows
        )
    }

    var childProfile: ChildProfile {
        ChildProfile(nickname: nickname)
    }
}

/// Step plus draft, persisted together.
struct OnboardingState: Equatable, Codable, Sendable {
    var step: OnboardingStep = .meetHop
    var draft = OnboardingDraft()
    /// Steps the caregiver has actually seen, so "Back" retraces the path taken
    /// rather than the path the machine would have chosen this time.
    var visited: [OnboardingStep] = [.meetHop]

    static let initial = OnboardingState()
}

extension OnboardingState {

    /// The next step, given everything decided so far.
    ///
    /// This is the whole routing policy, in one function, in reading order:
    ///
    /// - **Gentle mode never asks for Screen Time.** Nothing is ever shielded in
    ///   gentle mode, so requesting Family Controls would be asking for a
    ///   permission the app has no use for. The three permission screens
    ///   disappear.
    /// - **Denied or restricted authorization does not dead-end.** The app
    ///   cannot shield, so it moves to gentle mode, records that it did, and
    ///   carries on to quiet hours. The caregiver finishes setup with a working
    ///   app and a clear sentence about what changed — not a locked screen with
    ///   a retry button that a restricted device can never satisfy.
    /// - **No app selection means no test pause.** Testing a pause with nothing
    ///   selected would show the caregiver a failure they caused by skipping,
    ///   which teaches them the feature is broken.
    func nextStep(after step: OnboardingStep) -> OnboardingStep? {
        switch step {
        case .meetHop: return .theIdea
        case .theIdea: return .nickname
        case .nickname: return .chooseRoutine
        case .chooseRoutine: return .interval
        case .interval:
            return draft.mode.requiresScreenTimeAuthorization ? .whyScreenTime : .quietHours
        case .whyScreenTime:
            return .authorization
        case .authorization:
            return draft.authorizationStatus.canShield ? .chooseApps : .quietHours
        case .chooseApps:
            return .quietHours
        case .quietHours:
            return .notifications
        case .notifications:
            return canOfferTestPause ? .testPause : .ready
        case .testPause:
            return .ready
        case .ready:
            return nil
        }
    }

    /// Whether a test pause can succeed right now. Offering one that cannot is
    /// worse than not offering one.
    var canOfferTestPause: Bool {
        draft.mode.shieldsApps && draft.authorizationStatus.canShield && draft.hasAppSelection
    }

    /// The step to return to. Retraces `visited`, so a caregiver who was routed
    /// around the permission screens does not walk back into them.
    var previousStep: OnboardingStep? {
        guard visited.count > 1 else { return nil }
        return visited[visited.count - 2]
    }

    /// 1-based position for the step indicator, counted over the path this
    /// caregiver is actually walking rather than over all twelve.
    var indicatorPosition: (current: Int, total: Int) {
        let path = plannedPath
        let index = path.firstIndex(of: step) ?? max(0, path.count - 1)
        return (index + 1, path.count)
    }

    /// The route from the start given the current draft. Recomputed rather than
    /// stored: the moment the caregiver picks gentle mode, the remaining count
    /// should drop, because three screens genuinely stopped existing.
    var plannedPath: [OnboardingStep] {
        var path: [OnboardingStep] = [.meetHop]
        var cursor = OnboardingStep.meetHop
        // Bounded by the case count: `nextStep` only ever moves forward through
        // the declared order, but a parenting app must not spin on a future edit.
        for _ in 0..<OnboardingStep.allCases.count {
            guard let next = nextStep(after: cursor) else { break }
            path.append(next)
            cursor = next
        }
        return path
    }

    mutating func advance() {
        guard let next = nextStep(after: step) else { return }
        step = next
        if !visited.contains(next) { visited.append(next) }
    }

    mutating func goBack() {
        guard let previous = previousStep else { return }
        visited.removeLast()
        step = previous
    }

    /// Applies an authorization answer and routes accordingly.
    ///
    /// Falling back to gentle mode is recorded in the draft rather than done
    /// silently: the final screen tells the caregiver that reminders will run
    /// and apps will not pause, and Settings can change it later.
    mutating func apply(_ outcome: ScreenTimeAuthorizationOutcome) {
        draft.authorizationStatus = outcome.status
        switch outcome {
        case .approved:
            draft.fellBackToGentle = false
        case .denied, .restricted, .failed:
            draft.mode = .gentle
            draft.fellBackToGentle = true
        case .cancelled:
            // Cancelling is not a denial. The caregiver stays on the screen and
            // can ask again, which is the documented behaviour of
            // `FamilyControlsError.authorizationCanceled`.
            break
        }
    }
}
