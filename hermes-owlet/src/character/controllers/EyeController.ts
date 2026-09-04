import { damp } from '../animation/easing';
import { BlinkController } from './BlinkController';
import { GazeController } from './GazeController';

/**
 * The eye surface from the brief. It is a thin facade: gaze and blink each own
 * their own timing, and widen/narrow is a single signed value so the two can
 * never fight each other.
 */
export interface EyeControllerApi {
  gaze(x: number, y: number): void;
  blink(amount: number): void;
  widen(amount: number): void;
  narrow(amount: number): void;
}

export class EyeController implements EyeControllerApi {
  readonly gazeController = new GazeController();
  readonly blinkController = new BlinkController();

  /** Positive widens, negative narrows. Decays back to the phase pose. */
  private widenTarget = 0;
  private widenValue = 0;

  gaze(x: number, y: number): void {
    this.gazeController.gaze(x, y);
  }

  /** 0 opens, 1 closes. Values in between hold the lids part-way. */
  blink(amount: number): void {
    if (amount >= 0.999) this.blinkController.blink();
    else this.blinkController.reset();
  }

  widen(amount: number): void {
    this.widenTarget = Math.abs(amount);
  }

  narrow(amount: number): void {
    this.widenTarget = -Math.abs(amount);
  }

  /** Let a transient widen/narrow relax away. */
  update(dt: number): number {
    this.widenValue = damp(this.widenValue, this.widenTarget, 0.0005, dt);
    this.widenTarget = damp(this.widenTarget, 0, 0.02, dt);
    return this.widenValue;
  }

  reset(): void {
    this.widenTarget = 0;
    this.widenValue = 0;
    this.gazeController.reset();
    this.blinkController.reset();
  }
}
