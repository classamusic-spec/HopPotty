import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

// Direct manipulation in Hop's Pond.
//
// The pond is a place a child can put a finger on. Touching a flower opens it
// slightly, a fish darts and leaves a ripple, a lily pad bobs, a butterfly moves
// on, Hop looks over — and the water itself rings where the finger landed.
//
// **Every one of these is one short answer and then nothing.** There is no
// counter, no combo, no "tap it three times", no escalating response and no
// reason to come back and do it again: the pond answers because a living place
// answers, and then it is quiet. A pond that rewarded touching would be an
// engagement loop (`Docs/ChildSafety.md` §1.4), which is the one thing this
// screen must never become.
//
// TODO: `PondReaction` and its modifier belong beside `HopPondIdle` in
// `DesignSystem/Motion/HopPondMotion.swift` — they are the same kind of object,
// one for the pond at rest and one for the pond answering. They live here until
// that file can be edited, exactly as `HopGaze.eyeSpring` lives in
// `HopPerformance.swift` with a note saying it belongs in `HopMotion`.

// MARK: - What a thing does when it is touched

/// The six answers a pond object can give.
///
/// A closed list on purpose. Six named behaviours is a vocabulary an author can
/// hold in their head and a reviewer can check at a glance; "any animation you
/// like, per object" is how a calm scene becomes a fairground. Every case is
/// **short, bounded and self-cancelling**: it starts at the object's authored
/// position and ends there, so a pond nobody is touching is always the pond as
/// drawn.
enum PondReaction: String, CaseIterable, Sendable {
    /// Open water. Rings spread from the touch and fade.
    case ripple
    /// Airborne: a butterfly, a dragonfly, fireflies. Wings quicken and it
    /// moves a short way on.
    case flutter
    /// Afloat: a lily pad, a duckling, driftwood. Dips and settles.
    case bob
    /// Something under the surface. Darts, and the water rings behind it.
    case swim
    /// A flower. Opens a little, and stays open no longer than a breath.
    case bloom
    /// Hop. He looks at the finger and waves.
    case wave

    /// How long the whole answer lasts, in seconds.
    ///
    /// All under a second and a half. Long enough to be seen, short enough that
    /// a child who taps twice gets two answers rather than a queue.
    var duration: Double {
        switch self {
        case .ripple: 1.1
        case .flutter: 0.9
        case .bob: 0.8
        case .swim: 1.2
        case .bloom: 0.7
        case .wave: 1.3
        }
    }
}

// MARK: - The registry

/// One touchable thing in the pond.
///
/// Registered by whoever draws it, in the scene's own unit coordinates, so the
/// registry needs to know nothing about pixels, layout or the device.
struct PondInteractiveObject: Identifiable, Equatable {
    /// Stable and unique within one pond. Catalogue decorations use their
    /// `PondItemID.rawValue`; scenery uses the layer name it is drawn under
    /// (`pond-fish-1`, `pond-lily-2`), which is the same name the SVG exposes.
    let id: String
    let reaction: PondReaction
    /// Where it is, in unit coordinates: x and y from 0 to 1 across the scene.
    let anchor: CGPoint
    /// How far from `anchor` a touch still counts, in units of scene width.
    ///
    /// Generous by design — these are three-year-old fingers on small drawings —
    /// but never so generous that two neighbours overlap: `touch(at:)` resolves
    /// a contested point to the nearest centre, so a wide radius costs accuracy
    /// rather than correctness.
    let radius: Double

    /// What VoiceOver would call this. `nil` for scenery the collection strip
    /// already lists, which is everything in the catalogue.
    var label: String?
}

/// Every touchable thing in one pond, and which one is answering right now.
///
/// ## Deterministic
///
/// The same touch, on the same pond, produces the same answer every time: there
/// is no randomness here, no queue and no scheduler. `activations` is a plain
/// tally per object, and each reaction is a pure function of that tally — which
/// is what lets the whole thing be driven by SwiftUI's own animation rather than
/// by a timer this object would have to own.
///
/// ## Lightweight
///
/// The registry costs one dictionary lookup per touch and holds no per-frame
/// state at all. Nothing in this file runs on a clock, nothing here allocates
/// while the pond is idle, and a pond nobody is touching is exactly as expensive
/// as a still drawing.
@MainActor
@Observable
final class PondInteractionRegistry {

    /// The registered objects, in registration order — which is back-to-front,
    /// because that is the order the scene draws in.
    private(set) var objects: [PondInteractiveObject] = []

    /// How many times each object has been touched. The reaction modifiers watch
    /// this and run one beat per increment.
    private(set) var activations: [String: Int] = [:]

    /// The last place the child touched, in unit coordinates, or `nil` before
    /// the first touch. Hop follows it (§27) and the water rings there.
    private(set) var lastTouch: CGPoint?

    /// A tally of touches on open water, so the ripple layer can answer one
    /// without an object being registered for every square inch of pond.
    private(set) var waterTouches = 0

