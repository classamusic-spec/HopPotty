import Foundation
import HopPottyCore

// MARK: - Target membership
//
// SHARED BY ALL FOUR TARGETS. See the note at the top of `ScreenTimeIdentifiers.swift`.

/// The state boundary between the HopPotty app and its three extensions.
///
/// ## Why this is the smallest thing in the codebase
///
/// Four processes read and write this. Three of them are extensions with hard
/// memory ceilings, no UI, and lifetimes measured in milliseconds. None of them
/// can ask a question and wait for an answer. Whatever is here has to be
/// intelligible to a process that has just been woken up, knows nothing, and is
/// about to be killed.
///
/// So it holds five kinds of value and nothing else:
///
/// | Value | Why it cannot be derived |
/// | --- | --- |
/// | session id | Correlates an extension callback with the app's own session |
/// | pause state | Whether a shield is supposed to exist at all |
/// | started / expires | The only thing that can end a pause without the app |
/// | heartbeats | Which targets are actually running |
/// | failure code | What to show a caregiver who asks why nothing happened |
///
/// Plus two handoff flags, which exist because the shield action extension
/// cannot open the containing app and has to leave a note instead
/// (`HopPottyShieldActionExtension` documents that compromise in full).
///
/// ## What is deliberately NOT here
///
/// No child identifier. No nickname, age, or pronouns. No potty events, no
/// notes, no timeline, no star balance, no insight. No application tokens and no
/// encoded `FamilyActivitySelection`. No schedule.
///
/// The extensions do not need any of it. The device has one active child at a
/// time and the shield is device-wide, so "which child" is a question only the
/// app has to answer, and it answers it from its own private store by looking up
/// `sessionID`. An App Group container is readable by every target that carries
/// the entitlement and is included in device backups; a parenting app should put
/// the *least* it can across that line, not the most it conveniently could.
///
/// ## Reader/writer map
///
/// | Key | App | Monitor | ShieldConfig | ShieldAction |
/// | --- | --- | --- | --- | --- |
/// | `sessionID` | R/W | R | R | R |
/// | `pauseState` | R/W | R/W | R | R/W |
/// | `startedAt` / `startedUptime` | W | R | R | R |
/// | `expiresAt` | W | R | R | R |
/// | `failureCode` | R/W | W | — | W |
/// | `heartbeat(.app)` | W | — | — | — |
/// | `heartbeat(.monitor)` | R | W | — | — |
/// | `heartbeat(.shieldConfiguration)` | R | — | W | — |
/// | `heartbeat(.shieldAction)` | R | — | — | W |
/// | `childHandoffRequestedAt` | R/W | — | — | W |
/// | `grownUpRequestedAt` | R/W | — | — | W |
/// | `lastClear*` | R/W | W | W | W |
///
/// A cell that is `W` in an extension and `R` in the app is the whole point of
/// the boundary: the extension records what it did, the app finds out later.
public struct AppGroupStore: @unchecked Sendable {

    // `UserDefaults` is documented as thread-safe, and every access below is a
    // single get or set with no read-modify-write. `@unchecked Sendable` records
    // that this is a considered claim rather than an oversight.
    private let defaults: UserDefaults

    /// Whether the real App Group container was reachable.
    ///
    /// `false` means the entitlement is missing or the group identifier is wrong,
    /// and this instance is talking to a process-local `UserDefaults` that the
    /// other three targets cannot see. Every fail-safe in HopPotty still works in
    /// that state — because every fail-safe resolves *toward clearing*, and a
    /// reader that sees an empty store concludes "no session, clear the shield" —
    /// but automatic pauses will not function. The Potty Pause Lab shows this
    /// flag first, above everything else.
    public let isSharedStoreAvailable: Bool

    /// The shared instance. Extensions build their own rather than reaching for
    /// a global, because an extension that is about to be killed should not be
    /// initialising app-wide singletons.
    public static let shared = AppGroupStore()

