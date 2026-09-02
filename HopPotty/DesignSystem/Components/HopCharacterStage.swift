import SwiftUI
import HopPottyDesignTokens

/// Hop, placed on a surface and described to assistive technology.
///
/// The drawing itself is decorative — ``HopCharacterView`` hides it — and the
/// stage is what carries the label, because the label depends on what Hop is
/// doing here, not on how he is drawn.
public struct HopCharacterStage: View {
    private let pose: HopPose
    private let size: CGFloat
    private let ambient: Bool
    private let accessibilityLabel: String?

    public init(pose: HopPose, size: CGFloat, ambient: Bool = true) {
        self.pose = pose
        self.size = size
        self.ambient = ambient
        self.accessibilityLabel = nil
    }

    /// Overrides the spoken description, for the cases where the surrounding
    /// screen has already said what Hop is doing and repeating it is noise.
    /// Pass an empty string to make the illustration purely decorative.
    ///
    /// A distinct argument label, not a defaulted parameter, so this never
    /// competes with the primary initialiser at a two-argument call site.
    public init(pose: HopPose, size: CGFloat, ambient: Bool = true, describedAs description: String) {
        self.pose = pose
        self.size = size
        self.ambient = ambient
        self.accessibilityLabel = description
    }

    public var body: some View {
        HopCharacterView(pose: pose, size: size, ambient: ambient)
            .frame(width: size, height: size)
            .modifier(HopStageLabel(label: accessibilityLabel ?? pose.accessibilityDescription))
    }
}

/// Applies the label, or removes the element entirely when the caller has said
/// the illustration is decorative here.
private struct HopStageLabel: ViewModifier {
    let label: String

    func body(content: Content) -> some View {
        if label.isEmpty {
            content.accessibilityHidden(true)
        } else {
            content
                .accessibilityElement()
                .accessibilityLabel(label)
                .accessibilityAddTraits(.isImage)
        }
    }
}

/// A small, circular Hop for a row or a toolbar. Always `idle`, never ambient:
/// a chip that breathes in a settings list is a distraction.
///
/// This is the app's use of the generator's `face` entry. Rather than a second
/// drawing, it is `idle` scaled and shifted so that
/// ``HopPoseGeometry/faceCrop`` — the rectangle Hop's head occupies — fills the
/// circle. One drawing, one set of numbers, and a head that cannot drift out of
/// step with the body it belongs to.
public struct HopChip: View {
    private let diameter: CGFloat

    public init(diameter: CGFloat = 32) {
        self.diameter = diameter
    }

    /// How big the whole 512 canvas has to be for the head to fill the circle,
    /// with a tenth of the head's width left as breathing room.
    private var renderSize: CGFloat {
        diameter * HopCanvas.side / (HopPoseGeometry.faceCrop.width * 1.1)
    }

    /// Moves the head's centre onto the circle's centre.
    private var faceOffset: CGFloat {
        (HopCanvas.side / 2 - HopPoseGeometry.faceCrop.midY) * renderSize / HopCanvas.side
    }

    public var body: some View {
        HopCharacterView(pose: .idle, size: renderSize, ambient: false, castsShadow: false)
            .offset(y: faceOffset)
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .background {
                Circle().fill(HopCharacterPalette.belly)
            }
            .accessibilityHidden(true)
    }
}

#if DEBUG
private struct HopPoseSheet: View {
    var ambient: Bool = false

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 24) {
                ForEach(HopPose.allCases) { pose in
                    VStack(spacing: 8) {
                        HopCharacterStage(pose: pose, size: 140, ambient: ambient)
                        Text(pose.rawValue)
                            .hopTextStyle(.parentCaption)
                    }
                }
            }
            .padding()
        }
    }
}

/// Steps through the poses on a timer so the interpolation between them can be
/// checked, which a static grid cannot show.
private struct HopPoseTransitionPreview: View {
    @State private var index = 0

    var body: some View {
        VStack(spacing: 24) {
            HopCharacterStage(pose: HopPose.allCases[index], size: 220)
            HopSecondaryButton("Next pose") {
                index = (index + 1) % HopPose.allCases.count
            }
            Text(HopPose.allCases[index].rawValue)
                .hopTextStyle(.parentCaption)
        }
        .padding()
    }
}

#Preview("Hop · all poses") {
    HopPoseSheet()
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Hop · ambient (breath + blink)") {
    VStack(spacing: 32) {
        HopCharacterStage(pose: .idle, size: 240)
        HopCharacterStage(pose: .wait, size: 160)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Hop · Reduce Motion (must be still)") {
    VStack(spacing: 32) {
        HopCharacterStage(pose: .idle, size: 240)
        Text("No breath, no blink.").hopTextStyle(.parentCaption)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot(reduceMotion: true)
}

#Preview("Hop · pose transitions") {
    HopPoseTransitionPreview()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Hop · dark stage") {
    HopPoseSheet()
        .hopBackground()
        .hopThemedRoot()
        .preferredColorScheme(.dark)
}

#Preview("Hop · sizes and chip") {
    VStack(spacing: 24) {
        HStack(alignment: .bottom, spacing: 20) {
            HopCharacterStage(pose: .idle, size: 44, ambient: false)
            HopCharacterStage(pose: .idle, size: 88, ambient: false)
            HopCharacterStage(pose: .idle, size: 160, ambient: false)
        }
        HStack(spacing: 12) {
            HopChip()
            HopChip(diameter: 48)
            Text("Sam").hopTextStyle(.parentBody)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot()
}
#endif
