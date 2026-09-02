import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

// Presentation types the Design System API contract names but HopPottyCore does
// not define yet.
//
// They live here so `Docs/DesignSystemAPI.md` can be implemented exactly as
// written. Each is a plain, view-shaped value with no behaviour: when the
// insights engine, the paywall and the pause presenter land in Core, these move
// there unchanged and this file is deleted.

/// What the timer card is showing, already reduced from ``PottyPauseState`` to
/// the handful of situations that look different on screen.
public struct PottyPauseDisplayState: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        /// Potty Pause is off, or suspended indefinitely.
        case off
        /// Counting toward the next pause.
        case counting
        /// The warning threshold has passed; a pause is imminent.
        case approaching
        /// A pause is running. `remaining` counts the pause down, and it ends on
        /// that timer whatever the child does.
        case pausing
        /// Access is restored and the schedule is deliberately quiet.
        case cooldown
        /// Something needs a caregiver and a shield may still be up.
        case needsAttention(ScreenTimeFailure)
        /// Something needs a caregiver, but the child's apps are already back.
        /// Visually still an error — Potty Pause is not running — but it must
        /// never be described as if access were being withheld.
        case needsAttentionAccessRestored(ScreenTimeFailure)
    }

    public var phase: Phase
    public var mode: PottyPauseMode
    /// Time left in the current phase, when there is one to show.
    public var remaining: TimeInterval?
    /// The full length of the current phase, for the progress ring.
    public var total: TimeInterval?
    /// The child this card is about, when the family has more than one.
    public var childName: String?

    public init(
        phase: Phase,
        mode: PottyPauseMode,
        remaining: TimeInterval? = nil,
        total: TimeInterval? = nil,
        childName: String? = nil
    ) {
        self.phase = phase
        self.mode = mode
        self.remaining = remaining
        self.total = total
        self.childName = childName
    }

    /// Maps the state machine onto the five things the card can look like.
    ///
    /// `pauseTriggered`, `shieldActive`, `routineActive`, `completing` and
    /// `restoring` all collapse to `.pausing`: the caregiver's question during
    /// all five is the same — how long until my child's apps come back.
    public init(
        pauseState: PottyPauseState,
        mode: PottyPauseMode,
        remaining: TimeInterval? = nil,
        total: TimeInterval? = nil,
        childName: String? = nil
    ) {
        let phase: Phase = switch pauseState {
        case .disabled, .authorizationRequired, .ready: .off
        case .monitoring: .counting
        case .warningApproaching: .approaching
        case .pauseTriggered, .shieldActive, .routineActive, .completing, .restoring: .pausing
        case .cooldown: .cooldown
        case .errorRecoverable(let failure), .errorRequiresParent(let failure): .needsAttention(failure)
        case .errorAccessRestored(let failure): .needsAttentionAccessRestored(failure)
        }
        self.init(phase: phase, mode: mode, remaining: remaining, total: total, childName: childName)
    }

    /// Fraction elapsed, 0...1, or `nil` when there is nothing to show a ring for.
    public var progress: Double? {
        guard let remaining, let total, total > 0 else { return nil }
        return min(1, max(0, 1 - remaining / total))
    }

    /// The failure behind an attention state, if there is one.
    public var failure: ScreenTimeFailure? {
        switch phase {
        case .needsAttention(let failure), .needsAttentionAccessRestored(let failure): failure
        default: nil
        }
    }

    /// Whether the child's apps are currently being held. Drives whether the
    /// card says "apps are paused" or only "Potty Pause isn't running".
    public var isHoldingApps: Bool {
        switch phase {
        case .pausing: mode.shieldsApps
        case .off, .counting, .approaching, .cooldown, .needsAttentionAccessRestored: false
        case .needsAttention(let failure): failure.couldLeaveShieldUp
        }
    }

    /// Whether the caregiver can usefully skip or start a pause right now.
    public var allowsManualControl: Bool {
        switch phase {
        case .counting, .approaching, .cooldown: true
        case .off, .pausing, .needsAttention, .needsAttentionAccessRestored: false
        }
    }
}

/// One observed pattern, ready to render.
///
/// It carries its own sample size and its own disclaimer because the API
/// contract's card must not be able to draw an insight without them — see
/// `Docs/CONTRACTS.md` §4.5. Nothing here is phrased as advice.
public struct Insight: Identifiable, Equatable, Sendable {
    /// Stable across recomputation so a card does not re-animate on every tick.
    public let id: String
    /// A description of what was observed. Never an instruction.
    public let title: String
    /// The supporting detail, in the family's own numbers.
    public let detail: String
    public let glyph: HopGlyph
    public let window: InsightWindow
    /// How many observations this rests on.
    public let sampleSize: Int
    /// Distinct local days carrying an entry.
    public let observedDays: Int
    public let confidence: InsightConfidence.Level
    /// Actions the card may offer. Empty is normal — most insights are read-only.
    public let actions: [InsightAction]

    public init(
        id: String,
        title: String,
        detail: String,
        glyph: HopGlyph,
        window: InsightWindow,
        sampleSize: Int,
        observedDays: Int,
        confidence: InsightConfidence.Level,
        actions: [InsightAction] = []
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.glyph = glyph
        self.window = window
        self.sampleSize = sampleSize
        self.observedDays = observedDays
        self.confidence = confidence
        self.actions = actions
    }

    /// The label every insight carries, without exception. Sourced from Core so
    /// there is one sentence, not two.
    public var disclaimer: String { InsightConfidence.disclaimer }
}

/// Something a caregiver can do from an insight card.
public struct InsightAction: Identifiable, Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case adjustSchedule
        case addQuietHours
        case viewTimeline
        case dismiss
    }

    public let kind: Kind
    public let title: String

    public var id: String { kind.rawValue }

    public init(kind: Kind, title: String) {
        self.kind = kind
        self.title = title
    }
}

/// A capability that sits behind the paywall.
public enum PaywallFeature: String, CaseIterable, Sendable, Identifiable {
    case additionalChildren
    case fullPondCollection
    case detailedInsights
    case customRoutines
    case dataExport

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .additionalChildren: "More than one child"
        case .fullPondCollection: "The whole pond"
        case .detailedInsights: "Detailed patterns"
        case .customRoutines: "Custom routines"
        case .dataExport: "Export your data"
        }
    }

    /// Plain description of what unlocking adds. Never phrased as a loss.
    public var summary: String {
        switch self {
        case .additionalChildren: "Give each child their own pond, stars and schedule."
        case .fullPondCollection: "Every decoration Hop can unlock, across all three ponds."
        case .detailedInsights: "Longer windows and time-of-day comparisons."
        case .customRoutines: "Choose the steps and how long each one lasts."
        case .dataExport: "Take a copy of the timeline with you."
        }
    }

    public var glyph: HopGlyph {
        switch self {
        case .additionalChildren: .highFive
        case .fullPondCollection: .pond
        case .detailedInsights: .timer
        case .customRoutines: .check
        case .dataExport: .shield
        }
    }
}

// `HopVoiceLine` was declared here while Core was being written in
// parallel. Core owns it now (`HopPottyCore/Content/HopVoiceLine.swift`);
// keeping a second declaration collided in the app module. Its doc comment —
// that the caption is not optional and has no empty default, so a line cannot
// be expressed without one (`Docs/CONTRACTS.md` §6) — moved with it.
