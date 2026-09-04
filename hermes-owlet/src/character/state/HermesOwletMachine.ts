import {
  PHASE_PRIORITY,
  type HermesOwletPhase,
} from './HermesOwletState';

/** Normalised events the character consumes. The bridge adapts Hermes to these. */
export type HermesEvent =
  | { type: 'CONNECTED' }
  | { type: 'DISCONNECTED' }
  | { type: 'LISTENING_STARTED' }
  | { type: 'LISTENING_STOPPED' }
  | { type: 'RUN_STARTED' }
  | { type: 'TEXT_DELTA'; text: string }
  | { type: 'TOOL_STARTED'; tool?: string }
  | { type: 'TOOL_FINISHED'; success: boolean }
  | { type: 'SPEECH_STARTED' }
  | { type: 'SPEECH_LEVEL'; level: number }
  | { type: 'SPEECH_STOPPED' }
  | { type: 'INTERRUPTED' }
  | { type: 'RUN_COMPLETE' }
  | { type: 'ERROR'; message?: string };

export type HermesEventType = HermesEvent['type'];

/** Transient window lengths, in milliseconds. */
export const TIMINGS = {
  waking: 800,
  success: 700,
  /** Surprise reaction before handing over to listening. */
  interrupted: 180,
  /** Error is concerned but composed, and never strands the character. */
  errorHold: 6000,
  /** Lower-priority phases may not take over until the current one is this old. */
  minDwell: 200,
} as const;

/**
 * Independent facts about the agent. The phase is derived from these rather
 * than assigned, which is what stops overlapping Hermes events from making the
 * character flicker between states.
 */
export interface MachineContext {
  connected: boolean;
  listening: boolean;
  running: boolean;
  toolActive: boolean;
  speaking: boolean;
  errorActive: boolean;
  /** A run finished while speech was still playing; celebrate once it stops. */
  pendingSuccess: boolean;
  activeTool?: string;
  errorMessage?: string;
  wakingUntil: number;
  successUntil: number;
  interruptedUntil: number;
  errorUntil: number;
}

export const createContext = (connected = false): MachineContext => ({
  connected,
  listening: false,
  running: false,
  toolActive: false,
  speaking: false,
  errorActive: false,
  pendingSuccess: false,
  wakingUntil: 0,
  successUntil: 0,
  interruptedUntil: 0,
  errorUntil: 0,
});

/** Events that mean Hermes is healthy again, and so clear a standing error. */
const CLEARS_ERROR: ReadonlySet<HermesEventType> = new Set([
  'CONNECTED',
  'LISTENING_STARTED',
  'RUN_STARTED',
  'SPEECH_STARTED',
  'TOOL_STARTED',
]);

/** Pure reducer. `now` is milliseconds from a monotonic clock. */
export const reduce = (
  ctx: MachineContext,
  event: HermesEvent,
  now: number,
): MachineContext => {
  const next: MachineContext = { ...ctx };

  if (CLEARS_ERROR.has(event.type) && next.errorActive) {
    next.errorActive = false;
    next.errorUntil = 0;
    next.errorMessage = undefined;
  }

  switch (event.type) {
    case 'CONNECTED':
      if (!next.connected) next.wakingUntil = now + TIMINGS.waking;
      next.connected = true;
      break;

    case 'DISCONNECTED':
      next.connected = false;
      next.listening = false;
      next.running = false;
      next.toolActive = false;
      next.speaking = false;
      next.pendingSuccess = false;
      next.wakingUntil = 0;
      next.successUntil = 0;
      next.interruptedUntil = 0;
      break;

    case 'LISTENING_STARTED':
      next.listening = true;
      next.interruptedUntil = Math.min(next.interruptedUntil, now + TIMINGS.interrupted);
      break;

    case 'LISTENING_STOPPED':
      next.listening = false;
      break;

    case 'RUN_STARTED':
      next.running = true;
      next.pendingSuccess = false;
      next.successUntil = 0;
      break;

    case 'TEXT_DELTA':
      // A delta implies a run even if RUN_STARTED was dropped.
      next.running = true;
      break;

    case 'TOOL_STARTED':
      next.toolActive = true;
      next.running = true;
      next.activeTool = event.tool;
      break;

    case 'TOOL_FINISHED':
      next.toolActive = false;
      next.activeTool = undefined;
      if (!event.success) {
        next.errorActive = true;
        next.errorUntil = now + TIMINGS.errorHold;
      }
      break;

    case 'SPEECH_STARTED':
      next.speaking = true;
      break;

    case 'SPEECH_STOPPED':
      next.speaking = false;
      if (next.pendingSuccess) {
        next.pendingSuccess = false;
        next.successUntil = now + TIMINGS.success;
      }
      break;

    case 'SPEECH_LEVEL':
      // Amplitude drives the beak, not the phase.
      break;

    case 'INTERRUPTED':
      next.speaking = false;
      next.pendingSuccess = false;
      next.interruptedUntil = now + TIMINGS.interrupted;
      break;

    case 'RUN_COMPLETE':
      next.running = false;
      next.toolActive = false;
      next.activeTool = undefined;
      if (next.speaking) next.pendingSuccess = true;
      else next.successUntil = now + TIMINGS.success;
      break;

    case 'ERROR':
      next.errorActive = true;
      next.errorMessage = event.message;
      next.errorUntil = now + TIMINGS.errorHold;
      next.speaking = false;
      next.toolActive = false;
      next.pendingSuccess = false;
      break;
  }

  return next;
};

