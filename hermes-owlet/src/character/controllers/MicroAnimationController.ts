import { clamp01, easeOutBack, easeOutCubic, pulse } from '../animation/easing';
import type { HermesOwletPhase } from '../state/HermesOwletState';

export type MicroAnimation =
  | 'doubleBlink'
  | 'curiousTilt'
  | 'tinyNod'
  | 'lookLeft'
  | 'lookRight'
  | 'sparkle'
  | 'wake'
  | 'sleep'
  | 'successBounce'
  | 'interruptReaction';

/** Additive offsets a micro-animation contributes on top of the phase pose. */
export interface MicroOffsets {
  headY: number;
  headTilt: number;
  gazeX: number;
  gazeY: number;
  wingLift: number;
  eyeWiden: number;
  haloFlash: number;
  starFlash: number;
  sparkFlash: number;
  /** Multiplies the whole rig's opacity ramp during wake/sleep. */
  wakeProgress: number;
}

const DURATIONS: Record<MicroAnimation, number> = {
  doubleBlink: 0.6,
  curiousTilt: 1.5,
  tinyNod: 0.8,
  lookLeft: 1.8,
  lookRight: 1.8,
  sparkle: 1,
  wake: 0.9,
  sleep: 0.7,
  successBounce: 0.7,
  interruptReaction: 0.36,
};

/** Micro-animations must not fire on their own while these phases are active. */
const NO_RANDOM_PHASES: ReadonlySet<HermesOwletPhase> = new Set([
  'error',
  'interrupted',
  'tool_use',
  'offline',
  'waking',
]);

export const canRunRandomMicro = (phase: HermesOwletPhase): boolean =>
  !NO_RANDOM_PHASES.has(phase);

const zero = (o: MicroOffsets): void => {
  o.headY = 0;
  o.headTilt = 0;
  o.gazeX = 0;
  o.gazeY = 0;
  o.wingLift = 0;
  o.eyeWiden = 0;
  o.haloFlash = 0;
  o.starFlash = 0;
  o.sparkFlash = 0;
  o.wakeProgress = 1;
};

/**
 * Named one-shots. Only one large animation runs at a time — a second request
 * replaces the first rather than layering, so the head can never be pulled in
 * two directions at once.
 */
export class MicroAnimationController {
  readonly offsets: MicroOffsets = {
    headY: 0,
    headTilt: 0,
    gazeX: 0,
    gazeY: 0,
    wingLift: 0,
    eyeWiden: 0,
    haloFlash: 0,
    starFlash: 0,
    sparkFlash: 0,
    wakeProgress: 1,
  };

  private current: MicroAnimation | null = null;
  private elapsed = 0;
  private duration = 0;

  /** Callback the rig wires to the blink controller. */
  onBlinkRequest: ((double: boolean) => void) | null = null;

  get active(): MicroAnimation | null {
    return this.current;
  }

  play(name: MicroAnimation): void {
    this.current = name;
    this.elapsed = 0;
    this.duration = DURATIONS[name];
    if (name === 'doubleBlink') this.onBlinkRequest?.(true);
    if (name === 'sleep' || name === 'wake') this.offsets.wakeProgress = name === 'wake' ? 0 : 1;
  }

  stop(): void {
    this.current = null;
    zero(this.offsets);
  }

  update(dt: number): MicroOffsets {
    const o = this.offsets;
    if (!this.current) {
      zero(o);
      return o;
    }

    this.elapsed += dt;
    const t = clamp01(this.elapsed / this.duration);
    zero(o);

    switch (this.current) {
      case 'doubleBlink':
        break;

      case 'curiousTilt': {
        const w = pulse(t);
        o.headTilt = w * 4;
        o.gazeX = w * 0.1;
        o.gazeY = -w * 0.05;
        break;
      }

      case 'tinyNod': {
        o.headY = Math.sin(t * Math.PI * 2) * 1.8;
        o.headTilt = Math.sin(t * Math.PI * 2) * 0.6;
        break;
      }

      case 'lookLeft':
      case 'lookRight': {
        const dir = this.current === 'lookLeft' ? -1 : 1;
        const w = pulse(Math.min(t * 1.15, 1));
        o.gazeX = dir * w * 0.28;
        o.headTilt = dir * w * 1.2;
        break;
      }

      case 'sparkle': {
        const w = pulse(t);
        o.sparkFlash = w;
        o.haloFlash = w * 0.2;
        break;
      }

      case 'wake': {
        o.wakeProgress = easeOutCubic(t);
        o.headY = -2.5 * easeOutBack(t);
        o.haloFlash = pulse(t) * 0.35;
        o.starFlash = clamp01(t * 1.6);
        o.eyeWiden = pulse(t) * 0.25;
        break;
      }

      case 'sleep': {
        o.wakeProgress = 1 - easeOutCubic(t);
        o.headY = 2 * easeOutCubic(t);
        break;
      }

      case 'successBounce': {
        const rise = easeOutBack(clamp01(t * 1.8));
        const settle = t > 0.55 ? easeOutCubic((t - 0.55) / 0.45) : 0;
        o.headY = -4 * rise * (1 - settle);
        o.wingLift = 7 * rise * (1 - settle);
        o.haloFlash = pulse(t) * 0.45;
        o.starFlash = pulse(t);
        o.sparkFlash = pulse(t);
        break;
      }

      case 'interruptReaction': {
        const w = pulse(t);
        o.eyeWiden = w * 0.9;
        o.headY = w * 2.4;
        o.headTilt = -w * 2;
        break;
      }
    }

    if (t >= 1) {
      const finished = this.current;
      this.current = null;
      if (finished === 'sleep') o.wakeProgress = 0;
      if (finished === 'wake') o.wakeProgress = 1;
    }
    return o;
  }
}
