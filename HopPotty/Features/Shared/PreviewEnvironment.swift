#if DEBUG
import Foundation
import SwiftUI
import HopPottyCore

// Fake services and the assembled `ParentEnvironment` every preview uses.

@MainActor
final class PreviewScreenTimeService: ScreenTimeProviding {
    var authorizationStatus: ScreenTimeAuthorizationStatus
    var selectionCount: Int
    var applyFailure: ScreenTimeFailure?
    var shieldUp: Bool

    init(
        authorizationStatus: ScreenTimeAuthorizationStatus = .approved,
        selectionCount: Int = 6,
        applyFailure: ScreenTimeFailure? = nil,
        shieldUp: Bool = false
    ) {
        self.authorizationStatus = authorizationStatus
        self.selectionCount = selectionCount
        self.applyFailure = applyFailure
        self.shieldUp = shieldUp
    }

    func requestAuthorization() async -> ScreenTimeAuthorizationOutcome {
        switch authorizationStatus {
        case .approved: .approved
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .approved
        }
    }

    func snapshot(for childID: UUID) async -> ScreenTimeSnapshot {
        ScreenTimeSnapshot(
            configuration: ScreenTimeConfiguration(
                childID: childID,
                selectedApplicationCount: selectionCount,
                authorizationStatus: authorizationStatus,
                lastRegistrationFailure: applyFailure
            ),
            mayHaveShieldUp: shieldUp
        )
    }

    @discardableResult
    func saveSelection(_ data: Data?, for childID: UUID) async throws -> ScreenTimeConfiguration {
        ScreenTimeConfiguration(
            childID: childID,
            selectedApplicationCount: selectionCount,
            authorizationStatus: authorizationStatus
        )
    }

    func applySchedule(_ schedule: PottySchedule) async -> ScreenTimeFailure? { applyFailure }
    func startPauseNow(for schedule: PottySchedule) async -> ScreenTimeFailure? { applyFailure }
    func restoreScreenAccess() async -> ScreenTimeFailure? {
        shieldUp = false
        return nil
    }
}

@MainActor
final class PreviewNotificationService: NotificationProviding {
    var permission: NotificationPermission
    init(permission: NotificationPermission = .authorized) { self.permission = permission }
    func requestPermission() async -> NotificationPermission { permission }
    func refreshPermission() async {}
}

@MainActor
final class PreviewPurchaseService: PurchaseProviding {
    var entitlement: ParentEntitlement
    var product: HopProduct?

    init(entitlement: ParentEntitlement = .free, product: HopProduct? = .previewFamily) {
        self.entitlement = entitlement
        self.product = product
    }

    func loadProduct() async {}
    func purchase() async -> PurchaseOutcome {
        entitlement = .family
        return .purchased
    }
    func restore() async -> PurchaseOutcome {
        entitlement = .family
        return .purchased
    }
}

extension HopProduct {
    /// A plausible price for a preview only. Nothing in the shipping paywall
    /// composes a price — it comes from `Product.displayPrice` or the row is
    /// not drawn.
    static let previewFamily = HopProduct(
        id: "com.hoppotty.family",
        displayName: "HopPotty Family",
        displayPrice: "$14.99",
        description: "One purchase. Every feature, for good."
    )
}

@MainActor
final class PreviewDeletionService: DataDeletionProviding {
    var receipt: DeletionReceipt

    init(receipt: DeletionReceipt = DeletionReceipt(childName: "Maya", events: 47, stars: 31, decorations: 6, children: 1)) {
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
            profiles: InMemoryChildProfileRepository(children),
            events: InMemoryPottyEventRepository(resolvedEvents),
            rewards: InMemoryRewardRepository(PreviewData.stars(for: child.id, events: resolvedEvents)),
            pond: InMemoryPondProgressRepository(),
            schedules: InMemoryScheduleRepository([resolvedSchedule]),
            screenTime: InMemoryScreenTimeConfigurationRepository(),
            quizzes: InMemoryQuizProgressRepository(),
            games: InMemoryGameProgressRepository(),
            settings: InMemorySettingsRepository(AppSettings(activeChildID: child.id, hasCompletedOnboarding: true))
        )

        let environment = ParentEnvironment(
            repositories: repositories,
            screenTime: PreviewScreenTimeService(authorizationStatus: authorization),
            purchases: PreviewPurchaseService(entitlement: entitlement),
            notifications: PreviewNotificationService(permission: notificationPermission),
            deletion: PreviewDeletionService(),
            export: PreviewExportService(),
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

    static var previewCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        return calendar
    }
}
#endif
