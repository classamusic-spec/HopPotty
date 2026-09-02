import SwiftUI
import HopPottyDesignTokens

/// The launch animation, as numbers.
///
/// Separated from the view because it is the part worth reading and the part
/// worth checking: every duration below is a `HopMotion` token, the total is a
/// product commitment, and `Scripts/web/motion.js` mirrors all of it so the web
/// prototype shows the caregiver the same thing the app will.
///
/// ## The beats
///
/// ```
///   0.02  "Hop" leaves the left edge, stretched                jumpRise
///   0.12  "Potty" leaves the right edge, a hop behind          jumpRepeatGap
///   0.28  "Hop" is at the top of its arc, and hangs            jumpHang
///   0.34  "Hop" falls
///   0.44  "Potty" falls                                        jumpFall
///   0.52  the frog gathers itself behind the wordmark          jumpCrouch
///   0.56  "Hop" lands, flattened, and settles                  jumpSettle
///   0.66  "Potty" lands, and the frog pops up over the words   childArrive
///   0.71  the tagline pill settles in last                     stagger
///   1.26  everything is at rest
///   1.36  the whole splash cross-fades out                     reducedMotionFade
///   1.56  gone
/// ```
///
/// ## The two rules it exists to keep
///
/// **It never delays the app.** The splash is an overlay over a view tree that
/// is already loading; the launch work starts on the same frame the first hop
/// does. When the beat is over the splash leaves, whether or not the app is
/// ready — if it is not, the caregiver sees the loading state that would have
/// been there anyway. Nothing here waits on anything, and nothing loops.
///
/// **It never travels under Reduce Motion.** The decision is
/// ``HopAnimationToken/allowsTravel(reduceMotion:)`` and nothing else, and every
/// spring below is degraded by that same one gate, so the reduced choreography
/// is not a second animation — it is this one with the movement removed: the
/// assembled lockup fades up, holds, and fades out, in under a second, because
/// there is nothing to watch.
struct HopSplashChoreography: Sendable {

    /// One change to one layer, at one moment.
    struct Step: Equatable, Sendable {
        let at: Double
        let layer: HopLogoLayer
        let spring: HopSpring
        let placement: HopLogoPlacement
    }

    // MARK: - Sizing

    /// How much of the screen's width the lockup takes, and the point at which
    /// it stops growing. An iPad splash with a 700pt logo on it is a poster.
    static let logoWidthFraction: CGFloat = 0.74
    static let logoMaxWidth: CGFloat = 360

    /// Extra travel past the screen edge, in logo widths, so a word clears the
    /// edge by its sticker outline rather than stopping exactly at it.
    private static let clearance: CGFloat = 0.04

    // MARK: - Timing
    //
    // Absolute offsets from the first frame rather than gaps, so retuning one
    // beat cannot silently push the total past the ceiling.

    /// One frame of nothing, before the first movement.
    ///
    /// The opening positions and the first animation must not land in the same
    /// SwiftUI transaction: a change applied in the frame that establishes the
    /// state it changes has nothing to animate *from*, and snaps. This is the
    /// gap that keeps them apart, and it is the smallest gap that does.
    static let leadIn: Double = 0.02

    /// How long the finished lockup is held before it leaves. Long enough to
    /// read as a held frame rather than as a bounce that never finished.
    static let hold: Double = 0.10

    /// The hold under Reduce Motion, where there is no arrival to watch: the
    /// lockup is simply shown, for long enough to be seen and no longer.
    static let reducedHold: Double = HopMotion.childArrive.duration

    let reduceMotion: Bool
    let logoWidth: CGFloat
    private let containerWidth: CGFloat

    init(reduceMotion: Bool, container: CGSize) {
        self.reduceMotion = reduceMotion
        self.containerWidth = container.width
        self.logoWidth = min(container.width * Self.logoWidthFraction, Self.logoMaxWidth)
    }

    /// Whether anything may travel across the screen. The design system's one
    /// answer to that question; this file does not have a second opinion.
    var travels: Bool { HopAnimationToken.allowsTravel(reduceMotion: reduceMotion) }

    // MARK: - The plan

    /// Where every layer starts. Applied with no animation.
    var opening: HopLogoLayout {
        guard travels else {
            // Nothing moves: the assembled lockup, invisible, waiting to fade up.
            var layout = HopLogoLayout.assembled
            for layer in HopLogoLayer.allCases { layout[layer].opacity = 0 }
            return layout
        }
        var layout = HopLogoLayout.assembled
        layout.hop = airborne(.hop, at: offstage(.hop, edge: -1), height: 0)
        layout.potty = airborne(.potty, at: offstage(.potty, edge: 1), height: 0)
        layout.mascot = hidden
        layout.tagline = HopLogoPlacement(offset: CGSize(width: 0, height: 0.05), opacity: 0)
        return layout
    }

    /// Every change, in the order it happens.
    var steps: [Step] {
        guard travels else {
            // The one beat there is: everything appears where it belongs. The
            // spring is degraded to a cross-fade by the same gate that decided
            // there would be no travel.
            return HopLogoLayer.allCases.map {
                Step(at: Self.leadIn, layer: $0, spring: HopMotion.childArrive, placement: .placed)
            }
        }
        return (hop(.hop, from: -1, start: Self.leadIn)
            + hop(.potty, from: 1, start: pottyStart)
            + mascotPop
            + taglineArrival)
            .sorted { $0.at < $1.at }
    }

    /// When the splash starts fading out, and when it is gone.
    var fadeOutAt: Double {
        let settled = steps.map { $0.at + $0.spring.duration(reduceMotion: reduceMotion) }.max() ?? Self.leadIn
        return settled + (travels ? Self.hold : Self.reducedHold)
    }

