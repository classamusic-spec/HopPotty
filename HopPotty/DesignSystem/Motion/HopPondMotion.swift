import Foundation
import SwiftUI
import HopPottyDesignTokens

// Pond ambience: the slow, continuous, non-informational movement that makes a
// drawn pond read as *water* rather than as a picture of water.
//
// This file is the pond's counterpart to `HopAmbientMotion.swift`, which owns
// Hop's own idle. The two are deliberately separate because they solve
// different problems: Hop is one character with two effects, while the pond is
// a dozen layers that must never line up into a single visible pulse.
//
// **Everything here stops entirely under Reduce Motion** — not slowed, not
// shortened — and leaves the pond at its authored, still, correct arrangement.
// Continuous ambient motion is exactly the category that setting exists to
// remove, and a still pond is a perfectly good pond.
//
// **Nothing here is a reward and nothing here asks for a tap.** The pond on the
// parent's Home screen sits behind a countdown a caregiver is reading; the pond
// on the reward screen is scenery the child already owns. Motion that made
// either worth watching would be a bug, not a feature. `Docs/ChildSafety.md`.

// MARK: - Amplitudes

/// How far each pond layer is allowed to travel, and how often the clock ticks.
///
/// Periods live in ``HopMotion`` (the `pond*` group) because they are shared
/// design tokens; the amplitudes live here because they are properties of *this*
/// drawing. Together they set the only number that actually matters for
/// "gentle": peak speed, which is `2π × amplitude / period`. Every value below
/// is chosen to keep that under roughly 8 pt/s at the pond's 393pt reference
/// width — slow enough that the eye reads drift rather than movement.
public enum HopPondMotion {
    /// The pond's frame budget. Ambient motion this slow moves a fraction of a
    /// point per frame, so 30fps is indistinguishable from 60 and costs half as
    /// much on a screen the app spends most of its life on.
    public static let frameInterval: Double = 1.0 / 30.0

    // Reference amplitudes, in points at a 393pt-wide pond. Callers scale them
    // by the same `unit` the drawing scales its ornaments by.

    /// `pond-ripples` — how far a surface ripple slides, and how far it lifts.
    public static let rippleDrift: CGFloat = 6
    public static let rippleLift: CGFloat = 1.2
    /// `pond-clouds` — a bounded drift, never a traverse. A cloud that crosses
    /// the sky has to enter and leave, and something appearing at the edge of a
    /// background is precisely the thing that catches an eye reading a timer.
    public static let cloudDrift: CGFloat = 16
    /// `pond-shimmer` — travel as a fraction of the pond's width, and the peak
    /// opacity of the light itself. Low enough that the brightest point of the
    /// sheen changes by 5% of white over four and a half seconds.
    public static let shimmerTravel: CGFloat = 0.045
    public static let shimmerOpacity: Double = 0.055
    /// `pond-fish` — a long flat loop rather than a pass off-screen, so the fish
    /// is always where the still pond puts it.
    public static let fishTravel: CGFloat = 16
    public static let fishLift: CGFloat = 4
    /// `pond-dragonfly` — the flitting arc, and the wing angle that goes with it.
    public static let flitTravel: CGFloat = 10
    public static let flitLift: CGFloat = 5
    public static let flitWingDegrees: Double = 3
    /// `pond-lily-N` — how far a pad rocks about its own centre while it bobs.
    public static let lilyRollDegrees: Double = 1.2
    /// A blossom stirring on the water. Rotation only; a flower that slid would
    /// look like it had come loose.
    public static let blossomStirDegrees: Double = 1.6

    /// A phase offset, in turns, for the item at `index`.
    ///
    /// Golden-ratio spacing: consecutive indices land as far apart on the cycle
    /// as it is possible for them to be, and no two of any practical number of
    /// them coincide. That is the same property the `pond*` periods have between
    /// layers — nothing resynchronises — applied *within* a layer, so three
    /// lily pads bob independently rather than as one raft.
    public static func phase(_ index: Int) -> Double {
        let turns = Double(index) * 0.6180339887498949
        return turns - turns.rounded(.down)
    }
}

// MARK: - The clock

