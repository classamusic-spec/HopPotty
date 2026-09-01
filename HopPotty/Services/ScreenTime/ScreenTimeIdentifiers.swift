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
//   HopPottyDeviceActivityMonitor (extension)
//   HopPottyShieldConfiguration (extension)
//   HopPottyShieldAction (extension)
//
// There is no Xcode project in this repository yet, so target membership cannot
// be expressed in a `.pbxproj`. When the project is created, this file, together
// with `AppGroupStore.swift` and `ShieldReconciler.swift`, must be added to all
// four targets. If it is added to fewer, the app and its extensions will disagree
// about the App Group name, the ManagedSettings store name, or the activity
// names — and a disagreement about the *store name* is exactly the bug that
// strands a shield the app cannot clear.
//
// A shared framework would express this better. It is deliberately not used
// here: an embedded framework adds launch cost to three memory-constrained
// extensions in exchange for expressing a fact that three lines of build
// configuration already express.

/// Every string that has to mean the same thing in the app and in all three
/// extensions.
///
/// These values are load-bearing in a way that ordinary constants are not.
/// `ManagedSettingsStore(named:)` is keyed by name: two different names are two
/// different stores, and a shield written to one cannot be cleared through the
/// other. The same is true of `DeviceActivityName`. Every one of them lives here
/// so there is exactly one place a typo can happen, and one place to check it
/// against the entitlements file.
public enum ScreenTimeIdentifiers {

    // MARK: App Group

    /// The App Group that carries pause state between the app and the extensions.
    ///
    /// Must appear verbatim in the `com.apple.security.application-groups`
    /// entitlement of all four targets. If it does not, `UserDefaults(suiteName:)`
    /// returns `nil` and `AppGroupStore` degrades to a per-process store — see
    /// `AppGroupStore.isSharedStoreAvailable`, which the Potty Pause Lab surfaces
    /// precisely so this misconfiguration is caught before a release.
    ///
    /// UNVERIFIED — confirm on device: that this identifier matches the App Group
    /// provisioned in the developer portal for the app and all three extension
    /// bundle identifiers. A mismatch is silent at build time and total at runtime.
    public static let appGroupID = "group.com.hoppotty.shared"

    // MARK: Bundle identifiers
    //
    // Recorded here for the Lab's diagnostic dump and for the entitlements
    // checklist. Nothing branches on them.

    public static let appBundleID = "com.hoppotty.app"
    public static let deviceActivityMonitorBundleID = "com.hoppotty.app.DeviceActivityMonitor"
    public static let shieldConfigurationBundleID = "com.hoppotty.app.ShieldConfiguration"
    public static let shieldActionBundleID = "com.hoppotty.app.ShieldAction"

    // MARK: ManagedSettings

    /// The name of the one `ManagedSettingsStore` HopPotty ever writes a shield to.
    ///
    /// A *named* store is used rather than the default unnamed one so that the
    /// Potty Pause shield is a separable, individually clearable unit of system
    /// state. Anything else HopPotty might one day set through ManagedSettings
    /// goes in its own store and can never be confused with a pause.
    ///
    /// Kept as a raw `String` for the Lab's dump; the typed constant is
    /// `ManagedSettingsStore.Name.pottyPause` below. The two must stay identical.
    public static let managedSettingsStoreName = "hoppotty.pottypause"

    // MARK: DeviceActivity
    //
    // Every activity name HopPotty registers begins with `activityPrefix`. That
    // is what makes "cancel everything of ours, and only ours" expressible —
    // `DeviceActivityCenter.stopMonitoring()` with no arguments would also stop
    // activities registered by a future feature, so the monitoring service always
    // enumerates and filters by this prefix instead.
    //
    // Names carry NO child identity. They are role plus integer slot. The monitor
    // extension does not need to know which child a pause is for — the device has
    // one active child at a time and the shield is device-wide — and giving the
    // extension an identifier it does not need is how identity leaks across a
    // process boundary that was supposed to carry five values.

    public static let activityPrefix = "hoppotty."

    /// Screen-activity monitoring: one long interval carrying a ladder of usage
    /// thresholds. See `MonitoringPlan` for why it is a ladder and not one event.
    public static let usageActivityName = "hoppotty.usage"

    /// Wall-clock monitoring: one activity per pause slot, because a
    /// `DeviceActivitySchedule` describes a single interval and cannot itself
    /// repeat every N minutes.
    public static let clockActivityPrefix = "hoppotty.clock."

    /// The safety net. A short interval registered at the moment a shield goes up,
    /// whose only job is to clear that shield if nothing else did.
    public static let guardActivityName = "hoppotty.guard"

