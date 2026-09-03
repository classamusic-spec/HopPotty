import React from 'react';
import { ScrollView, StyleSheet, View, type StyleProp, type TextStyle } from 'react-native';

import { HopButton, HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';
import { ClockMark, IconTile, PlayMark } from './OnboardingMarks';
import {
  OnboardingEyebrow,
  OnboardingTextButton,
  restingShadow,
  useHopScreenLayout,
} from './OnboardingScaffold';

/**
 * 12 — the finish line of setup.
 *
 * The reference is `Art/render/screens/33-onboarding-first-pause-set.png`
 * (`firstPauseSet()` in `Scripts/screens/parent-extra.js`). It is the one
 * onboarding screen with no step dots and no eyebrow: setup is over, so the
 * indicator would be counting something that has stopped.
 *
 * It states what is actually armed — including the case where the caregiver
 * declined Screen Time. "Reminders are on. Apps are not paused." is a fact they
 * need, not a nag to go back and fix something.
 */

const MEDALLION = 214;
const HOP_SIZE = 226;

export interface ReadyScreenProps {
  /**
   * The schedule in one sentence, built by the host because plurals and
   * wall-clock times are locale work that belongs in one place. The render
   * reads: "Hop invites Maya about every 45 minutes, with a 2-minute heads-up.
   * Pauses last 3 minutes and stay quiet at nap and bedtime."
   */
  scheduleSummary: string;
  /** The caregiver declined Screen Time and HopPotty moved to gentle mode. */
  fellBackToGentle?: boolean;
  /** A test pause can only be offered when one could actually succeed. */
  canRunTestPause?: boolean;
  isWorking?: boolean;
  onRunTestPause?: () => void;
  onFinish?: () => void;
  onChangeSchedule?: () => void;
}

export function ReadyScreen({
  scheduleSummary,
  fellBackToGentle = false,
  canRunTestPause = true,
  isWorking = false,
  onRunTestPause,
  onFinish,
  onChangeSchedule,
}: ReadyScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const layout = useHopScreenLayout();
  const accent = theme.isDark ? theme.palette.hopGreenLight : theme.palette.hopGreenInk;

  return (
    <View style={[styles.root, { backgroundColor: theme.color.backgroundPrimary }]}>
      <ScrollView
        contentContainerStyle={[
          styles.scroll,
          { paddingHorizontal: layout.pagePadding, paddingTop: theme.spacing.xxxl },
        ]}
      >
        <View style={layout.column}>
          <View style={styles.stage}>
            <View
              style={[
                styles.disc,
                {
                  backgroundColor: theme.isDark
                    ? theme.color.surfaceElevated
                    : theme.palette.hopGreenSoft,
                },
              ]}
            />
            <HopCharacter
              size={HOP_SIZE}
              state="celebrate"
              accessibilityLabel="Hop is cheering"
            />
            <Sparkle style={styles.sparkleTopLeft} />
            <Sparkle style={styles.sparkleTopRight} />
            <Sparkle style={styles.sparkleLeft} />
            <Sparkle style={styles.sparkleRight} />
          </View>

          <HopText variant="hero" accessibilityRole="header" style={styles.centred}>
            You are all set
          </HopText>
          <HopText
            variant="parentBody"
            tone="secondary"
            style={[styles.centred, { marginTop: theme.spacing.s }]}
          >
            HopPotty is watching the clock now. Everything is editable in Settings.
          </HopText>

          <View
            style={[
              styles.schedule,
              {
                marginTop: theme.spacing.xl,
                borderRadius: theme.radius.l,
                padding: theme.spacing.l,
                gap: theme.spacing.m,
                backgroundColor: theme.isDark
                  ? theme.color.surfaceElevated
                  : theme.palette.hopGreenSoft,
              },
            ]}
          >
            <IconTile size={30} radius={15} background={theme.color.surface}>
              <ClockMark size={16} color={accent} />
            </IconTile>
            <View style={styles.flex}>
              <OnboardingEyebrow text="Your schedule" />
              <HopText
                variant="parentCallout"
                style={{
                  marginTop: theme.spacing.xxs,
                  color: theme.isDark ? theme.color.textPrimary : accent,
                }}
              >
                {scheduleSummary}
              </HopText>
            </View>
          </View>

          <View style={[styles.promise, { marginTop: theme.spacing.m, gap: theme.spacing.m }]}>
            <HopText
              variant="parentCallout"
              tone="secondary"
              accessibilityElementsHidden
              importantForAccessibility="no-hide-descendants"
            >
              ✓
            </HopText>
            <HopText variant="parentCaption" tone="secondary" style={styles.flex}>
              A pause always ends on its own timer. Screen access is never held back for a result.
            </HopText>
          </View>

          {fellBackToGentle ? (
            <HopText
              variant="parentFootnote"
              tone="secondary"
              style={{ marginTop: theme.spacing.m }}
            >
              Reminders are on. Apps are not paused.
            </HopText>
          ) : null}

          {canRunTestPause ? (
            <View
              style={[
                restingShadow(theme),
                {
                  marginTop: theme.spacing.xl,
                  backgroundColor: theme.color.surface,
                  borderRadius: theme.radius.l,
                  padding: theme.spacing.l,
                },
              ]}
            >
              <View style={[styles.promise, { gap: theme.spacing.m }]}>
                <IconTile
                  size={32}
                  radius={theme.radius.s}
                  background={
                    theme.isDark ? theme.color.surfaceSunken : theme.palette.pondBlueSoft
                  }
                >
                  <PlayMark size={15} color={theme.color.eventPee} />
                </IconTile>
                <View style={styles.flex}>
                  <HopText variant="parentHeadline">Try a Potty Pause</HopText>
                  <HopText
                    variant="parentCaption"
                    tone="secondary"
                    style={{ marginTop: theme.spacing.xs }}
                  >
                    This runs one pause right now so you can see exactly what your child sees. It
                    ends on its own.
                  </HopText>
                </View>
              </View>
              <HopButton
                label="Run a test pause"
                variant="secondary"
                disabled={isWorking}
                onPress={onRunTestPause}
                style={{ ...styles.stretch, marginTop: theme.spacing.m }}
              />
            </View>
          ) : null}
        </View>
      </ScrollView>

      <View
        style={[
          layout.column,
          styles.footer,
          { paddingHorizontal: layout.pagePadding, paddingBottom: theme.spacing.xl },
        ]}
      >
        <HopButton
          label="Go to HopPotty"
          disabled={isWorking}
          onPress={onFinish}
          style={styles.cta}
        />
        <OnboardingTextButton label="Change the schedule" onPress={onChangeSchedule} />
      </View>
    </View>
  );
}

/** A speck of light around Hop. Scenery, and hidden from assistive tech. */
function Sparkle({ style }: { style: StyleProp<TextStyle> }): React.ReactElement {
  const theme = useHopTheme();
  return (
    <HopText
      variant="parentCallout"
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      style={[style, { color: theme.palette.sunshine }]}
    >
      ★
    </HopText>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  flex: { flex: 1 },
  scroll: { flexGrow: 1 },
  centred: { textAlign: 'center' },
  stretch: { alignSelf: 'stretch' },
  stage: { alignItems: 'center', justifyContent: 'center', minHeight: HOP_SIZE },
  disc: {
    position: 'absolute',
    top: 22,
    width: MEDALLION,
    height: MEDALLION,
    borderRadius: MEDALLION / 2,
  },
  sparkleTopLeft: { position: 'absolute', left: 10, top: 38 },
  sparkleTopRight: { position: 'absolute', right: 12, top: 20 },
  sparkleLeft: { position: 'absolute', left: 32, top: 162 },
  sparkleRight: { position: 'absolute', right: 8, top: 138 },
  promise: { flexDirection: 'row', alignItems: 'flex-start' },
  schedule: { flexDirection: 'row', alignItems: 'flex-start' },
  footer: { alignSelf: 'center' },
  // 56pt is the caregiver primary-button height every render draws.
  cta: { alignSelf: 'stretch', minHeight: 56 },
});
