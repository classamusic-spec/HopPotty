import React, { useCallback, useEffect, useRef, useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  View,
  useWindowDimensions,
  type AccessibilityActionEvent,
} from 'react-native';
import Svg, { Circle } from 'react-native-svg';

import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import type { ParentGateReason } from '../../navigation/types';

/**
 * 37 — the grown-up gate.
 *
 * The reference is `Art/render/screens/37-parent-gate.png` (`parentGate()` in
 * `Scripts/screens/parent-extra.js`).
 *
 * Hold, then a sum. Either half alone is beatable by the person it is meant to
 * stop — a three-year-old holds a button down by accident, a six-year-old reads
 * "13 + 24" off the screen — so the gate asks for sustained intent *and*
 * arithmetic. It is not a security boundary and never pretends to be one.
 *
 * **There is no lock-out.** Three wrong answers get a different sum, not a
 * locked screen: locking a caregiver out of Restore Screen Access would be the
 * worst possible failure mode this app has.
 */

/** `ParentGateChallenge.holdDuration` — long enough that a stray tap misses it. */
const HOLD_DURATION_MS = 1200;
const HOLD_STEPS = 30;

/** `ParentGateChallenge.attemptsPerChallenge`. A new sum, never a lockout. */
export const ATTEMPTS_PER_CHALLENGE = 3;

const RING = 52;
const RING_RADIUS = 22;
const RING_STROKE = 6;
const RING_CIRCUMFERENCE = 2 * Math.PI * RING_RADIUS;

const KEY_HEIGHT = 46;
const KEY_MAX_WIDTH = 111;
const KEY_GAP = 8;

/** The measure a caregiver's paragraph is capped at on a wide screen. */
const READING_COLUMN = 560;

/** Both addends are two digits and the sum stays under 100. */
export interface ParentGateChallenge {
  readonly first: number;
  readonly second: number;
}

/**
 * Why a grown-up is being asked to prove they are one.
 *
 * The gate says what is on the other side of it before it asks for anything. A
 * challenge with no stated reason is a challenge a caregiver cannot judge.
 */
const REASON_SENTENCES: Readonly<Record<ParentGateReason, string>> = {
  screenTimeSettings: 'Next is Screen Time settings.',
  purchase: 'Next is a purchase.',
  restorePurchase: 'Next is restoring a purchase.',
  deleteData: "Next is deleting a child's data, which cannot be undone.",
  exportData: 'Next is exporting your data.',
  profileSettings: "Next is your child's profile settings.",
  restoreScreenAccess: 'Next is restoring screen access, which lifts any pause running right now.',
  leaveChildMode: 'Next is leaving Child Mode.',
};

export interface ParentGateScreenProps {
  reason: ParentGateReason;
  /** The sum being asked. The host mints it, so the screen holds no randomness. */
  challenge: ParentGateChallenge;
  onPass?: () => void;
  onCancel?: () => void;
  /** Three wrong answers. The host supplies a different sum; nothing locks. */
  onRequestNewChallenge?: () => void;
  /**
   * Start at the sum rather than the hold.
   *
   * A hold is a gesture some people cannot perform and VoiceOver cannot
   * describe, so when either assistive technology is on the challenge begins at
   * the arithmetic — which is still an adult-only step, and is the half that
   * actually does the work.
   */
  skipsHold?: boolean;
}

type Phase = 'holding' | 'answering' | 'retrying';

