import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

// MARK: - Why Hop arrives here as data
//
// The app's Hop (`HopPotty/DesignSystem/Components/HopCharacterView.swift`) is a
// full character: tuned `HopPoseGeometry`, layered SwiftUI paths, ambient
// motion, a blink timer, a theme environment. `project.yml` gives this extension
// `HopPottyCore` and `HopPottyDesignTokens` and nothing else, and it bundles no
// resources at all — so the widget can neither call that view nor load
// `Art/character/hop-face.svg`. It used to draw a simplified frog instead: a
// circle, two smaller circles and a capsule.
//
// It now draws the real one. `Scripts/widget-face.js` lifts the head out of the
// same five pose files the app ships — `hop-{idle,wave,jump,cheer,sleep}.svg`,
// one per `HopWidgetMood` — and emits every ellipse and curve of it into
// `HopWidgetFaceArt.swift` as path data. That is the same arrangement the splash
// screen's logo already uses (`Scripts/logo-art.js` → `HopLogoArtwork.swift`),
// for the same reason: a drawing a diff can review, in a target that cannot have
// the drawing.
//
// What it costs: a second copy of the head, in a repository that already has two
// (the art and the app's SwiftUI port). What keeps the copy honest is that
// nobody types it — `node Scripts/widget-face.js --check` renders it back over
// the artwork and measures the difference, and `Scripts/verify-config.sh` fails
// if the art has moved since it was generated.
//
// What it does not cost: the design system. No shape layer, no theme
// environment, no motion, no glyphs — a widget is redrawn by the system from an
// archived view hierarchy, where none of that runs anyway.

// MARK: - The data the generator emits

/// Which part of the face a shape is.
///
/// A role rather than a colour, because the same drawing has to be painted two
/// ways: in the palette on the home screen, and in one colour's alpha on the
/// lock screen. Declaration order is paint order, back to front, and it has to
/// match `ROLES` in `Scripts/widget-face.js`.
enum HopWidgetFaceRole: String, Sendable {
    /// The band that holds Hop's shape: his exterior outline, and the internal
    /// rim under the head fills. Drawn first because it is drawn under.
    case outline
    case head
    case spot
    case eyeWhite
    case pupil
    case highlight
    case closedEye
    case cheek
    case nostril
    case mouthInterior
    case tongue
    case smile
    /// Not a shape — the two z's above a sleeping head, which are type in the
    /// artwork and stay type here.
    case sleepMark
}

/// One shape of the head: the artwork's own path, in the artwork's own units.
struct HopWidgetFaceShape: Sendable {
    /// Absolute `M` / `L` / `C` / `Q` / `Z` — the only five commands the
    /// generator emits, and the only five ``HopWidgetFacePath`` decodes.
    let d: String
    let role: HopWidgetFaceRole
    /// Non-zero means the artwork strokes this shape rather than filling it:
    /// the shut eyes and the closed smile, which are drawn as round-capped arcs.
    let strokeWidth: CGFloat
    let opacity: Double
    /// The clip the artwork applies, as path data — the eye a pupil may not
    /// leave, the mouth the tongue may not.
    let clip: String?

    init(
        role: HopWidgetFaceRole,
        d: String,
        strokeWidth: CGFloat = 0,
        opacity: Double = 1,
        clip: String? = nil
    ) {
        self.role = role
        self.d = d
        self.strokeWidth = strokeWidth
        self.opacity = opacity
        self.clip = clip
    }
}

/// One glyph of the artwork: a z, at the size and place the drawing puts it.
struct HopWidgetFaceMark: Sendable {
    /// The glyph's origin, which in SVG is the left end of its baseline.
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
}

extension HopWidgetFaceArt {
    /// How tall the head is for a given width. The head is wider than it is
    /// tall — a frog's jaw is the widest thing about him — so a caller that
    /// asks for 40 points of Hop gets 40 across and about 28 down.
    static var aspect: CGFloat { content.height / content.width }

