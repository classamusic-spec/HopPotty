import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

/// Bubble Wash: the close-up of Hop's hands, and a finger rubbing them clean.
///
/// ## The composition, and the reason it is this composition
///
/// The brief asks for two things that fight each other: **Hop's hands enlarged
/// into the foreground**, and **Hop watching the child do it and smiling more as
/// they go**. A character cannot be in both places at once without his own arms
/// crossing his own chest, which at this scale is exactly the green-on-green
/// ambiguity the whole screen has to avoid.
///
/// A bathroom resolves it. Hop is in the **mirror** over the sink, four hundred
/// points above his own hands, so there is no plane in which a hand and a torso
/// can overlap at all. He looks further down and smiles more as coverage rises —
/// ``BubbleWashSession/delight`` — and the hands stay the only thing in the
/// foreground.
///
/// ## Keeping the two hands from becoming one green shape
///
/// Stated as geometry rather than trusted to the drawing:
///
/// * **a gutter that cannot close** — each hand gets its own third of the width
///   with ``handGutter`` of basin between them, so the two boxes never meet;
/// * **two tones** — the near hand is the character green, the far hand a step
///   lighter, which reads as depth rather than as one silhouette;
/// * **a rim on each** — every hand is stroked in the page colour, and the
///   stroke follows the fingers as well as the outline, so the four fingers stay
///   countable *and* the boundary survives foam drawn over the top of it;
/// * **a palm pad** — one shade deeper inside the palm, so a hand has an inside
///   as well as an edge.
///
/// ## Nothing here counts
///
/// No score, no points, no countdown, no combo, no "play again". Coverage is
/// drawn as foam on the hands and nowhere else, and the round rinses and leaves
/// by itself — see ``BubbleWashScreen``.
struct BubbleWashGameView: View {
    @Environment(\.hopTheme) private var theme

    let session: BubbleWashSession

    /// Fraction of the width left as basin between the two hands.
    private static let handGutter: CGFloat = 0.1

    /// Where the finger was on the previous drag event, in that hand's unit
    /// space, so a scrub can lay down more foam than a resting finger.
    @State private var lastRub: (hand: BubbleWashSession.Hand, point: CGPoint)?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let layout = Layout(size: size, gutter: Self.handGutter)

            ZStack(alignment: .topLeading) {
                BubbleWashBasin(delight: session.delight, isRunning: session.beat != .soap)

                soapTarget(layout)

                // Skin, not the brand colour: these are the child's hands.
                hand(.left, in: layout.left, flipped: false, tint: HopCharacterPalette.skin)
                hand(.right, in: layout.right, flipped: true, tint: HopCharacterPalette.skin)

                if session.beat == .rinse || session.beat == .done {
                    rinseSparkle(layout)
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            // Simultaneous, not exclusive: every patch is also a button, and a
            // tap must keep working while a drag across the hands also foams
            // them.
            .simultaneousGesture(rubGesture(layout))
            // The beat change is a state change, drawn through a motion token,
            // so Reduce Motion turns it into a cross-fade without this view
            // knowing Reduce Motion exists.
            .hopAnimation(.childArrive, value: session.beat)
        }
        // The clock lives here rather than on the screen around it, because the
        // rinse has to finish itself in either host: this view is what the game
        // list's `GameHostView` puts on screen, and a board that reached the
        // rinse with no clock would sit in it forever.
        .gameClock(session)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(session.stage.label.localized)
    }

    // MARK: - Where the pieces are

    /// The two hand boxes and the soap, derived from the space available.
    ///
    /// A struct rather than five computed properties so the gutter between the
    /// hands is one subtraction that can be read, and so nothing can move one
    /// hand without moving the other.
    private struct Layout {
        let left: CGRect
        let right: CGRect
        let soap: CGRect

        init(size: CGSize, gutter: CGFloat) {
            let handWidth = (size.width * (1 - gutter)) / 2
            let handHeight = min(size.height * 0.56, handWidth * 1.26)
            let top = size.height - handHeight - size.height * 0.02
            left = CGRect(x: 0, y: top, width: handWidth, height: handHeight)
            right = CGRect(x: size.width - handWidth, y: top, width: handWidth, height: handHeight)
            let soapSide = min(size.width * 0.17, size.height * 0.17)
            soap = CGRect(
                x: size.width * 0.02,
                y: top - soapSide * 0.92,
                width: soapSide,
                height: soapSide
            )
        }
    }

