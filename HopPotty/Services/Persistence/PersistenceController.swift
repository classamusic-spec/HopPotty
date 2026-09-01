import Foundation
import SwiftData

/// Opens the HopPotty store, and refuses to fail in a way a parent would see as
/// a crash.
///
/// ## The rule
///
/// A potty-training app is opened one-handed, at speed, by someone holding a
/// child who is announcing an emergency. If the store will not open, the app
/// must still launch, still let that child tap the big button, and still tell
/// the caregiver — calmly, later, in the parent area — that saved history could
/// not be read. `fatalError` on a store failure is the wrong trade in every
/// product and an actively harmful one here.
///
/// ## The ladder
///
/// 1. **Open normally**, with the migration plan. Almost always this.
/// 2. **Quarantine and retry.** A store that will not open is moved aside —
///    never deleted — into `Recovered/<timestamp>/`, and a fresh empty store is
///    created. The family's data is still on the device and a future build with
///    a repair path can read it. The caregiver is told history is missing.
/// 3. **In-memory container.** The disk itself is refusing (no space, a
///    protected-data-unavailable window at boot before first unlock). The app
///    runs for the session; nothing is saved.
/// 4. **No container at all.** The app falls back to the same in-memory
///    repositories previews use. Every feature works; nothing persists.
///
/// Steps 2–4 all set `outcome`, which the parent dashboard reads to explain what
/// happened. Nothing here logs a filename, a nickname or a row's contents.
@MainActor
final class PersistenceController {

    /// How the store came up. Drives one calm parent-facing message; never shown
    /// to the child.
    enum Outcome: Equatable {
        /// Normal launch.
        case opened
        /// Deliberately in memory — previews, tests, mock builds.
        case ephemeralByDesign
        /// The store would not open; it was moved aside and a new one created.
        /// Existing history is gone from the app's view but still on disk.
        case recoveredAfterCorruption
        /// Neither the on-disk store nor a replacement could be opened; this
        /// session is in memory and will not be saved.
        case ephemeralAfterFailure
        /// No container at all. Repositories are the in-memory stack.
        case unavailable

        /// Whether anything written this session will survive relaunch.
        var persistsWrites: Bool {
            switch self {
            case .opened, .recoveredAfterCorruption: true
            case .ephemeralByDesign, .ephemeralAfterFailure, .unavailable: false
            }
        }

        /// Whether the caregiver needs to be told something went wrong.
        var needsCaregiverNotice: Bool {
            switch self {
            case .opened, .ephemeralByDesign: false
            case .recoveredAfterCorruption, .ephemeralAfterFailure, .unavailable: true
            }
        }
    }

    let container: ModelContainer?
    let outcome: Outcome

    /// Where a quarantined store was put, for a future repair tool. Not shown
    /// to the caregiver — a file path in a UI invites deleting it.
    private(set) var quarantineDirectory: URL?

    private init(container: ModelContainer?, outcome: Outcome, quarantineDirectory: URL? = nil) {
        self.container = container
        self.outcome = outcome
        self.quarantineDirectory = quarantineDirectory
    }

    // MARK: - Construction

    /// The real store, with the full recovery ladder.
    static func live(fileManager: FileManager = .default) -> PersistenceController {
        let schema = Schema(versionedSchema: HopCurrentSchema.self)

        guard let storeURL = storeURL(fileManager: fileManager) else {
            HopLog.persistence.error("no writable application support directory; running ephemeral")
            return ephemeralFallback(schema: schema, outcome: .ephemeralAfterFailure)
        }

        // 1. Normal open.
        if let container = makeContainer(schema: schema, url: storeURL) {
            let version = HopCurrentSchema.versionIdentifier
            HopLog.persistence.info(
                "store opened version=\(version.major, privacy: .public).\(version.minor, privacy: .public).\(version.patch, privacy: .public)"
            )
            return PersistenceController(container: container, outcome: .opened)
        }

        // 2. Quarantine and retry. Moving, never deleting: the bytes are the
        // family's, and a migration bug we ship on Tuesday is a bug we may be
        // able to unpick on Thursday.
        let quarantine = quarantineStore(at: storeURL, fileManager: fileManager)
        if let container = makeContainer(schema: schema, url: storeURL) {
            HopLog.persistence.error("store recovered after quarantine; history not readable")
            return PersistenceController(
                container: container,
                outcome: .recoveredAfterCorruption,
                quarantineDirectory: quarantine
            )
        }

        // 3 & 4.
        HopLog.persistence.fault("store could not be opened after quarantine; running ephemeral")
        return ephemeralFallback(schema: schema, outcome: .ephemeralAfterFailure)
    }

