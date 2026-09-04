import { clamp01, damp } from '../animation/easing';
import type { PulseMode } from '../state/phaseTargets';

export interface HeadphoneUpdate {
  glow: number;
  pulse: PulseMode;
  /** Seconds per cycle. Clamped so the rings never flash faster than ~1 Hz. */
  period: number;
  /** Smoothed speech amplitude, used by the `voice` pulse mode. */
  speechLevel: number;
  reducedMotion: boolean;
}

/** Never faster than 1 Hz, per the brief. */
const MIN_PERIOD = 1;

/**
 * The ear discs are the agent's activity light. Left and right are tracked
 * separately so `tool_use` can alternate them without a second controller.
 */
export class HeadphoneController {
  left = 0;
  right = 0;

  private base = 0;
  private phase = 0;

  update(dt: number, opts: HeadphoneUpdate): void {
    this.base = clamp01(damp(this.base, clamp01(opts.glow), 0.0006, dt));
    const period = Math.max(opts.period, MIN_PERIOD);
    this.phase = (this.phase + dt / period) % 1;

    if (opts.reducedMotion || opts.pulse === 'off') {
      this.left = this.base;
      this.right = this.base;
      return;
    }

    const wave = (offset: number): number =>
      (Math.sin((this.phase + offset) * Math.PI * 2) + 1) / 2;

    switch (opts.pulse) {
      case 'gentle': {
        const w = wave(0);
        this.left = clamp01(this.base * (0.72 + 0.28 * w));
        this.right = this.left;
        break;
      }
      case 'alternating': {
        this.left = clamp01(this.base * (0.6 + 0.4 * wave(0)));
        this.right = clamp01(this.base * (0.6 + 0.4 * wave(0.5)));
        break;
      }
      case 'voice': {
        const v = clamp01(opts.speechLevel);
        this.left = clamp01(this.base * (0.82 + 0.18 * v) + v * 0.08);
        this.right = this.left;
        break;
      }
    }
  }
}
