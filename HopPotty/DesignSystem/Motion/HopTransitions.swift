import SwiftUI
import HopPottyDesignTokens

// HopPotty's transition vocabulary.
//
// A screen change is the largest piece of motion the app ever performs, and it
// is the one a person notices when it is wrong. The rule here is that a
// transition has to *say something* — which way through a flow we went, that a
// thing was presented over what came before, that something arrived for the
// child. Motion that says nothing is motion that should not run.
//
// Everything below is built from two small animatable modifiers and routed
// through `HopAnimationToken.guarded(_:reduceMotion:)`, so Reduce Motion is
// still decided in exactly one file. Under Reduce Motion every transition on
// this page is the same 0.20s cross-fade and nothing travels.

// MARK: - Primitives

/// Moves a page by a fraction of **its own size**, pushes it back in z, and
/// dims it.
///
/// A fraction rather than points because a push has to look the same on a
/// 375-point phone and an 834-point iPad column, and the outgoing page's
/// parallax is defined in `HopMotion.pageParallax` as a fraction of width.
/// The offset is the only part that needs the geometry, so it is the only part
/// inside `visualEffect`.
struct HopPageShift: ViewModifier, Animatable {
    /// Horizontal travel, as a fraction of the page's own width.
    var travel: Double
    /// Vertical travel, as a fraction of the page's own height.
    var rise: Double
    /// Scale. 1 is in the plane of the screen; less than 1 sits behind it.
    var depth: Double
    /// How far the page is faded out. 0 is fully opaque.
    var dim: Double

    static let identity = HopPageShift(travel: 0, rise: 0, depth: 1, dim: 0)

    // `nonisolated`, and it has to be. `ViewModifier` is a `@MainActor`
    // protocol, so conforming to it makes this struct main-actor isolated;
    // `Animatable` is not, and SwiftUI's animation machinery reads and writes
    // `animatableData` on its own terms. Swift 6 calls that out directly:
    //
    //     error: conformance of '...' to protocol 'Animatable' crosses into
    //            main actor-isolated code and can cause data races
    //
    // This is safe rather than merely silenced: the type is a value type whose
    // every stored property is a `Double`, so there is no shared mutable state
    // for the two domains to race over -- each side animates its own copy. That
    // is also why `nonisolated` is *allowed* to touch the stored properties at
    // all (SE-0434 permits it for `Sendable` storage in a global-actor-isolated
    // value type); if any property here were a reference, the compiler would
    // refuse and the fix would have to be a real one.
    nonisolated var animatableData: AnimatablePair<Double, AnimatablePair<Double, AnimatablePair<Double, Double>>> {

        get { AnimatablePair(travel, AnimatablePair(rise, AnimatablePair(depth, dim))) }
        set {
            travel = newValue.first
            rise = newValue.second.first
            depth = newValue.second.second.first
            dim = newValue.second.second.second
        }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(depth)
            .opacity(1 - dim)
            .visualEffect { [travel, rise] effect, proxy in
                effect.offset(x: travel * proxy.size.width, y: rise * proxy.size.height)
            }
    }
}

/// Lifts a surface into place by a fixed distance in points.
///
/// Points rather than a fraction, because a card is not a page: a tall card and
/// a short one should rise the same distance into the same layout, or a
/// dashboard's arrival reads as ragged.
struct HopSurfaceArrival: ViewModifier, Animatable {
    /// Vertical offset in points. Positive is below its final place.
    var lift: Double
    /// Scale. Slightly under 1 reads as "settling", not as "zooming".
    var depth: Double
    /// How far the surface is faded out. 0 is fully opaque.
    var dim: Double

    static let identity = HopSurfaceArrival(lift: 0, depth: 1, dim: 0)

    // `nonisolated`, and it has to be. `ViewModifier` is a `@MainActor`
    // protocol, so conforming to it makes this struct main-actor isolated;
    // `Animatable` is not, and SwiftUI's animation machinery reads and writes
    // `animatableData` on its own terms. Swift 6 calls that out directly:
    //
    //     error: conformance of '...' to protocol 'Animatable' crosses into
    //            main actor-isolated code and can cause data races
    //
    // This is safe rather than merely silenced: the type is a value type whose
    // every stored property is a `Double`, so there is no shared mutable state
    // for the two domains to race over -- each side animates its own copy. That
    // is also why `nonisolated` is *allowed* to touch the stored properties at
    // all (SE-0434 permits it for `Sendable` storage in a global-actor-isolated
    // value type); if any property here were a reference, the compiler would
    // refuse and the fix would have to be a real one.
    nonisolated var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {

        get { AnimatablePair(lift, AnimatablePair(depth, dim)) }
        set {
            lift = newValue.first
            depth = newValue.second.first
            dim = newValue.second.second
        }
    }

