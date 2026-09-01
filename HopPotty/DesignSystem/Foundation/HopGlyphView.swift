import SwiftUI

/// Renders a ``HopGlyph`` at a given size, from either SF Symbols or
/// HopPotty's own paths.
///
/// Decorative by default: when a glyph merely repeats a label that is already
/// on screen, VoiceOver should skip it. Pass `isDecorative: false` where the
/// mark is the only thing carrying the meaning.
public struct HopGlyphView: View {
    private let glyph: HopGlyph
    private let size: CGFloat
    private let isDecorative: Bool

    public init(_ glyph: HopGlyph, size: CGFloat = 20, isDecorative: Bool = true) {
        self.glyph = glyph
        self.size = size
        self.isDecorative = isDecorative
    }

    public var body: some View {
        mark
            .frame(width: size, height: size)
            .accessibilityHidden(isDecorative)
            .modifier(HopGlyphLabel(glyph: glyph, isDecorative: isDecorative))
    }

    @ViewBuilder
    private var mark: some View {
        if let systemImage = glyph.systemImage {
            Image(systemName: systemImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                // A symbol's glyph box is smaller than its layout box; the inset
                // makes symbol-backed and path-backed marks optically equal.
                .padding(size * 0.06)
                .fontWeight(.semibold)
        } else {
            HopGlyphShape(glyph)
                .fill(style: FillStyle(eoFill: true))
        }
    }
}

private struct HopGlyphLabel: ViewModifier {
    let glyph: HopGlyph
    let isDecorative: Bool

    func body(content: Content) -> some View {
        if isDecorative {
            content
        } else {
            content
                .accessibilityElement()
                .accessibilityLabel(glyph.accessibilityDescription)
        }
    }
}

/// A glyph inside a soft tinted container. The standard treatment for a mark
/// that identifies a row, a card or a state.
public struct HopGlyphBadge: View {
    @Environment(\.hopTheme) private var theme

    private let glyph: HopGlyph
    private let tint: Color
    private let diameter: CGFloat
    private let isDecorative: Bool

    public init(_ glyph: HopGlyph, tint: Color, diameter: CGFloat = 36, isDecorative: Bool = true) {
        self.glyph = glyph
        self.tint = tint
        self.diameter = diameter
        self.isDecorative = isDecorative
    }

    public var body: some View {
        HopGlyphView(glyph, size: diameter * 0.52, isDecorative: isDecorative)
            .foregroundStyle(tint)
            .frame(width: diameter, height: diameter)
            .background {
                Circle()
                    .fill(HopColors.wash(tint, isDark: theme.isDark))
                    // In increased contrast the wash alone is not enough
                    // separation from the card behind it.
                    .overlay {
                        Circle().strokeBorder(tint.opacity(theme.isHighContrast ? 0.55 : 0), lineWidth: 1.5)
                    }
            }
            .accessibilityHidden(isDecorative)
    }
}

#Preview("Glyph set") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 20) {
            ForEach(HopGlyph.allCases) { glyph in
                VStack(spacing: 8) {
                    HopGlyphBadge(glyph, tint: .accentColor, diameter: 52)
                    Text(glyph.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
    .hopThemedRoot()
}

#Preview("Glyph set · dark") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 20) {
            ForEach(HopGlyph.allCases) { glyph in
                HopGlyphBadge(glyph, tint: .accentColor, diameter: 52)
            }
        }
        .padding()
    }
    .hopBackground()
    .hopThemedRoot()
    .preferredColorScheme(.dark)
}
