import Foundation

// MARK: - Identifiers

/// A stable identifier for something Hop says.
///
/// Shares the dot-separated scheme with copy keys because it *becomes* copy
/// keys: a line with id `routine.step.wash.voice` contributes
/// `routine.step.wash.voice.spoken` to the catalog.
public struct HopVoiceLineID: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: StringLiteralType) { self.rawValue = value }
    public var description: String { rawValue }
}

/// The name of an audio file in the voice bundle, without an extension.
public struct HopVoiceAssetKey: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: StringLiteralType) { self.rawValue = value }
    public var description: String { rawValue }
}

// MARK: - Assets

/// Whether a recording for a line exists in the repository yet.
///
/// Every line in HopPotty is currently `.planned`. Voice direction, casting and
/// the recording session all come after the content is settled, and pretending
/// otherwise would mean shipping a player that fails at runtime on an asset that
/// was never going to be there.
public enum HopVoiceAssetState: String, Hashable, Sendable, CaseIterable {
    /// Written and approved; no audio recorded. The line plays as caption only.
    case planned
    /// A recording with this key ships in the app bundle.
    case recorded
}

public struct HopVoiceAsset: Hashable, Sendable {
    public let key: HopVoiceAssetKey
    public let state: HopVoiceAssetState

    public init(key: HopVoiceAssetKey, state: HopVoiceAssetState) {
        self.key = key
        self.state = state
    }

    /// A line whose audio has not been recorded yet.
    public static func planned(_ key: HopVoiceAssetKey) -> HopVoiceAsset {
        HopVoiceAsset(key: key, state: .planned)
    }

    public static func recorded(_ key: HopVoiceAssetKey) -> HopVoiceAsset {
        HopVoiceAsset(key: key, state: .recorded)
    }
}

// MARK: - Voice line

/// One thing Hop says, with the written form that always accompanies it.
///
/// `caption` is not optional and never empty. Every spoken line in HopPotty has
/// a written caption (`Docs/CONTRACTS.md` §6): a deaf child, a child in a noisy
/// car, a family with the volume off and a family whose device has no recorded
/// audio yet all get the same content.
public struct HopVoiceLine: Identifiable, Hashable, Sendable {
    public let id: HopVoiceLineID
    /// The words as spoken. This is the recording script.
    public let text: String
    /// The words as written on screen. Usually identical to `text`; kept
    /// separate because a spoken line may be looser than its written form, and
    /// because several languages punctuate speech differently from prose.
    public let caption: String
    public let asset: HopVoiceAsset

    /// Builds a line, defaulting the caption to the spoken text and the asset to
    /// a planned recording named after the line.
    public init(
        id: HopVoiceLineID,
        text: String,
        caption: String? = nil,
        asset: HopVoiceAsset? = nil
    ) {
        self.id = id
        self.text = text
        self.caption = caption ?? text
        self.asset = asset ?? .planned(HopVoiceAssetKey(rawValue: "vo." + id.rawValue))
    }

    /// True when the written form differs from the spoken form and therefore
    /// needs its own translation.
    public var hasDistinctCaption: Bool { caption != text }

    /// The catalog entries this line contributes.
    ///
    /// The spoken text is always an entry — it is the script a voice actor reads
    /// in every language, so it has to be translatable. A caption entry is added
    /// only when the written form differs, because a second key holding a
    /// byte-identical string is a second thing to keep in sync for no gain.
    public func copyEntries(audience: HopCopyAudience = .child, comment: String? = nil) -> [HopCopyEntry] {
        var entries: [HopCopyEntry] = [
            HopCopyEntry(
                key: id.rawValue + ".spoken",
                value: text,
                audience: audience,
                comment: comment ?? "Spoken by Hop. Also read aloud by VoiceOver when the recording is unavailable."
            )
        ]
        if hasDistinctCaption {
            entries.append(
                HopCopyEntry(
                    key: id.rawValue + ".caption",
                    value: caption,
                    audience: audience,
                    comment: "On-screen caption for the spoken line above."
                )
            )
        }
        return entries
    }
}

// MARK: - Playback resolution

/// Why a line is showing as text instead of playing.
///
/// The reason is carried, not swallowed. A caption that appears with no audio
/// and no explanation looks like a bug to a parent and like a broken app to a
/// support engineer; a reason lets the debug lab print "37 lines are caption
/// only: assetNotYetRecorded" and lets the player decide whether to fall back to
/// the system speech synthesiser.
public enum HopVoiceUnavailability: String, Hashable, Sendable, CaseIterable {
    /// The line is authored but nobody has recorded it. The launch state.
    case assetNotYetRecorded
    /// The content says a recording exists, but the bundle does not have it.
    /// A packaging mistake — the app should log this, loudly, in debug builds.
    case assetMissingFromBundle
    /// The caregiver switched Hop's voice off in Settings.
    case voiceTurnedOff
}

/// What the player should do with a line.
public enum HopVoicePlayback: Hashable, Sendable {
    /// Play this asset and show the caption alongside it.
    case play(HopVoiceAssetKey, caption: String)
    /// Show the caption only, for this reason.
    case captionOnly(caption: String, because: HopVoiceUnavailability)

    public var caption: String {
        switch self {
        case .play(_, let caption): caption
        case .captionOnly(let caption, _): caption
        }
    }

