import Foundation
import HopPottyCore
import UserNotifications
import Observation

// MARK: - The permitted kinds
//
// ## Why this enum is closed, and why it has three cases
//
// HopPotty is used by two- to five-year-olds and installed by a caregiver who is
// already worried about screens. The single fastest way to make this product
// harmful would be to send notifications that exist to bring people back to it.
// Contract rule 7 forbids engagement mechanics; this file is where that rule is
// either kept or broken, because a notification is the one thing the app can do
// when nobody asked it to.
//
// So the rule is absolute and structural rather than cultural:
//
// **HopPotty sends exactly three notifications. A heads-up a couple of minutes
// before a scheduled pause, an opt-in daily summary for the caregiver, and a
// one-off Quick Reminder at an instant the caregiver picked by hand.**
//
// The third one was added deliberately and it is the same shape as the other
// two: it exists because a person asked for it, at a time that person chose,
// and it happens exactly once. Nothing re-arms it, nothing escalates it, and
// nothing sends it because the app was not opened. If a fourth case is ever
// proposed, the question to answer first is the one this comment exists for:
// who asked for it, and what did they ask for?
//
// Specifically forbidden, and not expressible with the types in this file:
//
// - "Hop misses you!" / "Come back and see your pond" — re-engagement.
// - "You're about to lose your streak" — loss aversion aimed at a child.
// - "You haven't logged anything today" — guilt aimed at a parent who is
//   probably having a hard week.
// - "3 new pond items to discover!" — manufactured urgency.
// - Anything scheduled *because the app was not opened*.
//
// The structure that enforces it:
//
// 1. `HopNotificationKind` has three cases and is the only thing the service
//    can schedule. Adding a fourth is a visible, reviewable diff in this file,
//    next to this comment.
// 2. `HopNotificationRequest` has a `private init`. The only ways to make one
//    are the three factories below, and each is tied to something a caregiver
//    switched on or tapped.
// 3. Every factory takes the *instant a person or a schedule chose*. There is
//    no factory that takes "an interval since the user was last seen", because
//    that is the shape of the notification we will not send.
// 4. `NotificationService.schedule` rejects any request whose identifier does
//    not carry a permitted prefix, and logs a fault if one ever arrives.

/// The complete set of notifications HopPotty may send. See the note above
/// before adding a case.
enum HopNotificationKind: String, CaseIterable, Sendable {
    /// The heads-up before a scheduled pause. Enabled by
    /// `AppSettings.warningNotificationsEnabled`, timed by
    /// `PottySchedule.effectiveWarningOffset`.
    case pauseWarning
    /// The opt-in caregiver summary. Off by default
    /// (`AppSettings.dailySummaryEnabled`), fires at
    /// `AppSettings.dailySummaryTime`, and deliberately contains no numbers —
    /// a nightly scorecard for a toddler's toilet use is not a kindness.
    case dailyCaregiverSummary
    /// A one-off Quick Reminder the caregiver set by hand: "remind us in twenty
    /// minutes". Timed by nothing but the instant they picked, fires once, and
    /// shields nothing — see `QuickReminder` in HopPottyCore.
    case quickReminder

    var identifierPrefix: String {
        switch self {
        case .pauseWarning: "hop.notification.warning."
        case .dailyCaregiverSummary: "hop.notification.summary"
        // Trailing dot: the reminder's own id is appended, so one reminder can
        // be cancelled without touching another's.
        case .quickReminder: "hop.notification.quickReminder."
        }
    }

    /// The `UNNotificationCategory` this kind is delivered under.
    ///
    /// HopPotty registers no custom actions on any of them. The identifiers
    /// exist so that a delivered notification can be told apart from the others
    /// when one is tapped, and so the set is enumerable — a category that
    /// carried a "Snooze" or a "Remind me again" button would be an engagement
    /// mechanic wearing a system control, and the way to keep one from
    /// appearing is for every category in the app to be listed in one place.
    var categoryIdentifier: String {
        switch self {
        case .pauseWarning: "HOP_PAUSE_WARNING"
        case .dailyCaregiverSummary: "HOP_DAILY_SUMMARY"
        case .quickReminder: "HOP_QUICK_REMINDER"
        }
    }

    /// Who the words are for. The warning is read aloud to a child; the summary
    /// and the Quick Reminder are for the adult who asked for them.
    var audience: HopCopyAudience {
        switch self {
        case .pauseWarning: .child
        case .dailyCaregiverSummary, .quickReminder: .parent
        }
    }
}

// MARK: - Request

