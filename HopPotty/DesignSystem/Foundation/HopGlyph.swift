import SwiftUI
import HopPottyCore

/// A mark with a fixed meaning.
///
/// Every one of these exists so that meaning is never carried by colour alone.
/// A caregiver who cannot distinguish the peach `poop` accent from the blue
/// `pee` accent reads two different silhouettes; so does anyone looking at a
/// printed or screenshotted timeline.
///
/// The potty and routine marks are HopPotty's own drawings rather than SF
/// Symbols: the system set has nothing for "tried", "wiped" or "lily pad", and
/// a mark that is nearly right is worse than one that is obviously bespoke.
public enum HopGlyph: String, CaseIterable, Sendable, Identifiable {
    case tried, pee, poop, accident
    case star, check, pause, play
    case timer, quietHours, shield
    case wash, flush, wipe, highFive
    case pond

    public var id: String { rawValue }

    /// The SF Symbol backing this glyph, when one genuinely means the same
    /// thing. `nil` means the glyph is drawn by ``HopGlyphShape``.
    public var systemImage: String? {
        switch self {
        case .star: "star.fill"
        case .check: "checkmark"
        case .pause: "pause.fill"
        case .play: "play.fill"
        case .timer: "timer"
        case .quietHours: "moon.fill"
        case .shield: "shield.fill"
        case .highFive: "hand.raised.fill"
        case .tried, .pee, .poop, .accident, .wash, .flush, .wipe, .pond: nil
        }
    }

    /// What VoiceOver says when this mark is the only thing carrying the
    /// meaning. Deliberately plain, and never evaluative — an accident is
    /// "accident", not "oops" and not "miss".
    public var accessibilityDescription: String {
        switch self {
        case .tried: HopStrings.glyphTried
        case .pee: HopStrings.glyphPee
        case .poop: HopStrings.glyphPoop
        case .accident: HopStrings.glyphAccident
        case .star: HopStrings.glyphStar
        case .check: HopStrings.glyphCheck
        case .pause: HopStrings.glyphPause
        case .play: HopStrings.glyphPlay
        case .timer: HopStrings.glyphTimer
        case .quietHours: HopStrings.glyphQuietHours
        case .shield: HopStrings.glyphShield
        case .wash: HopStrings.glyphWash
        case .flush: HopStrings.glyphFlush
        case .wipe: HopStrings.glyphWipe
        case .highFive: HopStrings.glyphHighFive
        case .pond: HopStrings.glyphPond
        }
    }

    /// The glyph for a logged event kind. The one mapping; nothing else decides.
    public init(_ kind: PottyEventKind) {
        switch kind {
        case .tried: self = .tried
        case .pee: self = .pee
        case .poop: self = .poop
        case .accident: self = .accident
        }
    }
}

public extension PottyEventKind {
    var glyph: HopGlyph { HopGlyph(self) }

    /// Short, neutral label. `tried` leads because it is the primary event and
    /// never the lesser outcome.
    var displayName: String {
        switch self {
        case .tried: HopStrings.eventTried
        case .pee: HopStrings.eventPee
        case .poop: HopStrings.eventPoop
        case .accident: HopStrings.eventAccident
        }
    }
}
