#!/usr/bin/env node
/**
 * Builds the static HopPotty walkthrough prototype into `web/dist/`.
 *
 * This is not a port of the iOS app and cannot be one — the app's whole
 * mechanism is Apple's Screen Time API, which has no web equivalent. What it is
 * is the *design* made walkable: every screen here is produced by the same
 * `Scripts/screens/*` render harness that produces the design renders, from the
 * same `Scripts/tokens.json` the Swift target compiles against and the same
 * vector art the app bundles. Nothing is redrawn for the web.
 *
 * Three pages come out:
 *
 *   /          the phone prototype — one screen at a time, tap to walk the flow
 *   /gallery   every screen, Hop's states, the icon set, the pond, the app icon
 *   /about     what this is, plus the key product docs rendered from Markdown
 *
 * Screens are inlined into one document rather than iframed. Each screen's HTML
 * is a tree of inline-styled divs with no stylesheet of its own, so there is
 * nothing to collide: the only shared CSS is the font faces, which then load
 * once for all fourteen screens instead of fourteen times. The one real risk of
 * sharing a document is SVG `id` collision between two screens' gradients, and
 * `nsIds` below namespaces those per screen so it cannot happen.
 *
 *   node Scripts/web/build-prototype.js
 *   node Scripts/web/build-prototype.js --verify   (also measures every hotspot)
 */
const fs = require('fs');
const path = require('path');
const { T, c, baseCSS, ROOT } = require('../screens/ui');
const registry = require('../screens/registry');

const P = T.palette;
const WEB = path.join(ROOT, 'web');
const DIST = path.join(WEB, 'dist');
const ASSETS = path.join(DIST, 'assets');
const DEVICE = { w: 393, h: 852 };

// ---------------------------------------------------------------------------
// The screens
// ---------------------------------------------------------------------------

const slugOf = (key) => key.replace(/^\d+-/, '');

/** Human captions. The registry keys are filenames; these are what a person reads. */
const CAPTION = {
  'parent-home': ['Parent home', 'The dashboard a caregiver opens: next pause, today’s routine, one pattern.'],
  'onboarding-meet-hop': ['Meet Hop', 'First run. One idea, one action.'],
  'onboarding-idea': ['The idea', 'What the app actually does, before any permission is asked for.'],
  'timer-settings': ['Potty Pause settings', 'The schedule said once in words; every control below edits that sentence.'],
  'choose-apps': ['Apps that pause', 'Apple’s picker over our screen. HopPotty only ever holds a count.'],
  'potty-pause-shield': ['Potty Pause shield', 'The system shield over a paused app, warmed as far as the API allows.'],
  'routine-step1': ['Routine — to the potty', 'Step one of five. Big target, no time pressure.'],
  'routine-step3': ['Routine — what happened', 'Three answers, one shape. “I tried” is never ranked below the others.'],
  'routine-complete': ['Celebration', 'The attempt is what is celebrated, not the result.'],
  'hops-pond': ['Hop’s Pond', 'The reward is a place, not a score. Every price is visible in advance.'],
  'game-bubble-wash': ['Bubble Wash', 'A hand-washing game. Progress is bubbles caught, never a score.'],
  'quiz': ['Hop’s question', 'Pictures first, three answers, read aloud on demand.'],
  'insights': ['Progress', 'Descriptive statistics, never advice.'],
  'parent-home-dark': ['Parent home (dark)', 'The same screen in the dark appearance.'],
};

/** Order of the walkthrough, used by the ◀ ▶ chrome and the screen list. */
const FLOW = [
  'onboarding-meet-hop', 'onboarding-idea', 'timer-settings', 'choose-apps',
  'parent-home', 'potty-pause-shield', 'routine-step1', 'routine-step3',
  'routine-complete', 'hops-pond', 'game-bubble-wash', 'quiz', 'insights',
];

// ---------------------------------------------------------------------------
// Tap targets
// ---------------------------------------------------------------------------

/**
 * Hotspots are declared by what they *say*, not by where they sit.
 *
 * A coordinate baked at build time is wrong the moment a screen module changes
 * by a pixel, and these modules are edited constantly. So each hotspot names the
 * button's label, and a few lines of JS in the page find that label in the laid
 * out DOM and position a transparent link over it. The browser does the layout;
 * nothing here can go stale as long as the button still says what it says.
 *
 *   text  exact trimmed text of the element to find (leaf elements only)
 *   path  an SVG path `d` to find instead — for buttons that are pure icon
 *   sel   a CSS selector, for anything the other two cannot name
 *   up    climb N parents from the match, to grow a label into its button
 *   pick  'first' | 'last' — which match to take when a label repeats
 *   to    destination screen slug
 */
const TABS = [
  { text: 'Home', up: 1, pick: 'last', to: 'parent-home', label: 'Home tab' },
  { text: 'Progress', up: 1, pick: 'last', to: 'insights', label: 'Progress tab' },
  { text: 'Hop', up: 1, pick: 'last', to: 'hops-pond', label: 'Hop tab' },
  { text: 'Settings', up: 1, pick: 'last', to: 'timer-settings', label: 'Settings tab' },
];

const HOTSPOTS = {
  'onboarding-meet-hop': [
    { text: 'Get Started', to: 'onboarding-idea' },
    { text: 'Skip', to: 'parent-home' },
  ],
  'onboarding-idea': [
    { text: 'Continue', to: 'timer-settings' },
    { text: 'Skip', to: 'parent-home' },
  ],
  'timer-settings': [
    { text: 'Settings', up: 1, pick: 'first', to: 'parent-home', label: 'Back to Settings' },
    { text: 'Mode', up: 2, to: 'choose-apps', label: 'Apps that pause' },
    { text: 'Test Potty Pause', up: 3, to: 'potty-pause-shield' },
  ],
  'choose-apps': [
    { text: 'Choose apps', to: 'choose-apps', label: 'Choose apps (picker already open)' },
    { text: 'Cancel', to: 'timer-settings' },
    { text: 'Done', to: 'parent-home' },
  ],
  'parent-home': [
    { text: 'Start Now', to: 'potty-pause-shield' },
    { text: 'Skip', to: 'parent-home', label: 'Skip this pause' },
    { text: 'View all', to: 'insights' },
    ...TABS,
  ],
  'potty-pause-shield': [
    { text: "Let's Go!", to: 'routine-step1' },
    { text: 'Need a grown-up?', to: 'parent-home' },
  ],
  'routine-step1': [
    { text: "I'm here!", up: 1, to: 'routine-step3' },
    { text: 'Grown-up', up: 1, to: 'parent-home', label: 'Grown-up escape' },
  ],
  'routine-step3': [
    { text: 'I peed', up: 1, to: 'routine-complete' },
    { text: 'I pooped', up: 1, to: 'routine-complete' },
    { text: 'I tried', up: 1, to: 'routine-complete' },
    { text: 'Grown-up', up: 1, to: 'parent-home', label: 'Grown-up escape' },
  ],
  'routine-complete': [
    { text: 'Back to Play', up: 1, to: 'parent-home' },
    { text: 'See my pond', up: 1, to: 'hops-pond' },
  ],
  'hops-pond': [
    { path: 'M15 5l-7 7 7 7', up: 1, to: 'parent-home', label: 'Back' },
    { sel: '[data-hop]', to: 'game-bubble-wash', label: 'Play a game with Hop' },
    { text: '13', up: 1, to: 'quiz', label: 'Hop stars — Hop’s question' },
  ],
  'game-bubble-wash': [
    { text: 'All done', up: 1, to: 'hops-pond' },
  ],
  'quiz': [
    { text: 'A snack', up: 1, to: 'hops-pond' },
    { text: 'Wash hands', up: 1, to: 'hops-pond' },
    { text: 'Play a game', up: 1, to: 'hops-pond' },
  ],
  'insights': TABS,
};

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/**
 * Namespaces every SVG `id` in one screen's markup.
 *
 * `scenes.js` already randomises its gradient ids, but `child.js` derives one
 * from a bubble's coordinates, and any future screen may hard-code one. Two
 * screens in the same document sharing an id means the second one's gradient
 * silently resolves to the first one's. Prefixing per screen removes the class
 * of bug rather than the one instance of it.
 */
