import SwiftUI
import HopPottyCore

/// The bathroom, with three places in it and three things to put there.
///
/// ## Big, and drawn rather than labelled
///
/// Every piece on this board is a large illustration and nothing else: no title
/// on a tile, no caption under one, no badge in a corner. A two-year-old picks
/// the soap up because it looks like soap. The words exist for VoiceOver and for
/// the adult sitting alongside, which is why they are labels and hints rather
/// than text on the board.
///
/// ## What a wrong place looks like
///
/// It looks like nothing. The object springs back to its shelf on the child
/// motion token and Hop says "Almost! Try another spot." once. There is no red,
/// no cross, no shake, no buzz, no counter and nothing that could ever be summed
/// into a score — see `Docs/ChildSafety.md`, and see `BathroomMatchSession`,
/// which has no API that could record one.
///
/// A correct place is a soft haptic through ``EnvironmentValues/hopButtonFeedback``
/// (the design system's seam to `Services/Haptics`, so the caregiver's
/// `hapticsEnabled` switch still governs it), the object settling into place at
/// its destination, and Hop noticing.
struct BathroomMatchGameView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.hopButtonFeedback) private var buttonFeedback

    let session: BathroomMatchSession

    /// The object currently under a finger, and how far it has travelled.
    @State private var carrying: String?
    @State private var carryOffset: CGSize = .zero
    /// The object that has just sprung back, so exactly one piece bounces.
    @State private var returning: String?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let destinationHeight = size.height * 0.46

            ZStack(alignment: .top) {
                room

                VStack(spacing: 0) {
                    destinationsRow
                        .frame(height: destinationHeight)
                    // The board's geometry is captured here, where it is known,
                    // rather than stashed in state for the drop handler to read
                    // later — a size in `@State` is a size that can be one layout
                    // out of date exactly when a finger lifts.
                    shelf(dropping: { object, location in
                        drop(object, at: location, in: size, destinationHeight: destinationHeight)
                    })
                    .frame(maxHeight: .infinity)
                }

                hopAside
            }
            .coordinateSpace(name: matchBoardSpace)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.hero, style: .continuous))
        .hopAnimation(.childArrive, value: session.boardsCleared)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(session.game.childDescription.localized)
    }

    /// The room the things belong in. Decorative — everything on it is labelled.
    private var room: some View {
        HopArtwork(session.game.illustration)
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .accessibilityHidden(true)
    }

    // MARK: - Where things go

    private var destinationsRow: some View {
        HStack(spacing: theme.spacing.m) {
            ForEach(session.destinations) { destination in
                MatchDestinationView(destination: destination)
            }
        }
        .padding(theme.spacing.m)
    }

    // MARK: - What there is to carry

    private func shelf(
        dropping onDrop: @escaping (BathroomMatchSession.Object, CGPoint) -> Void
    ) -> some View {
        VStack(spacing: theme.spacing.s) {
            Text(instruction)
                .hopTextStyle(.childInstruction)
                .foregroundStyle(theme.color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, theme.spacing.l)
                .padding(.vertical, theme.spacing.xs)
                .background(Capsule().fill(theme.color.surface.opacity(0.92)))

            HStack(spacing: theme.spacing.m) {
                ForEach(session.objects) { object in
                    MatchObjectView(
                        object: object,
                        isCarried: carrying == object.id,
                        isReturning: returning == object.id,
                        offset: carrying == object.id ? carryOffset : .zero,
                        onPickUp: { carrying = object.id },
                        onMove: { carryOffset = $0 },
                        onDrop: { location in onDrop(object, location) }
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacing.m)
            .background {
                RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                    .fill(theme.color.surface.opacity(0.9))
            }
        }
        .padding(theme.spacing.m)
    }

    /// What Hop is saying. The nudge until something happens, then his one line
    /// about it — and back to the nudge.
    private var instruction: String {
        switch session.lastAnswer {
        case .landed: GameCopy.matched.localized
        case .returned: GameCopy.matchAlmost.localized
        case nil: GameCopy.matchNudge.localized
        }
    }

    /// Hop, at the side, watching. He is delighted when something lands and
    /// thoughtful when something comes back — never disappointed, because there
    /// is nothing here to be disappointed about.
    private var hopAside: some View {
        HopCharacterStage(
            act: hopAct,
            size: 84,
            gaze: .down,
            describedAs: ""
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(theme.spacing.s)
        .allowsHitTesting(false)
    }

    private var hopAct: HopAct {
        switch session.lastAnswer {
        case .landed: .delighted()
        case .returned: .speaking()
        case nil: .idle
        }
    }

    // MARK: - Carrying and dropping

    private func drop(
        _ object: BathroomMatchSession.Object,
        at location: CGPoint,
        in size: CGSize,
        destinationHeight: CGFloat
    ) {
        defer {
            carrying = nil
            carryOffset = .zero
        }

        guard let destination = destination(at: location, in: size, destinationHeight: destinationHeight) else {
            session.returnToShelf(object)
            springBack(object)
            return
        }

        if session.place(object, on: destination) {
            // The one haptic on this board, and it goes through the design
            // system's seam rather than a generator, so `hapticsEnabled` still
            // governs it.
            buttonFeedback.play(.confirmation)
            announce(GameCopy.matched.localized)
        } else {
            springBack(object)
            announce(GameCopy.matchAlmost.localized)
        }
        clearAnswerShortly()
    }

    /// The gentle bounce back. One object at a time, and it says nothing.
    private func springBack(_ object: BathroomMatchSession.Object) {
        returning = object.id
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            if returning == object.id { returning = nil }
        }
    }

    private func clearAnswerShortly() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            session.acknowledgeAnswer()
        }
    }

    private func announce(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }

    // MARK: - Hit testing

    /// Which destination a drop landed on, if any.
    ///
    /// The destinations are equal columns across the top band, so the test is
    /// two comparisons and a division. No preference keys, no anchor
    /// bookkeeping, and nothing that can go stale when the board reshuffles.
    private func destination(
        at location: CGPoint,
        in size: CGSize,
        destinationHeight: CGFloat
    ) -> BathroomMatchSession.Destination? {
        guard location.y <= destinationHeight, size.width > 0 else { return nil }
        let count = max(1, session.destinations.count)
        let column = Int(location.x / (size.width / CGFloat(count)))
        guard column >= 0, column < session.destinations.count else { return nil }
        return session.destinations[column]
    }
}