    /// Maps the head's own box onto `rect`, fitted and centred.
    ///
    /// `content` rather than `viewBox`: the artboard has margins, and a widget
    /// has none to spare.
    static func transform(fitting rect: CGRect) -> CGAffineTransform {
        let scale = min(rect.width / content.width, rect.height / content.height)
        return CGAffineTransform(
            translationX: rect.midX - content.midX * scale,
            y: rect.midY - content.midY * scale
        )
        .scaledBy(x: scale, y: scale)
    }

    /// How many points one artwork unit covers when the head is `width` wide.
    /// Stroke widths and glyph sizes are authored in artwork units and have to
    /// be converted, because neither scales with the path it accompanies.
    static func unit(for width: CGFloat) -> CGFloat { width / content.width }
}

// MARK: - One path of the artwork

/// One shape of the head, fitted to the view.
struct HopWidgetFacePath: Shape {
    let data: String

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var start = CGPoint.zero
        var tokens = data.split(separator: " ")[...]

        func number() -> CGFloat {
            guard let token = tokens.popFirst() else { return 0 }
            return CGFloat(Double(token) ?? 0)
        }
        func point() -> CGPoint {
            let x = number()
            return CGPoint(x: x, y: number())
        }

        while let command = tokens.popFirst() {
            switch command {
            case "M":
                start = point()
                path.move(to: start)
            case "L":
                path.addLine(to: point())
            case "C":
                let c1 = point(), c2 = point(), end = point()
                path.addCurve(to: end, control1: c1, control2: c2)
            case "Q":
                let c = point(), end = point()
                path.addQuadCurve(to: end, control: c)
            case "Z":
                path.closeSubpath()
            default:
                break
            }
        }
        return path.applying(HopWidgetFaceArt.transform(fitting: rect))
    }
}

// MARK: - Hop, at widget size

/// Hop's head, as the artwork draws it.
///
/// `size` is the width of the head. Everything inside scales with it rather than
/// with the layout, so the same drawing works in an 18-point Dynamic Island slot
/// and a 64-point medium widget without the features drifting apart.
struct HopWidgetFace: View {
    let mood: HopWidgetMood
    var size: CGFloat = 44

    /// Accessory widgets and the Dynamic Island are composited into a
    /// single-colour vibrant layer: the system keeps roughly each colour's
    /// luminance and discards its hue. Handing it the coloured drawing turns
    /// Hop's dark pupils and dark mouth — the two things that make a face a face
    /// — into the *dimmest* things on screen, and what is left is a pale disc.
    /// So in that context the same geometry is painted as a stencil instead: one
    /// colour, a tone per part, and the small stuff dropped. See `stencilAlpha`.
    var isMonochrome: Bool = false