function nsIds(html, prefix) {
  return html
    .replace(/ id="([^"]+)"/g, (_m, id) => ` id="${prefix}__${id}"`)
    .replace(/url\(#([^)]+)\)/g, (_m, id) => `url(#${prefix}__${id})`);
}

/** One screen, in one appearance, as a positioned layer. */
function screenLayer(slug, appearance, html, { hidden = true } = {}) {
  const col = c(appearance);
  const id = `${slug}-${appearance}`;
  return `<div class="screen${hidden ? '' : ' on'}" id="scr-${id}" data-screen="${slug}" ` +
    `data-theme="${appearance}" style="color:${col.textPrimary};background:${col.backgroundPrimary}">` +
    nsIds(html, id.replace(/[^a-z0-9-]/gi, '')) + `</div>`;
}

/** Every registry screen rendered in both appearances. */
function renderAll() {
  const out = [];
  for (const [key, def] of Object.entries(registry)) {
    const slug = slugOf(key);
    const light = def.render(def.appearance === 'dark' ? 'dark' : 'light');
    const dark = def.render('dark');
    out.push({ key, slug, light, dark, caption: CAPTION[slug] || [slug, ''] });
  }
  return out;
}

// ---------------------------------------------------------------------------
// Markdown (small, hand-rolled — the site ships no third-party code)
// ---------------------------------------------------------------------------

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function inlineMd(s) {
  const codes = [];
  let t = s.replace(/`([^`]+)`/g, (_m, code) => { codes.push(code); return `${codes.length - 1}`; });
  t = esc(t);
  t = t.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_m, txt, href) => `<a href="${href}">${txt}</a>`);
  t = t.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  t = t.replace(/(^|[^*\w])\*([^*\n]+)\*/g, '$1<em>$2</em>');
  t = t.replace(/(\d+)/g, (_m, i) => `<code>${esc(codes[Number(i)])}</code>`);
  return t;
}

function mdToHtml(src) {
  const fences = [];
  let text = src.replace(/```[^\n]*\n([\s\S]*?)```/g, (_m, code) => {
    fences.push(code.replace(/\n$/, ''));
    return ` F${fences.length - 1} `;
  });
  const lines = text.split('\n');
  const out = [];
  let i = 0;

  const listBlock = (items) => {
    // items: [{ indent, ordered, text }]
    const render = (start, indent) => {
      let j = start;
      const ordered = items[start].ordered;
      let html = ordered ? '<ol>' : '<ul>';
      while (j < items.length && items[j].indent >= indent) {
        if (items[j].indent > indent) {
          const sub = render(j, items[j].indent);
          html = html.replace(/<\/li>$/, sub.html + '</li>');
          j = sub.next;
          continue;
        }
        html += `<li>${inlineMd(items[j].text)}</li>`;
        j++;
      }
      html += ordered ? '</ol>' : '</ul>';
      return { html, next: j };
    };
    return render(0, items[0].indent).html;
  };

  while (i < lines.length) {
    const line = lines[i];
    const trimmed = line.trim();

    if (!trimmed) { i++; continue; }

    let m;
    if ((m = trimmed.match(/^ F(\d+) $/))) {
      out.push(`<pre><code>${esc(fences[Number(m[1])])}</code></pre>`);
      i++; continue;
    }
    if ((m = trimmed.match(/^(#{1,6})\s+(.*)$/))) {
      const n = m[1].length;
      out.push(`<h${n}>${inlineMd(m[2])}</h${n}>`);
      i++; continue;
    }
    if (/^(-{3,}|\*{3,}|_{3,})$/.test(trimmed)) { out.push('<hr>'); i++; continue; }

    if (trimmed.startsWith('|')) {
      const rows = [];
      while (i < lines.length && lines[i].trim().startsWith('|')) { rows.push(lines[i].trim()); i++; }
      const cells = (r) => r.replace(/^\|/, '').replace(/\|$/, '').split('|').map((x) => x.trim());
      const head = cells(rows[0]);
      const body = rows.slice(rows[1] && /^[\s|:-]+$/.test(rows[1]) ? 2 : 1);
      out.push(`<div class="tablewrap"><table><thead><tr>${head.map((h) => `<th>${inlineMd(h)}</th>`).join('')}` +
        `</tr></thead><tbody>${body.map((r) => `<tr>${cells(r).map((x) => `<td>${inlineMd(x)}</td>`).join('')}</tr>`).join('')}` +
        `</tbody></table></div>`);
      continue;
    }

    if (trimmed.startsWith('>')) {
      const buf = [];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        buf.push(lines[i].trim().replace(/^>\s?/, '')); i++;
      }
      out.push(`<blockquote>${mdToHtml(buf.join('\n'))}</blockquote>`);
      continue;
    }

    if (/^\s*([-*+]|\d+\.)\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^\s*([-*+]|\d+\.)\s+/.test(lines[i])) {
        const im = lines[i].match(/^(\s*)([-*+]|\d+\.)\s+(.*)$/);
        items.push({ indent: im[1].length, ordered: /\d/.test(im[2]), text: im[3] });
        i++;
        // a wrapped continuation line belongs to the item above it
        while (i < lines.length && lines[i].trim() && !/^\s*([-*+]|\d+\.)\s+/.test(lines[i]) &&
               /^\s{2,}/.test(lines[i])) {
          items[items.length - 1].text += ' ' + lines[i].trim(); i++;
        }
      }
      out.push(listBlock(items));
      continue;
    }

    const para = [];
    while (i < lines.length && lines[i].trim() && !/^\s*([-*+]|\d+\.)\s+/.test(lines[i]) &&
           !lines[i].trim().startsWith('|') && !lines[i].trim().startsWith('>') &&
           !/^#{1,6}\s/.test(lines[i].trim()) && !/^ F\d+ $/.test(lines[i].trim())) {
      para.push(lines[i].trim()); i++;
    }
    if (para.length) out.push(`<p>${inlineMd(para.join(' '))}</p>`);
    else i++;
  }
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// CSS
// ---------------------------------------------------------------------------

function siteCSS() {
  const L = c('light');
  const D = c('dark');
  const fontFaces = (baseCSS('light').match(/@font-face\{[^}]*\}/g) || []).join('\n');

  return `${fontFaces}
/* ---- reset ------------------------------------------------------------- */
*{box-sizing:border-box;margin:0;padding:0;-webkit-font-smoothing:antialiased}
html{-webkit-text-size-adjust:100%}
body{font-family:'HopStandard',system-ui,-apple-system,sans-serif;background:${P.sand100};color:${L.textPrimary}}
a{color:inherit}
.rounded{font-family:'HopRounded','HopStandard',sans-serif}
.mono-digits{font-variant-numeric:tabular-nums}

/* ---- a screen ---------------------------------------------------------- */
.screen{position:absolute;left:0;top:0;width:${DEVICE.w}px;height:${DEVICE.h}px;overflow:hidden;
  font-family:'HopStandard',system-ui,sans-serif;display:none}
.screen.on{display:block}

/* ---- the prototype ----------------------------------------------------- */
body.proto{background:${P.midnight};min-height:100vh;min-height:100dvh;
  display:flex;align-items:center;justify-content:center;overflow:hidden}
.stage{position:fixed;inset:0;display:flex;align-items:center;justify-content:center}
.device{position:relative;width:${DEVICE.w}px;height:${DEVICE.h}px;flex:0 0 auto;
  border-radius:54px;background:#000;box-shadow:0 0 0 11px #1c1c1e,0 0 0 13px #3a3a3c,0 40px 90px rgba(0,0,0,.55);
  transform-origin:center center}
.viewport{position:absolute;inset:0;overflow:hidden;border-radius:44px;background:${L.backgroundPrimary}}
.hotspots{position:absolute;inset:0;z-index:40}
.hs{position:absolute;display:block;border-radius:14px;-webkit-tap-highlight-color:transparent;
  cursor:pointer;background:transparent}
.hs:focus-visible{outline:3px solid ${L.focusRing};outline-offset:2px}
body.showhs .hs{background:rgba(108,196,232,.30);box-shadow:inset 0 0 0 2px rgba(42,135,172,.85)}
.hs:active{background:rgba(255,255,255,.14)}

/* ---- chrome ------------------------------------------------------------ */
.chrome{position:fixed;right:calc(14px + env(safe-area-inset-right));
  bottom:calc(14px + env(safe-area-inset-bottom));z-index:100;display:flex;gap:6px;
  padding:6px;border-radius:22px;background:rgba(20,25,42,.72);backdrop-filter:blur(14px);
  box-shadow:0 8px 26px rgba(0,0,0,.4)}
.chrome button{width:38px;height:38px;border:0;border-radius:16px;background:rgba(255,255,255,.1);
  color:#F3F1ED;font-size:15px;line-height:1;cursor:pointer;font-family:inherit;
  display:grid;place-items:center;transition:background .14s}
.chrome button:hover{background:rgba(255,255,255,.22)}
.chrome button[disabled]{opacity:.32;cursor:default}
.chrome button.wide{width:auto;padding:0 12px;font-size:12px;letter-spacing:.2px}

.sheet{position:fixed;inset:0;z-index:110;display:none;background:rgba(10,13,22,.62);
  backdrop-filter:blur(6px);padding:24px;overflow:auto}
.sheet.on{display:block}
.sheet-inner{max-width:560px;margin:auto;background:${L.surface};border-radius:24px;padding:20px 20px 14px;
  box-shadow:0 30px 80px rgba(0,0,0,.45)}
.sheet h2{font-family:'HopRounded','HopStandard',sans-serif;font-size:20px;color:${L.textPrimary};margin-bottom:2px}
.sheet p.sub{font-size:13px;color:${L.textTertiary};margin-bottom:14px}
.sheet ol{list-style:none;counter-reset:s}
.sheet li{counter-increment:s}
.sheet li a{display:flex;gap:12px;align-items:baseline;padding:9px 10px;border-radius:12px;
  text-decoration:none;color:${L.textPrimary}}
.sheet li a:hover{background:${L.surfaceSunken}}
.sheet li a::before{content:counter(s,decimal-leading-zero);font-variant-numeric:tabular-nums;
  font-size:11px;color:${L.textTertiary};min-width:18px}
.sheet li a.cur{background:${P.hopGreenSoft};color:${P.hopGreenInk};font-weight:700}
.sheet li a small{display:block;font-weight:400;font-size:12px;color:${L.textTertiary};margin-top:1px}
.sheet .close{display:block;width:100%;margin-top:8px;padding:11px;border:0;border-radius:14px;
  background:${L.surfaceSunken};color:${L.textSecondary};font-family:inherit;font-size:14px;cursor:pointer}
.sheet .foot{display:flex;gap:10px;margin-top:10px;padding-top:12px;border-top:1px solid ${L.divider};
  font-size:13px}
.sheet .foot a{color:${L.brandAction};text-decoration:none;font-weight:600}

.caption{position:fixed;left:50%;transform:translateX(-50%);
  bottom:calc(16px + env(safe-area-inset-bottom));z-index:90;
  padding:7px 15px;border-radius:16px;background:rgba(20,25,42,.72);backdrop-filter:blur(14px);
  color:#F3F1ED;font-size:12.5px;letter-spacing:.2px;max-width:min(60vw,420px);
  white-space:nowrap;overflow:hidden;text-overflow:ellipsis;pointer-events:none}

/* On a real phone the prototype is the phone: no frame, no chrome furniture. */
@media (max-width:520px){
  .device{border-radius:0;box-shadow:none}
  .viewport{border-radius:0}
  .caption{display:none}
}
@media print{.chrome,.sheet,.caption{display:none!important}.device{box-shadow:none}}

/* ---- shared page furniture (gallery + about) --------------------------- */
body.page{background:${P.sand100};color:${L.textPrimary};padding:0 0 80px}
.wrap{max-width:1120px;margin:0 auto;padding:0 28px}
.masthead{padding:44px 0 26px;display:flex;align-items:center;gap:16px;flex-wrap:wrap}
.masthead img{width:56px;height:56px;border-radius:13px;display:block;
  box-shadow:0 4px 16px rgba(36,48,71,.18)}
.masthead h1{font-family:'HopRounded','HopStandard',sans-serif;font-size:32px;letter-spacing:-.4px}
.masthead p{color:${L.textSecondary};font-size:15px;margin-top:2px}
nav.site{margin-left:auto;display:flex;gap:6px;flex-wrap:wrap}
nav.site a{padding:8px 14px;border-radius:20px;background:${L.surface};text-decoration:none;
  font-size:13.5px;font-weight:600;color:${L.textSecondary};box-shadow:0 1px 3px rgba(36,48,71,.08)}
nav.site a.cur{background:${P.hopGreenSoft};color:${P.hopGreenInk}}
.note{background:${P.sunshineSoft};border-radius:16px;padding:14px 18px;font-size:14px;
  color:${P.sunshineDeep};line-height:1.5;margin-bottom:30px}
h2.sec{font-family:'HopRounded','HopStandard',sans-serif;font-size:22px;margin:44px 0 4px}
p.secsub{color:${L.textSecondary};font-size:14.5px;margin-bottom:20px;max-width:64ch;line-height:1.55}

/* ---- gallery grid ------------------------------------------------------ */
.grid{display:grid;gap:26px;grid-template-columns:repeat(auto-fill,minmax(220px,1fr))}
.tile{background:${L.surface};border-radius:20px;padding:14px;box-shadow:0 2px 10px rgba(36,48,71,.08)}
.thumb{position:relative;width:100%;aspect-ratio:${DEVICE.w} / ${DEVICE.h};border-radius:13px;
  overflow:hidden;background:${L.surfaceSunken};box-shadow:inset 0 0 0 1px ${L.divider}}
.thumb .screen{transform-origin:top left;display:block}
.tile h3{font-size:14.5px;font-weight:700;margin-top:11px;color:${L.textPrimary}}
.tile p{font-size:12.5px;color:${L.textTertiary};line-height:1.45;margin-top:3px}
.tile .idx{font-size:11px;color:${L.textTertiary};font-variant-numeric:tabular-nums}

.states{display:grid;gap:18px;grid-template-columns:repeat(auto-fill,minmax(132px,1fr))}
.state{background:${L.surface};border-radius:18px;padding:12px;text-align:center;
  box-shadow:0 2px 10px rgba(36,48,71,.08)}
.state .box{height:118px;display:grid;place-items:center;background:${P.hopGreenSoft};border-radius:12px}
.state img{max-height:104px;width:auto;display:block}
.state b{display:block;font-size:13px;margin-top:9px}
.state span{display:block;font-size:11.5px;color:${L.textTertiary};margin-top:1px;line-height:1.35}

.loop{display:flex;align-items:center;gap:22px;background:${L.surface};border-radius:20px;padding:18px 22px;
  box-shadow:0 2px 10px rgba(36,48,71,.08);flex-wrap:wrap}
.loop .stack{position:relative;width:150px;height:150px;background:${P.hopGreenSoft};border-radius:16px;
  flex:0 0 auto}
.loop .stack img{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);max-height:130px}
.loop .stack img.b{animation:blinkloop 4.6s steps(1,end) infinite}
.loop .stack img.a{animation:idleloop 4.6s steps(1,end) infinite}
@keyframes idleloop{0%,92%{opacity:1}92.1%,100%{opacity:0}}
@keyframes blinkloop{0%,92%{opacity:0}92.1%,100%{opacity:1}}
.loop div.copy{flex:1;min-width:220px}
.loop h3{font-family:'HopRounded','HopStandard',sans-serif;font-size:18px}
.loop p{font-size:14px;color:${L.textSecondary};line-height:1.55;margin-top:6px;max-width:52ch}
@media (prefers-reduced-motion:reduce){.loop .stack img.a,.loop .stack img.b{animation:none}
  .loop .stack img.b{opacity:0}}

