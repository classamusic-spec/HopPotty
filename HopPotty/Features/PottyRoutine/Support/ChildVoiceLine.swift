import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

// `HopVoiceLine` is one type, and it lives in HopPottyCore: the recording
// script, its caption and the asset's state. The design system has no
// view-shaped twin — `HopAudioButton(line:)` takes the content type directly —
// so the references below could be written bare. They are written out in full
// deliberately: this file is the seam between authored content and what a child
// sees, and being explicit about which module owns the line is worth the extra
// twelve characters.

extension HopPottyCore.HopVoiceLine {
    /// The written form, through the string catalog.
    ///
    /// A line contributes `<id>.spoken` to `HopCopy`, plus `<id>.caption` only
    /// when the written form differs from the spoken one — see
    /// `HopVoiceLine.copyEntries(audience:comment:)`. Asking for the key that
    /// does not exist would silently fall back to the authored English forever,
    /// which is exactly the class of bug that survives a translation pass, so
    /// the key is chosen the same way the catalog builds it.
    var localizedCaption: String {
        let key = hasDistinctCaption ? id.rawValue + ".caption" : id.rawValue + ".spoken"
        return NSLocalizedString(key, tableName: nil, bundle: .main, value: caption, comment: "")
    }
}

extension HopPottyCore.HopVoiceLine {
    /// Roughly how long Hop is delivering this line for.
    ///
    /// Every line is `.planned`, so there is no recording whose length could be
    /// read — the words on screen *are* the delivery. The estimate is therefore
    /// made from the caption at an unhurried pace, and it is bounded at both
    /// ends: a two-word line still gets a beat of mouth movement, and a long one
    /// cannot leave Hop talking at a child who has already moved on.
    ///
    /// It drives ``HopAct/speaking(for:pose:)`` and nothing else. When a voice
    /// bundle ships, this is the one place that has to start asking the asset.
    var spokenDuration: TimeInterval {
        let words = localizedCaption.split(whereSeparator: { $0.isWhitespace }).count
        return min(6, max(1.2, Double(words) * 0.38))
    }
}

/// Delivers a line again when a child asks to hear it.
///
/// Every `HopVoiceLine` in HopPotty is `.planned`, so `HopVoiceResolver`
/// resolves all of them to `.captionOnly(_, because: .assetNotYetRecorded)`.
/// That is the shipping state, not a failure, and it is why replay is defined
/// in terms of the *words* rather than of an audio player: re-posting the line
/// reaches VoiceOver, and the caller pulses the on-screen caption so a child
/// using their eyes also sees that their tap did something. An audio player
/// added later becomes an additional delivery beside these two, not a
/// replacement for them.
@MainActor
enum ChildVoiceReplay {
    static func replay(_ line: HopPottyCore.HopVoiceLine) {
        AccessibilityNotification.Announcement(line.localizedCaption).post()
    }
}

/// A line Hop says, together with the caption that always accompanies it.
///
/// Contract §6: every spoken line has a written caption. Two rules govern what
/// is actually drawn, and between them a person is never left with nothing:
///
/// 1. **When the line is not audible, the words are always shown.** No voice
///    bundle ships yet, so `HopVoiceResolver` resolves every line to
///    `.captionOnly` — the text is not a caption *accompanying* audio then, it
///    is the only delivery, and hiding it would leave a silent, wordless screen.
///    `spokenTextCaptionsEnabled` is a preference about captions beside speech,
///    not permission for the content to exist.
/// 2. **When the line is audible and captions are off, the words are still in
///    the accessibility tree** — hidden from sight, never from VoiceOver or
///    Braille.
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

    private var playback: HopVoicePlayback { context.voiceResolver.playback(for: line) }

    /// Drawn whenever there is no audio to accompany, or whenever the caregiver
    /// has asked for captions.
    private var isVisible: Bool { !playback.isAudible || context.showsCaptions }

    var body: some View {
        Text(verbatim: line.localizedCaption)
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
            .opacity(isVisible ? 1 : 0)
            .frame(height: isVisible ? nil : 0)
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
            ChildVoiceReplay.replay(line)
            pulse += 1
        }
        // The words themselves are the hint, so someone who cannot hear the
        // recording still learns what replaying would say.
        .accessibilityHint(Text(verbatim: line.localizedCaption))
    }
}

/// The replay button owns the pulse and the spoken line reads it, so seeing
/// them work needs something holding `@State` between them.
///
/// At file scope rather than inside the `#Preview`: that body is a
/// `@ViewBuilder`, which takes views, not declarations — a nested `struct` in
/// there does not compile, and neither does the `return` that used to make it
/// a plain closure instead.
private struct SpokenLineReplayPreview: View {
    @State private var pulse = 0

    var body: some View {
        VStack(spacing: 24) {
            HopReplayButton(
                PottyRoutineContent.tryStep.voice,
                label: HopCopy.routine.repeatButton.localized,
                pulse: $pulse
            )
            HopSpokenLine(PottyRoutineContent.tryStep.voice, pulse: pulse)
        }
    }
}

#Preview("Spoken line and replay") {
    SpokenLineReplayPreview()
        .padding()
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Spoken line · captions off") {
    HopSpokenLine(PottyRoutineContent.washStep.voice)
        .padding()
        .childContext(ChildContext(settings: AppSettings(spokenTextCaptionsEnabled: false)))
        .hopBackground()
        .hopThemedRoot()
}
