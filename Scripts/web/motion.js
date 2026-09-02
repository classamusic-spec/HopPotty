/**
 * The prototype's motion layer.
 *
 * HopPotty's motion vocabulary is defined once, in Swift, in
 * `HopPottyKit/Sources/HopPottyDesignTokens/HopMotion.swift`. Every number in
 * `M` below is copied from it and named the same, so a reviewer can hold the two
 * files side by side. Nothing here invents a duration.
 *
 * Three rules shape the implementation:
 *
 *  1. **`prefers-reduced-motion: reduce` turns all of it off.** Every animation
 *     becomes a 0.20s cross-fade (`reducedMotionFade`) or nothing at all, and
 *     the prototype stays completely usable — the jump-then-advance beat
 *     advances immediately instead of waiting for a jump nobody will see.
 *  2. **Only `transform` and `opacity` animate.** Nothing here can cause layout.
 *  3. **Only the visible screen moves.** Every ambient rule is gated behind
 *     `.screen.on`, hidden screens are `display:none` so they have no box to
 *     animate, and the JS timers (blink, gaze) are started on the screen that is
 *     shown and cleared on the screen that leaves.
 *
 * And one rule from `Docs/ChildSafety.md`: nothing escalates. No loop grows to
 * recapture a wandering eye, no beat repeats itself louder, and the three
 * outcome answers on `08-routine-step3` are animated by one identical code path
 * so "I tried" cannot be celebrated less than "I peed".
 */

// ---------------------------------------------------------------------------
// The tokens, mirrored from HopMotion.swift
// ---------------------------------------------------------------------------

const M = {
  // Ambient character motion
  breathePeriod: 3.4,
  blinkInterval: [2.8, 6.5],
  blinkDuration: 0.14,

  // Hop's jump, four beats
  jumpCrouch: 0.14,
  jumpRise: 0.26,
  jumpHang: 0.06,
  jumpFall: 0.22,
  jumpSettle: 0.46,
  jumpHeightRatio: 0.34,
  jumpStretch: 1.07,
  jumpSquash: 0.90,

  // Pond ambience. Deliberately non-harmonic: the layers never resynchronise.
  pondRipplePeriod: 7.3,
  pondLilyBobPeriod: 5.9,
  pondReedSwayPeriod: 6.7,
  pondCloudDriftPeriod: 41.0,
  pondFishPeriod: 17.0,
  pondDragonflyPeriod: 11.3,
  pondShimmerPeriod: 9.1,
  pondBobDistance: 3.5,
  pondSwayDegrees: 2.4,

  // Surfaces and transitions
  pressScale: 0.97,
  childPressScale: 0.94,
  press: [0.18, 0.0],
  release: [0.34, 0.30],
  pagePush: [0.38, 0.04],
  childPage: [0.52, 0.22],
  parentSheet: [0.42, 0.08],
  pageParallax: 0.28,

  // Springs the beats above are timed against
  childTap: [0.30, 0.34],
  childArrive: [0.55, 0.28],
  childCelebrate: [0.70, 0.42],

  stagger: 0.045,
  staggerCap: 0.36,
  reducedMotionFade: 0.20,
  celebrationMaxDuration: 3.5,
};

/** One full hop, crouch through settle — `HopMotion.jumpDuration`. */
const JUMP = M.jumpCrouch + M.jumpRise + M.jumpHang + M.jumpFall + M.jumpSettle;   // 1.14s

/**
 * A SwiftUI `duration/bounce` spring as the nearest cubic-bézier.
 *
 * CSS has no springs, so this is an approximation and is allowed to be one: the
 * *duration* is exact (that is what makes the web and the app feel like the same
 * product) and the bounce becomes overshoot in the curve's second control point.
 * `bounce: 0` is a plain ease-out; every 0.1 of bounce buys 0.16 of overshoot,
 * which lands 0.22 (`childPage`) at a clear but unsilly 1.35.
 */
function ease(bounce) {
  if (!bounce) return 'cubic-bezier(.33,0,.2,1)';
  return `cubic-bezier(.34,${(1 + bounce * 1.6).toFixed(3)},.42,1)`;
}
const spring = ([d, b]) => `${d}s ${ease(b)}`;

// ---------------------------------------------------------------------------
// Deriving one drawing from another
// ---------------------------------------------------------------------------

/**
 * Hop is fifteen finished drawings, not a rig — the app swaps poses, it does not
 * tween them. But blinking, smiling, talking and looking are all *one feature of
 * one drawing* changing, and there is no fifteen-times-four set of files.
 *
 * So these four rules edit the eye group and the mouth group in place, in the
 * markup the artist already drew. They are not new art: applying `blink` to
 * `hop-idle.svg` reproduces `hop-blink.svg` byte for byte, which is the proof
 * that the substitution is the one the artist made by hand. `build-prototype.js`
 * asserts exactly that on every build.
 *
 * Each is self-contained (its own regexes, no closure state) because the same
 * source is stringified into the page and run in the browser, where the base
 * drawing is already inlined and no second file needs fetching.
 */