.icons{display:grid;gap:12px;grid-template-columns:repeat(auto-fill,minmax(96px,1fr))}
.icon{background:${L.surface};border-radius:14px;padding:10px 6px;text-align:center;
  box-shadow:0 1px 5px rgba(36,48,71,.07)}
.icon img{width:46px;height:46px;display:block;margin:0 auto}
.icon span{display:block;font-size:10.5px;color:${L.textTertiary};margin-top:6px;word-break:break-word;
  line-height:1.3}
.pondshot{border-radius:22px;overflow:hidden;box-shadow:0 4px 20px rgba(36,48,71,.14);background:${L.surface}}
.pondshot img{width:100%;display:block}
.appicons{display:flex;gap:22px;align-items:flex-end;flex-wrap:wrap}
.appicons figure{text-align:center}
.appicons img{display:block;border-radius:22.5%;box-shadow:0 6px 22px rgba(36,48,71,.2)}
.appicons figcaption{font-size:11.5px;color:${L.textTertiary};margin-top:8px}

/* ---- docs -------------------------------------------------------------- */
.doc{max-width:74ch;margin:0 auto;background:${L.surface};border-radius:22px;padding:38px 42px 46px;
  box-shadow:0 2px 14px rgba(36,48,71,.09);line-height:1.62;font-size:15.5px;color:${L.textSecondary}}
