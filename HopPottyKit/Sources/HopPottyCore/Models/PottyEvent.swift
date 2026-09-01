import Foundation

/// Something that happened on a potty visit.
public struct PottyEvent: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let childID: UUID
    /// When the event happened, not when it was recorded. A parent logging an
    /// accident twenty minutes later should be able to backdate it.
    public var timestamp: Date
    public var kind: PottyEventKind
    public var source: PottyEventSource
    /// Optional free text, parent-only. Never shown to the child, never sent
    /// off-device.
    public var note: String?
    /// The pause that prompted this visit, when there was one. Lets the insights
    /// engine relate outcomes to intervals without inferring from timestamps.
    public var pauseSessionID: UUID?
    public let createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        childID: UUID,
        timestamp: Date = Date(),
        kind: PottyEventKind,
        source: PottyEventSource,
        note: String? = nil,
        pauseSessionID: UUID? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.childID = childID
        self.timestamp = timestamp
        self.kind = kind
        self.source = source
        self.note = note
        self.pauseSessionID = pauseSessionID
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

/// What was recorded.
///
/// `tried` is the primary event and is never a lesser outcome than `pee` or
/// `poop`. `accident` is a neutral fact, not a failure — nothing in the reward
/// system reads it. See `Docs/ChildSafety.md`.
public enum PottyEventKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case tried, pee, poop, accident

    public var id: String { rawValue }

    /// Whether a child can log this themselves. Accidents are parent-recorded so
    /// a child is never asked to self-report one.
    public var isChildLoggable: Bool { self != .accident }

    /// Whether this event counts as the child having engaged with the routine.
    /// All three child-loggable kinds do, equally.
    public var countsAsParticipation: Bool { isChildLoggable }

    /// Whether the visit produced output. Used only for parent-facing descriptive
    /// statistics — never for rewards, and never framed as success or failure.
    public var producedOutput: Bool { self == .pee || self == .poop }
}

/// Who recorded the event, which determines how much trust the insights engine
/// places in the timestamp.
public enum PottyEventSource: String, Codable, CaseIterable, Sendable {
    /// Tapped by the child inside the guided routine.
    case childRoutine
    /// Entered by a caregiver on the parent dashboard.
    case parentManual
    /// Recorded when a Potty Pause completed without explicit logging, so the
    /// timeline does not silently lose the visit.
    case pauseCompletion
    /// Restored from an import or a migration.
    case restored
}