const FRAME = {
  /** Eyes closed: the whole eye group replaced by the closed-lid arc. */
  blink: function (svg) {
    return svg.replace(
      /<g>\s*<clipPath id="eyeClip[^"]*"><circle cx="([\d.]+)" cy="([\d.]+)"[^>]*\/><\/clipPath>[\s\S]*?<\/g>\s*<\/g>/g,
      function (_m, cx, cy) {
        var x = parseFloat(cx), y = parseFloat(cy);
        return '<path d="M ' + (x - 10) + ' ' + (y + 3) + ' Q ' + x + ' ' + (y + 12) +
          ' ' + (x + 10) + ' ' + (y + 3) + '"\n        fill="none" stroke="#1B5E39" ' +
          'stroke-width="3.2" stroke-linecap="round"/>';
      });
  },

  /** Pupils moved inside their clip, so Hop looks somewhere. */
  gaze: function (svg, dx, dy) {
    return svg.replace(/<g clip-path="url\(#eyeClip[^"]*\)">([\s\S]*?)<\/g>/g, function (m, inner) {
      var moved = inner
        .replace(/cx="([\d.]+)"/g, function (_c, v) { return 'cx="' + (parseFloat(v) + dx).toFixed(2) + '"'; })
        .replace(/cy="([\d.]+)"/g, function (_c, v) { return 'cy="' + (parseFloat(v) + dy).toFixed(2) + '"'; });
      return m.replace(inner, moved);
    });
  },

  /** The open mouth replaced by the closed smile Hop wears in `hop-sleep.svg`. */
  smile: function (svg) {
    return svg.replace(
      /<g transform="translate\(75 50\) scale\([\d.]+\) translate\(-75 -50\)">[\s\S]*?<\/g>/g,
      '<path d="M 58 50 Q 75 58 92 50" fill="none" stroke="#1B5E39" stroke-width="3.4" stroke-linecap="round"/>');
  },

  /** The mouth group at a different openness. 1 is wide, 0.72 is Hop talking. */
  mouth: function (svg, k) {
    return svg.replace(/(<g transform="translate\(75 50\) scale\()[\d.]+(\) translate\(-75 -50\)">)/g,
      '$1' + k + '$2');
  },
};

/** The extra frames each pose needs, and how each one is made. */
const VARIANTS = {
  blink: (s) => FRAME.blink(s),
  smile: (s) => FRAME.smile(s),
  gazeL: (s) => FRAME.gaze(s, -4.2, 1.2),
  gazeR: (s) => FRAME.gaze(s, 4.2, 1.2),
  gazeD: (s) => FRAME.gaze(s, 0, 4.2),
  talkShut: (s) => FRAME.mouth(s, 0.26),
};

/**
 * Which extra frames each pose gets.
 *
 * Not every pose needs every frame — a walking Hop has no reason to gaze at a
 * button, and `sleep` has his eyes shut already — and every frame that is not
 * asked for is a drawing the browser never has to hold.
 */
const POSE_FRAMES = {
  idle: ['blink', 'smile', 'gazeL', 'gazeR', 'gazeD'],
  wait: ['blink', 'smile', 'gazeL', 'gazeR', 'gazeD'],
  sit: ['blink', 'smile', 'gazeD'],
  talk: ['blink', 'smile', 'talkShut'],
  wave: ['blink', 'smile', 'talkShut'],
  cheer: ['blink', 'smile'],
  walk: ['blink', 'talkShut'],
  scrub: ['blink'],
  catch: ['blink'],
  land: ['blink', 'smile'],
  full: ['blink'],
  face: ['blink', 'gazeL', 'gazeR', 'talkShut'],
  jump: [],
  sleep: [],
  blink: [],
};

/**
 * The ambient loop each pose carries, as a CSS class.
 *
 * A pose is a claim about what Hop is doing, and the motion has to agree with
 * it: `walk` lilts, `scrub` scrubs, `sleep` breathes slowly and never blinks.
 * Anything unlisted just breathes.
 */
const POSE_ANIM = {
  walk: 'hp-a-walk', scrub: 'hp-a-scrub', cheer: 'hp-a-cheer',
  sleep: 'hp-a-sleep', catch: 'hp-a-catch', full: 'hp-a-full',
};

// ---------------------------------------------------------------------------
// CSS
// ---------------------------------------------------------------------------

/**
 * Where motion is allowed to run.
 *
 * `.screen.on` is the one screen the prototype is showing; every other screen in
 * the document is `display:none` and has no animation declared on it at all.
 * `.hopcell.playing` is a gallery tile that is currently on screen — the states
 * gallery is the deliberate exception to "one screen at a time", and an
 * IntersectionObserver takes `playing` off the tiles that scroll away.
 */
