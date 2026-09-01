import Foundation
import SwiftData

// MARK: - Schema versions

/// Version 1 of the HopPotty store.
///
/// See `HopMigrationPlan` for the rules every future version has to follow.
enum HopSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            StoredChildProfile.self,
            StoredAppSettings.self,
            StoredPottySchedule.self,
            StoredScreenTimeConfiguration.self,
            StoredPottyEvent.self,
            StoredRewardTransaction.self,
            StoredPondProgress.self,
            StoredQuizProgress.self,
            StoredGameProgress.self,
        ]
    }
}

/// The current schema. One symbol to change when a new version ships.
typealias HopCurrentSchema = HopSchemaV1

// MARK: - Migration plan

/// How the HopPotty store moves between versions.
///
/// ## Why this exists on day one
///
/// A potty-training app is used for months and updated during those months.
/// Adding the migration plan after the first release means the first release's
/// store has no version stamp to migrate *from*, and the second release either
/// silently wipes a family's history or fails to open at all. It costs almost
/// nothing to declare V1 now and everything to retrofit later.
///
/// ## The five rules
///
/// 1. **Additive by default.** A new version adds properties with defaults or
///    adds whole models. Both are *lightweight* migrations: SwiftData applies
///    them with no code and no data loss. Every schema change should try to be
///    one of these before it tries to be anything else.
///
/// 2. **Never rename or retype in place.** Renaming `note` to `caregiverNote`
///    is a destructive migration dressed as a rename. The safe sequence spans
///    two releases: V2 adds the new property and backfills it in a custom stage,
///    V3 stops writing the old one and drops it. Families skipping a release
///    still land correctly because SwiftData runs the stages in order.
///
/// 3. **Enums are stored as their raw `String`, never as the enum.** A new
///    `RewardReason` case is then a *content* change, not a schema change, and a
///    row written by a newer build that a downgraded build reads back maps to a
///    documented fallback (see `HopStoredCoding.decodeEnum`) rather than
///    failing to decode the whole store.
///
/// 4. **Composite values are stored as JSON blobs, and blob decoding never
///    throws upward.** `quietWindows`, `ScheduleSuspension`, `PottyPauseState`
///    and the pond's unlock map are Codable values with associated data. A blob
///    keeps them in one column and lets `Codable` do the versioning; a failed
///    decode degrades to a safe default and logs, because a corrupted quiet
///    window must not stop a caregiver from opening the app.
///
/// 5. **No relationships, only `childID` foreign keys.** Multi-child support
///    means every query is scoped by child anyway, and SwiftData's cascade
///    deletes on iOS 17 are the single most surprising part of the framework:
///    a cascade that reaches the reward ledger would delete stars, which
///    contract rule 2 forbids. Deletion is explicit, counted and per-table in
///    `DataDeletionService` — never a side effect of a relationship.
///
/// 6. **Cross-process state is not in this store.** A running Potty Pause is
///    read and written by two app extensions that cannot open SwiftData, so it
///    lives in the App Group record instead. See the note at the foot of
///    `StoredChildRecords.swift`.
///
/// ## Adding version 2
///
/// ```swift
/// enum HopSchemaV2: VersionedSchema {
///     static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
///     static var models: [any PersistentModel.Type] { [ /* V2 models */ ] }
/// }
///
/// // Lightweight: a new optional property, or a property with a default.
/// static let migrateV1toV2 = MigrationStage.lightweight(
///     fromVersion: HopSchemaV1.self,
///     toVersion: HopSchemaV2.self
/// )
///
/// // Custom: needed when data has to be rewritten, e.g. backfilling a
/// // denormalised column. `willMigrate` sees the old shape, `didMigrate` the
/// // new one; both get a context and must call `save()`.
/// static let migrateV2toV3 = MigrationStage.custom(
///     fromVersion: HopSchemaV2.self,
///     toVersion: HopSchemaV3.self,
///     willMigrate: nil,
///     didMigrate: { context in
///         let rows = try context.fetch(FetchDescriptor<StoredPottyEvent>())
///         for row in rows where row.newColumn.isEmpty { row.newColumn = derive(row) }
///         try context.save()
///     }
/// )
/// ```
///
/// Then add the version to `schemas` and the stage to `stages`, in order, and
/// point `HopCurrentSchema` at the new version. Never reorder or remove a stage
/// that has shipped: a family upgrading from two releases back replays them all.
enum HopMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [HopSchemaV1.self]
    }

    /// Empty at V1 — there is nothing to migrate from yet. The type still has to
    /// exist and be handed to the container so the store is stamped with a
    /// version identifier that V2 can migrate away from.
    static var stages: [MigrationStage] {
        []
    }
}

// MARK: - Blob coding

/// Encoding helpers shared by every `@Model` in the store.
///
/// Centralised so the JSON strategy is one decision rather than ten, and so a
/// decode failure has exactly one place that decides what to do about it.
enum HopStoredCoding {

    /// `.sortedKeys` makes a blob byte-stable for the same value, which turns
    /// "did this row actually change?" into a cheap comparison and keeps diffs
    /// of an exported store readable.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Encodes a value to a blob, returning empty `Data` on failure.
    ///
    /// A `Codable` value HopPotty defines cannot fail to encode in practice, and
    /// if one somehow does, writing an empty blob (which decodes to the caller's
    /// documented default) loses one composite field. Throwing here would fail
    /// the whole save and lose the potty event the caregiver just logged.
    static func encode(_ value: some Encodable, label: StaticString) -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            HopLog.persistence.error(
                "blob encode failed field=\(label, privacy: .public) error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            return Data()
        }
    }

    /// Decodes a blob, falling back to `fallback` on empty or malformed data.
    static func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        fallback: @autoclosure () -> T,
        label: StaticString
    ) -> T {
        guard !data.isEmpty else { return fallback() }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            HopLog.persistence.error(
                "blob decode failed field=\(label, privacy: .public) bytes=\(data.count, privacy: .public) error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            return fallback()
        }
    }

    /// Maps a stored raw value back to its enum, falling back when the raw value
    /// is not one this build knows.
    ///
    /// This is rule 3 in action. An unknown raw value means the store was
    /// written by a newer build (a TestFlight downgrade, a restored backup), and
    /// the honest response is "show the safe default and log it", not "refuse to
    /// open the family's data".
    static func decodeEnum<T: RawRepresentable>(
        _ type: T.Type,
        raw: String,
        fallback: T,
        label: StaticString
    ) -> T where T.RawValue == String {
        if let value = T(rawValue: raw) { return value }
        HopLog.persistence.error(
            "unknown raw value field=\(label, privacy: .public) value=\(raw, privacy: .public)"
        )
        return fallback
    }
}