/// A notification HopPotty is permitted to schedule.
///
/// `private init` plus three factories. This type is the gate.
struct HopNotificationRequest: Sendable {
    let kind: HopNotificationKind
    let identifier: String
    let title: String
    let body: String
    /// Absolute instant for a one-shot; `nil` for the repeating daily summary.
    let fireAt: Date?
    /// Wall-clock time for the repeating summary; `nil` for the one-shot.
    let dailyTime: LocalTimeOfDay?

    private init(
        kind: HopNotificationKind,
        identifier: String,
        title: String,
        body: String,
        fireAt: Date?,
        dailyTime: LocalTimeOfDay?
    ) {
        self.kind = kind
        self.identifier = identifier
        self.title = title
        self.body = body
        self.fireAt = fireAt
        self.dailyTime = dailyTime
    }

    /// The two-minute warning.
    ///
    /// `fireAt` comes from `PottyScheduleService.nextWarning(for:)`, which
    /// already refuses to fire inside a quiet window. Nothing here invents a
    /// time.
    static func pauseWarning(childID: UUID, nickname: String?, fireAt: Date) -> HopNotificationRequest {
        HopNotificationRequest(
            kind: .pauseWarning,
            // The child id is in the identifier so the warning for one child can
            // be cancelled without touching a sibling's. It is never logged.
            identifier: HopNotificationKind.pauseWarning.identifierPrefix + childID.uuidString,
            title: HopNotificationCopy.warningTitle(),
            body: HopNotificationCopy.warningBody(nickname: nickname),
            fireAt: fireAt,
            dailyTime: nil
        )
    }

    /// A Quick Reminder.
    ///
    /// `fireAt` comes from `QuickReminderPlanner`, which has already refused
    /// anything in the past, anything closer than a minute and anything more
    /// than a day out. Nothing here invents a time either.
    ///
    /// The reminder's own id is in the identifier so one can be cancelled
    /// without touching another — including the one it replaces, which is the
    /// case that matters: a replaced reminder whose notification nobody
    /// cancelled arrives for a caregiver who was told it had moved.
    static func quickReminder(id: UUID, fireAt: Date) -> HopNotificationRequest {
        HopNotificationRequest(
            kind: .quickReminder,
            identifier: HopNotificationKind.quickReminder.identifierPrefix + id.uuidString,
            title: HopNotificationCopy.quickReminderTitle(),
            body: HopNotificationCopy.quickReminderBody(),
            fireAt: fireAt,
            dailyTime: nil
        )
    }

    /// The opt-in daily caregiver summary.
    static func dailySummary(at time: LocalTimeOfDay) -> HopNotificationRequest {
        HopNotificationRequest(
            kind: .dailyCaregiverSummary,
            identifier: HopNotificationKind.dailyCaregiverSummary.identifierPrefix,
            title: HopNotificationCopy.summaryTitle(),
            body: HopNotificationCopy.summaryBody(),
            fireAt: nil,
            dailyTime: time
        )
    }

    // MARK: What a HopPotty notification looks like

    /// The content, decided in one place.
    ///
    /// Every service that schedules anything builds it from here rather than
    /// from its own `UNMutableNotificationContent`, so "no badge" and "does not
    /// break through a Focus" are properties of *HopPotty*, not of whichever
    /// file happened to be written first.
    func makeContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // No badge, no thread grouping that could accumulate, no
        // `interruptionLevel` escalation. A potty reminder is not time-sensitive
        // in the system's sense: it must not break through a Focus a caregiver
        // set deliberately.
        content.interruptionLevel = .active
        // No actions are registered against it; see `categoryIdentifier`.
        content.categoryIdentifier = kind.categoryIdentifier
        return content
    }

    /// The trigger, or `nil` for a request carrying neither an instant nor a
    /// daily time — which the factories cannot produce, and which is therefore
    /// a programming error rather than a state to recover from.
    func makeTrigger(now: Date, minimumLead: TimeInterval) -> UNNotificationTrigger? {
        if let fireAt {
            // A time-interval trigger for the one-shot. The horizon is minutes
            // or hours, so there is no daylight-saving edge to get wrong, and it
            // needs no calendar to be correct.
            return UNTimeIntervalNotificationTrigger(
                timeInterval: max(minimumLead, fireAt.timeIntervalSince(now)),
                repeats: false
            )
        }
        if let dailyTime {
            // A calendar trigger for the repeat, because "20:00" means 20:00 on
            // the wall clock every day — including the day the clocks change.
            var components = DateComponents()
            components.hour = dailyTime.hour
            components.minute = dailyTime.minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }
        return nil
    }

    /// Whether this request's identifier could have come from one of the
    /// factories above. The runtime half of the structural rule.
    var hasPermittedIdentifier: Bool { identifier.hasPrefix(kind.identifierPrefix) }
}