    public static let thresholdEventPrefix = "hoppotty.threshold."
    public static let warningEventPrefix = "hoppotty.warning."

    public static func clockActivityName(slot: Int) -> String {
        "\(clockActivityPrefix)\(slot)"
    }

    public static func thresholdEventName(step: Int) -> String {
        "\(thresholdEventPrefix)\(step)"
    }

    public static func warningEventName(step: Int) -> String {
        "\(warningEventPrefix)\(step)"
    }

    /// Whether a name came from HopPotty. Used to scope bulk cancellation.
    public static func isHopPottyActivity(_ rawValue: String) -> Bool {
        rawValue.hasPrefix(activityPrefix)
    }

    /// What an activity name means, decided by prefix alone.
    ///
    /// The monitor extension branches on this and nothing else. Parsing a
    /// meaning out of a string is normally a smell; here the string is the only
    /// thing `DeviceActivityMonitor` hands the extension, so the alternative is
    /// reading shared state to find out why we were woken, which is strictly
    /// worse in a process that is trying to do the minimum.
    public enum ActivityRole: String, Sendable, CaseIterable {
        case usage
        case clock
        case guardrail
        /// A name we do not recognise. Treated as "cancel it" — an activity
        /// HopPotty cannot explain is an orphan from a previous build.
        case unrecognised
    }

    public static func role(of rawValue: String) -> ActivityRole {
        if rawValue == usageActivityName { return .usage }
        if rawValue == guardActivityName { return .guardrail }
        if rawValue.hasPrefix(clockActivityPrefix) { return .clock }
        return .unrecognised
    }

    public enum EventRole: String, Sendable {
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
    // These are HopPotty's self-imposed ceilings, set below the platform limits
    // we believe exist. They are conservative on purpose: exceeding a
    // DeviceActivity limit throws at registration time and leaves the family with
    // no monitoring at all, which is a much worse failure than a slightly coarser
    // schedule.

    /// UNVERIFIED — confirm on device: Apple documents a limit on simultaneously
    /// monitored activities per app (widely reported as 20). HopPotty never
    /// registers more than this many, leaving headroom for the guard activity and
    /// for any activity the system has not yet finished tearing down.
    public static let maximumMonitoredActivities = 12

    /// UNVERIFIED — confirm on device: the number of `DeviceActivityEvent`s a
    /// single activity may carry. Reported limits vary; this ceiling keeps a
    /// full-day usage ladder well inside any of them.
    public static let maximumUsageEvents = 16

    /// UNVERIFIED — confirm on device: `DeviceActivitySchedule` intervals shorter
    /// than 15 minutes are rejected. This is the single most consequential
    /// platform constraint in this layer: it is why a 3-minute pause cannot be
    /// bounded by a schedule directly, and why `guardIntervalDuration` exists.
    public static let minimumScheduleInterval: TimeInterval = 15 * 60

    /// How long the guard activity runs. Exactly the platform minimum: the guard
    /// is a backstop, and the sooner it fires the smaller the window in which a
    /// stranded shield can survive unnoticed.
    public static let guardIntervalDuration: TimeInterval = minimumScheduleInterval
}

#if canImport(ManagedSettings)
public extension ManagedSettingsStore.Name {
    /// The single store HopPotty shields through.
    ///
    /// Built from a string literal rather than
    /// `ManagedSettingsStore.Name(ScreenTimeIdentifiers.managedSettingsStoreName)`
    /// because `Name`'s `ExpressibleByStringLiteral` conformance is the spelling
    /// Apple's own samples use, and the unlabelled `init(_:)` is the part of the
    /// API surface I am least sure of.
    ///
    /// UNVERIFIED — confirm on device: that this literal equals
    /// `ScreenTimeIdentifiers.managedSettingsStoreName`. It is asserted at runtime
    /// in `ShieldReconciler.assertStoreNamesAgree()` under DEBUG, because the
    /// compiler cannot check a literal against a constant.
    static let pottyPause: ManagedSettingsStore.Name = "hoppotty.pottypause"
}
#endif

#if canImport(DeviceActivity)
public extension DeviceActivityName {
    /// UNVERIFIED — confirm on device: `DeviceActivityName` exposes an unlabelled
    /// `init(_ rawValue: String)`. If the compiler rejects this, the fix is
    /// `DeviceActivityName(rawValue: raw)` — the type is `RawRepresentable` either
    /// way, and `rawValue` is read back in several places below.
    init(hopPotty rawValue: String) {
        self.init(rawValue)
    }
}

public extension DeviceActivityEvent.Name {
    init(hopPotty rawValue: String) {
        self.init(rawValue)
    }
}
#endif
