import Foundation
import HopPottyCore
#if canImport(ManagedSettings)
import ManagedSettings
#endif

// MARK: - Target membership
//
// SHARED BY ALL FOUR TARGETS. See the note at the top of `ScreenTimeIdentifiers.swift`.

/// The payloads that cross the App Group boundary.
///
/// ## What is here, and what is deliberately not
///
/// Three records, all small, all versioned, none of them carrying anything about
/// a child:
///
/// - ``SharedPauseRecord`` — session id, pause state, the instants, a failure code.
/// - ``ExtensionReport`` — one structural fact an extension observed.
/// - ``ShieldPresentation`` — the four strings and four colours the shield draws.
///
/// **Not here, and never to be added:** the child's identifier, nickname, age,
/// pronouns or notes; any `PottyEvent`; the star ledger; the schedule; free-form
/// text of any kind. An App Group container is readable by every target holding
/// the entitlement and is included in device backups. A parenting app puts the
/// least it can across that line.
///
/// The prohibition on free text is structural rather than advisory: `ExtensionReport`
/// has no `String` field a caller could fill in. Everything it can say, it says
/// with an enum. That is the only way to be sure that an extension which *can*
/// read `Application.localizedDisplayName` — the shield configuration extension is
/// the one place in the system where app identity is legible — never writes one
/// out by accident.

// MARK: - Pause record

/// The one source of truth for "is a pause running", as the extensions need it.
///
/// ## On concurrent writers
///
/// The app, the monitor extension and the shield-action extension can all write
/// this file. That is not the single-writer discipline the rest of the boundary
/// uses, and it is a considered exception:
///
/// - Writes are **atomic** (`Data.write(to:options:.atomic)` renames into place),
///   so a reader never sees a torn record.
/// - The only remaining hazard is a lost update, and **every lost update resolves
///   toward clearing the shield.** The record carries an absolute `plannedEndAt`
///   and an absolute `backstopEndAt`; an older record that overwrites a newer one
///   can at worst re-assert a pause that is already bounded and already expiring.
///   It can never extend one, because no writer may write a later expiry than the
///   one the pause started with.
/// - The alternative — one file per writer, merged on read — costs three reads in
///   an extension whose entire budget is "return as quickly as possible", to
///   prevent a race whose worst outcome is a redundant `clearAllSettings()`.
///
/// The invariant that makes this safe is worth stating on its own: **`startedAt`,
/// `plannedEndAt` and `backstopEndAt` are written once, at pause start, and are
/// `let`. Only `state` and `failureCode` ever change.** A pause cannot be
/// lengthened by any process, which is Contract §4.1 expressed in the type system.
public struct SharedPauseRecord: Codable, Equatable, Sendable {

    /// Bumped when the meaning of a field changes. A reader that finds a version
    /// it does not understand treats the record as absent — and absence means
    /// "clear the shield", which is the correct reading of a downgrade, a
    /// restored backup, or a hand-edited container.
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int

    /// An opaque per-pause identifier: a random UUID string, not derived from and
    /// not resolvable to a child. The app keeps the session-to-child mapping in
    /// its own private store, which is where that mapping belongs.
    public let sessionID: String

    /// Where the pause is, coarsely.
    public var state: SharedPauseState

    /// When the pause began. Absolute, never wall-clock: a pause survives a
    /// timezone change and a DST transition unchanged, because an instant cannot
    /// be reinterpreted by a change of zone. (Quiet windows are the opposite case
    /// and are stored the opposite way — see `LocalTimeOfDay`.)
    public let startedAt: Date

    /// `ProcessInfo.systemUptime` at the instant the pause started.
    ///
    /// The wall clock can be moved; uptime cannot, and it resets to near zero on
    /// reboot. Storing both is what lets `ShieldReconciler` tell "someone changed
    /// the clock" apart from "the device restarted" — two situations that both
    /// invalidate a session and are indistinguishable from a `Date` alone.
    public let startedUptime: TimeInterval

    /// The instant the pause is *meant* to end: the caregiver's configured
    /// duration. Delivered by `intervalWillEndWarning` when that callback is
    /// punctual, and by app foreground reconciliation when it is not.
    public let plannedEndAt: Date

