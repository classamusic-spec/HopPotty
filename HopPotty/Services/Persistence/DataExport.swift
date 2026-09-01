import Foundation
import HopPottyCore

// MARK: - The format
//
// ## `hoppotty.export`, format version 1
//
// A single JSON object. UTF-8, ISO-8601 instants, keys sorted so two exports of
// the same data are byte-identical and a caregiver can diff them.
//
// ```json
// {
//   "format": "hoppotty.export",
//   "formatVersion": 1,
//   "generatedAt": "2026-09-01T18:30:00Z",
//   "timeZone": "America/New_York",
//   "appVersion": "1.0 (12)",
//   "contents": { "notesIncluded": true, "nicknamesIncluded": true },
//   "children": [
//     {
//       "ref": "child-1",
//       "nickname": "Maya",
//       "createdAt": "2026-06-02T14:05:00Z",
//       "totals": { "pottyEvents": 47, "stars": 34, "pondItems": 6,
//                   "quizPlays": 3, "gamePlays": 5 },
//       "schedule": { "mode": "routine", "trigger": "screenActivity",
//                     "intervalMinutes": 45, "pauseSeconds": 180,
//                     "warningSeconds": 120, "cooldownSeconds": 300,
//                     "activeDays": [1,2,3,4,5,6,7],
//                     "activeWindow": { "start": "07:00", "end": "19:30" },
//                     "quietWindows": [ { "label": "nap", "start": "12:30",
//                                         "end": "14:30", "days": [] } ],
//                     "enabled": true },
//       "screenTime": { "status": "approved", "apps": 4, "categories": 1,
//                       "webDomains": 0 },
//       "events": [ { "ref": "e-1", "at": "2026-06-02T14:12:00Z", "kind": "pee",
//                     "source": "childRoutine", "pause": "p-1",
//                     "note": "asked to go on her own" } ],
//       "stars": [ { "at": "2026-06-02T14:12:00Z", "reason": "triedThePotty",
//                    "quantity": 1, "forEvent": "e-1" } ],
//       "pond": [ { "item": "lilyPadSmall", "unlockedAt": "..." } ],
//       "quizPlays": [ { "quiz": "whereDoesPoopGo", "plays": 2,
//                        "lastPlayed": "..." } ],
//       "gamePlays": [ { "game": "bubbleWash", "plays": 5, "lastPlayed": "..." } ]
//     }
//   ],
//   "settings": { "hopVoice": true, ... }
// }
// ```
//
// ## What is deliberately not in it
//
// **No UUIDs, anywhere.** Not for children, events, transactions, schedules or
// pause sessions. Internal identifiers in an exported file are a liability with
// no upside for the person reading it: they are stable across exports, so two
// files a year apart can be joined; they appear in support tickets and email
// attachments; and nothing a caregiver wants to do with this file needs them.
// Cross-references that *are* useful — "this star came from that event" — use
// per-export refs (`e-1`, `p-1`) that are meaningless outside the file.
//
// **No reward idempotency keys.** They embed the child's UUID by construction
// (`RewardIdempotency`), so exporting one would leak the identifier the refs
// exist to avoid.
//
// **No app or category selections.** HopPotty never holds them in a readable
// form — `ScreenTimeConfiguration` carries counts on purpose — and the export
// carries the same counts and nothing more.
//
// **Notes and nicknames only if the caregiver says so.** Both default to
// included, because this is the caregiver's own record and a health-visitor
// appointment is the main reason to make one. Both can be switched off, and
// when they are, the keys are absent rather than null or empty — an absent key
// cannot be misread as "the note was blank".
//
// **No device, account, locale or diagnostic data.** The time zone identifier is
// present because without it the instants cannot be read back as the wall-clock
// times the family experienced.
//
// ## Re-import
//
// This format is for reading, not for restoring. Stripping the identifiers means
// an import cannot merge with existing data; it would have to create new rows
// with new ids. That is the right trade for a file that leaves the device.

// MARK: - Options

/// What the caregiver chose to include.
struct DataExportOptions: Equatable, Sendable {
    /// Caregiver free text on events. Often the most sensitive content in the
    /// store.
    var includeNotes: Bool = true
    /// The child's nickname. Off produces a file that is still readable — the
    /// children are `child-1`, `child-2` in the order they were created.
    var includeNicknames: Bool = true
    /// Which children to include. `nil` means all of them.
    var children: [UUID]?