    // MARK: Registering

    /// Registers one touchable object.
    ///
    /// Re-registering an id replaces it rather than adding a second: the scene
    /// re-registers on every layout change, and a pond that accumulated a copy
    /// of every lily pad each time the keyboard appeared would slow down for
    /// reasons nobody could see.
    func registerInteractiveObject(
        id: String,
        reaction: PondReaction,
        at anchor: CGPoint,
        radius: Double = 0.075,
        label: String? = nil
    ) {
        let object = PondInteractiveObject(
            id: id,
            reaction: reaction,
            anchor: anchor,
            radius: radius,
            label: label
        )
        if let index = objects.firstIndex(where: { $0.id == id }) {
            guard objects[index] != object else { return }
            objects[index] = object
        } else {
            objects.append(object)
        }
    }

    /// Registers a catalogue decoration, deriving its reaction from what the
    /// thing *is*.
    ///
    /// Exhaustive over the catalogue rather than a lookup table with a default,
    /// so a forty-second decoration cannot ship with an unconsidered response.
    func registerInteractiveObject(_ item: PondItem, label: String? = nil) {
        registerInteractiveObject(
            id: item.id.rawValue,
            reaction: PondInteractionRegistry.reaction(for: item.id),
            at: CGPoint(x: item.anchor.x, y: item.anchor.y),
            radius: 0.055 + 0.03 * item.anchor.scale,
            label: label
        )
    }

    /// Forgets every registered object. Called when the scene rebuilds from
    /// scratch — a different child, or a pond that just gained an item.
    func removeAll() {
        objects.removeAll(keepingCapacity: true)
    }

    // MARK: Touching

    /// Routes a touch to the nearest object that contains it, and returns it.
    ///
    /// Nothing is ever "missed": a touch that lands on no object is a touch on
    /// the water, which answers with a ripple. That is the whole reason there is
    /// no failure path here — every point in the pond does something.
    @discardableResult
    func touch(at point: CGPoint) -> PondInteractiveObject? {
        lastTouch = point

        var best: PondInteractiveObject?
        var bestDistance = Double.greatestFiniteMagnitude
        for object in objects {
            let dx = Double(point.x - object.anchor.x)
            let dy = Double(point.y - object.anchor.y)
            let distance = (dx * dx + dy * dy).squareRoot()
            guard distance <= object.radius, distance < bestDistance else { continue }
            best = object
            bestDistance = distance
        }

        guard let best else {
            waterTouches += 1
            return nil
        }
        activations[best.id, default: 0] += 1
        return best
    }

    /// The tally for one object. Zero for anything never touched.
    func activationCount(_ id: String) -> Int { activations[id] ?? 0 }

    /// Where Hop should be looking: the last touch, or straight ahead.
    ///
    /// Expressed in Hop's own frame rather than the scene's, because that is
    /// what ``HopGaze`` takes — his frame is roughly a fifth of the scene wide,
    /// so a touch on the far bank is off the side of him and reads as a full
    /// turn of the head rather than a glance.
    func gaze(fromHopAt hop: CGPoint, hopExtent: Double) -> HopGaze {
        guard let lastTouch, hopExtent > 0 else { return .forward }
        let dx = Double(lastTouch.x - hop.x) / hopExtent
        let dy = Double(lastTouch.y - hop.y) / hopExtent
        return HopGaze(x: CGFloat(0.5 + dx), y: CGFloat(0.5 + dy))
    }

    // MARK: What each decoration does

    /// The reaction one catalogue decoration gives.
    ///
    /// The same four-way reading of the pond that ``HopPondIdle`` uses for what a
    /// thing does at rest — afloat, rooted, airborne, or put there and staying
    /// put — with two refinements the idle does not need: a flower blooms rather
    /// than merely swaying, and something under the surface swims rather than
    /// bobbing on it. Exhaustive with no `default`.
    static func reaction(for id: PondItemID) -> PondReaction {
        switch id {
        // Under the surface, or moving through it.
        case .fishOrange, .fishBlue, .tadpoleFriend, .duckling, .turtleRock:
            return .swim

        // Afloat.
        case .lilyPadSmall, .lilyPadLarge, .waterLilyCluster, .driftwood, .moonReflection:
            return .bob

        // Flowers, and the things that behave like them.
        case .flowerYellow, .flowerPink, .flowerPurple, .lilyFlower,
             .mushroomCluster, .blossomTree:
            return .bloom

        // Airborne.
        case .butterflyBlue, .butterflyYellow, .dragonfly, .fireflies, .cloudPuff:
            return .flutter

        // Hop's own kind. They wave back.
        case .frogFriendGreen, .frogFriendBlue:
            return .wave

        // Rooted, built, dropped, or made of light. A touch stirs the air
        // around them; nothing about them travels.
        case .reedsLeft, .reedsRight, .cattails, .fernPatch,
             .stoneSmall, .stoneStack, .pebblePath,
             .snail, .ladybug,
             .rainbow, .sunbeam,
             .clubhouse, .signpost, .birdhouse,
             .lantern, .starLantern, .windChime, .pondSwing:
            return .bloom
        }
    }
}

