import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

/// What the timer stands on.
///
/// Additive, and `.card` is the default, so every caller that predates the
/// choice keeps exactly the surface it had.
public enum HopTimerCardSurface: Equatable, Sendable {
    /// An opaque `.raised` ``HopCard``. Right on a plain ground, and what the
    /// timer is everywhere except the dashboard.
    case card
    /// No surface at all: the timer stands on whatever is drawn behind it.
    /// Only the parent dashboard, where that is Hop's pond.
    case scene
}

/// The parent dashboard's focal surface: what Potty Pause is doing right now.
///
/// One number, one sentence, at most two controls. Everything else on the
/// dashboard is subordinate to this, which is why it is the only thing drawn at
/// `.raised`.
///
/// ## Standing on water
///
/// On the dashboard there is no card — the countdown sits directly on the pond
/// (``HopTimerCardSurface/scene``). A pond is not a colour: it is sky, hills and
/// water with ripples drifting across it, so the contrast the card used to
/// guarantee has to be rebuilt out of three things that are not a card.
///
/// 1. **A veil shaped like the content, not like a box** — `sceneGround`. An
///    `EllipticalGradient` of the ground's own light (`cloud` by day, `scrim` at
///    dusk) inscribed in its own box, so it reaches zero alpha on all four sides
///    and there is no edge to see. It raises the *floor* of the water under the
///    type, which is the only number WCAG measures.
/// 2. **A tight halo on the glyphs** — `HopSceneHalo`. Two short shadow passes
///    in the veil's colour, so a numeral crossing a ripple keeps its own edge.
/// 3. **Controls that carry their own ground.** A button is a surface, not a
///    card, and it is allowed one: Start Now stays the brand solid, Skip becomes
///    the frosted capsule the scene already uses for its floating chrome, and
///    the status pill — a *wash*, which over water is a wash over whatever the
///    water happens to be doing there — gets an opaque capsule under it.
///
/// Measured against the rendered pond (`Scripts/screens/parent.js` carries the
/// table), the worst ground pixel leaves the countdown at 8.2:1 or better and
/// every small run at 5.1:1 or better, in both appearances, against WCAG AA
/// floors of 3.0 and 4.5.
///
/// **Increased contrast opts out of all of it.** A soft veil is precisely what
/// that setting exists to remove, so `.scene` draws an opaque surface with a
/// hairline instead, and the halos switch off. The one caregiver who has asked
/// the system for hard edges gets hard edges.
public struct HopTimerCard: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let state: PottyPauseDisplayState
    private let surface: HopTimerCardSurface
    private let onSkip: () -> Void
    private let onStartNow: () -> Void

    public init(
        state: PottyPauseDisplayState,
        surface: HopTimerCardSurface = .card,
        onSkip: @escaping () -> Void,
        onStartNow: @escaping () -> Void
    ) {
        self.state = state
        self.surface = surface
        self.onSkip = onSkip
        self.onStartNow = onStartNow
    }

    @ViewBuilder
    public var body: some View {
        switch surface {
        case .card:
            HopCard(elevation: .raised) {
                VStack(alignment: .leading, spacing: theme.spacing.xl) {
                    header
                    dial
                    actions
                }
            }
        case .scene:
            sceneBody
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .hopTextStyle(.parentHeadline)
                    .foregroundStyle(theme.color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if let childName = state.childName {
                    Text(childName)
                        .hopTextStyle(.parentCaption)
                        .foregroundStyle(theme.color.textSecondary)
                }
            }

            Spacer(minLength: theme.spacing.s)

            if let pill = statusPill {
                HopPill(pill.text, tint: pill.tint, glyph: pill.glyph)
            }
        }
    }

    private var headline: String {
        switch state.phase {
        case .off: HopStrings.timerPaused
        case .counting, .approaching: HopStrings.timerNextPause
        case .pausing: HopStrings.timerPauseRunning
        case .cooldown: HopStrings.timerCooldown
        case .needsAttention, .needsAttentionAccessRestored: HopStrings.timerNeedsAttention
        }
    }

    private var statusPill: (text: String, tint: Color, glyph: HopGlyph)? {
        switch state.phase {
        case .approaching:
            (HopStrings.timerApproaching, theme.color.warning, .timer)
        case .pausing:
            state.isHoldingApps
                ? (HopStrings.timerAppsPaused, theme.color.brandAction, .shield)
                : (HopStrings.timerPauseRunning, theme.color.brandAction, .pause)
        case .needsAttentionAccessRestored:
            // Says the reassuring half out loud: whatever went wrong, the child
            // is not locked out of anything.
            (HopStrings.timerAppsBack, theme.color.success, .check)
        case .needsAttention:
            (HopStrings.timerNeedsAttention, theme.color.warning, .shield)
        case .off, .counting, .cooldown:
            nil
        }
    }

    // MARK: - Dial

    private var dialTint: Color {
        switch state.phase {
        case .approaching: theme.color.warning
        case .needsAttention, .needsAttentionAccessRestored: theme.color.warning
        case .off: theme.color.neutral
        default: theme.color.brandAction
        }
    }

    @ViewBuilder
    private var dial: some View {
        if let remaining = state.remaining {
            HStack(spacing: theme.spacing.xl) {
                ZStack {
                    HopProgressRing(progress: state.progress ?? 0, lineWidth: 10, tint: dialTint)
                    HopGlyphView(state.phase.isPausing ? .pause : .timer, size: 22)
                        .foregroundStyle(dialTint)
                }
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    Text(HopDurationFormat.glanceable(remaining))
                        .hopTextStyle(.timer, allowsTightening: false)
                        .foregroundStyle(theme.color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(HopStrings.timerRemaining)
                        .hopTextStyle(.parentCaption)
                        .foregroundStyle(theme.color.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.phase.isPausing ? HopStrings.timerRemainingLabel : HopStrings.timerUntilNextLabel)
            .accessibilityValue(HopDurationFormat.spoken(remaining))
        } else {
            Text(detail)
                .hopTextStyle(.parentBody)
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var detail: String {
        switch state.phase {
        case .off: HopStrings.timerOffDetail
        case .cooldown: HopStrings.timerCooldownDetail
        case .needsAttention(let failure), .needsAttentionAccessRestored(let failure): failure.recoveryMessage
        case .counting, .approaching, .pausing: HopStrings.timerNoCountdown
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        if state.allowsManualControl {
            // Stacked at accessibility sizes: two buttons side by side at AX5
            // leaves about four characters each.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.m) {
                    HopSecondaryButton(HopStrings.skip, action: onSkip)
                    HopPrimaryButton(HopStrings.startNow, icon: "play.fill", action: onStartNow)
                }
                VStack(spacing: theme.spacing.m) {
                    HopPrimaryButton(HopStrings.startNow, icon: "play.fill", action: onStartNow)
                    HopSecondaryButton(HopStrings.skip, action: onSkip)
                }
            }
        } else if case .off = state.phase {
            HopPrimaryButton(HopStrings.startNow, icon: "play.fill", action: onStartNow)
        }
    }
}

// MARK: - On the scene

extension HopTimerCard {
    /// The same content with its card taken away: centred, because a countdown
    /// with nothing behind it has no left edge to hang off, and stacked so the
    /// number is the widest thing on the water.
    private var sceneBody: some View {
        VStack(spacing: theme.spacing.l) {
            sceneHeader
            sceneDial
            sceneActions
        }
        .frame(maxWidth: .infinity)
        .background { sceneGround }
    }

    /// The heading, whose child it is about, and the one status token.
    ///
    /// The token keeps its ``HopPill`` — the shape, the glyph and the tint are
    /// how a caregiver recognises it everywhere else — but gains an opaque
    /// capsule beneath. `HopPill` is a *wash*, and a wash over water is a wash
    /// over whatever the water is doing there; `warning` and `neutral` are both
    /// mid-luminance tints that fall under 4.5:1 against lit water however hard
    /// the veil pushes. Giving the token its own ground puts it back on the
    /// composite the contrast tests already cover.
    private var sceneHeader: some View {
        VStack(spacing: theme.spacing.xxs) {
            Text(headline)
                .hopTextStyle(.parentHeadline)
                .foregroundStyle(theme.color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .modifier(HopSceneHalo(theme: theme))

            if let childName = state.childName {
                Text(childName)
                    .hopTextStyle(.parentCaption)
                    .foregroundStyle(theme.color.textSecondary)
                    .modifier(HopSceneHalo(theme: theme))
            }

            if let pill = statusPill {
                HopPill(pill.text, tint: pill.tint, glyph: pill.glyph)
                    .background { Capsule().fill(theme.color.surfaceElevated) }
                    .padding(.top, theme.spacing.xs)
            }
        }
    }

    /// The ring and the number, centred as one group.
    ///
    /// Same content as the card's `dial`, same one spoken sentence — only the
    /// axis changed, so "remaining" sits under the number instead of beside the
    /// ring. Dynamic Type behaviour is untouched: the number still refuses to
    /// tighten and still scales down rather than wrapping, and every label
    /// around it grows.
    @ViewBuilder
    private var sceneDial: some View {
        if let remaining = state.remaining {
            VStack(spacing: 0) {
                HStack(spacing: theme.spacing.m) {
                    ZStack {
                        HopProgressRing(progress: state.progress ?? 0, lineWidth: 8, tint: dialTint)
                        HopGlyphView(state.phase.isPausing ? .pause : .timer, size: 18)
                            .foregroundStyle(dialTint)
                    }
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)

                    Text(HopDurationFormat.glanceable(remaining))
                        .hopTextStyle(.timer, allowsTightening: false)
                        .foregroundStyle(theme.color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .modifier(HopSceneHalo(theme: theme))
                }

                Text(HopStrings.timerRemaining)
                    .hopTextStyle(.parentCaption)
                    .foregroundStyle(theme.color.textSecondary)
                    .modifier(HopSceneHalo(theme: theme))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.phase.isPausing ? HopStrings.timerRemainingLabel : HopStrings.timerUntilNextLabel)
            .accessibilityValue(HopDurationFormat.spoken(remaining))
        } else {
            Text(detail)
                .hopTextStyle(.parentBody)
                .foregroundStyle(theme.color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(HopSceneHalo(theme: theme))
        }
    }

    /// The same two actions, in the same order, stacking at accessibility sizes
    /// for the same reason.
    @ViewBuilder
    private var sceneActions: some View {
        if state.allowsManualControl {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.m) {
                    sceneSkip
                    sceneStartNow
                }
                VStack(spacing: theme.spacing.m) {
                    sceneStartNow
                    sceneSkip
                }
            }
        } else if case .off = state.phase {
            sceneStartNow
        }
    }

    private var sceneSkip: some View {
        HopSceneActionButton(title: HopStrings.skip, icon: nil, role: .secondary, action: onSkip)
    }

    private var sceneStartNow: some View {
        HopSceneActionButton(title: HopStrings.startNow, icon: "play.fill", role: .primary, action: onStartNow)
    }

    /// The veil: the whole of the card's job, done without a card.
    ///
    /// `endRadiusFraction: 0.5` is load-bearing rather than decorative. An
    /// ellipse wider than the box it is drawn in gets cut off by that box, and a
    /// gradient still opaque where it is cut is a rectangle with a visible edge
    /// — which is the card this screen just removed. At 0.5 the ellipse is
    /// inscribed, so the veil reaches zero alpha on every side and there is
    /// nothing to see an edge of.
    ///
    /// The negative padding hangs the box 56 above the content and 8 below it,
    /// which puts the ellipse's centre on the numerals rather than in the middle
    /// of the block: the heading, the countdown and the status all live in the
    /// top of the stack, and the buttons below carry their own fill.
    @ViewBuilder
    private var sceneGround: some View {
        if theme.isHighContrast {
            // Increased contrast is the setting that exists to remove soft
            // edges. It gets a real surface and a real hairline.
            RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                .fill(theme.color.surfaceElevated)
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                        .strokeBorder(theme.color.divider, lineWidth: 1.5)
                }
                .padding(-theme.spacing.l)
        } else {
            EllipticalGradient(
                stops: HopSceneVeil.stops(tone: HopSceneVeil.tone(theme), isDark: theme.isDark),
                center: .center,
                startRadiusFraction: 0,
                endRadiusFraction: 0.5
            )
            .padding(.horizontal, -60)
            .padding(.top, -56)
            .padding(.bottom, -8)
            .allowsHitTesting(false)
        }
    }
}

/// The two colours and five stops the scene's veil and halo share.
///
/// One place, because the halo only works when it is made of the same light the
/// veil is: a white glow over a darkened pond, or a black one over a lit pond,
/// would read as an outline rather than as air.
private enum HopSceneVeil {
    static func tone(_ theme: HopTheme) -> Color {
        // `cloud` by day and `scrim` at dusk — both already in the pond, so
        // neither reads as a new material laid over it.
        theme.isDark ? theme.color.scrim : Color(HopPalette.cloud)
    }

    static func stops(tone: Color, isDark: Bool) -> [Gradient.Stop] {
        let core = isDark ? 0.46 : 0.66
        return [
            Gradient.Stop(color: tone.opacity(core), location: 0),
            Gradient.Stop(color: tone.opacity(core * 0.88), location: 0.30),
            Gradient.Stop(color: tone.opacity(core * 0.56), location: 0.55),
            Gradient.Stop(color: tone.opacity(core * 0.20), location: 0.78),
            Gradient.Stop(color: tone.opacity(0), location: 1),
        ]
    }
}

/// A tight halo behind one run of glyphs, in the veil's own colour.
///
/// Two passes, both short: one at radius 1 to give the letterform an edge, one
/// at radius 6 to lift it off a ripple. Deliberately not a drop shadow — there
/// is no offset worth speaking of, because the point is to thicken the ground
/// immediately around the glyph, not to make the text look raised.
///
/// Off in increased contrast, where the block has a real surface and a glow
/// around type on an opaque ground is noise.
private struct HopSceneHalo: ViewModifier {
    let theme: HopTheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if theme.isHighContrast {
            content
        } else {
            content
                .shadow(color: HopSceneVeil.tone(theme).opacity(theme.isDark ? 0.60 : 0.95), radius: 1, y: 1)
                .shadow(color: HopSceneVeil.tone(theme).opacity(theme.isDark ? 0.55 : 0.85), radius: 6)
        }
    }
}