.doc h1{font-family:'HopRounded','HopStandard',sans-serif;font-size:30px;color:${L.textPrimary};
  margin:0 0 18px;letter-spacing:-.3px}
.doc h2{font-family:'HopRounded','HopStandard',sans-serif;font-size:21px;color:${L.textPrimary};
  margin:34px 0 10px}
.doc h3{font-size:16.5px;color:${L.textPrimary};margin:24px 0 8px}
.doc h4,.doc h5,.doc h6{font-size:15px;color:${L.textPrimary};margin:18px 0 6px}
.doc p{margin:0 0 14px}
.doc ul,.doc ol{margin:0 0 14px 22px}
.doc li{margin:4px 0}
.doc code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.88em;
  background:${L.surfaceSunken};padding:1px 5px;border-radius:5px;color:${L.textPrimary}}
.doc pre{background:${P.midnight};color:#E7EAF2;border-radius:14px;padding:16px 18px;overflow-x:auto;
  margin:0 0 18px;font-size:13px;line-height:1.55}
.doc pre code{background:none;color:inherit;padding:0;font-size:inherit}
.doc blockquote{border-left:3px solid ${P.hopGreen};padding:2px 0 2px 16px;margin:0 0 16px;
  color:${L.textTertiary}}
.doc blockquote p:last-child{margin-bottom:0}
.doc hr{border:0;border-top:1px solid ${L.divider};margin:28px 0}
.doc a{color:${L.brandAction}}
.tablewrap{overflow-x:auto;margin:0 0 18px}
.doc table{border-collapse:collapse;width:100%;font-size:13.5px}
.doc th,.doc td{text-align:left;padding:8px 12px;border-bottom:1px solid ${L.divider};vertical-align:top}
.doc th{color:${L.textPrimary};font-weight:700;white-space:nowrap}
.backlink{display:inline-block;margin:0 0 18px;font-size:13.5px;color:${L.brandAction};
  text-decoration:none;font-weight:600}
.doclist{display:grid;gap:12px;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));margin-top:18px}
.doclist a{display:block;background:${L.surface};border-radius:16px;padding:16px 18px;text-decoration:none;
  box-shadow:0 1px 5px rgba(36,48,71,.08)}
.doclist b{display:block;font-size:15px;color:${L.textPrimary}}
.doclist span{display:block;font-size:12.5px;color:${L.textTertiary};margin-top:3px;line-height:1.45}
footer.site{margin-top:56px;padding-top:22px;border-top:1px solid ${L.divider};
  font-size:12.5px;color:${L.textTertiary};line-height:1.6}

