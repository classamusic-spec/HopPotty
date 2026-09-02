import SwiftUI
import WidgetKit
import ActivityKit
import HopPottyCore
import HopPottyDesignTokens

// MARK: - The Live Activity
//
// The lock screen and Dynamic Island presentation of a pause that is happening
// right now. The attributes it renders are declared in
// `PottyPauseActivityAttributes.swift`, which is a member of the app target too;
// everything in this file belongs to the widget extension alone.
//
// ## Who this is for
//
// The caregiver, on their own phone, not the child. The child is looking at the
// shield — `Extensions/HopPottyShieldConfiguration` draws that, with its own
// copy, on the child's device. A Live Activity is what a parent glances at from
// across the room to know the pause is real, is bounded, and is nearly over.
//
// It follows from that that the copy here is `HopCopy`'s *parent* register where
// there is a choice, and that nothing on it is a control. A Live Activity with a
// "skip" button would be a parental control on an unlocked-adjacent surface, and
// `Docs/CONTRACTS.md` puts every action with consequences behind the parent gate.

struct PottyPauseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PottyPauseAttributes.self) { context in
            PottyPauseLockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            // The lock-screen presentation is also what the system shows on a
            // device with no Dynamic Island, so it is the one that has to be
            // complete.
            .activityBackgroundTint(Color(HopPalette.hopGreenSoft))
            .activitySystemActionForegroundColor(Color(HopPalette.hopGreenInk))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HopWidgetFace(mood: context.state.mood, size: 40)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.range, countsDown: true)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 84)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(verbatim: context.headline)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(
                            timerInterval: context.state.range,
                            countsDown: false,
                            label: { EmptyView() },
                            currentValueLabel: { EmptyView() }
                        )
                        .progressViewStyle(.linear)
                        .tint(Color(HopPalette.hopGreen))

                        Text(verbatim: context.footnote)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                HopWidgetFace(mood: context.state.mood, size: 18, isMonochrome: true)
            } compactTrailing: {
                Text(timerInterval: context.state.range, countsDown: true)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    // Without a width the compact trailing slot resizes on every
                    // tick as the digits change, which reads as a twitch.
                    .frame(width: 44)
            } minimal: {
                HopWidgetFace(mood: context.state.mood, size: 16, isMonochrome: true)
            }
            .keylineTint(Color(HopPalette.hopGreen))
        }
    }
}

// MARK: - Lock screen

struct PottyPauseLockScreenView: View {
    let attributes: PottyPauseAttributes
    let state: PottyPauseAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            HopWidgetFace(mood: state.mood, size: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: headline)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Text(verbatim: HopCopy.shield.returning.value)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let footnote {
                    Text(verbatim: footnote)
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Text(timerInterval: state.range, countsDown: true)
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(width: 92)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: headline))
    }

    private var headline: String {
        PottyPauseActivityCopy.headline(for: attributes)
    }

    private var footnote: String? {
        PottyPauseActivityCopy.footnote(for: state)
    }
}

// MARK: - Copy

/// The words on the Live Activity, in one place so the lock screen and the
/// Dynamic Island cannot disagree.
///
/// Every string is a `HopCopy` entry. The routine step position is the one
/// number formatted here, and it is formatted from two integers rather than from
/// anything a caregiver typed.
enum PottyPauseActivityCopy {

    static func headline(for attributes: PottyPauseAttributes) -> String {
        // The child's own screen says "Potty time!"; the caregiver's says the
        // same thing, because a parent glancing at a phone should recognise the
        // words their child is looking at.
        HopCopy.shield.title.value
    }

    /// "Step 3 of 5" — or nothing, when this is a plain pause with no routine.
    ///
    /// Built from `HopCopy.routine`'s existing step-position entry where the
    /// catalogue has one, and otherwise from the two numbers alone. The step's
    /// *title* is deliberately not shown: "Wipe" on a lock screen is a fact
    /// about a three-year-old's morning, published to the room.
    static func footnote(for state: PottyPauseAttributes.ContentState) -> String? {
        guard let position = state.stepPosition else { return nil }
        return "\(position.index + 1) / \(position.count)"
    }
}

// MARK: - Convenience

extension PottyPauseAttributes.ContentState {
    /// The mood to draw, with the same fallback as the widget snapshot.
    var mood: HopWidgetMood {
        HopWidgetMood(rawValue: hopPoseName) ?? .cheer
    }

    /// The span the system tickers over.
    ///
    /// `Text(timerInterval:countsDown:)` and `ProgressView(timerInterval:)` are
    /// both rendered by the system from this range, so a Live Activity counts
    /// down and fills its bar with no update pushed from the app. That matters
    /// more here than on the widget: ActivityKit budgets updates too, and a pause
    /// is over in three minutes — spending an update per second on a countdown
    /// the system draws for free would be spending the whole budget on the one
    /// thing that did not need it.
    ///
    /// Guaranteed non-empty, because `ClosedRange` traps when the upper bound is
    /// below the lower one and a clock that jumped backwards must not crash a
    /// lock screen.
    var range: ClosedRange<Date> {
        startedAt...max(startedAt.addingTimeInterval(1), expectedEndAt)
    }
}

extension ActivityViewContext where Attributes == PottyPauseAttributes {
    var headline: String { PottyPauseActivityCopy.headline(for: attributes) }
    var footnote: String { PottyPauseActivityCopy.footnote(for: state) ?? HopCopy.shield.returning.value }
}