    /// The instant the pause ends *no matter what*: `startedAt` + 15 minutes, the
    /// shortest `DeviceActivitySchedule` the platform allows. This is the ceiling
    /// the guaranteed `intervalDidEnd` callback lands on.
    ///
    /// It is longer than any pause HopPotty schedules, on purpose. It is not the
    /// product's promise; it is the floor under the worst case where every other
    /// end-path has failed and the device has been face-down the whole time.
    public let backstopEndAt: Date

    /// The last thing that went wrong, as a `ScreenTimeFailure` raw value. A
    /// code, not a message: the sentence a caregiver reads is chosen by the app
    /// from `HopCopy`, and extensions have no business composing user-facing text.
    public var failureCode: String?

    public init(
        schemaVersion: Int = SharedPauseRecord.currentSchemaVersion,
        sessionID: String,
        state: SharedPauseState,
        startedAt: Date,
        startedUptime: TimeInterval,
        plannedEndAt: Date,
        backstopEndAt: Date,
        failureCode: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.sessionID = sessionID
        self.state = state
        self.startedAt = startedAt
        self.startedUptime = startedUptime
        self.plannedEndAt = plannedEndAt
        self.backstopEndAt = backstopEndAt
        self.failureCode = failureCode
    }

    public var failure: ScreenTimeFailure? {
        failureCode.flatMap(ScreenTimeFailure.init(rawValue:))
    }

    /// Build a record for a pause starting now, with both ceilings derived rather
    /// than passed in, so no caller can invent a longer one.
    public static func starting(
        sessionID: String = UUID().uuidString,
        at now: Date,
        uptime: TimeInterval,
        plannedDuration: TimeInterval
    ) -> SharedPauseRecord {
        // Clamped here as well as in `PottyPauseContext.pauseDuration`, because
        // this value becomes system state that outlives the process that wrote it.
        // A corrupted or migrated schedule must not be able to write a shield that
        // lasts an hour.
        let duration = min(
            max(plannedDuration, PottySchedule.minimumPauseDuration),
            PottySchedule.maximumPauseDuration
        )
        return SharedPauseRecord(
            sessionID: sessionID,
            state: .raising,
            startedAt: now,
            startedUptime: uptime,
            plannedEndAt: now.addingTimeInterval(duration),
            backstopEndAt: now.addingTimeInterval(ScreenTimeIdentifiers.backstopIntervalDuration)
        )
    }

    /// The `warningTime` to hand `DeviceActivitySchedule` so that
    /// `intervalWillEndWarning` lands on `plannedEndAt`.
    ///
    /// The schedule runs for 15 minutes; the warning fires `warningTime` *before*
    /// the end, so the offset is `backstop − planned`. Apple: "If the components
    /// specify a longer time interval than the schedule's interval, the system
    /// clamps the warning callbacks … to the start time of the interval" — so a
    /// nonsensical value degrades to "fires immediately", which errs toward
    /// ending the pause early. That is the right direction to degrade in.
    public var warningLeadTime: TimeInterval {
        max(0, backstopEndAt.timeIntervalSince(plannedEndAt))
    }

    /// The `DeviceActivitySchedule` components for this pause's backstop.
    ///
    /// Derived from the record rather than computed by whoever happens to be
    /// registering it, because the app and the monitor extension both start
    /// pauses and both must arm an identical safety net. One definition, on the
    /// type that owns the instants.
    ///
    /// `[.hour, .minute]` with no date: this is what a `DeviceActivitySchedule`
    /// takes. Note that the *pause* is still bounded by the absolute
    /// `plannedEndAt`/`backstopEndAt` above — the wall-clock components here only
    /// tell the system when to call back, and a callback that arrives at the
    /// wrong moment is checked against those instants before anything is done.
    ///
    /// Returned as a tuple rather than a `DeviceActivitySchedule` so this type
    /// stays free of DeviceActivity and can be compiled into the shield
    /// extensions, which must not link it.
    func backstopScheduleComponents(
        calendar: Calendar = .current
    ) -> (start: DateComponents, end: DateComponents, warning: DateComponents?) {
        let lead = Int(warningLeadTime / 60)
        return (
            calendar.dateComponents([.hour, .minute], from: startedAt),
            calendar.dateComponents([.hour, .minute], from: backstopEndAt),
            lead > 0 ? DateComponents(minute: lead) : nil
        )
    }
}

