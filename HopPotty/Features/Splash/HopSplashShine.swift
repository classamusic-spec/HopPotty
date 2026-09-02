import SwiftUI
import HopPottyDesignTokens

/// The light behind the lockup on the splash.
///
/// Two jobs, and the second is the one that justifies it. It is the "ta-da"
/// under a logo that has just assembled itself — and it is what keeps that logo
/// readable now that it sits on water instead of on a flat cream ground. The
/// artwork's white sticker outline is a strong edge against `backgroundPrimary`
/// and a weak one against pale sky, so something has to lift it. A grey scrim
/// over the whole pond would do it by making the pond worse; a warm bloom under
/// the logo does it by making the logo better.
///
/// ## Why it does not pulse
///
/// A shine that throbs is the oldest attention mechanic there is, and
/// `Docs/ChildSafety.md` rules those out — including on a surface a caregiver
/// sees several times a day. So the rays hold still and the bloom holds still.
/// The whole thing arrives with the stage and leaves with it, and in between it
/// does nothing at all. It also never flashes: every stop is a low-alpha warm
/// white, so there is no frame where luminance jumps.
struct HopSplashShine: View {
    @Environment(\.hopTheme) private var theme

    /// Width of the bloom. Sized from the logo rather than the screen, so the
    /// light belongs to the lockup at every device size.
    let diameter: CGFloat

    /// Number of rays. Odd, so no ray has a twin directly opposite it and the
    /// fan never reads as a grid.
    private static let rayCount = 13

    var body: some View {
        ZStack {
            rays
            bloom
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
    }

    /// A soft warm core that falls off to nothing well inside the frame.
    private var bloom: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        tint(theme.isDark ? 0.30 : 0.60),
                        tint(theme.isDark ? 0.12 : 0.20),
                        tint(0),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.5
                )
            )
    }

    /// The fan. Tapered slivers rather than lines, because a ray with a
    /// constant width reads as a spoke and a ray that narrows reads as light.
    private var rays: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let inner = size.width * 0.17
            let outer = size.width * 0.5
            for index in 0..<Self.rayCount {
                // Alternating lengths: a fan of identical rays is a wheel.
                let long = index.isMultiple(of: 2)
                let reach = inner + (outer - inner) * (long ? 0.96 : 0.78)
                let angle = (Double(index) / Double(Self.rayCount)) * 2 * .pi
                context.fill(
                    ray(centre: centre, angle: angle, inner: inner, reach: reach),
                    with: .color(tint(1))
                )
            }
        }
        .blur(radius: diameter * 0.0085)
        // The rays fade out along their own length. Flat slivers read as paper
        // cut-outs laid over the scene; light has to end in nothing.
        .mask {
            RadialGradient(
                colors: [.white.opacity(0.85), .white.opacity(0.30), .white.opacity(0)],
                center: .center,
                startRadius: 0,
                endRadius: diameter * 0.5
            )
        }
        .opacity(theme.isDark ? 0.46 : 0.78)
    }

    /// One sliver: wide where it leaves the core, a point where it ends.
    private func ray(centre: CGPoint, angle: Double, inner: CGFloat, reach: CGFloat) -> Path {
        let half = (2 * .pi / Double(Self.rayCount)) * 0.15
        func point(_ radius: CGFloat, _ theta: Double) -> CGPoint {
            CGPoint(x: centre.x + radius * cos(theta), y: centre.y + radius * sin(theta))
        }
        var path = Path()
        path.move(to: point(inner, angle - half))
        path.addLine(to: point(reach, angle))
        path.addLine(to: point(inner, angle + half))
        path.closeSubpath()
        return path
    }

    /// Warm white. Warm because the pond's light is warm and a cold shine on a
    /// warm scene reads as a screen artefact rather than as sunlight.
    private func tint(_ opacity: Double) -> Color {
        Color(HopPalette.sunshineSoft).opacity(opacity)
    }
}

#if DEBUG
#Preview("Shine · over the pond") {
    HopThemedRoot {
        ZStack {
            PondBackdropView(sceneHeight: 852)
            HopSplashShine(diameter: 300)
            HopLogoView(width: 260, layout: .assembled)
        }
    }
}

#Preview("Shine · dark") {
    HopThemedRoot(appearance: .dark) {
        ZStack {
            PondBackdropView(sceneHeight: 852)
            HopSplashShine(diameter: 300)
            HopLogoView(width: 260, layout: .assembled)
        }
    }
}
#endif