// MARK: - Permission

/// `UNAuthorizationStatus`, restated so nothing outside this file imports
/// `UserNotifications` to read a permission.
enum NotificationPermission: String, Sendable, CaseIterable {
    case notDetermined
    case denied
    case authorized
    /// Quiet delivery — straight to Notification Center, no banner.
    case provisional

    /// Whether a scheduled notification will actually reach anyone.
    var canDeliver: Bool { self == .authorized || self == .provisional }

    /// Whether asking again could change the answer. Once denied, only Settings
    /// can change it, and the UI must say that instead of offering a button
    /// that silently does nothing.
    var canRequest: Bool { self == .notDetermined }
}

/// Observable permission state.
///
/// A small `@Observable` box rather than making the service itself observable,
/// because features hold `any NotificationProviding` and SwiftUI cannot observe
/// through an existential. Both the real service and the mock own one of these,
/// so a preview shows the same UI paths as the shipping app.
@Observable
@MainActor
final class NotificationState {
    var permission: NotificationPermission = .notDetermined
    /// Set when scheduling failed, so the parent screen can explain itself.
    /// Never contains an underlying error message.
    var lastSchedulingFailed = false

    init(permission: NotificationPermission = .notDetermined) {
        self.permission = permission
    }
}

// MARK: - Protocol

@MainActor
protocol NotificationProviding: AnyObject {
    var state: NotificationState { get }

    /// The current permission, for a caller that wants the value rather than
    /// the observable box. Always `state.permission`.
    var permission: NotificationPermission { get }

    /// Reads the current system permission. Cheap; call on foreground.
    func refreshPermission() async

    /// Asks the system. Call only from a screen that has already explained why.
    @discardableResult
    func requestAuthorization() async -> NotificationPermission

    /// Spelling used by the parent settings screen. Identical behaviour.
    @discardableResult
    func requestPermission() async -> NotificationPermission

    /// Schedules the heads-up for one child, replacing any warning already
    /// scheduled for that child.
    func scheduleWarning(childID: UUID, nickname: String?, fireAt: Date) async

    /// Cancels the heads-up for one child. Called when a schedule is disabled,
    /// a pause starts early, or the child's profile goes away.
    func cancelWarning(childID: UUID) async

    /// Brings the daily summary in line with settings — scheduling it, moving
    /// it, or removing it.
    func applySummarySettings(_ settings: AppSettings) async

    /// Removes everything HopPotty has scheduled. Used by "Reset app" and by
    /// profile deletion.
    func cancelAll() async

    /// Pending requests, for the parent diagnostics row.
    func pendingCount() async -> Int
}

// MARK: - Service

@MainActor
final class NotificationService: NotificationProviding {
    let state: NotificationState
    var permission: NotificationPermission { state.permission }
    private let center: UNUserNotificationCenter
    private let clock: any HopClock

    init(
        center: UNUserNotificationCenter = .current(),
        clock: any HopClock = SystemClock(),
        state: NotificationState = NotificationState()
    ) {
        self.center = center
        self.clock = clock
        self.state = state
    }

    // MARK: Permission

    func refreshPermission() async {
        let permission = await Self.currentPermission(center: center)
        state.permission = permission
        HopLog.notification.info("permission=\(permission.rawValue, privacy: .public)")
    }

    @discardableResult
    func requestAuthorization() async -> NotificationPermission {
        do {
            // Alert and sound only. **No `.badge`.** A badge is an unread count
            // that sits on the home screen asking to be cleared, which is an
            // engagement mechanic with no content — exactly what rule 7 rules
            // out. HopPotty never sets one.
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            HopLog.notification.error(
                "authorization request failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
        }
        await refreshPermission()
        return state.permission
    }

    /// Reads the system status from a non-isolated context.
    ///
    /// `UNNotificationSettings` is mapped to HopPotty's own `Sendable` enum
    /// before anything crosses back to the main actor, so no `UserNotifications`
    /// object is ever passed between isolation domains.
    private nonisolated static func currentPermission(
        center: UNUserNotificationCenter
    ) async -> NotificationPermission {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        case .ephemeral: return .authorized
        // A status this build does not know maps to `.notDetermined`, not to
        // `.denied`: "we cannot tell" should leave the caregiver able to ask,
        // and must never look like a refusal they never gave.
        @unknown default: return .notDetermined
        }
    }

    // MARK: Scheduling

