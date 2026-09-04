import { clamp01, damp } from '../animation/easing';
import { createSpring, snapSpring, stepSpring } from '../animation/springs';
import { BEAK_MAX_DROP } from '../svg/geometry';
import { BEAK_SHAPES, beakShapeForLevel, type BeakShape } from '../state/HermesOwletState';

/**
 * Speech drives the beak and nothing else on the face — this is an owl, so
 * there is no mouth to animate. Raw TTS amplitude is far too jittery to use
 * directly, so it is smoothed with a fast attack and a slow release, quantised
 * to the four locked beak shapes, then sprung so the articulation has weight.
 */

/** Fraction of the gap still left after one second. Derived from the
 *  per-frame lerp factors in the brief (0.45 attack, 0.14 release at 60 Hz). */
const ATTACK_SMOOTHING = Math.pow(1 - 0.45, 60);
const RELEASE_SMOOTHING = Math.pow(1 - 0.14, 60);

export class BeakController {
  /** Smoothed amplitude, 0..1. */
  level = 0;
  /** Quantised shape currently being held. */
  shape: BeakShape = 'BEAK_CLOSED';
  /** Beak opening in user units. */
  drop = 0;

  private raw = 0;
  private readonly spring = createSpring(0, 21, 1.05);

  /** Feed a raw amplitude sample, 0..1. Safe to call at audio rate. */
  setLevel(level: number): void {
    this.raw = clamp01(Number.isFinite(level) ? level : 0);
  }

  /** Interruption: stop the beak dead and close it. */
  reset(): void {
    this.raw = 0;
    this.level = 0;
    this.shape = 'BEAK_CLOSED';
    this.drop = 0;
    snapSpring(this.spring, 0);
  }

  update(dt: number, speaking: boolean): number {
    const target = speaking ? this.raw : 0;
    const smoothing = target > this.level ? ATTACK_SMOOTHING : RELEASE_SMOOTHING;
    this.level = damp(this.level, target, smoothing, dt);

    this.shape = beakShapeForLevel(this.level);
    this.spring.target = BEAK_SHAPES[this.shape] * BEAK_MAX_DROP;
    this.drop = stepSpring(this.spring, dt);
    if (this.drop < 0) this.drop = 0;
    return this.drop;
  }
}
