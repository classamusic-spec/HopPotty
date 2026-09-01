import Foundation
import HopPottyCore

/// The app's live copy of `AppSettings`.
///
/// One observable object rather than a `@AppStorage` per switch. Three reasons:
///
/// 1. The settings are one value in the store and one value in the export, so
///    they should be one value in memory too.
/// 2. Several of them change how a *service* behaves — audio, haptics, the daily
///    summary — and a scattered set of `@AppStorage` properties gives no moment
///    at which to tell those services anything.
/// 3. "Reset app" has to put every setting back at once. That is one assignment
///    here and eleven easy-to-miss ones otherwise.
///
/// Writes go to disk immediately. A caregiver who flips a switch and force-quits
/// has flipped the switch.
@Observable
@MainActor
final class AppSettingsStore {
    private(set) var settings: AppSettings
    /// True when a write failed, so a settings screen can say the change did not
    /// stick instead of showing a switch that will revert on next launch.
    private(set) var lastWriteFailed = false

    private let repository: any SettingsRepository
    /// Called after every successful change, so services can re-read the values
    /// that affect them. Set once by `AppEnvironment`.
    var onChange: ((AppSettings) -> Void)?

    init(repository: any SettingsRepository, initial: AppSettings = AppSettings()) {
        self.repository = repository
        self.settings = initial
    }

    /// Reads the stored settings. Call once at launch, before the first screen.
    func load() async {
        do {
            settings = try await repository.settings()
            onChange?(settings)
        } catch {
            // Defaults are a working app. A settings read that fails must not
            // stop a child getting to the big button.
            HopLog.persistence.error(
                "settings load failed; using defaults error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            settings = AppSettings()
        }
    }

    /// Mutates and persists in one step.
    ///
    /// A closure rather than a setter per field: it keeps the write, the
    /// notification and the failure handling in one place, and it makes a
    /// two-field change one save instead of two.
    func update(_ transform: (inout AppSettings) -> Void) async {
        var updated = settings
        transform(&updated)
        guard updated != settings else { return }
        settings = updated
        do {
            try await repository.save(updated)
            lastWriteFailed = false
        } catch {
            lastWriteFailed = true
            HopLog.persistence.error(
                "settings save failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
        }
        onChange?(updated)
    }

    /// The child every child-facing screen is about.
    ///
    /// Nothing in HopPotty assumes a single child: this is a *selection*, and
    /// every query still takes an explicit id. It exists so the app can open on
    /// the child it was last used with, not so a repository can quietly default
    /// to one.
    func setActiveChild(_ childID: UUID?) async {
        await update { $0.activeChildID = childID }
    }

    /// Back to shipped defaults, in memory and on disk. Used by "Reset app".
    func resetToDefaults() async {
        do {
            try await repository.reset()
        } catch {
            HopLog.persistence.error(
                "settings reset failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
        }
        settings = AppSettings()
        onChange?(settings)
    }
}
