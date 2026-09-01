import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

public extension HopAvatarStyle {
    /// Name shown beside the avatar in the picker. Never a photograph, never a
    /// person — HopPotty's avatars are creatures on purpose.
    var displayName: String {
        switch self {
        case .frogGreen: "Green frog"
        case .frogBlue: "Blue frog"
        case .frogSunshine: "Yellow frog"
        case .frogPeach: "Peach frog"
        case .frogLavender: "Purple frog"
        case .tadpole: "Tadpole"
        case .turtle: "Turtle"
        case .duckling: "Duckling"
        }
    }

    /// The four hues an avatar is drawn from.
    var palette: (base: Color, deep: Color, light: Color, ground: Color) {
        typealias Palette = (base: Color, deep: Color, light: Color, ground: Color)
        func make(light: HopColorValue, base: HopColorValue, deep: HopColorValue, ground: HopColorValue) -> Palette {
            (base: Color(base), deep: Color(deep), light: Color(light), ground: Color(ground))
        }
        switch self {
        case .frogGreen:
            return make(light: HopPalette.hopGreenLight, base: HopPalette.hopGreen, deep: HopPalette.hopGreenDeep, ground: HopPalette.hopGreenSoft)
        case .frogBlue:
            return make(light: HopPalette.pondBlueLight, base: HopPalette.pondBlue, deep: HopPalette.pondBlueDeep, ground: HopPalette.pondBlueSoft)
        case .frogSunshine:
            return make(light: HopPalette.sunshineSoft, base: HopPalette.sunshineBright, deep: HopPalette.sunshineDeep, ground: HopPalette.sunshineSoft)
        case .frogPeach:
            return make(light: HopPalette.peachSoft, base: HopPalette.peachPop, deep: HopPalette.peachDeep, ground: HopPalette.peachSoft)
        case .frogLavender:
            return make(light: HopPalette.lavenderSoft, base: HopPalette.lavender, deep: HopPalette.lavenderDeep, ground: HopPalette.lavenderSoft)
        case .tadpole:
            return make(light: HopPalette.pondBlueLight, base: HopPalette.pondBlueDeep, deep: HopPalette.pondBlueInk, ground: HopPalette.pondBlueSoft)
        case .turtle:
            return make(light: HopPalette.hopGreenLight, base: HopPalette.hopGreenDeep, deep: HopPalette.hopGreenInk, ground: HopPalette.sand100)
        case .duckling:
            return make(light: HopPalette.sunshineSoft, base: HopPalette.sunshine, deep: HopPalette.sunshineDeep, ground: HopPalette.sunshineSoft)
        }
    }

    var isFrog: Bool {
        switch self {
        case .frogGreen, .frogBlue, .frogSunshine, .frogPeach, .frogLavender: true
        case .tadpole, .turtle, .duckling: false
        }
    }
}

/// A child's chosen creature.
///
/// Drawn, not photographed, and decorative by default — the nickname beside it
/// is what VoiceOver reads. Authored in a 100 × 100 box like the glyphs, so one
/// drawing serves a 28pt row and a 120pt profile header.
public struct HopAvatar: View {
    private let style: HopAvatarStyle
    private let size: CGFloat

    public init(style: HopAvatarStyle, size: CGFloat) {
        self.style = style
        self.size = size
    }

    private var scale: CGFloat { size / 100 }
    private var palette: (base: Color, deep: Color, light: Color, ground: Color) { style.palette }