/// The pause, as the extensions need to understand it.
///
/// Deliberately coarser than `PottyPauseState`. An extension does not need
/// fourteen states; it needs to know whether a shield is supposed to exist.
/// Mapping down to four values at the boundary means a state added to the app
/// cannot silently change what an extension believes.
///
/// The default for an unrecognised or missing value is `.idle`, and `.idle` means
/// "clear the shield". Every unknown resolves toward the child having their apps.
public enum SharedPauseState: String, Codable, CaseIterable, Sendable {
    /// No pause. A shield found in this state is stranded, and gets cleared.
    case idle
    /// A shield has been asked for and not confirmed. Treated as shielded,
    /// because a partially applied store is indistinguishable from a full one.
    case raising
    /// A shield is up and a pause is running.
    case shielded
    /// A clear is in flight and unconfirmed. Still treated as shielded, so a
    /// second clear is attempted rather than skipped.
    case clearing

    /// Mirrors `PottyPauseState.mayHaveShieldUp`, and errs the same way.
    public var mayHaveShieldUp: Bool { self != .idle }
}

// MARK: - Extension → app reports

/// One structural fact an extension observed, for the app to drain later.
///
/// This is the *only* channel from an extension back to the app, and it is
/// append-only: one file per record, so there is no cross-process
/// read-modify-write anywhere in the design.
///
/// Every field is an enum, a timestamp, or an opaque session id. There is no
/// `String` an extension could fill with a display name, a bundle identifier, or
/// a note. That is deliberate — see the type-level note on `SharedPauseTypes`.
public struct ExtensionReport: Codable, Equatable, Sendable, Identifiable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    /// Also the filename, which is what makes appending atomic and draining safe.
    public let id: String
    public let source: Source
    public let kind: Kind
    public let at: Date
    /// The pause this concerns, if any. Opaque; carries no child identity.
    public let sessionID: String?
    /// Which kind of activity woke us. A role, never the raw name.
    public let activityRole: ScreenTimeIdentifiers.ActivityRole?
    /// How the pause ended, as a `PauseOutcome` raw value.
    public let outcomeCode: String?
    /// Why a shield was cleared, as a `ShieldReconciler.ClearReason` raw value.
    public let clearReasonCode: String?
    /// What went wrong, as a `ScreenTimeFailure` raw value.
    public let failureCode: String?

    public enum Source: String, Codable, Sendable, CaseIterable {
        case app
        case monitor
        case shieldConfiguration
        case shieldAction
    }

    /// The closed set of things an extension may report.
    ///
    /// Adding a case is a deliberate act. Adding a free-text field is not
    /// permitted at all.
    public enum Kind: String, Codable, Sendable, CaseIterable {
        // Lifecycle observed by the monitor
        case intervalDidStart
        case intervalDidEnd
        case intervalWillStartWarning
        case intervalWillEndWarning
        case eventDidReachThreshold
        case eventWillReachThresholdWarning
        // Things that happened to the shield
        case pauseStarted
        case pauseEnded
        case shieldApplied
        case shieldApplyFailed
        case shieldCleared
        case shieldDrawn
        case shieldPrimaryButtonTapped
        case shieldSecondaryButtonTapped
        // Housekeeping
        case reconciled
        case monitoringStopped
        case failure
    }

    public init(
        schemaVersion: Int = ExtensionReport.currentSchemaVersion,
        id: String = UUID().uuidString,
        source: Source,
        kind: Kind,
        at: Date,
        sessionID: String? = nil,
        activityRole: ScreenTimeIdentifiers.ActivityRole? = nil,
        outcomeCode: String? = nil,
        clearReasonCode: String? = nil,
        failureCode: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.source = source
        self.kind = kind
        self.at = at
        self.sessionID = sessionID
        self.activityRole = activityRole
        self.outcomeCode = outcomeCode
        self.clearReasonCode = clearReasonCode
        self.failureCode = failureCode
    }

    public var outcome: PauseOutcome? { outcomeCode.flatMap(PauseOutcome.init(rawValue:)) }
    public var failure: ScreenTimeFailure? { failureCode.flatMap(ScreenTimeFailure.init(rawValue:)) }
}

// MARK: - Shield presentation