    var body: some View {
        ZStack {
            ForEach(Array(shapes.enumerated()), id: \.offset) { _, shape in
                draw(shape)
            }
            ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                draw(mark)
            }
        }
        .frame(width: size, height: size * HopWidgetFaceArt.aspect)
        .accessibilityLabel(Text(mood.accessibilityDescription))
    }

    private var shapes: [HopWidgetFaceShape] { HopWidgetFaceArt.shapes(for: mood) }
    private var marks: [HopWidgetFaceMark] { HopWidgetFaceArt.marks(for: mood) }

    /// One artwork unit, in points, at this size.
    private var unit: CGFloat { HopWidgetFaceArt.unit(for: size) }

    @ViewBuilder
    private func draw(_ shape: HopWidgetFaceShape) -> some View {
        if let paint = colour(shape.role) {
            let path = HopWidgetFacePath(data: shape.d)
            Group {
                if shape.strokeWidth > 0 {
                    path.stroke(paint, style: StrokeStyle(lineWidth: strokeWidth(shape), lineCap: .round))
                } else {
                    path.fill(paint)
                }
            }
            .opacity(shape.opacity)
            .clipShape(clip(shape))
        }
    }

    /// The clip the artwork applies to this shape, or the whole artboard when it
    /// applies none.
    ///
    /// The artboard rather than `nil`, because `clipShape` takes a shape and
    /// both branches have to be one type. The artboard is bigger than the head
    /// that is fitted to the view, so it falls outside the frame and clips
    /// nothing.
    private func clip(_ shape: HopWidgetFaceShape) -> some Shape {
        shape.clip.map { HopWidgetFacePath(data: $0) }
            ?? HopWidgetFacePath(data: everything)
    }

    /// The artwork's box as a path, for shapes that are not clipped.
    private var everything: String {
        let box = HopWidgetFaceArt.viewBox
        return "M \(box.minX) \(box.minY) L \(box.maxX) \(box.minY) " +
            "L \(box.maxX) \(box.maxY) L \(box.minX) \(box.maxY) Z"
    }

    /// A z. Type in the artwork, and type here — the one part of the drawing
    /// that is not a path, and cannot be without shipping a font to trace it
    /// from.
    ///
    /// `position` centres a view on a point where SVG's `x`/`y` start a
    /// baseline, so the glyph is nudged right and up by roughly the half-width
    /// and half-height of a lowercase letter. It is a decorative mark two
    /// millimetres tall; the artwork's own placement is the intent, and this is
    /// as close to it as type gets.
    @ViewBuilder
    private func draw(_ mark: HopWidgetFaceMark) -> some View {
        if let paint = colour(.sleepMark) {
            let scale = HopWidgetFaceArt.transform(fitting: frame)
            let origin = CGPoint(x: mark.x, y: mark.y).applying(scale)
            let points = mark.size * unit
            Text(verbatim: "z")
                .font(.system(size: points, weight: .heavy, design: .rounded))
                .foregroundStyle(paint)
                .opacity(mark.opacity)
                .position(x: origin.x + points * 0.3, y: origin.y - points * 0.28)
        }
    }

    /// The rectangle the shapes are fitted to — the view's own frame, at the
    /// origin, because everything inside a `ZStack` shares it.
    private var frame: CGRect {
        CGRect(x: 0, y: 0, width: size, height: size * HopWidgetFaceArt.aspect)
    }

    private func strokeWidth(_ shape: HopWidgetFaceShape) -> CGFloat {
        let drawn = shape.strokeWidth * unit
        // A shut eye is a 3.2-unit stroke, which at 24 points across is six
        // tenths of a point. Vibrancy renders six tenths of a point as a
        // rumour, so the stencil holds a floor under it; the colour drawing,
        // which is never that small, uses the artwork's own width.
        return isMonochrome ? max(drawn, size * 0.05) : drawn
    }

    // MARK: Colour — from the shared token package, never re-typed as hex here

    /// What a part of the face is painted, or `nil` for a part this rendering
    /// leaves out.
    private func colour(_ role: HopWidgetFaceRole) -> Color? {
        if isMonochrome {
            return stencilAlpha(role).map { Color.primary.opacity($0) }
        }
        return palette(role)
    }

    /// The artwork's palette. Eleven of the thirteen roles are a `HopPalette` token
    /// by value — `Scripts/widget-face.js` asserts that against
    /// `HopPalette.swift` every time it runs, so these cannot drift from the
    /// drawing. The two that are not are character-only colours the brand ramp
    /// has no token for, exactly as `HopCharacterPalette` declares them in the
    /// app: a value step between `hopGreen` and `hopGreenDeep`, and a pink
    /// brighter than any brand hue.
    private func palette(_ role: HopWidgetFaceRole) -> Color {
        switch role {
        case .outline: Color(HopPalette.hopOutline)
        case .head: Color(HopPalette.hopGreen)
        case .spot: Color(HopColorValue(hex: 0x45A971))
        case .eyeWhite: Color(HopPalette.white)
        case .pupil: Color(HopPalette.midnight)
        case .highlight: Color(HopPalette.white)
        case .closedEye: Color(HopPalette.hopGreenInk)
        case .cheek: Color(HopPalette.peachPop)
        case .nostril: Color(HopPalette.hopGreenInk)
        case .mouthInterior: Color(HopPalette.peachInk)
        case .tongue: Color(HopColorValue(hex: 0xFF6F7D))
        case .smile: Color(HopPalette.hopGreenInk)
        case .sleepMark: Color(HopPalette.hopGreenInk)
        }
    }

    // MARK: Stencil
    //
    // The lock screen's reading of the same head: one colour, and a tone per
    // part. Three rules made every number below, and they are worth stating
    // because the obvious approach — hand over the colour art and let vibrancy
    // sort it out — produces a blob:
    //
    //  1. **Tone is inverted, not preserved.** Vibrant content is light on the
    //     wallpaper, so the parts that are *darkest* in the drawing are the ones
    //     that must be *brightest* here. The pupils and the open mouth lead; the
    //     head, which is the drawing's mid-tone, steps back to a third.
    //  2. **Contrast is between neighbours.** The pupil reads because the sclera
    //     under it is dimmer, and the sclera reads because the head under that
    //     is dimmer again — three steps, in the same colour, so the face
    //     survives any wallpaper the material is composited over.
    //  3. **Anything under a point across is noise.** At 24 points of head the
    //     nostrils are a third of a point, the catchlights are half a point, and
    //     the forehead spots are barely more; drawn, they are grey dirt on the
    //     silhouette. The cheeks are the close call — two and a half points, and
    //     they sit on the jaw's edge where they soften the outline rather than
    //     decorate it. They are dropped too.
    //
    // One case per line, and the value is read back by
    // `Scripts/widget-face.js --sheet`, which renders this table over a
    // wallpaper at every size the widget uses it. Do not fold the `nil` cases
    // together.
    private func stencilAlpha(_ role: HopWidgetFaceRole) -> Double? {
        switch role {
        // Dropped, and it is the only role dropped for the opposite of the
        // usual reason. An outline exists to separate Hop from what is behind
        // him; in vibrancy the head wash already ends in a hard edge against
        // the blurred wallpaper, so a second edge in the same single colour
        // only thickens the silhouette and eats the jaw.
        case .outline: nil
        case .head: 0.32
        case .spot: nil
        case .eyeWhite: 0.62
        case .pupil: 1.0
        case .highlight: nil
        case .closedEye: 1.0
        case .cheek: nil
        case .nostril: nil
        case .mouthInterior: 1.0
        case .tongue: nil
        case .smile: 1.0
        case .sleepMark: 1.0
        }
    }
}

// MARK: - Token bridge

extension Color {
    /// The one place the widget turns a token into a SwiftUI colour.
    ///
    /// `HopPottyDesignTokens` is platform-agnostic on purpose — it is compiled
    /// and contrast-tested on Linux — so the SwiftUI conversion lives at each
    /// point of use. The app has its own, richer version in
    /// `DesignSystem/Foundation/HopColor+SwiftUI.swift`; this is the two-line
    /// form, kept separate because the design system is not a member of this
    /// target.
    init(_ value: HopColorValue) {
        self.init(
            .sRGB,
            red: value.red,
            green: value.green,
            blue: value.blue,
            opacity: value.alpha
        )
    }
}

#if DEBUG
#Preview("Hop's widget moods") {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            ForEach(HopWidgetMood.allCases) { mood in
                HopWidgetFace(mood: mood, size: 56)
            }
        }
        HStack(spacing: 12) {
            ForEach(HopWidgetMood.allCases) { mood in
                HopWidgetFace(mood: mood, size: 26, isMonochrome: true)
            }
        }
        .padding(8)
        .background(Color(HopPalette.midnight))
    }
    .padding()
}
#endif