/** Derive the phase from the facts, highest priority first. */
export const resolvePhase = (ctx: MachineContext, now: number): HermesOwletPhase => {
  if (ctx.errorActive && now < ctx.errorUntil) return 'error';
  if (now < ctx.interruptedUntil) return 'interrupted';
  if (!ctx.connected) return 'offline';
  if (now < ctx.wakingUntil) return 'waking';
  if (ctx.speaking) return 'speaking';
  if (ctx.toolActive) return 'tool_use';
  if (ctx.listening) return 'listening';
  if (ctx.running) return 'thinking';
  if (now < ctx.successUntil) return 'success';
  return 'idle';
};

export type PhaseListener = (phase: HermesOwletPhase, ctx: MachineContext) => void;

/**
 * Stateful wrapper. Holds the context, applies the dwell rule, and notifies
 * listeners only when the visible phase actually changes.
 */
export class HermesOwletMachine {
  private ctx: MachineContext;
  private phase: HermesOwletPhase;
  private phaseSince: number;
  private listeners = new Set<PhaseListener>();

  constructor(connected = false, now: number = Date.now()) {
    this.ctx = createContext(connected);
    this.phase = resolvePhase(this.ctx, now);
    this.phaseSince = now;
  }

  get context(): Readonly<MachineContext> {
    return this.ctx;
  }

  get currentPhase(): HermesOwletPhase {
    return this.phase;
  }

  get activeTool(): string | undefined {
    return this.ctx.activeTool;
  }

  subscribe(listener: PhaseListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  send(event: HermesEvent, now: number = Date.now()): HermesOwletPhase {
    this.ctx = reduce(this.ctx, event, now);
    return this.tick(now);
  }

  /**
   * Re-evaluate transient windows. Call from the rig loop so `waking`,
   * `success`, `interrupted` and `error` expire on their own.
   */
  tick(now: number = Date.now()): HermesOwletPhase {
    if (this.ctx.errorActive && now >= this.ctx.errorUntil) {
      this.ctx = { ...this.ctx, errorActive: false, errorMessage: undefined };
    }
    const wanted = resolvePhase(this.ctx, now);
    if (wanted === this.phase) return this.phase;

    // Upgrades are immediate; downgrades wait out the minimum dwell so a burst
    // of overlapping events cannot make the character stutter.
    const isUpgrade = PHASE_PRIORITY[wanted] > PHASE_PRIORITY[this.phase];
    if (!isUpgrade && now - this.phaseSince < TIMINGS.minDwell) return this.phase;

    this.phase = wanted;
    this.phaseSince = now;
    for (const listener of this.listeners) listener(this.phase, this.ctx);
    return this.phase;
  }

  /** Test/simulator hook: jump straight to a phase without an event. */
  forcePhase(phase: HermesOwletPhase, now: number = Date.now()): void {
    this.ctx = createContext(phase !== 'offline');
    switch (phase) {
      case 'listening':
        this.ctx.listening = true;
        break;
      case 'thinking':
        this.ctx.running = true;
        break;
      case 'tool_use':
        this.ctx.running = true;
        this.ctx.toolActive = true;
        this.ctx.activeTool = 'web_search';
        break;
      case 'speaking':
        this.ctx.speaking = true;
        break;
      case 'success':
        this.ctx.successUntil = now + TIMINGS.success;
        break;
      case 'interrupted':
        this.ctx.interruptedUntil = now + TIMINGS.interrupted;
        this.ctx.listening = true;
        break;
      case 'error':
        this.ctx.errorActive = true;
        this.ctx.errorUntil = now + TIMINGS.errorHold;
        break;
      case 'waking':
        this.ctx.wakingUntil = now + TIMINGS.waking;
        break;
      default:
        break;
    }
    this.phase = resolvePhase(this.ctx, now);
    this.phaseSince = now;
    for (const listener of this.listeners) listener(this.phase, this.ctx);
  }
}
