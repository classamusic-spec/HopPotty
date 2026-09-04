import {
  forwardRef,
  useCallback,
  useEffect,
  useImperativeHandle,
  useLayoutEffect,
  useRef,
  useState,
} from 'react';
import type { MicroAnimation } from './controllers/MicroAnimationController';
import { HermesOwletRig } from './rig/HermesOwletRig';
import { collectRigNodes } from './rig/RigNodes';
import type { HermesEmotion, HermesOwletPhase, HermesOwletState } from './state/HermesOwletState';
import { HermesOwletSVG } from './svg/HermesOwletSVG';
import type { HermesBridge } from '../bridge/HermesBridge';

export interface HermesOwletHandle {
  setSpeechLevel(level: number): void;
  setGaze(x: number, y: number): void;
  releaseGaze(): void;
  blink(): void;
  doubleBlink(): void;
  play(animation: MicroAnimation): void;
  /** Pin a glow for debugging; `null` hands it back to the phase. */
  setOverride(key: 'haloGlow' | 'headphoneGlow', value: number | null): void;
  getState(): Readonly<HermesOwletState> | null;
}

export interface HermesOwletProps {
  /** Ignored when a `bridge` is supplied — the bridge owns the phase then. */
  phase?: HermesOwletPhase;
  /** Overrides the phase's default emotion. */
  emotion?: HermesEmotion | null;
  /** Convenience for callers without an audio meter. Prefer the handle. */
  speechLevel?: number;
  /** Point the pupils somewhere; `null` hands control back to the drift. */
  gaze?: { x: number; y: number } | null;
  /** A Hermes event source. When present, `phase` is derived from its events. */
  bridge?: HermesBridge;
  size?: number | string;
  className?: string;
  title?: string | null;
  /** `'auto'` follows `prefers-reduced-motion`. */
  reducedMotion?: boolean | 'auto';
  /** Seed the idle randomness for reproducible captures. */
  seed?: number;
  /** ~12 Hz debug snapshot. Do not drive rendering from this. */
  onState?: (state: Readonly<HermesOwletState>) => void;
  onPhaseChange?: (phase: HermesOwletPhase) => void;
}

const usePrefersReducedMotion = (enabled: boolean): boolean => {
  const [value, setValue] = useState(false);
  useEffect(() => {
    if (!enabled || typeof window === 'undefined' || !window.matchMedia) return;
    const query = window.matchMedia('(prefers-reduced-motion: reduce)');
    setValue(query.matches);
    const onChange = (event: MediaQueryListEvent): void => setValue(event.matches);
    query.addEventListener('change', onChange);
    return () => query.removeEventListener('change', onChange);
  }, [enabled]);
  return value;
};

/**
 * The Hermes Owlet head.
 *
 * React holds the phase, the emotion and nothing else. Every animated value is
 * interpolated inside the rig and written straight to SVG attributes, so this
 * component re-renders only when the character's high-level state changes —
 * never at frame rate.
 */
export const HermesOwlet = forwardRef<HermesOwletHandle, HermesOwletProps>(
  function HermesOwlet(props, ref) {
    const {
      phase = 'idle',
      emotion = null,
      speechLevel,
      gaze,
      bridge,
      size,
      className,
      title = 'Hermes Owlet',
      reducedMotion = 'auto',
      seed,
      onState,
      onPhaseChange,
    } = props;

    const svgRef = useRef<SVGSVGElement | null>(null);
    const rigRef = useRef<HermesOwletRig | null>(null);
    const onStateRef = useRef(onState);
    onStateRef.current = onState;

    const prefersReduced = usePrefersReducedMotion(reducedMotion === 'auto');
    const reduced = reducedMotion === 'auto' ? prefersReduced : reducedMotion;

    const [bridgePhase, setBridgePhase] = useState<HermesOwletPhase | null>(null);
    const activePhase = bridge ? (bridgePhase ?? bridge.machine.currentPhase) : phase;

    // Build the rig once the SVG is in the document.
    useLayoutEffect(() => {
      const svg = svgRef.current;
      if (!svg) return;
      const rig = new HermesOwletRig(collectRigNodes(svg), {
        reducedMotion: reduced,
        seed,
        onState: (state) => onStateRef.current?.(state),
      });
      rigRef.current = rig;
      rig.setPhase(activePhase);
      rig.start();
      return () => {
        rig.stop();
        rigRef.current = null;
      };
      // The rig is rebuilt only if the art itself is replaced.
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [seed]);

    // Pause while the tab is hidden — a companion should not burn a core in
    // the background.
    useEffect(() => {
      const onVisibility = (): void => {
        const rig = rigRef.current;
        if (!rig) return;
        if (document.hidden) rig.stop();
        else rig.start();
      };
      document.addEventListener('visibilitychange', onVisibility);
      return () => document.removeEventListener('visibilitychange', onVisibility);
    }, []);

    useEffect(() => {
      rigRef.current?.setReducedMotion(reduced);
    }, [reduced]);

    useEffect(() => {
      rigRef.current?.setPhase(activePhase);
      onPhaseChange?.(activePhase);
    }, [activePhase, onPhaseChange]);

    useEffect(() => {
      rigRef.current?.setEmotion(emotion);
    }, [emotion]);

    useEffect(() => {
      if (speechLevel === undefined) return;
      rigRef.current?.setSpeechLevel(speechLevel);
    }, [speechLevel]);

    useEffect(() => {
      const rig = rigRef.current;
      if (!rig) return;
      if (gaze) rig.setGaze(gaze.x, gaze.y);
      else if (gaze === null) rig.releaseGaze();
    }, [gaze]);

    // Bridge wiring: phase from the machine, amplitude straight to the beak.
    useEffect(() => {
      if (!bridge) return;
      setBridgePhase(bridge.machine.currentPhase);
      const offPhase = bridge.onPhase((next) => setBridgePhase(next));
      const offLevel = bridge.onSpeechLevel((level) => rigRef.current?.setSpeechLevel(level));
      return () => {
        offPhase();
        offLevel();
      };
    }, [bridge]);

    useImperativeHandle(
      ref,
      (): HermesOwletHandle => ({
        setSpeechLevel: (level) => rigRef.current?.setSpeechLevel(level),
        setGaze: (x, y) => rigRef.current?.setGaze(x, y),
        releaseGaze: () => rigRef.current?.releaseGaze(),
        blink: () => rigRef.current?.blink(),
        doubleBlink: () => rigRef.current?.doubleBlink(),
        play: (animation) => rigRef.current?.play(animation),
        setOverride: (key, value) => rigRef.current?.setOverride(key, value),
        getState: () => rigRef.current?.getState() ?? null,
      }),
      [],
    );

    const setSvg = useCallback((node: SVGSVGElement | null) => {
      svgRef.current = node;
    }, []);

    return <HermesOwletSVG ref={setSvg} size={size} className={className} title={title} />;
  },
);
