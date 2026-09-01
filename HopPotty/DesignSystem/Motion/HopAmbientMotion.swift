import SwiftUI
import HopPottyDesignTokens

// Ambient character motion: the small, continuous, non-informational movement
// that makes Hop read as alive rather than as a sticker.
//
// Both modifiers below stop *entirely* under Reduce Motion — not slowed, not
// shortened. Continuous idle motion is precisely the category of animation that
// setting exists to remove, and Hop is perfectly legible standing still.

/// A slow breath: the body swells and settles about the ground line.
public struct HopBreathingModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme
    @State private var inhaled = false

    private let isEnabled: Bool
    private let period: Double
    private let amplitude: CGFloat

    public init(
        isEnabled: Bool,
        period: Double = HopMotion.breathePeriod,
        amplitude: CGFloat = 0.016
    ) {
        self.isEnabled = isEnabled
        self.period = period
        self.amplitude = amplitude
    }

    private var isActive: Bool { isEnabled && !theme.reduceMotion }

    public func body(content: Content) -> some View {
        content
            // Anchored at the bottom so the feet stay planted: scaling about the
            // centre would make Hop bob, which reads as impatience.
            .scaleEffect(
                x: 1 + (inhaled ? amplitude * 0.55 : 0),
                y: 1 + (inhaled ? amplitude : 0),
                anchor: .bottom
            )
            .animation(
                isActive ? .easeInOut(duration: period / 2).repeatForever(autoreverses: true) : nil,
                value: inhaled
            )
            .onAppear { inhaled = isActive }
            .onChange(of: isActive) { _, active in inhaled = active }
    }
}

/// Drives a 0...1 blink phase on an irregular interval.
///
/// The interval is randomised inside ``HopMotion/blinkInterval`` because a blink
/// on a fixed beat reads as a machine. The phase is a binding rather than
/// internal state so the same driver works for Hop, for an avatar, and for a
/// pond character that has its own eye geometry.
public struct HopBlinkingModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme
    @Binding private var phase: Double
    private let isEnabled: Bool

    public init(isEnabled: Bool, phase: Binding<Double>) {
        self.isEnabled = isEnabled
        self._phase = phase
    }

    private var isActive: Bool { isEnabled && !theme.reduceMotion }

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

                withAnimation(.easeIn(duration: HopMotion.blinkDuration)) { phase = 1 }
                try? await Task.sleep(for: .seconds(HopMotion.blinkDuration))
                guard !Task.isCancelled else { return }

                withAnimation(.easeOut(duration: HopMotion.blinkDuration)) { phase = 0 }
                try? await Task.sleep(for: .seconds(HopMotion.blinkDuration))
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
    func hopBreathing(_ isEnabled: Bool = true, period: Double = HopMotion.breathePeriod, amplitude: CGFloat = 0.016) -> some View {
        modifier(HopBreathingModifier(isEnabled: isEnabled, period: period, amplitude: amplitude))
    }

    /// Drives an irregular blink into `phase`. No-op under Reduce Motion.
    func hopBlinking(_ isEnabled: Bool = true, phase: Binding<Double>) -> some View {
        modifier(HopBlinkingModifier(isEnabled: isEnabled, phase: phase))
    }

    /// A gentle vertical float. No-op under Reduce Motion.
    func hopFloating(_ isEnabled: Bool = true, distance: CGFloat = 5, period: Double = 4.2) -> some View {
        modifier(HopFloatingModifier(isEnabled: isEnabled, distance: distance, period: period))
    }
}
