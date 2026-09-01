import SwiftUI
import HopPottyCore

// Bridging between the two `HopVoiceLine` types in play.
//
// `HopPottyCore.HopVoiceLine` is the authored content: the recording script,
// its caption and the asset's state. The design system declares its own
// view-shaped `HopVoiceLine` (id, caption, duration) because
// `HopAudioButton(line:)` takes that one. Unqualified `HopVoiceLine` in app
// code resolves to the app-module type, so every reference to the *content*
// type below is written out in full. That is deliberate, not verbosity.

extension HopVoiceLine {
    /// The view-layer line for an authored one.
    init(content line: HopPottyCore.HopVoiceLine) {
        self.init(id: line.id.rawValue, caption: line.caption, duration: nil)
    }
}

/// Delivers a line again when a child asks to hear it.
///
/// No voice bundle ships yet, so `HopVoiceResolver` resolves every line to
/// `.captionOnly(_, because: .assetNotYetRecorded)` — that is the normal path
/// today, not a failure. Replay therefore does two real things: it re-posts the
/// words to VoiceOver, and the caller pulses the caption so a child using their
/// eyes also sees that their tap did something.
@MainActor
enum ChildVoiceReplay {
    static func replay(_ line: HopPottyCore.HopVoiceLine, using resolver: HopVoiceResolver) {
        AccessibilityNotification.Announcement(resolver.playback(for: line).caption).post()
    }
}

/// A line Hop says, together with the caption that always accompanies it.
///
/// Contract §6: every spoken line has a written caption. Two settings decide
/// what a person *perceives* — `hopVoiceEnabled` and `spokenTextCaptionsEnabled`
/// — but neither can remove the words: when captions are switched off the text
/// is still in the accessibility tree, so VoiceOver and Braille still get it.
struct HopSpokenLine: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.childContext) private var context

    private let line: HopPottyCore.HopVoiceLine
    private let style: HopTextStyle
    /// Bumped by a replay button to draw the eye back to the words.
    private let pulse: Int

    @State private var isEmphasised = false

    init(_ line: HopPottyCore.HopVoiceLine, style: HopTextStyle = .childInstruction, pulse: Int = 0) {
        self.line = line
        self.style = style
        self.pulse = pulse
    }

    var body: some View {
        Text(context.voiceResolver.playback(for: line).caption)
            .hopTextStyle(style)
            .foregroundStyle(theme.color.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, theme.spacing.m)
            .padding(.vertical, theme.spacing.s)
            .background {
                RoundedRectangle(cornerRadius: theme.radius.m, style: .continuous)
                    .fill(HopColors.wash(theme.color.brandAction, isDark: theme.isDark))
                    .opacity(isEmphasised ? 1 : 0)
            }
            .hopAnimation(.childTap, value: isEmphasised)
            // Hidden from sight, never from assistive technology: a caregiver
            // turning captions off is asking for a cleaner picture, not for the
            // words to stop existing.
            .opacity(context.showsCaptions ? 1 : 0)
            .frame(height: context.showsCaptions ? nil : 0)
            .clipped()
            .accessibilityHidden(false)
            .task(id: pulse) {
                guard pulse > 0 else { return }
                isEmphasised = true
                // Long enough to notice, short enough that it is a blink rather
                // than a flash. It happens once per tap and never repeats.
                try? await Task.sleep(for: .milliseconds(700))
                isEmphasised = false
            }
    }
}

/// The "say it again" control.
///
/// `HopHitTarget.childMinimum` at the smallest, because a pre-reader who missed
/// the question has to be able to ask for it again without adult help. It never
/// auto-repeats and it never nags.
struct HopReplayButton: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.childContext) private var context

    private let line: HopPottyCore.HopVoiceLine
    private let label: String
    @Binding private var pulse: Int

    init(_ line: HopPottyCore.HopVoiceLine, label: String, pulse: Binding<Int>) {
        self.line = line
        self.label = label
        self._pulse = pulse
    }

    var body: some View {
        HopIconButton(
            systemImage: "speaker.wave.2.fill",
            accessibilityLabel: label,
            tint: theme.color.brandAction,
            minimumTarget: theme.hitTarget.child
        ) {
            ChildVoiceReplay.replay(line, using: context.voiceResolver)
            pulse += 1
        }
        // The words themselves are the hint, so someone who cannot hear the
        // recording still learns what replaying would say.
        .accessibilityHint(line.caption)
    }
}

#Preview("Spoken line and replay") {
    struct Harness: View {
        @State private var pulse = 0
        var body: some View {
            VStack(spacing: 24) {
                HopReplayButton(
                    PottyRoutineContent.tryStep.voice,
                    label: HopCopy.routine.repeatButton.value,
                    pulse: $pulse
                )
                HopSpokenLine(PottyRoutineContent.tryStep.voice, pulse: pulse)
            }
        }
    }
    return Harness()
        .padding()
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Spoken line · captions off") {
    VStack(spacing: 24) {
        HopSpokenLine(PottyRoutineContent.washStep.voice)
        Text(verbatim: "—")
    }
    .padding()
    .childContext(ChildContext(settings: AppSettings(spokenTextCaptionsEnabled: false)))
    .hopBackground()
    .hopThemedRoot()
}
