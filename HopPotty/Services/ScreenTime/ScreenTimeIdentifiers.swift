import Foundation
#if canImport(ManagedSettings)
import ManagedSettings
#endif
#if canImport(DeviceActivity)
import DeviceActivity
#endif

// MARK: - Target membership
//
// THIS FILE IS SHARED BY FOUR TARGETS.
//
//   HopPotty (app)
//   HopPottyDeviceActivityMonitor  (extension)
//   HopPottyShieldConfiguration    (extension)
//   HopPottyShieldAction           (extension)
//
// There is no Xcode project in this repository yet, so target membership cannot
// be expressed in a `.pbxproj`. When the project is created, this file, together
// with `AppGroupStore.swift`, `SharedPauseTypes.swift` and `ShieldReconciler.swift`,
// must be added to all four targets. If it is added to fewer, the app and its
// extensions will disagree about the App Group identifier or the ManagedSettings
// store name — and a disagreement about the *store name* is precisely the bug
// that strands a shield the app cannot clear.
//
// A shared framework would express this better. It is deliberately not used: an
// embedded framework adds launch cost to three latency-sensitive extensions in
// exchange for expressing a fact that three lines of build configuration already
// express. `Docs/ScreenTimeArchitecture.md` §8 has the full target topology.

/// Every string that must mean the same thing in the app and in all three
/// extensions.
///
/// These are load-bearing in a way ordinary constants are not.
/// `ManagedSettingsStore(named:)` is keyed by name — two names are two stores,
/// and a shield written to one cannot be cleared through the other. The same is
/// true of `DeviceActivityName`. They live in one file so there is exactly one
/// place a typo can happen and one place to check against the entitlements.
public enum ScreenTimeIdentifiers {

    // MARK: App Group

    /// The App Group container that carries HopPotty's own pause state between
    /// the app and the extensions.
    ///
    /// `Docs/Entitlements.md` §1 records this as `group.com.<team>.hoppotty`,
    /// where `<team>` is the Team ID, which is not yet known. When the Xcode
    /// project and the provisioning profiles are created, **this constant and the
    /// `com.apple.security.application-groups` entitlement of all four targets
    /// change together, in the same commit.** A mismatch is silent at build time
    /// and total at runtime.
    ///
    /// Note that this group carries only HopPotty's data. Named
    /// `ManagedSettingsStore`s are shared between an app and its extensions
    /// automatically, with no App Group involvement (WWDC22 session 110336) —
    /// so a broken App Group breaks *coordination*, not the shield itself, which
    /// is why every fail-safe below still works without it.
    public static let appGroupID = "group.com.hoppotty"

    // MARK: Bundle identifiers
    //
    // Placeholders matching `Docs/Entitlements.md` §1. Recorded for the Lab's
    // diagnostic dump; nothing branches on them.

    public static let appBundleID = "com.hoppotty"
    public static let monitorBundleID = "com.hoppotty.monitor"
    public static let shieldConfigurationBundleID = "com.hoppotty.shieldconfig"
    public static let shieldActionBundleID = "com.hoppotty.shieldaction"

    // MARK: ManagedSettings

    /// The name of the one `ManagedSettingsStore` HopPotty ever writes a shield to.
    ///
    /// A *named* store rather than the default unnamed one, so a Potty Pause is a
    /// separable unit of system state that can be cleared without touching
    /// anything else. `Docs/ScreenTimeArchitecture.md` §5 records the store
    /// layout: this store, and the default store deliberately left empty so that
    /// a future feature — or a bug in one — cannot strand a pause shield.
    ///
    /// Kept as a raw `String` for the Lab's dump; the typed constant is
    /// `ManagedSettingsStore.Name.pottyPause` below. The two must stay identical,
    /// which `ShieldReconciler.assertStoreNamesAgree()` checks in DEBUG.
    public static let managedSettingsStoreName = "hoppotty.pottypause"

    // MARK: DeviceActivity
    //
    // Every activity name begins with `activityPrefix`. That is what makes
    // "cancel everything of ours, and only ours" expressible: `stopMonitoring()`
    // with no arguments stops *everything*, including activities a future
    // feature registers, so the monitoring service always enumerates and filters
    // by this prefix instead.
    //
    // Names carry NO child identity. They are a role plus an integer slot. The
    // monitor extension does not need to know which child a pause is for — the
    // device has one active child at a time (`AppSettings.activeChildID`) and the
    // shield is device-wide — and handing an extension an identifier it does not
    // need is how identity leaks across a boundary meant to carry five values.
    //
    // Names are also deliberately *reused* rather than accumulated. Apple:
    // "Monitoring a second activity with the same name as a previous activity
    // overwrites the schedule for the first one." Re-registering under a stable
    // name is the documented way to update, and it is what keeps HopPotty far
    // below the 20-activity cap.

    public static let activityPrefix = "hoppotty."

    /// Screen-activity monitoring: one long interval carrying a ladder of usage
    /// thresholds. See `MonitoringPlan` for why it is a ladder and not one event.
    public static let usageActivityName = "hoppotty.usage"

    /// Wall-clock monitoring: one activity per pause slot, because a
    /// `DeviceActivitySchedule` describes a single interval and cannot repeat
    /// every N minutes within a day.
    public static let clockActivityPrefix = "hoppotty.clock."

    /// The backstop. A 15-minute interval registered at the moment a shield goes
    /// up, whose `intervalWillEndWarning` is aimed at the intended pause end and
    /// whose `intervalDidEnd` is the guaranteed ceiling.
    /// `Docs/ScreenTimeArchitecture.md` §9 paths (B) and (C).
    public static let backstopActivityName = "hoppotty.backstop"

