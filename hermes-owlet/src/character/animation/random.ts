/**
 * Deterministic-by-default randomness. A seeded generator keeps the simulator
 * and any visual regression run reproducible; pass no seed for real sessions.
 */
export interface Rng {
  next(): number;
  range(min: number, max: number): number;
  pick<T>(items: readonly T[]): T;
  /** Weighted pick. `weights` need not sum to 1. */
  weighted<T>(items: readonly T[], weights: readonly number[]): T;
  chance(p: number): boolean;
}

export const createRng = (seed?: number): Rng => {
  let s = (seed ?? (Math.random() * 0xffffffff)) >>> 0;
  const next = (): number => {
    // mulberry32
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const range = (min: number, max: number): number => min + next() * (max - min);
  return {
    next,
    range,
    pick: <T,>(items: readonly T[]): T => items[Math.floor(next() * items.length)]!,
    weighted: <T,>(items: readonly T[], weights: readonly number[]): T => {
      let total = 0;
      for (let i = 0; i < weights.length; i++) total += weights[i]!;
      let roll = next() * total;
      for (let i = 0; i < items.length; i++) {
        roll -= weights[i] ?? 0;
        if (roll <= 0) return items[i]!;
      }
      return items[items.length - 1]!;
    },
    chance: (p: number): boolean => next() < p,
  };
};