@media (prefers-color-scheme:dark){
  body.page{background:${D.backgroundPrimary};color:${D.textPrimary}}
  .tile,.state,.icon,.loop,.doc,.doclist a,nav.site a,.pondshot{background:${D.surface};
    box-shadow:0 2px 10px rgba(0,0,0,.4)}
  .tile h3,.doc h1,.doc h2,.doc h3,.doc h4,.doc th,.doclist b,.masthead h1,.loop h3{color:${D.textPrimary}}
  .tile p,.tile .idx,.state span,.icon span,.doclist span,.masthead p,.loop p,.doc,footer.site,nav.site a
    {color:${D.textSecondary}}
  .doc code{background:${D.surfaceSunken};color:${D.textPrimary}}
  .doc th,.doc td{border-color:${D.divider}}
  .doc hr,footer.site{border-color:${D.divider}}
  .doc a,.backlink,.doclist a b{color:${D.brandAction}}
  .note{background:rgba(255,215,105,.13);color:${D.warning}}
  nav.site a.cur{background:rgba(143,220,172,.16);color:${D.brandPrimary}}
  .thumb{background:${D.surfaceSunken};box-shadow:inset 0 0 0 1px ${D.divider}}
}
`;
}

// ---------------------------------------------------------------------------
// The prototype page
// ---------------------------------------------------------------------------

const RUNTIME = String.raw`
(function () {
  var FLOW = __FLOW__, HOT = __HOT__, CAP = __CAP__;
  var W = __W__, H = __H__;
  var body = document.body, viewport = document.getElementById('viewport');
  var device = document.querySelector('.device');
  var theme = localStorage.getItem('hp-theme') || 'light';
  var cur = FLOW[0];

  /* --- scale the device to the window -------------------------------- */
  function fit() {
    var vw = window.innerWidth, vh = window.innerHeight;
    var k = vw <= 520 ? vw / W : Math.min((vw - 60) / W, (vh - 60) / H);
    device.style.transform = 'scale(' + k + ')';
  }
  window.addEventListener('resize', fit);
  if (window.visualViewport) window.visualViewport.addEventListener('resize', fit);

  /* --- find the element a hotspot names ------------------------------ */
  function findEl(root, spec) {
    if (spec.sel) return root.querySelector(spec.sel);
    if (spec.path) {
      var p = root.querySelector('svg path[d="' + spec.path + '"]');
      return p ? p.closest('svg') : null;
    }
    var want = spec.text, hits = [];
    var all = root.querySelectorAll('*');
    for (var i = 0; i < all.length; i++) {
      var e = all[i];
      if (e.children.length || e.closest('svg')) continue;
      if ((e.textContent || '').replace(/\s+/g, ' ').trim() === want) hits.push(e);
    }
    if (!hits.length) return null;
    if (spec.pick === 'last') {
      hits.sort(function (a, b) { return a.getBoundingClientRect().top - b.getBoundingClientRect().top; });
      return hits[hits.length - 1];
    }
    return hits[0];
  }

  /* --- lay transparent links over the buttons ------------------------ */
  function hotspots(slug, layer) {
    var host = layer.querySelector('.hotspots');
    if (host) host.remove();
    host = document.createElement('div');
    host.className = 'hotspots';
    var base = layer.getBoundingClientRect();
    var k = base.width / W || 1;
    var specs = HOT[slug] || [];
    var missed = [];
    for (var i = 0; i < specs.length; i++) {
      var s = specs[i];
      var el = findEl(layer, s);
      for (var u = 0; el && u < (s.up || 0); u++) el = el.parentElement;
      if (!el) { missed.push(s.label || s.text || s.sel || s.path); continue; }
      var r = el.getBoundingClientRect();
      var x = (r.left - base.left) / k, y = (r.top - base.top) / k;
      var w = r.width / k, h = r.height / k;
      if (h < 44) { y -= (44 - h) / 2; h = 44; }
      if (w < 44) { x -= (44 - w) / 2; w = 44; }
      var a = document.createElement('a');
      a.className = 'hs';
      a.href = '#' + s.to;
      a.setAttribute('aria-label', s.label || s.text || s.to);
      a.title = (s.label || s.text || '') + ' → ' + s.to;
      a.style.cssText = 'left:' + x.toFixed(1) + 'px;top:' + y.toFixed(1) + 'px;width:' +
        w.toFixed(1) + 'px;height:' + h.toFixed(1) + 'px';
      host.appendChild(a);
    }
    layer.appendChild(host);
    if (missed.length) console.warn('[hotspot] unresolved on ' + slug + ':', missed.join(', '));
    window.__hotspotReport = window.__hotspotReport || {};
    window.__hotspotReport[slug] = { placed: host.children.length, missed: missed };
  }

  /* --- show one screen ------------------------------------------------ */
  function show(slug, push) {
    if (FLOW.indexOf(slug) < 0) slug = FLOW[0];
    cur = slug;
    var layers = viewport.querySelectorAll('.screen'), shown = null;
    for (var i = 0; i < layers.length; i++) {
      var on = layers[i].dataset.screen === slug && layers[i].dataset.theme === theme;
      layers[i].classList.toggle('on', on);
      if (on) shown = layers[i];
    }
    if (!shown) {   /* a screen with no variant in this theme falls back */
      for (var j = 0; j < layers.length; j++) {
        if (layers[j].dataset.screen === slug) { layers[j].classList.add('on'); shown = layers[j]; break; }
      }
    }
    if (shown) hotspots(slug, shown);
    var idx = FLOW.indexOf(slug);
    document.getElementById('prev').disabled = idx <= 0;
    document.getElementById('next').disabled = idx >= FLOW.length - 1;
    var cap = document.getElementById('caption');
    if (cap) cap.textContent = (idx + 1) + '/' + FLOW.length + '  ·  ' + (CAP[slug] || slug);
    var links = document.querySelectorAll('#sheet a[data-goto]');
    for (var n = 0; n < links.length; n++) {
      links[n].classList.toggle('cur', links[n].dataset.goto === slug);
    }
    if (push && location.hash.slice(1) !== slug) history.replaceState(null, '', '#' + slug);
    document.title = 'HopPotty — ' + (CAP[slug] || slug);
  }

  function go(delta) {
    var idx = FLOW.indexOf(cur) + delta;
    if (idx >= 0 && idx < FLOW.length) { location.hash = FLOW[idx]; }
  }

  function setTheme(t) {
    theme = t;
    try { localStorage.setItem('hp-theme', t); } catch (e) {}
    document.getElementById('theme').textContent = t === 'dark' ? '☀' : '☾';
    document.getElementById('theme').setAttribute('aria-label',
      t === 'dark' ? 'Switch to light appearance' : 'Switch to dark appearance');
    show(cur, false);
  }

  /* --- wiring --------------------------------------------------------- */
  document.getElementById('prev').addEventListener('click', function () { go(-1); });
  document.getElementById('next').addEventListener('click', function () { go(1); });
  document.getElementById('theme').addEventListener('click', function () {
    setTheme(theme === 'dark' ? 'light' : 'dark');
  });
  var sheet = document.getElementById('sheet');
  document.getElementById('list').addEventListener('click', function () { sheet.classList.add('on'); });
  sheet.addEventListener('click', function (e) {
    if (e.target === sheet || e.target.id === 'sheetclose' || e.target.closest('a[data-goto]')) {
      sheet.classList.remove('on');
    }
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'ArrowLeft') go(-1);
    else if (e.key === 'ArrowRight') go(1);
    else if (e.key === 'Escape') sheet.classList.remove('on');
    else if (e.key === 'h') body.classList.toggle('showhs');
    else if (e.key === 'd') setTheme(theme === 'dark' ? 'light' : 'dark');
  });
  window.addEventListener('hashchange', function () { show(location.hash.slice(1), false); });

  fit();
  setTheme(theme);
  show(location.hash.slice(1) || FLOW[0], true);
  if (document.fonts && document.fonts.ready) {
    document.fonts.ready.then(function () { show(cur, false); });  /* re-measure once type settles */
  }
})();
`;

function prototypePage(screens) {
  const layers = [];
  for (const s of screens) {
    if (!FLOW.includes(s.slug)) continue;   // the dark duplicate lives in the gallery
    layers.push(screenLayer(s.slug, 'light', s.light));
    layers.push(screenLayer(s.slug, 'dark', s.dark));
  }
  const capMap = {};
  FLOW.forEach((slug) => { capMap[slug] = (CAPTION[slug] || [slug])[0]; });

  const runtime = RUNTIME
    .replace('__FLOW__', JSON.stringify(FLOW))
    .replace('__HOT__', JSON.stringify(HOTSPOTS))
    .replace('__CAP__', JSON.stringify(capMap))
    .replace('__W__', String(DEVICE.w))
    .replace('__H__', String(DEVICE.h));

  const list = FLOW.map((slug) => {
    const [title, blurb] = CAPTION[slug] || [slug, ''];
    return `<li><a href="#${slug}" data-goto="${slug}">${title}<small>${blurb}</small></a></li>`;
  }).join('');

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,viewport-fit=cover">
<meta name="color-scheme" content="light dark">
<meta name="robots" content="noindex">
<meta name="description" content="HopPotty design prototype — a tappable walkthrough rendered from the app's design tokens and vector art.">
<title>HopPotty — Prototype</title>
<link rel="icon" href="/assets/art/appicon-1024.svg">
<link rel="apple-touch-icon" href="/assets/art/appicon-1024.svg">
<link rel="stylesheet" href="/assets/app.css">
</head>
<body class="proto">
<div class="stage">
  <div class="device">
    <div class="viewport" id="viewport">
${layers.join('\n')}
    </div>
  </div>
</div>

<div class="caption" id="caption"></div>

<nav class="chrome" aria-label="Prototype controls">
  <button id="prev" title="Previous screen (←)" aria-label="Previous screen">◀</button>
  <button id="next" title="Next screen (→)" aria-label="Next screen">▶</button>
  <button id="list" title="All screens" aria-label="All screens">☰</button>
  <button id="theme" title="Light / dark appearance (d)" aria-label="Toggle appearance">☾</button>
</nav>

<div class="sheet" id="sheet" role="dialog" aria-label="All screens">
  <div class="sheet-inner">
    <h2>Screens</h2>
    <p class="sub">Tap the buttons inside the phone to walk the flow, or jump straight to a screen.
      Press <b>h</b> to reveal the tap targets, <b>d</b> for dark.</p>
    <ol>${list}</ol>
    <div class="foot">
      <a href="/gallery">Gallery</a><a href="/about">About this prototype</a>
    </div>
    <button class="close" id="sheetclose">Close</button>
  </div>
</div>

<noscript>
  <div class="caption" style="white-space:normal;max-width:80vw;pointer-events:auto">
    The walkthrough needs JavaScript to move between screens.
    The <a href="/gallery" style="color:#8FDCAC">gallery</a> shows every screen without it.
  </div>
</noscript>

<script>${runtime}</script>
</body>
</html>`;
}

