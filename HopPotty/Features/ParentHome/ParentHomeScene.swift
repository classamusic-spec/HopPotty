import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

// The furniture the dashboard's pond layout needs: where the water line and
// Hop's pad land, the capsules that float on the scene, and the panel that
// rises out of it.
//
// None of it holds state and none of it reaches a service. Every control here
// is handed the same closure the previous layout handed the same control, so
// moving the dashboard onto the pond changed where things are, not what they do.

// MARK: - Geometry

/// Where the pond sits behind the dashboard, in one place.
///
/// The proportions are the render's, expressed against the container's width
/// rather than a 393pt phone: the drawing is a landscape, so the crop that keeps
/// the sky behind the pills, the far bank behind Hop's head and the water in the
/// gap the countdown leaves is a proportion of the width, not of the height. A
/// short container (a landscape phone, a split-view iPad) clamps against the
/// height so the water line can never fall off the bottom.
struct HomePondMetrics {
    /// The fraction of Hop's square canvas that is above the ground he stands
    /// on — `HopFigureShape`'s ground shadow sits at reference y 159 of 160, and
    /// the sitting pose settles just above it.
    static let hopGroundFraction: CGFloat = 0.92

    let size: CGSize
    let isRegular: Bool
    let isAccessibilitySize: Bool

    private var width: CGFloat { max(1, size.width) }
    private var height: CGFloat { max(1, size.height) }

    /// The drawing's own box. Hung at the top of the layer; below it the near
    /// shore simply continues.
    var sceneHeight: CGFloat {
        min(width * (isRegular ? 0.58 : 0.98), height * 0.9)
    }

    var hopSize: CGFloat {
        min(width * (isRegular ? 0.20 : 0.34), isRegular ? 190 : 170)
    }

    /// The centre of the big lily pad, which is also where Hop's feet go.
    var padPoint: CGPoint {
        CGPoint(x: width * 0.56, y: sceneHeight * 0.508)
    }

    /// The water the scroll content leaves open above the countdown.
    ///
    /// At an accessibility text size the pond gives most of it back: the
    /// countdown and the panel under it are what a caregiver came for, and a
    /// screen that opens on two thirds of a drawing is a screen they have to
    /// scroll before they can read anything.
    var opening: CGFloat {
        let base = min(width * (isRegular ? 0.34 : 0.62), height * (isRegular ? 0.42 : 0.50))
        return isAccessibilitySize ? base * 0.6 : base
    }

    /// The timer is a column beside the water on iPad and the full measure on a
    /// phone. Named for the card it used to be; the block it now measures has no
    /// card, but the width it is allowed is the same decision.
    var cardMaxWidth: CGFloat {
        isRegular ? width * 0.56 : .infinity
    }

    /// Enough panel that it reaches the bottom of the screen on a short day —
    /// the timer's own height is allowed for, and anything taller simply scrolls.
    var sheetMinHeight: CGFloat {
        max(0, height - opening - (isRegular ? 190 : 220))
    }
}

// MARK: - The scene

/// The pond, with Hop sitting in it.
///
/// Hop is placed against ``HomePondMetrics/padPoint`` — the same point
/// `PondBackdropView` draws the big lily pad at — so he is on the pad at every
/// width rather than near it. His idle breath and blink come from
/// ``HopCharacterStage``; passing `ambient: false` under Reduce Motion stops
/// them at the source as well as inside the modifiers, because a pond that
/// breathes behind a countdown is exactly the motion that setting removes.
struct HomePondScene: View {
    @Environment(\.hopTheme) private var theme

    let metrics: HomePondMetrics