    // MARK: - Parts

    private func hand(
        _ which: BubbleWashSession.Hand,
        in rect: CGRect,
        flipped: Bool,
        tint: Color
    ) -> some View {
        BubbleWashHand(
            patches: session.patches(on: which),
            fill: tint,
            rim: theme.color.backgroundPrimary,
            isFlipped: flipped,
            isRinsing: session.beat == .rinse || session.beat == .done,
            label: which == .left ? GameCopy.bubbleWashLeftHand.localized : GameCopy.bubbleWashRightHand.localized,
            onCover: { session.cover($0) }
        )
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
    }

    /// The soap, and the pulse that says "press me" on the first beat.
    ///
    /// A real target rather than decoration: the first beat has exactly one
    /// thing to do, and it is this.
    private func soapTarget(_ layout: Layout) -> some View {
        Button { session.pump() } label: {
            BubbleWashSoap(isPrompting: session.beat == .soap, tint: theme.color.eventTried)
        }
        .buttonStyle(.plain)
        .frame(width: layout.soap.width, height: layout.soap.height)
        .hopHitTarget(theme.hitTarget.child)
        .offset(x: layout.soap.minX, y: layout.soap.minY)
        .accessibilityLabel(GameCopy.bubbleWashSoap.localized)
        .accessibilityAddTraits(.isButton)
        .allowsHitTesting(session.beat == .soap)
        .opacity(session.beat == .soap ? 1 : 0.85)
    }

    /// The sparkle over the rinse. Decorative, and hidden from VoiceOver: the
    /// beat itself is announced by the line above the basin.
    private func rinseSparkle(_ layout: Layout) -> some View {
        HStack(spacing: layout.left.width * 0.5) {
            sparkle(side: layout.left.width * 0.16)
            sparkle(side: layout.left.width * 0.11)
        }
        .frame(width: layout.right.maxX - layout.left.minX)
        .offset(x: layout.left.minX, y: layout.left.minY - layout.left.height * 0.1)
        .accessibilityHidden(true)
    }

    private func sparkle(side: CGFloat) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: side))
            .foregroundStyle(theme.color.celebration)
    }

    // MARK: - The gesture

    /// Rubbing.
    ///
    /// The point is resolved into *one* hand's unit space before it reaches the
    /// model, so a finger on the left hand can never foam the right one — the
    /// two share a coordinate space and only the view knows where they are.
    private func rubGesture(_ layout: Layout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let (which, point) = resolve(value.location, in: layout) else { return }
                var speed = 0.0
                if let last = lastRub, last.hand == which {
                    speed = hypot(point.x - last.point.x, point.y - last.point.y)
                }
                lastRub = (which, point)
                session.rub(on: which, at: point, radius: 0.22, speed: speed)
            }
            .onEnded { _ in lastRub = nil }
    }

    /// Which hand a screen point is on, and where on it, or `nil` for the basin
    /// between them.
    private func resolve(_ location: CGPoint, in layout: Layout) -> (BubbleWashSession.Hand, CGPoint)? {
        for (which, rect) in [(BubbleWashSession.Hand.left, layout.left), (.right, layout.right)] {
            guard rect.contains(location), rect.width > 0, rect.height > 0 else { continue }
            return (
                which,
                CGPoint(
                    x: (location.x - rect.minX) / rect.width,
                    y: (location.y - rect.minY) / rect.height
                )
            )
        }
        return nil
    }
}

// MARK: - One hand

/// One of Hop's hands, with the foam that is on it.
private struct BubbleWashHand: View {
    @Environment(\.hopTheme) private var theme

    let patches: [BubbleWashSession.Patch]
    let fill: Color
    let rim: Color
    /// The right hand is the same drawing mirrored, so there is one hand shape
    /// in the app and the pair cannot drift apart.
    let isFlipped: Bool
    let isRinsing: Bool
    let label: String
    let onCover: (Int) -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                WashHandShape()
                    .fill(fill)
                WashHandCreaseShape()
                    .stroke(
                        HopCharacterPalette.skinCrease.opacity(0.5),
                        style: StrokeStyle(lineWidth: max(2, size.width * 0.022), lineCap: .round)
                    )
                // The rim runs round the fingers as well as the silhouette, so
                // the four fingers stay countable against the palm and the
                // boundary survives foam drawn over the top of it.
                WashHandShape()
                    .stroke(rim, style: StrokeStyle(lineWidth: max(3, size.width * 0.035), lineJoin: .round))

