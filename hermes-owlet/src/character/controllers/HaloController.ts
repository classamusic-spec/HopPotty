import { clamp01, damp, lerp } from '../animation/easing';
import type { Rng } from '../animation/random';

export interface HaloControllerApi {
  rotation: number;
  glow: number;
  opacity: number;
  tilt: number;
}

export interface HaloUpdate {
  glow: number;
  opacity: number;
  /** Static tilt from the phase, in degrees. */
  tilt: number;
  /** Seconds per revolution of the orbiting spark. */
  orbitPeriod: number;
  reducedMotion: boolean;
  rng: Rng;
  /** One-shot brightening, 0..1, added on top. */
  flash: number;
}

/**
 * The halo reads as Hermes' energy. It never spins fast — a fast ring reads as
 * a loading spinner, which is exactly what this must not be. Instead the ring
 * rocks a couple of degrees and a single spark drifts slowly around it.
 */
export class HaloController implements HaloControllerApi {
  /** Orbit angle of the spark, in degrees. */
  rotation = 0;
  glow = 0.3;
  opacity = 1;
  tilt = 0;

  /** Spark presentation. */
  sparkScale = 1;
  sparkOpacity = 0.75;

  private rockPhase = 0;
  private sparkPulse = 0;
  private nextSparkIn = 4;

  update(dt: number, opts: HaloUpdate): void {
    const orbitSpeed = opts.reducedMotion ? 0 : 360 / Math.max(opts.orbitPeriod, 1);
    this.rotation = (this.rotation + orbitSpeed * dt) % 360;

    this.glow = clamp01(damp(this.glow, clamp01(opts.glow + opts.flash), 0.0008, dt));
    this.opacity = damp(this.opacity, opts.opacity, 0.0008, dt);

    // A slow rock, not a rotation. Amplitude stays under the "is it moving?"
    // threshold on purpose.
    this.rockPhase += dt;
    const rock = opts.reducedMotion ? 0 : Math.sin(this.rockPhase * 0.42) * 1.6;
    this.tilt = damp(this.tilt, opts.tilt, 0.002, dt) + rock;

    if (opts.reducedMotion) {
      // Hold the spark still: reduced motion keeps state changes, not idle life.
      this.sparkScale = 1;
      this.sparkOpacity = 0.6 + this.glow * 0.4;
      return;
    }

    // The spark breathes every few seconds rather than continuously.
    this.nextSparkIn -= dt;
    if (this.nextSparkIn <= 0 && this.sparkPulse <= 0) {
      this.sparkPulse = 1;
      this.nextSparkIn = opts.rng.range(3.5, 8);
    }
    if (this.sparkPulse > 0) {
      this.sparkPulse = Math.max(0, this.sparkPulse - dt / 1.1);
      const wave = Math.sin((1 - this.sparkPulse) * Math.PI);
      this.sparkScale = lerp(0.9, 1.1, wave);
      this.sparkOpacity = lerp(0.6, 1, wave);
    } else {
      this.sparkScale = damp(this.sparkScale, 0.95, 0.02, dt);
      this.sparkOpacity = damp(this.sparkOpacity, 0.6 + this.glow * 0.4, 0.02, dt);
    }
  }
}