const LIVE = ['body.proto .screen.on', '.hopcell.playing'];
const on = (suffix) => LIVE.map((p) => `${p} ${suffix}`).join(',\n');

/** `t` seconds as a percentage of a `total`-second timeline. */
const at = (t, total) => `${(t / total * 100).toFixed(3)}%`;

/**
 * Hop's jump, as keyframes.
 *
 * Four beats, not one curve — the whole point of splitting them in
 * `HopMotion.swift` is that the squash on take-off and the squash on landing
 * differ, which is the difference between a character that jumps and a picture
 * that moves up. `rest` pads a still tail on the end so the gallery tile can
 * loop the same motion without it reading as a machine.
 */
function jumpFrames(name, rest = 0) {
  const total = JUMP + rest;
  const t0 = 0;
  const t1 = M.jumpCrouch;                                   // crouched
  const t2 = t1 + M.jumpRise;                                // apex
  const t3 = t2 + M.jumpHang;                                // hang over
  const t4 = t3 + M.jumpFall;                                // touchdown
  const up = -(M.jumpHeightRatio * 100);                     // 34% of Hop's height
  const sq = M.jumpSquash, st = M.jumpStretch;
  const sqX = (1 / sq).toFixed(3), stX = (1 / st).toFixed(3);   // volume, roughly kept
  return `@keyframes ${name}{
  ${at(t0, total)}{transform:translateY(0) scale(1,1);animation-timing-function:${ease(0)}}
  ${at(t1, total)}{transform:translateY(0) scale(${sqX},${sq});animation-timing-function:${ease(0.12)}}
  ${at(t2, total)}{transform:translateY(${up}%) scale(${stX},${st});animation-timing-function:linear}
  ${at(t3, total)}{transform:translateY(${up}%) scale(.975,1.03);animation-timing-function:cubic-bezier(.6,0,.85,.6)}
  ${at(t4 - 0.03, total)}{transform:translateY(-1.5%) scale(1,1)}
  ${at(t4, total)}{transform:translateY(0) scale(${sqX},${sq});animation-timing-function:${ease(0.46)}}
  ${at(t4 + M.jumpSettle * 0.26, total)}{transform:translateY(-5%) scale(.972,1.046)}
  ${at(t4 + M.jumpSettle * 0.55, total)}{transform:translateY(0) scale(1.016,.978)}
  ${at(t4 + M.jumpSettle * 0.8, total)}{transform:translateY(-1.4%) scale(.994,1.011)}
  ${at(t4 + M.jumpSettle, total)},100%{transform:translateY(0) scale(1,1)}
}`;
}

/**
 * Hello, in three beats.
 *
 * Wind-up, wave, settle — a wave that starts mid-air is a loop, not a greeting.
 * Hop's raised arm is drawn into `hop-wave.svg`, so the wave itself is the body
 * rocking under it; the anticipation is the small counter-lean before the first
 * swing, and the settle is the return to a rest the breathing takes back over.
 */
const WAVE = 1.62;
function waveFrames(name, rest = 0) {
  const total = WAVE + rest;
  return `@keyframes ${name}{
  0%{transform:rotate(0deg) translateY(0)}
  ${at(0.18, total)}{transform:rotate(-3.4deg) translateY(1%);animation-timing-function:${ease(0.1)}}
  ${at(0.42, total)}{transform:rotate(7deg) translateY(-1.5%)}
  ${at(0.66, total)}{transform:rotate(0.5deg) translateY(0)}
  ${at(0.9, total)}{transform:rotate(6deg) translateY(-1.2%)}
  ${at(1.14, total)}{transform:rotate(1deg) translateY(0)}
  ${at(1.34, total)}{transform:rotate(3.4deg) translateY(-.4%)}
  ${at(WAVE, total)},100%{transform:rotate(0deg) translateY(0)}
}`;
}

