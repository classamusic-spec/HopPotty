import SwiftUI
import HopPottyDesignTokens

/// HopPotty's motion vocabulary, as a closed set of tokens.
///
/// Feature code never writes `.spring(...)` and never writes
/// `if reduceMotion`. It asks the theme for a token and gets back an animation
/// that is already correct for the current accessibility settings. That is the
/// whole design: **there is exactly one `accessibilityReduceMotion` reader in
/// the app** (``HopThemedRoot``), it puts the answer on ``HopTheme``, and this
/// file is the only thing that acts on it.
///
/// Everything that moves routes through here, including the richer page
/// transitions in `HopTransitions.swift` (which pass their hand-built
/// `AnyTransition`s through ``HopAnimationToken/guarded(_:reduceMotion:)``) and
/// the press feel in ``HopPressFeel``. Adding a new kind of movement means
/// adding it to this file, not adding a second place that knows what Reduce
/// Motion means.
public enum HopAnimationToken: String, CaseIterable, Sendable {
    // Parent — quick, nearly flat, indistinguishable from the OS.
    case parentTap
    case parentTransition
    case parentSheet

    // Child — bouncier, because the motion is doing narrative work for someone
    // who cannot read the label.
    case childTap
    case childArrive
    case childCelebrate

    // Surfaces under a finger. Two tokens, not one: the press has no bounce at
    // all (a finger going down is not springy), and the bounce belongs to the
    // release, where it reads as the surface coming back up to meet you.
    case press
    case release

    // Whole-screen changes.
    /// A parent forward/back navigation. Fast, almost flat, iOS-like.
    case pagePush
    /// A child-facing screen change. Slower and springier, because for a
    /// pre-reader the movement *is* the explanation of what just happened.
    case childPage

    /// The underlying spring token.
    public var spring: HopSpring {
        switch self {
        case .parentTap: HopMotion.parentTap
        case .parentTransition: HopMotion.parentTransition
        case .parentSheet: HopMotion.parentSheet
        case .childTap: HopMotion.childTap
        case .childArrive: HopMotion.childArrive
        case .childCelebrate: HopMotion.childCelebrate
        case .press: HopMotion.press
        case .release: HopMotion.release
        case .pagePush: HopMotion.pagePush
        case .childPage: HopMotion.childPage
        }
    }

    /// The animation to use. Under Reduce Motion every spring — parent and
    /// child alike — becomes the same short cross-fade, so a state change is
    /// still legible but nothing travels across the screen.
    public func animation(reduceMotion: Bool) -> Animation {
        guard !reduceMotion else {
            return .easeInOut(duration: HopMotion.reducedMotionFade)
        }
        return .spring(duration: spring.duration, bounce: spring.bounce)
    }

    /// The token's animation, delayed by the stagger for `index`.
    ///
    /// The delay is dropped entirely under Reduce Motion: a list that dribbles
    /// in is movement, even when each item only fades.
    public func animation(reduceMotion: Bool, index: Int) -> Animation {
        animation(reduceMotion: reduceMotion)
            .delay(Self.stagger(index: index, reduceMotion: reduceMotion))
    }

    /// The matching transition. Movement and scale are replaced by opacity,
    /// never merely shortened: a fast slide is still a slide.
    public func transition(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        switch self {
        case .parentTap, .parentTransition:
            return .opacity.combined(with: .offset(y: 6))
        case .parentSheet:
            return .move(edge: .bottom).combined(with: .opacity)
        case .childTap:
            return .scale(scale: 0.94).combined(with: .opacity)
        case .childArrive:
            return .scale(scale: 0.72).combined(with: .opacity)
        case .childCelebrate:
            return .scale(scale: 0.55).combined(with: .opacity)
        case .press, .release:
            return .scale(scale: HopMotion.pressScale).combined(with: .opacity)
        case .pagePush:
            return .move(edge: .trailing).combined(with: .opacity)
        case .childPage:
            return .scale(scale: 0.88).combined(with: .opacity)
        }
    }

    /// How long the animation actually takes, for code that has to sequence
    /// around it.
    public func duration(reduceMotion: Bool) -> Double {
        reduceMotion ? HopMotion.reducedMotionFade : spring.duration
    }

    /// Staggered arrival delay for the item at `index`, zeroed under Reduce
    /// Motion so a list appears at once rather than dribbling in.
    public static func stagger(index: Int, reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : HopMotion.stagger(index: index)
    }
}

// MARK: - The Reduce Motion gate, for motion this enum cannot express

