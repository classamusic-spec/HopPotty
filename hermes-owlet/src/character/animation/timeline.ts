import { clamp01 } from './easing';

/**
 * A tiny one-shot timeline. Micro-animations (wake, success bounce, interrupt
 * recoil) are short, deterministic and non-looping, so they do not need a
 * general animation library — just a clock and a normalised progress value.
 */
export interface Timeline {
  /** Total duration in seconds. */
  duration: number;
  /** Elapsed seconds; equals duration when finished. */
  elapsed: number;
  active: boolean;
}

export const createTimeline = (): Timeline => ({ duration: 0, elapsed: 0, active: false });

export const startTimeline = (t: Timeline, durationSeconds: number): void => {
  t.duration = Math.max(durationSeconds, 1e-4);
  t.elapsed = 0;
  t.active = true;
};

export const stopTimeline = (t: Timeline): void => {
  t.active = false;
  t.elapsed = t.duration;
};

/** Advance and return normalised progress in 0..1. Returns 1 when idle. */
export const stepTimeline = (t: Timeline, dt: number): number => {
  if (!t.active) return 1;
  t.elapsed += dt;
  if (t.elapsed >= t.duration) {
    t.elapsed = t.duration;
    t.active = false;
    return 1;
  }
  return clamp01(t.elapsed / t.duration);
};

export const timelineProgress = (t: Timeline): number =>
  t.active ? clamp01(t.elapsed / t.duration) : 1;
