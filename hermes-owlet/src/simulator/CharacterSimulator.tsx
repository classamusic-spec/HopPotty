import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { HermesOwlet, type HermesOwletHandle } from '../character/HermesOwlet';
import type { MicroAnimation } from '../character/controllers/MicroAnimationController';
import {
  PHASE_LABELS,
  type HermesEmotion,
  type HermesOwletPhase,
  type HermesOwletState,
} from '../character/state/HermesOwletState';
import { HermesBridge, hermesEvents } from '../bridge/HermesBridge';
import { createSyntheticSpeech } from '../audio/SpeechMeter';
import './simulator.css';

const PHASES: HermesOwletPhase[] = [
  'offline',
  'waking',
  'idle',
  'listening',
  'thinking',
  'tool_use',
  'speaking',
  'success',
  'interrupted',
  'error',
];

const EMOTIONS: (HermesEmotion | 'auto')[] = [
  'auto',
  'neutral',
  'happy',
  'curious',
  'focused',
  'concerned',
];

const MICROS: MicroAnimation[] = [
  'doubleBlink',
  'curiousTilt',
  'tinyNod',
  'lookLeft',
  'lookRight',
  'sparkle',
  'successBounce',
  'interruptReaction',
  'wake',
  'sleep',
];

const SIZES = [64, 96, 128, 256, 512] as const;

/** A scripted Hermes session, so the event path can be exercised end to end. */
const SCRIPT: { at: number; label: string; run: (bridge: HermesBridge) => void }[] = [
  { at: 0, label: 'CONNECTED', run: (b) => b.send(hermesEvents.connected()) },
  { at: 1200, label: 'LISTENING_STARTED', run: (b) => b.send(hermesEvents.listeningStarted()) },
  { at: 3000, label: 'LISTENING_STOPPED', run: (b) => b.send(hermesEvents.listeningStopped()) },
  { at: 3100, label: 'RUN_STARTED', run: (b) => b.send(hermesEvents.runStarted()) },
  { at: 5000, label: 'TOOL_STARTED web_search', run: (b) => b.send(hermesEvents.toolStarted('web_search')) },
  { at: 7600, label: 'TOOL_FINISHED ok', run: (b) => b.send(hermesEvents.toolFinished(true)) },
  { at: 9000, label: 'SPEECH_STARTED', run: (b) => b.send(hermesEvents.speechStarted()) },
  { at: 15000, label: 'SPEECH_STOPPED', run: (b) => b.send(hermesEvents.speechStopped()) },
  { at: 15100, label: 'RUN_COMPLETE', run: (b) => b.send(hermesEvents.runComplete()) },
];

