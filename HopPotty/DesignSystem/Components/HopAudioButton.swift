import SwiftUI
import HopPottyDesignTokens

/// Plays one of Hop's lines.
///
/// Audio playback is a Services concern, so the design system takes a closure
/// from the environment rather than owning an engine. The default does nothing,
/// which means a preview and a unit-test host are silent instead of broken.
public struct HopVoicePlayback: Sendable {
    /// Deliberately un-isolated: the design system only needs to say "play
    /// this", and the audio service decides which actor that happens on.
    public let play: @Sendable (HopVoiceLine) -> Void

    public init(play: @escaping @Sendable (HopVoiceLine) -> Void) {
        self.play = play
    }

    public static let disabled = HopVoicePlayback { _ in }
}

private struct HopVoicePlaybackKey: EnvironmentKey {
    static let defaultValue = HopVoicePlayback.disabled
}

private struct HopSpokenCaptionsKey: EnvironmentKey {
    // On by default. Captions help pre-readers' caregivers, deaf and
    // hard-of-hearing families, and anyone using HopPotty with the sound off —
    // matching `AppSettings.spokenTextCaptionsEnabled`.
    static let defaultValue = true
}

public extension EnvironmentValues {
    var hopVoicePlayback: HopVoicePlayback {
        get { self[HopVoicePlaybackKey.self] }
        set { self[HopVoicePlaybackKey.self] = newValue }
    }

    /// Whether Hop's spoken lines are also shown in writing.
    var hopShowsSpokenCaptions: Bool {
        get { self[HopSpokenCaptionsKey.self] }
        set { self[HopSpokenCaptionsKey.self] = newValue }
    }
}

/// Replays a spoken prompt, with the written caption beside it.
///
/// The caption is part of the control, not an alternative to it: every spoken
/// line has a written form (`Docs/CONTRACTS.md` §6), and a child who cannot
/// hear the line still gets the instruction.
public struct HopAudioButton: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.hopVoicePlayback) private var playback
    @Environment(\.hopShowsSpokenCaptions) private var showsCaptions

    private let line: HopVoiceLine

    public init(line: HopVoiceLine) {
        self.line = line
    }

    public var body: some View {
        HStack(alignment: .center, spacing: theme.spacing.l) {
            Button {
                playback.play(line)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(theme.color.textOnBrand)
                    .frame(width: theme.hitTarget.child, height: theme.hitTarget.child)
                    .background {
                        Circle().fill(theme.color.brandAction)
                    }
            }
            // The child press feel, not the bare one: this is a 72-point target
            // a three-year-old is aiming at, and it should squash and spring
            // back like the rest of their controls rather than merely dim.
            .buttonStyle(
                HopBareButtonStyle(
                    minimumTarget: theme.hitTarget.child,
                    tint: theme.color.brandAction,
                    feel: .child
                )
            )
            .accessibilityLabel(HopStrings.replayAudio)
            .accessibilityValue(line.caption)

            if showsCaptions {
                Text(line.caption)
                    .hopTextStyle(.childInstruction, allowsTightening: false)
                    .foregroundStyle(theme.color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // A routine step advancing rewrites this line in place.
                    // Cross-fading is what stops it reading as a flicker.
                    .hopValueChange(line.caption)
                    // The button already speaks the caption as its value; reading
                    // it twice is noise.
                    .accessibilityHidden(true)
            }
        }
    }
}

/// Progress through a short, fixed sequence of steps.
///
/// Deliberately not a percentage bar: "step 2 of 4" is a countable promise a
/// four-year-old can hold, and the routine is always short enough to count.
public struct HopStepIndicator: View {
    @Environment(\.hopTheme) private var theme

    private let total: Int
    private let current: Int

    public init(total: Int, current: Int) {
        self.total = max(1, total)
        self.current = current
    }

    public var body: some View {
        HStack(spacing: theme.spacing.m) {
            ForEach(0..<total, id: \.self) { index in
                dot(at: index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HopStrings.stepIndicator(current: min(max(1, current), total), total: total))
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func dot(at index: Int) -> some View {
        let isDone = index < current - 1
        let isCurrent = index == current - 1
        return ZStack {
            Capsule()
                .fill(isDone || isCurrent ? theme.color.brandAction : theme.color.divider)
                .frame(width: isCurrent ? 34 : 14, height: 14)

            // A completed step carries a mark as well as a fill, so progress is
            // not conveyed by colour alone.
            if isDone {
                HopGlyphView(.check, size: 9)
                    .foregroundStyle(theme.color.textOnBrand)
            }
        }
        .hopAnimation(.childTap, value: current)
    }
}

#Preview("Audio button and steps") {
    VStack(alignment: .leading, spacing: 40) {
        HopStepIndicator(total: 4, current: 2)
        HopAudioButton(line: HopVoiceLine(id: "routine.sit", caption: "Sit down and give it a try."))
        HopAudioButton(line: HopVoiceLine(id: "routine.wash", caption: "Now let's wash our hands with lots of bubbles."))
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Audio button · captions off, AX3") {
    VStack(alignment: .leading, spacing: 40) {
        HopStepIndicator(total: 5, current: 5)
        HopAudioButton(line: HopVoiceLine(id: "routine.sit", caption: "Sit down and give it a try."))
    }
    .padding()
    .environment(\.hopShowsSpokenCaptions, false)
    .environment(\.dynamicTypeSize, .accessibility3)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .hopBackground()
    .hopThemedRoot()
}

#Preview("Audio button · dark") {
    VStack(alignment: .leading, spacing: 40) {
        HopStepIndicator(total: 4, current: 3)
        HopAudioButton(line: HopVoiceLine(id: "routine.sit", caption: "Sit down and give it a try."))
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .hopBackground()
    .hopThemedRoot()
    .preferredColorScheme(.dark)
}

#Preview("Audio button · Reduce Motion") {
    VStack(alignment: .leading, spacing: 40) {
        HopStepIndicator(total: 4, current: 2)
        HopAudioButton(line: HopVoiceLine(id: "routine.sit", caption: "Sit down and give it a try."))
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .hopBackground()
    .hopThemedRoot(reduceMotion: true)
}

#Preview("Steps · high contrast") {
    VStack(spacing: 24) {
        HopStepIndicator(total: 4, current: 1)
        HopStepIndicator(total: 4, current: 4)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .hopBackground()
    .hopThemedRoot(appearance: .darkHighContrast)
}