    func body(content: Content) -> some View {
        content
            .offset(y: lift)
            .scaleEffect(depth)
            .opacity(1 - dim)
    }
}

// MARK: - The named transitions

public extension AnyTransition {
    /// **Forward through a caregiver flow.** The new page comes in from the
    /// trailing edge at full travel while the old one slides only
    /// `HopMotion.pageParallax` of the way out and dims — the parallax is what
    /// makes a push read as one page in front of another rather than two pages
    /// swapping.
    static var hopParentPush: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: HopPageShift(travel: 1, rise: 0, depth: 1, dim: 0.2),
                identity: HopPageShift.identity
            ),
            removal: .modifier(
                active: HopPageShift(travel: -HopMotion.pageParallax, rise: 0, depth: 0.97, dim: 0.4),
                identity: HopPageShift.identity
            )
        )
    }

    /// **Back through a caregiver flow.** The exact mirror of ``hopParentPush``:
    /// the page being returned to comes back from behind and to the leading
    /// side, the page being left goes out the way it came in.
    static var hopParentPop: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: HopPageShift(travel: -HopMotion.pageParallax, rise: 0, depth: 0.97, dim: 0.4),
                identity: HopPageShift.identity
            ),
            removal: .modifier(
                active: HopPageShift(travel: 1, rise: 0, depth: 1, dim: 0.2),
                identity: HopPageShift.identity
            )
        )
    }

    /// **A child-facing screen change.** The same idea with weight added: the
    /// incoming screen arrives on a shallow arc, slightly small, and the
    /// outgoing one falls back rather than sliding flat — so a pre-reader sees
    /// one thing hand over to another instead of a cut.
    static var hopChildPage: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: HopPageShift(travel: 0.55, rise: 0.05, depth: 0.90, dim: 0.25),
                identity: HopPageShift.identity
            ),
            removal: .modifier(
                active: HopPageShift(travel: -0.28, rise: 0.03, depth: 0.90, dim: 0.55),
                identity: HopPageShift.identity
            )
        )
    }

    /// **A sheet rising over the page.** Comes up from the bottom edge, a hair
    /// under full size, so the last few points of the movement read as the
    /// sheet settling against the top of the screen.
    static var hopSheetRise: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: HopPageShift(travel: 0, rise: 1, depth: 0.98, dim: 0.1),
                identity: HopPageShift.identity
            ),
            removal: .modifier(
                active: HopPageShift(travel: 0, rise: 1, depth: 1, dim: 0.1),
                identity: HopPageShift.identity
            )
        )
    }

    /// **A modal arriving in place.** No travel at all — it belongs *here*, over
    /// what was already on screen — so it grows the last 8% into place and
    /// fades. Use it for an alert-shaped thing, a parent gate, a confirmation.
    static var hopModalArrival: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: HopPageShift(travel: 0, rise: 0, depth: 0.92, dim: 1),
                identity: HopPageShift.identity
            ),
            removal: .modifier(
                active: HopPageShift(travel: 0, rise: 0, depth: 0.96, dim: 1),
                identity: HopPageShift.identity
            )
        )
    }

    /// **A celebration arriving.** Comes in small and low and is thrown into
    /// place by ``HopAnimationToken/childCelebrate``'s overshoot; leaves
    /// quietly, because a reward that exits with a bang asks to be watched
    /// again and that is an engagement mechanic (`Docs/ChildSafety.md` §1.4).
    static var hopCelebrationArrival: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: HopPageShift(travel: 0, rise: 0.06, depth: 0.55, dim: 1),
                identity: HopPageShift.identity
            ),
            removal: .modifier(
                active: HopPageShift(travel: 0, rise: 0, depth: 0.94, dim: 1),
                identity: HopPageShift.identity
            )
        )
    }

    /// **A card arriving in a list.** Lifts 14 points into place and settles.
    /// Combined with a stagger it is what makes a dashboard look composed
    /// rather than dumped.
    static var hopCardArrival: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: HopSurfaceArrival(lift: 14, depth: 0.98, dim: 1),
                identity: HopSurfaceArrival.identity
            ),
            removal: .modifier(
                active: HopSurfaceArrival(lift: -6, depth: 0.98, dim: 1),
                identity: HopSurfaceArrival.identity
            )
        )
    }
}