    public init(suiteName: String = ScreenTimeIdentifiers.appGroupID) {
        if let shared = UserDefaults(suiteName: suiteName) {
            self.defaults = shared
            self.isSharedStoreAvailable = true
        } else {
            // Never crash. A parenting app that traps on a provisioning mistake
            // is a parenting app that a family cannot open to unlock their
            // child's iPad.
            self.defaults = .standard
            self.isSharedStoreAvailable = false
        }
    }

    /// Test seam. Lets the Lab and unit tests point at a scratch suite.
    public init(defaults: UserDefaults, isShared: Bool) {
        self.defaults = defaults
        self.isSharedStoreAvailable = isShared
    }

    // MARK: - Keys
    //
    // Short, prefixed, and versioned. Prefixed because the App Group container
    // is shared with anything else HopPotty may one day put there; short because
    // these are written from a memory-constrained extension.

    private enum Key {
        static let schemaVersion = "hp.v"
        static let sessionID = "hp.sid"
        static let pauseState = "hp.state"
        static let startedAt = "hp.t0"
        static let startedUptime = "hp.u0"
        static let expiresAt = "hp.t1"
        static let failureCode = "hp.fail"
        static let childHandoffRequestedAt = "hp.handoff"
        static let grownUpRequestedAt = "hp.grownup"
        static let lastClearAt = "hp.clr.t"
        static let lastClearReason = "hp.clr.r"

        static func heartbeat(_ target: HeartbeatTarget) -> String { "hp.hb.\(target.rawValue)" }
    }

    /// Bumped when the meaning of a key changes. A reader that finds a version it
    /// does not understand treats the whole record as absent, which — because
    /// absence means "clear the shield" — is the safe interpretation of a
    /// downgrade, a restored backup, or a hand-edited plist.
    public static let currentSchemaVersion = 1

    // MARK: - Values

    /// Which target is alive.
    public enum HeartbeatTarget: String, CaseIterable, Sendable {
        case app
        case monitor
        case shieldConfiguration = "shieldcfg"
        case shieldAction = "shieldact"
    }

    /// The pause, as the extensions need to understand it.
    ///
    /// Deliberately coarser than `PottyPauseState`. The extensions do not need
    /// thirteen states; they need to know whether a shield is supposed to exist.
    /// Mapping down to four values at the boundary means a future state added to
    /// the app cannot silently change what an extension believes.
    ///
    /// The default for an unrecognised or missing value is `.idle`, and `.idle`
    /// means "clear the shield". Every unknown resolves toward the child having
    /// their apps.
    public enum SharedPauseState: String, CaseIterable, Sendable {
        /// No pause. A shield found in this state is stranded and gets cleared.
        case idle
        /// A shield has been asked for and not confirmed. Treated as shielded.
        case raising
        /// A shield is up and a pause is running.
        case shielded
        /// A clear is in flight. Still treated as shielded, so a second clear is
        /// attempted rather than skipped.
        case clearing

        /// Whether a shield may exist in this state. Mirrors
        /// `PottyPauseState.mayHaveShieldUp` and errs the same way.
        public var mayHaveShieldUp: Bool { self != .idle }
    }

    // MARK: - Session record

    public var schemaVersion: Int {
        get { defaults.integer(forKey: Key.schemaVersion) }
        nonmutating set { defaults.set(newValue, forKey: Key.schemaVersion) }
    }

    /// An opaque per-pause identifier. A random UUID, not derived from and not
    /// resolvable to a child. The app keeps the session-to-child mapping in its
    /// own private store.
    public var sessionID: String? {
        get { defaults.string(forKey: Key.sessionID) }
        nonmutating set { defaults.set(newValue, forKey: Key.sessionID) }
    }

