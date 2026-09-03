import React from 'react';
import { Pressable, StyleSheet, TextInput, View } from 'react-native';

import { HopButton, HopText } from '../../design-system/components';
import { textStyle, useHopTheme } from '../../design-system/theme';
import {
  BORDER_WIDTH,
  Eyebrow,
  HopFaceDisc,
  ParentIcon,
  ParentPage,
  glyphSizes,
  softBacking,
} from '../settings/ParentKit';

/**
 * A child profile.
 *
 * Reference: `Art/render/screens/32-onboarding-child-profile.png` — the same
 * form appears in onboarding and in Settings, so it is one screen with a
 * different button on the end.
 *
 * Nickname, a character, a starting routine. That is the whole form, because
 * `ChildProfile` has nowhere to put a birthday, a last name or a photograph.
 * The band at the bottom is a *routine* choice rather than a fact about the
 * child, and the footer says so instead of leaving a caregiver to assume
 * HopPotty is keeping an age.
 */

export type StartingPoint = 'justStarting' | 'gettingTheHangOfIt' | 'mostlyIndependent';

export interface AvatarChoice {
  readonly id: string;
  /** The disc behind the face. A palette tint, never an arbitrary colour. */
  readonly tint: string;
  /** How a screen reader names it: "green", "pond blue". */
  readonly name: string;
}

export interface ChildProfileEditorScreenProps {
  nickname: string;
  /** The field's limit, so the counter and the field agree. */
  nicknameLimit: number;
  avatars: readonly AvatarChoice[];
  selectedAvatarId: string;
  startingPoint: StartingPoint;
  /** "Continue" in onboarding, "Save" from Settings. */
  submitLabel: string;
  onBack?: () => void;
  onChangeNickname?: (next: string) => void;
  onSelectAvatar?: (id: string) => void;
  onSelectStartingPoint?: (point: StartingPoint) => void;
  onSubmit?: () => void;
}

const NICKNAME_FOOTER =
  'Optional. HopPotty asks for nothing else: no last name, no birthday, no photo.';
const START_FOOTER =
  'This only picks a starting routine, and you can change it any time. HopPotty stores no age and no birthday.';

const BANDS: readonly { readonly id: StartingPoint; readonly title: string; readonly sub: string }[] = [
  { id: 'justStarting', title: 'Just starting out', sub: 'Around 2. Nappies most of the day.' },
  {
    id: 'gettingTheHangOfIt',
    title: 'Getting the hang of it',
    sub: 'Around 3. Dry stretches, some accidents.',
  },
  { id: 'mostlyIndependent', title: 'Mostly independent', sub: '4 and up. Needs the occasional nudge.' },
];

