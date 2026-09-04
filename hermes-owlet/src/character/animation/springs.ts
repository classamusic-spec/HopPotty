import { clamp } from './easing';

/**
 * A semi-implicit damped spring, integrated in place. Medium stiffness and high
 * damping give the pupils and head their soft, non-snappy settle without ever
 * ringing. Value objects are created once and mutated, so the rAF loop never
 * allocates.
 */
export interface Spring {
  value: number;
  velocity: number;
  target: number;
  /** Angular frequency. Higher = faster. */
  stiffness: number;
  /** 1 = critically damped. Above 1 never overshoots. */
  damping: number;
}

export const createSpring = (
  value = 0,
  stiffness = 12,
  damping = 1.1,
): Spring => ({ value, velocity: 0, target: value, stiffness, damping });

/** Maximum step taken in one integration slice, in seconds. */
const MAX_STEP = 1 / 60;

export const stepSpring = (s: Spring, dt: number): number => {
  let remaining = clamp(dt, 0, 0.1);
  const k = s.stiffness * s.stiffness;
  const c = 2 * s.damping * s.stiffness;
  while (remaining > 0) {
    const h = remaining > MAX_STEP ? MAX_STEP : remaining;
    remaining -= h;
    const accel = k * (s.target - s.value) - c * s.velocity;
    s.velocity += accel * h;
    s.value += s.velocity * h;
  }
  return s.value;
};

export const snapSpring = (s: Spring, value: number): void => {
  s.value = value;
  s.target = value;
  s.velocity = 0;
};

export const SPRING_PRESETS = {
  /** Pupils: soft, never overshoots, never snaps. */
  gaze: { stiffness: 11, damping: 1.25 },
  /** Head float and tilt: slow and weighty. */
  head: { stiffness: 7, damping: 1.15 },
  /** Reactions that must be felt immediately (interrupt recoil). */
  reaction: { stiffness: 26, damping: 0.92 },
  /** Glows and opacities: fast enough to feel responsive, slow enough to be calm. */
  glow: { stiffness: 14, damping: 1.4 },
  /** Wings: light, with a touch of follow-through. */
  wing: { stiffness: 10, damping: 0.95 },
} as const;