/// One of the two actions under the countdown, drawn to survive water.
///
/// Both roles are real controls with real fills — a button is a surface, which
/// is not the card the countdown lost — but they are deliberately not the same
/// surface:
///
/// - **primary** is the brand solid at `.raised`, text on brand. It would read
///   over anything, and it is the action a caregiver reaches for.
/// - **secondary** is the one that had to change. A tonal wash on a hairline is
///   invisible on a pond, so Skip becomes the frosted capsule with the same
///   fill, material and hairline `HomeScenePill` uses along the top of the same
///   scene — this screen's existing language for a control floating on water.
///   Quieter than the primary, and never faint: it is a real action a caregiver
///   needs, and it measures 7.1:1 or better in both appearances.
///
/// Built on ``HopBareButtonStyle`` with the parent press feel rather than a new
/// style, so the press, the hit target, the disabled dim and the focus ring all
/// come from the same place every other button in the app gets them.
private struct HopSceneActionButton: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    enum Role { case primary, secondary }

    let title: String
    let icon: String?
    let role: Role
    let action: () -> Void

    private var shape: Capsule { Capsule(style: .continuous) }

    private var fill: Color {
        switch role {
        case .primary: theme.color.brandAction
        case .secondary: theme.color.surface.opacity(theme.isHighContrast ? 1 : (theme.isDark ? 0.80 : 0.88))
        }
    }

    private var foreground: Color {
        switch role {
        case .primary: theme.color.textOnBrand
        case .secondary: theme.color.textSecondary
        }
    }

    private var border: Color? {
        switch role {
        case .primary: nil
        case .secondary: theme.color.divider.opacity(theme.isHighContrast ? 1 : 0.5)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.s) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        // Decorative: the title beside it carries the meaning.
                        .accessibilityHidden(true)
                }
                Text(title)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .hopTextStyle(.parentHeadline)
            .padding(.horizontal, theme.spacing.l)
            .padding(.vertical, theme.spacing.s)
            .frame(maxWidth: .infinity, minHeight: theme.hitTarget.parent)
            .background { shape.fill(fill) }
            // Behind the fill, so a translucent secondary frosts the water and
            // an opaque primary simply covers it.
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                if let border {
                    shape.strokeBorder(border, lineWidth: theme.isHighContrast ? 1.5 : 1)
                }
            }
            .modifier(theme.elevation(role == .primary ? .raised : .resting))
        }
        .buttonStyle(HopBareButtonStyle(minimumTarget: theme.hitTarget.parent, tint: foreground, feel: .parent))
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: theme.hitTarget.parent / 2)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

