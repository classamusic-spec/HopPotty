import Foundation
import HopPottyCore

// MARK: - Target membership
//
// SHARED BY ALL FOUR TARGETS. See the note at the top of `ScreenTimeIdentifiers.swift`.

/// The state boundary between the HopPotty app and its three extensions.
///
/// ## Why files and not `UserDefaults`
///
/// `Docs/Entitlements.md` settles this: `UserDefaults(suiteName:)` gives no
/// atomicity guarantee that can be reasoned about across four processes, whereas
/// `Data.write(to:options:.atomic)` renames a complete file into place, so a
/// reader either sees the whole previous record or the whole new one. With three
/// extensions that can be woken at arbitrary moments and killed mid-write, that
/// distinction is the difference between "a redundant clear" and "a record that
/// half-parses".
///
/// ## Layout
///
/// ```
/// <group container>/HopPotty/
///   pause.json          the active pause record         (app, monitor, shieldAction)
///   shield.json         pre-resolved shield appearance  (app writes, shieldConfig reads)
///   selection.json      encoded FamilyActivitySelection (app writes, monitor reads)
///   heartbeat/<t>.json  one file per target             (each target writes only its own)
///   outbox/<uuid>.json  extension → app reports         (extensions append, app drains)
/// ```
///
/// ## Writer discipline
///
/// | File | Writers | Readers | Race handling |
/// | --- | --- | --- | --- |
/// | `pause.json` | app, monitor, shieldAction | all four | Atomic; last write wins. Safe because the record's instants are `let` and no writer may lengthen a pause — see `SharedPauseRecord`. |
/// | `shield.json` | app only | shieldConfiguration | Single writer. |
/// | `selection.json` | app only | monitor | Single writer. Contains opaque tokens, never identities. |
/// | `heartbeat/<t>` | exactly one target each | app | Single writer per file by construction. |
/// | `outbox/*` | monitor, shieldAction, shieldConfiguration | app (drains and deletes) | One file per record, so appending is a create and draining is a delete. No read-modify-write anywhere. |
///
/// ## What never crosses this boundary
///
/// No child identifier, nickname, age, pronouns or notes. No `PottyEvent`, no
/// star ledger, no schedule, no insight. No free-form text of any kind — see the
/// note on `ExtensionReport`, which has no `String` field a caller could fill in.
/// An App Group container is readable by every target holding the entitlement and
/// is included in device backups; a parenting app puts the least it can across
/// that line, not the most it conveniently could.
///
/// Application tokens *are* permitted in `selection.json`: they are opaque by
/// construction, `Codable` is Apple's own persistence route for them, and the
/// monitor extension cannot shield anything without them. They may never be
/// logged, hashed into a key, or sent off-device.
public struct AppGroupStore: Sendable {

    /// The container root, or `nil` when the App Group is unreachable.
    ///
    /// `nil` means the entitlement is missing or `appGroupID` is wrong. Every
    /// fail-safe in HopPotty still works in that state — because every fail-safe
    /// resolves *toward clearing*, and a reader that finds no record concludes
    /// "no session, clear the shield" — but automatic pauses will not function.
    /// The Potty Pause Lab shows this first, above everything else.
    public let root: URL?

    public var isSharedContainerAvailable: Bool { root != nil }

    public static let shared = AppGroupStore()

