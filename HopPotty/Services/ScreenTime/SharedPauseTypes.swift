import Foundation
import HopPottyCore

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
}

/// The pause, as the extensions need to understand it.
///
/// Deliberately coarser than `PottyPauseState`. An extension does not need
/// thirteen states; it needs to know whether a shield is supposed to exist.
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
    /// The strings must stay identical to the `HopCopy` keys the app resolves.
    /// `Docs/PhysicalDeviceQA.md` has a check for exactly this drift.
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