                ForEach(patches) { patch in
                    PatchView(
                        patch: patch,
                        side: size.width * 0.3 * patch.scale,
                        isRinsing: isRinsing,
                        onCover: { onCover(patch.id) }
                    )
                    .position(x: size.width * patch.x, y: size.height * patch.y)
                }
            }
            .scaleEffect(x: isFlipped ? -1 : 1, y: 1, anchor: .center)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

}

/// One patch of hand: the foam on it, or the fact that there is none yet.
///
/// A button as well as a drag target, so a child who cannot yet drag — and a
/// child using VoiceOver or Switch Control — plays the same board rather than a
/// described one.
private struct PatchView: View {
    @Environment(\.hopTheme) private var theme

    let patch: BubbleWashSession.Patch
    let side: CGFloat
    let isRinsing: Bool
    let onCover: () -> Void

    var body: some View {
        Button(action: onCover) {
            ZStack {
                // Somewhere the child has not been yet — never a mistake, so
                // never a red mark. The dash carries the meaning as well as the
                // tone does, so the state is not held by colour alone.
                Circle()
                    .strokeBorder(
                        theme.color.backgroundPrimary,
                        style: StrokeStyle(lineWidth: 2.5, dash: [6, 7])
                    )
                    .background { Circle().fill(theme.color.textPrimary.opacity(0.1)) }
                    .opacity(patch.foam < 0.15 && !isRinsing ? 1 : 0)

                BubbleWashFoam(side: side)
                    .opacity(patch.foam)
                    .scaleEffect(0.55 + 0.45 * patch.foam)
            }
            .frame(width: side, height: side)
        }
        .buttonStyle(.plain)
        // The drawn patch is small; the target a two-year-old aims at is not.
        .hopHitTarget(theme.hitTarget.child)
        .hopAnimation(.childTap, value: patch.foam)
        .allowsHitTesting(!patch.isCovered)
        .accessibilityHidden(patch.isCovered)
        .accessibilityLabel(GameCopy.bubbleWashPatch.localized)
        .accessibilityAddTraits(.isButton)
    }
}

/// A puff of foam: five soft circles and two blue lights in it.
private struct BubbleWashFoam: View {
    @Environment(\.hopTheme) private var theme

    let side: CGFloat

    var body: some View {
        ZStack {
            puff(dx: 0, dy: 0, scale: 1)
            puff(dx: 0.36, dy: 0.14, scale: 0.72)
            puff(dx: -0.34, dy: 0.11, scale: 0.66)
            puff(dx: 0.14, dy: -0.29, scale: 0.6)
            puff(dx: -0.16, dy: -0.26, scale: 0.54)
            Circle()
                .fill(HopColors.wash(theme.color.brandSecondary, isDark: theme.isDark))
                .frame(width: side * 0.22, height: side * 0.22)
                .offset(x: -side * 0.14, y: -side * 0.14)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }

    private func puff(dx: CGFloat, dy: CGFloat, scale: CGFloat) -> some View {
        Circle()
            .fill(theme.color.backgroundPrimary)
            .frame(width: side * scale, height: side * scale)
            .offset(x: side * dx, y: side * dy)
    }
}

// MARK: - The hand itself

/// Hop's hand, as one path.
///
/// The same drawing the routine's high-five scene uses, expressed here as a
/// `Shape` so it can be filled, stroked and masked at any size. Palm and four
/// fingers are subpaths of one path on purpose: filled with the non-zero rule
/// they are a single silhouette, and stroked they gain exactly the internal
/// boundaries the close-up needs.
///
/// The design box is the drawing's own bounds — x −12…115, y −115…45 — mapped
/// onto whatever rectangle the caller gives it, so no call site carries a magic
/// number for the aspect.
/// The lines that separate the fingers, and the one setting the thumb off from
/// the palm. Stroked, not filled — the twin of `handCreases` in `hop-art.js`.
///
/// They are not decoration. Four fingers held together overlap along their
/// whole length, so there is no background between them anywhere and the
/// outline cannot help: it runs round the silhouette, and the silhouette of
/// four touching fingers is one mitten with a scalloped top.
struct WashHandCreaseShape: Shape {
    private typealias H = HopAnatomy.Hand