function motionCSS() {
  const bob = M.pondBobDistance, sway = M.pondSwayDegrees;
  const par = (M.pageParallax * 100).toFixed(0);
  const fade = M.reducedMotionFade;

  return `
/* =========================================================================
   MOTION
   Every duration below is HopMotion.swift's. See Scripts/web/motion.js.
   ========================================================================= */

/* ---- Hop ---------------------------------------------------------------
   .hop is a wrapper the runtime puts *inside* every [data-hop], so the
   screen's own positioning transform (translateX(-50%) and friends) is never
   fought over: the screen owns [data-hop], the motion layer owns .hop. */
.hop{position:relative;display:block;transform-origin:50% 100%}
.hop-ov{position:absolute;left:0;top:0;opacity:0;pointer-events:none}

@keyframes hp-breathe{
  0%,100%{transform:scale(1,1)}
  50%{transform:scale(.9955,1.014)}
}
@keyframes hp-a-walk{
  0%,100%{transform:translateY(0) rotate(-1.2deg)}
  50%{transform:translateY(-1.6%) rotate(1.2deg)}
}
@keyframes hp-a-scrub{
  0%,100%{transform:translate(-1.1%,0) rotate(-1.4deg)}
  50%{transform:translate(1.1%,-.8%) rotate(1.4deg)}
}
@keyframes hp-a-cheer{
  0%,100%{transform:translateY(0) scale(1,1)}
  42%{transform:translateY(-3.2%) scale(.986,1.024)}
  70%{transform:translateY(0) scale(1.012,.99)}
}
@keyframes hp-a-catch{
  0%,100%{transform:translateY(0) rotate(0deg)}
  55%{transform:translateY(-1%) rotate(2.2deg)}
}
@keyframes hp-a-full{
  0%,100%{transform:rotate(-1deg) scale(1,1)}
  50%{transform:rotate(1deg) scale(1.006,.994)}
}
${jumpFrames('hp-jump')}
${jumpFrames('hp-jump-loop', 1.9)}
${waveFrames('hp-wave')}
${waveFrames('hp-wave-loop', 2.1)}
/* The "he noticed you" beat: one childTap-sized pop, and it never repeats
   itself. It is deliberately a fifth of the celebration, not a small one. */
@keyframes hp-react{
  0%{transform:translateY(0) scale(1,1)}
  38%{transform:translateY(-2.6%) scale(.978,1.034)}
  100%{transform:translateY(0) scale(1,1)}
}
/* Hop's mouth, opening and closing on a line. Steps, never a tween — the app
   swaps drawings and so does this. */
@keyframes hp-talk{0%,49.9%{opacity:0}50%,100%{opacity:1}}

${on('.hop')}{animation:hp-breathe ${M.breathePeriod}s ease-in-out infinite}
${on('.hop.hp-a-walk')}{animation:hp-a-walk .92s ease-in-out infinite}
${on('.hop.hp-a-scrub')}{animation:hp-a-scrub .66s ease-in-out infinite}
${on('.hop.hp-a-cheer')}{animation:hp-a-cheer 1.15s ease-in-out infinite}
${on('.hop.hp-a-catch')}{animation:hp-a-catch 2.1s ease-in-out infinite}
${on('.hop.hp-a-full')}{animation:hp-a-full 4.4s ease-in-out infinite}
/* Asleep: the same breath, slowed by three quarters and shallower. */
${on('.hop.hp-a-sleep')}{animation:hp-breathe ${(M.breathePeriod * 1.75).toFixed(2)}s ease-in-out infinite}

${on('.hop.hp-jump')}{animation:hp-jump ${JUMP}s both}
${on('.hop.hp-jump-loop')}{animation:hp-jump-loop ${(JUMP + 1.9).toFixed(2)}s infinite}
${on('.hop.hp-wave')}{animation:hp-wave ${WAVE}s both}
${on('.hop.hp-wave-loop')}{animation:hp-wave-loop ${(WAVE + 2.1).toFixed(2)}s infinite}
${on('.hop.hp-react')}{animation:hp-react ${M.childTap[0]}s ${ease(M.childTap[1])} both}

/* Gaze and smile cross-fade; a blink is a hard cut, because an eyelid is. */
${on('.hop-ov[data-v="gazeL"]')},
${on('.hop-ov[data-v="gazeR"]')},
${on('.hop-ov[data-v="gazeD"]')},
${on('.hop-ov[data-v="smile"]')}{transition:opacity .42s ease}
${on('.hop-ov[data-v="talkShut"].hp-talking')}{animation:hp-talk .3s steps(1,end) var(--hp-talk-beats,8)}

/* ---- Pond ---------------------------------------------------------------
   Seven periods, none a multiple of another, so the layers never resynchronise
   into one visible pulse. Slow and small on purpose: a pond that reads as calm
   is doing its job, and nothing in it is a reward, so nothing demands watching.
   Every selector matches a *suffix* because build-prototype.js namespaces every
   id per screen. An id that does not exist simply matches nothing. */
@keyframes hp-ripple{
  0%,100%{transform:translateX(0);opacity:.85}
  50%{transform:translateX(7px);opacity:1}
}
@keyframes hp-bob{
  0%,100%{transform:translateY(-${bob}px)}
  50%{transform:translateY(${bob}px)}
}
@keyframes hp-sway{
  0%,100%{transform:rotate(-${sway}deg)}
  50%{transform:rotate(${sway}deg)}
}
@keyframes hp-cloud{
  0%,100%{transform:translateX(-14px)}
  50%{transform:translateX(14px)}
}
@keyframes hp-fish{
  0%,100%{transform:translate(24px,2px)}
  46%{transform:translate(-26px,-3px)}
  52%{transform:translate(-27px,-2px)}
}
@keyframes hp-dragonfly{
  0%,100%{transform:translate(-18px,3px)}
  30%{transform:translate(6px,-7px)}
  62%{transform:translate(20px,2px)}
}
@keyframes hp-shimmer{0%,100%{opacity:.82}50%{opacity:1}}

${on('[id$="pond-ripples"] path')}{animation:hp-ripple ${M.pondRipplePeriod}s ease-in-out infinite}
${on('[id$="pond-ripples"] path:nth-child(2)')}{animation-delay:-1.9s;animation-duration:${(M.pondRipplePeriod * 1.19).toFixed(2)}s}
${on('[id$="pond-ripples"] path:nth-child(3)')}{animation-delay:-3.7s;animation-duration:${(M.pondRipplePeriod * 0.87).toFixed(2)}s}
${on('[id$="pond-ripples"] path:nth-child(4)')}{animation-delay:-5.2s;animation-duration:${(M.pondRipplePeriod * 1.34).toFixed(2)}s}

${on('[id$="pond-lily-1"]')},
${on('[id$="pond-lily-2"]')},
${on('[id$="pond-lily-3"]')},
${on('[id$="pond-lily-4"]')}{animation:hp-bob ${M.pondLilyBobPeriod}s ease-in-out infinite}
/* Out of phase, or the pads read as one raft. */
${on('[id$="pond-lily-2"]')}{animation-delay:-2.3s;animation-duration:${(M.pondLilyBobPeriod * 1.21).toFixed(2)}s}
${on('[id$="pond-lily-3"]')}{animation-delay:-4.1s;animation-duration:${(M.pondLilyBobPeriod * 0.84).toFixed(2)}s}
${on('[id$="pond-lily-4"]')}{animation-delay:-1.1s}

${on('[id$="pond-reeds"] > g')}{animation:hp-sway ${M.pondReedSwayPeriod}s ease-in-out infinite}
${on('[id$="pond-reeds"] > g:nth-child(2)')}{animation-delay:-2.6s;animation-duration:${(M.pondReedSwayPeriod * 1.16).toFixed(2)}s}
${on('[id$="pond-reeds"] > g:nth-child(3)')}{animation-delay:-4.4s;animation-duration:${(M.pondReedSwayPeriod * 0.88).toFixed(2)}s}

${on('[id$="pond-clouds"] > g')}{animation:hp-cloud ${M.pondCloudDriftPeriod}s ease-in-out infinite}
${on('[id$="pond-clouds"] > g:nth-child(2)')}{animation-delay:-17s;animation-duration:${(M.pondCloudDriftPeriod * 1.32).toFixed(2)}s}
${on('[id$="pond-cloud-1"]')},
${on('[id$="pond-cloud-2"]')}{animation:hp-cloud ${M.pondCloudDriftPeriod}s ease-in-out infinite}

${on('[id$="pond-fish"]')}{animation:hp-fish ${M.pondFishPeriod}s ease-in-out infinite}
${on('[id$="pond-fish-2"]')}{animation:hp-fish ${(M.pondFishPeriod * 1.28).toFixed(2)}s ease-in-out infinite;animation-delay:-6s}
${on('[id$="pond-dragonfly"]')}{animation:hp-dragonfly ${M.pondDragonflyPeriod}s ease-in-out infinite}
${on('[id$="pond-butterfly"]')}{animation:hp-dragonfly ${(M.pondDragonflyPeriod * 1.21).toFixed(2)}s ease-in-out infinite}
${on('[id$="pond-butterfly-2"]')}{animation:hp-dragonfly ${(M.pondDragonflyPeriod * 0.79).toFixed(2)}s ease-in-out infinite;animation-delay:-4s}
${on('[id$="pond-shimmer"]')}{animation:hp-shimmer ${M.pondShimmerPeriod}s ease-in-out infinite}

/* ---- Press --------------------------------------------------------------
   The hotspot is a transparent link; the thing that presses is the button
   underneath it. The runtime composes the scale onto whatever transform the
   screen already gave that element, so nothing jumps out of position. */
body.proto .hp-press{transition:transform ${spring(M.press)}}
body.proto .hp-press.hp-releasing{transition:transform ${spring(M.release)}}

/* ---- Arrival ------------------------------------------------------------
   HopMotion.stagger(index:) — 45ms a step, capped at 360ms. */
@keyframes hp-arrive{from{opacity:0;transform:translateY(13px)}to{opacity:1;transform:translateY(0)}}
@keyframes hp-arrive-child{from{opacity:0;transform:translateY(22px) scale(.965)}to{opacity:1;transform:translateY(0) scale(1)}}
body.proto .hp-arrive{animation:hp-arrive ${spring(M.pagePush)} both}
body.proto .hp-arrive-child{animation:hp-arrive-child ${spring(M.childArrive)} both}

/* ---- Page transitions ---------------------------------------------------
   Parent motion is quick and nearly flat; it should feel like the OS. Child
   motion is bigger and carries bounce, because it is doing narrative work.
   The outgoing page parallaxes ${par}% of its width (HopMotion.pageParallax). */
.screen.leaving{display:block;pointer-events:none}
body.proto .screen.on{z-index:2}
body.proto .screen.leaving{z-index:1}
body.proto .screen.leaving.hp-above{z-index:3}

@keyframes hp-in-parent{from{transform:translateX(100%)}to{transform:translateX(0)}}
@keyframes hp-out-parent{from{transform:translateX(0);opacity:1}to{transform:translateX(-${par}%);opacity:.6}}
@keyframes hp-in-parent-back{from{transform:translateX(-${par}%);opacity:.6}to{transform:translateX(0);opacity:1}}
@keyframes hp-out-parent-back{from{transform:translateX(0)}to{transform:translateX(100%)}}

@keyframes hp-in-child{from{transform:translateX(100%) scale(.9);opacity:.35}55%{opacity:1}to{transform:translateX(0) scale(1);opacity:1}}
@keyframes hp-out-child{from{transform:translateX(0) scale(1);opacity:1}to{transform:translateX(-${par}%) scale(.93);opacity:.45}}
@keyframes hp-in-child-back{from{transform:translateX(-${par}%) scale(.93);opacity:.45}to{transform:translateX(0) scale(1);opacity:1}}
@keyframes hp-out-child-back{from{transform:translateX(0) scale(1);opacity:1}to{transform:translateX(100%) scale(.9);opacity:.35}}

@keyframes hp-in-sheet{from{transform:translateY(100%)}to{transform:translateY(0)}}
@keyframes hp-out-sheet-back{from{transform:translateY(0)}to{transform:translateY(100%)}}
@keyframes hp-under-sheet{from{transform:scale(1);opacity:1}to{transform:scale(.93);opacity:.55}}
@keyframes hp-over-sheet{from{transform:scale(.93);opacity:.55}to{transform:scale(1);opacity:1}}

@keyframes hp-fade-in{from{opacity:0}to{opacity:1}}
@keyframes hp-fade-out{from{opacity:1}to{opacity:0}}

body.proto .screen.hp-in-parent{animation:hp-in-parent ${spring(M.pagePush)} both}
body.proto .screen.hp-out-parent{animation:hp-out-parent ${spring(M.pagePush)} both}
body.proto .screen.hp-in-parent-back{animation:hp-in-parent-back ${spring(M.pagePush)} both}
body.proto .screen.hp-out-parent-back{animation:hp-out-parent-back ${spring(M.pagePush)} both}
body.proto .screen.hp-in-child{animation:hp-in-child ${spring(M.childPage)} both}
body.proto .screen.hp-out-child{animation:hp-out-child ${spring(M.childPage)} both}
body.proto .screen.hp-in-child-back{animation:hp-in-child-back ${spring(M.childPage)} both}
body.proto .screen.hp-out-child-back{animation:hp-out-child-back ${spring(M.childPage)} both}
body.proto .screen.hp-in-sheet{animation:hp-in-sheet ${spring(M.parentSheet)} both}
body.proto .screen.hp-out-sheet{animation:hp-under-sheet ${spring(M.parentSheet)} both}
body.proto .screen.hp-in-sheet-back{animation:hp-over-sheet ${spring(M.parentSheet)} both}
body.proto .screen.hp-out-sheet-back{animation:hp-out-sheet-back ${spring(M.parentSheet)} both}
body.proto .screen.hp-in-fade{animation:hp-fade-in ${M.reducedMotionFade}s linear both}
body.proto .screen.hp-out-fade{animation:hp-fade-out ${M.reducedMotionFade}s linear both}

/* ---- Reduce Motion ------------------------------------------------------
   Non-negotiable: every animation above becomes a ${fade}s cross-fade
   (HopMotion.reducedMotionFade) or nothing, and the prototype stays exactly as
   usable. The runtime checks the same query and skips the jump's delay, the
   press scale and the blink timers rather than running them invisibly. */
@media (prefers-reduced-motion: reduce){
  .hop,.hop-ov,.hopcell *,
  body.proto .screen *,
  body.proto .screen{animation:none!important;transition:none!important}
  .hop-ov{opacity:0!important}
  body.proto .screen[class*="hp-in-"]{animation:hp-fade-in ${fade}s linear both!important}
  body.proto .screen[class*="hp-out-"]{animation:hp-fade-out ${fade}s linear both!important}
}
`;
}

