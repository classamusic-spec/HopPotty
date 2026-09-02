import Foundation
import HopPottyCore

/// The bridge between `HopCopy` and the strings a notification carries.
///
/// Contract §5 says every user-visible string goes through `HopCopy`, and a
/// notification body is as user-visible as anything in the app. This is the one
/// place in the services layer that turns a `HopCopyEntry` into a `String`.
///
/// ## Localisation seam
///
/// `localized(_:)` looks the key up in the app's string table and falls back to
/// the English value baked into the catalog. That means the app is correct today
/// with no `Localizable.xcstrings` present, and correct tomorrow when one ships,
/// with no change here — which is the property the key/value pairing in
/// `HopCopyEntry` was designed for.
enum HopNotificationCopy {

    /// Hop's frog, prefixed to the child-facing warning title.
    ///
    /// Kept out of the copy catalog on purpose: it is a fixed piece of brand
    /// decoration rather than a translatable string, and a translator should
    /// never have to decide whether the frog stays.
    static let hopGlyph = "🐸"

    /// "🐸 Potty break coming soon!"
    static func warningTitle() -> String {
        hopGlyph + " " + localized(HopCopy.notification.warningTitle)
    }

    /// "Maya, find a good spot to pause your game." — or the nameless variant.
    ///
    /// The nickname goes into the notification body and nowhere else: not into a
    /// log line, not into the identifier, not into the export unless the
    /// caregiver asked for it.
    static func warningBody(nickname: String?) -> String {
        let variants = HopCopy.notification.warningBody
        let entry = variants.entry(forNickname: nickname)
        let format = localized(entry)
        guard let name = ChildProfile.sanitize(nickname) else { return format }
        return HopCopyFormat.filling(format, with: [1: name])
    }

    /// "Hop says: potty time?"
    ///
    /// No frog glyph and no nickname. This one lands on the *caregiver's* lock
    /// screen, next to their work mail, because they asked to be nudged — the
    /// decoration that suits a child's screen would be noise there, and a
    /// child's name on a caregiver's lock screen is a detail nobody asked
    /// HopPotty to broadcast.
    static func quickReminderTitle() -> String { localized(HopCopy.notification.quickReminderTitle) }

    /// "A gentle nudge you set earlier."
    ///
    /// Deliberately says where it came from. A reminder that does not explain
    /// itself reads as the app asking for attention, which is the one thing
    /// HopPotty's notifications may never do.
    static func quickReminderBody() -> String { localized(HopCopy.notification.quickReminderBody) }

    static func summaryTitle() -> String { localized(HopCopy.notification.summaryTitle) }

    /// Deliberately number-free. A push that says "3 accidents today" is a
    /// scorecard delivered to a lock screen, and it is not what an opt-in
    /// summary is for — the timeline in the app is.
    static func summaryBody() -> String { localized(HopCopy.notification.summaryBody) }

    /// Looks a key up, falling back to the catalog's English value.
    static func localized(_ entry: HopCopyEntry) -> String {
        Bundle.main.localizedString(forKey: entry.localizationKey, value: entry.value, table: nil)
    }
}
