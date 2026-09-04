import { createSpring, stepSpring, snapSpring, SPRING_PRESETS } from '../animation/springs';
import { clamp } from '../animation/easing';
import type { Rng } from '../animation/random';

export interface GazeUpdate {
  /** Autonomous drift is only allowed in calm phases. */
  autonomous: boolean;
  biasX: number;
  biasY: number;
  reducedMotion: boolean;
  rng: Rng;
}

/**
 * Pupil aim, in normalised -1..1 units. Nothing here ever snaps: every target
 * change is filtered through a soft, high-damping spring, and the drift target
 * only moves every few seconds.
 */
export class GazeController {
  private readonly sx = createSpring(0, SPRING_PRESETS.gaze.stiffness, SPRING_PRESETS.gaze.damping);
  private readonly sy = createSpring(0, SPRING_PRESETS.gaze.stiffness, SPRING_PRESETS.gaze.damping);

  private driftX = 0;
  private driftY = 0;
  private nextDriftIn = 3;

  /** Externally commanded gaze; overrides drift until cleared. */
  private override: { x: number; y: number } | null = null;

  /** One-shot additive nudge from a micro-animation. */
  offsetX = 0;
  offsetY = 0;

  readonly x = { value: 0 };
  readonly y = { value: 0 };

  /** EyeController surface: aim the pupils at a point in -1..1 space. */
  gaze(x: number, y: number): void {
    this.override = { x: clamp(x, -1, 1), y: clamp(y, -1, 1) };
  }

  /** Hand control back to the autonomous drift. */
  release(): void {
    this.override = null;
  }

  get isOverridden(): boolean {
    return this.override !== null;
  }

  reset(): void {
    snapSpring(this.sx, 0);
    snapSpring(this.sy, 0);
    this.driftX = 0;
    this.driftY = 0;
    this.override = null;
  }

  update(dt: number, opts: GazeUpdate): void {
    if (opts.autonomous && !opts.reducedMotion && !this.override) {
      this.nextDriftIn -= dt;
      if (this.nextDriftIn <= 0) {
        this.driftX = opts.rng.range(-0.12, 0.12);
        this.driftY = opts.rng.range(-0.08, 0.08);
        this.nextDriftIn = opts.rng.range(2.4, 5.2);
      }
    } else if (!opts.autonomous) {
      this.driftX = 0;
      this.driftY = 0;
    }

    const baseX = this.override ? this.override.x : this.driftX;
    const baseY = this.override ? this.override.y : this.driftY;

    this.sx.target = clamp(baseX + opts.biasX + this.offsetX, -1, 1);
    this.sy.target = clamp(baseY + opts.biasY + this.offsetY, -1, 1);

    this.x.value = stepSpring(this.sx, dt);
    this.y.value = stepSpring(this.sy, dt);
  }
}