    func scheduleWarning(childID: UUID, nickname: String?, fireAt: Date) async {
        // A warning whose instant has passed is dropped rather than fired
        // immediately: "potty break coming soon" delivered after the pause has
        // already started is confusing to a child and useless to a caregiver.
        let lead = fireAt.timeIntervalSince(clock.now)
        guard lead >= Self.minimumLeadTime else {
            HopLog.scheduling.debug("warning skipped: lead time too short")
            await cancelWarning(childID: childID)
            return
        }
        await schedule(.pauseWarning(childID: childID, nickname: nickname, fireAt: fireAt))
    }

    func cancelWarning(childID: UUID) async {
        let identifier = HopNotificationKind.pauseWarning.identifierPrefix + childID.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func applySummarySettings(_ settings: AppSettings) async {
        guard settings.dailySummaryEnabled else {
            center.removePendingNotificationRequests(
                withIdentifiers: [HopNotificationKind.dailyCaregiverSummary.identifierPrefix]
            )
            return
        }
        await schedule(.dailySummary(at: settings.dailySummaryTime))
    }

    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
        // Delivered notifications go too: after "Reset app" there should be
        // nothing left in Notification Center referring to a child who no
        // longer exists on this device.
        center.removeAllDeliveredNotifications()
        HopLog.notification.info("all pending notifications cancelled")
    }

    func pendingCount() async -> Int {
        await Self.pendingCount(center: center)
    }

    /// Counts pending requests without letting a `UNNotificationRequest` cross
    /// an isolation boundary — the same reasoning as `currentPermission`.
    private nonisolated static func pendingCount(center: UNUserNotificationCenter) async -> Int {
        await center.pendingNotificationRequests().count
    }

    // MARK: The single scheduling path

    /// The only method in this service that talks to
    /// `UNUserNotificationCenter.add`.
    ///
    /// The identifier check is the runtime half of the structural rule: a
    /// request whose identifier does not carry a permitted prefix cannot have
    /// come from one of the three factories, so it is refused and logged loudly.
    private func schedule(_ request: HopNotificationRequest) async {
        guard request.hasPermittedIdentifier else {
            HopLog.notification.fault("refused notification with unrecognised identifier")
            return
        }

        guard let trigger = request.makeTrigger(now: clock.now, minimumLead: Self.minimumLeadTime) else {
            HopLog.notification.fault("notification request had no trigger")
            return
        }

        // Same identifier replaces rather than duplicates, so re-arming a
        // warning on every foreground cannot pile up twenty copies.
        let systemRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: request.makeContent(),
            trigger: trigger
        )

        do {
            try await center.add(systemRequest)
            state.lastSchedulingFailed = false
            HopLog.notification.info("scheduled kind=\(request.kind.rawValue, privacy: .public)")
        } catch {
            state.lastSchedulingFailed = true
            HopLog.notification.error(
                "schedule failed kind=\(request.kind.rawValue, privacy: .public) error=\(HopLog.safeDescription(error), privacy: .public)"
            )
        }
    }

    /// A notification scheduled closer than this is not worth sending — the
    /// pause it warns about is effectively already happening.
    static let minimumLeadTime: TimeInterval = 5
}

// MARK: - Mock

/// Records what would have been scheduled. Previews, tests, and any build where
/// asking for notification permission would be rude.
@MainActor
final class MockNotificationService: NotificationProviding {
    let state: NotificationState
    var permission: NotificationPermission { state.permission }
    private(set) var scheduledWarnings: [UUID: Date] = [:]
    private(set) var summaryTime: LocalTimeOfDay?
    private(set) var cancelledAllCount = 0

    init(permission: NotificationPermission = .authorized) {
        self.state = NotificationState(permission: permission)
    }

    func refreshPermission() async {}

    @discardableResult
    func requestAuthorization() async -> NotificationPermission {
        if state.permission == .notDetermined { state.permission = .authorized }
        return state.permission
    }

    func scheduleWarning(childID: UUID, nickname: String?, fireAt: Date) async {
        scheduledWarnings[childID] = fireAt
    }

    func cancelWarning(childID: UUID) async {
        scheduledWarnings.removeValue(forKey: childID)
    }

    func applySummarySettings(_ settings: AppSettings) async {
        summaryTime = settings.dailySummaryEnabled ? settings.dailySummaryTime : nil
    }

    func cancelAll() async {
        scheduledWarnings.removeAll()
        summaryTime = nil
        cancelledAllCount += 1
    }

    func pendingCount() async -> Int {
        scheduledWarnings.count + (summaryTime == nil ? 0 : 1)
    }
}

// MARK: - Feature-layer spelling

extension NotificationProviding {
    /// `requestAuthorization()` under the name the parent settings screen uses.
    /// One implementation, two call sites, no second code path to keep honest.
    @discardableResult
    func requestPermission() async -> NotificationPermission {
        await requestAuthorization()
    }
}
