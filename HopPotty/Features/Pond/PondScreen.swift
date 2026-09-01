import SwiftUI
import HopPottyCore

/// Hop's Pond: the place the stars go.
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
    var arrivingItem: PondItemID?
    let onLeave: () -> Void

    @State private var selectedItem: PondItemID?

    private var stars: Int { context.totalStars }
    private var unlocked: Set<PondItemID> { Set(context.pond.unlocked.keys) }
    private var progress: PondUnlockProgress { PondCatalog.progressTowardNext(stars: stars) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.xxl) {
                header
                sceneAndProgress
                PondCollectionStrip(unlocked: unlocked, stars: stars) { selectedItem = $0 }
            }
            .frame(maxWidth: ChildStage.contentWidth)
            .frame(maxWidth: .infinity)
            .hopPageMargins()
            .padding(.vertical, theme.spacing.xl)
        }
        .scrollIndicators(.hidden)
        .hopBackground(.secondary)
        .task(id: arrivingItem) { await greetArrival() }
        .overlay(alignment: .bottom) { selectionCallout }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.m) {
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(HopCopy.pond.title.resolved(forNickname: context.nickname))
                    .hopTextStyle(.childTitle)
                    .foregroundStyle(theme.color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(HopCopy.pond.starCount.resolved(for: stars))
                    .hopTextStyle(.parentBody)
                    .foregroundStyle(theme.color.textSecondary)
            }

            Spacer(minLength: theme.spacing.s)

            HopStarBadge(count: stars, animatesArrival: arrivingItem != nil)
                .accessibilityHidden(true)

            HopIconButton(
                systemImage: "xmark",
                accessibilityLabel: HopCopy.celebration.resumeButton.value,
                action: onLeave
            )
        }
    }

    // MARK: - Scene

    @ViewBuilder
    private var sceneAndProgress: some View {
        if horizontalSizeClass == .regular {
            // iPad: the pond gets the width and the progress reads beside it,
            // rather than the phone layout being scaled up until Hop is a metre
            // tall.
            HStack(alignment: .top, spacing: theme.spacing.xxl) {
                scene.frame(maxWidth: .infinity)
                progressColumn.frame(width: 260)
            }
        } else {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                scene
                progressColumn
            }
        }
    }

    private var scene: some View {
        PondSceneView(
            unlocked: unlocked,
            nextUp: progress.next,
            onTapItem: { selectedItem = $0 }
        )
        .modifier(theme.elevation(.resting))
    }

    @ViewBuilder
    private var progressColumn: some View {
        if unlocked.isEmpty {
            emptyState
        } else if let next = progress.next {
            PondNextUpCard(progress: progress, next: next)
        } else {
            // The pond is finished. Still a warm sentence, still no ranking, and
            // nothing to keep grinding for.
            Text(HopCopy.pond.emptyBody.value)
                .hopTextStyle(.childInstruction)
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            Text(HopCopy.pond.emptyTitle.value)
                .hopTextStyle(.childTitle)
                .foregroundStyle(theme.color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(HopCopy.pond.emptyBody.value)
                .hopTextStyle(.childInstruction)
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Tapping a friend

    /// The one thing tapping a decoration does: it says its name.
    @ViewBuilder
    private var selectionCallout: some View {
        if let selectedItem {
            Text(PondItemNaming.name(for: selectedItem).value)
                .hopTextStyle(.childInstruction)
                .foregroundStyle(theme.color.textOnBrand)
                .padding(.horizontal, theme.spacing.xl)
                .padding(.vertical, theme.spacing.m)
                .background(Capsule().fill(theme.color.brandAction))
                .padding(.bottom, theme.spacing.xxl)
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
            HopCopy.celebration.pondUnlock.value
        ).post()
        selectedItem = arrivingItem
    }
}

/// What is coming next, and how close it is.
///
/// Written entirely forwards. `PondUnlockProgress.fraction` fills from the last
/// thing unlocked rather than from zero, so the bar shows real movement instead
/// of looking almost full for a hundred stars.
private struct PondNextUpCard: View {
    @Environment(\.hopTheme) private var theme

    let progress: PondUnlockProgress
    let next: PondItem

    private var sentence: String {
        HopCopy.pond.nextUnlock.resolved(
            for: progress.starsRemaining,
            additional: [2: .text(PondItemNaming.name(for: next.id).value)]
        )
    }

    var body: some View {
        HStack(spacing: theme.spacing.l) {
            HopArtwork(.pondItem(next.id))
                .frame(width: 64, height: 64)
                .opacity(0.45)

            VStack(alignment: .leading, spacing: theme.spacing.s) {
                Text(sentence)
                    .hopTextStyle(.childInstruction)
                    .foregroundStyle(theme.color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HopProgressRing(progress: progress.fraction, lineWidth: 8, tint: theme.color.brandAction)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
        }
        .padding(theme.spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: theme.radius.xl, style: .continuous)
                .fill(theme.color.surface)
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