public extension HopAnimationToken {
    /// Wraps a hand-built transition in the Reduce Motion guarantee.
    ///
    /// The page transitions in `HopTransitions.swift` are richer than any single
    /// token — a push is an asymmetric pair with parallax on the outgoing half —
    /// so they cannot be a `case` here. They pass through this instead, which
    /// keeps the substitution in one file rather than one per transition.
    static func guarded(_ transition: AnyTransition, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : transition
    }

    /// Whether an effect that moves a thing *from one place to another* — a
    /// parallax layer, a matched-geometry selection, a sliding highlight — may
    /// run at all.
    ///
    /// These cannot be softened into a cross-fade by shortening them, so the
    /// answer is a yes/no rather than a different animation.
    static func allowsTravel(reduceMotion: Bool) -> Bool { !reduceMotion }

    /// Digits roll when a number changes; under Reduce Motion they cross-fade,
    /// because a rolling digit is movement however small the cell is.
    static func numericContentTransition(reduceMotion: Bool) -> ContentTransition {
        reduceMotion ? .opacity : .numericText()
    }
}

// MARK: - Press feel

/// How a surface behaves under a finger.
///
/// Three things happen, and they are deliberately not simultaneous:
///
/// 1. the **surface** sinks immediately, with no bounce — a finger going down
///    is not springy;
/// 2. its **shadow softens** toward the ground, because a thing pressed into a
///    page casts less shadow, and a shadow that merely vanishes reads as a bug;
/// 3. the **label settles a beat after the surface** on the way back up, which
///    is the whole difference between a control that scales and a control that
///    has a front face and a body.
///
/// Under Reduce Motion none of the geometry moves at all. The press is still
/// confirmed — the button styles draw a pressed tint over the fill — so a
/// caregiver who cannot use motion still gets feedback, it just does not travel.
public struct HopPressFeel: Equatable, Sendable {
    /// How far the whole surface sinks.
    public let surfaceScale: CGFloat
    /// How far the label sinks. Always less than the surface: the label is
    /// printed *on* the front face, so it moves with it but not as far.
    public let labelScale: CGFloat
    /// How long the label lags the surface on release, in seconds.
    public let labelSettle: Double
    /// How much of the resting shadow is given up while held, 0...1.
    public let elevationSoftening: Double
    /// The spring on the way down.
    public let pressToken: HopAnimationToken
    /// The spring on the way back up.
    public let releaseToken: HopAnimationToken

    public init(
        surfaceScale: CGFloat,
        labelScale: CGFloat,
        labelSettle: Double,
        elevationSoftening: Double,
        pressToken: HopAnimationToken,
        releaseToken: HopAnimationToken
    ) {
        self.surfaceScale = surfaceScale
        self.labelScale = labelScale
        self.labelSettle = labelSettle
        self.elevationSoftening = elevationSoftening
        self.pressToken = pressToken
        self.releaseToken = releaseToken
    }

    /// A caregiver's control. Releases on ``HopAnimationToken/parentTap``
    /// rather than ``HopAnimationToken/release``: a settings button that boings
    /// is a settings button that does not feel like iOS.
    public static let parent = HopPressFeel(
        surfaceScale: HopMotion.pressScale,
        labelScale: 0.99,
        labelSettle: 0.04,
        elevationSoftening: 0.45,
        pressToken: .press,
        releaseToken: .parentTap
    )

    /// A child's control. Squashes further — the feedback has to be readable
    /// from a metre away, at arm's length, by someone who is not looking
    /// straight at it — and takes the full bouncy release.
    public static let child = HopPressFeel(
        surfaceScale: HopMotion.childPressScale,
        labelScale: 0.97,
        labelSettle: 0.07,
        elevationSoftening: 0.60,
        pressToken: .press,
        releaseToken: .release
    )

    /// A borderless control. Nothing to sink into, so it shrinks and dims a
    /// little instead, and has no separate label layer to settle.
    public static let bare = HopPressFeel(
        surfaceScale: 0.92,
        labelScale: 1,
        labelSettle: 0,
        elevationSoftening: 0,
        pressToken: .press,
        releaseToken: .parentTap
    )

    /// A whole card pressed as one object. Barely moves — a dashboard card that
    /// squashes like a button reads as a toy — but it does move.
    public static let surface = HopPressFeel(
        surfaceScale: 0.985,
        labelScale: 1,
        labelSettle: 0,
        elevationSoftening: 0.5,
        pressToken: .press,
        releaseToken: .parentTap
    )

    /// The scale of the surface right now.
    public func scale(isPressed: Bool, reduceMotion: Bool) -> CGFloat {
        guard isPressed, !reduceMotion else { return 1 }
        return surfaceScale
    }