export function ParentGateScreen({
  reason,
  challenge,
  onPass,
  onCancel,
  onRequestNewChallenge,
  skipsHold = false,
}: ParentGateScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const { width } = useWindowDimensions();
  const isRegular = width >= 768;

  const [phase, setPhase] = useState<Phase>(skipsHold ? 'answering' : 'holding');
  const [holdProgress, setHoldProgress] = useState(skipsHold ? 1 : 0);
  const [typed, setTyped] = useState('');
  const [attemptsLeft, setAttemptsLeft] = useState(ATTEMPTS_PER_CHALLENGE);
  const holdTimer = useRef<ReturnType<typeof setInterval> | null>(null);

  const answer = challenge.first + challenge.second;
  const held = phase !== 'holding';

  // A fresh sum means a fresh entry: the caregiver is answering a new question.
  useEffect(() => {
    setTyped('');
  }, [challenge.first, challenge.second]);

  const stopHold = useCallback(() => {
    if (holdTimer.current) {
      clearInterval(holdTimer.current);
      holdTimer.current = null;
    }
  }, []);

  useEffect(() => stopHold, [stopHold]);

  const completeHold = useCallback(() => {
    stopHold();
    setHoldProgress(1);
    setPhase('answering');
  }, [stopHold]);

  const beginHold = useCallback(() => {
    if (held || holdTimer.current) return;
    let step = 0;
    holdTimer.current = setInterval(() => {
      step += 1;
      setHoldProgress(step / HOLD_STEPS);
      if (step >= HOLD_STEPS) completeHold();
    }, HOLD_DURATION_MS / HOLD_STEPS);
  }, [held, completeHold]);

  const cancelHold = useCallback(() => {
    if (held) return;
    stopHold();
    setHoldProgress(0);
  }, [held, stopHold]);

  const submit = useCallback(
    (entry: string) => {
      if (Number(entry) === answer) {
        onPass?.();
        return;
      }
      setTyped('');
      setPhase('retrying');
      const left = attemptsLeft - 1;
      if (left <= 0) {
        // A different sum rather than a lockout. See `attemptsPerChallenge`.
        setAttemptsLeft(ATTEMPTS_PER_CHALLENGE);
        onRequestNewChallenge?.();
      } else {
        setAttemptsLeft(left);
      }
    },
    [answer, attemptsLeft, onPass, onRequestNewChallenge],
  );

  const press = useCallback(
    (digit: string) => {
      const entry = (typed + digit).slice(0, 3);
      setTyped(entry);
      // The sum is always two digits, so the answer is complete the moment it
      // is as long as the answer — the same way a passcode field behaves.
      if (entry.length === String(answer).length) submit(entry);
    },
    [typed, answer, submit],
  );

  const backspace = useCallback(() => setTyped((entry) => entry.slice(0, -1)), []);

  const onHoldAccessibilityAction = useCallback(
    (event: AccessibilityActionEvent) => {
      if (event.nativeEvent.actionName === 'activate') completeHold();
    },
    [completeHold],
  );

  return (
    <View style={[styles.root, { backgroundColor: theme.color.backgroundPrimary }]}>
      <View
        style={[
          styles.bar,
          { paddingHorizontal: theme.spacing.xl, minHeight: theme.hitTarget.parentMinimum },
        ]}
      >
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Cancel"
          onPress={onCancel}
          style={({ pressed }) => [
            styles.cancel,
            { minHeight: theme.hitTarget.parentMinimum, opacity: pressed ? 0.6 : 1 },
          ]}
        >
          <HopText variant="parentBody" tone="brand">
            Cancel
          </HopText>
        </Pressable>
        <HopText variant="parentTitle" accessibilityRole="header">
          Grown-ups only
        </HopText>
        <View style={styles.cancel} />
      </View>

      <ScrollView
        style={styles.flex}
        contentContainerStyle={[
          styles.body,
          {
            paddingHorizontal: theme.spacing.xl,
            paddingBottom: theme.spacing.l,
            maxWidth: isRegular ? READING_COLUMN : undefined,
            alignSelf: isRegular ? 'center' : 'stretch',
            width: '100%',
          },
        ]}
      >
        <HopText variant="parentBody" tone="secondary">
          Hold the button, then answer the question.
        </HopText>
        <HopText variant="parentCallout" tone="secondary" style={{ marginTop: theme.spacing.xs }}>
          {REASON_SENTENCES[reason]}
        </HopText>

        <Pressable
          accessibilityRole="button"
          accessibilityLabel={held ? 'Held' : 'Press and hold'}
          accessibilityHint="Keep your finger down until the ring fills."
          accessibilityState={{ disabled: held }}
          accessibilityActions={[{ name: 'activate' }]}
          onAccessibilityAction={onHoldAccessibilityAction}
          disabled={held}
          onPressIn={beginHold}
          onPressOut={cancelHold}
          style={[
            styles.holdCard,
            {
              marginTop: theme.spacing.l,
              backgroundColor: theme.color.surface,
              borderRadius: theme.radius.l,
              padding: theme.spacing.m,
              gap: theme.spacing.l,
              shadowColor: theme.color.shadow,
              shadowOpacity: theme.isDark ? 0.34 : 0.07,
              shadowRadius: 10,
              shadowOffset: { width: 0, height: 3 },
              elevation: 2,
            },
          ]}
        >
          <View style={styles.ring}>
            <Svg width={RING} height={RING}>
              <Circle
                cx={RING / 2}
                cy={RING / 2}
                r={RING_RADIUS}
                fill="none"
                stroke={theme.color.divider}
                strokeWidth={RING_STROKE}
              />
              <Circle
                cx={RING / 2}
                cy={RING / 2}
                r={RING_RADIUS}
                fill="none"
                stroke={theme.color.brandAction}
                strokeWidth={RING_STROKE}
                strokeLinecap="round"
                strokeDasharray={`${RING_CIRCUMFERENCE} ${RING_CIRCUMFERENCE}`}
                strokeDashoffset={RING_CIRCUMFERENCE * (1 - holdProgress)}
                transform={`rotate(-90 ${RING / 2} ${RING / 2})`}
              />
            </Svg>
            {held ? (
              <HopText
                variant="parentTitle"
                style={[styles.ringMark, { color: theme.color.brandAction }]}
              >
                ✓
              </HopText>
            ) : null}
          </View>
          <View style={styles.flex}>
            <HopText variant="parentCallout">{held ? 'Held' : 'Press and hold'}</HopText>
            <HopText variant="parentCaption" tone="secondary">
              Press and hold, one second.
            </HopText>
          </View>
        </Pressable>

        {held ? (
          <View style={{ paddingTop: theme.spacing.xl }}>
            <HopText variant="parentTitle" accessibilityRole="header">
              {`What is ${challenge.first} plus ${challenge.second}?`}
            </HopText>

            <View
              accessible
              accessibilityLabel={`Answer, ${typed === '' ? 'empty' : typed}`}
              style={[
                styles.answer,
                {
                  marginTop: theme.spacing.m,
                  backgroundColor: theme.color.surface,
                  borderRadius: theme.radius.m,
                  borderColor: theme.color.brandAction,
                  paddingHorizontal: theme.spacing.l,
                },
              ]}
            >
              <HopText variant="parentTitle">{typed}</HopText>
              <View style={[styles.caret, { backgroundColor: theme.color.brandAction }]} />
            </View>

            {phase === 'retrying' ? (
              <HopText
                variant="parentFootnote"
                accessibilityLiveRegion="polite"
                style={{ marginTop: theme.spacing.s, color: theme.color.warning }}
              >
                Not quite. Here is another one.
              </HopText>
            ) : null}

            <HopText
              variant="parentCaption"
              tone="secondary"
              style={{ marginTop: theme.spacing.s }}
            >
              Three tries, then Hop offers a different sum. There is no lock-out — Restore Screen
              Access must always be reachable.
            </HopText>
          </View>
        ) : null}
      </ScrollView>

      {held ? (
        <View
          style={[
            styles.tray,
            {
              backgroundColor: theme.isDark ? theme.color.surfaceSunken : theme.palette.sand100,
              paddingHorizontal: theme.spacing.s,
              paddingTop: theme.spacing.s,
              paddingBottom: theme.spacing.xl,
              gap: KEY_GAP,
            },
          ]}
        >
          {[
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ].map((row) => (
            <View key={row.join('')} style={[styles.keyRow, { gap: KEY_GAP }]}>
              {row.map((digit) => (
                <Key key={digit} label={digit} onPress={() => press(digit)} />
              ))}
            </View>
          ))}
          <View style={[styles.keyRow, { gap: KEY_GAP }]}>
            <View style={styles.keySlot} />
            <Key label="0" onPress={() => press('0')} />
            <Key label="⌫" accessibilityLabel="Delete" quiet onPress={backspace} />
          </View>
        </View>
      ) : null}
    </View>
  );
}

