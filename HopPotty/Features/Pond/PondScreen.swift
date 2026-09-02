import SwiftUI
import HopPottyCore

/// Hop's Pond: the place the stars go.
///
/// ## A place, not a page about a place
///
/// The pond is the screen. It fills it edge to edge, behind the status bar and
/// under the home indicator, and everything else — the child's name for it, the
/// star count, what is coming next, the collection — floats over the water as
/// small pieces of chrome. An earlier version framed the scene as a 4:3 card
/// halfway down a scrolling page, with the decorations reduced to a row of tiles
/// underneath; that is a *reward menu with a picture at the top*, and it is
/// precisely the thing this screen must not be. What a child has earned is in
/// the world, at the size the world draws it, and the list below is a way of
/// finding things — most of all with VoiceOver — rather than the point.
///
/// ## Nothing here can take anything away
///
/// Three things are always answerable at a glance — what I have, what is next,
/// and how far away it is — and none of them is ever phrased as a loss. There is
/// no expiry, no decay, no streak and no "come back or you'll lose it", because
/// `PondCatalog` and `PondProgressService` expose no operation that could take
/// something away and `RewardService`'s ledger only ever grows.
struct PondScreen: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.childContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// An item that has just arrived, handed over from a celebration. It gets a
    /// single arrival beat and then simply belongs to the pond like everything
    /// else.
    var arrivingItem: PondItemID? = nil
    let onLeave: () -> Void

    @State private var selectedItem: PondItemID?

    private var stars: Int { context.totalStars }
    private var unlocked: Set<PondItemID> { Set(context.pond.unlocked.keys) }
    private var progress: PondUnlockProgress { PondCatalog.progressTowardNext(stars: stars) }

    var body: some View {
        ZStack(alignment: .top) {
            scene
            chrome
        }
        .hopBackground(.secondary)
        .task(id: arrivingItem) { await greetArrival() }
        .overlay(alignment: .bottom) { selectionCallout }
    }

    // MARK: - The pond itself

    /// Full bleed, and the only thing on the screen that is not chrome.
    private var scene: some View {
        PondSceneView(
            unlocked: unlocked,
            nextUp: progress.next,
            isFullBleed: true,
            onTapItem: { selectedItem = $0 }
        )
        .ignoresSafeArea()
    }

    // MARK: - What floats over it

    private var chrome: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: theme.spacing.l)
            tray
        }
    }

    /// The child's name for the pond, their star count, and the way out.
    ///
    /// Every piece sits on its own opaque capsule. A translucent pill over open
    /// water is legible on the water and illegible the moment a lily pad drifts
    /// under it, and the star count is the one number on this screen a child
    /// looks for.
    private var header: some View {
        HStack(alignment: .center, spacing: theme.spacing.m) {
            HopIconButton(
                systemImage: "chevron.left",
                accessibilityLabel: HopCopy.celebration.resumeButton.localized,
                tint: theme.color.brandAction,
                minimumTarget: theme.hitTarget.child,
                action: onLeave
            )
            .background { Circle().fill(theme.color.surface.opacity(0.94)) }

            Spacer(minLength: theme.spacing.xs)

            Text(HopCopy.pond.title.localized(forNickname: context.nickname))
                .hopTextStyle(.childTitle)
                .foregroundStyle(theme.color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, theme.spacing.l)
                .padding(.vertical, theme.spacing.xs)
                .background { Capsule().fill(theme.color.surface.opacity(0.94)) }
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: theme.spacing.xs)

            HopStarBadge(count: stars, animatesArrival: arrivingItem != nil)
                .background { Capsule().fill(theme.color.surface.opacity(0.94)) }
                .accessibilityLabel(HopCopy.pond.starCount.localized(for: stars))
        }
        .hopPageMargins()
        .padding(.top, theme.spacing.s)
    }

    /// The tray: what is coming next, then the collection.
    ///
    /// Anchored to the bottom and deliberately shallow — it is the *edge* of the
    /// screen, not the content of it. Its own scroll view means an accessibility
    /// type size grows the tray rather than pushing the pond off the top.
    private var tray: some View {
        VStack(alignment: .leading, spacing: theme.spacing.l) {
            progressLine
            PondCollectionStrip(unlocked: unlocked, stars: stars) { selectedItem = $0 }
        }
        .padding(.horizontal, theme.spacing.xl)
        .padding(.top, theme.spacing.l)
        .padding(.bottom, theme.spacing.m)
        .frame(maxWidth: ChildStage.contentWidth)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: theme.radius.hero,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: theme.radius.hero,
                style: .continuous
            )
            .fill(theme.color.surface.opacity(0.96))
            .ignoresSafeArea(edges: .bottom)
        }
    }

    /// One sentence about what is on its way, or one about a pond that is
    /// finished. Never a bar with a number on it.
    @ViewBuilder
    private var progressLine: some View {
        if let next = progress.next {
            PondNextUpRow(progress: progress, next: next)
        } else {
            Text(HopCopy.pond.emptyBody.localized)
                .hopTextStyle(.childInstruction)
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Tapping a friend

    /// The one thing tapping a decoration does: it says its name.
    ///
    /// The decoration itself has already answered in the scene — the flower
    /// opened, the fish darted — and this is the word for what just moved.
    @ViewBuilder
    private var selectionCallout: some View {
        if let selectedItem {
            Text(PondItemNaming.name(for: selectedItem).localized)
                .hopTextStyle(.childInstruction)
                .foregroundStyle(theme.color.textOnBrand)
                .padding(.horizontal, theme.spacing.xl)
                .padding(.vertical, theme.spacing.m)
                .background(Capsule().fill(theme.color.brandAction))
                .padding(.bottom, theme.spacing.huge)
                .hopTransition(.childArrive)
                .task(id: selectedItem) {
                    try? await Task.sleep(for: .seconds(2))
                    self.selectedItem = nil
                }
        }
    }

    // MARK: - Arrival

    /// Announces a newly-arrived decoration once, then lets it settle in.
    private func greetArrival() async {
        guard let arrivingItem else { return }
        AccessibilityNotification.Announcement(
            HopCopy.celebration.pondUnlock.localized
        ).post()
        selectedItem = arrivingItem
    }
}

/// What is coming next, and how close it is.
///
/// One row, written entirely forwards. `PondUnlockProgress.fraction` fills from
/// the last thing unlocked rather than from zero, so the ring shows real
/// movement instead of looking almost full for a hundred stars.
private struct PondNextUpRow: View {
    @Environment(\.hopTheme) private var theme

    let progress: PondUnlockProgress
    let next: PondItem

    private var sentence: String {
        HopCopy.pond.nextUnlock.localized(
            for: progress.starsRemaining,
            additional: [2: .text(PondItemNaming.name(for: next.id).localized)]
        )
    }

    var body: some View {
        HStack(spacing: theme.spacing.l) {
            // A sketch of the thing on its way, at the size it will be in the
            // pond. Not a locked slot: nothing here was ever theirs and taken.
            HopArtwork(.pondItem(next.id))
                .frame(width: 52, height: 52)
                .opacity(0.42)

            Text(sentence)
                .hopTextStyle(.childInstruction)
                .foregroundStyle(theme.color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HopProgressRing(progress: progress.fraction, lineWidth: 7, tint: theme.color.brandAction)
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sentence)
    }
}

#Preview("Pond · empty") {
    PondScreen(onLeave: {})
        .childContext(ChildContext(child: ChildProfile(nickname: "Maya")))
        .hopThemedRoot()
}

#Preview("Pond · mid progress") {
    PondScreen(onLeave: {})
        .childContext(pondContext(stars: 62, nickname: "Maya"))
        .hopThemedRoot()
}

#Preview("Pond · item just arrived") {
    PondScreen(arrivingItem: .rainbow, onLeave: {})
        .childContext(pondContext(stars: 176))
        .hopThemedRoot()
}

#Preview("Pond · Reduce Motion") {
    PondScreen(onLeave: {})
        .childContext(pondContext(stars: 62))
        .hopThemedRoot(reduceMotion: true)
}

#Preview("Pond · AX3") {
    PondScreen(onLeave: {})
        .environment(\.dynamicTypeSize, .accessibility3)
        .childContext(pondContext(stars: 62))
        .hopThemedRoot()
}

#Preview("Pond · iPad") {
    PondScreen(onLeave: {})
        .frame(width: 1024, height: 768)
        .childContext(pondContext(stars: 243, nickname: "Sam"))
        .hopThemedRoot()
}

/// Builds a preview context whose pond matches its star total, the same way
/// `PondProgressService` builds a real one.
private func pondContext(stars: Int, nickname: String? = nil) -> ChildContext {
    let child = ChildProfile(nickname: nickname)
    return ChildContext(
        child: child,
        totalStars: stars,
        pond: PondProgressService().progress(forStars: stars, childID: child.id)
    )
}
