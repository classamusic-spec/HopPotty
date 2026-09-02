import SwiftUI
import HopPottyDesignTokens

/// Which corner the bubble's tail points from.
public enum HopBubbleTail: String, CaseIterable, Sendable {
    case bottomLeading, bottomTrailing, topLeading, topTrailing
    /// No tail — a caption that is not attributed to Hop.
    case hidden
}

/// The bubble outline: a soft rounded rectangle with a rounded tail.
///
/// The tail is a curve rather than a triangle because a sharp point next to a
/// character built entirely from ovals reads as a different illustration style.
struct HopSpeechBubbleShape: Shape {
    var tail: HopBubbleTail
    var cornerRadius: CGFloat
    var tailSize: CGFloat

    func path(in rect: CGRect) -> Path {
        let bodyRect: CGRect
        switch tail {
        case .bottomLeading, .bottomTrailing:
            bodyRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailSize)
        case .topLeading, .topTrailing:
            bodyRect = CGRect(x: rect.minX, y: rect.minY + tailSize, width: rect.width, height: rect.height - tailSize)
        case .hidden:
            bodyRect = rect
        }

        var path = Path(roundedRect: bodyRect, cornerRadius: cornerRadius, style: .continuous)
        guard tail != .hidden else { return path }

        let inset = cornerRadius + tailSize * 0.4
        let isLeading = tail == .bottomLeading || tail == .topLeading
        let anchorX = isLeading ? bodyRect.minX + inset : bodyRect.maxX - inset
        let isBottom = tail == .bottomLeading || tail == .bottomTrailing
        let baseY = isBottom ? bodyRect.maxY : bodyRect.minY
        let tipY = isBottom ? rect.maxY : rect.minY
        let direction: CGFloat = isLeading ? 1 : -1

        path.move(to: CGPoint(x: anchorX - tailSize * 0.55 * direction, y: baseY))
        path.addQuadCurve(
            to: CGPoint(x: anchorX + tailSize * 0.15 * direction, y: tipY),
            control: CGPoint(x: anchorX - tailSize * 0.3 * direction, y: tipY)
        )
        path.addQuadCurve(
            to: CGPoint(x: anchorX + tailSize * 0.9 * direction, y: baseY),
            control: CGPoint(x: anchorX + tailSize * 0.6 * direction, y: baseY - tailSize * 0.1)
        )
        path.closeSubpath()
        return path
    }
}

/// What Hop says, in writing.
///
/// Every spoken line has one of these — the caption is not an accessibility
/// afterthought but the primary form, because most of the audience cannot read
/// yet and the grown-up beside them is the one doing the reading.
public struct HopSpeechBubble: View {
    @Environment(\.hopTheme) private var theme
    @State private var hasArrived = false

    private let text: String
    private let tail: HopBubbleTail
    private let animatesArrival: Bool

    public init(_ text: String, tail: HopBubbleTail = .bottomLeading, animatesArrival: Bool = false) {
        self.text = text
        self.tail = tail
        self.animatesArrival = animatesArrival
    }

    private var isArriving: Bool { animatesArrival && !hasArrived }

    /// The bubble grows *out of the tail*, which is where Hop is. Scaling about
    /// the centre would make the words appear beside him; scaling about the tail
    /// makes them come from him, and for a pre-reader that is the difference
    /// between a caption and a character speaking.
    ///
    /// Off by default. Most callers already wrap this in a transition of their
    /// own, and a bubble that grows inside a view that is also growing is the
    /// exact double-animation this is meant to avoid.
    private var arrivalAnchor: UnitPoint {
        switch tail {
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .hidden: .center
        }
    }

    private let cornerRadius: CGFloat = 26
    private let tailSize: CGFloat = 18

    private var shape: HopSpeechBubbleShape {
        HopSpeechBubbleShape(tail: tail, cornerRadius: cornerRadius, tailSize: tailSize)
    }

    private var tailPadding: EdgeInsets {
        switch tail {
        case .bottomLeading, .bottomTrailing: EdgeInsets(top: 0, leading: 0, bottom: tailSize, trailing: 0)
        case .topLeading, .topTrailing: EdgeInsets(top: tailSize, leading: 0, bottom: 0, trailing: 0)
        case .hidden: EdgeInsets()
        }
    }

    public var body: some View {
        Text(text)
            .hopTextStyle(.childInstruction, allowsTightening: false)
            .foregroundStyle(theme.color.textPrimary)
            .multilineTextAlignment(.leading)
            // Child copy is short, but a translation can be long and a caption
            // that truncates is a caption that failed. Wrapping is unlimited.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, theme.spacing.xxl)
            .padding(.vertical, theme.spacing.xl)
            .padding(tailPadding)
            .background {
                shape
                    .fill(theme.color.surface)
                    .overlay {
                        shape.stroke(
                            theme.color.divider.opacity(theme.isHighContrast ? 1 : 0.5),
                            lineWidth: theme.isHighContrast ? 2 : 1
                        )
                    }
            }
            .modifier(theme.elevation(.resting))
            .scaleEffect(isArriving && !theme.reduceMotion ? 0.72 : 1, anchor: arrivalAnchor)
            .opacity(isArriving ? 0 : 1)
            .hopAnimation(.childArrive, value: hasArrived)
            // A new line replacing an old one inside a bubble that is already
            // on screen cross-fades; the bubble itself does not re-arrive.
            .hopValueChange(text)
            .onAppear { hasArrived = true }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
    }
}

#Preview("Speech bubble") {
    VStack(alignment: .leading, spacing: 32) {
        HopSpeechBubble("Let's go and try!")
        HopSpeechBubble("Sit for a little while. I'll wait right here with you.", tail: .bottomTrailing)
        HopSpeechBubble("All done — high five!", tail: .topLeading)
        HopSpeechBubble("Nothing to see here.", tail: .hidden)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Speech bubble · long text at AX3") {
    HopSpeechBubble("When you're ready, sit down and give it a try. There's no hurry at all — I'll wait right here with you the whole time.")
        .padding()
        .environment(\.dynamicTypeSize, .accessibility3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Speech bubble · dark + Hop") {
    VStack(alignment: .leading, spacing: 0) {
        HopSpeechBubble("Let's go and try!")
        HopCharacterStage(pose: .wave, size: 200)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
    .preferredColorScheme(.dark)
}

#Preview("Speech bubble · arrival from the tail") {
    VStack(alignment: .leading, spacing: 32) {
        HopSpeechBubble("Let's go and try!", animatesArrival: true)
        HopSpeechBubble("All done — high five!", tail: .topTrailing, animatesArrival: true)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Speech bubble · arrival, Reduce Motion") {
    VStack(alignment: .leading, spacing: 32) {
        HopSpeechBubble("Let's go and try!", animatesArrival: true)
        HopSpeechBubble("All done — high five!", tail: .topTrailing, animatesArrival: true)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .hopBackground()
    .hopThemedRoot(reduceMotion: true)
}

#Preview("Speech bubble · high contrast") {
    HopSpeechBubble("Let's go and try!")
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hopBackground()
        .hopThemedRoot(appearance: .lightHighContrast)
}