    /// The scale of the label right now.
    public func labelScale(isPressed: Bool, reduceMotion: Bool) -> CGFloat {
        guard isPressed, !reduceMotion else { return 1 }
        return labelScale
    }

    /// The elevation a surface resting at `level` should draw while held.
    public func elevation(_ level: HopElevation, isPressed: Bool, reduceMotion: Bool) -> HopElevation {
        // Under Reduce Motion the shadow is left alone as well. A shadow
        // shrinking is a thing moving; it is just moving in z.
        guard isPressed, !reduceMotion else { return level }
        return level.hopSoftened(by: elevationSoftening)
    }

    /// The spring for the direction the finger is going.
    public func animation(isPressed: Bool, reduceMotion: Bool) -> Animation {
        (isPressed ? pressToken : releaseToken).animation(reduceMotion: reduceMotion)
    }

    /// The label's spring: the same one, delayed on the way back up only.
    ///
    /// Never delayed on the way *down* — a label that lags into a press reads
    /// as the app being slow, which is the opposite of the intended effect.
    public func labelAnimation(isPressed: Bool, reduceMotion: Bool) -> Animation {
        let base = animation(isPressed: isPressed, reduceMotion: reduceMotion)
        guard !isPressed, !reduceMotion, labelSettle > 0 else { return base }
        return base.delay(labelSettle)
    }
}

public extension HopElevation {
    /// A softened copy of this step, for a surface pressed toward its ground.
    ///
    /// Softened rather than swapped for ``HopElevation/flat``: swapping to a
    /// zero radius crosses the branch in ``HopElevationModifier`` where the
    /// shadow stops being drawn at all, and a modifier that appears and
    /// disappears cannot be animated — it snaps. This only ever scales the
    /// numbers, and a surface that is already flat stays exactly flat.
    func hopSoftened(by amount: Double) -> HopElevation {
        guard radius > 0, amount > 0 else { return self }
        let keep = max(0.2, 1 - min(1, amount))
        return HopElevation(
            radius: radius * keep,
            yOffset: yOffset * keep,
            opacityScale: opacityScale * keep
        )
    }
}

// MARK: - Press state, published downward

private struct HopIsPressedKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Whether the enclosing HopPotty control is being held down right now.
    ///
    /// `ButtonStyle` owns the press state but the label is built by the caller,
    /// so without this there is no way for a chevron, an icon or a badge to
    /// react to a press on the row it sits in. Every HopPotty button style
    /// publishes it; nothing else should write it.
    var hopIsPressed: Bool {
        get { self[HopIsPressedKey.self] }
        set { self[HopIsPressedKey.self] = newValue }
    }
}

// MARK: - View sugar

public extension View {
    /// Animates a value change with a motion token.
    ///
    /// Prefer this to `.animation(_:value:)` with a hand-written spring: it is
    /// the form that cannot forget Reduce Motion.
    func hopAnimation<V: Equatable>(_ token: HopAnimationToken, value: V) -> some View {
        modifier(HopAnimationModifier(token: token, value: value))
    }

    /// Applies a token's transition on insertion and removal.
    func hopTransition(_ token: HopAnimationToken) -> some View {
        modifier(HopTransitionModifier(token: token))
    }

    /// Rolls digits when the number under them changes, and cross-fades them
    /// instead under Reduce Motion.
    ///
    /// Pair with ``View/hopAnimation(_:value:)`` on the same value, or the
    /// content transition has no transaction to run inside.
    func hopNumericTransition() -> some View {
        modifier(HopNumericTransitionModifier())
    }
}

public struct HopAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.hopTheme) private var theme
    let token: HopAnimationToken
    let value: V

    public func body(content: Content) -> some View {
        content.animation(theme.animation(token), value: value)
    }
}

public struct HopTransitionModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme
    let token: HopAnimationToken

    public func body(content: Content) -> some View {
        content.transition(theme.transition(token))
    }
}

public struct HopNumericTransitionModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme

    public func body(content: Content) -> some View {
        content.contentTransition(
            HopAnimationToken.numericContentTransition(reduceMotion: theme.reduceMotion)
        )
    }
}

/// Runs `body` inside the token's animation.
///
/// The imperative counterpart to ``View/hopAnimation(_:value:)``, for the cases
/// where the change is made in an action rather than derived from state.
@MainActor
public func withHopAnimation<Result>(
    _ token: HopAnimationToken,
    theme: HopTheme,
    _ body: () throws -> Result
) rethrows -> Result {
    try withAnimation(theme.animation(token), body)
}