    func path(in rect: CGRect) -> Path {
        let design = WashHandShape.designBounds
        let scale = min(rect.width / design.width, rect.height / design.height)
        let originX = rect.midX - design.midX * scale
        let originY = rect.midY - design.midY * scale
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: originX + x * scale, y: originY + y * scale)
        }

        var path = Path()
        for index in 0..<(H.fingers.count - 1) {
            let a = H.fingers[index]
            let b = H.fingers[index + 1]
            let tx = (a.tip.x + b.tip.x) / 2, ty = (a.tip.y + b.tip.y) / 2
            let bx = (a.base.x + b.base.x) / 2, by = (a.base.y + b.base.y) / 2
            let dx = bx - tx, dy = by - ty
            let length = max((dx * dx + dy * dy).squareRoot(), 0.0001)
            // Start inside the notch, not at the tips' midpoint, which is out
            // in the open air between them; finish a little past the knuckles.
            let inset = (a.half + b.half) * 0.42
            path.move(to: at(tx + dx / length * inset, ty + dy / length * inset))
            path.addLine(to: at(bx + dx / length * 9, by + dy / length * 9))
        }

        // The thumb's boundary, offset onto the palm side of its axis.
        let t = H.thumb
        let ax = t.tip.x - t.base.x, ay = t.tip.y - t.base.y
        let alen = max((ax * ax + ay * ay).squareRoot(), 0.0001)
        let off = t.half * 0.74
        let nx = -ay / alen, ny = ax / alen
        path.move(to: at(t.base.x + nx * off, t.base.y + ny * off))
        path.addLine(to: at(t.base.x + ax * 0.6 + nx * off, t.base.y + ay * 0.6 + ny * off))
        return path
    }
}

/// The child's hand, drawn from `HopAnatomy.Hand`.
///
/// Named for what it is. It was `HopHandShape` while it drew a green
/// three-fingered frog paw, which was the right anatomy for the wrong
/// character: these are the hands the child is being asked to wash.
struct WashHandShape: Shape {
    private typealias H = HopAnatomy.Hand

    /// The drawing's natural bounds, derived from the anatomy so it cannot fall
    /// out of step with it.
    static var designBounds: CGRect {
        var box = H.palm
        for digit in H.fingers + [H.thumb] {
            box = box.union(CGRect(
                x: min(digit.base.x, digit.tip.x) - digit.half,
                y: min(digit.base.y, digit.tip.y) - digit.half,
                width: abs(digit.tip.x - digit.base.x) + digit.half * 2,
                height: abs(digit.tip.y - digit.base.y) + digit.half * 2
            ))
        }
        return box.union(CGRect(
            x: -H.wrist.half, y: H.wrist.from.y,
            width: H.wrist.half * 2, height: H.wrist.to.y - H.wrist.from.y + H.wrist.half
        ))
    }

    func path(in rect: CGRect) -> Path {
        let design = Self.designBounds
        // Uniform scale, centred: a hand stretched to fill a box whose aspect
        // does not match is a hand with the wrong fingers.
        let scale = min(rect.width / design.width, rect.height / design.height)
        let originX = rect.midX - design.midX * scale
        let originY = rect.midY - design.midY * scale
        func at(_ point: CGPoint) -> CGPoint {
            CGPoint(x: originX + point.x * scale, y: originY + point.y * scale)
        }

        var path = Path()
        path.addHopRoundedRect(
            CGRect(
                x: originX + H.palm.minX * scale, y: originY + H.palm.minY * scale,
                width: H.palm.width * scale, height: H.palm.height * scale
            ),
            radius: H.palmRadius * scale
        )
        path.addHopCapsule(
            from: at(H.wrist.from), to: at(H.wrist.to), radius: H.wrist.half * scale
        )
        for digit in H.fingers + [H.thumb] {
            path.addHopCapsule(from: at(digit.base), to: at(digit.tip), radius: digit.half * scale)
        }
        return path
    }
}

