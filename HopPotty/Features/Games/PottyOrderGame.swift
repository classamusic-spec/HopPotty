import SwiftUI
import HopPottyCore

/// The path with four spots on it, and the cards that go there.
///
/// Two ways to play the same board, because a two-year-old's finger and a
/// three-year-old's finger are not the same instrument: **drag** a card onto a
/// spot, or **tap** it to pick it up and tap the spot. Both routes end in
/// ``PottyOrderSession/place(_:intoSlot:)``, so a child who cannot yet drag —
/// and a child using VoiceOver or Switch Control — plays the whole game rather
/// than a described version of it.
///
/// ## A card that does not fit
///
/// It goes home. The spring the drag settles on is the whole of the feedback:
/// a small wobble as it lands back in the tray, a two-and-a-half degree tilt
/// while Hop repeats the same warm invitation the quizzes use, and then
/// nothing. No red, no shake, no sound, no counter, and the card can be tried
/// again in the same second. Under Reduce Motion the token turns the settle
/// into a cross-fade, so the card arrives home without travelling.
///
/// ## The board is laid out, not flowed
///
/// Four spots across the top and the tray across the bottom, placed by
/// arithmetic in the scene's own coordinates — the same way every other board
/// here places its pieces. That is also what makes the drop test honest: a
/// dropped card's landing point is its own centre plus the drag's translation,
/// and the spot it landed on is the spot whose rectangle contains that point.
/// No coordinate spaces, no preference keys, nothing that can silently stop
/// matching what is drawn.
struct PottyOrderGameView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let session: PottyOrderSession

    var body: some View {
        GameScene(
            key: session.game.illustration,
            label: (session.game.intro ?? session.game.childDescription).localized
        ) { size in
            let layout = BoardLayout(
                size: size,
                slotCount: PottyOrderSession.cards.count,
                gap: theme.spacing.s,
                inset: theme.spacing.s
            )

            ZStack {
                ForEach(0..<layout.slotCount, id: \.self) { index in
                    slot(index, layout: layout)
                        .position(layout.slotCentre(index))
                }

                hop(in: size)

                ForEach(session.tray) { card in
                    trayCard(card, layout: layout)
                }
            }
            .hopAnimation(.childArrive, value: session.placements)
        }
        .overlay(alignment: .bottom) { spokenLine }
        .gameClock(session)
    }

    // MARK: - The path

    private func slot(_ index: Int, layout: BoardLayout) -> some View {
        OrderSlotView(
            expects: session.card(forSlot: index),
            holds: session.placed[index],
            size: layout.cardSize,
            // A spot only becomes a control when there is something in hand to
            // put on it. An empty spot with nothing held is scenery, and
            // scenery a child taps by accident stays quiet rather than saying no.
            isOffered: session.held != nil && session.placed[index] == nil,
            onTap: { session.placeHeld(intoSlot: index) }
        )
    }

    // MARK: - The tray

    private func trayCard(_ card: GameCopy.OrderCard, layout: BoardLayout) -> some View {
        let position = session.tray.firstIndex(of: card) ?? 0
        let centre = layout.trayCentre(position, of: session.tray.count)

        return TrayCardView(
            card: card,
            size: layout.cardSize,
            isHeld: session.held == card,
            isRebuffed: session.rebuffed == card,
            onTap: { session.pickUp(card) },
            onDrop: { translation in drop(card, from: centre, by: translation, layout: layout) }
        )
        .position(centre)
        // The tray closes up when a card leaves it; the remaining cards slide
        // along rather than jumping.
        .hopAnimation(.childArrive, value: centre)
        .hopTransition(.childArrive)
    }

    /// Where a released card landed, and whether that was a spot.
    ///
    /// A card let go over the pond rather than over a spot simply goes home
    /// without comment: not every gesture a child makes is an answer, and
    /// treating a fumble as one would be the one unkind thing on this board.
    private func drop(
        _ card: GameCopy.OrderCard,
        from centre: CGPoint,
        by translation: CGSize,
        layout: BoardLayout
    ) {
        let landing = CGPoint(x: centre.x + translation.width, y: centre.y + translation.height)
        guard let index = (0..<layout.slotCount).first(where: { layout.slotRect($0).contains(landing) }) else {
            return
        }
        session.place(card, intoSlot: index)
    }

    // MARK: - Hop

    /// Hop watches, and cheers when the path is finished. He is decorative
    /// here — the cards carry the meaning and the line below says what he
    /// says — and he never takes a drop, so a card released over him still
    /// reaches the spot behind him.
    private func hop(in size: CGSize) -> some View {
        // Small: he sits in the band between the path and the tray, and neither
        // row may have to move over for him.
        let side = min(min(size.width, size.height) * 0.24, ChildStage.characterSize(for: horizontalSizeClass) * 0.5)
        return HopCharacterStage(pose: session.isPathComplete ? .cheer : .talk, size: side, describedAs: "")
            .position(x: size.width * 0.5, y: size.height * 0.51)
            .hopAnimation(.childCelebrate, value: session.isPathComplete)
            .allowsHitTesting(false)
    }

    // MARK: - What Hop says

    private var spokenLine: some View {
        HopSpokenLine(line, pulse: session.placements + session.nudges)
            .padding(.horizontal, theme.spacing.l)
            .padding(.bottom, theme.spacing.m)
    }

    private var line: HopPottyCore.HopVoiceLine {
        if session.isPathComplete { return session.game.line("done") }
        // The same sentence every time, however many tries: a child who has
        // just been redirected hears an invitation, never a verdict.
        if session.rebuffed != nil { return session.game.line("retry") }
        return session.placements == 0 ? session.game.line("intro") : session.game.line("placed")
    }
}

