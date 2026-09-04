import { easeInOutSine } from '../animation/easing';
import type { Rng } from '../animation/random';
import type { HermesOwletPhase } from '../state/HermesOwletState';
import {
  canRunRandomMicro,
  MicroAnimationController,
  type MicroAnimation,
} from './MicroAnimationController';

export interface IdleUpdate {
  phase: HermesOwletPhase;
  /** Peak float displacement in user units; 0 disables floating. */
  amplitude: number;
  reducedMotion: boolean;
  rng: Rng;
  micro: MicroAnimationController;
}

/** Weighted idle repertoire, straight from the brief. */
const IDLE_MICROS: readonly MicroAnimation[] = [
  'lookLeft',
  'lookRight',
  'doubleBlink',
  'curiousTilt',
  'tinyNod',
  'sparkle',
];
const IDLE_WEIGHTS: readonly number[] = [20, 20, 25, 15, 10, 10];

/**
 * Breathing, the slow head micro-tilt, the crest's secondary motion and the
 * scheduler for random idle behaviour. Everything here is deliberately smaller
 * than the eye moves — the character should read as alive, not busy.
 */
export class IdleController {
  /** Vertical float, in user units (negative is up). */
  floatY = 0;
  /** Slow micro-tilt in degrees, well inside the +/-4 normal range. */
  microTilt = 0;
  /** Crest follow-through, in degrees. */
  tuftAngle = 0;

  private floatPhase = 0;
  private floatPeriod = 4.2;
  private tiltPhase = 0;
  private nextMicroIn = 6;
  private lastFloatY = 0;
  private tuftVelocity = 0;

  update(dt: number, opts: IdleUpdate): void {
    if (opts.reducedMotion || opts.amplitude <= 0) {
      this.floatY = 0;
      this.microTilt = 0;
      this.tuftAngle *= Math.pow(0.02, dt);
      return;
    }

    // Breathing: one smooth 0 -> -amplitude -> 0 cycle over 3.5-5s.
    this.floatPhase += dt / this.floatPeriod;
    if (this.floatPhase >= 1) {
      this.floatPhase -= 1;
      this.floatPeriod = opts.rng.range(3.5, 5);
    }
    this.floatY = -opts.amplitude * easeInOutSine((1 - Math.cos(this.floatPhase * Math.PI * 2)) / 2);

    this.tiltPhase += dt;
    this.microTilt = Math.sin(this.tiltPhase * 0.23) * 0.9;

    // The crest lags the head by a frame or two: 1-2px of secondary motion.
    const velocity = (this.floatY - this.lastFloatY) / Math.max(dt, 1e-4);
    this.lastFloatY = this.floatY;
    this.tuftVelocity += (velocity * 0.06 - this.tuftVelocity) * Math.min(1, dt * 9);
    this.tuftAngle = Math.max(-2, Math.min(2, -this.tuftVelocity));

    // Random idle behaviour, one at a time.
    this.nextMicroIn -= dt;
    if (this.nextMicroIn <= 0) {
      this.nextMicroIn = opts.rng.range(4, 12);
      if (canRunRandomMicro(opts.phase) && !opts.micro.active) {
        opts.micro.play(opts.rng.weighted(IDLE_MICROS, IDLE_WEIGHTS));
      }
    }
  }

  reset(): void {
    this.floatY = 0;
    this.microTilt = 0;
    this.tuftAngle = 0;
    this.tuftVelocity = 0;
    this.lastFloatY = 0;
  }
}
