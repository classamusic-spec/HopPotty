import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

// MARK: - Why Hop is redrawn here instead of reused
//
// The app's Hop (`HopPotty/DesignSystem/Components/HopCharacterView.swift`) is a
// full character: tuned `HopPoseGeometry` values, layered SwiftUI paths, ambient
// motion, a blink timer. `project.yml` gives the three Screen Time extensions
// exactly four shared source files and `HopPottyCore`; the design system is a
// member of the app target only, and the shield-configuration extension — the
// one other place a HopPotty extension draws anything — likewise gets none of
// it. It reads pre-resolved strings and colours out of the App Group and renders
// those.
//
// This widget follows that precedent rather than breaking it:
//
//   * A widget is redrawn by the system, on the system's schedule, from an
//     archived view hierarchy. Animation, timers and ambient motion do not run,
//     so most of what makes `HopCharacterView` good is inert here.
//   * A 40-point accessory circle cannot show a character. It can show a face.
//   * Pulling the design system into a widget target means pulling the shape
//     layer, the theme environment and the glyph layer into a process with a
//     hard memory ceiling, to draw one frog at thumbnail size.
//
// So: a deliberately simplified face, drawn from the SAME tokens
// (`HopPottyDesignTokens`, which is platform-agnostic and already a package
// product) so the colours cannot drift from the app's. This is stated plainly in
// `Docs/Widgets.md` §4 — it is a duplication, it is a knowing one, and what
// keeps the two in step is the shared palette, not a shared view.

/// Hop, at widget size: a head, two eyes, a smile, and whatever the mood asks
/// for.
///
/// Scales with `size` rather than with the layout, so the same face works in a
/// 20-point inline slot and a 64-point small widget without the features
/// drifting apart.
struct HopWidgetFace: View {
    let mood: HopWidgetMood
    var size: CGFloat = 44

    /// Accessory widgets are composited into a single-colour vibrant layer, so a
    /// green frog arrives as a grey frog. In that context the face is drawn from
    /// the system's own foreground styles instead of from the palette, which is
    /// the difference between a legible outline and a flat disc.
    var isMonochrome: Bool = false

    var body: some View {
        ZStack {
            head
            eyes
            mouth
            if mood == .sleep { sleepMark }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(mood.accessibilityDescription))
    }

    // MARK: Parts

    private var head: some View {
        Circle()
            .fill(bodyColor)
            .overlay {
                Circle().strokeBorder(outlineColor, lineWidth: size * 0.045)
            }
    }

    /// Two domed eyes riding the top of the head, the way Hop's do.
    private var eyes: some View {
        HStack(spacing: size * 0.16) {
            eye
            eye
        }
        .offset(y: -size * 0.24)
    }

    private var eye: some View {
        ZStack {
            Circle()
                .fill(eyeWhite)
                .overlay { Circle().strokeBorder(outlineColor, lineWidth: size * 0.035) }
            if mood == .sleep {
                // Closed: a lid rather than a pupil. Drawn as a capsule because
                // an arc stroke disappears at twelve points.
                Capsule()
                    .fill(outlineColor)
                    .frame(width: size * 0.13, height: size * 0.035)
            } else {
                Circle()
                    .fill(outlineColor)
                    .frame(width: size * 0.09, height: size * 0.09)
                    .offset(y: mood == .jump ? -size * 0.015 : 0)
            }
        }
        .frame(width: size * 0.24, height: size * 0.24)
    }

    /// A smile whose width says as much as the eyes do.
    private var mouth: some View {
        Capsule()
            .fill(outlineColor)
            .frame(width: size * mouthWidth, height: size * 0.05)
            .offset(y: size * 0.16)
    }

    private var mouthWidth: CGFloat {
        switch mood {
        case .cheer, .jump: 0.40
        case .wave: 0.32
        case .idle: 0.26
        case .sleep: 0.16
        }
    }

    /// The one flourish: a "z" for asleep. Everything else the mood has to say,
    /// it says with the eyes and the smile — at forty points there is nowhere to
    /// put a second idea.
    private var sleepMark: some View {
        Text(verbatim: "z")
            .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
            .foregroundStyle(outlineColor)
            .offset(x: size * 0.38, y: -size * 0.34)
    }

    // MARK: Colours — from the shared token package, never re-typed as hex here

    private var bodyColor: Color {
        isMonochrome ? Color.primary.opacity(0.25) : Color(HopPalette.hopGreen)
    }

    private var eyeWhite: Color {
        isMonochrome ? Color.primary.opacity(0.08) : Color(HopPalette.cloud)
    }

    private var outlineColor: Color {
        isMonochrome ? Color.primary : Color(HopPalette.hopGreenInk)
    }
}

// MARK: - Token bridge

extension Color {
    /// The one place the widget turns a token into a SwiftUI colour.
    ///
    /// `HopPottyDesignTokens` is platform-agnostic on purpose — it is compiled
    /// and contrast-tested on Linux — so the SwiftUI conversion lives at each
    /// point of use. The app has its own, richer version in
    /// `DesignSystem/Foundation/HopColor+SwiftUI.swift`; this is the two-line
    /// form, kept separate rather than shared for the same reason the face is.
    init(_ value: HopColorValue) {
        self.init(
            .sRGB,
            red: value.red,
            green: value.green,
            blue: value.blue,
            opacity: value.alpha
        )
    }
}

#if DEBUG
#Preview("Hop's widget moods") {
    HStack(spacing: 12) {
        ForEach(HopWidgetMood.allCases) { mood in
            HopWidgetFace(mood: mood, size: 56)
        }
    }
    .padding()
}
#endif
