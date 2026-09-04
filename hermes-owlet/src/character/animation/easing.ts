/** Small, allocation-free easing and interpolation helpers. */

export const clamp = (v: number, lo: number, hi: number): number =>
  v < lo ? lo : v > hi ? hi : v;

export const clamp01 = (v: number): number => clamp(v, 0, 1);

export const lerp = (a: number, b: number, t: number): number => a + (b - a) * t;

/**
 * Frame-rate independent exponential approach. `smoothing` is the fraction of
 * the remaining distance still left after one second, so the same call behaves
 * identically at 30, 60 or 120 Hz.
 */
export const damp = (current: number, target: number, smoothing: number, dt: number): number =>
  lerp(target, current, Math.pow(smoothing, dt));

/** Move `current` toward `target` by at most `maxDelta`. */
export const approach = (current: number, target: number, maxDelta: number): number => {
  const d = target - current;
  if (Math.abs(d) <= maxDelta) return target;
  return current + Math.sign(d) * maxDelta;
};

export const easeInOutSine = (t: number): number => -(Math.cos(Math.PI * t) - 1) / 2;
export const easeOutCubic = (t: number): number => 1 - Math.pow(1 - t, 3);
export const easeInCubic = (t: number): number => t * t * t;
export const easeOutQuad = (t: number): number => 1 - (1 - t) * (1 - t);
export const easeInOutCubic = (t: number): number =>
  t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;

/** Soft overshoot used for the success bounce. Peaks around t = 0.4. */
export const easeOutBack = (t: number): number => {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
};

/** 0 -> 1 -> 0, smooth at both ends. Used for one-shot pulses. */
export const pulse = (t: number): number => Math.sin(clamp01(t) * Math.PI);

/** Round to `places` decimals, for stable DOM attribute strings. */
export const round = (v: number, places = 2): number => {
  const f = places === 2 ? 100 : Math.pow(10, places);
  return Math.round(v * f) / f;
};
