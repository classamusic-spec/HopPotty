import Foundation
import HopPottyCore
import SwiftData

// MARK: - Potty event

/// The timeline row. The highest-volume table in the store — a busy family logs
/// perhaps a dozen a day, so a few thousand rows over a full training arc.
@Model
final class StoredPottyEvent {
    @Attribute(.unique) var id: UUID
    var childID: UUID
    /// When it *happened*. Indexed by every timeline and insight query, and the
    /// sort key everywhere; `createdAt` is only ever used for diagnostics.
    var timestamp: Date
    var kindRaw: String
    var sourceRaw: String
    /// Caregiver free text. Frequently the most sensitive field in the whole
    /// store — never logged, never shown to the child, excluded from an export
    /// when the caregiver says so.
    var note: String?
    var pauseSessionID: UUID?
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID,
        childID: UUID,
        timestamp: Date,
        kindRaw: String,
        sourceRaw: String,
        note: String?,
        pauseSessionID: UUID?,
        createdAt: Date,
        modifiedAt: Date
    ) {
        self.id = id
        self.childID = childID
        self.timestamp = timestamp
        self.kindRaw = kindRaw
        self.sourceRaw = sourceRaw
        self.note = note
        self.pauseSessionID = pauseSessionID
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    convenience init(_ event: PottyEvent) {
        self.init(
            id: event.id,
            childID: event.childID,
            timestamp: event.timestamp,
            kindRaw: event.kind.rawValue,
            sourceRaw: event.source.rawValue,
            note: event.note,
            pauseSessionID: event.pauseSessionID,
            createdAt: event.createdAt,
            modifiedAt: event.modifiedAt
        )
    }

    func apply(_ event: PottyEvent) {
        timestamp = event.timestamp
        kindRaw = event.kind.rawValue
        sourceRaw = event.source.rawValue
        note = event.note
        pauseSessionID = event.pauseSessionID
        modifiedAt = event.modifiedAt
    }

    var domainValue: PottyEvent {
        PottyEvent(
            id: id,
            childID: childID,
            timestamp: timestamp,
            // `.tried` is the fallback because it is the neutral participation
            // kind. Guessing `.accident` for an unreadable row would invent a
            // negative fact about a child that nothing in the data supports.
            kind: HopStoredCoding.decodeEnum(
                PottyEventKind.self, raw: kindRaw, fallback: .tried, label: "eventKind"
            ),
            source: HopStoredCoding.decodeEnum(
                PottyEventSource.self, raw: sourceRaw, fallback: .restored, label: "eventSource"
            ),
            note: note,
            pauseSessionID: pauseSessionID,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }
}

// MARK: - Reward transaction

/// One row of the append-only star ledger.
///
/// There is no `apply(_:)` on this model, and that is not an oversight. A
/// transaction is immutable once written: contract rule 2 says stars are never
/// removed, and a mutable `quantity` is the field that would let a future bug
/// remove one. The single legitimate edit — clearing `sourceEventID` when a
/// caregiver deletes the event that earned the star — goes through
/// `orphanSourceEvent()`, which cannot touch anything else.
@Model
final class StoredRewardTransaction {
    @Attribute(.unique) var id: UUID
    var childID: UUID
    var timestamp: Date
    var reasonRaw: String
    /// Always positive. Written once, never updated.
    var quantity: Int
    var sourceEventID: UUID?
    /// The deterministic key that makes awarding safe to retry. Unique, so a
    /// double award is rejected by the store itself and not only by the ledger
    /// in memory — belt and braces on the one invariant a child would notice.
    @Attribute(.unique) var idempotencyKey: String

    init(
        id: UUID,
        childID: UUID,
        timestamp: Date,
        reasonRaw: String,
        quantity: Int,
        sourceEventID: UUID?,
        idempotencyKey: String
    ) {
        self.id = id
        self.childID = childID
        self.timestamp = timestamp
        self.reasonRaw = reasonRaw
        self.quantity = quantity
        self.sourceEventID = sourceEventID
        self.idempotencyKey = idempotencyKey
    }

    convenience init(_ transaction: RewardTransaction) {
        self.init(
            id: transaction.id,
            childID: transaction.childID,
            timestamp: transaction.timestamp,
            reasonRaw: transaction.reason.rawValue,
            quantity: transaction.quantity,
            sourceEventID: transaction.sourceEventID,
            idempotencyKey: transaction.idempotencyKey
        )
    }

    /// Breaks the link to a deleted potty event. Keeps the star, the timestamp,
    /// the quantity and — importantly — the idempotency key, so a queued retry
    /// for the deleted event still collapses instead of re-awarding.
    func orphanSourceEvent() {
        sourceEventID = nil
    }

    var domainValue: RewardTransaction {
        RewardTransaction(
            id: id,
            childID: childID,
            timestamp: timestamp,
            reason: HopStoredCoding.decodeEnum(
                RewardReason.self, raw: reasonRaw, fallback: .triedThePotty, label: "rewardReason"
            ),
            quantity: quantity,
            sourceEventID: sourceEventID,
            idempotencyKey: idempotencyKey
        )
    }
}

// MARK: - Pond progress

/// A child's unlocked pond.
///
/// Strictly a cache of "what the star total already bought", kept so the unlock
/// *dates* survive — `PondProgressService` can always rebuild the set from the
/// ledger, but it cannot rebuild when each item appeared. If this row is lost,
/// `PondProgressService.progress(from:childID:)` regenerates a complete pond
/// from the ledger with today's date; the child loses nothing visible.
@Model
final class StoredPondProgress {
    @Attribute(.unique) var childID: UUID
    /// `[PondItemID.rawValue: Date]` as JSON.
    var unlockedData: Data
    /// Denormalised so the parent dashboard can show "12 of 41" without
    /// decoding, and so the deletion preview can count without decoding either.
    var unlockedCount: Int
    var modifiedAt: Date

    init(childID: UUID, unlockedData: Data, unlockedCount: Int, modifiedAt: Date) {
        self.childID = childID
        self.unlockedData = unlockedData
        self.unlockedCount = unlockedCount
        self.modifiedAt = modifiedAt
    }

    convenience init(_ progress: PondProgress, at date: Date = Date()) {
        let raw = Dictionary(
            uniqueKeysWithValues: progress.unlocked.map { ($0.key.rawValue, $0.value) }
        )
        self.init(
            childID: progress.childID,
            unlockedData: HopStoredCoding.encode(raw, label: "pondUnlocked"),
            unlockedCount: progress.unlockedCount,
            modifiedAt: date
        )
    }

    func apply(_ progress: PondProgress, at date: Date = Date()) {
        let raw = Dictionary(
            uniqueKeysWithValues: progress.unlocked.map { ($0.key.rawValue, $0.value) }
        )
        unlockedData = HopStoredCoding.encode(raw, label: "pondUnlocked")
        unlockedCount = progress.unlockedCount
        modifiedAt = date
    }

    var domainValue: PondProgress {
        let raw = HopStoredCoding.decode(
            [String: Date].self, from: unlockedData, fallback: [:], label: "pondUnlocked"
        )
        // An id this build does not know is silently dropped rather than
        // failing the row: it means the store was written by a build with more
        // pond items, and the child's other decorations must still appear.
        var unlocked: [PondItemID: Date] = [:]
        for (key, date) in raw {
            if let item = PondItemID(rawValue: key) { unlocked[item] = date }
        }
        return PondProgress(childID: childID, unlocked: unlocked)
    }
}

// MARK: - Quiz and game progress

@Model
final class StoredQuizProgress {
    @Attribute(.unique) var childID: UUID
    /// `[quizID: completionCount]` as JSON.
    var completionsData: Data
    /// `[quizID: lastCompletedDate]` as JSON.
    var lastCompletedData: Data
    var totalCompletions: Int
    var modifiedAt: Date

    init(
        childID: UUID,
        completionsData: Data,
        lastCompletedData: Data,
        totalCompletions: Int,
        modifiedAt: Date
    ) {
        self.childID = childID
        self.completionsData = completionsData
        self.lastCompletedData = lastCompletedData
        self.totalCompletions = totalCompletions
        self.modifiedAt = modifiedAt
    }

    convenience init(_ progress: QuizProgress) {
        self.init(
            childID: progress.childID,
            completionsData: HopStoredCoding.encode(progress.completionsByQuiz, label: "quizCompletions"),
            lastCompletedData: HopStoredCoding.encode(progress.lastCompletedByQuiz, label: "quizLastPlayed"),
            totalCompletions: progress.totalCompletions,
            modifiedAt: progress.modifiedAt
        )
    }

    func apply(_ progress: QuizProgress) {
        completionsData = HopStoredCoding.encode(progress.completionsByQuiz, label: "quizCompletions")
        lastCompletedData = HopStoredCoding.encode(progress.lastCompletedByQuiz, label: "quizLastPlayed")
        totalCompletions = progress.totalCompletions
        modifiedAt = progress.modifiedAt
    }

    var domainValue: QuizProgress {
        QuizProgress(
            childID: childID,
            completionsByQuiz: HopStoredCoding.decode(
                [String: Int].self, from: completionsData, fallback: [:], label: "quizCompletions"
            ),
            lastCompletedByQuiz: HopStoredCoding.decode(
                [String: Date].self, from: lastCompletedData, fallback: [:], label: "quizLastPlayed"
            ),
            modifiedAt: modifiedAt
        )
    }
}

@Model
final class StoredGameProgress {
    @Attribute(.unique) var childID: UUID
    var completionsData: Data
    var lastCompletedData: Data
    var totalCompletions: Int
    var modifiedAt: Date

    init(
        childID: UUID,
        completionsData: Data,
        lastCompletedData: Data,
        totalCompletions: Int,
        modifiedAt: Date
    ) {
        self.childID = childID
        self.completionsData = completionsData
        self.lastCompletedData = lastCompletedData
        self.totalCompletions = totalCompletions
        self.modifiedAt = modifiedAt
    }

    convenience init(_ progress: GameProgress) {
        self.init(
            childID: progress.childID,
            completionsData: HopStoredCoding.encode(progress.completionsByGame, label: "gameCompletions"),
            lastCompletedData: HopStoredCoding.encode(progress.lastCompletedByGame, label: "gameLastPlayed"),
            totalCompletions: progress.totalCompletions,
            modifiedAt: progress.modifiedAt
        )
    }

    func apply(_ progress: GameProgress) {
        completionsData = HopStoredCoding.encode(progress.completionsByGame, label: "gameCompletions")
        lastCompletedData = HopStoredCoding.encode(progress.lastCompletedByGame, label: "gameLastPlayed")
        totalCompletions = progress.totalCompletions
        modifiedAt = progress.modifiedAt
    }

    var domainValue: GameProgress {
        GameProgress(
            childID: childID,
            completionsByGame: HopStoredCoding.decode(
                [String: Int].self, from: completionsData, fallback: [:], label: "gameCompletions"
            ),
            lastCompletedByGame: HopStoredCoding.decode(
                [String: Date].self, from: lastCompletedData, fallback: [:], label: "gameLastPlayed"
            ),
            modifiedAt: modifiedAt
        )
    }
}
