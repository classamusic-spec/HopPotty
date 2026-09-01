import Foundation
#if canImport(ManagedSettings)
import ManagedSettings
#endif

// MARK: - Target membership
//
// SHARED BY THE APP AND THE DEVICE ACTIVITY MONITOR EXTENSION.

/// The three token sets a shield is built from, stored separately from the
/// caregiver's `FamilyActivitySelection`.
///
/// ## Why there are two copies of the same information
///
/// `selection.json` holds the whole `FamilyActivitySelection`, because that is
/// what `FamilyActivityPicker` round-trips and it carries `includeEntireCategory`
/// with it. But `FamilyActivitySelection` lives in **FamilyControls**, and the
/// monitor extension must not link FamilyControls: it is a latency-sensitive
/// process whose only job with these values is to hand them to
/// `ManagedSettingsStore`, and the token types themselves — `ApplicationToken`,
/// `ActivityCategoryToken`, `WebDomainToken`, all aliases of ManagedSettings'
/// `Token<T>` — are already in a framework it has to link anyway.
///
/// So the app writes the selection for itself and the tokens for the extension.
/// Both are written in the same call, from the same value, so they cannot
/// disagree; if they ever did, the tokens win, because the tokens are what
/// actually shields.
///
/// ## These are opaque and stay opaque
///
/// A token has no readable payload and HopPotty never tries to give it one. It is
/// not logged, not hashed into a key, not counted into anything but a total, and
/// not sent off-device. `Codable` is Apple's own persistence route for them, and
/// it is the only one used here.
///
/// Apple voids every token issued to an app when authorization is revoked, so
/// this file is deleted at the same moment the selection is
/// (`ScreenTimeService.clearSelection`).
#if canImport(ManagedSettings)
public struct ShieldTokens: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let applications: Set<ApplicationToken>
    public let categories: Set<ActivityCategoryToken>
    public let webDomains: Set<WebDomainToken>

    public init(
        schemaVersion: Int = ShieldTokens.currentSchemaVersion,
        applications: Set<ApplicationToken>,
        categories: Set<ActivityCategoryToken>,
        webDomains: Set<WebDomainToken>
    ) {
        self.schemaVersion = schemaVersion
        self.applications = applications
        self.categories = categories
        self.webDomains = webDomains
    }

    public var isEmpty: Bool {
        applications.isEmpty && categories.isEmpty && webDomains.isEmpty
    }

    /// Apple caps each shield property at 50.
    public var exceedsLimit: Bool {
        applications.count > ScreenTimeIdentifiers.shieldTokenLimit
            || categories.count > ScreenTimeIdentifiers.shieldTokenLimit
            || webDomains.count > ScreenTimeIdentifiers.shieldTokenLimit
    }
}

/// The one place a shield is ever raised.
///
/// Both the app and the monitor extension call this, so there is a single
/// definition of what "shielded" means. A second implementation would be a second
/// opportunity to write to the wrong store.
public enum ShieldApplier {

    /// Write the shield.
    ///
    /// Every property is set on every call, `nil` included. Apple: "Changing the
    /// value of a setting to `nil` deletes your app's configuration for that
    /// setting from the device." Setting all four unconditionally means a pause
    /// that shields only apps cannot inherit a category policy from a previous
    /// pause that shielded categories.
    ///
    /// `nil` rather than an empty set, always. An empty set is a configuration
    /// that shields nothing, which is a different thing from having no
    /// configuration, and Apple documents the behaviour of neither.
    ///
    /// Returns `false` only for the one condition worth refusing on: an over-cap
    /// selection, whose behaviour Apple does not document. Everything else is
    /// written and reported through the read-back, because a `ManagedSettings`
    /// write has no result to check.
    @discardableResult
    public static func apply(_ tokens: ShieldTokens) -> Bool {
        guard !tokens.isEmpty, !tokens.exceedsLimit else { return false }

        let store = ManagedSettingsStore(named: .pottyPause)
        store.shield.applications = tokens.applications.isEmpty ? nil : tokens.applications
        store.shield.webDomains = tokens.webDomains.isEmpty ? nil : tokens.webDomains
        store.shield.applicationCategories = tokens.categories.isEmpty
            ? nil
            : .specific(tokens.categories, except: Set())
        store.shield.webDomainCategories = tokens.categories.isEmpty
            ? nil
            : .specific(tokens.categories, except: Set())
        return true
    }

    /// Whether HopPotty's own store currently asks for anything to be shielded.
    ///
    /// A record of what was requested, not an observation of the device. Apple:
    /// "The system doesn't guarantee that the settings you specify govern the
    /// device's behavior."
    ///
    /// UNVERIFIED — confirm on device: that a read returns what was last written,
    /// promptly, within a process and across processes.
    public static var storeRequestsAShield: Bool {
        let store = ManagedSettingsStore(named: .pottyPause)
        if let applications = store.shield.applications, !applications.isEmpty { return true }
        if let domains = store.shield.webDomains, !domains.isEmpty { return true }
        if store.shield.applicationCategories != nil { return true }
        if store.shield.webDomainCategories != nil { return true }
        return false
    }
}

// MARK: - Container access

public extension AppGroupStore {

    private static var tokensFile: String { "tokens.json" }

    func loadShieldTokens() -> ShieldTokens? {
        guard let root,
              let data = try? Data(contentsOf: root.appendingPathComponent(Self.tokensFile)),
              let tokens = try? JSONDecoder().decode(ShieldTokens.self, from: data)
        else { return nil }
        return tokens.schemaVersion == ShieldTokens.currentSchemaVersion ? tokens : nil
    }

    @discardableResult
    func saveShieldTokens(_ tokens: ShieldTokens) -> Bool {
        guard let root, let data = try? JSONEncoder().encode(tokens) else { return false }
        return (try? data.write(to: root.appendingPathComponent(Self.tokensFile), options: .atomic)) != nil
    }

    func clearShieldTokens() {
        guard let root else { return }
        try? FileManager.default.removeItem(at: root.appendingPathComponent(Self.tokensFile))
    }
}
#endif