    /// Everything, which is what the export sheet offers first.
    static let complete = DataExportOptions()

    /// The privacy-minimal shape: counts, timings and outcomes, no free text and
    /// no names. What a caregiver sends to someone they do not know well.
    static let minimal = DataExportOptions(includeNotes: false, includeNicknames: false)
}

/// What an export actually contained. Fills the "your file is ready" sheet, and
/// is the number a caregiver checks before sending it anywhere.
struct DataExportManifest: Equatable, Sendable {
    var childCount = 0
    var pottyEventCount = 0
    var starCount = 0
    var rewardRowCount = 0
    var pondItemCount = 0
    var noteCount = 0
    var byteCount = 0
    var generatedAt = Date()
    var includedNotes = true
    var includedNicknames = true
}

struct DataExportResult: Sendable {
    let data: Data
    let manifest: DataExportManifest
    /// A filename with no identity in it. Dated so a caregiver taking two
    /// exports a month apart can tell them apart.
    var suggestedFileName: String {
        let stamp = DataExportService.fileStampFormatter.string(from: manifest.generatedAt)
        return "HopPotty-\(stamp).json"
    }
}

// MARK: - Service

/// Builds the export file.
@MainActor
final class DataExportService {
    static let formatIdentifier = "hoppotty.export"
    static let formatVersion = 1

    private let repositories: RepositorySet
    private let clock: any HopClock

    init(repositories: RepositorySet, clock: any HopClock = SystemClock()) {
        self.repositories = repositories
        self.clock = clock
    }

    /// Produces the file.
    ///
    /// Requires a `ParentAuthorization` for the same reason deletion does: this
    /// is the operation that takes a child's potty history off the device.
    func export(
        options: DataExportOptions = .complete,
        authorization: ParentAuthorization
    ) async throws -> DataExportResult {
        guard authorization.isValid(at: clock.now) else { throw DeletionError.authorizationExpired }
        guard authorization.reason == .exportData else { throw DeletionError.wrongAuthorization }

        var manifest = DataExportManifest(
            generatedAt: clock.now,
            includedNotes: options.includeNotes,
            includedNicknames: options.includeNicknames
        )

        var profiles = try await repositories.profiles.allProfiles()
        if let wanted = options.children {
            let set = Set(wanted)
            profiles = profiles.filter { set.contains($0.id) }
        }

        var children: [ExportedChild] = []
        for (index, profile) in profiles.enumerated() {
            let child = try await exportChild(profile, ordinal: index + 1, options: options)
            manifest.pottyEventCount += child.events.count
            manifest.starCount += child.totals.stars
            manifest.rewardRowCount += child.stars.count
            manifest.pondItemCount += child.pond.count
            manifest.noteCount += child.events.filter { $0.note != nil }.count
            children.append(child)
        }
        manifest.childCount = children.count

        let file = ExportedFile(
            format: Self.formatIdentifier,
            formatVersion: Self.formatVersion,
            generatedAt: manifest.generatedAt,
            timeZone: clock.calendar.timeZone.identifier,
            appVersion: Self.appVersionString(),
            contents: ExportedContents(
                notesIncluded: options.includeNotes,
                nicknamesIncluded: options.includeNicknames
            ),
            children: children,
            settings: ExportedSettings(try await repositories.settings.settings())
        )

        let data = try encode(file)
        manifest.byteCount = data.count
        HopLog.persistence.notice(
            "export written children=\(manifest.childCount, privacy: .public) events=\(manifest.pottyEventCount, privacy: .public) notes=\(options.includeNotes, privacy: .public) bytes=\(data.count, privacy: .public)"
        )
        return DataExportResult(data: data, manifest: manifest)
    }

