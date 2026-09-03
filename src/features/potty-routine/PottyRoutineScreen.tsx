import React from 'react';
import { Pressable, StyleSheet, View, useWindowDimensions } from 'react-native';
import Svg, { Defs, LinearGradient, Rect, Stop } from 'react-native-svg';

import type { HopIllustrationKey } from '../../art/HopArtwork';
import { ChildStage, GrownUpButton, HopButton, HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';
import type { HopAnimationState } from '../../mascot/hopStates';
import type { RoutineStepId } from '../../navigation/types';
import { DropGlyph, RingGlyph, SwirlGlyph } from '../child-hub/ChildGlyphs';
import { RoutineTimerRing } from './RoutineTimerRing';

/**
 * One step of the guided routine.
 *
 * The references are `16-routine-step-wipe.png`, `17-routine-step-flush.png`,
 * `18-routine-step-wash.png`, `19-routine-step-highfive.png`,
 * `20-routine-try-timer.png` and `08-routine-step3.png`. They are one screen
 * because they are one screen: a full-screen place, Hop doing the step alongside
 * the child, one short sentence, one big button, and — only where the content
 * marks the step skippable — the word "Skip this" underneath.
 *
 * What used to be here and is not: the five-dot indicator at the top and the
 * five-cell named strip along the bottom. Between them they told a child, twice,
 * how much of a queue was still ahead of them. A guided routine is one focused
 * step at a time; a child who can see four steps still to come is being shown a
 * queue.
 *
 * ## The two beats of the try step
 *
 * Sitting and being asked what happened are one step and two screens. They were
 * one screen, and one screen was wrong: three answers already on the rail while
 * a child is still trying is a question asked before there is anything to
 * answer, which is pressure. So Hop waits through the first beat — with the
 * caregiver's calm ring, if they turned one on — and only the second puts the
 * three answers up.
 *
 * ## The wash step
 *
 * In the shipping app the wash step hands the screen to Bubble Wash, which is
 * another workstream's surface. Until it lands, the step is drawn here in the
 * same shape as its four siblings, with its own scene and its own sentence, so
 * the routine is walkable end to end rather than stopping at a hole.
 */

/** What the child said happened. The three are peers; nothing ranks them. */
export type PottyOutcome = 'tried' | 'pee' | 'poop';

export interface PottyRoutineScreenProps {
  readonly step: RoutineStepId;
  /**
   * The try step's second beat: the three answers are up.
   *
   * Ignored on every other step, because no other step asks a question.
   */
  readonly isAwaitingOutcome?: boolean;
  /**
   * 0…1 fill of the calm ring on the try step, or null when the caregiver has
   * not switched one on — which is the default, and is not the same as zero.
   */
  readonly timerFraction?: number | null;
  /** Marks the step done. "Next" on four steps, "All done!" on the last. */
  readonly onNext: () => void;
  /** Offered only where the content marks the step skippable. */
  readonly onSkip?: () => void;
  readonly onOutcome?: (outcome: PottyOutcome) => void;
  /** The way to a grown-up, in the same corner on every child screen. */
  readonly onGrownUp?: () => void;
}

interface RoutineStepContent {
  /** One or two words, large, on its own line. */
  readonly title: string;
  /** The single thing to do, as a sentence. */
  readonly instruction: string;
  readonly scene: HopIllustrationKey;
  readonly hop: HopAnimationState;
  readonly hopLabel: string;
  readonly hopWidth: number;
  readonly primaryLabel: string;
  readonly isSkippable: boolean;
}

/**
 * The five steps, verbatim from `PottyRoutineContent`.
 *
 * Copy, illustration key and skippability are the content layer's, not this
 * screen's: a step whose words live in a view is a step a translator cannot see
 * and a caregiver cannot be shown.
 */
const STEPS: Readonly<Record<RoutineStepId, RoutineStepContent>> = {
  try: {
    title: 'Try',
    instruction: 'Give it a try.',
    scene: 'scene.routine.try',
    hop: 'sit',
    hopLabel: 'Hop sits and waits with you',
    hopWidth: 232,
    primaryLabel: 'Next',
    isSkippable: true,
  },
  wipe: {
    title: 'Wipe',
    instruction: 'Wipe from front to back.',
    scene: 'scene.routine.wipe',
    hop: 'sit',
    hopLabel: 'Hop shows you how to wipe',
    hopWidth: 236,
    primaryLabel: 'Next',
    // Plenty of visits produce nothing to wipe, and in many families a grown-up
    // does this part.
    isSkippable: true,
  },
  flush: {
    title: 'Flush',
    instruction: 'Flush it away.',
    scene: 'scene.routine.flush',
    hop: 'wave',
    hopLabel: 'Hop waves goodbye to the flush',
    hopWidth: 250,
    primaryLabel: 'Next',
    // Skippable on purpose: the noise frightens a real share of two- and
    // three-year-olds, and a routine that traps a scared child at the flush is a
    // routine they refuse tomorrow.
    isSkippable: true,
  },
  wash: {
    title: 'Wash',
    instruction: 'Wash those hands!',
    scene: 'scene.routine.wash',
    hop: 'wash',
    hopLabel: 'Hop scrubs his hands',
    hopWidth: 240,
    primaryLabel: 'Next',
    isSkippable: false,
  },
  highFive: {
    title: 'High five',
    instruction: 'High five with Hop!',
    scene: 'scene.routine.highFive',
    hop: 'celebrate',
    hopLabel: 'Hop has his hand up for a high five',
    hopWidth: 306,
    primaryLabel: 'All done!',
    isSkippable: false,
  },
};

/** The question the try step's second beat asks, and its three peer answers. */
const OUTCOMES: readonly { readonly id: PottyOutcome; readonly label: string }[] = [
  // "I tried" is first because a child who sat down and nothing happened did the
  // entire skill this product teaches.
  { id: 'tried', label: 'I tried' },
  { id: 'pee', label: 'I peed' },
  { id: 'poop', label: 'I pooped' },
];

export function PottyRoutineScreen({
  step,
  isAwaitingOutcome = false,
  timerFraction = null,
  onNext,
  onSkip,
  onOutcome,
  onGrownUp,
}: PottyRoutineScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const { width, height } = useWindowDimensions();
  const isWide = width >= 768;
  const content = STEPS[step];
  const asking = step === 'try' && isAwaitingOutcome;

  // The scene is drawn at its own 4:3, full width, so nothing in it is cropped —
  // which is the whole reason it is a band rather than a full-bleed cover.
  const bandHeight = width * 0.75;
  const bandTop = height * 0.223;
  const bandBottom = bandTop + bandHeight;
  const fade = bandHeight * 0.17;

  const showsRing = step === 'try' && !asking && timerFraction !== null;
  const hopSide = asking ? 236 : content.hopWidth;

  return (
    <ChildStage
      scene={content.scene}
      sceneStyle={{ top: bandTop, bottom: Math.max(0, height - bandBottom) }}
      veilFrom={bandBottom}
      veilHeight={Math.max(0, height - bandBottom)}
      veilStrength={asking ? 0.9 : 0.74}
    >
      <SceneBandEdges top={bandTop} height={bandHeight} fade={fade} width={width} />

      <View
        style={[
          styles.content,
          {
            paddingHorizontal: theme.spacing.xxl,
            paddingBottom: theme.spacing.s,
            maxWidth: isWide ? 560 : undefined,
            alignSelf: isWide ? 'center' : 'stretch',
            width: isWide ? '100%' : undefined,
          },
        ]}
      >
        <View style={styles.grownUpRow}>
          <GrownUpButton onPress={onGrownUp} />
        </View>

        <View style={styles.spacer} pointerEvents="none" />

        <View style={styles.mascot} pointerEvents="none">
          {showsRing && timerFraction !== null ? (
            <RoutineTimerRing
              fraction={timerFraction}
              diameter={Math.min(300, width * 0.78)}
              accessibilityLabel="Take all the time you need."
            >
              <HopCharacter
                size={content.hopWidth}
                state={content.hop}
                accessibilityLabel={content.hopLabel}
              />
            </RoutineTimerRing>
          ) : (
            <HopCharacter
              size={hopSide}
              state={asking ? 'talk' : content.hop}
              accessibilityLabel={asking ? 'Hop asks how it went' : content.hopLabel}
            />
          )}
        </View>

        <View style={{ height: theme.spacing.s }} />

        <View pointerEvents="none">
          <HopText variant="childTitle" style={styles.centred} accessibilityRole="header">
            {asking ? 'All done trying?' : content.title}
          </HopText>
          {asking ? null : (
            <HopText
              variant="childInstruction"
              tone="secondary"
              style={[styles.centred, { marginTop: theme.spacing.s }]}
            >
              {content.instruction}
            </HopText>
          )}
          {showsRing ? (
            <HopText
              variant="parentTitle"
              tone="secondary"
              style={[styles.centred, { marginTop: theme.spacing.s }]}
            >
              Take all the time you need.
            </HopText>
          ) : null}
        </View>

        <View style={styles.spacer} pointerEvents="none" />

        {asking ? (
          <View style={{ gap: theme.spacing.m }}>
            {OUTCOMES.map((outcome) => (
              <OutcomeChoice
                key={outcome.id}
                outcome={outcome.id}
                label={outcome.label}
                onPress={() => onOutcome?.(outcome.id)}
              />
            ))}
          </View>
        ) : (
          <View>
            <HopButton
              label={content.primaryLabel}
              audience="child"
              onPress={onNext}
              style={{ minHeight: 104, borderRadius: theme.radius.hero }}
            />
            {content.isSkippable && onSkip ? (
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Skip this"
                onPress={onSkip}
                style={({ pressed }) => [
                  styles.skip,
                  { minHeight: theme.hitTarget.childMinimum, opacity: pressed ? 0.6 : 1 },
                ]}
              >
                <HopText variant="parentTitle" tone="secondary">
                  Skip this
                </HopText>
              </Pressable>
            ) : null}
          </View>
        )}
      </View>
    </ChildStage>
  );
}

/**
 * One of the three answers.
 *
 * Identical height, radius, type and glyph diameter; the only differences are
 * the hue, the picture and the word, and each of those is a *peer* difference —
 * three kinds of thing, not three grades.
 */
function OutcomeChoice({
  outcome,
  label,
  onPress,
}: {
  readonly outcome: PottyOutcome;
  readonly label: string;
  readonly onPress: () => void;
}): React.ReactElement {
  const theme = useHopTheme();

  const tint =
    outcome === 'tried'
      ? { deep: theme.palette.lavenderDeep, soft: theme.palette.lavenderSoft, edge: theme.palette.lavender }
      : outcome === 'pee'
        ? { deep: theme.palette.pondBlueDeep, soft: theme.palette.pondBlueSoft, edge: theme.palette.pondBlueLight }
        : { deep: theme.palette.peachDeep, soft: theme.palette.peachSoft, edge: theme.palette.peachPop };

  const Glyph = outcome === 'tried' ? RingGlyph : outcome === 'pee' ? DropGlyph : SwirlGlyph;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={onPress}
      style={({ pressed }) => [
        styles.choice,
        {
          minHeight: 112,
          borderRadius: theme.radius.hero,
          backgroundColor: theme.color.surface,
          borderColor: tint.edge,
          paddingHorizontal: theme.spacing.xxl,
          gap: theme.spacing.xxl,
          opacity: pressed ? 0.9 : 1,
        },
      ]}
    >
      <View style={[styles.choiceGlyph, { backgroundColor: tint.soft }]}>
        <Glyph color={tint.deep} size={36} />
      </View>
      <HopText variant="metric" style={styles.choiceLabel}>
        {label}
      </HopText>
    </Pressable>
  );
}

