import Foundation
import OSLog

/// Privacy-safe logging for the HopPotty app target.
///
/// ## Why this file exists at all
///
/// HopPotty runs on a family's device, watches a child's app usage, and holds a
/// record of when a three-year-old used a toilet. A log line is not a private
/// place: `OSLog` messages are readable in Console.app by anyone with the
/// device unlocked and a Mac, they are collected into sysdiagnose archives that
/// get emailed to support desks, and public-formatted values are retained on
/// disk. So the rule is not "be careful what you log", it is **the identifying
/// value never enters the logging call in the first place**.
///
/// ## What must never be logged
///
/// | Never | Why |
/// | --- | --- |
/// | Nicknames | It is the child's name. That is the whole of the identity HopPotty holds. |
/// | Free-text notes | Caregiver-written, often medical or intimate ("blood in stool", "cried again"). |
/// | App / category selections | Reveals what the child watches and, transitively, the household. |
/// | Raw child UUIDs | Stable across launches, so a log archive can be joined to an export or a crash report. |
/// | Event kinds tied to a time | "poop at 14:03" is a health record with a timestamp on it. |
///
/// Counts, durations, enum case names for *configuration* (not outcomes),
/// failure kinds and state-machine transitions are all fine and are what makes
/// the logs worth having.
///
/// ## The child tag
///
/// Multi-child support means most log lines need to distinguish "which child"
/// without saying *who*. `HopLog.tag(for:)` produces a four-hex-digit tag that
/// is stable **within one launch** and different on the next one, because
/// `UUID.hashValue` is seeded per process. That is deliberate: it is enough to
/// follow one child through a single session's logs while debugging, and not
/// enough to correlate two sysdiagnoses taken a week apart.
enum HopLog {

    /// One subsystem for the app, so a `log stream --subsystem` filter shows
    /// everything HopPotty is doing and nothing else.
    static let subsystem = "com.hoppotty.app"

    /// The complete set of logging categories.
    ///
    /// Closed on purpose. A category that means "everything else" becomes the
    /// category everything is logged to, and then nobody can filter anything.
    /// Adding one is a deliberate act with a review attached.
    enum Category: String, CaseIterable {
        /// Family Controls authorization requests and status changes.
        case authorization
        /// Interval arithmetic, quiet windows, projections, warning timing.
        case scheduling
        /// `DeviceActivity` registration and threshold callbacks.
        case monitoring
        /// `ManagedSettings` shield application and clearing.
        case shield
        /// Recovering a pause session after process death.
        case restoration
        /// Store lifecycle, migration, repository writes, export and deletion.
        ///
        /// Also the channel for **bundled-resource and device-capability**
        /// diagnostics — a voice asset that is declared but missing, a haptic
        /// engine that will not start. Those are "what is actually on this
        /// device" questions, which is the same question this category answers
        /// for the store, and folding them in here keeps the category list at
        /// the eight the spec names rather than growing one per subsystem.
        case persistence
        /// Local notification permission and scheduling.
        case notification
        /// StoreKit product loading, purchase, entitlement changes.
        case purchase
    }

    // Loggers are cheap but not free; one per category, made once.
    static let authorization = Logger(subsystem: subsystem, category: Category.authorization.rawValue)
    static let scheduling = Logger(subsystem: subsystem, category: Category.scheduling.rawValue)
    static let monitoring = Logger(subsystem: subsystem, category: Category.monitoring.rawValue)
    static let shield = Logger(subsystem: subsystem, category: Category.shield.rawValue)
    static let restoration = Logger(subsystem: subsystem, category: Category.restoration.rawValue)
    static let persistence = Logger(subsystem: subsystem, category: Category.persistence.rawValue)
    static let notification = Logger(subsystem: subsystem, category: Category.notification.rawValue)
    static let purchase = Logger(subsystem: subsystem, category: Category.purchase.rawValue)

    static func logger(for category: Category) -> Logger {
        switch category {
        case .authorization: authorization
        case .scheduling: scheduling
        case .monitoring: monitoring
        case .shield: shield
        case .restoration: restoration
        case .persistence: persistence
        case .notification: notification
        case .purchase: purchase
        }
    }

    /// A per-launch, non-reversible tag for a child, safe to log publicly.
    ///
    /// Four hex digits collide roughly once in 65,536, which is irrelevant for a
    /// family with at most a handful of profiles and keeps the line readable.
    static func tag(for childID: UUID) -> String {
        String(format: "c%04x", UInt16(truncatingIfNeeded: childID.hashValue))
    }

    /// The same tag for an optional id, so call sites do not branch.
    static func tag(for childID: UUID?) -> String {
        guard let childID else { return "c----" }
        return tag(for: childID)
    }

    /// A per-launch tag for any other identifier — a pause session, a
    /// transaction. Same reasoning as `tag(for:)`.
    static func shortTag(_ id: UUID, prefix: String) -> String {
        String(format: "%@%04x", prefix, UInt16(truncatingIfNeeded: id.hashValue))
    }

    /// A description of an error that cannot contain user text.
    ///
    /// `error.localizedDescription` on a Core Data / SwiftData failure can and
    /// does interpolate the offending row's values into the message, which is
    /// how a nickname ends up in a log nobody meant to write it to. The domain
    /// and code identify the failure well enough to fix it.
    static func safeDescription(_ error: any Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain)#\(nsError.code)"
    }
}