// MARK: - Geometry

/// Where the spots and the tray sit on a board of a given size.
///
/// Plain arithmetic in the scene's coordinates, shared by what is drawn and by
/// the drop test, so the two cannot disagree.
private struct BoardLayout {
    let size: CGSize
    let slotCount: Int
    let gap: CGFloat
    let cardSize: CGSize

    init(size: CGSize, slotCount: Int, gap: CGFloat, inset: CGFloat) {
        self.size = size
        self.slotCount = max(1, slotCount)
        self.gap = gap

        let count = CGFloat(max(1, slotCount))
        let available = max(0, size.width - inset * 2 - gap * (count - 1))
        // Four across the board's width. On every supported width that leaves
        // each card comfortably above `HopHitTarget.childMinimum`; the ceiling
        // is what stops an iPad growing them into place mats.
        let width = min(available / count, 148)
        let height = max(width, min(width * 1.24, size.height * 0.28))
        self.cardSize = CGSize(width: width, height: height)
    }

    /// The row of spots, in the upper quarter.
    func slotCentre(_ index: Int) -> CGPoint {
        CGPoint(x: rowX(index, count: slotCount), y: size.height * 0.24)
    }

    /// The tray, along the bottom. It re-centres as it empties.
    func trayCentre(_ position: Int, of count: Int) -> CGPoint {
        CGPoint(x: rowX(position, count: count), y: size.height * 0.78)
    }

    /// The area a card has to be let go over to count as landing on a spot.
    /// Half a gap wider than the spot on each side, because a child aiming for
    /// a picture should not have to aim for its edges.
    func slotRect(_ index: Int) -> CGRect {
        let centre = slotCentre(index)
        return CGRect(
            x: centre.x - cardSize.width / 2 - gap / 2,
            y: centre.y - cardSize.height / 2 - gap / 2,
            width: cardSize.width + gap,
            height: cardSize.height + gap
        )
    }

    private func rowX(_ position: Int, count: Int) -> CGFloat {
        guard count > 0 else { return size.width / 2 }
        let total = cardSize.width * CGFloat(count) + gap * CGFloat(count - 1)
        let first = (size.width - total) / 2 + cardSize.width / 2
        return first + CGFloat(position) * (cardSize.width + gap)
    }
}

// MARK: - One spot on the path

/// An empty spot, or the card that ended up on it.
private struct OrderSlotView: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    /// The card that belongs here. Used for the spot's name, never shown as an
    /// answer: the picture appears when the child puts it there.
    let expects: GameCopy.OrderCard
    let holds: GameCopy.OrderCard?
    let size: CGSize
    let isOffered: Bool
    let onTap: () -> Void

    private var isFilled: Bool { holds != nil }

    /// Filled is drawn three ways — the picture, the border and the
    /// accessibility value — so the state never rests on colour alone.
    private var borderColor: Color {
        if isFilled { return theme.color.success }
        return isOffered ? theme.color.brandAction : theme.color.divider
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let holds {
                    HopArtwork(holds.illustration)
                        .padding(theme.spacing.xs)
                        .hopTransition(.childArrive)
                } else {
                    Text(verbatim: expects.slotLabel.localized)
                        .hopTextStyle(.parentCallout)
                        .foregroundStyle(theme.color.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(theme.spacing.xxs)
                }
            }
            .frame(width: size.width, height: size.height)
            .background {
                RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                    .fill(isFilled ? theme.color.surfaceElevated : theme.color.surfaceSunken.opacity(0.85))
            }
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                    .strokeBorder(
                        borderColor,
                        style: StrokeStyle(
                            lineWidth: isFilled || isOffered ? 4 : 2,
                            dash: isFilled ? [] : [7, 6]
                        )
                    )
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous))
        .disabled(!isOffered)
        // The breath is the invitation, and only while something is in hand.
        .hopBreathing(isOffered, amplitude: 0.03)
        .hopAnimation(.childArrive, value: isFilled)
        .hopAnimation(.childTap, value: isOffered)
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: theme.radius.l)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(holds?.label.localized ?? expects.slotLabel.localized)
        .modifier(SlotFilledValue(isFilled: isFilled))
        .accessibilityAddTraits(.isButton)
    }
}