// MARK: - The room

/// The wall, the mirror Hop is watching from, the tap and the basin.
///
/// Drawn from shapes rather than taken from an illustration key because the
/// basin has to line up with two hands whose size is decided at runtime, and
/// because a fixed picture of a sink would put a second soap bottle on a screen
/// whose soap bottle is a control.
private struct BubbleWashBasin: View {
    @Environment(\.hopTheme) private var theme

    /// 0…1 of how pleased Hop is. Drives how far down at his hands he looks.
    let delight: Double
    let isRunning: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let counterY = size.height * 0.72

            ZStack(alignment: .topLeading) {
                // The same room every other child surface stands in, with its
                // floor line where this screen's counter goes.
                ChildRoom(floorFraction: 0.72, glow: true)

                mirror(size: size)

                tap(size: size, counterY: counterY)

                RoundedRectangle(cornerRadius: theme.radius.s, style: .continuous)
                    .fill(theme.color.surface)
                    .frame(width: size.width, height: size.height - counterY)
                    .offset(y: counterY)

                Ellipse()
                    .fill(HopColors.wash(theme.color.brandSecondary, isDark: theme.isDark))
                    .overlay { Ellipse().strokeBorder(theme.color.surface, lineWidth: 5) }
                    .frame(width: size.width * 0.78, height: size.height * 0.13)
                    .offset(x: size.width * 0.11, y: counterY + size.height * 0.005)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    /// Hop's reflection.
    ///
    /// The head is cropped out of the full drawing the same way ``HopChip``
    /// does it — through `HopPoseGeometry.faceCrop`, the rectangle his head
    /// fills — so there is one Hop in the app and the mirror cannot drift out of
    /// step with the body it belongs to. The gaze is the live part: he looks
    /// further down at his own hands as the foam spreads.
    private func mirror(size: CGSize) -> some View {
        let diameter = min(size.width * 0.4, size.height * 0.26)
        let renderSize = diameter * HopCanvas.side / (HopPoseGeometry.faceCrop.width * 1.1)
        let faceOffset = (HopCanvas.side / 2 - HopPoseGeometry.faceCrop.midY) * renderSize / HopCanvas.side
        return HopCharacterView(
            pose: .idle,
            size: renderSize,
            ambient: true,
            castsShadow: false,
            gaze: .at(UnitPoint(x: 0.5, y: 0.62 + 0.5 * delight))
        )
        .offset(y: faceOffset)
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(theme.color.surface, lineWidth: diameter * 0.06) }
        .background { Circle().fill(HopColors.wash(theme.color.brandSecondary, isDark: theme.isDark)) }
        .offset(x: (size.width - diameter) / 2, y: size.height * 0.03)
    }

    private func tap(size: CGSize, counterY: CGFloat) -> some View {
        let neck = size.width * 0.055
        return ZStack(alignment: .topLeading) {
            Capsule()
                .fill(theme.color.divider)
                .frame(width: neck, height: size.height * 0.2)
                .offset(x: size.width * 0.38, y: counterY - size.height * 0.2)

            Capsule()
                .fill(theme.color.divider)
                .frame(width: size.width * 0.2, height: neck)
                .offset(x: size.width * 0.38, y: counterY - size.height * 0.2)

            if isRunning {
                Capsule()
                    .fill(HopColors.wash(theme.color.brandSecondary, isDark: theme.isDark))
                    .frame(width: neck * 0.8, height: size.height * 0.12)
                    .offset(x: size.width * 0.545, y: counterY - size.height * 0.14)
            }
        }
    }
}

/// The soap dispenser. A control, so it is drawn like one when it is the only
/// thing to do and quietly once the soap is on.
private struct BubbleWashSoap: View {
    @Environment(\.hopTheme) private var theme