// ---------------------------------------------------------------------------
// The runtime
// ---------------------------------------------------------------------------

/**
 * Hop's behaviour, as source to be pasted into a page.
 *
 * It runs on both the prototype and the gallery, so it takes its frames from
 * whatever the page can give it: on the prototype the drawings are already
 * inlined as data URIs and the variants are derived from them in the browser
 * (no second request, and the page keeps its promise of making none); in the
 * gallery the variants are files the build wrote next to the originals.
 */
function hopRuntimeJS() {
  return `
var HopLife = (function () {
  var FRAME = {
    blink: ${FRAME.blink.toString()},
    gaze: ${FRAME.gaze.toString()},
    smile: ${FRAME.smile.toString()},
    mouth: ${FRAME.mouth.toString()}
  };
  var VARIANT = {
    blink: function (s) { return FRAME.blink(s); },
    smile: function (s) { return FRAME.smile(s); },
    gazeL: function (s) { return FRAME.gaze(s, -4.2, 1.2); },
    gazeR: function (s) { return FRAME.gaze(s, 4.2, 1.2); },
    gazeD: function (s) { return FRAME.gaze(s, 0, 4.2); },
    talkShut: function (s) { return FRAME.mouth(s, 0.26); }
  };
  var POSE_FRAMES = ${JSON.stringify(POSE_FRAMES)};
  var POSE_ANIM = ${JSON.stringify(POSE_ANIM)};
  var BLINK = ${JSON.stringify(M.blinkInterval)}, BLINK_MS = ${M.blinkDuration * 1000};
  var cache = {};

  function reduced() {
    return window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  }
  function rand(a, b) { return a + Math.random() * (b - a); }

  /** A derived drawing, as a data URI. Cached: one string per pose per variant. */
  function frame(pose, variant, baseSvg) {
    var key = pose + '|' + variant;
    if (cache[key]) return cache[key];
    var made = VARIANT[variant](baseSvg);
    if (made === baseSvg) { cache[key] = null; return null; }   /* rule did not apply */
    cache[key] = 'data:image/svg+xml;utf8,' + encodeURIComponent(made);
    return cache[key];
  }

  /** The drawing behind an <img>, if the page inlined it. */
  function sourceOf(img) {
    var m = /^data:image\\/svg\\+xml;base64,(.*)$/.exec(img.getAttribute('src') || '');
    if (!m) return null;
    try { return atob(m[1]); } catch (e) { return null; }
  }

  /**
   * Wrap one [data-hop] so the motion layer has something of its own to move,
   * and hang the extra drawings this pose needs off it.
   *
   * The screen keeps [data-hop] and its positioning; .hop inside it is the only
   * thing any animation here ever touches.
   */
  function equip(host) {
    if (host.__hop) return host.__hop;
    var img = host.querySelector('img[data-pose]') || host.querySelector('img');
    if (!img) return null;
    var pose = img.getAttribute('data-pose') || 'idle';
    var wrap = document.createElement('div');
    wrap.className = 'hop';
    while (host.firstChild) wrap.appendChild(host.firstChild);
    host.appendChild(wrap);

    var src = sourceOf(img);
    var wants = POSE_FRAMES[pose] || [];
    var ovs = {};
    if (src) {
      for (var i = 0; i < wants.length; i++) {
        var uri = frame(pose, wants[i], src);
        if (!uri) continue;
        var ov = document.createElement('img');
        ov.className = 'hop-ov';
        ov.setAttribute('data-v', wants[i]);
        ov.setAttribute('alt', '');
        ov.setAttribute('aria-hidden', 'true');
        ov.style.cssText = img.getAttribute('style') || '';
        ov.style.position = 'absolute';
        ov.style.left = '0';
        ov.style.top = '0';
        ov.src = uri;
        wrap.appendChild(ov);
        ovs[wants[i]] = ov;
      }
    }
    host.__hop = { host: host, wrap: wrap, pose: pose, ov: ovs, timers: [] };
    if (POSE_ANIM[pose]) wrap.classList.add(POSE_ANIM[pose]);
    return host.__hop;
  }

  /** Gallery tiles arrive with their frames already in the markup. */
  function adopt(wrap) {
    if (wrap.__hop) return wrap.__hop;
    var ovs = {}, list = wrap.querySelectorAll('.hop-ov');
    for (var i = 0; i < list.length; i++) ovs[list[i].getAttribute('data-v')] = list[i];
    wrap.__hop = { host: wrap, wrap: wrap, pose: wrap.getAttribute('data-pose') || 'idle', ov: ovs, timers: [] };
    return wrap.__hop;
  }

  function clear(h) {
    for (var i = 0; i < h.timers.length; i++) clearTimeout(h.timers[i]);
    h.timers = [];
  }
  function later(h, fn, ms) { h.timers.push(setTimeout(fn, ms)); }

  /**
   * Blinking, on a schedule a person would not notice was a schedule.
   *
   * A perfectly periodic blink reads as a machine, so the gap is redrawn from
   * HopMotion.blinkInterval every time and roughly one blink in six is a double.
   */
  function blinkLoop(h) {
    var ov = h.ov.blink;
    if (!ov) return;
    var next = function () {
      later(h, function () {
        ov.style.opacity = '1';
        later(h, function () {
          ov.style.opacity = '0';
          if (Math.random() < 0.17) {
            later(h, function () {
              ov.style.opacity = '1';
              later(h, function () { ov.style.opacity = '0'; next(); }, BLINK_MS);
            }, 110);
          } else { next(); }
        }, BLINK_MS);
      }, rand(BLINK[0], BLINK[1]) * 1000);
    };
    next();
  }

  /**
   * Hop looking at the thing the child is being asked to touch.
   *
   * Small effect, and the only one here that is *about* the interface: it puts
   * Hop's attention where the child's needs to go, without a word or an arrow.
   */
  function gazeLoop(h, dir) {
    var ov = h.ov['gaze' + dir];
    if (!ov) return;
    var next = function () {
      later(h, function () {
        ov.style.opacity = '1';
        later(h, function () { ov.style.opacity = '0'; next(); }, rand(1200, 2000));
      }, rand(3600, 7400));
    };
    next();
  }

  /** A line, spoken. Mouth moves for as long as the line would take, then stops. */
  function talk(h, seconds) {
    var ov = h.ov.talkShut;
    if (!ov || reduced()) return;
    var beats = Math.max(2, Math.round((seconds || 2.4) / 0.3 / 2) * 2);
    ov.style.setProperty('--hp-talk-beats', String(beats));
    ov.classList.remove('hp-talking');
    void ov.offsetWidth;
    ov.classList.add('hp-talking');
    later(h, function () { ov.classList.remove('hp-talking'); }, beats * 300 + 60);
  }

  /** A one-shot class on .hop that removes itself when the animation ends. */
  function beat(h, cls, ms, done) {
    if (reduced()) { if (done) done(); return; }
    h.wrap.classList.remove(cls);
    void h.wrap.offsetWidth;
    h.wrap.classList.add(cls);
    later(h, function () { h.wrap.classList.remove(cls); if (done) done(); }, ms);
  }

  return {
    equip: equip,
    adopt: adopt,
    reduced: reduced,
    clear: clear,
    /** Start the life of one Hop. opts says what this screen asks of him. */
    live: function (h, opts) {
      if (!h) return;
      clear(h);
      if (reduced()) return;
      opts = opts || {};
      blinkLoop(h);
      if (opts.gaze) gazeLoop(h, opts.gaze);
      if (opts.wave) beat(h, 'hp-wave', ${WAVE * 1000});
      if (opts.talk) later(h, function () { talk(h, opts.talk); }, 420);
    },
    rest: function (h) {
      if (!h) return;
      clear(h);
      for (var k in h.ov) if (h.ov[k]) { h.ov[k].style.opacity = '0'; h.ov[k].classList.remove('hp-talking'); }
      h.wrap.classList.remove('hp-jump', 'hp-wave', 'hp-react');
    },
    jump: function (h, done) {
      if (!h) { if (done) done(); return; }
      beat(h, 'hp-jump', ${JUMP * 1000}, done);
    },
    /** The short "he noticed you" beat: a pop and a smile, once, per tap. */
    react: function (h) {
      if (!h || reduced()) return;
      beat(h, 'hp-react', ${M.childTap[0] * 1000});
      var sm = h.ov.smile;
      if (!sm) return;
      sm.style.opacity = '1';
      later(h, function () { sm.style.opacity = '0'; }, 720);
    },
    talk: talk
  };
})();
`;
}

