import { clamp01, easeInOutSine } from '../animation/easing';
import type { Rng } from '../animation/random';

type BlinkStage = 'open' | 'closing' | 'closed' | 'opening';

export interface BlinkUpdate {
  /** Autonomous blinking. Speech never switches this off. */
  enabled: boolean;
  rng: Rng;
}

/**
 * Blinking, driven by lid travel rather than by squashing the eyeball.
 * Stage lengths are re-rolled per blink inside the ranges from the brief, so
 * no two blinks are identical.
 */
export class BlinkController {
  /** 0 open .. 1 closed. */
  amount = 0;

  private stage: BlinkStage = 'open';
  private stageElapsed = 0;
  private stageDuration = 0;
  private closingMs = 0.14;
  private closedMs = 0.08;
  private openingMs = 0.14;
  private nextBlinkIn = 3;
  /** Extra blinks queued behind the current one (double blink). */
  private queued = 0;

  /** Trigger a single blink now. */
  blink(): void {
    if (this.stage === 'open') this.begin();
    else this.queued = Math.max(this.queued, 1);
  }

  /** Trigger a blink followed immediately by a second one. */
  doubleBlink(): void {
    this.blink();
    this.queued = Math.max(this.queued, 1);
  }

  reset(): void {
    this.stage = 'open';
    this.amount = 0;
    this.queued = 0;
    this.stageElapsed = 0;
  }

  private begin(rng?: Rng): void {
    this.closingMs = rng ? rng.range(0.1, 0.17) : 0.14;
    this.closedMs = rng ? rng.range(0.06, 0.1) : 0.08;
    this.openingMs = rng ? rng.range(0.1, 0.17) : 0.14;
    this.stage = 'closing';
    this.stageElapsed = 0;
    this.stageDuration = this.closingMs;
  }

  update(dt: number, opts: BlinkUpdate): number {
    if (this.stage === 'open') {
      if (this.queued > 0) {
        this.queued -= 1;
        this.begin(opts.rng);
      } else if (opts.enabled) {
        this.nextBlinkIn -= dt;
        if (this.nextBlinkIn <= 0) {
          this.nextBlinkIn = opts.rng.range(2.5, 7);
          // 10-15% of blinks come in pairs.
          if (opts.rng.chance(0.12)) this.queued = 1;
          this.begin(opts.rng);
        }
      }
      this.amount = 0;
      return this.amount;
    }

    this.stageElapsed += dt;
    const t = clamp01(this.stageElapsed / this.stageDuration);

    switch (this.stage) {
      case 'closing':
        this.amount = easeInOutSine(t);
        if (t >= 1) {
          this.stage = 'closed';
          this.stageElapsed = 0;
          this.stageDuration = this.closedMs;
        }
        break;
      case 'closed':
        this.amount = 1;
        if (t >= 1) {
          this.stage = 'opening';
          this.stageElapsed = 0;
          this.stageDuration = this.openingMs;
        }
        break;
      case 'opening':
        this.amount = 1 - easeInOutSine(t);
        if (t >= 1) {
          this.stage = 'open';
          this.amount = 0;
          this.stageElapsed = 0;
        }
        break;
    }
    return this.amount;
  }
}