    private func exportChild(
        _ profile: ChildProfile,
        ordinal: Int,
        options: DataExportOptions
    ) async throws -> ExportedChild {
        let events = try await repositories.events.events(
            matching: PottyEventQuery(childID: profile.id, newestFirst: false)
        )
        let ledger = try await repositories.rewards.ledger(for: profile.id)
        let pond = try await repositories.pond.progress(for: profile.id)
        let schedule = try await repositories.schedules.schedule(for: profile.id)
        let screenTime = try await repositories.screenTime.configuration(for: profile.id)
        let quizzes = try await repositories.quizzes.progress(for: profile.id)
        let games = try await repositories.games.progress(for: profile.id)

        // Refs are assigned here and nowhere else. Two maps, built once, so a
        // star's `forEvent` and its event's `ref` cannot disagree.
        var eventRefs: [UUID: String] = [:]
        var pauseRefs: [UUID: String] = [:]
        for (index, event) in events.enumerated() {
            eventRefs[event.id] = "e-\(index + 1)"
            if let pauseID = event.pauseSessionID, pauseRefs[pauseID] == nil {
                pauseRefs[pauseID] = "p-\(pauseRefs.count + 1)"
            }
        }

        let exportedEvents = events.map { event in
            ExportedEvent(
                ref: eventRefs[event.id] ?? "e-?",
                at: event.timestamp,
                kind: event.kind.rawValue,
                source: event.source.rawValue,
                pause: event.pauseSessionID.flatMap { pauseRefs[$0] },
                note: options.includeNotes ? event.note : nil
            )
        }

        let exportedStars = ledger.transactions
            .sorted { $0.timestamp < $1.timestamp }
            .map { transaction in
                ExportedStar(
                    at: transaction.timestamp,
                    reason: transaction.reason.rawValue,
                    quantity: transaction.quantity,
                    // A star whose event was deleted has no ref, which is
                    // exactly the orphan state `RewardService.reconcile`
                    // produces. The absence is the information.
                    forEvent: transaction.sourceEventID.flatMap { eventRefs[$0] }
                )
            }

        return ExportedChild(
            ref: "child-\(ordinal)",
            nickname: options.includeNicknames ? profile.nickname : nil,
            createdAt: profile.createdAt,
            totals: ExportedTotals(
                pottyEvents: events.count,
                stars: ledger.totalStars(for: profile.id),
                pondItems: pond.unlockedCount,
                quizPlays: quizzes.totalCompletions,
                gamePlays: games.totalCompletions
            ),
            schedule: schedule.map(ExportedSchedule.init),
            screenTime: screenTime.map(ExportedScreenTime.init),
            events: exportedEvents,
            stars: exportedStars,
            pond: pond.unlocked
                .map { ExportedPondItem(item: $0.key.rawValue, unlockedAt: $0.value) }
                .sorted { $0.unlockedAt < $1.unlockedAt },
            quizPlays: quizzes.completionsByQuiz
                .map {
                    ExportedPlay(id: $0.key, plays: $0.value, lastPlayed: quizzes.lastCompletedByQuiz[$0.key])
                }
                .sorted { $0.id < $1.id },
            gamePlays: games.completionsByGame
                .map {
                    ExportedPlay(id: $0.key, plays: $0.value, lastPlayed: games.lastCompletedByGame[$0.key])
                }
                .sorted { $0.id < $1.id }
        )
    }

    private func encode(_ file: ExportedFile) throws -> Data {
        let encoder = JSONEncoder()
        // Sorted keys make the file diffable; pretty printing makes it readable
        // by the caregiver who opens it in Notes rather than a JSON viewer.
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        do {
            return try encoder.encode(file)
        } catch {
            HopLog.persistence.error(
                "export encode failed error=\(HopLog.safeDescription(error), privacy: .public)"
            )
            throw PersistenceError.readFailed
        }
    }

    static let fileStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // Fixed locale: the filename must not become non-ASCII or reorder its
        // components because the device is set to a different region.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func appVersionString() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }
}

// MARK: - Wire types
//
// Separate `Encodable` structs rather than encoding the domain values directly.
// `PottyEvent` is `Codable`, and encoding it would put its UUIDs in the file —
// the sanitisation would be one forgotten `CodingKeys` away from undone. These
// types simply have nowhere to put an identifier.

private struct ExportedFile: Encodable {
    let format: String
    let formatVersion: Int
    let generatedAt: Date
    let timeZone: String
    let appVersion: String
    let contents: ExportedContents
    let children: [ExportedChild]
    let settings: ExportedSettings
}

private struct ExportedContents: Encodable {
    let notesIncluded: Bool
    let nicknamesIncluded: Bool
}

private struct ExportedChild: Encodable {
    let ref: String
    let nickname: String?
    let createdAt: Date
    let totals: ExportedTotals
    let schedule: ExportedSchedule?
    let screenTime: ExportedScreenTime?
    let events: [ExportedEvent]
    let stars: [ExportedStar]
    let pond: [ExportedPondItem]
    let quizPlays: [ExportedPlay]
    let gamePlays: [ExportedPlay]
}

