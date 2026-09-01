import SwiftUI
import HopPottyDesignTokens

/// Layout constants that depend on the size class rather than on the theme.
public enum HopLayout {
    /// The horizontal page margin for a width class.
    ///
    /// iPad does not just get "more padding": at a regular width the margin has
    /// to grow with the measure or the text column runs to a line length nobody
    /// can track back to the start of.
    public static func pageMargin(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? CGFloat(HopSpacing.pageRegular) : CGFloat(HopSpacing.pageCompact)
    }

    /// The widest a column of parent-facing prose or form rows is allowed to be.
    ///
    /// Apple's own utility apps stop around here on iPad; past it, a settings
    /// row becomes a label at one edge and a value at the other with a metre of
    /// nothing between them.
    public static let readableWidth: CGFloat = 640

    /// The widest a child surface's content is allowed to be. Wider than the
    /// parent measure because it is illustration, not text, and the child is
    /// holding the device closer.
    public static let childContentWidth: CGFloat = 760
}

/// Applies the page margin for the current width class.
public struct HopPageMarginsModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let edges: Edge.Set

    public init(edges: Edge.Set = .horizontal) {
        self.edges = edges
    }

    public func body(content: Content) -> some View {
        content.padding(edges, HopLayout.pageMargin(for: horizontalSizeClass))
    }
}

/// Centres content and caps its width.
public struct HopContentWidthModifier: ViewModifier {
    private let maximum: CGFloat

    public init(maximum: CGFloat) {
        self.maximum = maximum
    }

    public func body(content: Content) -> some View {
        content
            .frame(maxWidth: maximum)
            .frame(maxWidth: .infinity)
    }
}

public extension View {
    /// The standard horizontal page margin: 20pt compact, 32pt regular.
    func hopPageMargins(_ edges: Edge.Set = .horizontal) -> some View {
        modifier(HopPageMarginsModifier(edges: edges))
    }

    /// Caps and centres a parent-facing column.
    func hopReadableWidth(_ maximum: CGFloat = HopLayout.readableWidth) -> some View {
        modifier(HopContentWidthModifier(maximum: maximum))
    }

    /// Guarantees a minimum tappable area without changing the visual size of
    /// what is drawn.
    ///
    /// `contentShape` is the load-bearing part: without it the extra frame is
    /// transparent to hit-testing and the target is still too small.
    func hopHitTarget(_ minimum: CGFloat) -> some View {
        frame(minWidth: minimum, minHeight: minimum)
            .contentShape(Rectangle())
    }

    /// Draws the focus ring for a control that is keyboard- or
    /// switch-control-focused, or that a component wants to mark as active.
    func hopFocusRing(_ isVisible: Bool, cornerRadius: CGFloat) -> some View {
        modifier(HopFocusRingModifier(isVisible: isVisible, cornerRadius: cornerRadius))
    }
}

/// The focus indicator. One shape, one colour, everywhere — a person who learns
/// what focus looks like on the parent dashboard should not have to relearn it
/// on the child's routine screen.
public struct HopFocusRingModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme
    let isVisible: Bool
    let cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: cornerRadius + 3, style: .continuous)
                .strokeBorder(theme.color.focusRing, lineWidth: 3)
                .padding(-3)
                .opacity(isVisible ? 1 : 0)
                // Not animated: a focus ring that fades in reads as latency.
                .allowsHitTesting(false)
        }
    }
}
