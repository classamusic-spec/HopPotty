import Foundation

/// Strings the design system itself owns.
///
/// The engineering contract routes all user-visible text through `HopCopy`
/// (`HopPottyCore/Content/`), which does not exist yet. These are component
/// mechanics — a close button's label, a glyph's VoiceOver description, the
/// word "Step" in a step indicator — not product copy, and they are gathered in
/// one file precisely so the migration to `HopCopy` is a single mechanical
/// change with no call sites to hunt for.
///
/// Nothing here evaluates a child. There is no "failed", no "wrong", no "lost",
/// no negation of effort — see `Docs/CONTRACTS.md` §4.4.
enum HopStrings {
    // Glyph descriptions
    static let glyphTried = "Tried"
    static let glyphPee = "Pee"
    static let glyphPoop = "Poop"
    static let glyphAccident = "Accident"
    static let glyphStar = "Star"
    static let glyphCheck = "Done"
    static let glyphPause = "Paused"
    static let glyphPlay = "Start"
    static let glyphTimer = "Timer"
    static let glyphQuietHours = "Quiet hours"
    static let glyphShield = "Apps paused"
    static let glyphWash = "Wash hands"
    static let glyphFlush = "Flush"
    static let glyphWipe = "Wipe"
    static let glyphHighFive = "High five"
    static let glyphPond = "Pond"

    // Event kinds
    static let eventTried = "Tried"
    static let eventPee = "Pee"
    static let eventPoop = "Poop"
    static let eventAccident = "Accident"

    // Controls
    static let close = "Close"
    static let cancel = "Cancel"
    static let dismiss = "Dismiss"
    static let skip = "Skip this one"
    static let startNow = "Start now"
    static let reviewSettings = "Review settings"
    static let unlock = "Unlock"
    static let replayAudio = "Play again"
    static let loading = "Loading"

    // Structure
    static func stepIndicator(current: Int, total: Int) -> String { "Step \(current) of \(total)" }
    static func starCount(_ count: Int) -> String { count == 1 ? "1 star" : "\(count) stars" }
    static func progressPercent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded())) percent"
    }

    // Parent gate
    static let gateTitle = "Grown-up check"
    static let gateHoldPrompt = "Press and hold"
    static let gateHoldHint = "Keep your finger down until the ring fills."
    static let gateSumPrompt = "What is"
    static let gateSumHint = "Enter the answer, then tap Done."
    static let gateDone = "Done"
    static let gateDelete = "Delete"
    static let gateRetry = "Not quite — here is another one."
    static let gateFaceIDReason = "Confirm you are a grown-up"
    static let gateBiometricPrompt = "Confirm it's you"
    static let gateBiometricUnavailable = "Device authentication isn't available. Use the number check instead."

    // Timer card
    static let timerNextPause = "Next Potty Pause"
    static let timerPauseRunning = "Potty Pause"
    static let timerCooldown = "Taking a break"
    static let timerPaused = "Potty Pause is off"
    static let timerNeedsAttention = "Needs your attention"
    static let timerRemaining = "remaining"

    // Insight
    static let insightDisclaimerFallback = "Pattern, not medical advice."
    static func insightSample(_ count: Int, days: Int) -> String {
        "From \(count) entries across \(days) \(days == 1 ? "day" : "days")"
    }

    // Locked / paywall
    static let lockedBadge = "HopPotty Plus"

    // Errors
    static let errorTitle = "HopPotty couldn't finish that"

    // Mode selector
    static let modeSelectorLabel = "Potty Pause mode"
    static let modeGentleTitle = "Gentle"
    static let modeGentleDetail = "A reminder only. Nothing is ever blocked."
    static let modePauseTitle = "Pause"
    static let modePauseDetail = "Chosen apps pause and Hop asks about the potty."
    static let modeRoutineTitle = "Routine"
    static let modeRoutineDetail = "Chosen apps pause and Hop walks through the whole routine."
}

extension HopStrings {
    static let destructiveHint = "This cannot be undone."
}
