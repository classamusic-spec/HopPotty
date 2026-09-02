#if DEBUG
import Foundation
import SwiftUI
import HopPottyCore
// Sample children live in their own module so they can never reach a real
// family's data. Previews are the only callers.
import HopPottyFixtures

// The assembled `ParentEnvironment` every preview uses.
//
// ## Why there are almost no fakes here
//
// There used to be five `Preview*Service` types in this file, one per port. They
// are gone, and their absence is the point: `Services/` already ships a fake for
// every service it defines — `MockScreenTimeService`, `MockNotificationService`,
// `MockPurchaseService`, `MockActivityMonitoringService`,
// `NoOpLiveActivityController` — and `ServiceContainer.mock` assembles exactly
// those. A second set here was a second answer to "what does this service do
// when it is not real", and the two drifted: the copies in this file were still
// conforming to protocol shapes that had been replaced, which is a compile
// error at best and a preview that exercises a code path the app does not have
// at worst.
//
// What remains are the two ports `Services/` has no fake for — deletion and
// export — where the preview needs a *receipt with plausible numbers on it*
// rather than the real service's answer over an empty in-memory store.

@MainActor
final class PreviewDeletionService: DataDeletionProviding {
    var receipt: DeletionReceipt

    init(
        receipt: DeletionReceipt = DeletionReceipt(
            scope: .childProfile(childID: UUID()),
            childNickname: "Maya",
            counts: DeletionCounts(pottyEvents: 47, starsRemoved: 31, pondItems: 6, profiles: 1),
            completedAt: .now
        )
    ) {
        self.receipt = receipt
    }

    func receipt(forChild childID: UUID) async throws -> DeletionReceipt { receipt }
    func receiptForEverything() async throws -> DeletionReceipt { receipt }
    func deleteChild(_ childID: UUID, authorization: ParentAuthorization) async throws -> DeletionReceipt { receipt }
    func deleteEverything(authorization: ParentAuthorization) async throws -> DeletionReceipt { receipt }
}

@MainActor
final class PreviewExportService: DataExportProviding {
    func exportArchive(for childID: UUID?, authorization: ParentAuthorization) async throws -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("hoppotty-export.json")
    }
}

// MARK: - Assembled environments

extension ParentEnvironment {

    /// The standard preview family: one named child with a fortnight of entries.
    static func preview(
        children: [ChildProfile] = [HopFixtures.maya],
        events: [PottyEvent]? = nil,
        schedule: PottySchedule? = nil,
        authorization: ScreenTimeAuthorizationStatus = .approved,
        entitlement: ParentEntitlement = .free,
        notificationPermission: NotificationPermission = .authorized,
        isStoreAvailable: Bool = true,
        now: Date = HopFixtures.referenceDate
    ) -> ParentEnvironment {
        let child = children.first ?? HopFixtures.maya
        let clock = FixedClock(now: now, calendar: previewCalendar)
        let resolvedEvents = events ?? PreviewData.fortnight(for: child.id, endingAt: now, calendar: previewCalendar)
        let resolvedSchedule = schedule ?? PottySchedule(
            childID: child.id,
            mode: .pause,
            triggerBasis: .screenActivity,
            interval: .minutes45,
            quietWindows: QuietWindow.onboardingSuggestions
        )

        let repositories = RepositorySet(
            profiles: InMemoryChildProfileRepository(profiles: children),
            events: InMemoryPottyEventRepository(events: resolvedEvents),
            rewards: InMemoryRewardRepository(transactions: PreviewData.stars(for: child.id, events: resolvedEvents)),
            pond: InMemoryPondProgressRepository(),
            schedules: InMemoryScheduleRepository(schedules: [resolvedSchedule]),
            screenTime: InMemoryScreenTimeConfigurationRepository(),
            quizzes: InMemoryQuizProgressRepository(),
            games: InMemoryGameProgressRepository(),
            settings: InMemorySettingsRepository(settings: AppSettings(activeChildID: child.id, hasCompletedOnboarding: true))
        )

        let environment = ParentEnvironment(
            repositories: repositories,
            screenTime: previewScreenTime(.init(authorizationStatus: authorization), clock: clock),
            purchases: MockPurchaseService(entitlement: entitlement),
            notifications: MockNotificationService(permission: notificationPermission),
            deletion: PreviewDeletionService(),
            export: PreviewExportService(),
            liveActivities: NoOpLiveActivityController(),
            clock: clock,
            settings: AppSettings(activeChildID: child.id, hasCompletedOnboarding: true),
            isStoreAvailable: isStoreAvailable
        )
        return environment
    }

