import Foundation

/// What a reward is *for*, expressed as something that already exists on disk
/// before the star is written.
///
/// This is the whole trick behind crash-safe awarding. The scope is never
/// invented at award time — it is always an identifier the caller already
/// persisted (a `PottyEvent.id`, a pause session id) or a value that is a pure
/// function of the calendar (a local day). So if the app is killed between
/// "event saved" and "star written", the relaunch recomputes byte-identical
/// scope, byte-identical key, and the retry collapses instead of doubling.
public enum RewardScope: Hashable, Sendable {
    /// A specific `PottyEvent`. The event row is written first, so its UUID is
    /// stable across a crash and a retry.
    case event(UUID)
    /// A durable session — a Potty Pause, a quiz run, a game round. The session
    /// id is minted when the session starts, long before any star is awarded.
    case session(UUID)
    /// A calendar day in the caller's calendar. Used for rewards that have no
    /// row of their own; the natural collapse window for those is "once today".
    case day(Date)
    /// An explicit key fragment supplied by the caller, for migrations and
    /// imports that carry their own identity.
    case custom(String)
}

/// Builds the deterministic idempotency keys that make star awarding safe to
/// retry.
///
/// ## The scheme
///
/// ```
/// hop.reward.<version>|<childID>|<reason>|<scope>
/// ```
///
/// * `version` — `v1`. Bumping it is a deliberate, migration-visible act; it
///   would re-open every previously-collapsed award, so it never changes
///   casually.
/// * `childID` — lowercased UUID string. Two siblings finishing the same
///   routine must both be rewarded, so the child is part of the identity.
/// * `reason` — the `RewardReason` raw value. Trying the potty and washing
///   hands are two different stars for the same visit, so the reason is part of
///   the identity too.
/// * `scope` — `event:<uuid>` / `session:<uuid>` / `day:<yyyy-MM-dd>` /
///   `custom:<text>`, all lowercased.
///
/// ## Why every part is derived, never generated
///
/// A key containing a fresh `UUID()` or a wall-clock timestamp would be unique
/// per *attempt*, which is exactly wrong: the second attempt after a crash
/// would look like a new award and the child would be credited twice for one
/// routine. Every component here is a pure function of data that was already
/// durable before the award was attempted, so attempt *n* and attempt *n+1*
/// produce the same string.
///
/// ## Why UUID text is normalised
///
/// `UUID.uuidString` is uppercase in Swift, but keys also arrive from imports,
/// JSON and older builds. Lowercasing at the single point of construction means
/// a key never fails to match itself because of case.
public enum RewardIdempotency {
    /// Scheme version. See the type documentation before changing this.
    public static let version = "v1"

    private static let separator = "|"

    /// The canonical key for one award.
    public static func key(
        reason: RewardReason,
        childID: UUID,
        scope: RewardScope,
        calendar: Calendar = .current
    ) -> String {
        [
            "hop.reward.\(version)",
            normalised(childID),
            reason.rawValue,
            fragment(for: scope, calendar: calendar),
        ].joined(separator: separator)
    }

    /// The key for an award tied to a potty event, which is the common case.
    public static func key(reason: RewardReason, childID: UUID, sourceEventID: UUID) -> String {
        key(reason: reason, childID: childID, scope: .event(sourceEventID))
    }

    static func fragment(for scope: RewardScope, calendar: Calendar) -> String {
        switch scope {
        case .event(let id): "event:\(normalised(id))"
        case .session(let id): "session:\(normalised(id))"
        case .day(let date): "day:\(dayStamp(date, calendar: calendar))"
        case .custom(let text): "custom:\(normalised(text))"
        }
    }

    private static func normalised(_ id: UUID) -> String { id.uuidString.lowercased() }

    /// Collapses whitespace and case so two spellings of the same custom scope
    /// cannot award twice.
    private static func normalised(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// `yyyy-MM-dd` built from calendar components rather than a `DateFormatter`.
    ///
    /// A formatter carries a locale, and a locale can render the year in a
    /// non-Gregorian calendar or with non-ASCII digits. That would make the key
    /// depend on device settings, so the same day could award twice after a
    /// traveller changes region. Components are locale-proof.
    static func dayStamp(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return "\(pad(year, width: 4))-\(pad(month, width: 2))-\(pad(day, width: 2))"
    }

    private static func pad(_ value: Int, width: Int) -> String {
        let digits = String(abs(value))
        let padding = String(repeating: "0", count: max(0, width - digits.count))
        return (value < 0 ? "-" : "") + padding + digits
    }
}
