import React from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import {
  HopFaceDisc,
  ListGroup,
  ParentIcon,
  ParentNavBar,
  ParentPage,
  glyphSizes,
  softBacking,
  type ParentIconName,
} from '../settings/ParentKit';

/**
 * Children.
 *
 * Reference: `Art/render/screens/35-child-profiles.png`, laid out in
 * `Scripts/screens/parent-extra.js`.
 *
 * Each child owns a schedule, a timeline, their own stars and their own pond,
 * so a row says which schedule is theirs rather than treating a second child as
 * a copy of the first. Today's counts sit on the card because that is the
 * question a caregiver opens this screen with; the pond bar is progress, and it
 * is a bar rather than a percentage because a fraction of a pond is a thing you
 * can see.
 */

export interface ChildTodayCounts {
  readonly tried: number;
  readonly pee: number;
  readonly poop: number;
  readonly stars: number;
}

export interface ChildProfileSummary {
  readonly id: string;
  readonly name: string;
  /** "Guided routine · every 45 minutes". */
  readonly schedule: string;
  /** The disc behind the face — a palette tint chosen at profile creation. */
  readonly tint: string;
  readonly isCurrentlyShown: boolean;
  readonly today: ChildTodayCounts;
  readonly pondUnlocked: number;
  readonly pondTotal: number;
}

export interface ChildProfilesScreenProps {
  profiles: readonly ChildProfileSummary[];
  /** Whether HopPotty Family has been bought. Never gates what a child earned. */
  isFamilyUnlocked: boolean;
  onBack?: () => void;
  onSelectProfile?: (id: string) => void;
  onAddChild?: () => void;
  onOpenFamily?: () => void;
}

const ADD_FOOTER =
  'Every child gets their own pond, stars and schedule. Nothing is shared between them, and switching child is one tap from Home.';
const FAMILY_UNLOCKED = 'One purchase, already made. Every child you add is covered.';
const FAMILY_LOCKED = 'One purchase covers every child you add. Nothing your child earned is behind it.';

export function ChildProfilesScreen({
  profiles,
  isFamilyUnlocked,
  onBack,
  onSelectProfile,
  onAddChild,
  onOpenFamily,
}: ChildProfilesScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const g = glyphSizes(theme);

  return (
    <ParentPage>
      <ParentNavBar title="Children" backLabel="Settings" onBack={onBack} />

      {profiles.map((profile) => (
        <ChildCard
          key={profile.id}
          profile={profile}
          onPress={onSelectProfile === undefined ? undefined : () => onSelectProfile(profile.id)}
        />
      ))}

      <ListGroup
        footer={ADD_FOOTER}
        rows={[
          {
            id: 'add',
            label: 'Add a child',
            tone: 'brand',
            leading: <ParentIcon name="plus" color={theme.color.brandAction} size={g.m} />,
            onPress: onAddChild,
          },
        ]}
      />

      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`HopPotty Family, ${isFamilyUnlocked ? 'unlocked' : 'not bought yet'}`}
        onPress={onOpenFamily}
        style={[
          styles.familyRow,
          {
            columnGap: theme.spacing.m,
            padding: theme.spacing.l,
            borderRadius: theme.radius.l,
            backgroundColor: theme.color.surface,
            borderWidth: StyleSheet.hairlineWidth,
            borderColor: theme.color.divider,
          },
        ]}
      >
        <View
          style={[
            styles.centre,
            {
              width: theme.spacing.xxxl,
              height: theme.spacing.xxxl,
              borderRadius: theme.radius.s,
              backgroundColor: softBacking(theme, theme.palette.sunshineSoft),
            },
          ]}
        >
          <ParentIcon name="star" color={theme.color.celebration} size={g.s} />
        </View>
        <View style={styles.grow}>
          <View style={[styles.titleRow, { columnGap: theme.spacing.s }]}>
            <HopText variant="parentHeadline">HopPotty Family</HopText>
            {isFamilyUnlocked ? <Badge label="Unlocked" /> : null}
          </View>
          <HopText variant="parentCaption" tone="secondary" style={{ marginTop: theme.spacing.xxs }}>
            {isFamilyUnlocked ? FAMILY_UNLOCKED : FAMILY_LOCKED}
          </HopText>
        </View>
      </Pressable>
    </ParentPage>
  );
}