// ---------------------------------------------------------------------------
// The gallery
// ---------------------------------------------------------------------------

const HOP_STATES = [
  ['idle', 'At rest. The default pose and the base of the ambient loop.'],
  ['blink', 'One frame of the ambient loop. Nothing else moves.'],
  ['wave', 'Greeting. Onboarding and the Potty Pause shield.'],
  ['talk', 'Speaking a line the child can also hear read aloud.'],
  ['walk', 'On the way to the potty, step one of the routine.'],
  ['wait', 'Patient, hands folded. Shown while nothing is expected.'],
  ['sit', 'Settled. Used where the child is not being hurried.'],
  ['jump', 'Mid-air. Bubble Wash and moments of delight.'],
  ['land', 'The beat after a jump.'],
  ['cheer', 'Celebration. The attempt, never the result.'],
  ['scrub', 'Washing hands, for the hand-washing step and game.'],
  ['catch', 'Reaching for a bubble.'],
  ['full', 'Full-length reference pose.'],
  ['sleep', 'Quiet hours. Nap and bedtime, when HopPotty says nothing.'],
  ['face', 'Head only. Avatars, the tab bar, and question prompts.'],
];

function galleryPage(screens, icons, pondFile) {
  const K = 0.52;   // thumbnails render the real screen, scaled

  const tiles = screens.map((s, i) => {
    const [title, blurb] = s.caption;
    const layer = screenLayer(s.slug + '-thumb', 'light', s.light, { hidden: false })
      .replace('class="screen on"', 'class="screen on"')
      .replace('style="color:', `style="transform:scale(${K});color:`);
    return `<figure class="tile">
      <div class="thumb" style="--k:${K}">${layer}</div>
      <h3>${title}</h3>
      <p class="idx">${String(i + 1).padStart(2, '0')} · ${s.slug}</p>
      <p>${blurb}</p>
    </figure>`;
  }).join('\n');

  const states = HOP_STATES.map(([name, blurb]) => `
    <figure class="state">
      <div class="box"><img src="/assets/art/hop-${name}.svg" alt="Hop, ${name}" loading="lazy"></div>
      <b>hop-${name}</b><span>${blurb}</span>
    </figure>`).join('');

  const iconTiles = icons.map((f) => `
    <figure class="icon">
      <img src="/assets/art/icons/${f}" alt="${f.replace(/\.svg$/, '')}" loading="lazy">
      <span>${f.replace(/\.svg$/, '')}</span>
    </figure>`).join('');

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light dark">
<meta name="robots" content="noindex">
<title>HopPotty — Gallery</title>
<link rel="icon" href="/assets/art/appicon-1024.svg">
<link rel="stylesheet" href="/assets/app.css">
</head>
<body class="page">
<div class="wrap">
  <header class="masthead">
    <img src="/assets/art/appicon-1024.svg" alt="HopPotty app icon">
    <div>
      <h1>HopPotty — Gallery</h1>
      <p>Every screen, every state of Hop, and the art the app ships with.</p>
    </div>
    <nav class="site">
      <a href="/">Prototype</a><a href="/gallery" class="cur">Gallery</a><a href="/about">About</a>
    </nav>
  </header>

  <div class="note">
    These are design renders, not simulator screenshots — drawn in a browser from
    <code>Scripts/tokens.json</code> and the app’s own SVGs. Nothing on this page needs JavaScript.
  </div>

  <h2 class="sec">Screens</h2>
  <p class="secsub">All ${screens.length} screens the harness renders, at 393×852 and scaled to fit.
    Each is the live markup, not an image — zoom in and the type stays sharp.</p>
  <div class="grid">${tiles}</div>

  <h2 class="sec">Hop</h2>
  <p class="secsub">One character, drawn once per state. The app never tweens between poses; it swaps
    them, so every state has to read on its own.</p>

  <div class="loop">
    <div class="stack">
      <img class="a" src="/assets/art/hop-idle.svg" alt="Hop, idle">
      <img class="b" src="/assets/art/hop-blink.svg" alt="Hop, blinking">
    </div>
    <div class="copy">
      <h3>The ambient loop</h3>
      <p>Hop is still by default and blinks every few seconds. That is the entire idle animation:
        no bobbing, no breathing, nothing that pulls a child’s eye back to the screen while they
        are meant to be walking to the bathroom. It honours <code>prefers-reduced-motion</code>.</p>
    </div>
  </div>

  <div class="states" style="margin-top:22px">${states}</div>

  <h2 class="sec">The pond</h2>
  <p class="secsub">Where stars are spent. The scene is assembled from individually unlockable pieces,
    in a fixed catalogue order with fixed prices.</p>
  <div class="pondshot"><img src="/assets/art/${pondFile}" alt="Hop’s pond"></div>

  <h2 class="sec">Icon set</h2>
  <p class="secsub">${icons.length} vectors: the four event marks a caregiver logs with, each with a
    monochrome twin, and the picture answers for Hop’s questions.</p>
  <div class="icons">${iconTiles}</div>

  <h2 class="sec">App icon</h2>
  <p class="secsub">One mark, drawn as a vector and rasterised at build time by the app’s own pipeline.</p>
  <div class="appicons">
    <figure><img src="/assets/art/appicon-1024.svg" width="180" height="180" alt="App icon, 180pt">
      <figcaption>180×180</figcaption></figure>
    <figure><img src="/assets/art/appicon-1024.svg" width="120" height="120" alt="App icon, 120pt">
      <figcaption>120×120</figcaption></figure>
    <figure><img src="/assets/art/appicon-1024.svg" width="60" height="60" alt="App icon, 60pt">
      <figcaption>60×60</figcaption></figure>
    <figure><img src="/assets/art/appicon-1024.svg" width="29" height="29" alt="App icon, 29pt">
      <figcaption>29×29</figcaption></figure>
  </div>

  <footer class="site">
    A design prototype of HopPotty, rendered from the repository’s design tokens and vector art.
    It is not the iOS app. <a href="/about">What this is and is not →</a>
  </footer>
</div>
</body>
</html>`;
}

// ---------------------------------------------------------------------------
// About + docs
// ---------------------------------------------------------------------------

const DOCS = [
  ['ProductVision', 'Docs/ProductVision.md', 'Product Vision', 'What HopPotty is, who it is for, and what it refuses to be.'],
  ['ChildSafety', 'Docs/ChildSafety.md', 'Child Safety', 'The rules the child-facing surface is held to, and why.'],
  ['ScreenTimeArchitecture', 'Docs/ScreenTimeArchitecture.md', 'Screen Time Architecture', 'How the pause is actually built on Apple’s Family Controls, and its limits.'],
  ['BUILD_STATUS', 'BUILD_STATUS.md', 'Build Status', 'What exists in the repository right now.'],
];

const docSlug = (name) => name.toLowerCase().replace(/_/g, '-');

function shell({ title, current, body }) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light dark">
<meta name="robots" content="noindex">
<title>${title}</title>
<link rel="icon" href="/assets/art/appicon-1024.svg">
<link rel="stylesheet" href="/assets/app.css">
</head>
<body class="page">
<div class="wrap">
  <header class="masthead">
    <img src="/assets/art/appicon-1024.svg" alt="HopPotty app icon">
    <div>
      <h1>HopPotty</h1>
      <p>Design prototype</p>
    </div>
    <nav class="site">
      <a href="/"${current === 'proto' ? ' class="cur"' : ''}>Prototype</a>
      <a href="/gallery"${current === 'gallery' ? ' class="cur"' : ''}>Gallery</a>
      <a href="/about"${current === 'about' ? ' class="cur"' : ''}>About</a>
    </nav>
  </header>
${body}
  <footer class="site">
    A design prototype of HopPotty, rendered from the repository’s design tokens and vector art.
    It is not the iOS app, and nothing here is evidence that the app builds or behaves this way on a device.
  </footer>
</div>
</body>
</html>`;
}