    /// An in-memory store for previews, tests and mock builds.
    static func ephemeral() -> PersistenceController {
        let schema = Schema(versionedSchema: HopCurrentSchema.self)
        return ephemeralFallback(schema: schema, outcome: .ephemeralByDesign)
    }

    private static func ephemeralFallback(schema: Schema, outcome: Outcome) -> PersistenceController {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            return PersistenceController(container: container, outcome: outcome)
        } catch {
            // The schema itself is unloadable. Nothing on disk can help. The app
            // still launches, on the in-memory repository stack.
            HopLog.persistence.fault(
                "in-memory container failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            return PersistenceController(container: nil, outcome: .unavailable)
        }
    }

    private static func makeContainer(schema: Schema, url: URL) -> ModelContainer? {
        do {
            let configuration = ModelConfiguration(schema: schema, url: url)
            return try ModelContainer(
                for: schema,
                migrationPlan: HopMigrationPlan.self,
                configurations: configuration
            )
        } catch {
            // Domain and code only. A SwiftData failure description can quote
            // the offending row, and the offending row can be a nickname.
            HopLog.persistence.error(
                "store open failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            return nil
        }
    }

    // MARK: - Files

    static let storeDirectoryName = "HopPotty"
    static let storeFileName = "HopPotty.store"
    /// How many quarantined stores to keep. Enough to survive a bad release and
    /// a bad hotfix; few enough that a crash loop cannot fill a 64 GB iPad.
    static let quarantineRetentionLimit = 3

    private static func storeURL(fileManager: FileManager) -> URL? {
        do {
            let support = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = support.appendingPathComponent(storeDirectoryName, isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathComponent(storeFileName)
        } catch {
            HopLog.persistence.error(
                "store directory unavailable error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            return nil
        }
    }

    /// Moves the store and its sidecars aside. Returns where they went.
    ///
    /// SQLite in WAL mode is three files. Moving only `.store` leaves a
    /// write-ahead log that the *new* store would try to replay, which is how a
    /// "recovery" corrupts the replacement too.
    @discardableResult
    private static func quarantineStore(at storeURL: URL, fileManager: FileManager) -> URL? {
        let parent = storeURL.deletingLastPathComponent()
        let root = parent.appendingPathComponent("Recovered", isDirectory: true)
        let stamp = String(Int(Date().timeIntervalSince1970))
        let destination = root.appendingPathComponent(stamp, isDirectory: true)

        do {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            for suffix in ["", "-wal", "-shm"] {
                let source = URL(fileURLWithPath: storeURL.path + suffix)
                guard fileManager.fileExists(atPath: source.path) else { continue }
                let target = destination.appendingPathComponent(source.lastPathComponent)
                try fileManager.moveItem(at: source, to: target)
            }
            pruneQuarantine(root: root, fileManager: fileManager)
            HopLog.persistence.error("store quarantined")
            return destination
        } catch {
            HopLog.persistence.fault(
                "quarantine failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            return nil
        }
    }

    private static func pruneQuarantine(root: URL, fileManager: FileManager) {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil
        ) else { return }
        // Directory names are unix timestamps, so lexicographic order is
        // chronological for every date this app will ever see.
        let sorted = entries.map(\.lastPathComponent).sorted()
        guard sorted.count > quarantineRetentionLimit else { return }
        for name in sorted.prefix(sorted.count - quarantineRetentionLimit) {
            try? fileManager.removeItem(at: root.appendingPathComponent(name, isDirectory: true))
        }
    }

    // MARK: - Contexts

    /// The container's own main-actor context, or `nil` when no container
    /// opened.
    ///
    /// Deliberately `container.mainContext` and **not** `ModelContext(container)`.
    /// The scene installs the same container with `.modelContainer(_:)`, which
    /// binds every `@Query` to `mainContext` too. A second context here would
    /// give the app two sets of unsaved changes on the same actor — the exact
    /// split `RepositorySet` exists to prevent, where a deletion spanning seven
    /// tables is one unit of work in one context and a half-deleted child in
    /// the other.
    ///
    /// Autosave is left at the container's default. Every repository write ends
    /// in an explicit `save()`, so a failure still surfaces at its call site;
    /// turning autosave off here would also turn it off for the `@Query`-driven
    /// edits the feature layer makes through the same context.
    var mainContext: ModelContext? { container?.mainContext }
}