/// Everything the shield draws, pre-resolved by the app.
///
/// Apple requires the shield configuration data source to return "as quickly as
/// possible", runs it in a sandbox that blocks network access, and **falls back
/// to the system's own default shield if the extension is slow**. That fallback
/// is not a cosmetic failure: the default shield carries Apple's copy, which is
/// the language of restriction — exactly the framing HopPotty exists to avoid.
///
/// So the extension performs no lookup, no localisation, no colour arithmetic and
/// no asset decoding. The app resolves all of it from `HopCopy` and
/// `HopPottyDesignTokens` while it has time to spare, and writes the result here.
/// The extension reads four strings and four colours and assembles them.
///
/// Copy still originates in `HopCopy` (Contract §5) — only the *resolution* moves
/// into the app, which is what keeps the child-safety copy test meaningful.
public struct ShieldPresentation: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let title: String
    public let subtitle: String
    public let primaryButtonLabel: String
    /// `nil` removes the secondary button entirely — that is what Apple's API
    /// means by a `nil` `secondaryButtonLabel`.
    public let secondaryButtonLabel: String?

    /// RGBA in 0...1, sRGB. Stored as components rather than a `UIColor` because
    /// the boundary is `Codable` JSON and because `HopPottyDesignTokens` is a
    /// Foundation-only package with no `UIColor` to encode.
    public let titleColor: RGBA
    public let subtitleColor: RGBA
    public let backgroundColor: RGBA
    public let primaryButtonColor: RGBA
    public let primaryButtonTextColor: RGBA

    /// `UIBlurEffect.Style.rawValue`, or `nil` for no blur.
    ///
    /// UNVERIFIED — confirm on device: whether `backgroundBlurStyle = nil` with an
    /// opaque `backgroundColor` yields a solid background, or whether the system
    /// composites the colour over a default blur regardless. If it is the latter,
    /// the shielded game shows through the Potty Pause screen, which is
    /// distracting for a three-year-old and needs a different treatment.
    public let backgroundBlurStyleRawValue: Int?

    public struct RGBA: Codable, Equatable, Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double
        public let alpha: Double

        public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        /// From a 24-bit hex literal, matching `HopColorValue(hex:)`.
        public init(hex: UInt32, alpha: Double = 1) {
            self.init(
                red: Double((hex >> 16) & 0xFF) / 255,
                green: Double((hex >> 8) & 0xFF) / 255,
                blue: Double(hex & 0xFF) / 255,
                alpha: alpha
            )
        }
    }

    public init(
        schemaVersion: Int = ShieldPresentation.currentSchemaVersion,
        title: String,
        subtitle: String,
        primaryButtonLabel: String,
        secondaryButtonLabel: String?,
        titleColor: RGBA,
        subtitleColor: RGBA,
        backgroundColor: RGBA,
        primaryButtonColor: RGBA,
        primaryButtonTextColor: RGBA,
        backgroundBlurStyleRawValue: Int?
    ) {
        self.schemaVersion = schemaVersion
        self.title = title
        self.subtitle = subtitle
        self.primaryButtonLabel = primaryButtonLabel
        self.secondaryButtonLabel = secondaryButtonLabel
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
        self.backgroundColor = backgroundColor
        self.primaryButtonColor = primaryButtonColor
        self.primaryButtonTextColor = primaryButtonTextColor
        self.backgroundBlurStyleRawValue = backgroundBlurStyleRawValue
    }

    /// The compiled-in fallback, used when the App Group payload is missing,
    /// unreadable, or written by a schema this build does not understand.
    ///
    /// This is not a placeholder. It is the shipping copy, duplicated into the
    /// extension binary on purpose: the alternative to a fallback is Apple's
    /// default shield, whose copy is the language of restriction. A HopPotty
    /// shield with slightly stale colours is a far better failure than a system
    /// shield telling a three-year-old they have reached a limit.
    ///
    /// ## Unresolved copy conflict — needs a decision before shipping
    ///
    /// The two button labels below do **not** match `HopCopy`, and the mismatch is
    /// left visible rather than silently resolved, because resolving it is a copy
    /// decision and not an engineering one:
    ///
    /// | Element | This fallback | `HopCopy` key | `HopCopy` value |
    /// | --- | --- | --- | --- |
    /// | title | "Potty time!" | `shield.title` | "Potty time!" ✅ |
    /// | subtitle | "Let's hop to the potty. Your game will be here when you get back." | `shield.body` | identical ✅ |
    /// | primary | "Let's Go!" | `shield.primary` | "Let's Go!" |
    /// | secondary | "Need a grown-up?" | `shield.secondary` | "Need a grown-up?" |
    ///
    /// At runtime **`HopCopy` wins**: the app resolves it into `shield.json` and
    /// the extension reads that, so Contract §5 holds and this fallback is only
    /// reached when the payload is missing. The `HopCopy` wording is also the
    /// better of the two — "I'm going!" is the child's own voice, and a question
    /// mark on a button aimed at a pre-reader is a smaller target than a verb.
    ///
    /// The Potty Pause Lab shows both side by side so the drift cannot be
    /// forgotten. **One of the two must change.** Until it does, a device with a
    /// broken App Group shows different button labels from a healthy one, which is
    /// exactly the kind of inconsistency a QA pass will report as a bug.
    ///
    /// `Docs/PhysicalDeviceQA.md` §3 has the check.
    ///
    /// Colours are `HopPalette.cloud`, `.midnight`, `.hopGreen` — repeated as hex
    /// rather than imported, because `HopPottyDesignTokens` is one more thing to
    /// link into a latency-critical extension for three constants.
    public static let fallback = ShieldPresentation(
        title: "Potty time!",
        subtitle: "Let's hop to the potty. Your game will be here when you get back.",
        primaryButtonLabel: "Let's Go!",
        secondaryButtonLabel: "Need a grown-up?",
        titleColor: RGBA(hex: 0x243047),          // HopPalette.midnight
        subtitleColor: RGBA(hex: 0x243047),       // HopPalette.midnight
        backgroundColor: RGBA(hex: 0xFFF9F2),     // HopPalette.cloud
        primaryButtonColor: RGBA(hex: 0x63C88A),  // HopPalette.hopGreen
        primaryButtonTextColor: RGBA(hex: 0x243047),
        backgroundBlurStyleRawValue: nil
    )
}

