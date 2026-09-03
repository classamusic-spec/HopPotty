import React from 'react';
import { StyleSheet, View } from 'react-native';

import { HopText } from '../../design-system/components';
import { useHopTheme, type HopTheme } from '../../design-system/theme';
import { IconTile, LockMark, PauseMark, PlayMark, RingMark } from './OnboardingMarks';
import {
  OnboardingScaffold,
  restingShadow,
  stepPosition,
  type OnboardingStepPosition,
} from './OnboardingScaffold';

/**
 * 03 — the loop, drawn.
 *
 * The reference is `Art/render/screens/03-onboarding-idea.png` (`theIdea()` in
 * `Scripts/screens/onboarding.js`). The rail down the left is the argument:
 * four beats and a return, so the interruption reads as a circle rather than a
 * punishment with an end. It is built from views rather than a path because the
 * shape is two straight lines and a rounded bracket, and a bracket is a border.
 */

const CARD = 68;
const GAP = 14;
const GUTTER = 46;
const SPINE_X = 33;
const LOOP_X = 7;
const CENTRES = [0, 1, 2, 3].map((i) => i * (CARD + GAP) + CARD / 2);
const RAIL_HEIGHT = 4 * CARD + 3 * GAP;

export interface TheIdeaScreenProps {
  onContinue?: () => void;
  onSkip?: () => void;
  onBack?: () => void;
  step?: OnboardingStepPosition;
}

export function TheIdeaScreen({
  onContinue,
  onSkip,
  onBack,
  step = stepPosition('theIdea'),
}: TheIdeaScreenProps): React.ReactElement {
  const theme = useHopTheme();

  return (
    <OnboardingScaffold
      eyebrow="The idea"
      title="Pause. Potty. Play."
      message="One loop, four beats. Your child gets a routine; the game they were promised comes back."
      step={step}
      primaryLabel="Continue"
      onPrimary={onContinue}
      skipLabel={onSkip ? 'Skip' : undefined}
      onSkip={onSkip}
      onBack={onBack}
    >
      <View style={styles.railRow}>
        <Rail theme={theme} />
        <View style={styles.beats}>
          <Beat
            word="PLAY"
            body="Your child is deep in a game."
            soft={theme.palette.hopGreenSoft}
            mark={<PlayMark size={19} color={theme.palette.hopGreenDeep} />}
          />
          <Beat
            word="PAUSE"
            body="The app goes quiet. Hop appears."
            soft={theme.palette.sunshineSoft}
            mark={<PauseMark size={18} color={theme.palette.sunshineDeep} />}
          />
          <Beat
            word="POTTY"
            body="Try, wipe, flush, wash, high five."
            soft={theme.palette.lavenderSoft}
            mark={<RingMark size={19} color={theme.palette.lavenderDeep} />}
          />
          <Beat
            word="PLAY"
            body="The game comes right back."
            soft={theme.palette.pondBlueSoft}
            mark={<PlayMark size={19} color={theme.palette.pondBlueDeep} />}
          />
        </View>
      </View>

      <View style={[styles.loopRow, { marginTop: theme.spacing.l }]}>
        <HopText
          variant="parentCaption"
          tone="secondary"
          accessibilityElementsHidden
          importantForAccessibility="no-hide-descendants"
        >
          ↻
        </HopText>
        <HopText variant="parentCaption" tone="secondary">
          And around again, on the rhythm you set.
        </HopText>
      </View>

      <View
        style={[
          styles.promise,
          restingShadow(theme),
          {
            marginTop: theme.spacing.xxl,
            backgroundColor: theme.color.surface,
            borderRadius: theme.radius.l,
            padding: theme.spacing.l,
            gap: theme.spacing.m,
          },
        ]}
      >
        <IconTile
          size={34}
          radius={theme.radius.s}
          background={theme.isDark ? theme.color.surfaceSunken : theme.palette.hopGreenSoft}
        >
          <LockMark size={16} color={theme.isDark ? theme.palette.hopGreenLight : theme.palette.hopGreenInk} />
        </IconTile>
        <HopText variant="parentCaption" tone="secondary" style={styles.flex}>
          The pause ends on its own timer. Screen access is never held back for a result.
        </HopText>
      </View>
    </OnboardingScaffold>
  );
}

/** One beat of the loop. */
function Beat({
  word,
  body,
  soft,
  mark,
}: {
  word: string;
  body: string;
  soft: string;
  mark: React.ReactNode;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View
      accessible
      accessibilityLabel={`${word}. ${body}`}
      style={[
        styles.beat,
        restingShadow(theme),
        {
          backgroundColor: theme.color.surface,
          borderRadius: theme.radius.l,
          paddingHorizontal: theme.spacing.l,
          gap: theme.spacing.l,
        },
      ]}
    >
      <IconTile size={42} radius={theme.radius.m} background={theme.isDark ? theme.color.surfaceSunken : soft}>
        {mark}
      </IconTile>
      <View style={styles.flex}>
        <HopText variant="parentHeadline" style={{ color: theme.color.textPrimary }}>
          {word}
        </HopText>
        <HopText variant="parentCaption" tone="secondary">
          {body}
        </HopText>
      </View>
    </View>
  );
}

/**
 * The spine, its four ticks and the bracket that returns to the top.
 *
 * Decorative: every beat beside it is already a labelled element, and a screen
 * reader announcing four dots and an arrow would be reading the drawing rather
 * than the argument.
 */
function Rail({ theme }: { theme: HopTheme }): React.ReactElement {
  const rail = theme.color.brandAction;
  const first = CENTRES[0] ?? 0;
  const last = CENTRES[3] ?? 0;
  return (
    <View
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      style={styles.rail}
    >
      {/* The return: down the left, round the corners, back to the first beat. */}
      <View
        style={[
          styles.loop,
          {
            left: LOOP_X,
            top: first - 8,
            width: SPINE_X - LOOP_X,
            height: last - first + 16,
            borderColor: rail,
          },
        ]}
      />
      <View
        style={[
          styles.spine,
          { left: SPINE_X - 1, top: first, height: last - first, backgroundColor: rail },
        ]}
      />
      {CENTRES.map((y) => (
        <React.Fragment key={y}>
          <View style={[styles.tick, { left: SPINE_X, top: y - 1, backgroundColor: rail }]} />
          <View style={[styles.node, { left: SPINE_X - 5, top: y - 5, backgroundColor: rail }]} />
        </React.Fragment>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  railRow: { flexDirection: 'row' },
  rail: { width: GUTTER, height: RAIL_HEIGHT, opacity: 0.55 },
  loop: {
    position: 'absolute',
    borderLeftWidth: 2,
    borderTopWidth: 2,
    borderBottomWidth: 2,
    borderRightWidth: 0,
    borderTopLeftRadius: 13,
    borderBottomLeftRadius: 13,
  },
  spine: { position: 'absolute', width: 2 },
  tick: { position: 'absolute', width: 15, height: 2 },
  node: { position: 'absolute', width: 10, height: 10, borderRadius: 5 },
  beats: { flex: 1, gap: GAP },
  beat: { height: CARD, flexDirection: 'row', alignItems: 'center' },
  loopRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8 },
  promise: { flexDirection: 'row', alignItems: 'flex-start' },
});
