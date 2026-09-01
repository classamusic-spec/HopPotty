import SwiftUI
import HopPottyDesignTokens

/// Hop, drawn.
///
/// Vector paths rather than a raster asset, for three reasons that all matter:
/// the poses interpolate (Hop moves between them instead of cutting), one
/// drawing serves a 28pt dashboard chip and a 320pt celebration without a
/// separate export, and the geometry stays in step with
/// `Scripts/hop-art.js`, which generates the same character for the app icon
/// and the marketing art.
///
/// Ambient motion — the breath and the blink — is owned here and routed through
/// the modifiers in `Motion/`, so it stops under Reduce Motion without this
/// file ever asking whether Reduce Motion is on.
public struct HopCharacterView: View {
    @Environment(\.hopTheme) private var theme
    @State private var ambientBlink: Double = 0

    private let pose: HopPose
    private let size: CGFloat
    private let ambient: Bool
    private let castsShadow: Bool

    public init(pose: HopPose, size: CGFloat, ambient: Bool = true, castsShadow: Bool = true) {
        self.pose = pose
        self.size = size
        self.ambient = ambient
        self.castsShadow = castsShadow
    }

    private var geometry: HopPoseGeometry { pose.geometry }
    private var scale: CGFloat { size / HopCanvas.side }

    /// The pose's own blink, plus the ambient one. A pose that already has the
    /// eyes shut cannot be blinked further closed.
    private var blink: Double {
        min(1, geometry.blink + ambientBlink * (1 - geometry.blink))
    }

    public var body: some View {
        ZStack {
            Color.clear
            if castsShadow { groundShadow }
            character
                .offset(y: geometry.groupOffsetY * scale)
                .hopBreathing(ambient)
        }
        .frame(width: size, height: size)
        .hopBlinking(ambient, phase: $ambientBlink)
        .hopAnimation(pose.arrivalMotion, value: pose)
        .accessibilityHidden(true)
    }

    // MARK: - Layers, in the order `hop-art.js` stacks them

    private var character: some View {
        ZStack {
            if geometry.showsBag { bag }
            HopBodyShape(squash: geometry.squash)
                .fill(bodyGradient)
                .frame(width: size, height: size)
            sheen
            if geometry.showsBag { bagStrap }
            arm(geometry.leftArm)
            arm(geometry.rightArm)
            belly
            foot(geometry.leftFoot)
            foot(geometry.rightFoot)
            eyes
            cheeks
            mouth
        }
    }

