import Foundation
import ActivityKit

// MARK: - Target membership
//
// SHARED BY TWO TARGETS.
//
//   HopPotty         (app)              — starts, updates and ends the activity
//   HopPottyWidgets  (widget extension) — draws it
//
// ActivityKit matches a running activity to its UI by the attributes type, so
// the two processes must compile the *same* declaration. This file is the
// declaration; `PottyPauseActivity.swift` next to it is the UI and belongs to the
// widget target alone, because an app that linked the Dynamic Island view would
// be an app carrying a widget's view hierarchy for no reason.
//
// Changing any stored property here is a wire-format change across a process
// boundary. Anything already running when the app updates keeps the old shape.
// Add, never rename or retype; and if the shape ever has to change, end the old
// activities first.

/// What a Potty Pause Live Activity is about.
///
/// ## What is on this boundary, and what is not
///
/// A Live Activity is drawn on the lock screen and in the Dynamic Island: the
/// most public surface HopPotty has. It is visible without unlocking the phone,
/// to whoever is holding it or standing next to it.
///
/// So it carries five things, and none of them is about a child:
///
///   * an opaque per-pause session id — the same random UUID the App Group
///     record uses, which is not derived from and not resolvable to a child
///     (`Docs/PrivacyArchitecture.md` §5);
///   * whether this is a guided routine or a plain pause;
///   * when it started and when it is expected to end;
///   * which step of the routine is on screen, as an index;
///   * which face Hop is wearing.
///
/// **Deliberately absent:** the child's name, identifier or avatar; the step's
/// title or instruction; anything about outcomes; the names, icons or number of
/// the apps being held. A stranger reading a HopPotty Live Activity over
/// somebody's shoulder learns that a timer is running. That is the whole of it.
struct PottyPauseAttributes: ActivityAttributes {

    /// Everything that changes while the pause runs.
    struct ContentState: Codable, Hashable {

        /// When the pause began. Absolute, so a timezone change cannot move it.
        var startedAt: Date

        /// When it is expected to end.
        ///
        /// An expectation, not a promise. `Docs/ScreenTimeArchitecture.md` §9
        /// lists four independent paths that can end a pause, three of them
        /// earlier than this. The lock screen counts down to it because a
        /// caregiver needs *a* number; the shield comes down when it comes down.
        var expectedEndAt: Date

        /// Which step of the guided routine is on screen, zero-based.
        ///
        /// `nil` for a plain pause, which has no steps. An index rather than a
        /// title: `PottyRoutineContent` owns the words, the widget process has
        /// them compiled in, and an index cannot accidentally carry something a
        /// caregiver typed.
        var stepIndex: Int?

        /// How many steps there are, so the lock screen can draw "3 of 5"
        /// without the widget having to agree with the app about the routine's
        /// length by coincidence.
        var stepCount: Int?

        /// `HopWidgetMood.rawValue`. A string for the same reason
        /// `WidgetSnapshot.hopPoseName` is one: an activity started by an older
        /// build must still render.
        var hopPoseName: String

        init(
            startedAt: Date,
            expectedEndAt: Date,
            stepIndex: Int? = nil,
            stepCount: Int? = nil,
            hopPoseName: String
        ) {
            self.startedAt = startedAt
            self.expectedEndAt = expectedEndAt
            self.stepIndex = stepIndex
            self.stepCount = stepCount
            self.hopPoseName = hopPoseName
        }

        /// Progress through the pause, `0...1`, for a ring or a bar.
        ///
        /// Clamped at both ends: an activity that outlives its expected end
        /// shows a full ring rather than one that keeps growing, and a clock
        /// that jumped backwards shows an empty one rather than a negative.
        func fraction(at instant: Date) -> Double {
            let total = expectedEndAt.timeIntervalSince(startedAt)
            guard total > 0 else { return 1 }
            return min(1, max(0, instant.timeIntervalSince(startedAt) / total))
        }

        /// "3 of 5", as two numbers, or `nil` when there is no routine running.
        var stepPosition: (index: Int, count: Int)? {
            guard let stepIndex, let stepCount, stepCount > 0 else { return nil }
            return (min(stepIndex, stepCount - 1), stepCount)
        }
    }

    /// The opaque per-pause session identifier, matching `SharedPauseRecord`.
    ///
    /// Carried so a caregiver's diagnostics can line a Live Activity up with the
    /// pause record it belongs to. It identifies a *pause*, never a child.
    var sessionID: String

    /// Whether the child is being walked through the five-step routine, or the
    /// pause is simply holding the apps.
    var isGuidedRoutine: Bool

    init(sessionID: String, isGuidedRoutine: Bool) {
        self.sessionID = sessionID
        self.isGuidedRoutine = isGuidedRoutine
    }
}