// MARK: - Monitoring gate
//
// Moved here from a file of its own so that it is a member of every target that
// already compiles `SharedPauseTypes.swift`. `project.yml` names exactly four
// files as shared across all four targets; adding a fifth would mean editing a
// manifest another part of the build owns, and a payload that crosses the App
// Group boundary belongs in the file named for payloads that cross the App Group
// boundary anyway.

/// The minimum a `DeviceActivityMonitor` extension needs in order to *decline* to
/// start a pause, and to start one correctly when it does.
///
/// ## Why this exists at all
///
/// The monitor extension is woken by the system with a `DeviceActivityName` and
/// nothing else. It has no `ModelContainer`, no `PottySchedule`, and no way to
/// ask the app anything — the app is usually not running, which is the entire
/// point of the extension. But it is the process that must raise a shield when a
/// usage threshold is crossed, and raising a shield requires knowing how long the
/// pause lasts and whether a pause is allowed right now at all.
///
/// Without this payload the extension would either shield for a hard-coded
/// duration it invented, or interrupt a child during a nap. Both are worse than
/// putting four pieces of configuration across the boundary.
///
/// ## Why this does not violate the boundary rule
///
/// It is configuration, not identity. There is no child identifier here, no
/// nickname, no age, no notes, no event history, no reward state, and no free
/// text — the same prohibitions that govern `SharedPauseTypes`. A reader of this
/// file learns that *somebody* on this device does not want to be interrupted
/// between 12:30 and 14:00. They learn nothing about who.
///
/// This does go beyond the five values a minimal boundary would carry, and that
/// is a deliberate, narrow exception, listed here so it cannot expand quietly:
/// **pause duration, active days, quiet ranges, cooldown.** Anything else that
/// wants to cross should be questioned as hard as this was.
///
/// ## Writer discipline
///
/// Written only by the app, whenever the schedule changes and on every foreground.
/// Read only by the monitor extension. Single writer, so no race.
public struct MonitoringGate: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int

    /// How long a pause the extension should open. Already clamped to the
    /// product's bounds by the app; clamped again on use, because this value
    /// becomes system state and a corrupted file must not be able to write an
    /// hour-long shield.
    public let pauseDurationSeconds: TimeInterval

    /// `Weekday.rawValue`s the schedule is active on. Empty means every day.
    public let activeDayNumbers: [Int]

    /// Minutes-since-midnight ranges during which no pause may start. Stored as
    /// wall-clock minutes rather than instants for the same reason `QuietWindow`
    /// does: "naps start at 12:30" means 12:30 in whatever zone the family is in
    /// today, and an absolute instant would shift by an hour every DST boundary.
    public let quietRanges: [QuietRange]

    /// The earliest and latest wall-clock minute at which a pause may occur.
    public let activeWindowStartMinutes: Int
    public let activeWindowEndMinutes: Int

    /// The quiet period after a pause. Enforced against `cooldown.json`.
    public let cooldownSeconds: TimeInterval

    public struct QuietRange: Codable, Equatable, Sendable {
        public let startMinutes: Int
        public let endMinutes: Int

        public init(startMinutes: Int, endMinutes: Int) {
            self.startMinutes = startMinutes
            self.endMinutes = endMinutes
        }

        /// Half-open, and midnight-wrapping, exactly like `QuietWindow.contains`.
        /// The two implementations must agree; `Docs/PhysicalDeviceQA.md` has a
        /// check that a nap window suppresses a pause on-device.
        public func contains(minutes: Int) -> Bool {
            if endMinutes <= startMinutes {
                return minutes >= startMinutes || minutes < endMinutes
            }
            return minutes >= startMinutes && minutes < endMinutes
        }
    }

    public init(
        schemaVersion: Int = MonitoringGate.currentSchemaVersion,
        pauseDurationSeconds: TimeInterval,
        activeDayNumbers: [Int],
        quietRanges: [QuietRange],
        activeWindowStartMinutes: Int,
        activeWindowEndMinutes: Int,
        cooldownSeconds: TimeInterval
    ) {
        self.schemaVersion = schemaVersion
        self.pauseDurationSeconds = pauseDurationSeconds
        self.activeDayNumbers = activeDayNumbers
        self.quietRanges = quietRanges
        self.activeWindowStartMinutes = activeWindowStartMinutes
        self.activeWindowEndMinutes = activeWindowEndMinutes
        self.cooldownSeconds = cooldownSeconds
    }

    public init(schedule: PottySchedule) {
        self.init(
            pauseDurationSeconds: min(
                max(schedule.pauseDuration, PottySchedule.minimumPauseDuration),
                PottySchedule.maximumPauseDuration
            ),
            activeDayNumbers: schedule.activeDays.map(\.rawValue).sorted(),
            quietRanges: schedule.quietWindows
                .filter(\.isEnabled)
                .map {
                    QuietRange(
                        startMinutes: $0.start.minutesSinceMidnight,
                        endMinutes: $0.end.minutesSinceMidnight
                    )
                },
            activeWindowStartMinutes: schedule.activeWindowStart.minutesSinceMidnight,
            activeWindowEndMinutes: schedule.activeWindowEnd.minutesSinceMidnight,
            cooldownSeconds: max(0, schedule.cooldown)
        )
    }

    /// The clamped duration to actually use.
    public var safePauseDuration: TimeInterval {
        min(
            max(pauseDurationSeconds, PottySchedule.minimumPauseDuration),
            PottySchedule.maximumPauseDuration
        )
    }

    /// Whether a pause may start at this instant.
    ///
    /// The extension calls this and nothing else. Note the direction it fails in:
    /// a gate that cannot be read at all means **no pause**, not a pause with
    /// invented settings. A missed pause is a reminder that did not happen; an
    /// invented pause is a shield of unknown duration on a child's device.
    public func permitsPause(at instant: Date, calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: instant)
        guard let hour = components.hour, let minute = components.minute else { return false }
        let minutes = hour * 60 + minute

        if !activeDayNumbers.isEmpty, let weekday = components.weekday,
           !activeDayNumbers.contains(weekday) {
            return false
        }

        let inWindow: Bool = activeWindowEndMinutes > activeWindowStartMinutes
            ? (minutes >= activeWindowStartMinutes && minutes < activeWindowEndMinutes)
            : (minutes >= activeWindowStartMinutes || minutes < activeWindowEndMinutes)
        guard inWindow else { return false }

        return !quietRanges.contains { $0.contains(minutes: minutes) }
    }
}