// MARK: - The vocabulary, as a token

/// The named screen transitions, paired with the spring each one should be
/// driven by.
///
/// A transition and its animation are one decision, not two: ``hopParentPush``
/// run on ``HopAnimationToken/childCelebrate`` would be a caregiver's settings
/// screen bouncing. Using this enum rather than the raw `AnyTransition`s above
/// is what keeps the pairing.
public enum HopScreenTransition: String, CaseIterable, Sendable {
    /// Forward through a caregiver flow — settings detail, onboarding step,
    /// paywall. Parallax on the outgoing page.
    case parentPush
    /// Back out of one. The mirror of ``parentPush``.
    case parentPop
    /// A child-facing screen change — hub to routine, question to question,
    /// game to game.
    case childPage
    /// A sheet rising over the page.
    case sheet
    /// A modal that belongs over what is already there: parent gate,
    /// confirmation, error.
    case modal
    /// A celebration or reward arriving on a child surface.
    case celebration
    /// A card, row or tile arriving inside a screen that is already there.
    case cardArrival

    /// The spring this transition is driven by.
    public var motion: HopAnimationToken {
        switch self {
        case .parentPush, .parentPop: .pagePush
        case .childPage: .childPage
        case .sheet: .parentSheet
        case .modal: .parentTransition
        case .celebration: .childCelebrate
        case .cardArrival: .parentTransition
        }
    }

    /// The transition, already degraded to a cross-fade under Reduce Motion.
    public func transition(reduceMotion: Bool) -> AnyTransition {
        HopAnimationToken.guarded(fullMotion, reduceMotion: reduceMotion)
    }

    /// The undegraded transition. Prefer ``transition(reduceMotion:)`` — this is
    /// exposed for previews and for the design lab, which need to show both.
    public var fullMotion: AnyTransition {
        switch self {
        case .parentPush: .hopParentPush
        case .parentPop: .hopParentPop
        case .childPage: .hopChildPage
        case .sheet: .hopSheetRise
        case .modal: .hopModalArrival
        case .celebration: .hopCelebrationArrival
        case .cardArrival: .hopCardArrival
        }
    }

    /// The reverse of this transition, where there is one. A flow that can only
    /// go forward — a celebration, a card arriving — is its own reverse.
    public var reversed: HopScreenTransition {
        switch self {
        case .parentPush: .parentPop
        case .parentPop: .parentPush
        default: self
        }
    }
}

// MARK: - Adoption

public extension View {
    /// Applies a named screen transition. Goes on the content *inside* the
    /// `if` / `switch` that is changing, not on the container.
    func hopScreenTransition(_ style: HopScreenTransition) -> some View {
        modifier(HopScreenTransitionModifier(style: style))
    }

    /// Animates a screen or route change with the transition's own spring. Goes
    /// on the **container** whose child is being swapped.
    func hopScreenChange<V: Equatable>(_ style: HopScreenTransition, value: V) -> some View {
        modifier(HopAnimationModifier(token: style.motion, value: value))
    }

    /// A considered arrival: the surface lifts and fades into place once, on
    /// first appearance, staggered by `index` when several arrive together.
    ///
    /// Runs exactly once per view identity. A value inside the surface changing
    /// later does **not** re-run it — that is the entire reason this is separate
    /// state and not a transition on the content.
    func hopArrival(index: Int = 0, isEnabled: Bool = true) -> some View {
        modifier(HopArrivalModifier(index: index, isEnabled: isEnabled))
    }

    /// Cross-fades, interpolates or rolls a value change in place instead of
    /// snapping to it. Put it on the `Text` (or small subtree) that changes, and
    /// pass the value that changes.
    func hopValueChange<V: Equatable>(_ value: V, style: HopContentChange = .crossFade) -> some View {
        modifier(HopValueChangeModifier(value: value, style: style))
    }

