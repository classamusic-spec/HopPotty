/**
 * First run. Two screens a caregiver sees before they hand the device over.
 *
 * Restraint matters more here than anywhere: this is the moment a parent
 * decides whether the app is serious. One idea per screen, one action per
 * screen, and nothing that has to be read twice.
 */
const { T, c, type, statusBar, homeIndicator, svg, alpha, mix, elevation } = require('./ui');
const { pageDots, MARK } = require('./kit');
const P = T.palette;

/** The primary action on a caregiver screen: full width, one per screen. */
function ctaButton(col, appearance, label) {
  return `<div style="height:56px;border-radius:28px;background:${col.brandAction};display:grid;place-items:center;
    box-shadow:${elevation(appearance, 'raised')};${type('parentHeadline', { color: col.textOnBrand, weight: 'semibold' })};font-size:18px">${label}</div>`;
}

/** 02 — Meet Hop. */
function meetHop(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const D = 300;
  const speck = (x, y, glyph) => `<div style="position:absolute;left:${x}px;top:${y}px">${glyph}</div>`;

  return `
  <div style="display:flex;flex-direction:column;height:100%;background:${col.backgroundPrimary}">
    ${statusBar(col.textPrimary)}
    <div style="flex:1;display:flex;flex-direction:column;padding:0 28px 8px;min-height:0">

      <div style="height:26px;display:flex;align-items:center;justify-content:flex-end">
        <span style="${type('parentCallout', { color: col.textTertiary })};font-size:15px">Skip</span>
      </div>

      <div style="flex:1;display:flex;align-items:center;justify-content:center;min-height:0">
        <div style="position:relative;width:${D}px;height:${D}px">

          <!-- the medallion: a circle of pond, cropped to a disc -->
          <div style="position:absolute;inset:0;border-radius:${D / 2}px;overflow:hidden;
            background:${dark ? alpha(P.hopGreen, .12) : mix(P.hopGreenSoft, P.cloud, .3)}">
            <div style="position:absolute;left:50%;top:50%;width:224px;height:224px;margin:-112px 0 0 -112px;
              border-radius:112px;border:1.5px solid ${alpha(P.hopGreen, dark ? .3 : .26)}"></div>
            <svg width="${D}" height="${D}" viewBox="0 0 ${D} ${D}" style="position:absolute;inset:0">
              <path d="M 0 236 C 60 210, 118 208, 150 214 C 196 222, 244 216, ${D} 232 L ${D} ${D} L 0 ${D} Z"
                    fill="${dark ? alpha(P.hopGreen, .3) : P.hopGreenLight}"/>
              <path d="M 0 258 C 80 240, 190 244, ${D} 256 L ${D} ${D} L 0 ${D} Z"
                    fill="${mix(P.hopGreenLight, P.hopGreen, dark ? .2 : .55)}"/>
              <g stroke="${mix(P.hopGreen, P.hopGreenDeep, .35)}" stroke-width="3.4" fill="none" stroke-linecap="round" opacity="0.7">
                <path d="M 44 250 C 45 242, 47 238, 50 234"/><path d="M 54 252 C 54 244, 55 240, 57 236"/>
                <path d="M 246 246 C 247 238, 249 234, 252 230"/><path d="M 256 248 C 256 240, 257 236, 259 232"/>
              </g>
              <circle cx="70" cy="272" r="5" fill="${P.sunshine}" opacity="0.85"/>
              <circle cx="232" cy="278" r="4" fill="${P.peachPop}" opacity="0.8"/>
            </svg>
          </div>

          <div style="position:absolute;left:50%;top:50%;transform:translate(-50%,-48%)">
            ${svg('Art/character/hop-wave.svg', { width: 258 })}
          </div>

          ${speck(6, 52, MARK.star(P.sunshine, 22))}
          ${speck(272, 104, MARK.star(P.sunshine, 14))}
          ${speck(-2, 168, MARK.leaf(alpha(P.hopGreen, .5), 24))}
        </div>
      </div>

      <div style="flex:0 0 auto;text-align:center;padding:0 4px">
        <div style="${type('hero', { color: col.textPrimary })};font-size:42px">Meet Hop</div>
        <div style="${type('parentBody', { color: col.textSecondary })};font-size:19px;margin-top:10px">
          Your child's new potty-time buddy.</div>
        <div style="${type('parentCallout', { color: col.textTertiary })};font-size:15px;margin-top:14px;
          line-height:1.45;padding:0 6px">
          HopPotty pauses the games your child is playing, invites them to the potty, and hands the game straight back.</div>
      </div>

      <div style="flex:0 0 auto;padding-top:32px">
        ${pageDots(col, 4, 0)}
        <div style="margin-top:22px">${ctaButton(col, appearance, 'Get Started')}</div>
      </div>
    </div>
    ${homeIndicator(col.textPrimary)}
  </div>`;
}

/**
 * 03 — The loop, drawn.
 *
 * The rail down the left is the argument: four beats and a return, so the
 * interruption reads as a circle rather than a punishment with an end.
 */
