import SwiftUI
import UIKit
import HopPottyCore

/// Draws an illustration named by a ``HopIllustrationKey``.
///
/// Feature code never names a file. It names the *key* Core already declared —
/// `scene.routine.try`, `icon.quiz.soap`, `pond.lilyPadSmall` — and this view
/// resolves it. The naming rule is one line and mechanical: **dots become
/// dashes**, so `icon.quiz.washHands` is the image asset `icon-quiz-washHands`.
/// That is the contract the art export pipeline has to satisfy; nothing else in
/// the app knows or cares where an SVG came from.
///
/// When the asset is not in the bundle the view draws a soft placeholder rather
/// than an empty box. Art lands over weeks and a half-drawn catalog must not
/// make a screen unusable for the child who has it today.
struct HopArtwork: View {
    @Environment(\.hopTheme) private var theme

    let key: HopIllustrationKey
    /// The label a screen reader hears. `nil` marks the drawing as decorative,
    /// which is correct only when a real label sits beside it.
    let accessibilityLabel: String?

    init(_ key: HopIllustrationKey, accessibilityLabel: String? = nil) {
        self.key = key
        self.accessibilityLabel = accessibilityLabel
    }

    /// The asset-catalog name for a key.
    ///
    /// Delegated to `HopIllustrationKey.assetName`, which is the contract the
    /// art pipeline actually satisfies: **drop the family segment and join what
    /// remains with hyphens**, so `scene.routine.try` is `routine-try`. This
    /// file used to replace every dot with a hyphen instead, which produced
    /// `scene-routine-try` and would have missed every exported drawing the day
    /// the catalog landed. Nothing caught it because the catalog is still empty
    /// — `HopArtwork` drew its placeholder either way.
    static func assetName(for key: HopIllustrationKey) -> String {
        key.assetName
    }

    /// Whether the bundle actually carries this drawing.
    ///
    /// Public to the feature layer because a screen's *ground* has to know: a
    /// missing picture inside a screen is a placeholder, but a missing picture
    /// behind the words is a lilac blob under a sentence, and a caller that can
    /// ask simply draws the room instead.
    ///
    /// Checked per render rather than cached: the answer is fixed for the life
    /// of the process and `UIImage(named:)` is itself cached by UIKit.
    static func hasAsset(for key: HopIllustrationKey) -> Bool {
        UIImage(named: assetName(for: key)) != nil
    }

    private var isPresent: Bool { Self.hasAsset(for: key) }

    var body: some View {
        Group {
            if isPresent {
                Image(Self.assetName(for: key))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                HopArtworkPlaceholder(seed: key.rawValue)
            }
        }
        .modifier(HopArtworkAccessibility(label: accessibilityLabel))
    }
}

/// Applies the label, or hides the drawing when it carries no meaning of its own.
private struct HopArtworkAccessibility: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label {
            content
                .accessibilityElement()
                .accessibilityLabel(label)
                // `.image` tells VoiceOver this is a picture rather than a
                // control, so a child's helper is not invited to double-tap it.
                .accessibilityAddTraits(.isImage)
        } else {
            content.accessibilityHidden(true)
        }
    }
}

/// The stand-in for a drawing that has not shipped yet.
///
/// Deliberately a soft, warm, slightly organic blob rather than a grey box with
/// a question mark: on a child's screen a missing asset should look like part
/// of the pond, not like a broken image. The shape varies with the key so two
/// adjacent placeholders are not identical twins.
private struct HopArtworkPlaceholder: View {
    @Environment(\.hopTheme) private var theme
    let seed: String

    /// A stable 0...1 value from the key. Same key, same blob, every launch.
    private var variance: Double {
        let hash = seed.unicodeScalars.reduce(UInt32(2_166_136_261)) { partial, scalar in
            (partial ^ scalar.value) &* 16_777_619
        }
        return Double(hash % 1000) / 1000
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            RoundedRectangle(cornerRadius: side * (0.28 + variance * 0.18), style: .continuous)
                .fill(HopColors.wash(theme.color.brandSecondary, isDark: theme.isDark))
                .overlay {
                    RoundedRectangle(cornerRadius: side * (0.28 + variance * 0.18), style: .continuous)
                        .strokeBorder(theme.color.divider, lineWidth: theme.isHighContrast ? 1.5 : 0.75)
                }
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Pond items

extension HopIllustrationKey {
    /// The drawing for a pond decoration.
    ///
    /// `PondItem` carries geometry and a price but no art key, so the key is
    /// derived from the stable enum raw value. Deriving rather than storing
    /// means a new decoration cannot ship pointing at the wrong picture.
    static func pondItem(_ id: PondItemID) -> HopIllustrationKey {
        HopIllustrationKey(rawValue: "pond." + id.rawValue)
    }

    /// The drawing for one of Hop's poses.
    static func character(_ pose: String) -> HopIllustrationKey {
        HopIllustrationKey(rawValue: "character." + pose)
    }
}

#Preview("Artwork · keys that exist and keys that do not") {
    VStack(spacing: 24) {
        HStack(spacing: 20) {
            HopArtwork("scene.routine.try", accessibilityLabel: "Hop sitting on the potty")
            HopArtwork(.pondItem(.lilyPadSmall), accessibilityLabel: "A small lily pad")
            HopArtwork("icon.quiz.soap", accessibilityLabel: "A pump of soap")
        }
        .frame(height: 140)
    }
    .padding()
    .hopBackground()
    .hopThemedRoot()
}
