import SwiftUI
import HopPottyDesignTokens

// Ambient character motion: the small, continuous, non-informational movement
// that makes Hop read as alive rather than as a sticker.
//
// Every modifier below stops *entirely* under Reduce Motion — not slowed, not
// shortened. Continuous idle motion is precisely the category of animation that
// setting exists to remove, and Hop is perfectly legible standing still.
//
// ## The rule these have to obey
//
// Ambient life keeps Hop alive. It may never *perform*. Nothing here escalates
// with time, nothing gets bigger the longer a child does not tap, and nothing
// is a bid for attention — that would be an engagement mechanic aimed at a
// three-year-old, which `Docs/ChildSafety.md` §1.4 forbids outright. Every
// amplitude below is a constant, every interval is drawn from a fixed range,
// and none of them can grow.
//
// The periods are deliberately not multiples of each other. A breath of 3.4s
// against a weight shift of 9.7s against a blink somewhere in 2.8…6.5s never
// resynchronises into one visible pulse, which is what would turn three subtle
// movements into one obvious one.

/// A slow breath: the body swells and settles about the ground line.
public struct HopBreathingModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme
    @State private var inhaled = false

    private let isEnabled: Bool
    private let period: Double
    private let amplitude: CGFloat
    private let anchor: UnitPoint

    public init(
        isEnabled: Bool,
        period: Double = HopMotion.breathePeriod,
        amplitude: CGFloat = 0.016,
        anchor: UnitPoint = .bottom
    ) {
        self.isEnabled = isEnabled
        self.period = period
        self.amplitude = amplitude
        self.anchor = anchor
    }

    private var isActive: Bool { isEnabled && !theme.reduceMotion }

    public func body(content: Content) -> some View {
        content
            // Anchored at the feet so they stay planted: scaling about the
            // centre would make Hop bob, which reads as impatience. Callers who
            // know where their subject's ground line is pass it in; `.bottom`
            // is right for anything drawn to fill its frame.
            .scaleEffect(
                x: 1 + (inhaled ? amplitude * 0.55 : 0),
                y: 1 + (inhaled ? amplitude : 0),
                anchor: anchor
            )
            .animation(
                isActive ? .easeInOut(duration: period / 2).repeatForever(autoreverses: true) : nil,
                value: inhaled
            )
            .onAppear { inhaled = isActive }
            .onChange(of: isActive) { _, active in inhaled = active }
    }
}

/// A slow transfer of weight from one foot to the other.
///
/// The second half of a convincing idle, and the half that is usually missing:
/// a character that only breathes is a character being inflated. This is a
/// rotation about the *ground line*, not the centre, so it reads as leaning
/// rather than as tipping, and it is under a degree — at 190pt that moves the
/// top of Hop's head by about two points over ten seconds.
public struct HopWeightShiftModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme
    @State private var shifted = false

    private let isEnabled: Bool
    private let degrees: Double
    private let period: Double
    private let anchor: UnitPoint

    public init(
        isEnabled: Bool,
        degrees: Double = 0.75,
        period: Double = 9.7,
        anchor: UnitPoint = .bottom
    ) {
        self.isEnabled = isEnabled
        self.degrees = degrees
        self.period = period
        self.anchor = anchor
    }

    private var isActive: Bool { isEnabled && !theme.reduceMotion }

    public func body(content: Content) -> some View {
        content
            // The "off" end of the swing is upright, not the mirror of the "on"
            // end, so switching the driver off leaves Hop standing straight
            // rather than frozen mid-lean.
            .rotationEffect(.degrees(shifted ? degrees : 0), anchor: anchor)
            .animation(
                isActive ? .easeInOut(duration: period / 2).repeatForever(autoreverses: true) : nil,
                value: shifted
            )
            .onAppear { shifted = isActive }
            .onChange(of: isActive) { _, active in shifted = active }
    }
}

/// Drives a 0...1 blink phase on an irregular interval.
///
/// The interval is randomised inside ``HopMotion/blinkInterval`` because a blink
/// on a fixed beat reads as a machine — and for the same reason roughly one
/// blink in three is a *double*, which is what a real pair of eyes does and
/// which no periodic driver can produce.
///
/// The phase is a binding rather than internal state so the same driver works
/// for Hop, for an avatar, and for a pond character that has its own eye
/// geometry.
public struct HopBlinkingModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme
    @Binding private var phase: Double
    private let isEnabled: Bool

    public init(isEnabled: Bool, phase: Binding<Double>) {
        self.isEnabled = isEnabled
        self._phase = phase
    }

    private var isActive: Bool { isEnabled && !theme.reduceMotion }

    /// How often a blink is a double. Fixed: it is a property of eyes, not a
    /// dial that anything is allowed to turn up.
    private static let doubleBlinkChance = 0.32

    public func body(content: Content) -> some View {
        content.task(id: isActive) {
            guard isActive else {
                // Leave the eyes open when the driver stops, whatever the phase
                // was mid-blink.
                phase = 0
                return
            }
            while !Task.isCancelled {
                let wait = Double.random(in: HopMotion.blinkInterval)
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled else { return }

                await blink()
                guard !Task.isCancelled else { return }

                if Double.random(in: 0...1) < HopBlinkingModifier.doubleBlinkChance {
                    // The gap inside a double blink is shorter than the blink
                    // itself; any longer and it reads as two blinks.
                    try? await Task.sleep(for: .seconds(HopMotion.blinkDuration * 0.6))
                    guard !Task.isCancelled else { return }
                    await blink()
                }
            }
        }
    }

    /// One shut-and-open. There is no motion token for a blink — it is a
    /// property of the drawing rather than a UI transition — so it names its
    /// own easing, guarded by `isActive`, which is already false under Reduce
    /// Motion.
    private func blink() async {
        withAnimation(.easeIn(duration: HopMotion.blinkDuration)) { phase = 1 }
        try? await Task.sleep(for: .seconds(HopMotion.blinkDuration))
        guard !Task.isCancelled else {
            phase = 0
            return
        }
        withAnimation(.easeOut(duration: HopMotion.blinkDuration)) { phase = 0 }
        try? await Task.sleep(for: .seconds(HopMotion.blinkDuration))
    }
}