function theIdea(appearance = 'light') {
  const col = c(appearance);
  const dark = appearance.startsWith('dark');
  const soft = (hex) => (dark ? alpha(hex, 0.2) : mix(hex, '#FFFFFF', 0.78));
  const CARD = 68, GAP = 14, GUT = 46;
  const centres = [0, 1, 2, 3].map((i) => i * (CARD + GAP) + CARD / 2);
  const total = 4 * CARD + 3 * GAP;

  const beat = (word, body, glyph, hue) => `
    <div style="height:${CARD}px;background:${col.surface};border-radius:${T.radius.l}px;padding:0 15px;display:flex;
      align-items:center;gap:14px;box-shadow:${elevation(appearance, 'resting')}">
      <div style="width:42px;height:42px;border-radius:13px;background:${soft(hue)};display:grid;place-items:center;flex:0 0 auto">
        ${glyph}
      </div>
      <div style="flex:1;min-width:0">
        <div style="${type('parentTitle', { color: col.textPrimary, weight: 'bold' })};font-size:17px;letter-spacing:.4px">${word}</div>
        <div style="${type('parentCaption', { color: col.textSecondary })};font-size:13.5px;margin-top:1px">${body}</div>
      </div>
    </div>`;

  const rail = dark ? P.hopGreenLight : P.hopGreenDeep;
  const spine = `<svg width="${GUT}" height="${total}" viewBox="0 0 ${GUT} ${total}"
      style="position:absolute;left:0;top:0;overflow:visible">
    <path d="M 33 ${centres[0]} L 33 ${centres[3]}
             C 33 ${centres[3] + 26}, 7 ${centres[3] + 24}, 7 ${centres[3] - 8}
             L 7 ${centres[0] + 8}
             C 7 ${centres[0] - 24}, 33 ${centres[0] - 26}, 33 ${centres[0]}"
          fill="none" stroke="${alpha(rail, .5)}" stroke-width="2.4" stroke-linecap="round"/>
    ${centres.map((y) => `<path d="M 33 ${y} H ${GUT + 2}" stroke="${alpha(rail, .32)}" stroke-width="2.4" stroke-linecap="round"/>`).join('')}
    ${centres.map((y) => `<circle cx="33" cy="${y}" r="5.4" fill="${rail}"/>`).join('')}
    <path d="M 26.5 ${centres[0] + CARD / 2 + 1} l 6.5 8 l 6.5 -8" fill="none" stroke="${rail}"
          stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M 0.5 ${(centres[0] + centres[3]) / 2 + 5} l 6.5 -8 l 6.5 8" fill="none" stroke="${alpha(rail, .85)}"
          stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>
  </svg>`;

  return `
  <div style="display:flex;flex-direction:column;height:100%;background:${col.backgroundPrimary}">
    ${statusBar(col.textPrimary)}
    <div style="flex:1;display:flex;flex-direction:column;padding:0 24px 8px;min-height:0">

      <div style="height:26px;display:flex;align-items:center;justify-content:flex-end">
        <span style="${type('parentCallout', { color: col.textTertiary })};font-size:15px">Skip</span>
      </div>

      <div style="flex:0 0 auto;padding:10px 2px 0">
        <div style="${type('parentFootnote', { color: col.brandAction, weight: 'semibold' })};font-size:12px;
          letter-spacing:.9px;text-transform:uppercase">The idea</div>
        <div style="${type('parentLargeTitle', { color: col.textPrimary })};font-size:32px;margin-top:5px">Pause. Potty. Play.</div>
        <div style="${type('parentCallout', { color: col.textSecondary })};font-size:15px;margin-top:8px;line-height:1.42">
          One loop, four beats. Your child gets a routine; the game they were promised comes back.</div>
      </div>

      <div style="flex:1;display:flex;flex-direction:column;min-height:0;padding-top:26px">
        <div style="position:relative;padding-left:${GUT}px;height:${total}px">
          ${spine}
          <div style="display:flex;flex-direction:column;gap:${GAP}px">
            ${beat('PLAY', 'Your child is deep in a game.', MARK.play(P.hopGreenDeep, 21), P.hopGreen)}
            ${beat('PAUSE', 'The app goes quiet. Hop appears.', MARK.pause(P.sunshineDeep, 21), P.sunshine)}
            ${beat('POTTY', 'Try, wipe, flush, wash, high five.', MARK.ring(P.lavenderDeep, 21), P.lavender)}
            ${beat('PLAY', 'The game comes right back.', MARK.play(P.pondBlueDeep, 21), P.pondBlue)}
          </div>
        </div>

        <div style="display:flex;align-items:center;justify-content:center;gap:8px;margin-top:14px">
          ${MARK.loop(col.textTertiary, 15)}
          <span style="${type('parentCaption', { color: col.textTertiary })};font-size:13.5px">
            And around again, on the rhythm you set.</span>
        </div>

        <div style="height:26px"></div>

        <div style="display:flex;gap:13px;align-items:flex-start;background:${col.surface};border-radius:${T.radius.l}px;
          padding:14px 15px;box-shadow:${elevation(appearance, 'resting')}">
          <div style="width:34px;height:34px;border-radius:11px;flex:0 0 auto;display:grid;place-items:center;
            background:${dark ? alpha(P.hopGreen, .2) : P.hopGreenSoft}">${MARK.lock(dark ? P.hopGreenLight : P.hopGreenInk, 18)}</div>
          <div style="flex:1;${type('parentCaption', { color: col.textSecondary })};font-size:13.5px;line-height:1.42">
            The pause ends on its own timer. Screen access is never held back for a result.</div>
        </div>
        <div style="flex:1"></div>
      </div>

      <div style="flex:0 0 auto">
        ${pageDots(col, 4, 1)}
        <div style="margin-top:20px">${ctaButton(col, appearance, 'Continue')}</div>
      </div>
    </div>
    ${homeIndicator(col.textPrimary)}
  </div>`;
}

module.exports = { meetHop, theIdea, ctaButton };