// MARK: Gate and cooldown storage

public extension AppGroupStore {

    private static var gateFile: String { "gate.json" }
    private static var cooldownFile: String { "cooldown.json" }

    /// One `Date` in a file. Written by whichever process ends a pause; read by
    /// the monitor before starting one.
    ///
    /// Multi-writer and last-write-wins, which is safe because the value is
    /// advisory: a stale cooldown at worst allows one pause that should have been
    /// suppressed, or suppresses one that could have run. Neither can strand a
    /// shield, which is the only class of error this layer treats as serious.
    struct CooldownRecord: Codable, Equatable, Sendable {
        public let until: Date
        public init(until: Date) { self.until = until }
    }

    func loadGate() -> MonitoringGate? {
        guard let root, let data = try? Data(contentsOf: root.appendingPathComponent(Self.gateFile)) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let gate = try? decoder.decode(MonitoringGate.self, from: data) else { return nil }
        return gate.schemaVersion == MonitoringGate.currentSchemaVersion ? gate : nil
    }

    @discardableResult
    func saveGate(_ gate: MonitoringGate) -> Bool {
        guard let root else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(gate) else { return false }
        return (try? data.write(to: root.appendingPathComponent(Self.gateFile), options: .atomic)) != nil
    }

    func clearGate() {
        guard let root else { return }
        try? FileManager.default.removeItem(at: root.appendingPathComponent(Self.gateFile))
    }