function aboutPage() {
  const cards = DOCS.map(([name, , title, blurb]) =>
    `<a href="/about/${docSlug(name)}"><b>${title}</b><span>${blurb}</span></a>`).join('');

  return shell({
    title: 'HopPotty — About this prototype',
    current: 'about',
    body: `
  <div class="doc">
    <h1>About this prototype</h1>

    <p><strong>This is a design prototype, not the HopPotty iOS app.</strong> It is a static web page.
    Every screen you can tap through here was drawn in a browser by the repository’s render harness
    (<code>Scripts/screens/*</code>) from two things: <code>Scripts/tokens.json</code>, the design token
    file the Swift target compiles against, and the SVGs in <code>Art/</code> that the app itself bundles.
    No colour, radius, spacing step or type size on this site can be one the app does not use.</p>

    <p>What it therefore <em>is</em>: a faithful picture of the intended design, walkable on a phone,
    so the flow can be judged as a flow rather than as fourteen separate pictures.</p>

    <p>What it is <em>not</em>:</p>
    <ul>
      <li><strong>Not the app running.</strong> HopPotty’s entire mechanism is Apple’s Family Controls
        and <code>ManagedSettings</code> frameworks — pausing another app’s screen and handing it back.
        There is no web equivalent and there cannot be one. The Potty Pause shield here is a drawing
        of a system view.</li>
      <li><strong>Not evidence the code compiles.</strong> Nothing here was produced by Xcode or an iOS
        simulator. It says nothing about whether the SwiftUI lays out identically on a device.</li>
      <li><strong>Not live data.</strong> Every number, name and time is fixed sample content.
        Nothing is stored, nothing is sent anywhere, and the page makes no network requests at all —
        the typefaces and artwork are embedded in the files it already loaded.</li>
      <li><strong>Not the app’s typefaces.</strong> The renders use Nunito and Fredoka
        (SIL Open Font License) as stand-ins for the system rounded design the app actually uses.
        The app bundles no third-party fonts.</li>
    </ul>

    <p>The interactions are hotspots: transparent links laid over the real buttons. They move the
    prototype from one static screen to the next. Nothing computes, and a control that is not on
    the walkthrough path simply does nothing.</p>

    <h2>The documents</h2>
    <p>These four are the ones worth reading beside the screens — rendered here from the Markdown in
    the repository, unedited.</p>
    <div class="doclist">${cards}</div>
  </div>`,
  });
}

