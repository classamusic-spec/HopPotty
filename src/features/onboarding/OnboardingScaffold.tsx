import React from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  View,
  useWindowDimensions,
  type ViewStyle,
} from 'react-native';

import { HopButton, HopText } from '../../design-system/components';
import { useHopTheme, type HopTheme } from '../../design-system/theme';

/**
 * The frame every onboarding step sits in.
 *
 * One scaffold rather than twelve layouts, for the reason
 * `OnboardingScaffold` exists in Swift: the back row, the eyebrow, the measure,
 * the step dots and the button placement are identical on every step, and a
 * step that laid itself out differently would read as a different app. The
 * numbers come from `Scripts/screens/onboarding.js` and
 * `Scripts/screens/parent-extra.js`, which produced renders 02, 03, 31 and 32.
 */

/** Where a step sits in the path this caregiver is actually walking. */
export interface OnboardingStepPosition {
  readonly index: number;
  readonly total: number;
}

/**
 * The twelve steps, in order, so a screen can name its own default position
 * without the caller having to count. The host may still pass a shorter path:
 * choosing gentle mode genuinely removes the three permission screens, and the
 * indicator should shrink with it rather than stall.
 */
export const ONBOARDING_STEP_IDS = [
  'meetHop',
  'theIdea',
  'nickname',
  'chooseRoutine',
  'interval',
  'whyScreenTime',
  'authorization',
  'chooseApps',
  'quietHours',
  'notifications',
  'testPause',
  'ready',
] as const;

export type OnboardingStepId = (typeof ONBOARDING_STEP_IDS)[number];

export function stepPosition(id: OnboardingStepId): OnboardingStepPosition {
  return { index: ONBOARDING_STEP_IDS.indexOf(id), total: ONBOARDING_STEP_IDS.length };
}

/**
 * iPad is a layout, not a stretched phone.
 *
 * `READING_COLUMN` is a measure rather than a token: the design tokens describe
 * rhythm and type, and have nothing to say about how wide a paragraph may get
 * before it stops being readable. 560pt keeps a caregiver's line length near
 * the phone's, which is what the renders were drawn at.
 */
const READING_COLUMN = 560;
const REGULAR_WIDTH = 768;

export interface HopScreenLayout {
  readonly isRegular: boolean;
  readonly pagePadding: number;
  /** Centres and caps a column of reading matter on a wide screen. */
  readonly column: ViewStyle;
}

export function useHopScreenLayout(): HopScreenLayout {
  const theme = useHopTheme();
  const { width } = useWindowDimensions();
  const isRegular = width >= REGULAR_WIDTH;
  return {
    isRegular,
    pagePadding: isRegular ? theme.spacing.pageRegular : theme.spacing.xxl,
    column: isRegular
      ? { width: '100%', maxWidth: READING_COLUMN, alignSelf: 'center' }
      : { width: '100%' },
  };
}

/** The soft lift a caregiver surface sits on. Mirrors `elevation(_, 'resting')`. */
export function restingShadow(theme: HopTheme): ViewStyle {
  return {
    shadowColor: theme.color.shadow,
    shadowOpacity: theme.isDark ? 0.34 : 0.07,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 3 },
    elevation: 2,
  };
}

/** The uppercase label an onboarding screen opens with. */
export function OnboardingEyebrow({
  text,
  tone = 'brand',
}: {
  text: string;
  tone?: 'brand' | 'secondary';
}): React.ReactElement {
  return (
    <HopText variant="parentFootnote" tone={tone} style={styles.eyebrow}>
      {text}
    </HopText>
  );
}

/** How far through setup the caregiver is — dots, never "step 4 of 12". */
export function OnboardingStepDots({
  step,
}: {
  step: OnboardingStepPosition;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View
      style={styles.dots}
      accessibilityRole="progressbar"
      accessibilityLabel={`Step ${step.index + 1} of ${step.total}`}
      accessibilityValue={{ min: 1, max: step.total, now: step.index + 1 }}
    >
      {Array.from({ length: step.total }, (_, i) => (
        <View
          key={i}
          style={[
            styles.dot,
            i === step.index
              ? { width: 22, backgroundColor: theme.color.brandAction }
              : { width: 8, backgroundColor: theme.color.divider },
          ]}
        />
      ))}
    </View>
  );
}

/** A quiet text control: Skip, Not now, Change the schedule. */
export function OnboardingTextButton({
  label,
  onPress,
  align = 'center',
  tone = 'secondary',
}: {
  label: string;
  onPress?: () => void;
  align?: 'center' | 'end';
  tone?: 'secondary' | 'brand';
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={onPress}
      style={({ pressed }) => [
        styles.textButton,
        {
          minHeight: theme.hitTarget.parentMinimum,
          alignItems: align === 'end' ? 'flex-end' : 'center',
          paddingHorizontal: theme.spacing.xs,
          opacity: pressed ? 0.6 : 1,
        },
      ]}
    >
      <HopText variant="parentCallout" tone={tone}>
        {label}
      </HopText>
    </Pressable>
  );
}