/// One pond's sense of time, sampled once per frame and handed to every layer.
///
/// A value type rather than a driver: the pond has exactly one clock, so there
/// is one `TimelineView` for a dozen moving things instead of a dozen timers.
/// Layers ask it for a phase and get back a plain number.
///
/// ``isLive`` is the whole Reduce Motion story. When it is `false` every
/// accessor returns its neutral value, which puts every layer back at the
/// position the drawing authored — so the still pond is not "the pond frozen
/// mid-wobble", it is the pond as drawn.
public struct HopPondClock: Equatable, Sendable {
    /// Seconds of *animated* time. Time spent off-screen, backgrounded or under
    /// Reduce Motion is not counted, so the pond resumes where it left off
    /// rather than jumping forward by however long the app was away.
    public let seconds: Double
    /// Whether phases advance at all.
    public let isLive: Bool

    public init(seconds: Double, isLive: Bool) {
        self.seconds = seconds
        self.isLive = isLive
    }

    /// The pond at rest: every layer at its authored place.
    public static let still = HopPondClock(seconds: 0, isLive: false)

    /// A sine over `period` seconds, offset by `phase` turns. `-1...1`, and
    /// exactly `0` at rest — which is what lets an amplitude be added to an
    /// authored coordinate without moving the still drawing.
    public func wave(period: Double, phase: Double = 0) -> Double {
        guard isLive, period > 0 else { return 0 }
        return sin((seconds / period + phase) * 2 * .pi)
    }

    /// The quadrature partner of ``wave(period:phase:)``: `-1...0`, also exactly
    /// `0` at rest. Pairing the two traces a shallow ellipse — a fish's loop, a
    /// butterfly's arc — that always passes back through the authored point.
    public func rise(period: Double, phase: Double = 0) -> Double {
        guard isLive, period > 0 else { return 0 }
        return (cos((seconds / period + phase) * 2 * .pi) - 1) / 2
    }
}

// MARK: - The time base

/// Runs one clock for a whole pond, and stops it whenever nobody can see it.
///
/// Three things pause the clock, and all three matter for a screen the app
/// spends most of its life on:
///
/// - **Reduce Motion.** The pond goes still and stays still.
/// - **Off screen.** `onDisappear` — a pushed detail screen, a full-screen
///   cover, a dismissed tab — stops the ticking rather than animating behind
///   the thing on top of it.
/// - **Not `.active`.** The app switcher, Control Centre and the background all
///   stop it. Nothing animates while a caregiver is somewhere else.
///
/// While paused the `TimelineView` requests no updates at all, so the cost of a
/// paused pond is the cost of a static drawing.
public struct HopPondTimeline<Content: View>: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    @State private var isOnScreen = false
    /// Animated seconds banked before the current pause.
    @State private var settled: Double = 0
    /// When the current run started, or `nil` while paused.
    @State private var resumedAt: Date?

    private let interval: Double
    private let content: (HopPondClock) -> Content

    public init(
        interval: Double = HopPondMotion.frameInterval,
        @ViewBuilder content: @escaping (HopPondClock) -> Content
    ) {
        self.interval = interval
        self.content = content
    }

    private var isRunning: Bool {
        isOnScreen && scenePhase == .active && !theme.reduceMotion
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: interval, paused: !isRunning)) { timeline in
            content(clock(at: timeline.date))
        }
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
        .onChange(of: isRunning, initial: true) { _, running in
            if running {
                resumedAt = Date.now
            } else {
                if let resumedAt {
                    settled += max(0, Date.now.timeIntervalSince(resumedAt))
                }
                resumedAt = nil
            }
        }
    }

    private func clock(at date: Date) -> HopPondClock {
        // Reduce Motion is the only case that rewinds. A pause for any other
        // reason holds the pond exactly where it was, so coming back from the
        // app switcher does not snap every layer to a new position.
        guard !theme.reduceMotion else { return .still }
        guard let resumedAt else {
            // Paused. Before the clock has ever run — the frame between the
            // first layout and `onAppear` — there is no phase to hold, so the
            // pond draws exactly as authored rather than at a phase offset.
            return settled > 0 ? HopPondClock(seconds: settled, isLive: true) : .still
        }
        return HopPondClock(
            seconds: settled + max(0, date.timeIntervalSince(resumedAt)),
            isLive: true
        )
    }
}

