import React from 'react';
import { Pressable, StyleSheet, TextInput, View } from 'react-native';

import { HopText } from '../../design-system/components';
import { textStyle, useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';
import {
  OnboardingEyebrow,
  OnboardingScaffold,
  restingShadow,
  stepPosition,
  type OnboardingStepPosition,
} from './OnboardingScaffold';

/**
 * 03 of the flow, and the top half of `Art/render/screens/32-onboarding-child-profile.png`
 * (`childProfile()` in `Scripts/screens/parent-extra.js`).
 *
 * A nickname, and a colour for the frog. That is everything HopPotty ever asks
 * about a child — there is nowhere in `ChildProfile` to put a birthday, a last
 * name or a photograph, and the footnote says so rather than leaving a
 * caregiver to assume otherwise.
 */

/** `ChildProfile.maxNicknameLength`. The same cap at every entry point. */
export const MAX_NICKNAME_LENGTH = 24;

/** The five frog colours of `HopAvatarStyle`. */
export type HopAvatarStyleId =
  | 'frogGreen'
  | 'frogBlue'
  | 'frogSunshine'
  | 'frogPeach'
  | 'frogLavender';

export const HOP_AVATAR_STYLES: readonly HopAvatarStyleId[] = [
  'frogGreen',
  'frogBlue',
  'frogSunshine',
  'frogPeach',
  'frogLavender',
];

const AVATAR_LABELS: Readonly<Record<HopAvatarStyleId, string>> = {
  frogGreen: 'Green frog',
  frogBlue: 'Blue frog',
  frogSunshine: 'Sunshine frog',
  frogPeach: 'Peach frog',
  frogLavender: 'Lavender frog',
};

export interface NicknameScreenProps {
  /** What is in the field. Empty is a valid, finished answer. */
  nickname: string;
  onChangeNickname?: (nickname: string) => void;
  avatar: HopAvatarStyleId;
  onChangeAvatar?: (avatar: HopAvatarStyleId) => void;
  onContinue?: () => void;
  /** Skipping is a real answer: the nameless copy exists so the app still reads. */
  onSkip?: () => void;
  onBack?: () => void;
  step?: OnboardingStepPosition;
}

export function NicknameScreen({
  nickname,
  onChangeNickname,
  avatar,
  onChangeAvatar,
  onContinue,
  onSkip,
  onBack,
  step = stepPosition('nickname'),
}: NicknameScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const trimmed = nickname.trim();

  return (
    <OnboardingScaffold
      eyebrow="Your child"
      title="What can Hop call your child?"
      step={step}
      primaryLabel="Continue"
      onPrimary={onContinue}
      skipLabel="Skip for now"
      onSkip={onSkip}
      onBack={onBack}
    >
      <View
        style={[
          styles.field,
          restingShadow(theme),
          {
            backgroundColor: theme.color.surface,
            borderRadius: theme.radius.m,
            borderColor: theme.color.brandAction,
            paddingHorizontal: theme.spacing.l,
          },
        ]}
      >
        <TextInput
          value={nickname}
          onChangeText={(value) => onChangeNickname?.(value.slice(0, MAX_NICKNAME_LENGTH))}
          placeholder="Nickname"
          placeholderTextColor={theme.color.textTertiary}
          maxLength={MAX_NICKNAME_LENGTH}
          autoCapitalize="words"
          autoCorrect={false}
          accessibilityLabel="Your child's nickname"
          accessibilityHint="Optional. Hop uses it when he speaks to your child."
          style={[textStyle('parentTitle'), styles.input, { color: theme.color.textPrimary }]}
        />
        <HopText variant="parentFootnote" tone="secondary">
          {`${nickname.length}/${MAX_NICKNAME_LENGTH}`}
        </HopText>
      </View>

      <HopText
        variant="parentCaption"
        tone="secondary"
        style={{ marginTop: theme.spacing.s, paddingHorizontal: theme.spacing.xs }}
      >
        Optional. HopPotty asks for nothing else: no last name, no birthday, no photo.
      </HopText>

      <View
        style={[
          styles.greeting,
          {
            marginTop: theme.spacing.l,
            borderRadius: theme.radius.xl,
            backgroundColor: theme.isDark ? theme.color.surfaceElevated : theme.palette.hopGreenSoft,
            paddingRight: theme.spacing.l,
            gap: theme.spacing.m,
          },
        ]}
      >
        <AvatarDisc size={30} ring={theme.palette.hopGreenLight} fill={theme.color.surface} />
        <HopText
          variant="parentCallout"
          style={{
            color: theme.isDark ? theme.color.textPrimary : theme.palette.hopGreenInk,
          }}
        >
          {trimmed ? `Hi, ${trimmed}! I'm Hop.` : "Hi! I'm Hop."}
        </HopText>
      </View>

      <View style={{ marginTop: theme.spacing.xl }}>
        <OnboardingEyebrow text="Character" tone="secondary" />
        <View style={[styles.avatars, { marginTop: theme.spacing.m, gap: theme.spacing.m }]}>
          {HOP_AVATAR_STYLES.map((style) => (
            <AvatarChoice
              key={style}
              style={style}
              selected={style === avatar}
              onPress={() => onChangeAvatar?.(style)}
            />
          ))}
        </View>
      </View>
    </OnboardingScaffold>
  );
}

function AvatarChoice({
  style,
  selected,
  onPress,
}: {
  style: HopAvatarStyleId;
  selected: boolean;
  onPress: () => void;
}): React.ReactElement {
  const theme = useHopTheme();
  const tints: Readonly<Record<HopAvatarStyleId, { fill: string; ring: string }>> = {
    frogGreen: { fill: theme.palette.hopGreenSoft, ring: theme.palette.hopGreen },
    frogBlue: { fill: theme.palette.pondBlueSoft, ring: theme.palette.pondBlue },
    frogSunshine: { fill: theme.palette.sunshineSoft, ring: theme.palette.sunshineBright },
    frogPeach: { fill: theme.palette.peachSoft, ring: theme.palette.peachPop },
    frogLavender: { fill: theme.palette.lavenderSoft, ring: theme.palette.lavender },
  };
  const tint = tints[style];

  return (
    <Pressable
      accessibilityRole="radio"
      accessibilityState={{ selected }}
      accessibilityLabel={AVATAR_LABELS[style]}
      onPress={onPress}
      style={({ pressed }) => [
        styles.avatarChoice,
        {
          borderRadius: 32,
          borderColor: selected ? theme.color.brandAction : 'transparent',
          opacity: pressed ? 0.75 : 1,
        },
      ]}
    >
      <AvatarDisc size={52} fill={tint.fill} ring={tint.ring} />
    </Pressable>
  );
}

/** Hop's own face, on a coloured disc, the way every avatar in the app is drawn. */
function AvatarDisc({
  size,
  fill,
  ring,
}: {
  size: number;
  fill: string;
  ring: string;
}): React.ReactElement {
  return (
    <View
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        backgroundColor: fill,
        borderWidth: 2,
        borderColor: ring,
        overflow: 'hidden',
        alignItems: 'center',
      }}
    >
      {/* The rig draws Hop whole; the disc shows his head, as the avatars do. */}
      <View style={{ marginTop: size * 0.02 }}>
        <HopCharacter size={size * 1.9} state="idle" decorative animated={false} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  field: {
    height: 56,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1.5,
  },
  input: { flex: 1, paddingVertical: 0 },
  greeting: { flexDirection: 'row', alignItems: 'center', alignSelf: 'flex-start', padding: 8 },
  avatars: { flexDirection: 'row', alignItems: 'center' },
  avatarChoice: { padding: 3, borderWidth: 2.5 },
});