/** The back chevron onboarding draws on its own row. */
export function OnboardingBackButton({ onPress }: { onPress?: () => void }): React.ReactElement {
  const theme = useHopTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel="Back"
      onPress={onPress}
      style={({ pressed }) => [
        styles.back,
        { minWidth: theme.hitTarget.parentMinimum, opacity: pressed ? 0.6 : 1 },
      ]}
    >
      <HopText variant="parentTitle" tone="brand">
        {'‹'}
      </HopText>
    </Pressable>
  );
}

export interface OnboardingScaffoldProps {
  /** Small uppercase label above the title. */
  eyebrow?: string;
  title: string;
  titleAlign?: 'leading' | 'center';
  /** The one sentence under the title. */
  message?: string;
  /** A second, quieter paragraph. Only `MeetHop` uses one. */
  detail?: string;
  /** Art or a medallion that sits above the title and takes the slack. */
  hero?: React.ReactNode;
  children?: React.ReactNode;
  /** Centred caption directly above the step dots. */
  footnote?: string;
  step: OnboardingStepPosition;
  primaryLabel: string;
  primaryEnabled?: boolean;
  onPrimary?: () => void;
  /** A quiet control under the primary button — "Not now", never a second CTA. */
  secondaryLabel?: string;
  onSecondary?: () => void;
  /** Top-right escape. A skippable step says so rather than hiding it in "Next". */
  skipLabel?: string;
  onSkip?: () => void;
  onBack?: () => void;
}

export function OnboardingScaffold({
  eyebrow,
  title,
  titleAlign = 'leading',
  message,
  detail,
  hero,
  children,
  footnote,
  step,
  primaryLabel,
  primaryEnabled = true,
  onPrimary,
  secondaryLabel,
  onSecondary,
  skipLabel,
  onSkip,
  onBack,
}: OnboardingScaffoldProps): React.ReactElement {
  const theme = useHopTheme();
  const layout = useHopScreenLayout();
  const centred = titleAlign === 'center';

  return (
    <View style={[styles.root, { backgroundColor: theme.color.backgroundPrimary }]}>
      <ScrollView
        style={styles.scroll}
        contentContainerStyle={[
          styles.scrollContent,
          { paddingHorizontal: layout.pagePadding, paddingBottom: theme.spacing.l },
        ]}
      >
        <View style={layout.column}>
          {onBack || skipLabel ? (
            <View style={styles.topRow}>
              {onBack ? <OnboardingBackButton onPress={onBack} /> : <View />}
              {skipLabel ? (
                <OnboardingTextButton label={skipLabel} onPress={onSkip} align="end" />
              ) : null}
            </View>
          ) : null}

          {hero ? <View style={styles.hero}>{hero}</View> : null}

          <View style={centred ? styles.centred : undefined}>
            {eyebrow ? <OnboardingEyebrow text={eyebrow} /> : null}
            <HopText
              variant={centred ? 'hero' : 'parentLargeTitle'}
              accessibilityRole="header"
              style={[{ marginTop: theme.spacing.xs }, centred ? styles.centredText : null]}
            >
              {title}
            </HopText>
            {message ? (
              <HopText
                variant="parentBody"
                tone="secondary"
                style={[{ marginTop: theme.spacing.s }, centred ? styles.centredText : null]}
              >
                {message}
              </HopText>
            ) : null}
            {detail ? (
              <HopText
                variant="parentCallout"
                tone="secondary"
                style={[{ marginTop: theme.spacing.m }, centred ? styles.centredText : null]}
              >
                {detail}
              </HopText>
            ) : null}
          </View>

          {children ? (
            <View style={{ marginTop: theme.spacing.xl }}>{children}</View>
          ) : null}
        </View>
      </ScrollView>

      <View
        style={[
          styles.footer,
          layout.column,
          { paddingHorizontal: layout.pagePadding, paddingBottom: theme.spacing.xl },
        ]}
      >
        {footnote ? (
          <HopText
            variant="parentCaption"
            tone="secondary"
            style={[styles.centredText, { paddingBottom: theme.spacing.m }]}
          >
            {footnote}
          </HopText>
        ) : null}
        <OnboardingStepDots step={step} />
        <HopButton
          label={primaryLabel}
          onPress={onPrimary}
          disabled={!primaryEnabled}
          style={{ ...styles.cta, marginTop: theme.spacing.l }}
        />
        {secondaryLabel ? (
          <OnboardingTextButton label={secondaryLabel} onPress={onSecondary} />
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  scroll: { flex: 1 },
  scrollContent: { flexGrow: 1, alignItems: 'stretch' },
  topRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    minHeight: 44,
  },
  back: { justifyContent: 'center', alignItems: 'flex-start' },
  hero: { alignItems: 'center', justifyContent: 'center', flexGrow: 1 },
  centred: { alignItems: 'center' },
  centredText: { textAlign: 'center' },
  eyebrow: { textTransform: 'uppercase' },
  dots: { flexDirection: 'row', gap: 8, alignItems: 'center', justifyContent: 'center' },
  dot: { height: 8, borderRadius: 4 },
  // 56pt is the caregiver primary-button height every render draws.
  cta: { alignSelf: 'stretch', minHeight: 56 },
  textButton: { justifyContent: 'center' },
  footer: { alignSelf: 'center' },
});
