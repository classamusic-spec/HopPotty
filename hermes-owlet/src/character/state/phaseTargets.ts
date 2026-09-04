import type { HermesEmotion, HermesOwletPhase } from './HermesOwletState';

/** Cyan pulse styles for the headphone rings. Never faster than ~1 Hz. */
export type PulseMode = 'off' | 'gentle' | 'alternating' | 'voice';

/**
 * The resting pose for each phase. The rig springs toward these; nothing here
 * is applied instantly. Values are absolute, not deltas, except where noted.
 */
export interface PhaseTarget {
  /** Base vertical offset in user units, before the idle float is added. */
  headY: number;
  /** Degrees; the idle micro-tilt is added on top. */
  headTilt: number;
  /** Degrees of side-feather lift. */
  wingLift: number;
  /** Multiplier on eye height. */
  eyeScaleY: number;
  /** Additive lid closure, 0..1. */
  lidNarrow: number;
  /** Multiplier on the navy pupil core. */
  pupilScale: number;
  /** Normalised gaze bias applied on top of drift. */
  gazeBiasX: number;
  gazeBiasY: number;
  /** 0..1 */
  headphoneGlow: number;
  pulse: PulseMode;
  /** Seconds per pulse cycle. */
  pulsePeriod: number;
  /** 0..1 */
  haloGlow: number;
  haloOpacity: number;
  /** Degrees of static halo tilt. */
  haloTilt: number;
  /** Seconds per revolution of the halo spark. Higher = calmer. */
  haloOrbitPeriod: number;
  /** 0..1 */
  starGlow: number;
  /** Seconds per forehead-star pulse; 0 disables the pulse. */
  starPulsePeriod: number;
  /** Amplitude of the idle float, in user units. 0 disables floating. */
  floatAmplitude: number;
  /** Blink and gaze drift run autonomously in these phases. */
  autonomous: boolean;
  /** Default emotion when the caller has not chosen one. */
  emotion: HermesEmotion;
}

const idle: PhaseTarget = {
  headY: 0,
  headTilt: 0,
  wingLift: 0,
  eyeScaleY: 1,
  lidNarrow: 0,
  pupilScale: 1,
  gazeBiasX: 0,
  gazeBiasY: 0,
  headphoneGlow: 0.72,
  pulse: 'off',
  pulsePeriod: 3,
  haloGlow: 0.5,
  haloOpacity: 1,
  haloTilt: 0,
  haloOrbitPeriod: 15,
  starGlow: 0.5,
  starPulsePeriod: 0,
  floatAmplitude: 2,
  autonomous: true,
  emotion: 'neutral',
};

export const PHASE_TARGETS: Record<HermesOwletPhase, PhaseTarget> = {
  idle,

  listening: {
    ...idle,
    headY: -2,
    wingLift: 5,
    eyeScaleY: 1.04,
    gazeBiasX: 0,
    gazeBiasY: 0.02,
    headphoneGlow: 0.95,
    pulse: 'gentle',
    pulsePeriod: 1.5,
    haloGlow: 0.75,
    starGlow: 0.55,
    emotion: 'curious',
  },

  thinking: {
    ...idle,
    headTilt: 3,
    eyeScaleY: 0.98,
    lidNarrow: 0.08,
    gazeBiasX: 0.12,
    gazeBiasY: -0.1,
    headphoneGlow: 0.62,
    pulse: 'off',
    haloGlow: 0.6,
    haloOrbitPeriod: 11,
    starGlow: 0.7,
    starPulsePeriod: 2,
    emotion: 'focused',
  },

  tool_use: {
    ...idle,
    headTilt: 1.5,
    eyeScaleY: 0.97,
    lidNarrow: 0.05,
    pupilScale: 0.95,
    gazeBiasX: 0.06,
    gazeBiasY: -0.04,
    headphoneGlow: 0.82,
    pulse: 'alternating',
    pulsePeriod: 1.1,
    haloGlow: 0.9,
    haloOrbitPeriod: 7,
    starGlow: 1,
    starPulsePeriod: 1.3,
    emotion: 'focused',
  },

  speaking: {
    ...idle,
    headY: -1,
    wingLift: 2,
    headphoneGlow: 0.74,
    pulse: 'voice',
    pulsePeriod: 1.4,
    haloGlow: 0.7,
    starGlow: 0.55,
    emotion: 'neutral',
  },

  success: {
    ...idle,
    headY: -3,
    wingLift: 7,
    eyeScaleY: 0.96,
    headphoneGlow: 0.92,
    pulse: 'gentle',
    pulsePeriod: 1.2,
    haloGlow: 1,
    starGlow: 1,
    emotion: 'happy',
  },

  interrupted: {
    ...idle,
    headY: 2,
    headTilt: -2,
    wingLift: 3,
    eyeScaleY: 1.08,
    headphoneGlow: 0.85,
    pulse: 'gentle',
    pulsePeriod: 1.4,
    haloGlow: 0.7,
    starGlow: 0.5,
    emotion: 'curious',
  },

  error: {
    ...idle,
    headY: 2,
    headTilt: -1.5,
    wingLift: -2,
    eyeScaleY: 0.94,
    lidNarrow: 0.22,
    gazeBiasY: 0.16,
    headphoneGlow: 0.16,
    pulse: 'off',
    haloGlow: 0.22,
    haloOpacity: 0.75,
    haloTilt: -7,
    haloOrbitPeriod: 22,
    starGlow: 0.12,
    emotion: 'concerned',
  },

  offline: {
    ...idle,
    headY: 3,
    headTilt: 0,
    wingLift: -3,
    lidNarrow: 0.85,
    headphoneGlow: 0,
    pulse: 'off',
    haloGlow: 0,
    haloOpacity: 0.3,
    haloOrbitPeriod: 30,
    starGlow: 0.06,
    floatAmplitude: 1.2,
    autonomous: false,
    emotion: 'neutral',
  },

  waking: {
    ...idle,
    headY: -1,
    headphoneGlow: 0.5,
    haloGlow: 0.5,
    haloOpacity: 1,
    starGlow: 0.5,
    autonomous: false,
    emotion: 'neutral',
  },
};

/** Default cross-fade for a phase change, in seconds. */
export const PHASE_TRANSITION_SECONDS = 0.26;

/** Phases whose reaction must be felt at once rather than eased into. */
export const IMMEDIATE_PHASES: ReadonlySet<HermesOwletPhase> = new Set([
  'interrupted',
  'offline',
]);
