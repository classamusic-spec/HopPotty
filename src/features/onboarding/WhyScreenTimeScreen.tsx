import React, { useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { AppsMark, LockMark, SlidersMark } from './OnboardingMarks';
import {
  OnboardingScaffold,
  restingShadow,
  stepPosition,
  type OnboardingStepPosition,
} from './OnboardingScaffold';

/**
 * 06 — the permission conversation, before Apple's prompt.
 *
 * The reference is `Art/render/screens/31-onboarding-screen-time-ask.png`
 * (`screenTimeAsk()` in `Scripts/screens/parent-extra.js`).
 *
 * The order is the whole design: a system alert that arrives with no context is
 * the one a caregiver declines. Three promises, three lines, no card each —
 * everything longer (the framework, the sealed tokens, what persists) is behind
 * **How this works**, closed by default. Trust is not built by saying more at
 * the moment of the ask; it is built by making the short version true and the
 * long version reachable.
 */

export interface WhyScreenTimeScreenProps {
  onAllow?: () => void;
  /** Declining here is a real path: gentle mode needs no permission at all. */
  onNotNow?: () => void;
  onBack?: () => void;
  step?: OnboardingStepPosition;
}

export function WhyScreenTimeScreen({
  onAllow,
  onNotNow,
  onBack,
  step = stepPosition('whyScreenTime'),
}: WhyScreenTimeScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const [expanded, setExpanded] = useState(false);
  const accent = theme.isDark ? theme.palette.hopGreenLight : theme.palette.hopGreenInk;

  return (
    <OnboardingScaffold
      eyebrow="Permission"
      title="HopPotty uses Screen Time"
      step={step}
      footnote="The next screen is Apple's. Without permission, apps are never paused."
      primaryLabel="Allow Screen Time"
      onPrimary={onAllow}
      secondaryLabel="Not now"
      onSecondary={onNotNow}
      onBack={onBack}
    >
      <View style={{ gap: theme.spacing.xl, marginTop: theme.spacing.xxl }}>
        <Promise text="You choose the apps." mark={<AppsMark size={19} color={accent} />} />
        <Promise
          text="HopPotty can't see inside them."
          mark={<LockMark size={19} color={accent} />}
        />
        <Promise
          text="You can turn this off anytime."
          mark={<SlidersMark size={19} color={accent} />}
        />
      </View>

      <Pressable
        accessibilityRole="button"
        accessibilityState={{ expanded }}
        accessibilityLabel="How this works"
        accessibilityHint={expanded ? 'Collapses the detail' : 'Shows what iOS does and what HopPotty can see'}
        onPress={() => setExpanded((open) => !open)}
        style={({ pressed }) => [
          restingShadow(theme),
          {
            marginTop: theme.spacing.xxl,
            backgroundColor: theme.color.surface,
            borderRadius: theme.radius.l,
            padding: theme.spacing.l,
            minHeight: theme.hitTarget.parentMinimum,
            justifyContent: 'center',
            opacity: pressed ? 0.85 : 1,
          },
        ]}
      >
        <View style={styles.disclosureRow}>
          <HopText variant="parentBody" style={styles.flex}>
            How this works
          </HopText>
          <HopText
            variant="parentHeadline"
            tone="tertiary"
            accessibilityElementsHidden
            importantForAccessibility="no-hide-descendants"
          >
            {expanded ? '⌄' : '›'}
          </HopText>
        </View>
        {expanded ? (
          <HopText
            variant="parentCallout"
            tone="secondary"
            style={{ marginTop: theme.spacing.s }}
          >
            iOS does the pausing, not HopPotty. When you pick apps, Apple hands over a sealed token
            for each one: HopPotty can count them and pause them, and cannot read a name or an icon.
            The next screen is Apple&apos;s, and HopPotty cannot see or change what it asks. Without
            permission, apps are never paused — Hop still checks in on your schedule, and you can
            turn pausing on later in Settings.
          </HopText>
        ) : null}
      </Pressable>
    </OnboardingScaffold>
  );
}

/** One promise: a mark and a sentence. A card each would be three containers
 *  doing the work one list does. */
function Promise({ text, mark }: { text: string; mark: React.ReactNode }): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View accessible accessibilityLabel={text} style={[styles.promise, { gap: theme.spacing.l }]}>
      <View style={styles.markSlot}>{mark}</View>
      <HopText variant="parentBody" style={styles.flex}>
        {text}
      </HopText>
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  promise: { flexDirection: 'row', alignItems: 'flex-start' },
  markSlot: { width: 22, alignItems: 'center', paddingTop: 3 },
  disclosureRow: { flexDirection: 'row', alignItems: 'center' },
});
