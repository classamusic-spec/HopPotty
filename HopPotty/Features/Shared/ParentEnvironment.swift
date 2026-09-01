import Foundation
import Observation
import SwiftUI
import HopPottyCore

/// Everything the parent-facing features are allowed to reach.
///
/// One value, handed down through the SwiftUI environment, rather than each
/// screen constructing its own store. That is what makes "this screen runs
/// against an in-memory set with no store at all" a preview parameter instead
/// of a rewrite — see `RepositorySet`, whose whole purpose is the same seam.
///
/// It is `@Observable` so that the two things which genuinely change while the
/// app is open — which child is selected, and the app-wide settings — propagate
/// without every screen re-reading them.
@MainActor
@Observable
final class ParentEnvironment {

    let repositories: RepositorySet
    let screenTime: any ScreenTimeProviding
    let purchases: any PurchaseProviding
    let notifications: any NotificationProviding
    let deletion: any DataDeletionProviding
    let export: any DataExportProviding
    let clock: any HopClock

    /// Pure scheduling logic. Built from the clock's calendar so a preview
    /// pinned to a fixed time zone reasons in that zone.
    let scheduleService: PottyScheduleService

    /// Whether the store opened. When it did not, every screen still works and
    /// the settings screen says so — a caregiver whose device is full should not
    /// meet a blank dashboard with no explanation.
    let isStoreAvailable: Bool

    // MARK: Shared mutable state

    private(set) var settings: AppSettings
    private(set) var children: [ChildProfile] = []
    private(set) var activeChildID: UUID?
    private(set) var loadFailure: ParentFailure?

    var activeChild: ChildProfile? {
        guard let activeChildID else { return children.first }
        return children.first { $0.id == activeChildID } ?? children.first
    }

    /// Whether the family may add another child. Multi-child is a paid feature;
    /// nothing a child already earned is ever behind it.
    var canAddChild: Bool {
        purchases.entitlement.isUnlocked || children.count < ParentEntitlement.freeChildLimit
    }

    init(
        repositories: RepositorySet,
        screenTime: any ScreenTimeProviding,
        purchases: any PurchaseProviding,
        notifications: any NotificationProviding,
        deletion: any DataDeletionProviding,
        export: any DataExportProviding,
        clock: any HopClock = SystemClock(),
        settings: AppSettings = AppSettings(),
        isStoreAvailable: Bool = true
    ) {
        self.repositories = repositories
        self.screenTime = screenTime
        self.purchases = purchases
        self.notifications = notifications
        self.deletion = deletion
        self.export = export
        self.clock = clock
        self.settings = settings
        self.isStoreAvailable = isStoreAvailable
        self.scheduleService = PottyScheduleService(calendar: clock.calendar)
        self.activeChildID = settings.activeChildID
    }

    // MARK: Loading

    /// Reads settings and profiles. Called by the root once and after any change
    /// that can add or remove a child.
    func reload() async {
        do {
            let settings = try await repositories.settings.settings()
            let children = try await repositories.profiles.allProfiles()
            self.settings = settings
            self.children = children
            // A stale `activeChildID` — the selected child was deleted on
            // another screen — silently falls back to the first profile rather
            // than leaving the dashboard pointed at nothing.
            if let id = settings.activeChildID, children.contains(where: { $0.id == id }) {
                activeChildID = id
            } else {
                activeChildID = children.first?.id
            }
            loadFailure = nil
        } catch {
            loadFailure = isStoreAvailable ? .readFailed : .storageUnavailable
        }
    }

    func selectChild(_ childID: UUID) async {
        guard children.contains(where: { $0.id == childID }) else { return }
        activeChildID = childID
        var updated = settings
        updated.activeChildID = childID
        await save(updated)
    }

    func save(_ newSettings: AppSettings) async {
        settings = newSettings
        do {
            try await repositories.settings.save(newSettings)
        } catch {
            loadFailure = .saveFailed
        }
    }

    /// Mutates settings in place and persists, so a toggle row is one line at
    /// the call site and cannot forget to save.
    func updateSettings(_ mutate: (inout AppSettings) -> Void) async {
        var updated = settings
        mutate(&updated)
        guard updated != settings else { return }
        await save(updated)
    }

    func markOnboardingComplete() async {
        await updateSettings { $0.hasCompletedOnboarding = true }
    }

    /// The schedule for a child, or a fresh default one. Returning a value
    /// rather than `nil` means the timer screen has something to edit on the
    /// very first launch after onboarding was skipped.
    func schedule(for childID: UUID) async -> PottySchedule {
        (try? await repositories.schedules.schedule(for: childID)) ?? PottySchedule(childID: childID)
    }

    func saveSchedule(_ schedule: PottySchedule) async -> ParentFailure? {
        do {
            var updated = schedule
            updated.modifiedAt = clock.now
            try await repositories.schedules.save(updated)
            if let failure = await screenTime.applySchedule(updated) {
                return .screenTime(failure)
            }
            return nil
        } catch {
            return .saveFailed
        }
    }
}

// MARK: - Convenience

extension ParentEnvironment {
    /// The child a screen should show, given an explicit selection or the
    /// app-wide one.
    func resolvedChild(_ requested: UUID?) -> ChildProfile? {
        guard let requested else { return activeChild }
        return children.first { $0.id == requested } ?? activeChild
    }

    var hasMultipleChildren: Bool { children.count > 1 }
}
