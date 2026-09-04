/**
 * The character's high-level state. This is the contract between the Hermes
 * agent and the animated head. Everything here changes at human speed — never
 * at 60 Hz. Per-frame interpolation lives in the rig, not in React.
 */

export type HermesOwletPhase =
  | 'offline'
  | 'waking'
  | 'idle'
  | 'listening'
  | 'thinking'
  | 'tool_use'
  | 'speaking'
  | 'success'
  | 'interrupted'
  | 'error';

export type HermesEmotion = 'neutral' | 'happy' | 'curious' | 'focused' | 'concerned';

/**
 * Composable secondary values. The phase says what Hermes is doing; these say
 * how the face is currently posed. Anything the rig drives autonomously (blink,
 * gaze drift, halo) is reported here for debugging, but written by the rig.
 */
export interface HermesOwletState {
  phase: HermesOwletPhase;
  emotion: HermesEmotion;

  /** -1 (hard left) .. 1 (hard right). */
  gazeX: number;
  /** -1 (up) .. 1 (down). */
  gazeY: number;

  /** 0 = open, 1 = fully closed. */
  blinkAmount: number;

  /** Degrees. Normal range +/-4, reactions up to +/-7. */
  headTilt: number;

  /** User units; negative is up. */
  headY: number;

  /** Orbit angle of the halo spark, in degrees. */
  haloRotation: number;
  /** 0..1 */
  haloGlow: number;
  /** 0..1 */
  headphoneGlow: number;
  /** Degrees of lift on the side feathers. */
  wingLift: number;

  /** Smoothed TTS amplitude, 0..1. */
  speechLevel: number;
  /** 0 = closed, 1 = fully open. Derived from speechLevel. */
  beakOpen: number;

  activeTool?: string;
}

/** Discrete beak shapes the speech mapper quantises to. */
export const BEAK_SHAPES = {
  BEAK_CLOSED: 0,
  BEAK_SMALL: 0.28,
  BEAK_MEDIUM: 0.62,
  BEAK_OPEN: 1,
} as const;

export type BeakShape = keyof typeof BEAK_SHAPES;

/** Amplitude bands from the brief, mapped to the four locked beak shapes. */
export const beakShapeForLevel = (level: number): BeakShape => {
  if (level < 0.15) return 'BEAK_CLOSED';
  if (level < 0.35) return 'BEAK_SMALL';
  if (level < 0.65) return 'BEAK_MEDIUM';
  return 'BEAK_OPEN';
};

export const createInitialState = (
  phase: HermesOwletPhase = 'offline',
): HermesOwletState => ({
  phase,
  emotion: 'neutral',
  gazeX: 0,
  gazeY: 0,
  blinkAmount: 0,
  headTilt: 0,
  headY: 0,
  haloRotation: 0,
  haloGlow: 0.3,
  headphoneGlow: 0,
  wingLift: 0,
  speechLevel: 0,
  beakOpen: 0,
});

/**
 * Explicit priority. Hermes events overlap constantly — a tool call while
 * speech is playing, a run starting while the mic is still hot — and the
 * character must not flicker between them. Highest wins.
 */
export const PHASE_PRIORITY: Record<HermesOwletPhase, number> = {
  error: 100,
  interrupted: 90,
  offline: 80,
  speaking: 70,
  tool_use: 60,
  listening: 50,
  thinking: 40,
  success: 30,
  waking: 20,
  idle: 10,
};

export const higherPriorityPhase = (
  a: HermesOwletPhase,
  b: HermesOwletPhase,
): HermesOwletPhase => (PHASE_PRIORITY[a] >= PHASE_PRIORITY[b] ? a : b);

export const PHASE_LABELS: Record<HermesOwletPhase, string> = {
  offline: 'Offline',
  waking: 'Waking',
  idle: 'Idle',
  listening: 'Listening',
  thinking: 'Thinking',
  tool_use: 'Tool use',
  speaking: 'Speaking',
  success: 'Success',
  interrupted: 'Interrupted',
  error: 'Error',
};