/// The board's coordinate space. Named once, so the drag that reports a point
/// and the code that interprets it cannot disagree about which origin it is in.
private let matchBoardSpace = "bathroomMatchBoard"

// MARK: - One place

/// A destination: a large, quiet picture of somewhere a thing belongs.
///
/// Empty and filled are drawn as two different pictures — a dashed ring waiting,
/// and the object sitting there — plus a spoken value, so the state never rests
/// on a colour. Nothing about an empty destination reads as missing or wrong.
private struct MatchDestinationView: View {
    @Environment(\.hopTheme) private var theme

    let destination: BathroomMatchSession.Destination

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                .fill(theme.color.surface.opacity(0.86))

            VStack(spacing: theme.spacing.xs) {
                HopArtwork(destination.illustration)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let holds = destination.holds {
                    HopArtwork(holds)
                        .frame(height: 34)
                        .hopTransition(.childArrive)
                }
            }
            .padding(theme.spacing.m)
        }
        .overlay {
            RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                .strokeBorder(
                    destination.isFilled ? theme.color.success : theme.color.brandAction.opacity(0.55),
                    style: StrokeStyle(
                        lineWidth: destination.isFilled ? 3 : 2.5,
                        dash: destination.isFilled ? [] : [8, 7]
                    )
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: theme.hitTarget.childPrimary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(destination.label.localized)
        .modifier(MatchFilledValue(isFilled: destination.isFilled))
    }
}

/// Adds the spoken state only when there is one to add.
private struct MatchFilledValue: ViewModifier {
    let isFilled: Bool

    func body(content: Content) -> some View {
        if isFilled {
            content.accessibilityValue(GameCopy.matched.localized)
        } else {
            content
        }
    }
}

// MARK: - One thing to carry

/// A draggable object: one big picture, and nothing else on it.
private struct MatchObjectView: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    let object: BathroomMatchSession.Object
    let isCarried: Bool
    let isReturning: Bool
    let offset: CGSize
    let onPickUp: () -> Void
    let onMove: (CGSize) -> Void
    let onDrop: (CGPoint) -> Void

    private var side: CGFloat { max(theme.hitTarget.childPrimary, 96) }

    var body: some View {
        HopArtwork(object.illustration)
            .padding(theme.spacing.s)
            .frame(width: side, height: side)
            .background {
                RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                    .fill(theme.color.surfaceElevated)
            }
            .modifier(theme.elevation(isCarried ? .floating : .resting))
            // A placed object leaves the shelf entirely rather than being greyed
            // out: it is not disabled, it is somewhere else now.
            .opacity(object.isPlaced ? 0 : 1)
            .scaleEffect(isCarried ? 1.08 : (isReturning ? 0.94 : 1))
            .offset(offset)
            .hopAnimation(.childTap, value: isCarried)
            .hopAnimation(.childArrive, value: isReturning)
            .gesture(carry)
            .disabled(object.isPlaced)
            .focused($isFocused)
            .hopFocusRing(isFocused, cornerRadius: theme.radius.xl)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(object.label.localized)
            .accessibilityHint(GameCopy.matchHint.localized)
            .accessibilityAddTraits(.isButton)
    }

    /// Pick up, carry, put down. `minimumDistance` is zero so a two-year-old's
    /// press-and-shove registers as a carry from the first pixel.
    private var carry: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(matchBoardSpace))
            .onChanged { value in
                if !isCarried { onPickUp() }
                onMove(value.translation)
            }
            .onEnded { value in
                onDrop(value.location)
            }
    }
}

#Preview("Bathroom Match · fresh board") {
    BathroomMatchHostPreview(session: BathroomMatchSession())
}

#Preview("Bathroom Match · one thing placed") {
    BathroomMatchHostPreview(session: {
        let session = BathroomMatchSession()
        if let object = session.objects.first,
           let destination = session.destinations.first(where: { $0.pairID == object.pairID }) {
            session.place(object, on: destination)
        }
        return session
    }())
}

#Preview("Bathroom Match · something came back") {
    BathroomMatchHostPreview(session: {
        let session = BathroomMatchSession()
        if let object = session.objects.first,
           let other = session.destinations.first(where: { $0.pairID != object.pairID }) {
            session.place(object, on: other)
        }
        return session
    }())
}

#Preview("Bathroom Match · AX3") {
    BathroomMatchHostPreview(session: BathroomMatchSession())
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Bathroom Match · iPad") {
    BathroomMatchHostPreview(session: BathroomMatchSession())
        .frame(width: 1024, height: 768)
}

private struct BathroomMatchHostPreview: View {
    @State var session: BathroomMatchSession
    var reduceMotion: Bool? = nil

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: {}
        ) {
            BathroomMatchGameView(session: session)
        }
        .hopThemedRoot(reduceMotion: reduceMotion)
    }
}

#Preview("Bathroom Match · Reduce Motion") {
    BathroomMatchHostPreview(session: BathroomMatchSession(), reduceMotion: true)
}
