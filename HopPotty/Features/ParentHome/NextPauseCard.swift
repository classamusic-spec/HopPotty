import SwiftUI
import HopPottyCore

/// The hero card: what happens next, and the two controls a caregiver actually
/// reaches for.
///
/// The card answers one question — *when is my child next interrupted, and can I
/// stop it* — and it answers it in whatever terms are true right now. There are
/// six of those, and each one is a different sentence rather than a countdown
/// with a caveat:
///
/// - a countdown, when a pause is genuinely coming;
/// - "when app use starts again", for an activity-driven schedule that is not
///   counting because the child is not on the selected apps;
/// - a quiet window, naming when it lifts;
/// - a caregiver hold — skipping the next one, or paused until tomorrow;
/// - gentle mode, which never pauses anything and says so plainly;
/// - something that needs the caregiver, routed through the shared error mapping.
///
/// ## Standing on water
///
/// The card itself is unchanged: same content, same controls, same Dynamic Type
/// behaviour, and `HopTimerCard` was already opaque and `.raised`, which is
/// exactly what a countdown needs over a drawing. What did change is everything
/// *below* it. A status pill and a tonal button are both washes of a tint, and a
/// wash over a pond is a wash over whatever the pond happens to be doing there,
/// so the footer gets its own opaque field. It appears only when there is
/// something to say — in the ordinary counting case there is nothing under the
/// card at all.
struct NextPauseCard: View {
    @Environment(\.hopTheme) private var theme

    let snapshot: ParentHomeModel.Snapshot
    let now: Date
    let calendar: Calendar
    let onSkip: () -> Void
    let onStartNow: () -> Void
    let onResume: () -> Void
    let onReviewSettings: () -> Void
    let onRestoreAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            HopTimerCard(
                state: displayState,
                onSkip: onSkip,
                onStartNow: onStartNow
            )