// MARK: - Idle motion for a drawn decoration

/// What a pond decoration does when nothing is happening.
///
/// Four answers, because a pond has four kinds of thing in it: what floats, what
/// is rooted, what is airborne, and what was built or dropped there and stays
/// put. A stone that swayed would be wrong in a way a child would notice before
/// an adult did.
public enum HopPondIdle: Equatable, Sendable {
    /// Built, dropped or resting. Does not move.
    case still
    /// Afloat: rises and settles, with a whisper of roll a beat behind.
    case bob
    /// Rooted: rocks about its own base, like a reed in moving air.
    case sway
    /// Airborne: floats, with a slow lateral drift.
    case drift
}

/// Applies a decoration's idle.
///
/// Declarative rather than clock-driven on purpose. The reward pond is up to
/// forty-one separate image views, and re-evaluating all of them every frame to
/// nudge each by a fraction of a point would be a poor trade; a repeating
/// `Animation` hands the whole job to the render server, where it costs nothing
/// per frame and pauses by itself when the app is not on screen.
public struct HopPondIdleModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var advanced = false

    private let idle: HopPondIdle
    /// The decoration's drawn size, so amplitudes stay proportionate to it and
    /// a duckling does not travel as far as a blossom tree.
    private let extent: CGFloat
    /// 0...1 turns. Staggers this decoration against its neighbours.
    private let phase: Double

    public init(idle: HopPondIdle, extent: CGFloat, phase: Double) {
        self.idle = idle
        self.extent = extent
        self.phase = phase
    }

    private var isActive: Bool {
        idle != .still && !theme.reduceMotion && scenePhase == .active
    }

    private var period: Double {
        switch idle {
        case .still: 1
        case .bob: HopMotion.pondLilyBobPeriod
        case .sway: HopMotion.pondReedSwayPeriod
        case .drift: HopMotion.pondDragonflyPeriod
        }
    }

    /// 0 at the authored position, 1 at the far end of the cycle.
    private var travel: CGFloat { advanced ? 1 : 0 }

    /// Rises never go below the authored place: a duckling that bobbed *down*
    /// would sink into whatever it is sitting on.
    private var offsetY: CGFloat {
        switch idle {
        case .still: 0
        case .bob: -min(HopMotion.pondBobDistance, extent * 0.07) * travel
        case .sway: 0
        case .drift: -min(HopMotion.pondBobDistance * 1.4, extent * 0.06) * travel
        }
    }

    private var offsetX: CGFloat {
        guard idle == .drift else { return 0 }
        return min(HopMotion.pondBobDistance, extent * 0.05) * (travel * 2 - 1)
    }

    private var degrees: Double {
        let swing = Double(travel) * 2 - 1
        switch idle {
        case .still: return 0
        case .bob: return HopMotion.pondSwayDegrees * 0.5 * swing
        case .sway: return HopMotion.pondSwayDegrees * swing
        case .drift: return HopMotion.pondSwayDegrees * 0.4 * swing
        }
    }

    /// A rooted thing pivots at its base; anything else about its middle.
    private var anchor: UnitPoint { idle == .sway ? .bottom : .center }

    private var idleAnimation: Animation? {
        guard isActive else { return nil }
        return .easeInOut(duration: period / 2)
            .repeatForever(autoreverses: true)
            .delay(phase * period)
    }

    public func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(degrees), anchor: anchor)
            .offset(x: offsetX, y: offsetY)
            .animation(idleAnimation, value: advanced)
            .onAppear { advanced = isActive }
            .onChange(of: isActive) { _, active in advanced = active }
    }
}

public extension View {
    /// A pond decoration's idle. No-op under Reduce Motion, and while the app is
    /// not the active scene.
    func hopPondIdle(_ idle: HopPondIdle, extent: CGFloat, phase: Double = 0) -> some View {
        modifier(HopPondIdleModifier(idle: idle, extent: extent, phase: phase))
    }
}