/**
 * The gallery's script: play a tile while it is on screen, stop when it is not.
 *
 * The states gallery is the one place that animates more than one Hop at a time,
 * because seeing the whole repertoire side by side is the entire point of it —
 * so an IntersectionObserver keeps the count honest by taking `playing` off
 * every tile that scrolls away.
 */
function galleryJS() {
  return `${hopRuntimeJS()}
(function () {
  var cells = [].slice.call(document.querySelectorAll('.hopcell'));
  if (!cells.length) return;
  var play = function (cell, yes) {
    var wrap = cell.querySelector('.hop');
    if (!wrap) return;
    var h = HopLife.adopt(wrap);
    if (yes) {
      cell.classList.add('playing');
      HopLife.live(h, { gaze: cell.getAttribute('data-gaze') || null });
      if (cell.getAttribute('data-talk')) {
        // A line, a long pause, another line. Re-armed with setTimeout so that
        // stopping the tile stops it: HopLife.clear only knows about timeouts.
        var line = function () {
          HopLife.talk(h, 2.4);
          h.timers.push(setTimeout(line, 7200));
        };
        h.timers.push(setTimeout(line, 500));
      }
    } else {
      cell.classList.remove('playing');
      HopLife.rest(h);
    }
  };
  if (!('IntersectionObserver' in window)) { cells.forEach(function (c) { play(c, true); }); return; }
  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) { play(e.target, e.isIntersecting); });
  }, { rootMargin: '80px' });
  cells.forEach(function (c) { io.observe(c); });
  document.addEventListener('visibilitychange', function () {
    cells.forEach(function (c) { if (document.hidden) play(c, false); });
  });
})();
`;
}

module.exports = { M, JUMP, WAVE, ease, spring, FRAME, VARIANTS, POSE_FRAMES, POSE_ANIM,
  motionCSS, hopRuntimeJS, galleryJS };