    public var isAudible: Bool {
        if case .play = self { return true }
        return false
    }
}

/// Decides how a line is delivered on this device, right now.
///
/// The two inputs are the caregiver's setting and the set of assets the bundle
/// actually contains. Both are supplied by the app layer; Core does no file I/O,
/// which is what keeps this testable on Linux.
public struct HopVoiceResolver: Sendable {
    public let isVoiceEnabled: Bool
    /// Asset keys present in the shipped voice bundle. Empty is a legitimate
    /// state and the one HopPotty is in today.
    public let availableAssets: Set<HopVoiceAssetKey>

    public init(isVoiceEnabled: Bool, availableAssets: Set<HopVoiceAssetKey> = []) {
        self.isVoiceEnabled = isVoiceEnabled
        self.availableAssets = availableAssets
    }

    /// The resolver used when no voice bundle has shipped: captions for
    /// everything, with a reason attached.
    public static let captionsOnly = HopVoiceResolver(isVoiceEnabled: true, availableAssets: [])

    public func playback(for line: HopVoiceLine) -> HopVoicePlayback {
        guard isVoiceEnabled else {
            return .captionOnly(caption: line.caption, because: .voiceTurnedOff)
        }
        switch line.asset.state {
        case .planned:
            return .captionOnly(caption: line.caption, because: .assetNotYetRecorded)
        case .recorded:
            guard availableAssets.contains(line.asset.key) else {
                return .captionOnly(caption: line.caption, because: .assetMissingFromBundle)
            }
            return .play(line.asset.key, caption: line.caption)
        }
    }
}

// MARK: - Catalog

/// Every line Hop can say, gathered from the content that owns it.
///
/// Derived rather than hand-listed, so a new routine step or quiz question is
/// covered by the recording script and the caption tests the moment it is
/// written.
public enum HopVoiceCatalog {
    public static var allLines: [HopVoiceLine] {
        PottyRoutineContent.voiceLines
            + QuizContent.voiceLines
            + MiniGameCatalog.voiceLines
            + HopVoice.shared.allLines
    }

    /// Lines with no recording yet. The recording session's work list.
    public static var unrecordedLines: [HopVoiceLine] {
        allLines.filter { $0.asset.state == .planned }
    }

    /// Fraction of lines with audio, 0...1. Reported in the debug lab so the
    /// gap between "written" and "recorded" is visible rather than assumed.
    public static var recordedFraction: Double {
        let lines = allLines
        guard !lines.isEmpty else { return 0 }
        let recorded = lines.filter { $0.asset.state == .recorded }.count
        return Double(recorded) / Double(lines.count)
    }

    /// A plain-text script for a voice session: one block per line, in a stable
    /// order, with the asset key the file has to be named after.
    public static func recordingScript() -> String {
        allLines
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map { line in
                """
                \(line.asset.key.rawValue)
                  say: \(line.text)
                  caption: \(line.caption)
                """
            }
            .joined(separator: "\n\n")
    }
}

/// Lines that belong to no single step or question: the redirects, the
/// affirmations and the celebration.
///
/// Deliberately not a `HopCopySection`: its lines land on four different
/// surfaces (`quizzes.`, `celebration.`, `shield.`, `games.`) because that is
/// where a child hears them, and a section that claimed one surface would have
/// to lie about the other three.
public struct HopVoiceSharedLines: Sendable {
    /// The only response to an answer that is not the one being taught. There is
    /// no second, sterner version — a child who picks twice hears the same warm
    /// invitation both times.
    public let quizRedirect = HopVoiceLine(
        id: "quizzes.feedback.redirect",
        text: "Almost! Let's try another."
    )
    public let quizAffirm = HopVoiceLine(
        id: "quizzes.feedback.affirm",
        text: "Yes! That's it."
    )
    public let quizFinished = HopVoiceLine(
        id: "quizzes.feedback.finished",
        text: "You answered them all!"
    )
    public let routineSuccess = HopVoiceLine(
        id: "celebration.success.voice",
        text: "You listened to your body!"
    )
    public let routineNoOutput = HopVoiceLine(
        id: "celebration.tried.voice",
        text: "Nothing happened? That's okay. Nice trying!"
    )
    public let hygieneCheer = HopVoiceLine(
        id: "celebration.hygiene.voice",
        text: "Flush, wash, high five!"
    )
    public let resume = HopVoiceLine(
        id: "celebration.resume.voice",
        text: "Back to play!"
    )
    public let shieldInvitation = HopVoiceLine(
        id: "shield.invitation.voice",
        text: "Potty time! Let's hop to the potty.",
        caption: "Potty time! Let's hop to the potty."
    )
    public let gameFinished = HopVoiceLine(
        id: "games.feedback.finished",
        text: "Great playing!"
    )

    public var allLines: [HopVoiceLine] {
        [
            quizRedirect, quizAffirm, quizFinished,
            routineSuccess, routineNoOutput, hygieneCheer, resume,
            shieldInvitation, gameFinished,
        ]
    }

    /// Entries are keyed by each line's own id, which already carries the
    /// surface it belongs to.
    public var entries: [HopCopyEntry] {
        allLines.flatMap { $0.copyEntries() }
    }
}

public enum HopVoice {
    public static let shared = HopVoiceSharedLines()
}
