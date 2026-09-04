import { clamp, clamp01, damp, lerp, round } from '../animation/easing';
import { createRng, type Rng } from '../animation/random';
import { BeakController } from '../controllers/BeakController';
import { EyeController } from '../controllers/EyeController';
import { HaloController } from '../controllers/HaloController';
import { HeadphoneController } from '../controllers/HeadphoneController';
import { IdleController } from '../controllers/IdleController';
import {
  MicroAnimationController,
  type MicroAnimation,
} from '../controllers/MicroAnimationController';
import { WingController } from '../controllers/WingController';
import { EXPRESSIONS, type ExpressionPose } from '../state/expressions';
import {
  createInitialState,
  type HermesEmotion,
  type HermesOwletPhase,
  type HermesOwletState,
} from '../state/HermesOwletState';
import {
  IMMEDIATE_PHASES,
  PHASE_TARGETS,
  PHASE_TRANSITION_SECONDS,
  type PhaseTarget,
} from '../state/phaseTargets';
import { ANCHORS, GOLD_RAMP, LID_TRAVEL } from '../svg/geometry';
import { DomWriter, rotateAbout, translate } from './DomWriter';
import type { RigNodes } from './RigNodes';

export interface RigOptions {
  reducedMotion?: boolean;
  /** Seed the idle randomness for reproducible captures. */
  seed?: number;
  /** Debug snapshot, delivered at ~12 Hz — never per frame. */
  onState?: (state: Readonly<HermesOwletState>) => void;
}

/** Fraction of a gap still remaining one second later, for the phase blend. */
const PHASE_BLEND_SMOOTHING = Math.pow(0.05, 1 / PHASE_TRANSITION_SECONDS);
const EXPRESSION_BLEND_SMOOTHING = 1e-4;

/** Speech nudges the head, but never by more than 2 units. */
const SPEECH_BOB_MAX = 1.5;

/** Pick a flat gold step for a 0..1 brightness. */
const goldStep = (brightness: number): string =>
  GOLD_RAMP[Math.round(clamp01(brightness) * (GOLD_RAMP.length - 1))]!;

type BlendKeys =
  | 'headY'
  | 'headTilt'
  | 'wingLift'
  | 'eyeScaleY'
  | 'lidNarrow'
  | 'pupilScale'
  | 'gazeBiasX'
  | 'gazeBiasY'
  | 'headphoneGlow'
  | 'pulsePeriod'
  | 'haloGlow'
  | 'haloOpacity'
  | 'haloTilt'
  | 'haloOrbitPeriod'
  | 'starGlow'
  | 'starPulsePeriod'
  | 'floatAmplitude';

const BLEND_KEYS: readonly BlendKeys[] = [
  'headY',
  'headTilt',
  'wingLift',
  'eyeScaleY',
  'lidNarrow',
  'pupilScale',
  'gazeBiasX',
  'gazeBiasY',
  'headphoneGlow',
  'pulsePeriod',
  'haloGlow',
  'haloOpacity',
  'haloTilt',
  'haloOrbitPeriod',
  'starGlow',
  'starPulsePeriod',
  'floatAmplitude',
];

const EXPRESSION_KEYS: readonly (keyof ExpressionPose)[] = [
  'lidNarrow',
  'eyeScaleY',
  'eyeCurve',
  'browOpacity',
  'browAngle',
  'browY',
  'gazeBiasY',
];

/**
 * The animation engine.
 *
 * React owns the character's high-level state; this owns everything that moves.
 * One rAF loop, no per-frame allocation beyond the transform strings, and every
 * DOM write is dirty-checked, so a still character costs almost nothing.
 */
export class HermesOwletRig {
  readonly eyes = new EyeController();
  readonly beak = new BeakController();
  readonly halo = new HaloController();
  readonly headphones = new HeadphoneController();
  readonly wings = new WingController();
  readonly idle = new IdleController();
  readonly micro = new MicroAnimationController();

  private writer: DomWriter;
  private rng: Rng;
  private raf = 0;
  private lastTime = 0;
  private running = false;
  private reducedMotion: boolean;
  private onState?: (state: Readonly<HermesOwletState>) => void;
  private stateClock = 0;

  private phase: HermesOwletPhase = 'offline';
  private emotionOverride: HermesEmotion | null = null;
  private blend: Record<BlendKeys, number>;
  private expression: ExpressionPose = { ...EXPRESSIONS.neutral };