    /// A selection highlight that travels from the old selection to the new one
    /// rather than blinking out and in.
    ///
    /// Applied to the highlight itself, on the selected item only. Under Reduce
    /// Motion the matched geometry is dropped entirely — there is no way to
    /// cross-fade a thing sliding across the screen, so it simply does not
    /// slide, and the highlight fades in where it belongs.
    func hopSelectionHighlight(id: String, in namespace: Namespace.ID, isActive: Bool = true) -> some View {
        modifier(HopSelectionHighlightModifier(id: id, namespace: namespace, isActive: isActive))
    }
}

/// How a value replaces the one before it.
public enum HopContentChange: String, CaseIterable, Sendable {
    /// The old value fades out as the new one fades in. The default, and right
    /// for anything that is a word.
    case crossFade
    /// Digits roll. For counts and durations — a number that cross-fades to a
    /// different number reads as a glitch.
    case numeric
    /// The glyphs morph. For a label that stays the same *kind* of thing.
    case interpolate

    public func contentTransition(reduceMotion: Bool) -> ContentTransition {
        switch self {
        case .crossFade: .opacity
        case .numeric: HopAnimationToken.numericContentTransition(reduceMotion: reduceMotion)
        case .interpolate: reduceMotion ? .opacity : .interpolate
        }
    }
}

public struct HopScreenTransitionModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme
    let style: HopScreenTransition

    public func body(content: Content) -> some View {
        content.transition(style.transition(reduceMotion: theme.reduceMotion))
    }
}

public struct HopArrivalModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme
    @State private var hasArrived = false

    let index: Int
    let isEnabled: Bool

    private var isActive: Bool { isEnabled && !hasArrived }

    /// Under Reduce Motion the surface still arrives — it just arrives by
    /// becoming visible rather than by moving.
    private var lift: CGFloat { theme.reduceMotion ? 0 : 14 }
    private var depth: CGFloat { theme.reduceMotion ? 1 : 0.98 }

    public func body(content: Content) -> some View {
        content
            .offset(y: isActive ? lift : 0)
            .scaleEffect(isActive ? depth : 1)
            .opacity(isActive ? 0 : 1)
            .animation(
                HopScreenTransition.cardArrival.motion.animation(
                    reduceMotion: theme.reduceMotion,
                    index: index
                ),
                value: hasArrived
            )
            .onAppear { hasArrived = true }
    }
}

public struct HopValueChangeModifier<V: Equatable>: ViewModifier {
    @Environment(\.hopTheme) private var theme
    let value: V
    let style: HopContentChange

    public func body(content: Content) -> some View {
        content
            .contentTransition(style.contentTransition(reduceMotion: theme.reduceMotion))
            .animation(theme.animation(.parentTransition), value: value)
    }
}

public struct HopSelectionHighlightModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme
    let id: String
    let namespace: Namespace.ID
    let isActive: Bool

    @ViewBuilder
    public func body(content: Content) -> some View {
        if isActive, HopAnimationToken.allowsTravel(reduceMotion: theme.reduceMotion) {
            content.matchedGeometryEffect(id: id, in: namespace)
        } else {
            content
        }
    }
}

// MARK: - One-line page switching

/// Swaps one page for another with a named transition and its matching spring.
///
/// The whole vocabulary in one call site:
///
/// ```swift
/// HopPageSwitch(.parentPush, value: model.step) { step in
///     stepView(step)
/// }
/// ```
///
/// `value` is both the identity of the page and the thing being animated, so
/// there is no way to end up with the transition wired and the animation not.
public struct HopPageSwitch<Value: Hashable, Content: View>: View {
    @Environment(\.hopTheme) private var theme

    private let style: HopScreenTransition
    private let value: Value
    private let alignment: Alignment
    private let content: (Value) -> Content

    public init(
        _ style: HopScreenTransition,
        value: Value,
        alignment: Alignment = .center,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.style = style
        self.value = value
        self.alignment = alignment
        self.content = content
    }

    public var body: some View {
        ZStack(alignment: alignment) {
            content(value)
                .id(value)
                .transition(style.transition(reduceMotion: theme.reduceMotion))
        }
        // Clipped, so the outgoing page's parallax does not paint over whatever
        // is beside it while it slides.
        .clipped()
        .animation(theme.animation(style.motion), value: value)
    }
}

