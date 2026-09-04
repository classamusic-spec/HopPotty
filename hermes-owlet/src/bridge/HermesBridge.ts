import {
  HermesOwletMachine,
  type HermesEvent,
} from '../character/state/HermesOwletMachine';
import type { HermesOwletPhase } from '../character/state/HermesOwletState';

export type PhaseHandler = (phase: HermesOwletPhase) => void;
export type SpeechHandler = (level: number) => void;

/**
 * The seam between the Hermes agent and the character.
 *
 * Everything Hermes emits is normalised into `HermesEvent` before it reaches
 * the machine, so the character has no idea what a run, a tool call or a TTS
 * chunk actually is. Speech amplitude bypasses the machine entirely: it is a
 * continuous signal and belongs on the beak, not in the phase.
 */
export class HermesBridge {
  readonly machine: HermesOwletMachine;

  private phaseHandlers = new Set<PhaseHandler>();
  private speechHandlers = new Set<SpeechHandler>();
  private timer: ReturnType<typeof setInterval> | null = null;

  constructor(connected = false) {
    this.machine = new HermesOwletMachine(connected);
    this.machine.subscribe((phase) => {
      for (const handler of this.phaseHandlers) handler(phase);
    });
  }

  /** Feed one normalised event. Returns the phase it resolved to. */
  send(event: HermesEvent): HermesOwletPhase {
    if (event.type === 'SPEECH_LEVEL') {
      for (const handler of this.speechHandlers) handler(event.level);
      return this.machine.currentPhase;
    }
    if (event.type === 'SPEECH_STOPPED' || event.type === 'INTERRUPTED') {
      for (const handler of this.speechHandlers) handler(0);
    }
    return this.machine.send(event);
  }

  onPhase(handler: PhaseHandler): () => void {
    this.phaseHandlers.add(handler);
    this.ensureTicking();
    return () => {
      this.phaseHandlers.delete(handler);
      this.maybeStopTicking();
    };
  }

  onSpeechLevel(handler: SpeechHandler): () => void {
    this.speechHandlers.add(handler);
    return () => this.speechHandlers.delete(handler);
  }

  get phase(): HermesOwletPhase {
    return this.machine.currentPhase;
  }

  get activeTool(): string | undefined {
    return this.machine.activeTool;
  }

  /** Jump straight to a phase. For the simulator and for tests only. */
  forcePhase(phase: HermesOwletPhase): void {
    this.machine.forcePhase(phase);
  }

  dispose(): void {
    this.phaseHandlers.clear();
    this.speechHandlers.clear();
    this.maybeStopTicking();
  }

  /**
   * Transient phases (`waking`, `success`, `interrupted`, `error`) expire on a
   * clock rather than on an event, so the machine needs a heartbeat. 30 ms is
   * fine-grained enough for the 180 ms interrupt window and costs nothing.
   */
  private ensureTicking(): void {
    if (this.timer !== null) return;
    this.timer = setInterval(() => this.machine.tick(), 30);
  }

  private maybeStopTicking(): void {
    if (this.phaseHandlers.size > 0 || this.timer === null) return;
    clearInterval(this.timer);
    this.timer = null;
  }
}

/** Convenience helpers for the common Hermes call sites. */
export const hermesEvents = {
  connected: (): HermesEvent => ({ type: 'CONNECTED' }),
  disconnected: (): HermesEvent => ({ type: 'DISCONNECTED' }),
  listeningStarted: (): HermesEvent => ({ type: 'LISTENING_STARTED' }),
  listeningStopped: (): HermesEvent => ({ type: 'LISTENING_STOPPED' }),
  runStarted: (): HermesEvent => ({ type: 'RUN_STARTED' }),
  textDelta: (text: string): HermesEvent => ({ type: 'TEXT_DELTA', text }),
  toolStarted: (tool?: string): HermesEvent => ({ type: 'TOOL_STARTED', tool }),
  toolFinished: (success: boolean): HermesEvent => ({ type: 'TOOL_FINISHED', success }),
  speechStarted: (): HermesEvent => ({ type: 'SPEECH_STARTED' }),
  speechLevel: (level: number): HermesEvent => ({ type: 'SPEECH_LEVEL', level }),
  speechStopped: (): HermesEvent => ({ type: 'SPEECH_STOPPED' }),
  interrupted: (): HermesEvent => ({ type: 'INTERRUPTED' }),
  runComplete: (): HermesEvent => ({ type: 'RUN_COMPLETE' }),
  error: (message?: string): HermesEvent => ({ type: 'ERROR', message }),
} as const;