function Key({
  label,
  accessibilityLabel,
  quiet = false,
  onPress,
}: {
  label: string;
  accessibilityLabel?: string;
  quiet?: boolean;
  onPress: () => void;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel ?? label}
      onPress={onPress}
      style={({ pressed }) => [
        styles.key,
        {
          borderRadius: theme.radius.xs,
          backgroundColor: quiet ? 'transparent' : theme.color.surface,
          opacity: pressed ? 0.6 : 1,
        },
      ]}
    >
      <HopText variant="parentMetric">{label}</HopText>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  flex: { flex: 1 },
  bar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  cancel: { width: 80, justifyContent: 'center' },
  body: { alignSelf: 'stretch', flexGrow: 1 },
  holdCard: { flexDirection: 'row', alignItems: 'center' },
  ring: { width: RING, height: RING, alignItems: 'center', justifyContent: 'center' },
  ringMark: { position: 'absolute' },
  answer: { height: 56, flexDirection: 'row', alignItems: 'center', borderWidth: 1.5 },
  caret: { width: 2, height: 26, borderRadius: 1, marginLeft: 2 },
  tray: { alignSelf: 'stretch' },
  keyRow: { flexDirection: 'row', justifyContent: 'center' },
  keySlot: { flex: 1, maxWidth: KEY_MAX_WIDTH, height: KEY_HEIGHT },
  key: {
    flex: 1,
    maxWidth: KEY_MAX_WIDTH,
    height: KEY_HEIGHT,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
