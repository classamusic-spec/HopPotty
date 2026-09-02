import SwiftUI
import HopPottyCore

/// Hop's screen — the child's home, and the only place Child Space is entered
/// from.
///
/// ## What this screen is
///
/// Four doors, a frog, and a count of stars. `Docs/InformationArchitecture.md`
/// §1 draws the line this view sits on: everything reachable from here leads
/// somewhere good, and nothing reachable from here costs money, deletes data,
/// changes a schedule or leaves the app. That is a structural property, not a
/// matter of hiding controls — the only way out is the grown-up control in the
/// corner, and it raises the gate.
///
/// ## Why it is a cover rather than a tab
///
/// The Hop tab in `ParentRootView` is a *door*, not a pane. Selecting it
/// presents this view as a full-screen cover over the whole shell and bounces
/// the tab selection straight back, so while a child is holding the device
/// there is no tab bar, no navigation bar and no way back to the caregiver's
/// side except through the gate. A tab that merely *showed* this screen would
/// leave three other tabs one mis-tap away.
///
/// ## Reading a pause, never writing one
///
/// This view can be opened with the routine already on screen — that is what
/// `startsInRoutine` means, and `ParentRootView` decides it by reading the App
/// Group's pause record once. Nothing here shortens, extends or ends the pause:
/// it runs on its own timer and finishes on that timer whatever the child does
/// (`Docs/ChildSafety.md` §8, Contract §4.1). Finishing the routine returns the
/// child here, to Hop and their pond — not to the caregiver's dashboard.
struct HopHubView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Whether the hub opens with the guided routine already presented. Set when
    /// the app came forward during a Potty Pause.
    private let startsInRoutine: Bool
    /// Leaves Child Space. Called **only** after the grown-up gate has passed.
    private let onLeaveToGrownUps: () -> Void

    /// The lock screen's copy of a running pause.
    ///
    /// Held here rather than on `HopHubModel` on purpose: the model's whole
    /// documented job is that it is the one object a child's tap can reach that
    /// has a repository in it, and a Live Activity is not a write — it is the
    /// same picture, drawn somewhere else. Nothing below shortens, extends,
    /// cancels or inspects the pause itself.
    private let liveActivities: any LiveActivityControlling

    @State private var model: HopHubModel
    @State private var destination: ChildDestination?
    /// Where to go once the cover currently on screen has finished dismissing.
    ///
    /// SwiftUI presents one cover at a time, so a surface that wants to hand the
    /// child to another surface — Fly Snack ending at the potty, the routine
    /// asking for a grown-up — asks for it here and the dismissal handler acts
    /// on it. Swapping the item under a live cover instead produces a cover that
    /// is dismissing and presenting in the same frame.
    @State private var pendingDestination: ChildDestination?
    @State private var pendingGrownUpGate = false
    @State private var isGatePresented = false
    /// Minted when the routine opens, so every star the run earns is keyed to
    /// something that existed before anything could have gone wrong.
    @State private var routineSession = UUID()
    @State private var hasHandledInitialDestination = false

    init(
        environment: ParentEnvironment,
        startsInRoutine: Bool = false,
        onLeaveToGrownUps: @escaping () -> Void
    ) {
        self.startsInRoutine = startsInRoutine
        self.onLeaveToGrownUps = onLeaveToGrownUps
        self.liveActivities = environment.liveActivities
        _model = State(initialValue: HopHubModel(environment: environment))
    }

    var body: some View {
        ZStack {
            backdrop
            content
        }
        .hopBackground(.secondary)
        // Installed once, at the root of the child flow, exactly as
        // `ChildContext` documents. Every surface below — routine, pond, games,
        // questions — reads the same child from here and none of them reaches
        // for a repository.
        .childContext(model.context)
        .task {
            await model.load()
            openInitialDestinationIfNeeded()
        }
        .hopParentGated(isPresented: $isGatePresented) { onLeaveToGrownUps() }
        .fullScreenCover(item: $destination, onDismiss: handleCoverDismissed) { place in
            // The cover's own presentation is the arrival; this is what happens
            // when one place hands straight over to another underneath it —
            // Fly Snack ending at the potty — so the swap reads as a child page
            // change rather than as a cut.
            HopPageSwitch(.childPage, value: place) { place in
                cover(for: place)
            }
            .childContext(model.context)
        }
    }

    // MARK: - The pond, as ground rather than as a picture

    /// The child's own pond, full bleed, with whatever they have unlocked in it.
    ///
    /// Hop is drawn separately and much larger in front, so the scene's own
    /// small Hop is turned off — two frogs in one pond is one frog too many.
    /// The whole thing is inert: a decoration here is scenery, and tapping it
    /// belongs to `PondScreen`, which is a place the child chose to go.
    private var backdrop: some View {
        PondSceneView(
            unlocked: Set(model.context.pond.unlocked.keys),
            nextUp: nil,
            showsHop: false,
            isFullBleed: true,
            onTapItem: { _ in }
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            topBar
            doorsColumn
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// The star count and the way out. Both live above the scroll, because
    /// neither may ever be scrolled off: the count is the child's, and the
    /// grown-up control is the caregiver's only exit.
    private var topBar: some View {
        HStack(spacing: theme.spacing.m) {
            // A count, never a target. `HopStarBadge` says "12 stars" and
            // nothing about how many are needed for anything — the pond screen
            // is the only place a next unlock is named, and it is named as an
            // invitation.
            HopStarBadge(count: model.context.totalStars)
                // The badge's own capsule is a wash, which is designed to sit on
                // a surface rather than on open water. One opaque capsule behind
                // it keeps the number legible over any part of the pond, in
                // either appearance.
                .background { Capsule().fill(theme.color.surface.opacity(0.92)) }

            Spacer(minLength: theme.spacing.s)

            grownUpsPill
        }
        .hopPageMargins()
        .padding(.vertical, theme.spacing.m)
    }

    /// Deliberately adult-shaped: small, quiet, standard type, a 44pt target
    /// rather than a child's 72pt one. It is the one control on this screen that
    /// is not for the child, and it should not look like one of the doors.
    private var grownUpsPill: some View {
        Button {
            isGatePresented = true
        } label: {
            HStack(spacing: theme.spacing.xs) {
                Image(systemName: "person.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)
                Text(hop: HopCopy.childHub.grownUps)
                    .hopTextStyle(.parentFootnote)
                    .lineLimit(1)
            }
            .foregroundStyle(theme.color.textSecondary)
            .padding(.horizontal, theme.spacing.m)
            .padding(.vertical, theme.spacing.s)
            .background {
                Capsule().fill(theme.color.surface.opacity(0.92))
            }
            .overlay {
                Capsule().strokeBorder(
                    theme.color.divider.opacity(theme.isHighContrast ? 1 : 0.5),
                    lineWidth: theme.isHighContrast ? 1.5 : 0.75
                )
            }
            .hopHitTarget(theme.hitTarget.parent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(hop: HopCopy.childHub.grownUps))
        .accessibilityHint(Text(hop: HopCopy.childHub.grownUpsHint))
        .accessibilityAddTraits(.isButton)
    }

    /// Hop, the greeting and the four doors.
    ///
    /// It scrolls only when it has to (`.basedOnSize`), which at a default type
    /// size means the screen is a still picture rather than a list that moves
    /// under a child's finger — and at an accessibility type size means the
    /// fourth door is still reachable instead of being off the bottom.
    private var doorsColumn: some View {
        ScrollView {
            VStack(spacing: theme.spacing.xl) {
                greeting
                hopStage
                doors
            }
            .frame(maxWidth: ChildStage.contentWidth)
            .frame(maxWidth: .infinity)
            .hopPageMargins()
            .padding(.bottom, theme.spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    private var greeting: some View {
        Text(HopCopy.childHub.title.localized(forNickname: model.context.nickname))
            .hopTextStyle(.childTitle)
            .foregroundStyle(theme.color.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    /// Hop himself: he waves hello **once**, when the child arrives on his
    /// screen, and then stands there breathing and blinking on an irregular
    /// beat. The wave is a one-shot beat, not a loop, and nothing here starts a
    /// second one when nobody taps — a mascot that keeps waving is a mascot
    /// asking to be looked at (`Docs/ChildSafety.md` §1.4).
    ///
    /// Perfectly still under Reduce Motion, because `HopCharacterView` routes
    /// both the act and the ambient life through the motion tokens and those
    /// stop entirely rather than slowing down. Nothing in this view asks
    /// whether Reduce Motion is on.
    private var hopStage: some View {
        HopCharacterStage(
            act: .greeting,
            size: ChildStage.characterSize(for: horizontalSizeClass),
            // He is above the four doors, so looking down is looking at the
            // thing the child is being invited to touch.
            gaze: .down,
            describedAs: HopCopy.a11y.hopCharacter.localized
        )
    }

    private var doors: some View {
        LazyVGrid(columns: doorColumns, spacing: theme.spacing.l) {
            HopHubDoor(
                icon: .glyph(.tried, tint: theme.color.brandAction),
                title: HopCopy.childHub.pottyButton.localized,
                hint: HopCopy.childHub.pottyHint.localized
            ) {
                open(.routine)
            }

            HopHubDoor(
                icon: .glyph(.pond, tint: theme.color.brandPrimary),
                title: HopCopy.childHub.pondButton.localized,
                hint: HopCopy.childHub.pondHint.localized
            ) {
                open(.pond)
            }

            // The two optional doors. `AppSettings` lets a caregiver turn either
            // off, and a door that opens onto a screen the app then refuses to
            // draw is worse than no door — see `GamesScreen`, which expects its
            // caller to have checked.
            if model.context.settings.miniGamesEnabled {
                HopHubDoor(
                    icon: .glyph(.play, tint: theme.color.brandSecondary),
                    title: HopCopy.childHub.gamesButton.localized,
                    hint: HopCopy.childHub.gamesHint.localized
                ) {
                    open(.games)
                }
            }

            if model.context.settings.quizzesEnabled {
                HopHubDoor(
                    icon: .hopFace,
                    title: HopCopy.childHub.questionsButton.localized,
                    hint: HopCopy.childHub.questionsHint.localized
                ) {
                    open(.questions)
                }
            }
        }
    }

    /// Two columns everywhere. An iPad gets bigger doors up to the child content
    /// width and then stops: four tiles across a 1024pt window would be a toolbar.
    private var doorColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: theme.spacing.l), count: 2)
    }

    // MARK: - Where the doors lead

    @ViewBuilder
    private func cover(for destination: ChildDestination) -> some View {
        switch destination {
        case .routine:
            HubRoutineFlow(
                settings: model.context.settings,
                onFinish: { result in
                    let session = routineSession
                    Task { await model.finishRoutine(result, session: session) }
                    close()
                },
                onAskForHelp: { askForAGrownUp() },
                onStepChange: { index, count in
                    reportRoutineStep(index: index, count: count)
                }
            )

        case .pond:
            PondScreen(onLeave: close)

        case .games:
            GamesScreen(
                onFinishRound: { result in
                    Task { await model.finishGame(result) }
                    // Fly Snack's whole story is *eat, feel it, go*, so a round
                    // that reached the ending asks to be taken to the potty
                    // rather than back to the game list. The routine opens at
                    // its first step, which is also exactly what
                    // `MiniGameCompletion.handOffStep` names today — there is no
                    // start-at-step API on `PottyRoutineModel`, and none is
                    // needed while the hand-off step *is* the first step.
                    if result.handOffStep != nil {
                        pendingDestination = .routine
                        close()
                    }
                },
                onLeave: close
            )

        case .questions:
            QuizRoundView(onFinish: { result in
                Task { await model.finishQuiz(result) }
                close()
            })
        }
    }

    private func open(_ next: ChildDestination) {
        if next == .routine { routineSession = UUID() }
        destination = next
    }

    /// Moves the lock screen on when the routine changes step.
    ///
    /// Only while an activity is actually running: `isRunning` is checked here
    /// and `LiveActivityControlling.update` no-ops again for itself, because the
    /// routine is reachable from Hop's screen at any time and most runs of it
    /// have no pause behind them at all.
    ///
    /// Two numbers cross this line and nothing else. **No step title**, ever —
    /// `Docs/Widgets.md` §2 and `PottyPauseAttributes` both say why: a Live
    /// Activity is drawn on a locked screen, and the widget process already has
    /// `PottyRoutineContent` compiled in if it ever wants the words. The mood is
    /// `.cheer`, which is what `HopWidgetMood` documents as "a pause or routine
    /// is running right now" and what the activity was started with.
    private func reportRoutineStep(index: Int, count: Int) {
        guard liveActivities.isRunning else { return }
        liveActivities.update(
            stepIndex: index,
            stepCount: count,
            expectedEndAt: nil,
            mood: .cheer
        )
    }

    private func close() {
        destination = nil
    }

    /// The routine's "I need a grown-up" button, and the only other thing that
    /// raises the gate. The cover has to come down first — a sheet presented
    /// from underneath a full-screen cover has nowhere to appear.
    private func askForAGrownUp() {
        pendingGrownUpGate = true
        close()
    }

    private func handleCoverDismissed() {
        if let next = pendingDestination {
            pendingDestination = nil
            open(next)
            return
        }
        if pendingGrownUpGate {
            pendingGrownUpGate = false
            isGatePresented = true
        }
    }

    /// Opens the routine on the first appearance when the app came forward
    /// during a pause. Guarded so that a re-run of `task` — a store read that
    /// finishes late, a view that is rebuilt — cannot re-open a routine the
    /// child has already left.
    private func openInitialDestinationIfNeeded() {
        guard startsInRoutine, !hasHandledInitialDestination else { return }
        hasHandledInitialDestination = true
        open(.routine)
    }
}

/// The four places Hop's screen leads.
private enum ChildDestination: String, Identifiable, Hashable {
    case routine, pond, games, questions
    var id: String { rawValue }
}

// MARK: - The routine, and the one thing it opens on top of itself

/// Hosts `PottyRoutineView` and the pond it can raise from the celebration.
///
/// `PottyRoutineView.onOpenPond` is deliberately separate from `onFinish` so the
/// caller can decide whether the pond *replaces* the routine or sits on top of
/// it. It sits on top: replacing it would dismiss the celebration before
/// `onFinish` had run, and the run's stars would go with it. Closing the pond
/// puts the child back on the celebration, where "Back to play!" still finishes
/// the run properly.
private struct HubRoutineFlow: View {
    let settings: AppSettings
    let onFinish: (PottyRoutineResult) -> Void
    let onAskForHelp: () -> Void
    /// Passed straight through to `PottyRoutineView`, which is the only thing
    /// that knows where in the routine the child is. Zero-based index, then the
    /// number of steps.
    let onStepChange: (Int, Int) -> Void

    @State private var isShowingPond = false

    var body: some View {
        PottyRoutineView(
            settings: settings,
            onFinish: onFinish,
            onOpenPond: { isShowingPond = true },
            onAskForHelp: onAskForHelp,
            onStepChange: onStepChange
        )
        .fullScreenCover(isPresented: $isShowingPond) {
            PondScreen(onLeave: { isShowingPond = false })
        }
    }
}

// MARK: - One door

/// One of the four doors: a picture, a word, and a target a whole hand can hit.
///
/// The picture is the affordance and the word is the confirmation, never the
/// other way round — the audience is two to four years old and cannot read
/// "pond". Which is also why the four icons are four different *shapes* rather
/// than four tints of the same one.
private struct HopHubDoor: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    /// What the door shows. Hop's own face is a legitimate icon here: the
    /// questions are his, and a frog is more recognisable to a pre-reader than
    /// any question mark.
    enum Icon {
        case glyph(HopGlyph, tint: Color)
        case hopFace
    }

    let icon: Icon
    let title: String
    let hint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: theme.spacing.s) {
                mark
                Text(title)
                    .hopTextStyle(.buttonLarge)
                    .foregroundStyle(theme.color.textPrimary)
                    .multilineTextAlignment(.center)
                    // Wrapping is always allowed; truncating a door's name is not.
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(theme.spacing.l)
            .frame(maxWidth: .infinity)
            // The floor is the child *primary* target — 96pt, well above both
            // the 44pt HIG minimum and the 64pt this screen was asked for. The
            // real height is whatever the picture and the wrapped word need.
            .frame(minHeight: theme.hitTarget.childPrimary)
            .background {
                RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                    .fill(theme.color.surfaceElevated)
            }
        }
        .buttonStyle(HopHubDoorStyle())
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: theme.radius.xl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
    }

    private var markDiameter: CGFloat { 64 }

    @ViewBuilder
    private var mark: some View {
        switch icon {
        case .glyph(let glyph, let tint):
            HopGlyphBadge(glyph, tint: tint, diameter: markDiameter)
        case .hopFace:
            HopChip(diameter: markDiameter)
        }
    }
}

/// Press feedback for a door.
///
/// `.plain` would leave a child pressing a card that does not answer. The squash
/// is the child token's, which is deeper than a parent control's because the
/// feedback has to be visible at arm's length — and which collapses to nothing
/// under Reduce Motion, because `HopTheme.animation(_:)` is the one place that
/// decides.
private struct HopHubDoorStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Body(configuration: configuration)
    }

    private struct Body: View {
        @Environment(\.hopTheme) private var theme
        let configuration: ButtonStyleConfiguration

        var body: some View {
            configuration.label
                .modifier(theme.elevation(configuration.isPressed ? .flat : .raised))
                .scaleEffect(configuration.isPressed ? 0.945 : 1)
                .animation(theme.animation(.childTap), value: configuration.isPressed)
                .contentShape(RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous))
        }
    }
}

#if DEBUG
#Preview("Hop's screen · a pond with something in it") {
    HopHubView(environment: .preview(), onLeaveToGrownUps: {})
        .hopThemedRoot()
}

#Preview("Hop's screen · first launch, no name") {
    HopHubView(environment: .previewEmpty(), onLeaveToGrownUps: {})
        .hopThemedRoot()
}

#Preview("Hop's screen · Reduce Motion (Hop must be still)") {
    HopHubView(environment: .preview(), onLeaveToGrownUps: {})
        .hopThemedRoot(reduceMotion: true)
}

#Preview("Hop's screen · AX3") {
    HopHubView(environment: .preview(), onLeaveToGrownUps: {})
        .environment(\.dynamicTypeSize, .accessibility3)
        .hopThemedRoot()
}

#Preview("Hop's screen · dark") {
    HopHubView(environment: .preview(), onLeaveToGrownUps: {})
        .hopThemedRoot()
        .preferredColorScheme(.dark)
}

#Preview("Hop's screen · iPad") {
    HopHubView(environment: .preview(), onLeaveToGrownUps: {})
        .frame(width: 1024, height: 768)
        .hopThemedRoot()
}
#endif
