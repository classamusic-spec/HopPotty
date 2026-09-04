/**
 * Turns a TTS output (or any audio node / media stream) into the 0..1
 * amplitude the beak reads.
 *
 * The analyser gives an honest RMS, which is far too spiky to drive a face
 * with, so it is normalised against a slowly-tracked ceiling and then smoothed
 * with a fast attack and a slow release — the beak snaps open on a syllable
 * and closes lazily, which is what reads as speech.
 */

export interface SpeechMeterOptions {
  /** Existing context to attach to. One is created if omitted. */
  audioContext?: AudioContext;
  fftSize?: number;
  /** Fraction of the gap left after one second while rising. */
  attackSmoothing?: number;
  /** Fraction of the gap left after one second while falling. */
  releaseSmoothing?: number;
  /** Amplitude below this is treated as silence. */
  noiseFloor?: number;
}

const DEFAULTS = {
  fftSize: 1024,
  attackSmoothing: Math.pow(1 - 0.45, 60),
  releaseSmoothing: Math.pow(1 - 0.14, 60),
  noiseFloor: 0.012,
};

export class SpeechMeter {
  private context: AudioContext | null = null;
  private ownsContext = false;
  private analyser: AnalyserNode | null = null;
  private source: AudioNode | null = null;
  private buffer = new Float32Array(new ArrayBuffer(0));
  private raf = 0;
  private lastTime = 0;
  private ceiling = 0.08;
  private smoothed = 0;
  private listener: ((level: number) => void) | null = null;
  private readonly options: Required<Omit<SpeechMeterOptions, 'audioContext'>>;

  constructor(options: SpeechMeterOptions = {}) {
    this.options = {
      fftSize: options.fftSize ?? DEFAULTS.fftSize,
      attackSmoothing: options.attackSmoothing ?? DEFAULTS.attackSmoothing,
      releaseSmoothing: options.releaseSmoothing ?? DEFAULTS.releaseSmoothing,
      noiseFloor: options.noiseFloor ?? DEFAULTS.noiseFloor,
    };
    if (options.audioContext) this.context = options.audioContext;
  }

  /** Current smoothed level, 0..1. */
  get level(): number {
    return this.smoothed;
  }

  private ensureContext(): AudioContext {
    if (!this.context) {
      this.context = new AudioContext();
      this.ownsContext = true;
    }
    return this.context;
  }

  private ensureAnalyser(): AnalyserNode {
    const ctx = this.ensureContext();
    if (!this.analyser) {
      this.analyser = ctx.createAnalyser();
      this.analyser.fftSize = this.options.fftSize;
      this.analyser.smoothingTimeConstant = 0.2;
      this.buffer = new Float32Array(new ArrayBuffer(this.analyser.fftSize * 4));
    }
    return this.analyser;
  }

  /** Attach to a microphone or TTS media stream. */
  connectStream(stream: MediaStream): void {
    const ctx = this.ensureContext();
    this.connectNode(ctx.createMediaStreamSource(stream));
  }

  /** Attach to an <audio> element playing TTS. */
  connectElement(element: HTMLMediaElement): void {
    const ctx = this.ensureContext();
    const node = ctx.createMediaElementSource(element);
    node.connect(ctx.destination);
    this.connectNode(node);
  }

  /** Attach to any node already in the graph. */
  connectNode(node: AudioNode): void {
    const analyser = this.ensureAnalyser();
    this.source?.disconnect(analyser);
    this.source = node;
    node.connect(analyser);
  }

  start(listener: (level: number) => void): void {
    this.listener = listener;
    if (this.raf) return;
    this.lastTime = performance.now();
    const frame = (now: number): void => {
      const dt = Math.min((now - this.lastTime) / 1000, 0.1);
      this.lastTime = now;
      this.listener?.(this.sample(dt));
      this.raf = requestAnimationFrame(frame);
    };
    this.raf = requestAnimationFrame(frame);
  }

  stop(): void {
    if (this.raf) cancelAnimationFrame(this.raf);
    this.raf = 0;
    this.listener = null;
    this.smoothed = 0;
  }

  async dispose(): Promise<void> {
    this.stop();
    this.analyser?.disconnect();
    this.analyser = null;
    if (this.ownsContext && this.context) await this.context.close();
    this.context = null;
    this.source = null;
  }

  /** Read one frame. Exposed so a host can drive the meter from its own loop. */
  sample(dt: number): number {
    const analyser = this.analyser;
    if (!analyser) return 0;
    analyser.getFloatTimeDomainData(this.buffer);

    let sum = 0;
    for (let i = 0; i < this.buffer.length; i++) {
      const v = this.buffer[i]!;
      sum += v * v;
    }
    const rms = Math.sqrt(sum / this.buffer.length);

    // Track a slow ceiling so quiet and loud voices both fill the range.
    this.ceiling = rms > this.ceiling ? rms : this.ceiling + (rms - this.ceiling) * 0.02;
    const ceiling = Math.max(this.ceiling, 0.02);
    const raw = rms < this.options.noiseFloor ? 0 : Math.min(1, rms / ceiling);

    const smoothing =
      raw > this.smoothed ? this.options.attackSmoothing : this.options.releaseSmoothing;
    this.smoothed = raw + (this.smoothed - raw) * Math.pow(smoothing, dt);
    return this.smoothed;
  }
}

/**
 * A deterministic stand-in for real TTS. The simulator uses it so the beak can
 * be exercised without an audio pipeline.
 */
export const createSyntheticSpeech = (seed = 1): ((t: number) => number) => {
  const a = 0.9 + (seed % 7) * 0.03;
  return (t: number): number => {
    const syllable = Math.max(0, Math.sin(t * 9.1 * a));
    const word = Math.max(0, Math.sin(t * 1.6 + 0.6));
    const breath = Math.sin(t * 0.37) * 0.5 + 0.5;
    return Math.min(1, syllable * (0.45 + word * 0.55) * (0.55 + breath * 0.6));
  };
};