private extension PottyPauseDisplayState.Phase {
    var isPausing: Bool {
        if case .pausing = self { return true }
        return false
    }
}

#if DEBUG
#Preview("Timer card · states") {
    ScrollView {
        VStack(spacing: 20) {
            HopTimerCard(
                state: PottyPauseDisplayState(phase: .counting, mode: .pause, remaining: 1_845, total: 2_700, childName: "Sam"),
                onSkip: {}, onStartNow: {}
            )
            HopTimerCard(
                state: PottyPauseDisplayState(phase: .approaching, mode: .routine, remaining: 118, total: 2_700, childName: "Sam"),
                onSkip: {}, onStartNow: {}
            )
            HopTimerCard(
                state: PottyPauseDisplayState(phase: .pausing, mode: .pause, remaining: 245, total: 300, childName: "Sam"),
                onSkip: {}, onStartNow: {}
            )
            HopTimerCard(
                state: PottyPauseDisplayState(phase: .off, mode: .gentle, childName: "Sam"),
                onSkip: {}, onStartNow: {}
            )
            HopTimerCard(
                state: PottyPauseDisplayState(pauseState: .errorAccessRestored(.shieldApplyFailed), mode: .pause, childName: "Sam"),
                onSkip: {}, onStartNow: {}
            )
        }
        .padding()
    }
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Timer card · AX3") {
    ScrollView {
        HopTimerCard(
            state: PottyPauseDisplayState(phase: .counting, mode: .pause, remaining: 1_845, total: 2_700, childName: "Maya"),
            onSkip: {}, onStartNow: {}
        )
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Timer card · dark") {
    HopTimerCard(
        state: PottyPauseDisplayState(phase: .pausing, mode: .routine, remaining: 245, total: 300, childName: "Sam"),
        onSkip: {}, onStartNow: {}
    )
    .padding()
    .frame(maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
    .preferredColorScheme(.dark)
}

/// A stand-in for the pond: the two hues the dashboard's water actually runs
/// between, in the same order, so the veil and the halos can be judged without
/// pulling a feature's scene into a design-system preview. The real thing is in
/// `ParentHomeView`'s previews.
private struct ScenePreviewGround<Content: View>: View {
    var appearance: HopAppearance = .light
    @ViewBuilder var content: Content

    var body: some View {
        LinearGradient(
            colors: [
                Color(HopPalette.hopGreenLight),
                Color(HopPalette.pondBlueLight),
                Color(HopPalette.pondBlue),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay {
            content
                .padding(.horizontal, 20)
        }
        .frame(width: 393, height: 420)
        .hopThemedRoot(appearance: appearance)
    }
}

#Preview("Timer · on a scene") {
    ScenePreviewGround {
        HopTimerCard(
            state: PottyPauseDisplayState(phase: .counting, mode: .routine, remaining: 1_694, total: 2_700, childName: "Maya"),
            surface: .scene,
            onSkip: {}, onStartNow: {}
        )
    }
}

#Preview("Timer · on a scene, a pause is close") {
    ScenePreviewGround {
        HopTimerCard(
            state: PottyPauseDisplayState(phase: .approaching, mode: .routine, remaining: 118, total: 2_700, childName: "Maya"),
            surface: .scene,
            onSkip: {}, onStartNow: {}
        )
    }
}

#Preview("Timer · on a scene, dark") {
    ScenePreviewGround(appearance: .dark) {
        HopTimerCard(
            state: PottyPauseDisplayState(phase: .counting, mode: .routine, remaining: 1_694, total: 2_700, childName: "Maya"),
            surface: .scene,
            onSkip: {}, onStartNow: {}
        )
    }
}

// The veil and the halos are gone here and a real surface has taken their
// place. That is the point of the preview: increased contrast is the one
// setting that gets its card back.
#Preview("Timer · on a scene, increased contrast") {
    ScenePreviewGround(appearance: .lightHighContrast) {
        HopTimerCard(
            state: PottyPauseDisplayState(phase: .counting, mode: .routine, remaining: 1_694, total: 2_700, childName: "Maya"),
            surface: .scene,
            onSkip: {}, onStartNow: {}
        )
    }
}

#Preview("Timer · on a scene, AX3") {
    ScenePreviewGround {
        HopTimerCard(
            state: PottyPauseDisplayState(phase: .counting, mode: .routine, remaining: 1_694, total: 2_700, childName: "Maya"),
            surface: .scene,
            onSkip: {}, onStartNow: {}
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Timer card · iPad, high contrast") {
    HopTimerCard(
        state: PottyPauseDisplayState(phase: .counting, mode: .pause, remaining: 3_845, total: 5_400, childName: "Sam"),
        onSkip: {}, onStartNow: {}
    )
    .hopPageMargins()
    .hopReadableWidth()
    .frame(width: 834, height: 400)
    .hopBackground()
    .hopThemedRoot(appearance: .lightHighContrast)
}
#endif
