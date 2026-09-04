import type { HermesEmotion } from './HermesOwletState';

/**
 * Expression presets modify existing face layers — there is no separate SVG per
 * expression. Every field is a small offset applied on top of the phase pose.
 */
export interface ExpressionPose {
  /** Additive lid closure, 0..1. Positive narrows the eye. */
  lidNarrow: number;
  /** Multiplier applied to eye height. 1 = neutral. */
  eyeScaleY: number;
  /** How much of a happy lower-lid curve to show, 0..1. */
  eyeCurve: number;
  /** Brow visibility, 0..1. Neutral keeps brows invisible so the locked
   *  silhouette is untouched. */
  browOpacity: number;
  /** Degrees. Positive angles the inner ends of the brows up. */
  browAngle: number;
  /** User units. Negative raises the brows. */
  browY: number;
  /** Additive gaze bias, in normalised gaze units. */
  gazeBiasY: number;
}

const base: ExpressionPose = {
  lidNarrow: 0,
  eyeScaleY: 1,
  eyeCurve: 0,
  browOpacity: 0,
  browAngle: 0,
  browY: 0,
  gazeBiasY: 0,
};

export const EXPRESSIONS: Record<HermesEmotion | 'surprised', ExpressionPose> = {
  neutral: { ...base },
  happy: { ...base, eyeCurve: 1, lidNarrow: 0.16, browOpacity: 0.5, browAngle: -4, browY: -3 },
  curious: { ...base, eyeScaleY: 1.03, browOpacity: 0.55, browAngle: 7, browY: -4 },
  focused: { ...base, lidNarrow: 0.14, eyeScaleY: 0.97, browOpacity: 0.8, browAngle: -6, browY: 2 },
  surprised: { ...base, eyeScaleY: 1.06, browOpacity: 0.6, browAngle: 2, browY: -7 },
  concerned: {
    ...base,
    lidNarrow: 0.2,
    eyeScaleY: 0.98,
    browOpacity: 0.9,
    browAngle: 12,
    browY: -2,
    gazeBiasY: 0.18,
  },
};

export type ExpressionName = keyof typeof EXPRESSIONS;
