import { damp } from '../animation/easing';
import { createSpring, stepSpring, SPRING_PRESETS } from '../animation/springs';

export interface WingUpdate {
  /** Degrees of lift from the current phase. */
  lift: number;
  /** Additive one-shot lift from a micro-animation. */
  bonus: number;
  reducedMotion: boolean;
}

/** Normal idle sway stays inside +/-3 degrees. */
const SWAY_DEGREES = 2.4;

/**
 * Both side feather groups are treated as one shape per side in V1 — no
 * per-feather animation. The two sides sway slightly out of phase so the
 * character never looks mechanically symmetrical.
 */
export class WingController {
  left = 0;
  right = 0;

  private readonly spring = createSpring(0, SPRING_PRESETS.wing.stiffness, SPRING_PRESETS.wing.damping);
  private swayPhase = 0;
  private sway = 0;

  update(dt: number, opts: WingUpdate): void {
    this.spring.target = opts.lift + opts.bonus;
    const lift = stepSpring(this.spring, dt);

    if (opts.reducedMotion) {
      // Settle exactly, so the transform stops changing rather than creeping.
      this.sway = 0;
    } else {
      this.swayPhase += dt;
      this.sway = damp(this.sway, 1, 0.01, dt);
    }

    this.left = lift + Math.sin(this.swayPhase * 0.55) * SWAY_DEGREES * this.sway;
    this.right = lift + Math.sin(this.swayPhase * 0.55 + 1.9) * SWAY_DEGREES * this.sway;
  }
}