// MARK: - Playing a reaction

/// Runs one object's reaction when its tally changes.
///
/// Declarative rather than clock-driven, for the same reason ``HopPondIdle`` is:
/// the pond can be forty-one image views, and re-evaluating all of them every
/// frame to nudge one is the wrong trade. A tally change flips one Boolean, and
/// the render server animates out and back on its own.
///
/// **Reduce Motion keeps the answer and drops the movement.** A touched flower
/// still says it was touched — it brightens for a moment — but nothing bounces,
/// nothing travels and nothing rotates. The state the child produced is
/// preserved; only the journey to it is removed (§21).
private struct PondReactionModifier: ViewModifier {
    @Environment(\.hopTheme) private var theme

    let reaction: PondReaction
    let activations: Int
    /// The drawn size of the thing reacting, so a duckling's dart is a
    /// duckling's dart and not a blossom tree's.
    let extent: CGFloat

    /// True for the length of one answer.
    @State private var isReacting = false

    private var moves: Bool { !theme.reduceMotion }

    private var offsetY: CGFloat {
        guard isReacting, moves else { return 0 }
        switch reaction {
        case .bob: return extent * 0.06
        case .flutter: return -extent * 0.10
        case .swim: return -extent * 0.04
        case .wave: return -extent * 0.04
        case .bloom, .ripple: return 0
        }
    }

    private var offsetX: CGFloat {
        guard isReacting, moves else { return 0 }
        switch reaction {
        case .flutter: return extent * 0.12
        case .swim: return extent * 0.16
        case .bob, .bloom, .wave, .ripple: return 0
        }
    }

    private var scale: CGFloat {
        guard isReacting else { return 1 }
        guard moves else { return 1 }
        switch reaction {
        case .bloom: return 1.09
        case .bob: return 0.97
        case .wave: return 1.05
        case .flutter, .swim, .ripple: return 1
        }
    }

    private var degrees: Double {
        guard isReacting, moves else { return 0 }
        switch reaction {
        case .flutter: return -7
        case .swim: return 6
        case .bob: return 2.5
        case .bloom, .wave, .ripple: return 0
        }
    }

    /// The one thing Reduce Motion keeps: the object brightens for a beat, so
    /// the touch is still answered on a screen with no movement on it at all.
    private var brightness: Double { isReacting ? 0.08 : 0 }

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: .center)
            .rotationEffect(.degrees(degrees), anchor: .center)
            .offset(x: offsetX, y: offsetY)
            .brightness(brightness)
            .animation(.easeOut(duration: reaction.duration * 0.35), value: isReacting)
            .onChange(of: activations) { _, _ in
                isReacting = true
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(reaction.duration * 0.45))
                    isReacting = false
                }
            }
    }
}

extension View {
    /// Answers a touch on a pond object. No-op until the tally moves.
    func pondReaction(_ reaction: PondReaction, activations: Int, extent: CGFloat) -> some View {
        modifier(PondReactionModifier(reaction: reaction, activations: activations, extent: extent))
    }
}

// MARK: - The ring a touch leaves on the water

/// One expanding ring, at the point a finger landed.
///
/// Drawn as a stroked circle that grows and fades — no filter, no blur and no
/// shadow, because those are the three things that stop a pond hitting 60fps on
/// the phones this app is actually used on (§50).
///
/// Under Reduce Motion it is a single soft ring that fades in place: the touch
/// is still acknowledged, nothing expands.
struct PondTouchRing: View {
    @Environment(\.hopTheme) private var theme

    /// Where the finger landed, in unit coordinates.
    let unitPoint: CGPoint
    /// Increments once per touch. The ring restarts from nothing each time.
    let activations: Int
    let sceneSize: CGSize

    @State private var isSpreading = false

    private var side: CGFloat { PondGeometry.stage(in: sceneSize).width * 0.26 }

    var body: some View {
        Circle()
            .strokeBorder(
                Color(HopPalette.white).opacity(isSpreading ? 0 : 0.45),
                lineWidth: 3
            )
            .frame(width: side, height: side)
            .scaleEffect(theme.reduceMotion ? 0.55 : (isSpreading ? 1 : 0.2))
            .position(PondGeometry.point(unitPoint, in: sceneSize))
            .allowsHitTesting(false)
            .animation(.easeOut(duration: PondReaction.ripple.duration), value: isSpreading)
            .onChange(of: activations) { _, _ in
                isSpreading = false
                Task { @MainActor in
                    // One frame at rest, so a second tap restarts the ring
                    // rather than continuing the first one's fade.
                    try? await Task.sleep(for: .milliseconds(16))
                    isSpreading = true
                }
            }
            .accessibilityHidden(true)
    }
}
