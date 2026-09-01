import SwiftUI
import HopPottyCore

// Screens 1–3: what HopPotty is, how the loop works, and the one optional
// question about the child.

/// 1. Meet Hop.
struct MeetHopScreen: View {
    @Environment(\.hopTheme) private var theme
    let model: OnboardingModel

    var body: some View {
        OnboardingScaffold(
            title: HopCopy.onboarding.welcomeTitle.localized,
            message: HopCopy.onboarding.welcomeBody.localized,
            primaryTitle: HopCopy.onboarding.welcomeContinue.localized,
            onPrimary: model.advance
        ) {
            VStack(spacing: theme.spacing.l) {
                HopCharacterStage(pose: .wave, size: 200)
                Text(hop: HopCopy.onboarding.welcomeTagline)
                    .font(theme.font(.parentTitle))
                    .foregroundStyle(theme.color.brandPrimary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// 2. The idea: PLAY → PAUSE → POTTY → PLAY.
///
/// The loop is drawn as four beats that return to where they started, because
/// the promise a caregiver needs to believe is the last arrow: the game comes
/// back. Not a funnel, not a checklist — a circle.
struct TheIdeaScreen: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let model: OnboardingModel

    private struct Beat: Identifiable {
        let id = UUID()
        let glyph: HopGlyph
        let title: String
        let detail: String
    }

    private var beats: [Beat] {
        [
            Beat(glyph: .play, title: HopStrings.glyphPlay, detail: HopCopy.onboarding.welcomeBody.localized),
            Beat(glyph: .pause, title: HopStrings.glyphPause, detail: HopCopy.onboarding.modePauseBody.localized),
            Beat(glyph: .tried, title: HopCopy.parentHome.eventTried.localized, detail: HopCopy.onboarding.modeRoutineBody.localized),
            Beat(glyph: .play, title: HopStrings.glyphPlay, detail: HopCopy.timerSettings.durationFooter.localized),
        ]
    }

    var body: some View {
        OnboardingScaffold(
            title: HopCopy.brand.tagline.localized,
            message: HopCopy.onboarding.privacyBody.localized,
            primaryTitle: HopCopy.common.next.localized,
            canGoBack: model.canGoBack,
            onPrimary: model.advance,
            onBack: model.goBack
        ) {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                ForEach(beats) { beat in
                    HStack(alignment: .top, spacing: theme.spacing.m) {
                        HopGlyphView(beat.glyph, size: 28, isDecorative: true)
                            .foregroundStyle(theme.color.brandPrimary)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                            Text(verbatim: beat.title)
                                .font(theme.font(.parentHeadline))
                                .foregroundStyle(theme.color.textPrimary)
                            Text(verbatim: beat.detail)
                                .font(theme.font(.parentCallout))
                                .foregroundStyle(theme.color.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// 3. Nickname. Optional, and the only thing HopPotty ever asks about a child.
struct NicknameScreen: View {
    @Environment(\.hopTheme) private var theme
    let model: OnboardingModel

    @State private var nickname = ""
    @FocusState private var focused: Bool

    var body: some View {
        OnboardingScaffold(
            title: HopCopy.onboarding.nameTitle.localized,
            message: HopCopy.onboarding.nameFooter.localized,
            primaryTitle: HopCopy.common.next.localized,
            skipTitle: HopCopy.onboarding.nameSkip.localized,
            canGoBack: model.canGoBack,
            onPrimary: {
                model.setNickname(nickname)
                model.advance()
            },
            onSkip: {
                // Skipping is a real answer, not a deferral: the nameless copy
                // variants exist so the app reads correctly forever without one.
                model.setNickname(nil)
                model.advance()
            },
            onBack: model.goBack
        ) {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                TextField(HopCopy.onboarding.namePlaceholder.localized, text: $nickname)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textContentType(.givenName)
                    .font(theme.font(.parentTitle))
                    .focused($focused)
                    .padding(theme.spacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: theme.radius.m, style: .continuous)
                            .fill(theme.color.surfaceSunken)
                    )
                    .onChange(of: nickname) { _, newValue in
                        // Capped at the model's own limit so every entry point
                        // gives the same guarantee — see `ChildProfile.sanitize`.
                        if newValue.count > ChildProfile.maxNicknameLength {
                            nickname = String(newValue.prefix(ChildProfile.maxNicknameLength))
                        }
                    }

                Text(hop: HopCopy.settings.childNicknameFooter)
                    .font(theme.font(.parentFootnote))
                    .foregroundStyle(theme.color.textSecondary)
            }
            .onAppear {
                nickname = model.draft.nickname ?? ""
                focused = true
            }
        }
    }
}

#if DEBUG
#Preview("Meet Hop") {
    MeetHopScreen(model: .preview(step: .meetHop))
        .hopThemedRoot()
}

#Preview("The idea, iPad") {
    TheIdeaScreen(model: .preview(step: .theIdea))
        .hopThemedRoot()
}

#Preview("Nickname, AX3") {
    NicknameScreen(model: .preview(step: .nickname))
        .environment(\.dynamicTypeSize, .accessibility3)
        .hopThemedRoot()
}

#Preview("Nickname, dark") {
    NicknameScreen(model: .preview(step: .nickname))
        .preferredColorScheme(.dark)
        .hopThemedRoot()
}
#endif