    /// The body gradient's unit points are the SVG's `objectBoundingBox` stops
    /// re-expressed against the full canvas, since the shape is drawn at canvas
    /// scale rather than inside its own bounding box.
    private var bodyGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: HopCharacterPalette.bodyLight, location: 0),
                .init(color: HopCharacterPalette.bodyMid, location: 0.52),
                .init(color: HopCharacterPalette.bodyDeep, location: 1),
            ],
            startPoint: UnitPoint(x: 0.322, y: 0.363),
            endPoint: UnitPoint(x: 0.708, y: 0.840)
        )
    }

    private var sheen: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: .white.opacity(0.45), location: 0),
                        .init(color: .white.opacity(0), location: 1),
                    ],
                    center: UnitPoint(x: 0.34, y: 0.22),
                    startRadius: 0,
                    endRadius: 0.6 * 192 * scale
                )
            )
            .frame(width: 192 * scale, height: 140 * scale)
            .position(x: 200 * scale, y: 248 * scale)
    }

    private var belly: some View {
        Ellipse()
            .fill(HopCharacterPalette.belly.opacity(0.95))
            .overlay {
                Ellipse().stroke(HopCharacterPalette.bellyEdge, lineWidth: 3 * scale)
            }
            .frame(width: 172 * scale, height: 112 * scale)
            .position(x: 256 * scale, y: 364 * scale)
    }

    private var cheeks: some View {
        ZStack {
            cheek(x: 158)
            cheek(x: 354)
        }
    }

    private func cheek(x: CGFloat) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: HopCharacterPalette.cheekCore.opacity(0.85), location: 0),
                        .init(color: HopCharacterPalette.cheek.opacity(0.55), location: 0.55),
                        .init(color: HopCharacterPalette.cheek.opacity(0), location: 1),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 30 * scale
                )
            )
            .frame(width: 60 * scale, height: 38 * scale)
            .position(x: x * scale, y: 308 * scale)
    }

    private var groundShadow: some View {
        let lift = geometry.lift
        return Ellipse()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: HopCharacterPalette.groundShadow.opacity(0.20), location: 0),
                        .init(color: HopCharacterPalette.groundShadow.opacity(0), location: 1),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: (132 - lift * 0.35) * scale
                )
            )
            .frame(width: (132 - lift * 0.35) * 2 * scale, height: (26 - lift * 0.06) * 2 * scale)
            .position(x: 256 * scale, y: (452 + lift * 0.25) * scale)
    }

    private func arm(_ arm: HopArmGeometry) -> some View {
        ZStack {
            HopArmShape(origin: arm.origin, angle: arm.angle, length: arm.length, width: arm.width)
                .fill(HopCharacterPalette.bodyDeep)
            HopArmShape(origin: arm.origin, angle: arm.angle, length: arm.length, width: arm.width, isHighlight: true)
                .fill(HopCharacterPalette.bodyMid.opacity(0.5))
        }
        .frame(width: size, height: size)
    }

    private func foot(_ foot: HopFootGeometry) -> some View {
        ZStack {
            HopFootShape(centre: foot.resolvedCentre, flip: foot.flip, part: .body)
                .fill(HopCharacterPalette.bodyDeep)
            HopFootShape(centre: foot.resolvedCentre, flip: foot.flip, part: .highlight)
                .fill(HopCharacterPalette.bodyLight.opacity(0.45))
            HopFootShape(centre: foot.resolvedCentre, flip: foot.flip, part: .outline)
                .stroke(HopCharacterPalette.bodyShadow.opacity(0.35), lineWidth: 2.5 * scale)
        }
        .frame(width: size, height: size)
    }

    private var eyes: some View {
        ZStack {
            HopEyeView(centreX: 194, gaze: geometry.gaze, blink: blink, scale: scale)
            HopEyeView(centreX: 318, gaze: geometry.gaze, blink: blink, scale: scale)
            lash(x: 194)
            lash(x: 318)
        }
    }

    private func lash(x: CGFloat) -> some View {
        HopEyeLashShape(centre: CGPoint(x: x, y: 196), radius: 57)
            .stroke(
                HopCharacterPalette.ink.opacity(0.85),
                style: StrokeStyle(lineWidth: 8 * scale, lineCap: .round)
            )
            .frame(width: size, height: size)
            // The lash arrives as the lid closes rather than snapping in at the
            // end, which is what makes a slow blink read as a slow blink.
            .opacity(min(1, blink * 1.6))
    }

    private var mouth: some View {
        ZStack {
            HopMouthShape(open: geometry.mouthOpen)
                .fill(HopCharacterPalette.ink.opacity(0.9))
                .frame(width: size, height: size)
                .opacity(openMouthOpacity)

            HopMouthShape(open: geometry.mouthOpen, isTongue: true)
                .fill(HopCharacterPalette.cheek.opacity(0.85))
                .frame(width: size, height: size)
                .opacity(openMouthOpacity)

            HopSmileShape(smile: geometry.mouthSmile)
                .stroke(
                    HopCharacterPalette.mouth,
                    style: StrokeStyle(lineWidth: 11 * scale, lineCap: .round)
                )
                .frame(width: size, height: size)
                .opacity(1 - openMouthOpacity)
        }
    }

    /// The two mouths cross-fade rather than swap, so a pose change that opens
    /// Hop's mouth is one continuous movement.
    private var openMouthOpacity: Double {
        min(1, geometry.mouthOpen * 3)
    }

    private var bag: some View {
        ZStack {
            HopBagShape(part: .body).fill(HopCharacterPalette.bagBody)
            HopBagShape(part: .flap).fill(HopCharacterPalette.bagFlap)
            HopBagShape(part: .buckle).fill(HopCharacterPalette.bagStrap)
            HopBagShape(part: .body)
                .stroke(HopCharacterPalette.bagStrap.opacity(0.45), lineWidth: 3 * scale)
        }
        .frame(width: size, height: size)
    }

    private var bagStrap: some View {
        HopBagShape(part: .strap)
            .stroke(
                HopCharacterPalette.bagStrap.opacity(0.92),
                style: StrokeStyle(lineWidth: 12 * scale, lineCap: .round)
            )
            .frame(width: size, height: size)
    }
}

/// One eye: a skin dome, the white, and a pupil with two catchlights, all
/// clipped to the opening so a blink closes over them instead of fading them.
private struct HopEyeView: View {
    let centreX: CGFloat
    let gaze: CGSize
    let blink: Double
    let scale: CGFloat

    private let centreY: CGFloat = 196
    private let radius: CGFloat = 57
    private let pupilRadius: CGFloat = 25

    private var opening: Double { max(0.001, 1 - blink) }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [HopCharacterPalette.domeLight, HopCharacterPalette.domeDeep],
                        center: UnitPoint(x: 0.36, y: 0.28),
                        startRadius: 0,
                        endRadius: 0.75 * (radius + 3) * 2 * scale
                    )
                )
                .frame(width: (radius + 3) * 2 * scale, height: (radius + 3) * 2 * scale)

            ZStack {
                Ellipse().fill(HopCharacterPalette.eyeWhite)
                pupil
            }
            .frame(width: radius * 2 * scale, height: radius * 2 * scale)
            .mask {
                Ellipse().scaleEffect(y: opening, anchor: .center)
            }
        }
        .position(x: centreX * scale, y: centreY * scale)
    }

    private var pupil: some View {
        ZStack {
            Circle()
                .fill(HopCharacterPalette.pupil)
                .frame(width: pupilRadius * 2 * scale, height: pupilRadius * 2 * scale)

            Circle()
                .fill(Color.white.opacity(0.96))
                .frame(width: pupilRadius * 0.72 * scale, height: pupilRadius * 0.72 * scale)
                .offset(x: -pupilRadius * 0.36 * scale, y: -pupilRadius * 0.42 * scale)

            Circle()
                .fill(Color.white.opacity(0.72))
                .frame(width: pupilRadius * 0.34 * scale, height: pupilRadius * 0.34 * scale)
                .offset(x: pupilRadius * 0.32 * scale, y: pupilRadius * 0.34 * scale)
        }
        .scaleEffect(1 - blink * 0.35)
        .offset(x: gaze.width * scale, y: gaze.height * (1 - blink) * scale)
    }
}