            footer
        }
        // One sentence for the whole card, so VoiceOver says "Next Potty Pause,
        // in 28 minutes" on arrival instead of leaving a caregiver to assemble
        // it from a heading, a dial and a caption. The controls inside stay
        // individually reachable — `.contain` groups, it does not swallow.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: spokenSummary))
    }

    // MARK: Display state

    private var displayState: PottyPauseDisplayState {
        PottyPauseDisplayState(
            pauseState: snapshot.pauseState,
            mode: snapshot.schedule.mode,
            remaining: remaining,
            total: total,
            childName: snapshot.child.nickname
        )
    }

    /// Time left until the next pause, or `nil` when nothing is counting.
    ///
    /// For an activity-driven schedule the projection's start is a *floor* — it
    /// assumes continuous use of the selected apps — so the card labels it as
    /// "when app use starts again" rather than presenting a floor as a promise.
    private var remaining: TimeInterval? {
        guard snapshot.blockReason == nil, let projection = snapshot.projection else { return nil }
        guard projection.start > now else { return 0 }
        return projection.start.timeIntervalSince(now)
    }

    private var total: TimeInterval? {
        guard remaining != nil else { return nil }
        return snapshot.schedule.interval.duration
    }

    // MARK: Footer

    /// Everything that is not the card, on a surface of its own.
    @ViewBuilder
    private var footer: some View {
        if let failure = snapshot.pauseState.failure {
            errorFooter(failure)
        } else if statusPill != nil || showsResume {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                if let pill = statusPill {
                    HopPill(pill.text, tint: pill.tint, glyph: pill.glyph)
                }
                if showsResume {
                    HopSecondaryButton(HopCopy.parentHome.actionResume.localized, action: onResume)
                }
            }
            .padding(theme.spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                    .fill(theme.color.surfaceElevated)
            }
            .modifier(theme.elevation(.resting))
        }
    }

    /// The one status token the card shows, in the order the states rank.
    ///
    /// A value rather than a view so the footer can ask whether there is
    /// anything to draw before it draws a surface to draw it on.
    private var statusPill: (text: String, tint: Color, glyph: HopGlyph)? {
        if snapshot.schedule.mode == .gentle {
            return (HopCopy.timerSettings.modeGentle.localized, theme.color.neutral, .play)
        }
        if let text = blockText {
            return (text, theme.color.warning, .pause)
        }
        if let projection = snapshot.projection, projection.willBeSkipped {
            return (HopCopy.parentHome.heroSkippingNext.localized, theme.color.neutral, .pause)
        }
        if remaining == nil, snapshot.schedule.triggerBasis == .screenActivity {
            return (HopCopy.parentHome.heroWaitingForActivity.localized, theme.color.neutral, .timer)
        }
        return nil
    }

    /// The one sentence explaining why nothing is counting. Derived from
    /// `PauseBlockReason`, which is exhaustive and strictly ordered, so the card
    /// can always say something specific rather than going quiet.
    private var blockText: String? {
        guard let reason = snapshot.blockReason else { return nil }
        switch reason {
        case .scheduleDisabled, .suspendedIndefinitely:
            return HopCopy.parentHome.heroDisabled.localized
        case .suspendedUntilTomorrow:
            return HopCopy.parentHome.heroPausedUntilTomorrow.localized
        case .suspendedUntil(let date):
            return HopCopy.parentHome.heroQuietWindow.localized(.text(ParentFormat.clock(date)))
        case .quietWindow(_, let resumesAt):
            return HopCopy.parentHome.heroQuietWindow.localized(.text(ParentFormat.clock(resumesAt)))
        case .outsideActiveWindow:
            return HopCopy.parentHome.heroOutsideActiveHours.localized
        case .inactiveDay:
            return HopCopy.parentHome.heroOutsideActiveHours.localized
        case .cooldown(let until):
            return HopCopy.parentHome.heroQuietWindow.localized(.text(ParentFormat.clock(until)))
        case .skippingNextPause:
            return HopCopy.parentHome.heroSkippingNext.localized
        }
    }

    /// "Resume Potty Pause" is offered only when a caregiver hold is what is
    /// stopping it — never when the schedule is simply outside its hours, where
    /// there is nothing to resume.
    private var showsResume: Bool {
        guard snapshot.pauseState.failure == nil, let reason = snapshot.blockReason else { return false }
        return isCaregiverHold(reason)
    }

    private func isCaregiverHold(_ reason: PauseBlockReason) -> Bool {
        switch reason {
        case .scheduleDisabled, .suspendedIndefinitely, .suspendedUntil,
             .suspendedUntilTomorrow, .skippingNextPause:
            true
        case .inactiveDay, .outsideActiveWindow, .quietWindow, .cooldown:
            false
        }
    }

    // MARK: Accessibility

    /// The card as one spoken sentence: the heading, then the countdown in words
    /// (never "twenty-eight colon fourteen"), then whatever is holding it.
    private var spokenSummary: String {
        var parts = [HopCopy.parentHome.heroTitle.localized]
        if let remaining {
            parts.append(
                HopCopy.parentHome.heroCountdown.localized(.text(ParentFormat.spelledDuration(remaining)))
            )
        }
        if let pill = statusPill {
            parts.append(pill.text)
        }
        return parts.joined(separator: ", ")
    }

    // MARK: Errors

    private func errorFooter(_ failure: ScreenTimeFailure) -> some View {
        let presentation = failure.parentPresentation
        return VStack(alignment: .leading, spacing: theme.spacing.s) {
            Text(verbatim: presentation.title)
                .font(theme.font(.parentHeadline))
                .foregroundStyle(theme.color.textPrimary)
            Text(verbatim: presentation.message)
                .font(theme.font(.parentCallout))
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: theme.spacing.s) {
                switch presentation.recovery {
                case .retry, .reviewSettings, .openSystemSettings:
                    HopSecondaryButton(HopStrings.reviewSettings, action: onReviewSettings)
                case .dismissOnly:
                    EmptyView()
                }
                // The emergency exit is offered wherever a shield might be
                // standing. It is never gated on anything the child did.
                if snapshot.pauseState.mayHaveShieldUp {
                    HopSecondaryButton(HopCopy.settings.emergencyTitle.localized, action: onRestoreAccess)
                }
            }
        }
        .padding(theme.spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Opaque, because this sits over the pond like everything else the card
        // carries.
        .background(
            RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                .fill(theme.color.surfaceElevated)
        )
        .modifier(theme.elevation(.resting))
    }
}