/**
 * The band's top and bottom edges, melted into the page.
 *
 * The design renders mask the picture's edges away over a blurred copy of
 * itself. React Native has no blur without another native dependency, so the
 * same result is reached from the other side: the page colour is painted *over*
 * the band's first and last sixth, which is what the mask was doing.
 */
function SceneBandEdges({
  top,
  height,
  fade,
  width,
}: {
  readonly top: number;
  readonly height: number;
  readonly fade: number;
  readonly width: number;
}): React.ReactElement {
  const theme = useHopTheme();
  const ns = React.useId().replace(/[^A-Za-z0-9]/g, '');
  const id = `bandEdge${ns}`;
  const c = theme.color.backgroundPrimary;
  const stop = height > 0 ? fade / height : 0;

  return (
    <Svg
      width={width}
      height={height}
      pointerEvents="none"
      style={{ position: 'absolute', left: 0, top, width, height }}
    >
      <Defs>
        <LinearGradient id={id} x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor={c} stopOpacity={1} />
          <Stop offset={stop} stopColor={c} stopOpacity={0} />
          <Stop offset={1 - stop} stopColor={c} stopOpacity={0} />
          <Stop offset="1" stopColor={c} stopOpacity={1} />
        </LinearGradient>
      </Defs>
      <Rect x={0} y={0} width={width} height={height} fill={`url(#${id})`} />
    </Svg>
  );
}

const styles = StyleSheet.create({
  content: { flex: 1 },
  grownUpRow: { alignItems: 'flex-end', paddingTop: 4 },
  spacer: { flex: 1 },
  mascot: { alignItems: 'center' },
  centred: { textAlign: 'center' },
  skip: { alignItems: 'center', justifyContent: 'center' },
  choice: { flexDirection: 'row', alignItems: 'center', borderWidth: 2 },
  choiceGlyph: { width: 70, height: 70, borderRadius: 35, alignItems: 'center', justifyContent: 'center' },
  choiceLabel: { flex: 1 },
});