    /// First frame to gone. The number the product owes a caregiver who sees
    /// this several times a day.
    var total: Double { fadeOutAt + HopMotion.reducedMotionFade }

    // MARK: - One word's hop
    //
    // The four beats of `HopJumpMotion`, minus the crouch: a word arriving from
    // off-screen took off out there, and a visible crouch would only add a word
    // sitting still on an empty screen before it moves.
    //
    // The two words are one gesture rather than two, which is what
    // `jumpRepeatGap` means — the gap that makes repeated hops read as one
    // burst rather than as a queue — so it is the gap between them here too.

    private var pottyStart: Double { Self.leadIn + HopMotion.jumpRepeatGap }

    /// When a word that left at `start` puts its feet down.
    private func landing(after start: Double) -> Double {
        start + HopMotion.jumpRise.duration + HopMotion.jumpHang + HopMotion.jumpFall.duration
    }

    private func hop(_ layer: HopLogoLayer, from edge: CGFloat, start: Double) -> [Step] {
        let falls = start + HopMotion.jumpRise.duration + HopMotion.jumpHang
        return [
            // Up and most of the way across, stretched along the travel.
            Step(at: start, layer: layer, spring: HopMotion.jumpRise,
                 placement: airborne(layer, at: offstage(layer, edge: edge) * 0.42, height: layer.arcHeight)),
            // Down onto its line, and flattened onto it by the impact.
            Step(at: falls, layer: layer, spring: HopMotion.jumpFall,
                 placement: flattened(layer)),
            // The bounce, which is where a hop stops being a slide.
            Step(at: landing(after: start), layer: layer, spring: HopMotion.jumpSettle,
                 placement: .placed),
        ]
    }

    /// The frog: a gather, then up over the wordmark carrying the arrival
    /// spring's own overshoot.
    ///
    /// It is painted *under* the two words (`PAINT_ORDER` in
    /// `Scripts/logo-art.js`), so it grows out from behind the letters rather
    /// than across them — which is what "pops up behind the wording" means.
    private var mascotPop: [Step] {
        let lands = landing(after: pottyStart)
        return [
            Step(at: lands - HopMotion.jumpCrouch.duration, layer: .mascot,
                 spring: HopMotion.jumpCrouch, placement: gathered),
            Step(at: lands, layer: .mascot,
                 spring: HopMotion.childArrive, placement: .placed),
        ]
    }

    /// The tagline, one stagger step behind the frog, because a pill that
    /// arrives with everything else is a pill nobody notices arriving.
    private var taglineArrival: [Step] {
        [Step(at: landing(after: pottyStart) + HopMotion.stagger(index: 1),
              layer: .tagline, spring: HopMotion.childArrive, placement: .placed)]
    }

    // MARK: - Placements

    /// How far off-screen a layer has to be to be *off* screen: past the gap
    /// between the logo and the container, past its own drawing, plus the
    /// clearance. In logo widths, because that is what ``HopLogoPlacement``
    /// measures offsets in.
    private func offstage(_ layer: HopLogoLayer, edge: CGFloat) -> CGFloat {
        let gap = (containerWidth - logoWidth) / 2 / logoWidth
        let box = HopLogoArtwork.viewBox.width
        let extent = edge < 0
            ? layer.art.bounds.maxX / box
            : 1 - layer.art.bounds.minX / box
        return edge * (gap + extent + Self.clearance)
    }

    /// In the air: stretched along the direction of travel, about its own line.
    private func airborne(_ layer: HopLogoLayer, at x: CGFloat, height: CGFloat) -> HopLogoPlacement {
        HopLogoPlacement(
            offset: CGSize(width: x, height: -height),
            scaleX: 1 / HopMotion.jumpStretch,
            scaleY: HopMotion.jumpStretch,
            anchor: layer.groundAnchor
        )
    }

    /// The impact: on its line, flattened onto it.
    private func flattened(_ layer: HopLogoLayer) -> HopLogoPlacement {
        HopLogoPlacement(
            scaleX: 1 / HopMotion.jumpSquash,
            scaleY: HopMotion.jumpSquash,
            anchor: layer.groundAnchor
        )
    }

    /// The frog before it is seen: shrunk down onto the line the wordmark lands
    /// on, and transparent.
    ///
    /// Both, not either. Small alone would leave a frog-coloured pebble sitting
    /// on an empty screen for half a second before there is any wordmark to be
    /// behind; transparent alone would make the arrival a fade, and the product
    /// owner asked for a pop.
    private var hidden: HopLogoPlacement {
        HopLogoPlacement(
            offset: CGSize(width: 0, height: 0.05),
            scaleX: Self.mascotHiddenScale,
            scaleY: Self.mascotHiddenScale,
            opacity: 0,
            anchor: HopLogoLayer.mascot.groundAnchor
        )
    }

    /// The gather: smaller still, lower still, and now opaque — which is nearly
    /// free to see, because by this beat it is a thumbnail-sized shape sitting
    /// where the wordmark is landing on top of it.
    private var gathered: HopLogoPlacement {
        var placement = hidden
        placement.offset.height = 0.07
        placement.scaleX = Self.mascotGatherScale
        placement.scaleY = Self.mascotGatherScale
        placement.opacity = 1
        return placement
    }

    /// Small enough to sit inside the "P" of "Potty" — which is where it sits,
    /// and which is why it can be made opaque a beat early without being seen.
    private static let mascotHiddenScale: CGFloat = 0.12
    private static let mascotGatherScale: CGFloat = 0.09
}