/// Occasional micro-settles: a glance away and back, a couple of reference
/// units at most.
///
/// This is the third layer of an idle, after the breath and the weight shift,
/// and the one that stops a still character reading as *paused*. It drives an
/// eye offset rather than the body, because at the sizes Hop is drawn a body
/// movement small enough to be tasteful is too small to see, and an eye
/// movement that size is not.
///
/// Fixed amplitude, fixed interval range, no memory of how long anyone has been
/// looking. It cannot build, and it cannot ask for anything.
public struct HopMicroSettleModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme
    @Binding private var offset: CGSize
    private let isEnabled: Bool
    private let interval: ClosedRange<Double>
    private let reach: CGFloat

    public init(
        isEnabled: Bool,
        offset: Binding<CGSize>,
        interval: ClosedRange<Double> = 6.5...13.0,
        reach: CGFloat = 1.6
    ) {
        self.isEnabled = isEnabled
        self._offset = offset
        self.interval = interval
        self.reach = reach
    }

    private var isActive: Bool { isEnabled && !theme.reduceMotion }

    public func body(content: Content) -> some View {
        content.task(id: isActive) {
            guard isActive else {
                offset = .zero
                return
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: interval)))
                guard !Task.isCancelled else { return }

                let target = CGSize(
                    width: CGFloat.random(in: -reach...reach),
                    height: CGFloat.random(in: (-reach * 0.6)...(reach * 0.6))
                )
                withAnimation(.easeInOut(duration: 0.9)) { offset = target }
                try? await Task.sleep(for: .seconds(Double.random(in: 1.1...2.4)))
                guard !Task.isCancelled else {
                    offset = .zero
                    return
                }
                withAnimation(.easeInOut(duration: 1.1)) { offset = .zero }
                try? await Task.sleep(for: .seconds(1.1))
            }
        }
    }
}

/// A gentle float, for things that hang rather than stand — a star arriving, a
/// speech bubble waiting to be read.
public struct HopFloatingModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme
    @State private var raised = false

    private let isEnabled: Bool
    private let distance: CGFloat
    private let period: Double

    public init(isEnabled: Bool, distance: CGFloat = 5, period: Double = 4.2) {
        self.isEnabled = isEnabled
        self.distance = distance
        self.period = period
    }

    private var isActive: Bool { isEnabled && !theme.reduceMotion }

    public func body(content: Content) -> some View {
        content
            .offset(y: raised ? -distance : 0)
            .animation(
                isActive ? .easeInOut(duration: period / 2).repeatForever(autoreverses: true) : nil,
                value: raised
            )
            .onAppear { raised = isActive }
            .onChange(of: isActive) { _, active in raised = active }
    }
}

public extension View {
    /// A slow breath. No-op under Reduce Motion.
    func hopBreathing(
        _ isEnabled: Bool = true,
        period: Double = HopMotion.breathePeriod,
        amplitude: CGFloat = 0.016,
        anchor: UnitPoint = .bottom
    ) -> some View {
        modifier(HopBreathingModifier(isEnabled: isEnabled, period: period, amplitude: amplitude, anchor: anchor))
    }

    /// A slow transfer of weight. No-op under Reduce Motion.
    func hopWeightShift(
        _ isEnabled: Bool = true,
        degrees: Double = 0.75,
        period: Double = 9.7,
        anchor: UnitPoint = .bottom
    ) -> some View {
        modifier(HopWeightShiftModifier(isEnabled: isEnabled, degrees: degrees, period: period, anchor: anchor))
    }

    /// Drives an irregular blink into `phase`. No-op under Reduce Motion.
    func hopBlinking(_ isEnabled: Bool = true, phase: Binding<Double>) -> some View {
        modifier(HopBlinkingModifier(isEnabled: isEnabled, phase: phase))
    }

    /// Drives an occasional glance away and back into `offset`, in reference
    /// units. No-op under Reduce Motion.
    func hopMicroSettle(_ isEnabled: Bool = true, offset: Binding<CGSize>) -> some View {
        modifier(HopMicroSettleModifier(isEnabled: isEnabled, offset: offset))
    }

    /// A gentle vertical float. No-op under Reduce Motion.
    func hopFloating(_ isEnabled: Bool = true, distance: CGFloat = 5, period: Double = 4.2) -> some View {
        modifier(HopFloatingModifier(isEnabled: isEnabled, distance: distance, period: period))
    }
}