    public init(groupID: String = ScreenTimeIdentifiers.appGroupID) {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("HopPotty", isDirectory: true)
        self.root = container
        // Best-effort. A failure here is indistinguishable at read time from an
        // empty container, and an empty container is the safe reading.
        if let container {
            try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: container.appendingPathComponent("heartbeat", isDirectory: true), withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: container.appendingPathComponent("outbox", isDirectory: true), withIntermediateDirectories: true)
        }
    }

    /// Test and Lab seam: point the store at a scratch directory.
    public init(root: URL?) {
        self.root = root
        if let root {
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: root.appendingPathComponent("heartbeat", isDirectory: true), withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: root.appendingPathComponent("outbox", isDirectory: true), withIntermediateDirectories: true)
        }
    }

    // MARK: - Coding
    //
    // ISO-8601 dates rather than the default `Double` reference-date encoding, so
    // the container is legible when dumped from a device during QA. That is worth
    // the handful of bytes: `Docs/PhysicalDeviceQA.md` asks a tester to read these
    // files, and "2026-09-01T14:03:00Z" is a fact a person can check against a
    // wall clock while "778430580.0" is not.

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private func url(_ component: String) -> URL? {
        root?.appendingPathComponent(component)
    }

    /// Read and decode, or `nil`.
    ///
    /// Every failure — missing container, missing file, unreadable bytes,
    /// unparseable JSON, a schema from the future — comes back as `nil`, because
    /// every one of them means the same thing to a caller: *you do not know what
    /// is going on, so clear the shield*. Distinguishing them would invite a
    /// caller to treat one of them as "probably fine".
    private func read<T: Decodable>(_ type: T.Type, from component: String) -> T? {
        guard let url = url(component), let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode(type, from: data)
    }

    @discardableResult
    private func write<T: Encodable>(_ value: T, to component: String) -> Bool {
        guard let url = url(component), let data = try? Self.encoder.encode(value) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private func remove(_ component: String) {
        guard let url = url(component) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Pause record

    private static let pauseFile = "pause.json"

    /// The active pause, if the record is present, parseable, and written by a
    /// schema this build understands.
    public func loadPause() -> SharedPauseRecord? {
        guard let record = read(SharedPauseRecord.self, from: Self.pauseFile) else { return nil }
        guard record.schemaVersion == SharedPauseRecord.currentSchemaVersion else { return nil }
        return record
    }

    @discardableResult
    public func savePause(_ record: SharedPauseRecord) -> Bool {
        write(record, to: Self.pauseFile)
    }

    /// Remove the pause record.
    ///
    /// **Always called *after* the shield has been cleared, never before.** The
    /// record is the only evidence that a shield might exist; deleting it first
    /// would hide the very problem it exists to expose from every process that
    /// runs afterwards.
    public func clearPause() {
        remove(Self.pauseFile)
    }

    /// Move an existing record to a new state without disturbing its instants.
    /// A no-op when there is no record, which is correct: there is nothing to
    /// advance, and inventing a record here would invent a shield.
    public func advancePause(to state: SharedPauseState, failure: ScreenTimeFailure? = nil) {
        guard var record = loadPause() else { return }
        record.state = state
        if let failure { record.failureCode = failure.rawValue }
        savePause(record)
    }

    // MARK: - Shield presentation

    private static let shieldFile = "shield.json"

    public func loadShieldPresentation() -> ShieldPresentation? {
        guard let presentation = read(ShieldPresentation.self, from: Self.shieldFile) else { return nil }
        guard presentation.schemaVersion == ShieldPresentation.currentSchemaVersion else { return nil }
        return presentation
    }

    @discardableResult
    public func saveShieldPresentation(_ presentation: ShieldPresentation) -> Bool {
        write(presentation, to: Self.shieldFile)
    }

    // MARK: - Selection
    //
    // Stored as raw bytes. This layer never decodes it, because decoding requires
    // FamilyControls and the whole point of keeping it opaque here is that the
    // store has no opinion about what is inside. `FamilyActivitySelectionStore`
    // owns the encoding.

    private static let selectionFile = "selection.json"

    public func loadSelectionData() -> Data? {
        guard let url = url(Self.selectionFile) else { return nil }
        return try? Data(contentsOf: url)
    }

    @discardableResult
    public func saveSelectionData(_ data: Data) -> Bool {
        guard let url = url(Self.selectionFile) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    public func clearSelectionData() {
        remove(Self.selectionFile)
    }

    // MARK: - Heartbeats
    //
    // One file per target, so each target is the sole writer of its own. This is
    // the only way to answer "is the DeviceActivity extension actually installed,
    // signed, and being invoked?" without a debugger attached: an extension that
    // is missing from the build or failing to launch leaves its heartbeat absent
    // forever, and the Lab shows a dash.

    public struct Heartbeat: Codable, Equatable, Sendable {
        public let at: Date
        public let uptime: TimeInterval
        public init(at: Date, uptime: TimeInterval) {
            self.at = at
            self.uptime = uptime
        }
    }

    public enum HeartbeatTarget: String, CaseIterable, Sendable {
        case app
        case monitor
        case shieldConfiguration = "shieldcfg"
        case shieldAction = "shieldact"
    }

    private func heartbeatFile(_ target: HeartbeatTarget) -> String {
        "heartbeat/\(target.rawValue).json"
    }

    public func heartbeat(_ target: HeartbeatTarget) -> Heartbeat? {
        read(Heartbeat.self, from: heartbeatFile(target))
    }

    /// Stamp a heartbeat. Called at the top of every extension entry point and on
    /// every app foreground.
    public func beat(
        _ target: HeartbeatTarget,
        at instant: Date = Date(),
        uptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        write(Heartbeat(at: instant, uptime: uptime), to: heartbeatFile(target))
    }

    public var mostRecentHeartbeat: Date? {
        HeartbeatTarget.allCases.compactMap { heartbeat($0)?.at }.max()
    }

    // MARK: - Outbox
    //
    // Append-only, one file per record. Appending is a create and draining is a
    // delete, so there is no read-modify-write across the process boundary
    // anywhere in the design.

    /// A hard cap on the outbox, enforced on every append.
    ///
    /// An unbounded directory in shared storage is a slow leak that nothing on
    /// the extension side is in a position to notice: the app drains it, and an
    /// app that is never opened never drains. Sixty records is several days of
    /// ordinary use and a few minutes of a pathological retry loop, which is
    /// exactly the case worth bounding.
    public static let outboxCapacity = 60

    private var outboxDirectory: URL? { url("outbox") }

    /// Append one report. Never throws and never blocks: an extension that cannot
    /// file a report must still return a shield configuration or a shield action.
    public func appendReport(_ report: ExtensionReport) {
        guard let directory = outboxDirectory else { return }
        guard let data = try? Self.encoder.encode(report) else { return }
        let file = directory.appendingPathComponent("\(report.id).json")
        try? data.write(to: file, options: .atomic)
        pruneOutbox()
    }

    /// Read every report, oldest first.
    public func loadReports() -> [ExtensionReport] {
        guard let directory = outboxDirectory else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        )) ?? []
        return files
            .compactMap { file -> ExtensionReport? in
                guard let data = try? Data(contentsOf: file) else { return nil }
                guard let report = try? Self.decoder.decode(ExtensionReport.self, from: data) else {
                    // A record this build cannot parse is deleted rather than
                    // left to be retried forever. It is diagnostic data; losing
                    // one is a smaller problem than a permanently stuck outbox.
                    try? FileManager.default.removeItem(at: file)
                    return nil
                }
                return report.schemaVersion == ExtensionReport.currentSchemaVersion ? report : nil
            }
            .sorted { $0.at < $1.at }
    }

    /// Read every report and delete it in the same pass.
    ///
    /// Only the app calls this. Delivery is at-most-once from the app's point of
    /// view — a crash between the read and the delete loses a record — which is
    /// acceptable *only because* nothing safety-critical depends on the outbox.
    /// A shield is never cleared because a report said so; it is cleared because
    /// `ShieldReconciler` decided so from `pause.json`. The outbox exists to
    /// award a star and to fill in the timeline, and the reward ledger is
    /// idempotent (Contract §4.2), so a replayed record is harmless too.
    public func drainReports() -> [ExtensionReport] {
        let reports = loadReports()
        guard let directory = outboxDirectory else { return reports }
        for report in reports {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(report.id).json"))
        }
        return reports
    }

    private func pruneOutbox() {
        guard let directory = outboxDirectory else { return }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        guard files.count > Self.outboxCapacity else { return }
        let sorted = files.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return l < r
        }
        for file in sorted.prefix(files.count - Self.outboxCapacity) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Snapshot and reset

    /// One consistent read of everything the reconciler and the Lab need.
    ///
    /// Taking a snapshot means the reconciler decides against a single view
    /// rather than re-reading files another process may change underneath it.
    public func snapshot(
        now: Date = Date(),
        uptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> AppGroupSnapshot {
        AppGroupSnapshot(
            isSharedContainerAvailable: isSharedContainerAvailable,
            containerPath: root?.path,
            pause: loadPause(),
            hasShieldPresentation: loadShieldPresentation() != nil,
            hasSelectionData: loadSelectionData() != nil,
            heartbeats: Dictionary(
                uniqueKeysWithValues: HeartbeatTarget.allCases.map { ($0, heartbeat($0)?.at) }
            ),
            reportCount: loadReports().count,
            observedAt: now,
            observedUptime: uptime
        )
    }

    /// Remove everything HopPotty has written here.
    ///
    /// Used by the Potty Pause Lab's "reset environment", and by nothing else. In
    /// particular **not** by the fail-safe path, which clears the shield first and
    /// only then removes the record.
    public func reset() {
        clearPause()
        remove(Self.shieldFile)
        clearSelectionData()
        for target in HeartbeatTarget.allCases { remove(heartbeatFile(target)) }
        if let directory = outboxDirectory {
            let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            for file in files { try? FileManager.default.removeItem(at: file) }
        }
    }
}

/// A consistent read of the whole shared record.
public struct AppGroupSnapshot: Equatable, Sendable {
    public let isSharedContainerAvailable: Bool
    public let containerPath: String?
    public let pause: SharedPauseRecord?
    public let hasShieldPresentation: Bool
    public let hasSelectionData: Bool
    public let heartbeats: [AppGroupStore.HeartbeatTarget: Date?]
    public let reportCount: Int
    public let observedAt: Date
    public let observedUptime: TimeInterval

    public init(
        isSharedContainerAvailable: Bool,
        containerPath: String?,
        pause: SharedPauseRecord?,
        hasShieldPresentation: Bool,
        hasSelectionData: Bool,
        heartbeats: [AppGroupStore.HeartbeatTarget: Date?],
        reportCount: Int,
        observedAt: Date,
        observedUptime: TimeInterval
    ) {
        self.isSharedContainerAvailable = isSharedContainerAvailable
        self.containerPath = containerPath
        self.pause = pause
        self.hasShieldPresentation = hasShieldPresentation
        self.hasSelectionData = hasSelectionData
        self.heartbeats = heartbeats
        self.reportCount = reportCount
        self.observedAt = observedAt
        self.observedUptime = observedUptime
    }

    /// Human-readable, and free of anything sensitive by construction — there is
    /// nothing sensitive in the record to leak.
    public var debugDump: [String] {
        func stamp(_ date: Date?) -> String {
            guard let date else { return "—" }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withFullTime, .withColonSeparatorInTime]
            return "\(formatter.string(from: date))  (\(Int(observedAt.timeIntervalSince(date)))s ago)"
        }
        var lines = [
            "container: \(isSharedContainerAvailable ? (containerPath ?? "?") : "UNAVAILABLE — App Group entitlement or identifier is wrong")",
            "shield payload: \(hasShieldPresentation ? "present" : "MISSING — extension will use its compiled-in fallback")",
            "selection payload: \(hasSelectionData ? "present" : "absent")",
            "outbox: \(reportCount) report(s)",
            "uptime now: \(Int(observedUptime))s",
        ]
        if let pause {
            lines += [
                "— pause record —",
                "  session: \(pause.sessionID)",
                "  state: \(pause.state.rawValue)",
                "  startedAt: \(stamp(pause.startedAt))",
                "  plannedEndAt: \(stamp(pause.plannedEndAt))",
                "  backstopEndAt: \(stamp(pause.backstopEndAt))",
                "  startedUptime: \(Int(pause.startedUptime))s",
                "  failure: \(pause.failureCode ?? "—")",
            ]
        } else {
            lines.append("— no pause record —")
        }
        for target in AppGroupStore.HeartbeatTarget.allCases {
            lines.append("heartbeat \(target.rawValue): \(stamp(heartbeats[target] ?? nil))")
        }
        return lines
    }
}