export function ChildProfileEditorScreen({
  nickname,
  nicknameLimit,
  avatars,
  selectedAvatarId,
  startingPoint,
  submitLabel,
  onBack,
  onChangeNickname,
  onSelectAvatar,
  onSelectStartingPoint,
  onSubmit,
}: ChildProfileEditorScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const g = glyphSizes(theme);
  const selected = avatars.find((avatar) => avatar.id === selectedAvatarId) ?? avatars[0];
  const greeting = nickname.trim().length === 0 ? "Hi! I'm Hop." : `Hi, ${nickname}! I'm Hop.`;

  return (
    <ParentPage>
      <View>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Back"
          onPress={onBack}
          hitSlop={theme.spacing.m}
          style={styles.backRow}
        >
          <ParentIcon name="chevronLeft" color={theme.color.brandAction} size={g.m} />
        </Pressable>
        <Eyebrow text="Your child" tone="brand" style={{ marginTop: theme.spacing.s }} />
        <HopText variant="parentLargeTitle" style={{ marginTop: theme.spacing.xxs }}>
          What can Hop call your child?
        </HopText>
      </View>

      <View
        style={{
          minHeight: theme.hitTarget.parentMinimum + theme.spacing.m,
          borderRadius: theme.radius.m,
          borderWidth: BORDER_WIDTH.control,
          borderColor: theme.color.brandAction,
          backgroundColor: theme.color.surface,
          paddingHorizontal: theme.spacing.l,
          flexDirection: 'row',
          alignItems: 'center',
          columnGap: theme.spacing.s,
        }}
      >
        <TextInput
          accessibilityLabel="Nickname"
          value={nickname}
          onChangeText={onChangeNickname}
          maxLength={nicknameLimit}
          placeholder="Nickname"
          placeholderTextColor={theme.color.textTertiary}
          selectionColor={theme.color.brandAction}
          style={[textStyle('parentTitle'), styles.field, { color: theme.color.textPrimary }]}
        />
        <HopText variant="parentFootnote" tone="secondary">
          {`${nickname.length}/${nicknameLimit}`}
        </HopText>
      </View>
      <HopText variant="parentCaption" tone="secondary" style={{ paddingHorizontal: theme.spacing.xs }}>
        {NICKNAME_FOOTER}
      </HopText>

      <View
        style={[
          styles.greeting,
          {
            alignSelf: 'flex-start',
            columnGap: theme.spacing.s,
            paddingLeft: theme.spacing.s,
            paddingRight: theme.spacing.l,
            paddingVertical: theme.spacing.s,
            borderRadius: theme.radius.xl,
            backgroundColor: softBacking(theme, theme.palette.hopGreenSoft),
          },
        ]}
      >
        <HopFaceDisc
          size={theme.spacing.xxxl}
          fill={theme.color.surface}
          ring={selected?.tint ?? theme.palette.hopGreenLight}
        />
        <HopText variant="parentCallout" tone="brand">
          {greeting}
        </HopText>
      </View>

      <View>
        <Eyebrow text="Character" />
        <View
          accessibilityRole="radiogroup"
          accessibilityLabel="Character"
          style={[styles.avatars, { columnGap: theme.spacing.m, marginTop: theme.spacing.s }]}
        >
          {avatars.map((avatar) => {
            const on = avatar.id === selectedAvatarId;
            return (
              <Pressable
                key={avatar.id}
                accessibilityRole="radio"
                accessibilityState={{ selected: on }}
                accessibilityLabel={avatar.name}
                onPress={() => onSelectAvatar?.(avatar.id)}
                style={[
                  styles.avatarSlot,
                  {
                    padding: theme.spacing.xxs,
                    borderRadius: theme.radius.hero,
                    borderWidth: BORDER_WIDTH.selection,
                    borderColor: on ? theme.color.brandAction : 'transparent',
                  },
                ]}
              >
                <HopFaceDisc
                  size={theme.hitTarget.parentMinimum + theme.spacing.s}
                  fill={avatar.tint}
                />
              </Pressable>
            );
          })}
        </View>
      </View>

      <View>
        <Eyebrow text="Where are you starting?" />
        <View
          accessibilityRole="radiogroup"
          accessibilityLabel="Where are you starting?"
          style={{
            marginTop: theme.spacing.s,
            borderRadius: theme.radius.l,
            overflow: 'hidden',
            backgroundColor: theme.color.surface,
            borderWidth: StyleSheet.hairlineWidth,
            borderColor: theme.color.divider,
          }}
        >
          {BANDS.map((band, index) => {
            const on = band.id === startingPoint;
            return (
              <Pressable
                key={band.id}
                accessibilityRole="radio"
                accessibilityState={{ selected: on }}
                accessibilityLabel={`${band.title}. ${band.sub}`}
                onPress={() => onSelectStartingPoint?.(band.id)}
                style={{
                  flexDirection: 'row',
                  alignItems: 'center',
                  columnGap: theme.spacing.m,
                  minHeight: theme.hitTarget.parentMinimum + theme.spacing.m,
                  paddingHorizontal: theme.spacing.l,
                  paddingVertical: theme.spacing.s,
                  borderTopWidth: index === 0 ? 0 : StyleSheet.hairlineWidth,
                  borderTopColor: theme.color.divider,
                }}
              >
                <View style={styles.grow}>
                  <HopText variant={on ? 'parentHeadline' : 'parentBody'}>{band.title}</HopText>
                  <HopText variant="parentCaption" tone="secondary">
                    {band.sub}
                  </HopText>
                </View>
                {on ? (
                  <ParentIcon name="check" color={theme.color.brandAction} size={g.m} />
                ) : (
                  <View
                    style={{
                      width: theme.spacing.xl,
                      height: theme.spacing.xl,
                      borderRadius: theme.spacing.m,
                      borderWidth: BORDER_WIDTH.control,
                      borderColor: theme.color.divider,
                    }}
                  />
                )}
              </Pressable>
            );
          })}
        </View>
        <HopText
          variant="parentCaption"
          tone="secondary"
          style={{ paddingHorizontal: theme.spacing.xs, paddingTop: theme.spacing.s }}
        >
          {START_FOOTER}
        </HopText>
      </View>

      <HopButton label={submitLabel} onPress={onSubmit} style={{ marginTop: theme.spacing.s }} />
    </ParentPage>
  );
}

const styles = StyleSheet.create({
  grow: { flex: 1 },
  field: { flex: 1, paddingVertical: 0 },
  greeting: { flexDirection: 'row', alignItems: 'center' },
  avatars: { flexDirection: 'row', alignItems: 'center' },
  avatarSlot: { alignItems: 'center', justifyContent: 'center' },
  backRow: { flexDirection: 'row', alignItems: 'center', alignSelf: 'flex-start' },
});
