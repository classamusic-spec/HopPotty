import SwiftUI
import HopPottyCore

/// The calm ring that fills while a step is running.
///
/// Two rules make it calm rather than pressuring:
///
/// 1. **It fills; it never drains.** A shape that empties is a countdown, and a
///    countdown in a bathroom is the exact feeling this product exists to
///    remove. Something growing is something being made.
/// 2. **Nothing is gated on it.** The child can answer, advance or leave at any
///    fraction. Reaching 1.0 changes nothing except that the ring is full.
///
/// There is no implicit animation on the fill: the fraction is redrawn from the
/// model's elapsed time on every tick, the way a clock face is redrawn. That is
/// a state readout, not an animation, so it stays correct and legible under
/// Reduce Motion without a substitute path. The only decorative movement here
/// is the slow breath, which the design system's ambient layer already stops.
struct RoutineTimerRing: View {
    @Environment(\.hopTheme) private var theme

    /// 0...1. Clamped by the model, clamped again here so a preview cannot draw
    /// a ring past full.
    let fraction: Double
    let diameter: CGFloat
    /// Shown under the ring. `nil` where the step's own instruction already says
    /// everything — the wash step's ring needs no second sentence.
    let caption: String?

    private var clamped: Double { min(1, max(0, fraction)) }

    private var lineWidth: CGFloat { max(10, diameter * 0.085) }

    var body: some View {
        VStack(spacing: theme.spacing.m) {
            ZStack {
                Circle()
                    .stroke(theme.color.surfaceSunken, lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(
                        theme.color.brandAction,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    // Starts at the top and grows clockwise, which is the
                    // direction a three-year-old has already seen on every
                    // clock, timer and loading ring in their house.
                    .rotationEffect(.degrees(-90))

                // A soft centre so the ring reads as a filling vessel rather
                // than a gauge with an empty hole in it.
                Circle()
                    .fill(HopColors.wash(theme.color.brandAction, isDark: theme.isDark))
                    .padding(lineWidth * 1.6)
            }
            .frame(width: diameter, height: diameter)
            .hopBreathing(amplitude: 0.010)
            .accessibilityElement()
            .accessibilityLabel(caption ?? HopCopy.routine.sitTimerCaption.localized)
            .accessibilityValue(HopStrings.progressPercent(clamped))

            if let caption {
                Text(caption)
                    .hopTextStyle(.childInstruction)
                    .foregroundStyle(theme.color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    // The ring above already announces this as its label; a
                    // second reading of the same sentence is noise.
                    .accessibilityHidden(true)
            }
        }
    }
}

/// Drives a timed step's ring from a display-linked ticker.
///
/// The ticker lives in the view rather than the model so the model stays a
/// plain value a preview can place at any position without waiting, and so a
/// backgrounded routine is not burning a timer.
struct RoutineTimerTicker: ViewModifier {
    let isRunning: Bool
    let onTick: (TimeInterval) -> Void

    /// Ten a second: fine enough that the ring reads as continuous, coarse
    /// enough that it costs nothing.
    private static let interval: TimeInterval = 0.1

    func body(content: Content) -> some View {
        content.task(id: isRunning) {
            guard isRunning else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.interval))
                guard !Task.isCancelled else { return }
                onTick(Self.interval)
            }
        }
    }
}

extension View {
    /// Ticks a timed routine step while `isRunning`.
    func routineTicker(isRunning: Bool, onTick: @escaping (TimeInterval) -> Void) -> some View {
        modifier(RoutineTimerTicker(isRunning: isRunning, onTick: onTick))
    }
}

#Preview("Timer ring · sit timer part-way") {
    RoutineTimerRing(
        fraction: 0.42,
        diameter: 220,
        caption: HopCopy.routine.sitTimerCaption.localized
    )
    .padding()
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Timer ring · wash step, nearly full") {
    RoutineTimerRing(fraction: 0.86, diameter: 180, caption: nil)
        .padding()
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Timer ring · Reduce Motion") {
    RoutineTimerRing(
        fraction: 0.42,
        diameter: 220,
        caption: HopCopy.routine.sitTimerCaption.localized
    )
    .padding()
    .hopBackground()
    .hopThemedRoot(reduceMotion: true)
}
