import SwiftUI

// Cross-cutting support for the child's illustrated surfaces, in the same
// folder and for the same reason as `ChildContext` and `ChildArtwork`: this
// workstream's agreed write scope. At integration it moves to
// `Features/ChildSurfaces/` unchanged.

/// The room a child screen happens in.
///
/// ## Why this is drawn rather than loaded
///
/// A child screen is supposed to be a **place**, and a place has to be there on
/// the first frame, at any size, on a build with no art in it. `HopArtwork`
/// draws a soft placeholder when a key has not shipped — which is right for a
/// picture *inside* a screen and quite wrong for the screen's own ground, where
/// it would put a lilac blob behind the words.
///
/// So the ground is four shapes and a gradient: a wall, two tile lines, a
/// counter edge and a floor. It costs nothing, it scales to any device, and it
/// is the same room the render harness draws in `Scripts/screens/child.js`, so
/// the design renders and the app agree about where the floor is.
///
/// Every colour comes from the semantic palette. There is no hex here and no
/// asset — see `Docs/DesignSystem.md`.
struct ChildRoom: View {
    @Environment(\.hopTheme) private var theme

    /// Fraction of the height at which the floor (or the counter) starts.
    var floorFraction: CGFloat = 0.68
    /// A soft pool of light behind whatever the screen's subject is. Off for a
    /// screen whose subject brings its own.
    var glow: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let floorY = size.height * floorFraction

            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        HopColors.wash(theme.color.brandSecondary, isDark: theme.isDark),
                        theme.color.backgroundSecondary,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                tiles(size: size, floorY: floorY)

                if glow {
                    RadialGradient(
                        colors: [theme.color.backgroundPrimary.opacity(0.9), theme.color.backgroundPrimary.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size.width * 0.72
                    )
                    .frame(width: size.width, height: size.width)
                    .offset(y: floorY - size.width * 0.72)
                }

                Rectangle()
                    .fill(theme.color.surface)
                    .frame(width: size.width, height: max(1, size.height * 0.016))
                    .offset(y: floorY - size.height * 0.016)

                Rectangle()
                    .fill(theme.color.backgroundPrimary)
                    .frame(width: size.width, height: max(0, size.height - floorY))
                    .offset(y: floorY)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        // The room is the room. Everything a child can act on carries its own
        // label, and a screen reader has no use for "a wall".
        .accessibilityHidden(true)
    }

    /// Two horizontal courses and three verticals, at the weight of a hint.
    private func tiles(size: CGSize, floorY: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach([0.22, 0.44], id: \.self) { fraction in
                Rectangle()
                    .fill(theme.color.surface.opacity(0.5))
                    .frame(width: size.width, height: 1.5)
                    .offset(y: floorY * fraction)
            }
            ForEach([0.25, 0.5, 0.75], id: \.self) { fraction in
                Rectangle()
                    .fill(theme.color.surface.opacity(0.5))
                    .frame(width: 1.5, height: floorY)
                    .offset(x: size.width * fraction)
            }
        }
    }
}

// MARK: - Outdoors

/// The meadow, the path, and — when a screen is taking a child somewhere — the
/// bathroom door at the end of it.
///
/// Drawn rather than loaded for the reason ``ChildRoom`` is: the ground of a
/// child screen has to be there on the first frame at any size, and the asset
/// catalog carries no scenes yet (`BUILD_STATUS.md`). The door earns its place
/// on the pause screen — "let's hop to the potty" said to a pre-reader without a
/// picture of *where* is only words — and is off everywhere else.
struct ChildMeadow: View {
    @Environment(\.hopTheme) private var theme

    var showsDoor = false
    /// Fraction of the height the sky occupies.
    var horizonFraction: CGFloat = 0.52

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let horizon = size.height * horizonFraction

            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        HopColors.wash(theme.color.brandSecondary, isDark: theme.isDark),
                        theme.color.backgroundPrimary,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // The far hill, so the horizon is a shape rather than a rule.
                Ellipse()
                    .fill(HopColors.wash(theme.color.brandPrimary, isDark: theme.isDark))
                    .frame(width: size.width * 2.1, height: size.height * 0.5)
                    .offset(x: -size.width * 0.55, y: horizon - size.height * 0.12)

                Rectangle()
                    .fill(theme.color.brandPrimary.opacity(theme.isDark ? 0.32 : 0.42))
                    .frame(width: size.width, height: max(0, size.height - horizon))
                    .offset(y: horizon)

                if showsDoor {
                    path(size: size, horizon: horizon)
                    door(size: size, horizon: horizon)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// The path Hop is walking up, widening toward the child.
    private func path(size: CGSize, horizon: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: size.width * 0.3, y: size.height))
            path.addQuadCurve(
                to: CGPoint(x: size.width * 0.78, y: horizon),
                control: CGPoint(x: size.width * 0.5, y: size.height * 0.78)
            )
            path.addLine(to: CGPoint(x: size.width * 0.88, y: horizon))
            path.addQuadCurve(
                to: CGPoint(x: size.width * 0.76, y: size.height),
                control: CGPoint(x: size.width * 0.72, y: size.height * 0.78)
            )
            path.closeSubpath()
        }
        .fill(theme.color.backgroundSecondary.opacity(0.9))
    }

    /// The bathroom door at the end of the path: the destination, drawn.
    private func door(size: CGSize, horizon: CGFloat) -> some View {
        let width = size.width * 0.19
        let height = width * 1.25
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: width * 0.1, style: .continuous)
                .fill(theme.color.eventPoop.opacity(0.55))
                .frame(width: width, height: height)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(HopColors.wash(theme.color.celebration, isDark: theme.isDark))
                        .frame(width: width * 0.5, height: height * 0.34)
                        .offset(y: height * 0.14)
                }
            ChildRoofShape()
                .fill(theme.color.success)
                .frame(width: width * 1.4, height: height * 0.44)
                .offset(y: -height + height * 0.06)
        }
        .frame(width: width * 1.4, height: height * 1.4, alignment: .bottom)
        .offset(x: size.width * 0.72, y: horizon - height)
    }
}

/// The door's pitched roof. Three points, so a shape rather than a rotated
/// rectangle that would have to be un-rotated at every size.
private struct ChildRoofShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Child meadow · with the door") {
    ChildMeadow(showsDoor: true)
        .hopThemedRoot()
}

#Preview("Child room") {
    ChildRoom()
        .hopThemedRoot()
}

#Preview("Child room · dark") {
    ChildRoom(floorFraction: 0.8, glow: false)
        .hopThemedRoot(appearance: .dark)
}