function ChildCard({
  profile,
  onPress,
}: {
  profile: ChildProfileSummary;
  onPress?: () => void;
}): React.ReactElement {
  const theme = useHopTheme();
  const g = glyphSizes(theme);
  const stats: readonly { key: string; icon: ParentIconName; tint: string; soft: string; value: number; label: string }[] = [
    { key: 'tried', icon: 'ring', tint: theme.color.eventTried, soft: theme.palette.lavenderSoft, value: profile.today.tried, label: 'Tried' },
    { key: 'pee', icon: 'drop', tint: theme.color.eventPee, soft: theme.palette.pondBlueSoft, value: profile.today.pee, label: 'Pee' },
    { key: 'poop', icon: 'swirl', tint: theme.color.eventPoop, soft: theme.palette.peachSoft, value: profile.today.poop, label: 'Poop' },
    { key: 'stars', icon: 'star', tint: theme.color.celebration, soft: theme.palette.sunshineSoft, value: profile.today.stars, label: 'Stars' },
  ];
  const fraction = profile.pondTotal === 0 ? 0 : profile.pondUnlocked / profile.pondTotal;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`${profile.name}. ${profile.schedule}`}
      accessibilityHint="Opens this child’s settings"
      onPress={onPress}
      style={{
        backgroundColor: theme.color.surface,
        borderRadius: theme.radius.xl,
        borderWidth: StyleSheet.hairlineWidth,
        borderColor: theme.color.divider,
        padding: theme.spacing.l,
      }}
    >
      <View style={[styles.header, { columnGap: theme.spacing.m }]}>
        <HopFaceDisc
          size={theme.hitTarget.parentMinimum}
          fill={profile.tint}
        />
        <View style={styles.grow}>
          <View style={[styles.titleRow, { columnGap: theme.spacing.s }]}>
            <HopText variant="parentTitle">{profile.name}</HopText>
            {profile.isCurrentlyShown ? <Badge label="Currently shown" /> : null}
          </View>
          <HopText variant="parentCaption" tone="secondary" style={{ marginTop: theme.spacing.xxs }}>
            {profile.schedule}
          </HopText>
        </View>
        <ParentIcon name="chevron" color={theme.color.textTertiary} size={g.s} />
      </View>

      <HopText
        variant="parentFootnote"
        tone="secondary"
        style={[
          styles.eyebrow,
          {
            marginTop: theme.spacing.m,
            paddingTop: theme.spacing.m,
            borderTopWidth: StyleSheet.hairlineWidth,
            borderTopColor: theme.color.divider,
          },
        ]}
      >
        TODAY
      </HopText>

      <View style={[styles.stats, { columnGap: theme.spacing.xs, marginTop: theme.spacing.s }]}>
        {stats.map((stat) => (
          <View key={stat.key} style={[styles.stat, { columnGap: theme.spacing.s }]}>
            <View
              style={[
                styles.centre,
                {
                  width: theme.spacing.xxl,
                  height: theme.spacing.xxl,
                  borderRadius: theme.spacing.m,
                  backgroundColor: softBacking(theme, stat.soft),
                },
              ]}
            >
              <ParentIcon name={stat.icon} color={stat.tint} size={g.s} />
            </View>
            <View style={styles.shrink}>
              <HopText variant="parentHeadline">{String(stat.value)}</HopText>
              <HopText variant="parentFootnote" tone="secondary">
                {stat.label}
              </HopText>
            </View>
          </View>
        ))}
      </View>

      <View
        style={[styles.pond, { columnGap: theme.spacing.s, marginTop: theme.spacing.m }]}
        accessibilityRole="progressbar"
        accessibilityLabel={`Pond, ${profile.pondUnlocked} of ${profile.pondTotal} unlocked`}
      >
        <HopText variant="parentFootnote" tone="secondary">
          Pond
        </HopText>
        <View
          style={{
            flex: 1,
            height: theme.spacing.s,
            borderRadius: theme.radius.xs,
            backgroundColor: theme.color.surfaceSunken,
            overflow: 'hidden',
          }}
        >
          <View
            style={{
              width: `${Math.round(fraction * 100)}%`,
              height: '100%',
              borderRadius: theme.radius.xs,
              backgroundColor: theme.color.brandPrimary,
            }}
          />
        </View>
        <HopText variant="parentFootnote" tone="secondary">
          {`${profile.pondUnlocked} of ${profile.pondTotal}`}
        </HopText>
      </View>
    </Pressable>
  );
}

/** A quiet state badge. Green because it is good news, never a call to act. */
function Badge({ label }: { label: string }): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View
      style={{
        paddingHorizontal: theme.spacing.s,
        paddingVertical: theme.spacing.xxs,
        borderRadius: theme.radius.s,
        backgroundColor: softBacking(theme, theme.palette.hopGreenSoft),
      }}
    >
      <HopText variant="parentFootnote" tone="brand">
        {label}
      </HopText>
    </View>
  );
}

const styles = StyleSheet.create({
  grow: { flex: 1 },
  shrink: { flexShrink: 1, minWidth: 0 },
  centre: { alignItems: 'center', justifyContent: 'center' },
  header: { flexDirection: 'row', alignItems: 'center' },
  titleRow: { flexDirection: 'row', alignItems: 'center' },
  eyebrow: { textTransform: 'uppercase', letterSpacing: 0.5 },
  stats: { flexDirection: 'row' },
  stat: { flex: 1, flexDirection: 'row', alignItems: 'center', minWidth: 0 },
  pond: { flexDirection: 'row', alignItems: 'center' },
  familyRow: { flexDirection: 'row', alignItems: 'flex-start' },
});