    /// A family that has logged nothing at all — the genuine first-use state.
    static func previewEmpty() -> ParentEnvironment {
        preview(children: [HopFixtures.unnamedChild], events: [])
    }

    /// A nickname at the length the layouts are designed to hold.
    static func previewLongNickname() -> ParentEnvironment {
        var child = HopFixtures.maya
        child.nickname = String("Maximilian Bartholomew".prefix(ChildProfile.maxNicknameLength))
        return preview(children: [child])
    }

    /// A device that has never run onboarding.
    static func previewFirstRun() -> ParentEnvironment {
        let clock = FixedClock(now: HopFixtures.referenceDate, calendar: previewCalendar)
        let repositories = RepositorySet(
            profiles: InMemoryChildProfileRepository(),
            events: InMemoryPottyEventRepository(),
            rewards: InMemoryRewardRepository(),
            pond: InMemoryPondProgressRepository(),
            schedules: InMemoryScheduleRepository(),
            screenTime: InMemoryScreenTimeConfigurationRepository(),
            quizzes: InMemoryQuizProgressRepository(),
            games: InMemoryGameProgressRepository(),
            settings: InMemorySettingsRepository(settings: AppSettings(hasCompletedOnboarding: false))
        )
        return ParentEnvironment(
            repositories: repositories,
            screenTime: previewScreenTime(.notDetermined, clock: clock),
            purchases: MockPurchaseService(),
            notifications: MockNotificationService(permission: .notDetermined),
            deletion: PreviewDeletionService(
                receipt: DeletionReceipt(
                    scope: .entireApp,
                    childNickname: nil,
                    counts: DeletionCounts(),
                    completedAt: .now
                )
            ),
            export: PreviewExportService(),
            liveActivities: NoOpLiveActivityController(),
            clock: clock,
            settings: AppSettings(hasCompletedOnboarding: false)
        )
    }

    /// StoreKit did not answer — offline, or the product is not configured. The
    /// paywall must describe the unlock without inventing a price.
    static func previewOffline() -> ParentEnvironment {
        let environment = preview()
        return ParentEnvironment(
            repositories: environment.repositories,
            screenTime: environment.screenTime,
            purchases: MockPurchaseService(entitlement: .free, hasProducts: false),
            notifications: environment.notifications,
            deletion: environment.deletion,
            export: environment.export,
            liveActivities: environment.liveActivities,
            clock: environment.clock,
            settings: environment.settings
        )
    }

    /// The parent screens' Screen Time port, backed by the services layer's own
    /// fake.
    ///
    /// `MockActivityMonitoringService` is what makes "we could not arm your
    /// schedule" reachable in a preview: `applySchedule` returns `nil` without a
    /// monitoring service, so a preview built without one would quietly never
    /// exercise the failure it exists to show.
    static func previewScreenTime(
        _ scenario: MockScreenTimeService.Scenario = .authorized,
        clock: any HopClock
    ) -> ParentScreenTimeAdapter {
        ParentScreenTimeAdapter(
            service: MockScreenTimeService(scenario: scenario),
            monitoring: MockActivityMonitoringService(),
            clock: clock
        )
    }

    static var previewCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        return calendar
    }
}
#endif