  /** Effect layer weights, damped so nothing pops on or off. */
  private fx = { listening: 0, speaking: 0, thinking: 0, error: 0 };
  /** Debug overrides. `null` means "follow the phase". */
  private overrides: { haloGlow: number | null; headphoneGlow: number | null } = {
    haloGlow: null,
    headphoneGlow: null,
  };
  private errorFlicker = 0;
  private starPhase = 0;

  private readonly state: HermesOwletState = createInitialState('offline');

  constructor(nodes: RigNodes, options: RigOptions = {}) {
    this.writer = new DomWriter(nodes);
    this.rng = createRng(options.seed);
    this.reducedMotion = options.reducedMotion ?? false;
    this.onState = options.onState;

    const t = PHASE_TARGETS.offline;
    this.blend = {} as Record<BlendKeys, number>;
    for (const key of BLEND_KEYS) this.blend[key] = t[key];

    this.micro.onBlinkRequest = (double) => {
      if (double) this.eyes.blinkController.doubleBlink();
      else this.eyes.blinkController.blink();
    };
  }

  // ------------------------------------------------------------------ inputs

  setNodes(nodes: RigNodes): void {
    this.writer.setNodes(nodes);
  }

  setPhase(phase: HermesOwletPhase): void {
    if (phase === this.phase) return;
    const previous = this.phase;
    this.phase = phase;
    this.state.phase = phase;
    this.onPhaseEnter(phase, previous);
  }

  setEmotion(emotion: HermesEmotion | null): void {
    this.emotionOverride = emotion;
  }

  /** Raw TTS amplitude, 0..1. Safe to call at audio rate. */
  setSpeechLevel(level: number): void {
    this.beak.setLevel(level);
  }

  setGaze(x: number, y: number): void {
    this.eyes.gaze(x, y);
  }

  releaseGaze(): void {
    this.eyes.gazeController.release();
  }

  blink(): void {
    this.eyes.blinkController.blink();
  }

  doubleBlink(): void {
    this.eyes.blinkController.doubleBlink();
  }

  play(animation: MicroAnimation): void {
    this.micro.play(animation);
  }

  setReducedMotion(value: boolean): void {
    this.reducedMotion = value;
  }

  /** Pin a glow to a fixed value, or pass `null` to follow the phase again. */
  setOverride(key: 'haloGlow' | 'headphoneGlow', value: number | null): void {
    this.overrides[key] = value === null ? null : clamp01(value);
  }

  getState(): Readonly<HermesOwletState> {
    return this.state;
  }

  // ------------------------------------------------------------- transitions

  private onPhaseEnter(phase: HermesOwletPhase, previous: HermesOwletPhase): void {
    switch (phase) {
      case 'interrupted':
        // The beak stops dead: an interruption must never leave the owl
        // mouthing words the user has already talked over.
        this.beak.reset();
        this.micro.play('interruptReaction');
        break;
      case 'speaking':
        this.micro.stop();
        break;
      case 'success':
        this.micro.play('successBounce');
        break;
      case 'waking':
        this.micro.play('wake');
        break;
      case 'offline':
        this.beak.reset();
        this.micro.play('sleep');
        break;
      case 'error':
        this.beak.reset();
        this.micro.stop();
        this.errorFlicker = 1;
        break;
      default:
        break;
    }

    if (IMMEDIATE_PHASES.has(phase)) {
      // Snap the parts of the pose the user must feel at once.
      const t = PHASE_TARGETS[phase];
      this.blend.eyeScaleY = t.eyeScaleY;
      this.blend.lidNarrow = t.lidNarrow;
      if (previous !== 'offline') this.blend.headY = t.headY;
    }
  }

  // -------------------------------------------------------------------- loop

  start(): void {
    if (this.running) return;
    this.running = true;
    this.lastTime = performance.now();
    const frame = (now: number): void => {
      if (!this.running) return;
      const dt = clamp((now - this.lastTime) / 1000, 0, 0.1);
      this.lastTime = now;
      this.update(dt);
      this.raf = requestAnimationFrame(frame);
    };
    this.raf = requestAnimationFrame(frame);
  }

  stop(): void {
    this.running = false;
    if (this.raf) cancelAnimationFrame(this.raf);
    this.raf = 0;
  }