export function CharacterSimulator(): JSX.Element {
  const owlRef = useRef<HermesOwletHandle | null>(null);
  const bridge = useMemo(() => new HermesBridge(true), []);

  const [useBridge, setUseBridge] = useState(false);
  const [phase, setPhase] = useState<HermesOwletPhase>('idle');
  const [emotion, setEmotion] = useState<HermesEmotion | 'auto'>('auto');
  const [size, setSize] = useState<number>(320);
  const [dark, setDark] = useState(true);
  const [reduced, setReduced] = useState(false);
  const [showAll, setShowAll] = useState(false);

  const [speech, setSpeech] = useState(0);
  const [autoSpeech, setAutoSpeech] = useState(true);
  const [gazeX, setGazeX] = useState(0);
  const [gazeY, setGazeY] = useState(0);
  const [freeGaze, setFreeGaze] = useState(true);
  const [haloGlow, setHaloGlow] = useState<number | null>(null);
  const [phoneGlow, setPhoneGlow] = useState<number | null>(null);

  const [snapshot, setSnapshot] = useState<HermesOwletState | null>(null);
  const [fps, setFps] = useState(0);
  const [log, setLog] = useState<string[]>([]);

  const push = useCallback((line: string) => {
    setLog((prev) => [`${new Date().toLocaleTimeString()}  ${line}`, ...prev].slice(0, 14));
  }, []);

  // Frame counter, sampled once a second — never per frame into React.
  useEffect(() => {
    let frames = 0;
    let last = performance.now();
    let raf = 0;
    const tick = (now: number): void => {
      frames += 1;
      if (now - last >= 1000) {
        setFps(Math.round((frames * 1000) / (now - last)));
        frames = 0;
        last = now;
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, []);

  // Synthetic TTS amplitude while speaking.
  useEffect(() => {
    if (!autoSpeech) return;
    const speakingNow = useBridge ? bridge.phase === 'speaking' : phase === 'speaking';
    if (!speakingNow) {
      owlRef.current?.setSpeechLevel(0);
      return;
    }
    const wave = createSyntheticSpeech(3);
    const started = performance.now();
    let raf = 0;
    const tick = (now: number): void => {
      const level = wave((now - started) / 1000);
      owlRef.current?.setSpeechLevel(level);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(raf);
      owlRef.current?.setSpeechLevel(0);
    };
  }, [autoSpeech, phase, useBridge, bridge]);

  useEffect(() => {
    if (autoSpeech) return;
    owlRef.current?.setSpeechLevel(speech);
  }, [speech, autoSpeech]);

  useEffect(() => {
    if (freeGaze) owlRef.current?.releaseGaze();
    else owlRef.current?.setGaze(gazeX, gazeY);
  }, [gazeX, gazeY, freeGaze]);

  useEffect(() => {
    owlRef.current?.setOverride('haloGlow', haloGlow);
  }, [haloGlow]);

  useEffect(() => {
    owlRef.current?.setOverride('headphoneGlow', phoneGlow);
  }, [phoneGlow]);

  useEffect(() => {
    if (!useBridge) return;
    const off = bridge.onPhase((next) => push(`phase → ${PHASE_LABELS[next]}`));
    return off;
  }, [bridge, useBridge, push]);

  const runScript = useCallback(() => {
    setUseBridge(true);
    push('script: start');
    const timers = SCRIPT.map((step) =>
      setTimeout(() => {
        step.run(bridge);
        push(`event ${step.label}`);
      }, step.at),
    );
    return () => timers.forEach(clearTimeout);
  }, [bridge, push]);

  const selectPhase = (next: HermesOwletPhase): void => {
    setUseBridge(false);
    setPhase(next);
    push(`phase → ${PHASE_LABELS[next]}`);
  };

  return (
    <div className={`sim ${dark ? 'sim--dark' : 'sim--light'}`}>
      <header className="sim__head">
        <div>
          <h1>Hermes Owlet</h1>
          <p>Animated character head · state simulator</p>
        </div>
        <div className="sim__badge">
          <span className={fps >= 55 ? 'ok' : fps >= 40 ? 'warn' : 'bad'}>{fps} fps</span>
        </div>
      </header>

      <main className="sim__body">
        <section className="sim__stage">
          <div className="sim__owl" style={{ width: size, height: size }}>
            <HermesOwlet
              ref={owlRef}
              phase={phase}
              bridge={useBridge ? bridge : undefined}
              emotion={emotion === 'auto' ? null : emotion}
              reducedMotion={reduced || 'auto'}
              onState={setSnapshot}
            />
          </div>

          {showAll ? (
            <div className="sim__sizes">
              {SIZES.map((s) => (
                <div key={s} className="sim__size">
                  <div style={{ width: s, height: s }}>
                    <HermesOwlet
                      phase={useBridge ? undefined : phase}
                      bridge={useBridge ? bridge : undefined}
                      emotion={emotion === 'auto' ? null : emotion}
                      reducedMotion={reduced || 'auto'}
                      title={null}
                    />
                  </div>
                  <span>{s}px</span>
                </div>
              ))}
            </div>
          ) : null}

          <div className="sim__stagebar">
            <label>
              Preview
              <input
                type="range"
                min={64}
                max={512}
                step={8}
                value={size}
                onChange={(e) => setSize(Number(e.target.value))}
              />
              <b>{size}px</b>
            </label>
            <button type="button" onClick={() => setDark((v) => !v)}>
              {dark ? 'Light bg' : 'Dark bg'}
            </button>
            <button type="button" onClick={() => setShowAll((v) => !v)}>
              {showAll ? 'Hide icon sizes' : 'Icon sizes 64–512'}
            </button>
          </div>
        </section>

        <aside className="sim__panel">
          <fieldset>
            <legend>Phase</legend>
            <div className="grid grid--phases">
              {PHASES.map((p) => (
                <button
                  key={p}
                  type="button"
                  className={!useBridge && phase === p ? 'is-active' : ''}
                  onClick={() => selectPhase(p)}
                >
                  {PHASE_LABELS[p].toUpperCase()}
                </button>
              ))}
            </div>
            <div className="row">
              <button type="button" onClick={runScript}>
                Run Hermes event script
              </button>
              <span className="hint">{useBridge ? 'driven by bridge' : 'driven manually'}</span>
            </div>
          </fieldset>

          <fieldset>
            <legend>Emotion</legend>
            <div className="grid grid--emotions">
              {EMOTIONS.map((e) => (
                <button
                  key={e}
                  type="button"
                  className={emotion === e ? 'is-active' : ''}
                  onClick={() => setEmotion(e)}
                >
                  {e}
                </button>
              ))}
            </div>
          </fieldset>

          <fieldset>
            <legend>Speech</legend>
            <label className="check">
              <input
                type="checkbox"
                checked={autoSpeech}
                onChange={(e) => setAutoSpeech(e.target.checked)}
              />
              Synthetic TTS amplitude
            </label>
            <label className="slider">
              Speech level
              <input
                type="range"
                min={0}
                max={1}
                step={0.01}
                value={speech}
                disabled={autoSpeech}
                onChange={(e) => setSpeech(Number(e.target.value))}
              />
              <b>{speech.toFixed(2)}</b>
            </label>
            <p className="hint">The beak follows amplitude only while SPEAKING.</p>
          </fieldset>

          <fieldset>
            <legend>Eyes</legend>
            <label className="check">
              <input
                type="checkbox"
                checked={freeGaze}
                onChange={(e) => setFreeGaze(e.target.checked)}
              />
              Autonomous gaze
            </label>
            <label className="slider">
              Gaze X
              <input
                type="range"
                min={-1}
                max={1}
                step={0.01}
                value={gazeX}
                disabled={freeGaze}
                onChange={(e) => setGazeX(Number(e.target.value))}
              />
              <b>{gazeX.toFixed(2)}</b>
            </label>
            <label className="slider">
              Gaze Y
              <input
                type="range"
                min={-1}
                max={1}
                step={0.01}
                value={gazeY}
                disabled={freeGaze}
                onChange={(e) => setGazeY(Number(e.target.value))}
              />
              <b>{gazeY.toFixed(2)}</b>
            </label>
            <div className="row">
              <button type="button" onClick={() => owlRef.current?.blink()}>
                Blink
              </button>
              <button type="button" onClick={() => owlRef.current?.doubleBlink()}>
                Double blink
              </button>
            </div>
          </fieldset>

          <fieldset>
            <legend>Glow</legend>
            <label className="slider">
              Halo glow
              <input
                type="range"
                min={0}
                max={1}
                step={0.01}
                value={haloGlow ?? 0}
                onChange={(e) => setHaloGlow(Number(e.target.value))}
              />
              <b>{haloGlow === null ? 'auto' : haloGlow.toFixed(2)}</b>
            </label>
            <label className="slider">
              Headphone glow
              <input
                type="range"
                min={0}
                max={1}
                step={0.01}
                value={phoneGlow ?? 0}
                onChange={(e) => setPhoneGlow(Number(e.target.value))}
              />
              <b>{phoneGlow === null ? 'auto' : phoneGlow.toFixed(2)}</b>
            </label>
            <div className="row">
              <button
                type="button"
                onClick={() => {
                  setHaloGlow(null);
                  setPhoneGlow(null);
                }}
              >
                Follow phase
              </button>
            </div>
          </fieldset>

          <fieldset>
            <legend>Micro-animations</legend>
            <div className="grid grid--micros">
              {MICROS.map((m) => (
                <button key={m} type="button" onClick={() => owlRef.current?.play(m)}>
                  {m}
                </button>
              ))}
            </div>
          </fieldset>

          <fieldset>
            <legend>Accessibility</legend>
            <label className="check">
              <input
                type="checkbox"
                checked={reduced}
                onChange={(e) => setReduced(e.target.checked)}
              />
              Force reduced motion
            </label>
            <p className="hint">
              Unchecked, the character follows <code>prefers-reduced-motion</code>. Reduced motion
              stops floating, gaze drift, halo motion and wing sway; blinking, beak articulation and
              every state change stay.
            </p>
          </fieldset>

          <fieldset>
            <legend>Live state</legend>
            <pre className="sim__state">
              {snapshot
                ? [
                    `phase        ${snapshot.phase}`,
                    `emotion      ${snapshot.emotion}`,
                    `gaze         ${snapshot.gazeX.toFixed(2)}, ${snapshot.gazeY.toFixed(2)}`,
                    `blink        ${snapshot.blinkAmount.toFixed(2)}`,
                    `headY/tilt   ${snapshot.headY.toFixed(2)} / ${snapshot.headTilt.toFixed(2)}°`,
                    `halo         rot ${snapshot.haloRotation.toFixed(0)}° glow ${snapshot.haloGlow.toFixed(2)}`,
                    `headphones   ${snapshot.headphoneGlow.toFixed(2)}`,
                    `wings        ${snapshot.wingLift.toFixed(2)}°`,
                    `speech/beak  ${snapshot.speechLevel.toFixed(2)} / ${snapshot.beakOpen.toFixed(2)}`,
                  ].join('\n')
                : 'waiting…'}
            </pre>
          </fieldset>

          <fieldset>
            <legend>Event log</legend>
            <ul className="sim__log">
              {log.map((line, i) => (
                <li key={`${line}-${i}`}>{line}</li>
              ))}
            </ul>
          </fieldset>
        </aside>
      </main>
    </div>
  );
}