    func cooldownUntil() -> Date? {
        guard let root, let data = try? Data(contentsOf: root.appendingPathComponent(Self.cooldownFile)) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(CooldownRecord.self, from: data))?.until
    }

    func setCooldown(until instant: Date) {
        guard let root else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(CooldownRecord(until: instant)) else { return }
        try? data.write(to: root.appendingPathComponent(Self.cooldownFile), options: .atomic)
    }

    func clearCooldown() {
        guard let root else { return }
        try? FileManager.default.removeItem(at: root.appendingPathComponent(Self.cooldownFile))
    }

    /// Whether the post-pause quiet period has elapsed.
    ///
    /// A cooldown recorded in the future by more than the longest cooldown the
    /// product allows is treated as expired, because that can only come from a
    /// clock that moved. Erring toward "allowed" here is the safe direction: the
    /// cost is one extra reminder, and reminders do not shield.
    func isCooldownElapsed(at instant: Date, limit: TimeInterval) -> Bool {
        guard let until = cooldownUntil() else { return true }
        if until.timeIntervalSince(instant) > max(limit, 60) { return true }
        return instant >= until
    }
}

// MARK: - Shield tokens
//
// Here for the same reason as the monitoring gate above.

/// The three token sets a shield is built from, stored separately from the
/// caregiver's `FamilyActivitySelection`.
///
/// ## Why there are two copies of the same information
///
/// `selection.json` holds the whole `FamilyActivitySelection`, because that is
/// what `FamilyActivityPicker` round-trips and it carries `includeEntireCategory`
/// with it. But `FamilyActivitySelection` lives in **FamilyControls**, and the
/// monitor extension must not link FamilyControls: it is a latency-sensitive
/// process whose only job with these values is to hand them to
/// `ManagedSettingsStore`, and the token types themselves — `ApplicationToken`,
/// `ActivityCategoryToken`, `WebDomainToken`, all aliases of ManagedSettings'
/// `Token<T>` — are already in a framework it has to link anyway.
///
/// So the app writes the selection for itself and the tokens for the extension.
/// Both are written in the same call, from the same value, so they cannot
/// disagree; if they ever did, the tokens win, because the tokens are what
/// actually shields.
///
/// ## These are opaque and stay opaque
///
/// A token has no readable payload and HopPotty never tries to give it one. It is
/// not logged, not hashed into a key, not counted into anything but a total, and
/// not sent off-device. `Codable` is Apple's own persistence route for them, and
/// it is the only one used here.
///
/// Apple voids every token issued to an app when authorization is revoked, so
/// this file is deleted at the same moment the selection is
/// (`ScreenTimeService.clearSelection`).
#if canImport(ManagedSettings)
/// `@unchecked Sendable` rather than `Sendable`, because `ApplicationToken` and
/// its siblings are `Token<T>`, which Apple has not annotated (CI run 54 named
/// all three stored properties). A token is an opaque, immutable, `Codable`
/// value with no reference semantics and no mutable state — sending one is
/// safe; the compiler just cannot see that through an unannotated framework.
/// `@preconcurrency import` would only downgrade the diagnostic to a warning,
/// and `SWIFT_TREAT_WARNINGS_AS_ERRORS` turns it back into an error.
public struct ShieldTokens: Codable, Equatable, @unchecked Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let applications: Set<ApplicationToken>
    public let categories: Set<ActivityCategoryToken>
    public let webDomains: Set<WebDomainToken>

    public init(
        schemaVersion: Int = ShieldTokens.currentSchemaVersion,
        applications: Set<ApplicationToken>,
        categories: Set<ActivityCategoryToken>,
        webDomains: Set<WebDomainToken>
    ) {
        self.schemaVersion = schemaVersion
        self.applications = applications
        self.categories = categories
        self.webDomains = webDomains
    }

    public var isEmpty: Bool {
        applications.isEmpty && categories.isEmpty && webDomains.isEmpty
    }

    /// Apple caps each shield property at 50.
    public var exceedsLimit: Bool {
        applications.count > ScreenTimeIdentifiers.shieldTokenLimit
            || categories.count > ScreenTimeIdentifiers.shieldTokenLimit
            || webDomains.count > ScreenTimeIdentifiers.shieldTokenLimit
    }
}