    let isPrompting: Bool
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                if isPrompting {
                    Circle()
                        .strokeBorder(tint.opacity(0.5), lineWidth: 3)
                        .frame(width: size.width * 1.35, height: size.width * 1.35)
                }
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: size.width * 0.12, style: .continuous)
                        .fill(tint.opacity(0.7))
                        .frame(width: size.width * 0.28, height: size.height * 0.26)
                    RoundedRectangle(cornerRadius: size.width * 0.22, style: .continuous)
                        .fill(HopColors.wash(tint, isDark: theme.isDark))
                        .overlay {
                            RoundedRectangle(cornerRadius: size.width * 0.22, style: .continuous)
                                .strokeBorder(tint.opacity(0.4), lineWidth: 2)
                        }
                        .frame(width: size.width * 0.72, height: size.height * 0.62)
                }
                .frame(width: size.width, height: size.height, alignment: .bottom)
            }
            .frame(width: size.width, height: size.height)
        }
        // The pulse is a state change, not a journey: it grows and holds rather
        // than looping, so Reduce Motion has nothing to strip.
        .hopFloating(isPrompting, distance: 3, period: 3.2)
    }
}

// MARK: - The whole screen

/// Bubble Wash as the child meets it: full screen, one line, and no chrome.
///
/// This is the view the guided routine's wash step opens, and it is the one the
/// game list should open too. It is deliberately **not** `GameHostView`: that
/// host is right for the seven other boards and wrong for this one, because it
/// adds a row of progress dots and a "Play again" button, and `§23` of the brief
/// forbids both here. Everything the host provides that this screen still needs
/// — a way out, one star at the end — it provides itself.
///
/// The round ends by itself: at ``BubbleWashSession/rinseThreshold`` the water
/// takes over, the foam goes, a sparkle lands, "Squeaky clean!" is said once,
/// and ``onFinish`` fires. Nothing asks the child to stay.
struct BubbleWashScreen: View {
    @Environment(\.hopTheme) private var theme

    /// Called once the hands are clean and the ending has been seen.
    let onFinish: () -> Void
    /// The way to a grown-up. Never a dead end, and the only chrome on screen.
    var onAskForHelp: (() -> Void)?
    /// The line the caller wants on the way in. The routine passes "Wash those
    /// hands!", which is what the wash step is called; once the child starts, the
    /// beat names itself and the ending says "Squeaky clean!".
    var title: String?

    @State private var session = BubbleWashSession()

    var body: some View {
        VStack(spacing: theme.spacing.l) {
            header
            BubbleWashGameView(session: session)
                .frame(maxWidth: ChildStage.contentWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, theme.spacing.m)
        .hopBackground(.secondary)
        .onChange(of: session.isFinished) { _, finished in
            guard finished else { return }
            onFinish()
        }
    }

    /// The caller's line while nothing has happened yet, then the board's own.
    private var headline: String {
        if let title, session.beat == .soap { return title }
        return session.line.localized
    }

    /// One line and, if the caller offered one, the way to a grown-up.
    private var header: some View {
        ZStack {
            Text(headline)
                .hopTextStyle(.childTitle)
                .foregroundStyle(theme.color.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity)

            if let onAskForHelp {
                HStack {
                    Spacer()
                    HopIconButton(
                        systemImage: "hand.raised.fill",
                        accessibilityLabel: HopCopy.routine.helpButton.localized,
                        tint: theme.color.textSecondary,
                        minimumTarget: theme.hitTarget.child,
                        action: onAskForHelp
                    )
                }
            }
        }
        .hopPageMargins()
    }
}

// MARK: - Previews

#Preview("Bubble Wash · the soap beat") {
    BubbleWashScreen(onFinish: {}, onAskForHelp: {})
        .hopThemedRoot()
}

#Preview("Bubble Wash · inside the routine") {
    BubbleWashScreen(onFinish: {}, onAskForHelp: {}, title: "Wash those hands!")
        .hopThemedRoot()
}

#Preview("Bubble Wash · Reduce Motion") {
    BubbleWashScreen(onFinish: {})
        .hopThemedRoot(reduceMotion: true)
}

#Preview("Bubble Wash · AX3") {
    BubbleWashScreen(onFinish: {})
        .environment(\.dynamicTypeSize, .accessibility3)
        .hopThemedRoot()
}

#Preview("Bubble Wash · iPad") {
    BubbleWashScreen(onFinish: {})
        .frame(width: 1024, height: 768)
        .hopThemedRoot()
}

#Preview("Bubble Wash · one hand, close up") {
    BubbleWashGameView(session: BubbleWashSession())
        .frame(width: 360, height: 520)
        .hopBackground(.secondary)
        .hopThemedRoot()
}