    public var body: some View {
        ZStack {
            Circle().fill(palette.ground)
            creature
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var creature: some View {
        switch style {
        case .frogGreen, .frogBlue, .frogSunshine, .frogPeach, .frogLavender:
            frog
        case .tadpole:
            tadpole
        case .turtle:
            turtle
        case .duckling:
            duckling
        }
    }

    // MARK: - Creatures

    private var frog: some View {
        ZStack {
            oval(x: 50, y: 60, w: 74, h: 62, fill: palette.base)
            oval(x: 50, y: 74, w: 40, h: 26, fill: palette.light.opacity(0.75))
            eyeDome(x: 31, y: 34)
            eyeDome(x: 69, y: 34)
            smile(y: 62, width: 30)
            cheek(x: 20, y: 58)
            cheek(x: 80, y: 58)
        }
    }

    private var tadpole: some View {
        ZStack {
            // Tail first, so the body's edge covers where they join.
            tail
            oval(x: 44, y: 52, w: 52, h: 48, fill: palette.base)
            oval(x: 44, y: 62, w: 28, h: 18, fill: palette.light.opacity(0.6))
            pupil(x: 34, y: 44, r: 6)
            smile(y: 58, width: 16)
        }
    }

    private var tail: some View {
        HopAvatarTailShape()
            .fill(palette.deep)
            .frame(width: size, height: size)
    }

    private var turtle: some View {
        ZStack {
            oval(x: 68, y: 40, w: 30, h: 30, fill: palette.light)
            pupil(x: 74, y: 38, r: 4)
            oval(x: 46, y: 58, w: 66, h: 50, fill: palette.deep)
            oval(x: 46, y: 58, w: 44, h: 32, fill: palette.base)
            oval(x: 46, y: 58, w: 20, h: 15, fill: palette.light.opacity(0.8))
            oval(x: 24, y: 80, w: 22, h: 14, fill: palette.light)
            oval(x: 66, y: 82, w: 22, h: 14, fill: palette.light)
        }
    }

    private var duckling: some View {
        ZStack {
            oval(x: 52, y: 62, w: 62, h: 54, fill: palette.base)
            oval(x: 40, y: 34, w: 42, h: 40, fill: palette.base)
            oval(x: 52, y: 72, w: 30, h: 20, fill: palette.light.opacity(0.8))
            pupil(x: 34, y: 30, r: 5)
            HopAvatarBeakShape()
                .fill(palette.deep)
                .frame(width: size, height: size)
        }
    }

    // MARK: - Parts

    private func oval(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, fill: Color) -> some View {
        Ellipse()
            .fill(fill)
            .frame(width: w * scale, height: h * scale)
            .position(x: x * scale, y: y * scale)
    }

    private func eyeDome(x: CGFloat, y: CGFloat) -> some View {
        ZStack {
            Circle().fill(palette.light).frame(width: 26 * scale, height: 26 * scale)
            Circle().fill(Color.white).frame(width: 19 * scale, height: 19 * scale)
            Circle().fill(Color(HopPalette.midnight)).frame(width: 9 * scale, height: 9 * scale)
                .offset(y: 2 * scale)
        }
        .position(x: x * scale, y: y * scale)
    }

    private func pupil(x: CGFloat, y: CGFloat, r: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color.white).frame(width: (r + 3) * 2 * scale, height: (r + 3) * 2 * scale)
            Circle().fill(Color(HopPalette.midnight)).frame(width: r * 2 * scale, height: r * 2 * scale)
        }
        .position(x: x * scale, y: y * scale)
    }

    private func smile(y: CGFloat, width: CGFloat) -> some View {
        HopAvatarSmileShape(centreY: y, width: width)
            .stroke(Color(HopPalette.midnight).opacity(0.8), style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))
            .frame(width: size, height: size)
    }

    private func cheek(x: CGFloat, y: CGFloat) -> some View {
        Ellipse()
            .fill(Color(HopPalette.peachPop).opacity(0.5))
            .frame(width: 14 * scale, height: 9 * scale)
            .position(x: x * scale, y: y * scale)
    }
}

/// Shapes authored in the avatar's 100 × 100 box.
struct HopAvatarSmileShape: Shape {
    var centreY: CGFloat
    var width: CGFloat

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100
        var path = Path()
        path.move(to: CGPoint(x: (50 - width / 2) * scale, y: centreY * scale))
        path.addQuadCurve(
            to: CGPoint(x: (50 + width / 2) * scale, y: centreY * scale),
            control: CGPoint(x: 50 * scale, y: (centreY + 11) * scale)
        )
        return path
    }
}

struct HopAvatarTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100
        var path = Path()
        path.move(to: CGPoint(x: 62 * scale, y: 44 * scale))
        path.addQuadCurve(to: CGPoint(x: 94 * scale, y: 30 * scale), control: CGPoint(x: 84 * scale, y: 32 * scale))
        path.addQuadCurve(to: CGPoint(x: 88 * scale, y: 66 * scale), control: CGPoint(x: 96 * scale, y: 50 * scale))
        path.addQuadCurve(to: CGPoint(x: 62 * scale, y: 60 * scale), control: CGPoint(x: 78 * scale, y: 62 * scale))
        path.closeSubpath()
        return path
    }
}

struct HopAvatarBeakShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100
        var path = Path()
        path.move(to: CGPoint(x: 20 * scale, y: 36 * scale))
        path.addLine(to: CGPoint(x: 3 * scale, y: 42 * scale))
        path.addLine(to: CGPoint(x: 20 * scale, y: 48 * scale))
        path.closeSubpath()
        return path
    }
}

#Preview("Avatars") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 20) {
            ForEach(HopAvatarStyle.allCases) { style in
                VStack(spacing: 8) {
                    HopAvatar(style: style, size: 88)
                    Text(style.displayName).hopTextStyle(.parentCaption)
                }
            }
        }
        .padding()
    }
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Avatars · sizes and dark") {
    VStack(spacing: 24) {
        HStack(spacing: 12) {
            ForEach(HopAvatarStyle.allCases) { style in
                HopAvatar(style: style, size: 32)
            }
        }
        HopAvatar(style: .frogLavender, size: 120)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
    .preferredColorScheme(.dark)
}