function docPage(title, mdSource, sourcePath) {
  return shell({
    title: `HopPotty — ${title}`,
    current: 'about',
    body: `
  <div class="doc">
    <a class="backlink" href="/about">← About this prototype</a>
    ${mdToHtml(mdSource)}
    <hr>
    <p style="font-size:13px"><em>Rendered from <code>${sourcePath}</code> in the HopPotty repository.</em></p>
  </div>`,
  });
}

// ---------------------------------------------------------------------------
// Build
// ---------------------------------------------------------------------------

function copyArt() {
  const artDir = path.join(ASSETS, 'art');
  fs.mkdirSync(path.join(artDir, 'icons'), { recursive: true });

  for (const [name] of HOP_STATES) {
    const src = path.join(ROOT, 'Art', 'character', `hop-${name}.svg`);
    if (fs.existsSync(src)) fs.copyFileSync(src, path.join(artDir, `hop-${name}.svg`));
    else console.warn('  ! missing', src);
  }

  const icons = fs.readdirSync(path.join(ROOT, 'Art', 'icons')).filter((f) => f.endsWith('.svg')).sort();
  for (const f of icons) fs.copyFileSync(path.join(ROOT, 'Art', 'icons', f), path.join(artDir, 'icons', f));

  fs.copyFileSync(path.join(ROOT, 'Art', 'appicon', 'appicon-1024.svg'), path.join(artDir, 'appicon-1024.svg'));

  // The best single picture of the pond that exists on disk.
  const pondCandidates = ['Art/pond/pond-scene.svg', 'Art/pond/pond-preview.svg', 'Art/pond/pond-base.svg'];
  let pondFile = null;
  for (const rel of pondCandidates) {
    if (fs.existsSync(path.join(ROOT, rel))) {
      pondFile = path.basename(rel);
      fs.copyFileSync(path.join(ROOT, rel), path.join(artDir, pondFile));
      break;
    }
  }
  return { icons, pondFile };
}

function dirSize(dir) {
  let total = 0;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    total += entry.isDirectory() ? dirSize(p) : fs.statSync(p).size;
  }
  return total;
}

function build() {
  fs.rmSync(DIST, { recursive: true, force: true });
  fs.mkdirSync(ASSETS, { recursive: true });

  const { icons, pondFile } = copyArt();
  fs.writeFileSync(path.join(ASSETS, 'app.css'), siteCSS());

  const screens = renderAll();

  const proto = prototypePage(screens);
  fs.writeFileSync(path.join(DIST, 'index.html'), proto);
  fs.mkdirSync(path.join(DIST, 'app'), { recursive: true });
  fs.writeFileSync(path.join(DIST, 'app', 'index.html'), proto);

  fs.mkdirSync(path.join(DIST, 'gallery'), { recursive: true });
  fs.writeFileSync(path.join(DIST, 'gallery', 'index.html'), galleryPage(screens, icons, pondFile));

  fs.mkdirSync(path.join(DIST, 'about'), { recursive: true });
  fs.writeFileSync(path.join(DIST, 'about', 'index.html'), aboutPage());
  for (const [name, rel, title] of DOCS) {
    const abs = path.join(ROOT, rel);
    if (!fs.existsSync(abs)) { console.warn('  ! doc missing', rel); continue; }
    const dir = path.join(DIST, 'about', docSlug(name));
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, 'index.html'), docPage(title, fs.readFileSync(abs, 'utf8'), rel));
  }

  fs.writeFileSync(path.join(DIST, 'robots.txt'), 'User-agent: *\nDisallow: /\n');

  // web/ configuration — committed dist means a static deploy needs no build step,
  // but Vercel can still rebuild from source if it wants to.
  fs.writeFileSync(path.join(WEB, 'vercel.json'), JSON.stringify({
    cleanUrls: true,
    trailingSlash: false,
    outputDirectory: 'dist',
    buildCommand: 'npm run build',
    headers: [
      {
        source: '/assets/(.*)',
        headers: [{ key: 'Cache-Control', value: 'public, max-age=31536000, immutable' }],
      },
      {
        source: '/(.*)',
        headers: [{ key: 'X-Content-Type-Options', value: 'nosniff' }],
      },
    ],
  }, null, 2) + '\n');

  fs.writeFileSync(path.join(WEB, 'package.json'), JSON.stringify({
    name: 'hoppotty-prototype',
    private: true,
    version: '0.0.0',
    description: 'Static design prototype of HopPotty, built from the repository design tokens and art.',
    scripts: { build: 'node ../Scripts/web/build-prototype.js' },
  }, null, 2) + '\n');

  const pages = [];
  (function walk(dir) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.name.endsWith('.html')) pages.push(path.relative(DIST, p));
    }
  })(DIST);

  console.log(`built ${pages.length} pages into web/dist`);
  pages.sort().forEach((p) => console.log('   /' + p.replace(/index\.html$/, '')));
  console.log(`   assets: ${icons.length} icons, ${HOP_STATES.length} Hop states, pond: ${pondFile || 'none'}`);
  console.log(`   size:   ${(dirSize(DIST) / 1024 / 1024).toFixed(2)} MB`);
  return { screens, pages };
}

// ---------------------------------------------------------------------------
// Verification — resolve every hotspot in a real browser
// ---------------------------------------------------------------------------

async function verify() {
  const { chromium } = require('playwright');
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 480, height: 900 } });
  let bad = 0;
  for (const slug of FLOW) {
    await page.goto('file://' + path.join(DIST, 'index.html') + '#' + slug);
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(120);
    const report = await page.evaluate((s) => {
      const layer = document.querySelector('.screen.on');
      const boxes = [...(layer ? layer.querySelectorAll('.hs') : [])].map((a) => ({
        to: a.getAttribute('href').slice(1),
        label: a.getAttribute('aria-label'),
        box: [Math.round(parseFloat(a.style.left)), Math.round(parseFloat(a.style.top)),
              Math.round(parseFloat(a.style.width)), Math.round(parseFloat(a.style.height))],
      }));
      return { boxes, missed: (window.__hotspotReport[s] || {}).missed || [] };
    }, slug);
    const want = (HOTSPOTS[slug] || []).length;
    const ok = report.boxes.length === want && !report.missed.length;
    if (!ok) bad++;
    console.log(`${ok ? '✓' : '✗'} ${slug}  ${report.boxes.length}/${want} hotspots` +
      (report.missed.length ? `  MISSING: ${report.missed.join(', ')}` : ''));
    for (const b of report.boxes) {
      const off = b.box[0] < -2 || b.box[1] < -2 || b.box[0] + b.box[2] > DEVICE.w + 2 ||
        b.box[1] + b.box[3] > DEVICE.h + 2;
      console.log(`     ${off ? '!' : ' '} [${b.box.join(',').padEnd(18)}] ${b.label} → ${b.to}`);
    }
  }
  await browser.close();
  if (bad) process.exitCode = 1;
}

if (require.main === module) {
  build();
  if (process.argv.includes('--verify')) verify().catch((e) => { console.error(e); process.exit(1); });
}

module.exports = { build, mdToHtml, HOTSPOTS, FLOW };
