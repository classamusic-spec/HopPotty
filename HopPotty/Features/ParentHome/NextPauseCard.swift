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

            statusLine

            if let failure = snapshot.pauseState.failure {
                errorFooter(failure)
            } else if let resumeControl {
                resumeControl
            }
        }
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

    // MARK: Status

    @ViewBuilder
    private var statusLine: some View {
        if snapshot.schedule.mode == .gentle {
            HopPill(HopCopy.timerSettings.modeGentle.localized, tint: theme.color.neutral, glyph: .play)
        } else if let text = blockText {
            HopPill(text, tint: theme.color.warning, glyph: .pause)
        } else if let projection = snapshot.projection, projection.willBeSkipped {
            HopPill(HopCopy.parentHome.heroSkippingNext.localized, tint: theme.color.neutral, glyph: .pause)
        } else if remaining == nil, snapshot.schedule.triggerBasis == .screenActivity {
            HopPill(HopCopy.parentHome.heroWaitingForActivity.localized, tint: theme.color.neutral, glyph: .timer)
        }
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

    /// "Resume Potty Pause", shown only when a caregiver hold is what is
    /// stopping it — never when the schedule is simply outside its hours, where
    /// there is nothing to resume.
    @ViewBuilder
    private var resumeControl: some View {
        if let reason = snapshot.blockReason, isCaregiverHold(reason) {
            HopSecondaryButton(HopCopy.parentHome.actionResume.localized, action: onResume)
        }
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
        .background(
            RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                .fill(theme.color.surfaceSunken)
        )
    }
}