/// The one place a shield is ever raised.
///
/// Both the app and the monitor extension call this, so there is a single
/// definition of what "shielded" means. A second implementation would be a second
/// opportunity to write to the wrong store.
public enum ShieldApplier {

    /// Write the shield.
    ///
    /// Every property is set on every call, `nil` included. Apple: "Changing the
    /// value of a setting to `nil` deletes your app's configuration for that
    /// setting from the device." Setting all four unconditionally means a pause
    /// that shields only apps cannot inherit a category policy from a previous
    /// pause that shielded categories.
    ///
    /// `nil` rather than an empty set, always. An empty set is a configuration
    /// that shields nothing, which is a different thing from having no
    /// configuration, and Apple documents the behaviour of neither.
    ///
    /// Returns `false` only for the one condition worth refusing on: an over-cap
    /// selection, whose behaviour Apple does not document. Everything else is
    /// written and reported through the read-back, because a `ManagedSettings`
    /// write has no result to check.
    @discardableResult
    public static func apply(_ tokens: ShieldTokens) -> Bool {
        guard !tokens.isEmpty, !tokens.exceedsLimit else { return false }

        let store = ManagedSettingsStore(named: .pottyPause)
        store.shield.applications = tokens.applications.isEmpty ? nil : tokens.applications
        store.shield.webDomains = tokens.webDomains.isEmpty ? nil : tokens.webDomains
        store.shield.applicationCategories = tokens.categories.isEmpty
            ? nil
            : .specific(tokens.categories, except: Set())
        store.shield.webDomainCategories = tokens.categories.isEmpty
            ? nil
            : .specific(tokens.categories, except: Set())
        return true
    }

    /// Whether HopPotty's own store currently asks for anything to be shielded.
    ///
    /// A record of what was requested, not an observation of the device. Apple:
    /// "The system doesn't guarantee that the settings you specify govern the
    /// device's behavior."
    ///
    /// UNVERIFIED — confirm on device: that a read returns what was last written,
    /// promptly, within a process and across processes.
    public static var storeRequestsAShield: Bool {
        let store = ManagedSettingsStore(named: .pottyPause)
        if let applications = store.shield.applications, !applications.isEmpty { return true }
        if let domains = store.shield.webDomains, !domains.isEmpty { return true }
        if store.shield.applicationCategories != nil { return true }
        if store.shield.webDomainCategories != nil { return true }
        return false
    }
}

// MARK: Token storage

public extension AppGroupStore {

    private static var tokensFile: String { "tokens.json" }

    func loadShieldTokens() -> ShieldTokens? {
        guard let root,
              let data = try? Data(contentsOf: root.appendingPathComponent(Self.tokensFile)),
              let tokens = try? JSONDecoder().decode(ShieldTokens.self, from: data)
        else { return nil }
        return tokens.schemaVersion == ShieldTokens.currentSchemaVersion ? tokens : nil
    }

    @discardableResult
    func saveShieldTokens(_ tokens: ShieldTokens) -> Bool {
        guard let root, let data = try? JSONEncoder().encode(tokens) else { return false }
        return (try? data.write(to: root.appendingPathComponent(Self.tokensFile), options: .atomic)) != nil
    }

    func clearShieldTokens() {
        guard let root else { return }
        try? FileManager.default.removeItem(at: root.appendingPathComponent(Self.tokensFile))
    }
}
#endif