    var body: some View {
        PondBackdropView(sceneHeight: metrics.sceneHeight)
            .overlay(alignment: .topLeading) {
                HopCharacterStage(
                    pose: .sit,
                    size: metrics.hopSize,
                    ambient: !theme.reduceMotion,
                    describedAs: ""
                )
                .frame(width: metrics.hopSize, height: metrics.hopSize)
                .offset(
                    x: metrics.padPoint.x - metrics.hopSize / 2,
                    y: metrics.padPoint.y - metrics.hopSize * HomePondMetrics.hopGroundFraction
                )
            }
            // The whole layer is scenery. A caregiver's screen reader should
            // reach the countdown, not a description of a frog.
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

// MARK: - Chrome that floats on the scene

/// A translucent capsule sitting on the water.
///
/// Never below 44pt, and opaque in increased contrast: a frosted pill is a
/// pleasant thing over a drawing right up until it is the only thing between a
/// caregiver and a child's name.
struct HomeScenePill<Content: View>: View {
    @Environment(\.hopTheme) private var theme

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var fillOpacity: Double {
        if theme.isHighContrast { return 1 }
        return theme.isDark ? 0.80 : 0.88
    }

    private var shape: Capsule { Capsule(style: .continuous) }

    var body: some View {
        content
            .padding(.horizontal, theme.spacing.m)
            .padding(.vertical, theme.spacing.xs)
            .frame(minHeight: theme.hitTarget.parent)
            .background(theme.color.surface.opacity(fillOpacity), in: shape)
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape.strokeBorder(
                    theme.color.divider.opacity(theme.isHighContrast ? 1 : 0.5),
                    lineWidth: theme.isHighContrast ? 1.5 : 0.75
                )
            }
            .modifier(theme.elevation(.resting))
    }
}

/// The row along the top of the scene: who this screen is about, and what they
/// have earned today.
///
/// The switcher is the same ``ChildSwitcher`` the stacked layout used, with the
/// same `onSelect`, so switching child still runs through
/// `ParentEnvironment.selectChild`. The star count is a fact, not a control:
/// there is nowhere on the parent side for it to lead, and a pill that looks
/// tappable and is not is worse than one that plainly is not.
struct HomeSceneTopBar: View {
    @Environment(\.hopTheme) private var theme

    let greeting: String
    let children: [ChildProfile]
    let child: ChildProfile
    let starsToday: Int
    let onSelectChild: (UUID) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: theme.spacing.s) {
            childPill
            Spacer(minLength: theme.spacing.s)
            starsPill
        }
    }

    /// The whole capsule is the switcher's label, so the target is the capsule
    /// rather than the name inside it.
    private var childPill: some View {
        ChildSwitcher(children: children, selected: child, onSelect: onSelectChild) { name in
            HomeScenePill {
                HStack(spacing: theme.spacing.s) {
                    HopChip(diameter: 32)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: greeting)
                            .hopTextStyle(.parentFootnote)
                            .foregroundStyle(theme.color.textSecondary)
                            .lineLimit(1)

                        Text(verbatim: name)
                            .hopTextStyle(.parentHeadline)
                            .foregroundStyle(theme.color.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    if children.count > 1 {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote)
                            .foregroundStyle(theme.color.textTertiary)
                    }
                }
            }
        }
        // Keeps the menu from tinting a label that has already chosen its own
        // colours.
        .buttonStyle(.plain)
    }

    private var starsPill: some View {
        HomeScenePill {
            HStack(spacing: theme.spacing.xs) {
                HopGlyphView(.star, size: 15)
                    .foregroundStyle(theme.color.celebration)

                Text(verbatim: ParentFormat.count(starsToday))
                    .hopTextStyle(.parentHeadline)
                    .foregroundStyle(theme.color.textPrimary)
                    .hopNumericText()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: HopCopy.parentHome.summaryStars.localized(for: starsToday)))
    }
}

// MARK: - The panel

/// The panel the day's detail lives on.
///
/// A rounded top on the app's own ground, rising out of the water — not a
/// presented sheet. It scrolls with the countdown above it, which is the point:
/// the pond is where the screen starts and the detail is what a caregiver pulls
/// up when they want it, in one gesture, with nothing to dismiss afterwards.
struct HomeSheetPanel<Content: View>: View {
    @Environment(\.hopTheme) private var theme

    private let minimumHeight: CGFloat
    private let content: Content

    init(minimumHeight: CGFloat, @ViewBuilder content: () -> Content) {
        self.minimumHeight = minimumHeight
        self.content = content()
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: theme.radius.hero,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: theme.radius.hero,
            style: .continuous
        )
    }

    var body: some View {
        VStack(spacing: theme.spacing.l) {
            grabber
            content
        }
        .padding(.bottom, theme.spacing.giant)
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(minHeight: minimumHeight, alignment: .top)
        .background {
            shape
                .fill(theme.color.backgroundPrimary)
                .shadow(color: theme.color.shadow, radius: 18, y: -6)
        }
        // In increased contrast the shadow is not a boundary, so the panel's
        // edge gets a hairline. Everywhere else the shadow is the edge, and a
        // border along a panel that runs off the bottom of the screen would
        // draw a line across it.
        .overlay {
            if theme.isHighContrast {
                shape.stroke(theme.color.divider, lineWidth: 1.5)
            }
        }
    }

    /// The handle that says the panel moves. Decorative — the panel is a scroll
    /// view, and VoiceOver users move it the way they move any other one.
    private var grabber: some View {
        Capsule()
            .fill(theme.color.divider)
            .frame(width: 38, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, theme.spacing.s)
            .accessibilityHidden(true)
    }
}