/// Says "Filled" only where there is something to say it about, rather than
/// hanging an empty value on every spot.
private struct SlotFilledValue: ViewModifier {
    let isFilled: Bool

    func body(content: Content) -> some View {
        if isFilled {
            content.accessibilityValue(Text(verbatim: GameCopy.slotFilled.localized))
        } else {
            content
        }
    }
}

// MARK: - One card in the tray

/// A card waiting to be put somewhere. A button *and* a draggable thing, in
/// that order: the tap route is the one that always works.
private struct TrayCardView: View {
    @Environment(\.hopTheme) private var theme
    @FocusState private var isFocused: Bool

    /// Where the finger has carried the card, relative to its home in the tray.
    @State private var drag: CGSize = .zero

    let card: GameCopy.OrderCard
    let size: CGSize
    let isHeld: Bool
    let isRebuffed: Bool
    let onTap: () -> Void
    let onDrop: (CGSize) -> Void

    private var isLifted: Bool { isHeld || drag != .zero }

    var body: some View {
        Button(action: onTap) {
            HopArtwork(card.illustration)
                .padding(theme.spacing.xs)
                .frame(width: size.width, height: size.height)
                .background {
                    RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                        .fill(theme.color.surfaceElevated)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                        .strokeBorder(
                            isLifted ? theme.color.brandAction : theme.color.divider,
                            lineWidth: isLifted ? 4 : 1
                        )
                }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous))
        .modifier(theme.elevation(isLifted ? .raised : .resting))
        .scaleEffect(isLifted ? 1.05 : 1)
        .hopAnimation(.childTap, value: isLifted)
        // The tilt while a sprung-back card is still being talked about. Two
        // and a half degrees, once, on the card itself — never a shake, and
        // never anything the rest of the board has to react to.
        .rotationEffect(.degrees(isRebuffed ? 2.5 : 0))
        .hopAnimation(.childTap, value: isRebuffed)
        .offset(drag)
        // Keyed on *whether* the card is being carried rather than on where it
        // is: while the finger is down the card tracks it exactly, and the one
        // animated change is the settle home — which is where the wobble comes
        // from, and which Reduce Motion turns into a cross-fade.
        .hopAnimation(.childArrive, value: drag == .zero)
        .zIndex(isLifted ? 1 : 0)
        // Simultaneous, not exclusive: the card is a button first, and tapping
        // it has to keep working while dragging it also does.
        .simultaneousGesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in drag = value.translation }
                .onEnded { value in
                    drag = .zero
                    onDrop(value.translation)
                }
        )
        .focused($isFocused)
        .hopFocusRing(isFocused, cornerRadius: theme.radius.l)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.label.localized)
        .accessibilityHint(Text(verbatim: GameCopy.pickUpHint.localized))
        .accessibilityAddTraits(isHeld ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Previews

private struct PottyOrderHostPreview: View {
    @State var session: PottyOrderSession
    var reduceMotion: Bool? = nil

    var body: some View {
        GameHostView(
            game: session.game,
            isFinished: session.isFinished,
            completion: session.completion,
            onPlayAgain: { session.restart() },
            onLeave: {}
        ) {
            PottyOrderGameView(session: session)
        }
        .hopThemedRoot(reduceMotion: reduceMotion)
    }
}

#Preview("Potty Order · fresh path") {
    PottyOrderHostPreview(session: PottyOrderSession())
}

#Preview("Potty Order · two placed") {
    PottyOrderHostPreview(session: {
        let session = PottyOrderSession()
        session.place(.pantsDown, intoSlot: 0)
        session.place(.sit, intoSlot: 1)
        return session
    }())
}

#Preview("Potty Order · a card that did not fit") {
    PottyOrderHostPreview(session: {
        let session = PottyOrderSession()
        // Sprung back, and still exactly as playable as it was a moment ago.
        session.place(.wash, intoSlot: 0)
        return session
    }())
}

#Preview("Potty Order · path finished") {
    PottyOrderHostPreview(session: {
        let session = PottyOrderSession()
        for card in PottyOrderSession.cards { session.place(card, intoSlot: card.order) }
        return session
    }())
}

#Preview("Potty Order · Reduce Motion") {
    PottyOrderHostPreview(session: PottyOrderSession(), reduceMotion: true)
}

#Preview("Potty Order · iPad") {
    PottyOrderHostPreview(session: PottyOrderSession())
        .frame(width: 1024, height: 768)
}

#Preview("Potty Order · AX3") {
    PottyOrderHostPreview(session: PottyOrderSession())
        .environment(\.dynamicTypeSize, .accessibility3)
}