    public var pauseState: SharedPauseState {
        get {
            guard schemaVersion == Self.currentSchemaVersion,
                  let raw = defaults.string(forKey: Key.pauseState),
                  let state = SharedPauseState(rawValue: raw)
            else { return .idle }
            return state
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.pauseState) }
    }

    public var startedAt: Date? {
        get { date(forKey: Key.startedAt) }
        nonmutating set { setDate(newValue, forKey: Key.startedAt) }
    }

    /// `ProcessInfo.systemUptime` at the instant the pause started.
    ///
    /// The wall clock can be moved; uptime cannot, and it resets to near zero on
    /// reboot. Storing both is what lets `ShieldReconciler` tell "the clock was
    /// nudged" apart from "the device restarted" — two situations that both
    /// invalidate a session and would otherwise be indistinguishable from a
    /// `Date` alone.
    public var startedUptime: TimeInterval? {
        get { defaults.object(forKey: Key.startedUptime) as? TimeInterval }
        nonmutating set {
            if let newValue { defaults.set(newValue, forKey: Key.startedUptime) }
            else { defaults.removeObject(forKey: Key.startedUptime) }
        }
    }

    /// The instant the shield must be down by. Absolute, never wall-clock: a
    /// pause survives a timezone change and a DST transition unchanged, because
    /// an instant cannot be reinterpreted by a change of zone.
    public var expiresAt: Date? {
        get { date(forKey: Key.expiresAt) }
        nonmutating set { setDate(newValue, forKey: Key.expiresAt) }
    }

    /// The last thing that went wrong, as a `ScreenTimeFailure` raw value.
    /// A code, not a message: the sentence a caregiver reads is chosen by the app
    /// from `HopCopy`, and extensions have no business composing user-facing text.
    public var failureCode: ScreenTimeFailure? {
        get {
            guard let raw = defaults.string(forKey: Key.failureCode) else { return nil }
            return ScreenTimeFailure(rawValue: raw)
        }
        nonmutating set { defaults.set(newValue?.rawValue, forKey: Key.failureCode) }
    }

    // MARK: - Handoff flags
    //
    // Written only by the shield action extension. See
    // `HopPottyShieldActionExtension` for why a flag is the best available
    // mechanism and what it costs.

    /// The child tapped "Let's Go!" on the shield.
    public var childHandoffRequestedAt: Date? {
        get { date(forKey: Key.childHandoffRequestedAt) }
        nonmutating set { setDate(newValue, forKey: Key.childHandoffRequestedAt) }
    }

    /// The child tapped "Need a grown-up?" on the shield. This never unlocks
    /// anything on its own — a child can tap it, so it only raises a flag that a
    /// caregiver resolves behind the parent gate.
    public var grownUpRequestedAt: Date? {
        get { date(forKey: Key.grownUpRequestedAt) }
        nonmutating set { setDate(newValue, forKey: Key.grownUpRequestedAt) }
    }

    // MARK: - Clear audit
    //
    // One instant and one reason. Not a log: a log in shared storage grows
    // without bound in a process that cannot prune it. This is the answer to
    // "why did the apps come back?", which is the question a caregiver actually
    // asks, and the Lab shows it.

    public private(set) var lastClearAt: Date? {
        get { date(forKey: Key.lastClearAt) }
        nonmutating set { setDate(newValue, forKey: Key.lastClearAt) }
    }

    public private(set) var lastClearReason: String? {
        get { defaults.string(forKey: Key.lastClearReason) }
        nonmutating set { defaults.set(newValue, forKey: Key.lastClearReason) }
    }

    public func recordClear(reason: String, at instant: Date) {
        lastClearAt = instant
        lastClearReason = reason
    }

    // MARK: - Heartbeats

    public func heartbeat(_ target: HeartbeatTarget) -> Date? {
        date(forKey: Key.heartbeat(target))
    }

    /// Stamp a heartbeat. Called at the top of every extension entry point and on
    /// every app foreground.
    ///
    /// This is the only way to answer "is the DeviceActivity extension actually
    /// installed and being invoked?" without a device attached to a debugger. An
    /// extension that is missing from the build, mis-signed, or failing to launch
    /// leaves its heartbeat `nil` forever, and the Lab shows a dash.
    public func beat(_ target: HeartbeatTarget, at instant: Date = Date()) {
        setDate(instant, forKey: Key.heartbeat(target))
    }

    /// The most recent heartbeat from any target. Used by `ShieldReconciler` as a
    /// last-resort staleness check against a corrupt `expiresAt`.
    public var mostRecentHeartbeat: Date? {
        HeartbeatTarget.allCases.compactMap(heartbeat).max()
    }

    // MARK: - Compound operations
    //
    // Grouped so a caller cannot write half a session. There is no cross-process
    // lock here and none is needed: only the app ever *begins* a session, and
    // every reader treats a partially written record as absent, which clears.

    /// Record that a pause is starting. Written before the shield is applied, so
    /// a crash between the two leaves a record that says "shield may be up" —
    /// the conservative direction.
    public func beginSession(id: String, startedAt: Date, expiresAt: Date, uptime: TimeInterval) {
        schemaVersion = Self.currentSchemaVersion
        sessionID = id
        self.startedAt = startedAt
        self.expiresAt = expiresAt
        startedUptime = uptime
        childHandoffRequestedAt = nil
        grownUpRequestedAt = nil
        failureCode = nil
        pauseState = .raising
    }

    /// Wipe the session record. Called *after* a successful clear, never before:
    /// the record is what tells a later process that a shield might exist, so
    /// removing it first would hide the very problem it exists to expose.
    public func endSession() {
        pauseState = .idle
        sessionID = nil
        startedAt = nil
        expiresAt = nil
        startedUptime = nil
        childHandoffRequestedAt = nil
        grownUpRequestedAt = nil
    }

    /// Everything, as values, for the Lab's dump and for `ShieldReconciler`'s
    /// pure decision function. Taking one snapshot means the reconciler decides
    /// against a single consistent view instead of re-reading keys that another
    /// process may change underneath it.
    public func snapshot(now: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> AppGroupSnapshot {
        AppGroupSnapshot(
            isSharedStoreAvailable: isSharedStoreAvailable,
            schemaVersion: schemaVersion,
            sessionID: sessionID,
            pauseState: pauseState,
            startedAt: startedAt,
            startedUptime: startedUptime,
            expiresAt: expiresAt,
            failureCode: failureCode,
            childHandoffRequestedAt: childHandoffRequestedAt,
            grownUpRequestedAt: grownUpRequestedAt,
            lastClearAt: lastClearAt,
            lastClearReason: lastClearReason,
            heartbeats: Dictionary(
                uniqueKeysWithValues: HeartbeatTarget.allCases.map { ($0, heartbeat($0)) }
            ),
            observedAt: now,
            observedUptime: uptime
        )
    }

    /// Remove every HopPotty key. Used by the Lab's "reset environment" and by
    /// nothing else — in particular *not* by the fail-safe path, which clears the
    /// shield first and only then ends the session.
    public func removeAll() {
        let keys = [
            Key.schemaVersion, Key.sessionID, Key.pauseState, Key.startedAt,
            Key.startedUptime, Key.expiresAt, Key.failureCode,
            Key.childHandoffRequestedAt, Key.grownUpRequestedAt,
            Key.lastClearAt, Key.lastClearReason,
        ] + HeartbeatTarget.allCases.map(Key.heartbeat)
        for key in keys { defaults.removeObject(forKey: key) }
    }

    // MARK: - Date storage
    //
    // Stored as `timeIntervalSinceReferenceDate` doubles rather than `Date`
    // objects. `UserDefaults` can store a `Date`, but a plist round-trip through
    // a backup or a device migration is one fewer moving part when the value is
    // a primitive. `0` is a real instant (2001-01-01), so absence is expressed by
    // the key being missing, checked explicitly.

    private func date(forKey key: String) -> Date? {
        guard let interval = defaults.object(forKey: key) as? TimeInterval else { return nil }
        return Date(timeIntervalSinceReferenceDate: interval)
    }

    private func setDate(_ date: Date?, forKey key: String) {
        if let date {
            defaults.set(date.timeIntervalSinceReferenceDate, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

/// A consistent read of the whole shared record.
public struct AppGroupSnapshot: Equatable, Sendable {
    public let isSharedStoreAvailable: Bool
    public let schemaVersion: Int
    public let sessionID: String?
    public let pauseState: AppGroupStore.SharedPauseState
    public let startedAt: Date?
    public let startedUptime: TimeInterval?
    public let expiresAt: Date?
    public let failureCode: ScreenTimeFailure?
    public let childHandoffRequestedAt: Date?
    public let grownUpRequestedAt: Date?
    public let lastClearAt: Date?
    public let lastClearReason: String?
    public let heartbeats: [AppGroupStore.HeartbeatTarget: Date?]
    public let observedAt: Date
    public let observedUptime: TimeInterval

    public init(
        isSharedStoreAvailable: Bool,
        schemaVersion: Int,
        sessionID: String?,
        pauseState: AppGroupStore.SharedPauseState,
        startedAt: Date?,
        startedUptime: TimeInterval?,
        expiresAt: Date?,
        failureCode: ScreenTimeFailure?,
        childHandoffRequestedAt: Date?,
        grownUpRequestedAt: Date?,
        lastClearAt: Date?,
        lastClearReason: String?,
        heartbeats: [AppGroupStore.HeartbeatTarget: Date?],
        observedAt: Date,
        observedUptime: TimeInterval
    ) {
        self.isSharedStoreAvailable = isSharedStoreAvailable
        self.schemaVersion = schemaVersion
        self.sessionID = sessionID
        self.pauseState = pauseState
        self.startedAt = startedAt
        self.startedUptime = startedUptime
        self.expiresAt = expiresAt
        self.failureCode = failureCode
        self.childHandoffRequestedAt = childHandoffRequestedAt
        self.grownUpRequestedAt = grownUpRequestedAt
        self.lastClearAt = lastClearAt
        self.lastClearReason = lastClearReason
        self.heartbeats = heartbeats
        self.observedAt = observedAt
        self.observedUptime = observedUptime
    }

    /// Multi-line, human-readable, and free of anything sensitive by
    /// construction — there is nothing sensitive in the record to leak.
    public var debugDump: [String] {
        func stamp(_ date: Date?) -> String {
            guard let date else { return "—" }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullTime, .withColonSeparatorInTime]
            let relative = Int(observedAt.timeIntervalSince(date))
            return "\(formatter.string(from: date))  (\(relative)s ago)"
        }
        var lines: [String] = [
            "shared container: \(isSharedStoreAvailable ? "available" : "UNAVAILABLE — entitlement or group id is wrong")",
            "schema: \(schemaVersion) (expected \(AppGroupStore.currentSchemaVersion))",
            "session: \(sessionID ?? "—")",
            "state: \(pauseState.rawValue)",
            "startedAt: \(stamp(startedAt))",
            "expiresAt: \(stamp(expiresAt))",
            "startedUptime: \(startedUptime.map { String(format: "%.0fs", $0) } ?? "—") (now \(String(format: "%.0fs", observedUptime)))",
            "failure: \(failureCode?.rawValue ?? "—")",
            "childHandoff: \(stamp(childHandoffRequestedAt))",
            "grownUpRequest: \(stamp(grownUpRequestedAt))",
            "lastClear: \(stamp(lastClearAt)) \(lastClearReason ?? "")",
        ]
        for target in AppGroupStore.HeartbeatTarget.allCases {
            lines.append("heartbeat \(target.rawValue): \(stamp(heartbeats[target] ?? nil))")
        }
        return lines
    }
}