  /** Advance one frame. Exposed so tests can step the rig deterministically. */
  update(dt: number): void {
    const target: PhaseTarget = PHASE_TARGETS[this.phase];
    const reduced = this.reducedMotion;

    // ------------------------------------------------ blend toward the phase
    for (const key of BLEND_KEYS) {
      this.blend[key] = damp(this.blend[key], target[key], PHASE_BLEND_SMOOTHING, dt);
    }
    const emotion = this.emotionOverride ?? target.emotion;
    const wantExpression = EXPRESSIONS[emotion];
    for (const key of EXPRESSION_KEYS) {
      this.expression[key] = damp(
        this.expression[key],
        wantExpression[key],
        EXPRESSION_BLEND_SMOOTHING,
        dt,
      );
    }

    // ------------------------------------------------------------ controllers
    const micro = this.micro.update(dt);

    this.idle.update(dt, {
      phase: this.phase,
      amplitude: this.blend.floatAmplitude,
      reducedMotion: reduced,
      rng: this.rng,
      micro: this.micro,
    });

    this.eyes.gazeController.offsetX = micro.gazeX;
    this.eyes.gazeController.offsetY = micro.gazeY;
    this.eyes.gazeController.update(dt, {
      autonomous: target.autonomous && !reduced,
      biasX: this.blend.gazeBiasX,
      biasY: this.blend.gazeBiasY + this.expression.gazeBiasY,
      reducedMotion: reduced,
      rng: this.rng,
    });

    // Blinking survives every state except sleep, speech included.
    const blink = this.eyes.blinkController.update(dt, {
      enabled: this.phase !== 'offline',
      rng: this.rng,
    });
    const widen = this.eyes.update(dt) + micro.eyeWiden;

    const speaking = this.phase === 'speaking';
    const beakDrop = this.beak.update(dt, speaking);

    this.halo.update(dt, {
      glow: this.overrides.haloGlow ?? this.blend.haloGlow,
      opacity: this.blend.haloOpacity,
      tilt: this.blend.haloTilt,
      orbitPeriod: this.blend.haloOrbitPeriod,
      reducedMotion: reduced,
      rng: this.rng,
      flash: micro.haloFlash,
    });

    this.headphones.update(dt, {
      glow: this.overrides.headphoneGlow ?? this.blend.headphoneGlow,
      pulse: reduced ? 'off' : target.pulse,
      period: this.blend.pulsePeriod,
      speechLevel: this.beak.level,
      reducedMotion: reduced,
    });

    this.wings.update(dt, {
      lift: this.blend.wingLift,
      bonus: micro.wingLift,
      reducedMotion: reduced,
    });

    // -------------------------------------------------------- effect weights
    this.fx.listening = damp(this.fx.listening, this.phase === 'listening' ? 1 : 0, 1e-4, dt);
    this.fx.speaking = damp(this.fx.speaking, speaking ? 1 : 0, 1e-4, dt);
    this.fx.thinking = damp(
      this.fx.thinking,
      this.phase === 'thinking' || this.phase === 'tool_use' ? 1 : 0,
      1e-4,
      dt,
    );
    this.fx.error = damp(this.fx.error, this.phase === 'error' ? 1 : 0, 1e-4, dt);
    if (this.errorFlicker > 0) this.errorFlicker = Math.max(0, this.errorFlicker - dt / 0.65);

    this.starPhase += dt;

    // ------------------------------------------------------------ composition
    const speechBob = -clamp01(this.beak.level) * SPEECH_BOB_MAX;
    const headY = this.blend.headY + this.idle.floatY + micro.headY + speechBob;
    const headTilt = clamp(this.blend.headTilt + this.idle.microTilt + micro.headTilt, -7, 7);

    const gazePx = {
      x: this.eyes.gazeController.x.value * ANCHORS.eye.maxGazeX,
      y: this.eyes.gazeController.y.value * ANCHORS.eye.maxGazeY,
    };

    const narrow = clamp01(this.blend.lidNarrow + this.expression.lidNarrow);
    const upperClose = clamp01(narrow + (1 - narrow) * blink);
    const lowerNarrow = clamp01(this.expression.eyeCurve * 0.34 + this.blend.lidNarrow * 0.25);
    const lowerClose = clamp01(lowerNarrow + (1 - lowerNarrow) * blink);

    const eyeScaleY = clamp(
      this.blend.eyeScaleY * this.expression.eyeScaleY * (1 + widen * 0.06),
      0.85,
      1.15,
    );
    const eyeScaleX = 1 + (eyeScaleY - 1) * 0.35;

    this.writeFrame({
      headY,
      headTilt,
      gazePx,
      upperClose,
      lowerClose,
      eyeScaleX,
      eyeScaleY,
      beakDrop,
      micro,
    });

    // --------------------------------------------------------- debug snapshot
    this.state.emotion = emotion;
    this.state.gazeX = round(this.eyes.gazeController.x.value, 3);
    this.state.gazeY = round(this.eyes.gazeController.y.value, 3);
    this.state.blinkAmount = round(upperClose, 3);
    this.state.headTilt = round(headTilt, 2);
    this.state.headY = round(headY, 2);
    this.state.haloRotation = round(this.halo.rotation, 1);
    this.state.haloGlow = round(this.halo.glow, 3);
    this.state.headphoneGlow = round(this.headphones.left, 3);
    this.state.wingLift = round(this.wings.left, 2);
    this.state.speechLevel = round(this.beak.level, 3);
    this.state.beakOpen = round(beakDrop / 9, 3);

    if (this.onState) {
      this.stateClock += dt;
      if (this.stateClock >= 1 / 12) {
        this.stateClock = 0;
        this.onState(this.state);
      }
    }
  }

