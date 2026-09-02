import Foundation
import HopPottyCore
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Target membership
//
// THIS FILE IS SHARED BY THREE TARGETS.
//
//   HopPotty                       (app)              — writes
//   HopPottyWidgets                (widget extension) — reads
//   HopPottyDeviceActivityMonitor  (extension)        — writes, when it starts a
//                                                       pause with the app closed
//
// It is deliberately NOT the same file set as the Screen Time four
// (`ScreenTimeIdentifiers.swift` and friends). Those import ManagedSettings and
// DeviceActivity; a widget extension has no business linking either, and an
// extension App ID that links them is an extension App ID that has to be put
// through the Family Controls distribution request. So this file re-declares the
// one constant it needs from that set — ``widgetAppGroupID`` — and
// `Scripts/verify-config.sh` fails the build configuration if it ever stops
// matching `ScreenTimeIdentifiers.appGroupID` and the xcconfig.
//
// One duplicated string, checked by a script, in exchange for a widget process
// that links Foundation and WidgetKit and nothing else. `Docs/Widgets.md` §5.

/// Reads and writes `widget.json` in the App Group container.
///
/// ## Why this is not `AppGroupStore`
///
/// `AppGroupStore` is the pause boundary: four processes, a shield that must
/// come down, and a set of fail-safes that all resolve toward clearing. The
/// widget boundary is nothing like it. There is exactly one writer that matters,
/// nothing is enforced on a device as a result of what is written, and a reader
/// that finds nothing shows a placeholder rather than taking action. Putting the
/// two behind one type would invite the widget's much weaker guarantees to be
/// read as the pause's.
///
/// ## Failure is always "there is no snapshot"
///
/// Missing container, missing file, unreadable bytes, unparseable JSON, a schema
/// from a build that is not this one: every one of them returns `nil`, because
/// every one of them means the same thing to the widget — *draw the placeholder
/// and ask again later*. A widget cannot ask a question, cannot retry usefully,
/// and cannot tell a caregiver anything they could act on, so distinguishing the
/// causes would only invite one of them to be treated as recoverable.
public struct WidgetSnapshotStore: Sendable {

    /// LOAD-BEARING. Must equal `ScreenTimeIdentifiers.appGroupID` and
    /// `HOPPOTTY_APP_GROUP` in `Config/Base.xcconfig`, byte for byte.
    /// `Scripts/verify-config.sh` compares all three.
    public static let widgetAppGroupID = "group.com.hoppotty"

    /// The WidgetKit kind string. Shared so the app reloads the same widget the
    /// extension registers, and so a typo is a compile error in one file rather
    /// than a widget that silently never refreshes.
    public static let widgetKind = "com.hoppotty.widget.nextpause"

    private static let fileName = "widget.json"

    /// The container root, or `nil` when the App Group is unreachable.
    public let root: URL?

    public var isSharedContainerAvailable: Bool { root != nil }

    public static let shared = WidgetSnapshotStore()

    public init(groupID: String = WidgetSnapshotStore.widgetAppGroupID) {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("HopPotty", isDirectory: true)
        self.init(root: container)
    }

    /// Test and preview seam: point the store at a scratch directory.
    public init(root: URL?) {
        self.root = root
        if let root {
            // Best effort, exactly as in `AppGroupStore`: a failure here is
            // indistinguishable at read time from an empty container, and an
            // empty container is the safe reading.
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
    }

    // MARK: - Coding
    //
    // ISO-8601, matching `AppGroupStore`, so a tester dumping the container
    // during `Docs/PhysicalDeviceQA.md` reads one date format rather than two.

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

    private var url: URL? { root?.appendingPathComponent(Self.fileName) }

    // MARK: - Reading

    /// The published snapshot, or `nil`.
    public func load() -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        guard let snapshot = try? Self.decoder.decode(WidgetSnapshot.self, from: data) else { return nil }
        guard snapshot.schemaVersion == WidgetSnapshot.currentSchemaVersion else { return nil }
        return snapshot
    }

    /// The snapshot to draw right now: the published one while it is fresh, the
    /// honest empty state once it is not.
    ///
    /// A widget that has not been refreshed for half a day is a widget whose
    /// answer nobody has confirmed since breakfast. Showing "next pause 09:15" at
    /// six in the evening is worse than showing nothing, because a caregiver
    /// reads the first as a fact and the second as a prompt to open the app.
    public func loadForDisplay(at instant: Date) -> WidgetSnapshot {
        guard let snapshot = load(), !snapshot.isStale(at: instant) else {
            return .empty(at: instant)
        }
        return snapshot
    }

    // MARK: - Writing

    @discardableResult
    public func save(_ snapshot: WidgetSnapshot) -> Bool {
        guard let url, let data = try? Self.encoder.encode(snapshot) else { return false }
        do {
            // Atomic, so a widget reading while the app writes never sees a torn
            // record — the same discipline as the pause file, for the same
            // reason: there are two processes and no lock between them.
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    public func clear() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Note that a pause or routine has begun, without recomputing anything.
    ///
    /// This is what the DeviceActivity monitor extension calls. That process
    /// cannot project a schedule, has no profile, and must finish quickly — but
    /// it *does* know that a pause just started and when it should end, and that
    /// is the one fact the widget would otherwise be wrong about for as long as
    /// the app stayed closed.
    ///
    /// A no-op when no snapshot exists: inventing one from inside an extension
    /// would put a record on the boundary that no schedule backs.
    @discardableResult
    public func markPauseStarted(endingAt end: Date, now: Date) -> Bool {
        guard let existing = load() else { return false }
        return save(
            WidgetSnapshot(
                nextPauseAt: existing.nextPauseAt,
                childDisplayName: existing.childDisplayName,
                hopPoseName: HopWidgetMood.cheer.rawValue,
                quickReminderAt: existing.quickReminderAt,
                isScheduleEnabled: existing.isScheduleEnabled,
                pauseEndsAt: end,
                generatedAt: now
            )
        )
    }

    /// Note that whatever was running has stopped.
    ///
    /// The mood drops back to a resting face rather than being recomputed:
    /// working out whether the *next* pause is now imminent needs the schedule,
    /// and the process that has the schedule will publish a full snapshot the
    /// next time it runs.
    @discardableResult
    public func markPauseEnded(now: Date) -> Bool {
        guard let existing = load() else { return false }
        return save(
            WidgetSnapshot(
                nextPauseAt: existing.nextPauseAt,
                childDisplayName: existing.childDisplayName,
                hopPoseName: HopWidgetMood.idle.rawValue,
                quickReminderAt: existing.quickReminderAt,
                isScheduleEnabled: existing.isScheduleEnabled,
                pauseEndsAt: nil,
                generatedAt: now
            )
        )
    }

    // MARK: - Asking WidgetKit to redraw

    /// Ask WidgetKit for a new timeline for HopPotty's widget.
    ///
    /// Callable from an extension: `WidgetCenter` is available to app extensions,
    /// which is what lets the DeviceActivity monitor refresh the widget after
    /// starting a pause with the app not running.
    ///
    /// A *request*, not a redraw. The system decides when — and, if the budget
    /// for the day is spent, whether. Nothing in HopPotty may depend on this
    /// having happened; the widget is a convenience, and every path that matters
    /// (the shield, the notification, the routine) works with the widget frozen
    /// on yesterday's frame.
    public func reloadTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
        #endif
    }
}