// MARK: - Previews

#if DEBUG
/// A page of flat colour with a number on it, so a transition is legible in a
/// still frame as well as in motion.
private struct HopTransitionDemoPage: View {
    @Environment(\.hopTheme) private var theme
    let index: Int

    private var tint: Color {
        switch index % 3 {
        case 0: theme.color.brandAction
        case 1: theme.color.brandSecondary
        default: theme.color.celebration
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
            .fill(HopColors.wash(tint, isDark: theme.isDark))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                    .strokeBorder(tint.opacity(0.5), lineWidth: 2)
            }
            .overlay {
                Text("Page \(index + 1)")
                    .hopTextStyle(.parentTitle)
                    .foregroundStyle(theme.color.textPrimary)
            }
    }
}

/// Steps through every transition in the vocabulary with one control.
private struct HopTransitionGallery: View {
    @Environment(\.hopTheme) private var theme
    @State private var style: HopScreenTransition = .parentPush
    @State private var page = 0

    var body: some View {
        VStack(spacing: theme.spacing.l) {
            Picker("Transition", selection: $style) {
                ForEach(HopScreenTransition.allCases, id: \.self) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 110)

            HopPageSwitch(style, value: page) { page in
                HopTransitionDemoPage(index: page)
            }
            .frame(height: 260)

            HStack(spacing: theme.spacing.m) {
                HopSecondaryButton("Back", icon: "chevron.left") { page = max(0, page - 1) }
                HopPrimaryButton("Next", icon: "chevron.right") { page += 1 }
            }

            Text(theme.reduceMotion ? "Reduce Motion: every style cross-fades." : "Full motion.")
                .hopTextStyle(.parentCaption)
                .foregroundStyle(theme.color.textSecondary)
        }
        .padding()
    }
}

#Preview("Transitions · gallery") {
    HopTransitionGallery()
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Transitions · Reduce Motion") {
    HopTransitionGallery()
        .hopBackground()
        .hopThemedRoot(reduceMotion: true)
}

#Preview("Transitions · dark") {
    HopTransitionGallery()
        .hopBackground()
        .hopThemedRoot()
        .preferredColorScheme(.dark)
}

/// Arrival and stagger, re-runnable so the staggered entrance can be watched
/// more than once without rebuilding the preview.
private struct HopArrivalGallery: View {
    @Environment(\.hopTheme) private var theme
    @State private var generation = 0

    var body: some View {
        VStack(spacing: theme.spacing.l) {
            HopPrimaryButton("Play the arrival again", icon: "arrow.clockwise") { generation += 1 }

            VStack(spacing: theme.spacing.m) {
                ForEach(0..<5, id: \.self) { index in
                    HopCard {
                        Text("Card \(index + 1)")
                            .hopTextStyle(.parentHeadline)
                            .foregroundStyle(theme.color.textPrimary)
                    }
                    .hopArrival(index: index)
                }
            }
            .id(generation)
        }
        .padding()
    }
}

#Preview("Arrival · staggered cards") {
    ScrollView { HopArrivalGallery() }
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Arrival · Reduce Motion") {
    ScrollView { HopArrivalGallery() }
        .hopBackground()
        .hopThemedRoot(reduceMotion: true)
}

/// A live-updating value, which is the case the parent dashboard actually has:
/// the number changes while the card stays exactly where it is.
private struct HopValueChangeGallery: View {
    @Environment(\.hopTheme) private var theme
    @State private var count = 6

    var body: some View {
        VStack(spacing: theme.spacing.xl) {
            HopMetricCard(value: count.formatted(), label: "Tried today", glyph: .tried, tint: theme.color.eventTried)
                .hopArrival()

            Text(count > 8 ? "A busy afternoon" : "A quiet afternoon")
                .hopTextStyle(.parentHeadline)
                .foregroundStyle(theme.color.textPrimary)
                .hopValueChange(count > 8)

            HopPrimaryButton("Add one", icon: "plus") { count += 1 }
        }
        .padding()
    }
}

#Preview("Value change · live card") {
    HopValueChangeGallery()
        .frame(maxHeight: .infinity)
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Value change · Reduce Motion") {
    HopValueChangeGallery()
        .frame(maxHeight: .infinity)
        .hopBackground()
        .hopThemedRoot(reduceMotion: true)
}
#endif