  // ------------------------------------------------------------- DOM writing

  private writeFrame(f: {
    headY: number;
    headTilt: number;
    gazePx: { x: number; y: number };
    upperClose: number;
    lowerClose: number;
    eyeScaleX: number;
    eyeScaleY: number;
    beakDrop: number;
    micro: { starFlash: number; sparkFlash: number; wakeProgress: number };
  }): void {
    const w = this.writer;
    const halo = ANCHORS.halo;

    w.transform(
      'head-root',
      `${translate(0, f.headY)} ${rotateAbout(f.headTilt, ANCHORS.headPivot.x, ANCHORS.headPivot.y)}`,
    );
    w.transform(
      'crown-tuft',
      rotateAbout(this.idle.tuftAngle, ANCHORS.tuftPivot.x, ANCHORS.tuftPivot.y),
    );
    w.transform(
      'left-wing',
      rotateAbout(this.wings.left, ANCHORS.leftWingPivot.x, ANCHORS.leftWingPivot.y),
    );
    w.transform(
      'right-wing',
      rotateAbout(-this.wings.right, ANCHORS.rightWingPivot.x, ANCHORS.rightWingPivot.y),
    );

    // Halo: follows the float at half strength so it reads as detached.
    w.transform(
      'halo-group',
      `${translate(0, f.headY * 0.5)} ${rotateAbout(this.halo.tilt, halo.cx, halo.cy)}`,
    );
    const haloOpacity = this.halo.opacity * (1 - 0.55 * this.flickerWave());
    w.opacity('halo', haloOpacity);
    // Brightness steps along the flat gold ramp; the soft bloom only joins in
    // at the top of the range, so the halo is never permanently hazy.
    w.attr('halo', 'stroke', goldStep(this.halo.glow));
    w.opacity('halo-bloom', Math.max(0, this.halo.glow - 0.72) * 1.15 * haloOpacity);

    const sparkAngle = (this.halo.rotation * Math.PI) / 180;
    const sparkX = halo.cx + Math.cos(sparkAngle) * 26;
    const sparkY = halo.cy + Math.sin(sparkAngle) * 8;
    const sparkScale = this.halo.sparkScale * (1 + f.micro.sparkFlash * 0.35);
    w.transform('halo-spark', `${translate(sparkX, sparkY)} scale(${round(sparkScale, 3)})`);
    w.opacity('halo-spark', clamp01(this.halo.sparkOpacity + f.micro.sparkFlash * 0.4) * haloOpacity);

    // Forehead star: a slow breath while thinking, a flash on success.
    const pulsePeriod = this.blend.starPulsePeriod;
    const starWave =
      pulsePeriod > 0.05 ? (Math.sin((this.starPhase / pulsePeriod) * Math.PI * 2) + 1) / 2 : 0;
    const starScale = 1 + starWave * 0.1 + f.micro.starFlash * 0.12;
    w.transform(
      'forehead-star-group',
      `translate(${round(ANCHORS.foreheadStar.x)} ${round(ANCHORS.foreheadStar.y)}) ` +
        `scale(${round(starScale, 4)}) ` +
        `translate(${round(-ANCHORS.foreheadStar.x)} ${round(-ANCHORS.foreheadStar.y)})`,
    );
    const starLight = clamp01(this.blend.starGlow + starWave * 0.18 + f.micro.starFlash * 0.5);
    w.attr('forehead-star', 'fill', goldStep(starLight));
    w.opacity('forehead-star-bloom', Math.max(0, starLight - 0.7) * 1.8);

    // Eyes.
    const eyeTransform = (x: number, y: number): string =>
      `${translate(x, y)} scale(${round(f.eyeScaleX, 4)} ${round(f.eyeScaleY, 4)})`;
    w.transform('left-eye', eyeTransform(ANCHORS.leftEye.x, ANCHORS.leftEye.y));
    w.transform('right-eye', eyeTransform(ANCHORS.rightEye.x, ANCHORS.rightEye.y));

    const pupil = translate(f.gazePx.x, f.gazePx.y);
    w.transform('left-pupil', pupil);
    w.transform('right-pupil', pupil);

    const core = ANCHORS.eye.coreOffset;
    const coreScale =
      `translate(${core.x} ${core.y}) scale(${round(this.blend.pupilScale, 4)}) ` +
      `translate(${-core.x} ${-core.y})`;
    w.transform('left-pupil-core', coreScale);
    w.transform('right-pupil-core', coreScale);

    const upperY = lerp(LID_TRAVEL.upperParked, LID_TRAVEL.upperClosed, f.upperClose);
    const lowerY = lerp(LID_TRAVEL.lowerParked, LID_TRAVEL.lowerClosed, f.lowerClose);
    const upper = translate(0, upperY);
    const lower = translate(0, lowerY);
    w.transform('left-lid', upper);
    w.transform('right-lid', upper);
    w.transform('left-lower-lid', lower);
    w.transform('right-lower-lid', lower);

    // Brows stay invisible at neutral so the locked silhouette is untouched.
    const browOpacity = clamp01(this.expression.browOpacity);
    const browY = ANCHORS.leftEye.y - 60 + this.expression.browY;
    w.opacity('left-brow', browOpacity);
    w.opacity('right-brow', browOpacity);
    w.transform(
      'left-brow',
      `${translate(ANCHORS.leftEye.x, browY)} rotate(${round(-this.expression.browAngle, 2)})`,
    );
    w.transform(
      'right-brow',
      `${translate(ANCHORS.rightEye.x, browY)} rotate(${round(this.expression.browAngle, 2)})`,
    );

    // Beak.
    w.transform('lower-beak', translate(0, f.beakDrop));
    w.attr('beak-gap', 'height', round(2 + f.beakDrop, 2));

    // Headphone rings.
    w.opacity('left-headphone-lit', this.headphones.left);
    w.opacity('right-headphone-lit', this.headphones.right);
    // The soft ring outside each cup belongs to LISTENING; at rest it is off.
    w.opacity('left-headphone-glow', this.headphones.left * 0.3 * this.fx.listening);
    w.opacity('right-headphone-glow', this.headphones.right * 0.3 * this.fx.listening);

    // Effects.
    w.opacity('listening-glow', this.fx.listening * 0.34);
    w.opacity('speaking-pulse', this.fx.speaking * clamp01(0.12 + this.beak.level * 0.35));
    w.opacity('error-pulse', this.fx.error * 0.17);

    const thinkAngle = (-this.halo.rotation * 1.7 * Math.PI) / 180;
    const tx = halo.cx + Math.cos(thinkAngle) * (halo.rx + 18);
    const ty = halo.cy + Math.sin(thinkAngle) * (halo.ry + 16);
    w.transform('thinking-spark', `${translate(tx, ty)} scale(0.62)`);
    w.opacity('thinking-spark', this.fx.thinking * 0.9);
  }

  /** A single decaying flicker on entering the error state — it never loops. */
  private flickerWave(): number {
    if (this.errorFlicker <= 0) return 0;
    const t = 1 - this.errorFlicker;
    return Math.max(0, Math.sin(t * Math.PI * 3)) * this.errorFlicker;
  }
}