private struct ExportedTotals: Encodable {
    let pottyEvents: Int
    let stars: Int
    let pondItems: Int
    let quizPlays: Int
    let gamePlays: Int
}

private struct ExportedEvent: Encodable {
    let ref: String
    let at: Date
    let kind: String
    let source: String
    let pause: String?
    let note: String?
}

private struct ExportedStar: Encodable {
    let at: Date
    let reason: String
    let quantity: Int
    let forEvent: String?
}

private struct ExportedPondItem: Encodable {
    let item: String
    let unlockedAt: Date
}

private struct ExportedPlay: Encodable {
    let id: String
    let plays: Int
    let lastPlayed: Date?
}

private struct ExportedSchedule: Encodable {
    let mode: String
    let trigger: String
    let intervalMinutes: Int
    let warningSeconds: Int
    let pauseSeconds: Int
    let cooldownSeconds: Int
    let activeDays: [Int]
    let activeWindow: ExportedWindow
    let quietWindows: [ExportedQuietWindow]
    let enabled: Bool

    init(_ schedule: PottySchedule) {
        mode = schedule.mode.rawValue
        trigger = schedule.triggerBasis.rawValue
        intervalMinutes = schedule.interval.minutes
        warningSeconds = Int(schedule.warningOffset)
        pauseSeconds = Int(schedule.pauseDuration)
        cooldownSeconds = Int(schedule.cooldown)
        activeDays = schedule.activeDays.map(\.rawValue).sorted()
        activeWindow = ExportedWindow(
            start: schedule.activeWindowStart.description,
            end: schedule.activeWindowEnd.description
        )
        quietWindows = schedule.quietWindows.map(ExportedQuietWindow.init)
        enabled = schedule.isEnabled
    }
}

private struct ExportedWindow: Encodable {
    let start: String
    let end: String
}

private struct ExportedQuietWindow: Encodable {
    let label: String
    let start: String
    let end: String
    let days: [Int]
    let enabled: Bool

    init(_ window: QuietWindow) {
        label = window.label.rawValue
        start = window.start.description
        end = window.end.description
        days = window.days.map(\.rawValue).sorted()
        enabled = window.isEnabled
    }
}

private struct ExportedScreenTime: Encodable {
    let status: String
    let apps: Int
    let categories: Int
    let webDomains: Int
    let lastRegistered: Date?
    let lastFailure: String?

    init(_ configuration: ScreenTimeConfiguration) {
        status = configuration.authorizationStatus.rawValue
        // Counts only. There is no key here that could hold a bundle identifier.
        apps = configuration.selectedApplicationCount
        categories = configuration.selectedCategoryCount
        webDomains = configuration.selectedWebDomainCount
        lastRegistered = configuration.lastMonitoringRegistration
        lastFailure = configuration.lastRegistrationFailure?.rawValue
    }
}

private struct ExportedSettings: Encodable {
    let hopVoice: Bool
    let soundEffects: Bool
    let ambientAudio: Bool
    let haptics: Bool
    let captions: Bool
    let warningNotifications: Bool
    let dailySummary: Bool
    let dailySummaryTime: String
    let miniGames: Bool
    let quizzes: Bool
    let routineSitTimer: Bool
    let routineSitTimerSeconds: Int
    let parentGate: String

    init(_ settings: AppSettings) {
        hopVoice = settings.hopVoiceEnabled
        soundEffects = settings.soundEffectsEnabled
        ambientAudio = settings.ambientAudioEnabled
        haptics = settings.hapticsEnabled
        captions = settings.spokenTextCaptionsEnabled
        warningNotifications = settings.warningNotificationsEnabled
        dailySummary = settings.dailySummaryEnabled
        dailySummaryTime = settings.dailySummaryTime.description
        miniGames = settings.miniGamesEnabled
        quizzes = settings.quizzesEnabled
        routineSitTimer = settings.routineSitTimerEnabled
        routineSitTimerSeconds = Int(settings.routineSitTimerDuration)
        parentGate = settings.parentGateStyle.rawValue
        // `activeChildID` is not exported: it is a UUID, and which profile was
        // last open is not information about the child anyway.
    }
}