    public static let thresholdEventPrefix = "hoppotty.threshold."
    public static let warningEventPrefix = "hoppotty.warning."

    public static func clockActivityName(slot: Int) -> String { "\(clockActivityPrefix)\(slot)" }
    public static func thresholdEventName(step: Int) -> String { "\(thresholdEventPrefix)\(step)" }
    public static func warningEventName(step: Int) -> String { "\(warningEventPrefix)\(step)" }

    /// Whether a name came from HopPotty. Used to scope bulk cancellation.
    public static func isHopPottyActivity(_ rawValue: String) -> Bool {
        rawValue.hasPrefix(activityPrefix)
    }

    /// What an activity name means, decided by prefix alone.
    ///
    /// The monitor extension branches on this and nothing else. Parsing meaning
    /// out of a string is normally a smell; here the string is the only thing
    /// `DeviceActivityMonitor` hands the extension, and the alternative — reading
    /// shared state to discover why we were woken — is strictly worse in a
    /// process trying to do the minimum.
    public enum ActivityRole: String, Sendable, Codable, CaseIterable {
        case usage
        case clock
        case backstop
        /// A name we do not recognise: an orphan from a previous build. Treated
        /// as "stop monitoring it".
        case unrecognised
    }

    public static func role(of rawValue: String) -> ActivityRole {
        if rawValue == usageActivityName { return .usage }
        if rawValue == backstopActivityName { return .backstop }
        if rawValue.hasPrefix(clockActivityPrefix) { return .clock }
        return .unrecognised
    }

    public enum EventRole: String, Sendable, Codable {
        case threshold
        case warning
        case unrecognised
    }

    public static func eventRole(of rawValue: String) -> EventRole {
        if rawValue.hasPrefix(thresholdEventPrefix) { return .threshold }
        if rawValue.hasPrefix(warningEventPrefix) { return .warning }
        return .unrecognised
    }

    // MARK: Platform limits
    //
    // Documented values from `Docs/ScreenTimeArchitecture.md` §4 and §5, plus
    // HopPotty's own ceilings set below them. The margins are deliberate:
    // exceeding a DeviceActivity limit throws at registration and leaves the
    // family with *no* monitoring, which is much worse than a coarser schedule.

    /// Apple's documented cap on concurrently monitored activities, app-wide,
    /// across the app and all extensions. Exceeding it throws
    /// `DeviceActivityCenter.MonitoringError.excessiveActivities`, which HopPotty
    /// maps to `ScreenTimeFailure.monitoringLimitReached`.
    public static let platformActivityLimit = 20

    /// HopPotty's own ceiling, well under the platform's. One backstop plus at
    /// most this many scheduled activities.
    public static let maximumScheduledActivities = 8

    /// Apple's documented cap per shield property: 50 application tokens, 50
    /// category tokens, 50 web domain tokens. Apple does not document what
    /// happens at 51 — the caregiver picker must not let it happen.
    ///
    /// UNVERIFIED — confirm on device: whether exceeding 50 truncates silently,
    /// shields nothing, or throws. Until it is known, HopPotty refuses to apply
    /// an over-cap selection and tells the caregiver, which is the only behaviour
    /// that is correct under all three answers.
    public static let shieldTokenLimit = 50

    /// UNVERIFIED — confirm on device: the number of `DeviceActivityEvent`s a
    /// single activity may carry. Apple documents no figure. This ceiling keeps a
    /// full-day usage ladder well inside any plausible limit.
    public static let maximumUsageEvents = 16

    /// Apple's documented minimum `DeviceActivitySchedule` interval. Shorter
    /// intervals throw `.intervalTooShort`.
    ///
    /// This is the single most consequential constraint in this layer: it is why
    /// a 3-minute pause cannot be timed by DeviceActivity at all, and why the
    /// backstop schedule is 15 minutes with the intended end delivered by
    /// `warningTime`. See `Docs/ScreenTimeArchitecture.md` §9.
    public static let minimumScheduleInterval: TimeInterval = 15 * 60

    /// Apple's documented maximum interval: one week.
    public static let maximumScheduleInterval: TimeInterval = 7 * 24 * 60 * 60

    /// The backstop interval. Exactly the platform minimum: the sooner it ends,
    /// the smaller the window in which a stranded shield can survive unnoticed.
    public static let backstopIntervalDuration: TimeInterval = minimumScheduleInterval
}

#if canImport(ManagedSettings)
public extension ManagedSettingsStore.Name {
    /// The single store HopPotty shields through.
    ///
    /// Built from a string literal rather than from
    /// `ScreenTimeIdentifiers.managedSettingsStoreName` because `Name`'s
    /// `ExpressibleByStringLiteral` conformance is the spelling Apple's own
    /// samples use, and the unlabelled `init(_:)` is the part of that API surface
    /// I am least certain of.
    ///
    /// The compiler cannot check a literal against a constant, so
    /// `ShieldReconciler.assertStoreNamesAgree()` does, in DEBUG, at first use.
    static let pottyPause: ManagedSettingsStore.Name = "hoppotty.pottypause"
}
#endif

#if canImport(DeviceActivity)
public extension DeviceActivityName {
    /// UNVERIFIED — confirm on device: `DeviceActivityName` exposes an unlabelled
    /// `init(_ rawValue: String)`. If the compiler rejects this, the fix is
    /// `self.init(rawValue: rawValue)` — the type is `RawRepresentable` either
    /// way, and `rawValue` is read back in several places below.
    init(hopPotty rawValue: String) { self.init(rawValue) }
}

public extension DeviceActivityEvent.Name {
    init(hopPotty rawValue: String) { self.init(rawValue) }
}
#endif
