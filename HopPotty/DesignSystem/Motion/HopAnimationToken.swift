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

    /// The underlying spring token.
    public var spring: HopSpring {
        switch self {
        case .parentTap: HopMotion.parentTap
        case .parentTransition: HopMotion.parentTransition
        case .parentSheet: HopMotion.parentSheet
        case .childTap: HopMotion.childTap
        case .childArrive: HopMotion.childArrive
        case .childCelebrate: HopMotion.childCelebrate
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
