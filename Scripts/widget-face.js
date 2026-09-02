#!/usr/bin/env node
/**
 * Lifts Hop's head out of the shipped pose art and emits it for the widget.
 *
 *   Art/character/hop-{idle,wave,jump,cheer,sleep}.svg     the drawing (input)
 *   Art/character/hop-face.svg                             the frame, and the proof
 *     ↓
 *   Extensions/HopPottyWidgets/HopWidgetFaceArt.swift      path data, one list per mood
 *   Art/render/widget-face/*.svg                           the same data, re-rendered
 *
 * ## Why this exists
 *
 * The widget extension is not a member of the app's design system — `project.yml`
 * gives it `HopPottyCore` and `HopPottyDesignTokens`, and nothing else — and it
 * bundles no resources, so it can neither call `HopCharacterView` nor load
 * `Art/character/hop-face.svg`. Until now that meant a hand-approximated face: a
 * circle, two smaller circles and a capsule, which is a frog only if you are
 * told it is one.
 *
 * So the head comes across as *data* instead, exactly the way the lockup does
 * (`Scripts/logo-art.js` → `HopLogoArtwork.swift`): every ellipse, circle and
 * curve of the real drawing, resolved to absolute coordinates, emitted as the
 * five commands a short Swift decoder understands, and re-rendered here so the
 * result can be measured against the artwork rather than admired.
 *
 * Nothing is redrawn, re-proportioned or recoloured. The one thing this script
 * decides is *which* elements are the head: the head's share of
 * `#hop-silhouette` — the exterior outline, which is drawn as a sibling of the
 * figure so the parts union without seams — followed by the whole of `#head`,
 * which in `Scripts/hop-art.js`'s `figure()` is the internal rim, the head
 * fills, the face group and (for `sleep`) the two z's. The body is emitted
 * around those and the ground shadow before them, and neither comes across.
 *
 * ## Nothing about the canvas is assumed
 *
 * `hop-art.js` solves its own reference→canvas transform from the drawing, and
 * has already changed it once. So this script reads every frame it uses: the
 * shared box and the anchor come from `hop-face.svg`'s viewBox and its own head
 * group, and each pose is placed by composing that pose's matrices and scaling
 * to the reference. A change of canvas moves the art and this file follows it;
 * a change of *drawing* moves the digest, and `Scripts/verify-config.sh` says so.
 *
 * ## Colour
 *
 * Fills are matched back to `HopPalette` by value: this script reads
 * `HopPalette.swift`, and a fill that is a token's colour is emitted as that
 * token's *name*, so the widget says `HopPalette.hopGreen` and never a hex
 * literal. Two of the face's colours have no brand token — the mid-green of the
 * spots, and the tongue's pink — exactly as `HopCharacterPalette` notes in the
 * app; those two are carried as values, from the art, with the same reason
 * given. If a green ever moves, the assertion here fails rather than the widget
 * quietly painting last month's frog.
 *
 *   node Scripts/widget-face.js           regenerate
 *   node Scripts/widget-face.js --check   prove the emitted art against the artwork
 *   node Scripts/widget-face.js --sheet   render inspection PNGs, colour and accessory
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.resolve(__dirname, '..');
const ART = path.join(ROOT, 'Art', 'character');
const PALETTE_SWIFT = path.join(ROOT, 'HopPottyKit', 'Sources', 'HopPottyDesignTokens', 'HopPalette.swift');
const SWIFT = path.join(ROOT, 'Extensions', 'HopPottyWidgets', 'HopWidgetFaceArt.swift');
const VIEW_SWIFT = path.join(ROOT, 'Extensions', 'HopPottyWidgets', 'HopWidgetFace.swift');
const PROOF = path.join(ROOT, 'Art', 'render', 'widget-face');

/** `HopWidgetMood.allCases`, in declaration order. Each is also a `HopPose`. */
const MOODS = ['idle', 'wave', 'jump', 'cheer', 'sleep'];

/**
 * The head-only pose, and the frame everything is expressed in.
 *
 * `hop-art.js` draws it from the same `headShape`/`eyes`/`mouth` calls as `idle`
 * with no body around it, so it is an independently generated copy of what this
 * script has to lift out of `hop-idle.svg`. That makes it two things at once:
 * the box the widget's coordinates live in, and the answer `--check` marks the
 * extraction against.
 */
const REFERENCE = 'face';

/** Hop's own rotation point, in the 150×160 space every pose is authored in. */
const FACE_CENTRE = { x: 75, y: 50 };

// ---------------------------------------------------------------------------
// Matrices — [a, b, c, d, e, f], as SVG writes them
// ---------------------------------------------------------------------------

const IDENTITY = [1, 0, 0, 1, 0, 0];

/** `m` applied after `n`: the matrix for a child of a transformed group. */
function mul(m, n) {
  return [
    m[0] * n[0] + m[2] * n[1],
    m[1] * n[0] + m[3] * n[1],
    m[0] * n[2] + m[2] * n[3],
    m[1] * n[2] + m[3] * n[3],
    m[0] * n[4] + m[2] * n[5] + m[4],
    m[1] * n[4] + m[3] * n[5] + m[5],
  ];
}

function apply(m, p) {
  return { x: m[0] * p.x + m[2] * p.y + m[4], y: m[1] * p.x + m[3] * p.y + m[5] };
}

function invert(m) {
  const det = m[0] * m[3] - m[1] * m[2];
  if (!det) throw new Error('singular transform');
  return [
    m[3] / det, -m[1] / det, -m[2] / det, m[0] / det,
    (m[2] * m[5] - m[3] * m[4]) / det,
    (m[1] * m[4] - m[0] * m[5]) / det,
  ];
}

/** How much `m` scales a length. Every transform in this art is uniform. */
function scaleOf(m) {
  return Math.sqrt(Math.abs(m[0] * m[3] - m[1] * m[2]));
}

function parseTransform(value) {
  let m = IDENTITY;
  if (!value) return m;
  for (const call of value.matchAll(/([a-zA-Z]+)\s*\(([^)]*)\)/g)) {
    const a = call[2].trim().split(/[\s,]+/).map(Number);
    switch (call[1]) {
      case 'translate':
        m = mul(m, [1, 0, 0, 1, a[0], a[1] || 0]);
        break;
      case 'scale':
        m = mul(m, [a[0], 0, 0, a.length > 1 ? a[1] : a[0], 0, 0]);
        break;
      case 'rotate': {
        const r = (a[0] * Math.PI) / 180;
        const cos = Math.cos(r), sin = Math.sin(r);
        const cx = a[1] || 0, cy = a[2] || 0;
        m = mul(m, mul([1, 0, 0, 1, cx, cy], mul([cos, sin, -sin, cos, 0, 0], [1, 0, 0, 1, -cx, -cy])));
        break;
      }
      case 'matrix':
        m = mul(m, a);
        break;
      default:
        throw new Error(`unsupported transform: ${call[1]}`);
    }
  }
  return m;
}

const matrixAttr = (m) => `matrix(${m.map((n) => +n.toFixed(6)).join(' ')})`;

// ---------------------------------------------------------------------------
// Reading the artwork
// ---------------------------------------------------------------------------

const TAG = /<(\/?)([A-Za-z][\w:-]*)((?:\s+[\w:-]+\s*=\s*"[^"]*")*)\s*(\/?)>/g;

function attrs(raw) {
  const out = {};
  for (const a of raw.matchAll(/([\w:-]+)\s*=\s*"([^"]*)"/g)) out[a[1]] = a[2];
  return out;
}

/**
 * Every drawable in the file, in document order, with its transform composed
 * and its paint inherited.
 *
 * Deliberately not an XML library: the input is one generator's output, six
 * element types wide, and a parser that throws on anything it has not seen
 * before is worth more here than one that shrugs and drops a feature.
 */
function read(src) {
  const drawables = [];
  const clips = {};
  const stack = [{ matrix: IDENTITY, style: {}, clip: null, groups: [] }];
  let collecting = null; // the clipPath id currently being filled
  let pendingText = null;

  TAG.lastIndex = 0;
  let match;
  while ((match = TAG.exec(src))) {
    const [full, closing, name, rawAttrs] = match;
    const selfClosing = match[4] === '/';
    const a = attrs(rawAttrs);
    const top = stack[stack.length - 1];

    if (pendingText) {
      // <text …>z</text>: the glyph sits between the tags.
      pendingText.text = src.slice(pendingText.at, match.index).trim();
      drawables.push(pendingText);
      pendingText = null;
    }

    if (closing) {
      if (name === 'clipPath') collecting = null;
      else if (name === 'g' || name === 'svg') stack.pop();
      continue;
    }

    const style = {
      fill: a.fill !== undefined ? a.fill : top.style.fill,
      stroke: a.stroke !== undefined ? a.stroke : top.style.stroke,
      strokeWidth: a['stroke-width'] !== undefined ? Number(a['stroke-width']) : top.style.strokeWidth,
      opacity: a.opacity !== undefined ? Number(a.opacity) * (top.style.opacity ?? 1) : top.style.opacity,
      fontSize: a['font-size'] !== undefined ? Number(a['font-size']) : top.style.fontSize,
    };
    const matrix = mul(top.matrix, parseTransform(a.transform));
    const clipRef = /url\(#([^)]+)\)/.exec(a['clip-path'] || '');
    const clip = clipRef ? clipRef[1] : top.clip;
    // The ids of every group a record is inside. `hop-art.js` names the
    // anatomical groups, and the extraction below asks "is this inside #head"
    // rather than counting elements — a question that survives the rig gaining
    // or losing a part.
    const groups = a.id ? [...top.groups, a.id] : top.groups;

    if (name === 'svg' || name === 'g') {
      if (!selfClosing) stack.push({ matrix, style, clip, groups });
      continue;
    }
    if (name === 'clipPath') {
      collecting = a.id;
      clips[collecting] = { matrix, d: null };
      continue;
    }

    const record = { name, attrs: a, matrix, style, clip, groups };
    if (collecting) {
      clips[collecting].d = geometry(record);
      continue;
    }
    if (name === 'text') {
      pendingText = { ...record, at: match.index + full.length };
      continue;
    }
    drawables.push(record);
  }
  return { drawables, clips };
}

// ---------------------------------------------------------------------------
// Geometry → absolute path data
// ---------------------------------------------------------------------------

const KAPPA = 0.5522847498307936;

const round = (n) => {
  const r = Math.round(n * 100) / 100;
  return Object.is(r, -0) ? 0 : r;
};

const fmt = (p) => `${round(p.x)} ${round(p.y)}`;

/** An ellipse as four cubic segments, starting at three o'clock. */
function ellipsePath(cx, cy, rx, ry, m) {
  const p = (x, y) => apply(m, { x, y });
  const corner = [[cx + rx, cy], [cx, cy + ry], [cx - rx, cy], [cx, cy - ry]];
  const control = [
    [[cx + rx, cy + ry * KAPPA], [cx + rx * KAPPA, cy + ry]],
    [[cx - rx * KAPPA, cy + ry], [cx - rx, cy + ry * KAPPA]],
    [[cx - rx, cy - ry * KAPPA], [cx - rx * KAPPA, cy - ry]],
    [[cx + rx * KAPPA, cy - ry], [cx + rx, cy - ry * KAPPA]],
  ];
  const out = [`M ${fmt(p(...corner[0]))}`];
  for (let i = 0; i < 4; i++) {
    const [c1, c2] = control[i];
    out.push(`C ${fmt(p(...c1))} ${fmt(p(...c2))} ${fmt(p(...corner[(i + 1) % 4]))}`);
  }
  out.push('Z');
  return out.join(' ');
}

/**
 * `d` → absolute `M` / `L` / `C` / `Q` / `Z`, transformed.
 *
 * The art uses seven of the twenty command forms, and no arcs inside a head;
 * anything else throws rather than being silently dropped, because a dropped
 * command is a face with a piece missing that nobody notices until it ships.
 */
function pathData(d, m) {
  const toks = d.match(/[a-zA-Z]|-?\d*\.?\d+(?:[eE][-+]?\d+)?/g) || [];
  const out = [];
  let i = 0, cmd = null, cur = { x: 0, y: 0 }, start = { x: 0, y: 0 };
  const num = () => Number(toks[i++]);
  const next = (rel) => (rel ? { x: cur.x + num(), y: cur.y + num() } : { x: num(), y: num() });
  const emit = (letter, ...points) => out.push(`${letter} ${points.map((p) => fmt(apply(m, p))).join(' ')}`);

  while (i < toks.length) {
    if (/[a-zA-Z]/.test(toks[i])) cmd = toks[i++];
    const rel = cmd === cmd.toLowerCase();
    switch (cmd.toUpperCase()) {
      case 'M':
        cur = next(rel); start = { ...cur }; emit('M', cur); cmd = rel ? 'l' : 'L';
        break;
      case 'L': cur = next(rel); emit('L', cur); break;
      case 'H': cur = { x: rel ? cur.x + num() : num(), y: cur.y }; emit('L', cur); break;
      case 'V': cur = { x: cur.x, y: rel ? cur.y + num() : num() }; emit('L', cur); break;
      case 'C': {
        const c1 = next(rel), c2 = next(rel), end = next(rel);
        emit('C', c1, c2, end); cur = end;
        break;
      }
      case 'Q': {
        const c = next(rel), end = next(rel);
        emit('Q', c, end); cur = end;
        break;
      }
      case 'Z': out.push('Z'); cur = { ...start }; break;
      default:
        throw new Error(`unsupported path command '${cmd}' in "${d.slice(0, 40)}…"`);
    }
  }
  return out.join(' ');
}

function geometry(record) {
  const a = record.attrs;
  const m = record.matrix;
  switch (record.name) {
    case 'circle':
      return ellipsePath(Number(a.cx), Number(a.cy), Number(a.r), Number(a.r), m);
    case 'ellipse':
      return ellipsePath(Number(a.cx), Number(a.cy), Number(a.rx), Number(a.ry), m);
    case 'path':
      return pathData(a.d, m);
    default:
      throw new Error(`unsupported element <${record.name}>`);
  }
}

/**
 * The box around emitted path data.
 *
 * Every number in it is an on-curve point or a control point, so this contains
 * the drawing rather than hugging it. For ellipses — which is most of a face —
 * the two are the same, because a four-segment ellipse's control points sit on
 * its own bounding box.
 */
function bounds(d) {
  const nums = (d.match(/-?\d*\.?\d+/g) || []).map(Number);
  let box = { x0: Infinity, y0: Infinity, x1: -Infinity, y1: -Infinity };
  for (let i = 0; i < nums.length; i += 2) {
    box.x0 = Math.min(box.x0, nums[i]); box.x1 = Math.max(box.x1, nums[i]);
    box.y0 = Math.min(box.y0, nums[i + 1]); box.y1 = Math.max(box.y1, nums[i + 1]);
  }
  return box;
}

// ---------------------------------------------------------------------------
// The palette, read from the token package
// ---------------------------------------------------------------------------

/** `#RRGGBB` → token name, from `HopPalette.swift` itself. */
function paletteByValue() {
  const src = fs.readFileSync(PALETTE_SWIFT, 'utf8');
  const out = {};
  for (const m of src.matchAll(/static let (\w+) = HopColorValue\(hex: 0x([0-9A-Fa-f]{6})\)/g)) {
    const hex = `#${m[2].toUpperCase()}`;
    if (!out[hex]) out[hex] = m[1];
  }
  return out;
}

/**
 * What each part of the face is painted, and which token that must be.
 *
 * `token: null` is a character-only colour: the art uses it, the brand ramp does
 * not have it, and `HopCharacterPalette` in the app declares it as a raw value
 * for the same reason. Everything else is asserted against `HopPalette` by
 * value, at generation time.
 *
 * Declaration order is paint order, and therefore the order of
 * `HopWidgetFaceRole` in the widget.
 */
const ROLES = {
  outline: { hex: '#356B50', token: 'hopOutline' },
  head: { hex: '#63C88A', token: 'hopGreen' },
  spot: { hex: '#45A971', token: null },
  eyeWhite: { hex: '#FFFFFF', token: 'white' },
  pupil: { hex: '#243047', token: 'midnight' },
  highlight: { hex: '#FFFFFF', token: 'white' },
  closedEye: { hex: '#1B5E39', token: 'hopGreenInk' },
  cheek: { hex: '#FF9F8F', token: 'peachPop' },
  nostril: { hex: '#1B5E39', token: 'hopGreenInk' },
  mouthInterior: { hex: '#8A3F30', token: 'peachInk' },
  tongue: { hex: '#FF6F7D', token: null },
  smile: { hex: '#1B5E39', token: 'hopGreenInk' },
  sleepMark: { hex: '#1B5E39', token: 'hopGreenInk' },
};

const ROLE_ORDER = Object.keys(ROLES);

// ---------------------------------------------------------------------------
// Extraction
// ---------------------------------------------------------------------------

const isCrown = (r) =>
  r.name === 'ellipse' && r.attrs.cx === '75' && r.attrs.cy === '40' &&
  r.attrs.rx === '44' && r.attrs.ry === '33';

/** The head group's own matrix in one pose file, and where it puts Hop's
 * rotation point. Everything else in this script is relative to these two. */
function anchorOf(src, label) {
  const { drawables } = read(src);
  const crown = drawables.findIndex(isCrown);
  if (crown < 0) throw new Error(`${label}: no crown ellipse — has hop-art.js's headShape changed?`);
  const headMatrix = drawables[crown].matrix;

  // Where the head *starts*, which is not where the crown starts.
  //
  // Hop's outline is drawn under his fills, so `#head` opens with its own
  // internal rim and only then paints the crown. Slicing at the crown drops
  // that rim, and the widget was the one un-outlined Hop in the product
  // because of it. Walk back over everything inside `#head` instead.
  let start = crown;
  while (start > 0 && drawables[start - 1].groups.includes('head')) start -= 1;

  // And the exterior silhouette, which is drawn earlier still — `#hop-silhouette`
  // is a sibling of the figure, not part of it, so that the union of all the
  // parts has no interior seams. It holds one child per part, and its children
  // are not named; but the head's share of it is drawn from the same four
  // shapes as the head's own rim, so it is the child with that geometry, under
  // that placement. That is the band that makes Hop hold his shape at 24 points.
  //
  // Matching on the geometry rather than the matrix matters: the head is placed
  // by `rotate(0 75 50)` in every pose that does not tilt it, and a rotation of
  // nothing is the identity — so half the body shares the head's matrix.
  const rim = drawables[start];
  if (start === crown || (rim.style.fill || '').toUpperCase() !== ROLES.outline.hex) {
    throw new Error(`${label}: #head does not open with its outline rim — has hop-art.js's outline system changed?`);
  }
  const silhouette = drawables
    .map((d, i) => [d, i])
    .filter(([d]) => d.groups.includes('hop-silhouette') &&
      d.attrs.d === rim.attrs.d && same(d.matrix, rim.matrix))
    .map(([, i]) => i);
  if (!silhouette.length) {
    throw new Error(`${label}: #hop-silhouette has no part drawn from the head's shapes — has hop-art.js's outline system changed?`);
  }

  return {
    index: start,
    silhouette,
    matrix: headMatrix,
    at: apply(headMatrix, FACE_CENTRE),
    scale: scaleOf(headMatrix),
    drawables,
  };
}

/** Two matrices are the same placement, to within the rounding the art emits. */
function same(a, b) {
  return a.every((n, i) => Math.abs(n - b[i]) < 1e-6);
}

/** The shared frame: `hop-face.svg`'s viewBox, and where it puts the head. */
function reference() {
  const src = fs.readFileSync(path.join(ART, `hop-${REFERENCE}.svg`), 'utf8');
  const box = /viewBox="([^"]+)"/.exec(src)[1].trim().split(/[\s,]+/).map(Number);
  const anchor = anchorOf(src, REFERENCE);
  return {
    viewBox: { x: box[0], y: box[1], width: box[2], height: box[3] },
    anchor: anchor.at,
    scale: anchor.scale,
  };
}

/**
 * Which part of the face a record is.
 *
 * By colour, which is how the drawing distinguishes them too — with three
 * disambiguations colour alone cannot make: a white inside an eye's clip is the
 * catchlight and not the eye; and the ink green is a nostril when it is filled,
 * a shut eye when it is a stroke up at eye height, and the closed smile when it
 * is a stroke down at mouth height.
 */
function roleFor(record, d, frame) {
  const paint = (record.style.fill && record.style.fill !== 'none' ? record.style.fill : record.style.stroke) || '';
  const hex = paint.toUpperCase();
  const stroked = !record.style.fill || record.style.fill === 'none';
  switch (hex) {
    case ROLES.outline.hex: return 'outline';
    case ROLES.head.hex: return 'head';
    case ROLES.spot.hex: return 'spot';
    case ROLES.eyeWhite.hex: return record.clip ? 'highlight' : 'eyeWhite';
    case ROLES.pupil.hex: return 'pupil';
    case ROLES.cheek.hex: return 'cheek';
    case ROLES.mouthInterior.hex: return 'mouthInterior';
    case ROLES.tongue.hex: return 'tongue';
    case ROLES.nostril.hex: {
      if (!stroked) return 'nostril';
      const box = bounds(d);
      // Ten reference units above the rotation point is between the eyes
      // (21 above) and the mouth (0–4 below) with room on either side.
      return (box.y0 + box.y1) / 2 < frame.anchor.y - 10 * frame.scale ? 'closedEye' : 'smile';
    }
    default:
      throw new Error(`no role for paint ${paint}`);
  }
}

/**
 * One mood's head, in the shared frame.
 *
 * Everything from the crown ellipse onward — see the header — placed so that
 * this pose's own head-rotation point lands on the reference's, at the
 * reference's scale. A pose's lift and lean leave with that placement; its tilt
 * stays baked into the coordinates, because a tilted head is what `sleep` *is*.
 */
function head(pose, frame) {
  const file = path.join(ART, `hop-${pose}.svg`);
  const src = fs.readFileSync(file, 'utf8');
  const { drawables, clips } = read(src);
  const anchor = anchorOf(src, pose);
  const k = frame.scale / anchor.scale;
  const norm = mul(
    [1, 0, 0, 1, frame.anchor.x, frame.anchor.y],
    mul([k, 0, 0, k, 0, 0], [1, 0, 0, 1, -anchor.at.x, -anchor.at.y])
  );

  const shapes = [];
  const marks = [];
  const source = [...anchor.silhouette.map((i) => drawables[i]), ...drawables.slice(anchor.index)];
  for (const record of source) {
    const m = mul(norm, record.matrix);
    if (record.name === 'text') {
      const at = apply(m, { x: Number(record.attrs.x), y: Number(record.attrs.y) });
      marks.push({
        text: record.text,
        x: round(at.x),
        y: round(at.y),
        size: round(record.style.fontSize * scaleOf(m)),
        opacity: record.style.opacity ?? 1,
      });
      continue;
    }
    const d = geometry({ ...record, matrix: m });
    const role = roleFor(record, d, frame);
    // An outline is painted with the same colour on both sides — filled so the
    // parts union without seams, stroked so the union grows. Only the stroke
    // ever shows, because the part's own fill lands on top of the fill; so it
    // crosses as a stroke, and the widget draws one path instead of two.
    const stroked = role === 'outline' || !record.style.fill || record.style.fill === 'none';
    shapes.push({
      role,
      d,
      strokeWidth: stroked ? round(record.style.strokeWidth * scaleOf(m)) : 0,
      opacity: record.style.opacity ?? 1,
      clip: record.clip
        ? pathData(clips[record.clip].d, norm)
        : null,
    });
  }
  return { pose, shapes, marks, norm, back: invert(norm), source: src };
}

// ---------------------------------------------------------------------------
// Proof SVGs — the emitted data, re-rendered
// ---------------------------------------------------------------------------

/**
 * The emitted data as an SVG again.
 *
 * `place` puts it back where it came from, so a proof can be laid over the pose
 * it was lifted out of and the difference measured. Without it the head sits in
 * the shared frame, which is what the widget draws.
 */
function proofSVG(art, { viewBox, place = null, paint = (role) => ROLES[role].hex } = {}) {
  const defs = [];
  const body = [];
  art.shapes.forEach((shape, i) => {
    const colour = paint(shape.role);
    if (colour === null) return;
    let clip = '';
    if (shape.clip) {
      defs.push(`  <clipPath id="c${i}"><path d="${shape.clip}"/></clipPath>`);
      clip = ` clip-path="url(#c${i})"`;
    }
    const opacity = shape.opacity === 1 ? '' : ` opacity="${round(shape.opacity)}"`;
    body.push(shape.strokeWidth
      ? `  <path d="${shape.d}" fill="none" stroke="${colour}" stroke-width="${shape.strokeWidth}" stroke-linecap="round"${opacity}${clip}/>`
      : `  <path d="${shape.d}" fill="${colour}"${opacity}${clip}/>`);
  });
  for (const mark of art.marks) {
    const colour = paint('sleepMark');
    if (colour === null) continue;
    body.push(`  <text x="${mark.x}" y="${mark.y}" font-size="${mark.size}" fill="${colour}" ` +
      `font-family="system-ui, sans-serif" font-weight="800" opacity="${round(mark.opacity)}">${mark.text}</text>`);
  }
  const open = place ? `<g transform="${matrixAttr(art.back)}">` : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox.x} ${viewBox.y} ${viewBox.width} ${viewBox.height}" ` +
    `width="${viewBox.width}" height="${viewBox.height}">\n` +
    (defs.length ? `<defs>\n${defs.join('\n')}\n</defs>\n` : '') +
    `${open}\n${body.join('\n')}\n${place ? '</g>' : ''}\n</svg>\n`;
}

/** The viewBox of a pose file, so a proof can be rendered over it. */
function viewBoxOf(pose) {
  const src = fs.readFileSync(path.join(ART, `hop-${pose}.svg`), 'utf8');
  const box = /viewBox="([^"]+)"/.exec(src)[1].trim().split(/[\s,]+/).map(Number);
  return { x: box[0], y: box[1], width: box[2], height: box[3] };
}

/** What `Scripts/verify-config.sh` recomputes: the art this file was built from. */
function sourceDigest() {
  const hash = crypto.createHash('sha256');
  for (const pose of MOODS) hash.update(fs.readFileSync(path.join(ART, `hop-${pose}.svg`)));
  return hash.digest('hex').slice(0, 16);
}

// ---------------------------------------------------------------------------
// The stencil the accessory families get, read back out of the widget
// ---------------------------------------------------------------------------

/**
 * The role → alpha table in `HopWidgetFace.swift`, parsed.
 *
 * Read rather than duplicated: `--sheet` exists to show what the lock screen
 * will actually get, and a second copy of the table here would be a sheet of
 * what it used to get. The Swift is written one case per line for this.
 */
function stencil() {
  const src = fs.readFileSync(VIEW_SWIFT, 'utf8');
  const block = /MARK: Stencil([\s\S]*?)\n    }/.exec(src);
  if (!block) throw new Error('HopWidgetFace.swift: no "MARK: Stencil" table to read');
  const out = {};
  for (const m of block[1].matchAll(/case \.(\w+): (nil|[\d.]+)/g)) {
    out[m[1]] = m[2] === 'nil' ? null : Number(m[2]);
  }
  const missing = ROLE_ORDER.filter((r) => !(r in out));
  if (missing.length) throw new Error(`HopWidgetFace.swift stencil has no entry for: ${missing.join(', ')}`);
  return out;
}

// ---------------------------------------------------------------------------
// Swift
// ---------------------------------------------------------------------------

function swiftSource(arts, frame, content, digest) {
  const palette = paletteByValue();

  const roleLines = ROLE_ORDER.map((role) => {
    const { hex, token } = ROLES[role];
    if (token && palette[hex] !== token) {
      throw new Error(`${role}: the art paints ${hex}; HopPalette.${token} is not that colour`);
    }
    return token
      ? `//   ${role.padEnd(14)} ${hex}  HopPalette.${token}`
      : `//   ${role.padEnd(14)} ${hex}  character-only — the brand ramp has no such token`;
  }).join('\n');

  const shapeList = (art) => art.shapes.map((s) => {
    const parts = [`role: .${s.role}`, `d: "${s.d}"`];
    if (s.strokeWidth) parts.push(`strokeWidth: ${s.strokeWidth}`);
    if (s.opacity !== 1) parts.push(`opacity: ${round(s.opacity)}`);
    if (s.clip) parts.push(`clip: "${s.clip}"`);
    return `        HopWidgetFaceShape(${parts.join(', ')}),`;
  }).join('\n');

  const markList = (art) => art.marks.map((m) =>
    `        HopWidgetFaceMark(x: ${m.x}, y: ${m.y}, size: ${m.size}, opacity: ${round(m.opacity)}),`
  ).join('\n');

  const moodBlocks = arts.map((art) => {
    const marks = art.marks.length
      ? `\n    /// The ${art.marks.length} z's, which are type in the artwork rather than paths.\n` +
        `    static let ${art.pose}Marks: [HopWidgetFaceMark] = [\n${markList(art)}\n    ]\n`
      : '';
    return `    /// ${art.shapes.length} shapes from \`Art/character/hop-${art.pose}.svg\`.
    static let ${art.pose}: [HopWidgetFaceShape] = [
${shapeList(art)}
    ]
${marks}`;
  }).join('\n');

  return `// Generated by Scripts/widget-face.js from Art/character/hop-{${MOODS.join(',')}}.svg.
// Do not edit.
//
// source-digest: ${digest}
//
// Hop's head, as the artwork draws it, for a process that can load neither the
// design system nor the art. Every ellipse is the drawing's own ellipse resolved
// to four cubic segments; every curve is the drawing's own curve. Nothing here
// was redrawn or re-proportioned — \`--check\` renders these coordinates back
// over the artwork they came from and measures the difference.
//
// The five lists are the five \`HopWidgetMood\` cases, which are also five
// \`HopPose\` cases, which are the five files above. Each is the whole head at
// that pose: the tilt of a sleeping head is in the coordinates; its lift and
// lean are not, because a crop follows the head and only the head's own
// rotation survives it.
//
// \`HopWidgetFace.swift\` turns these into \`Path\`s and decides what a role is
// painted — including the alpha-only reading the lock screen's monochrome
// families need, which is why a role is carried here and a colour is not:
//
${roleLines}
//
// Regenerate with:  node Scripts/widget-face.js
// Verify with:      node Scripts/widget-face.js --check
//                   Scripts/verify-config.sh    (the digest above, against the art)

import CoreGraphics
import HopPottyCore

enum HopWidgetFaceArt {

    /// The box the coordinates below live in — \`Art/character/hop-face.svg\`'s
    /// own viewBox, shared by all five moods so no feature moves between them.
    static let viewBox = CGRect(x: ${frame.viewBox.x}, y: ${frame.viewBox.y}, width: ${frame.viewBox.width}, height: ${frame.viewBox.height})

    /// What the drawing actually covers, across all five moods together — which
    /// is not the whole box. The view fits *this* to its frame, so \`size\` is
    /// the width of Hop's head rather than the width of the artboard's margins,
    /// and so the tilted mood and the one wearing z's do not shrink the other
    /// three.
    static let content = CGRect(x: ${content.x}, y: ${content.y}, width: ${content.width}, height: ${content.height})

    static func shapes(for mood: HopWidgetMood) -> [HopWidgetFaceShape] {
        switch mood {
${MOODS.map((m) => `        case .${m}: ${m}`).join('\n')}
        }
    }

    static func marks(for mood: HopWidgetMood) -> [HopWidgetFaceMark] {
        switch mood {
${MOODS.map((m) => `        case .${m}: ${arts.find((a) => a.pose === m).marks.length ? `${m}Marks` : '[]'}`).join('\n')}
        }
    }

${moodBlocks}}
`;
}

// ---------------------------------------------------------------------------

function build({ quiet = false } = {}) {
  const frame = reference();
  const arts = MOODS.map((pose) => head(pose, frame));

  // One box for every mood, so the head sits still as the mood changes.
  let box = { x0: Infinity, y0: Infinity, x1: -Infinity, y1: -Infinity };
  const grow = (x0, y0, x1, y1) => {
    box = {
      x0: Math.min(box.x0, x0), y0: Math.min(box.y0, y0),
      x1: Math.max(box.x1, x1), y1: Math.max(box.y1, y1),
    };
  };
  for (const art of arts) {
    for (const shape of art.shapes) {
      const b = bounds(shape.d);
      const pad = shape.strokeWidth / 2;
      grow(b.x0 - pad, b.y0 - pad, b.x1 + pad, b.y1 + pad);
    }
    // A glyph's box, near enough. A 'z' has no ascender and no descender, so it
    // stands about six tenths of its font size above its own baseline — using
    // the full em here would reserve a strip of empty air above the z's and
    // shrink all five heads to pay for it.
    for (const mark of art.marks) grow(mark.x, mark.y - mark.size * 0.6, mark.x + mark.size * 0.6, mark.y);
  }
  const { viewBox } = frame;
  if (box.x0 < viewBox.x || box.y0 < viewBox.y ||
      box.x1 > viewBox.x + viewBox.width || box.y1 > viewBox.y + viewBox.height) {
    throw new Error(`a head no longer fits hop-face.svg's frame: ${JSON.stringify(box)} in ${JSON.stringify(viewBox)}`);
  }
  const content = {
    x: round(box.x0), y: round(box.y0),
    width: round(box.x1 - box.x0), height: round(box.y1 - box.y0),
  };

  const digest = sourceDigest();
  fs.writeFileSync(SWIFT, swiftSource(arts, frame, content, digest));

  fs.mkdirSync(PROOF, { recursive: true });
  for (const art of arts) {
    fs.writeFileSync(path.join(PROOF, `${art.pose}.svg`), proofSVG(art, { viewBox }));
    // Laid back over the pose, minus the exterior outline — see the second
    // check below for why that band cannot be part of this comparison.
    fs.writeFileSync(path.join(PROOF, `${art.pose}-in-place.svg`),
      proofSVG(art, {
        viewBox: viewBoxOf(art.pose),
        place: true,
        paint: (role) => (role === 'outline' ? null : ROLES[role].hex),
      }));
  }

  if (!quiet) {
    console.log(`widget-face: ${arts.map((a) => `${a.pose} ${a.shapes.length}`).join(', ')} shapes`);
    console.log(`  frame ${viewBox.width}×${viewBox.height}, content ${content.width}×${content.height} at (${content.x}, ${content.y})`);
    console.log(`  digest ${digest}`);
    console.log(`  → ${path.relative(ROOT, SWIFT)}`);
    console.log(`  → ${path.relative(ROOT, PROOF)}/{${MOODS.join(',')}}{,-in-place}.svg`);
  }
  return { arts, frame, content, digest };
}

// ---------------------------------------------------------------------------
// --check: the emitted art, measured against the artwork
// ---------------------------------------------------------------------------

/**
 * How much of the *interior* may disagree.
 *
 * Interior, not the whole frame, and that distinction is the check.
 * `hop-face.svg` draws an eye with `<circle>`; this file draws the same eye as
 * four cubic segments, because four opcodes is all the widget's decoder needs to
 * know. The two are the same circle to within a fortieth of a pixel — and
 * Chromium still antialiases them slightly differently, so ~0.3% of the frame
 * (a dotted line one pixel wide, along every contour) differs no matter how
 * exact the geometry is. Gating on that number would mean gating on the
 * rasteriser's mood.
 *
 * So a pixel counts only if it differs *and* both drawings are flat around it —
 * inside a fill, away from any edge in either one. Nothing that is merely
 * antialiased can land there, and nothing that is actually wrong can avoid it: a
 * shape that moved, changed colour, went missing or arrived unclipped repaints
 * an area, and an area is interior. A deliberate two-unit shift of one pupil —
 * six tenths of a percent of the head's width — fails this at four times the
 * limit; that is the calibration.
 */
const TOLERANCE = 0.0002;
/** Below this a pixel is antialiasing along an edge, not a different drawing. */
const CHANNEL = 24;
/** How still the artwork has to be around a pixel for it to count as interior. */
const FLAT = 8;

const dataURI = (file) =>
  `data:image/svg+xml;base64,${Buffer.from(fs.readFileSync(file, 'utf8')).toString('base64')}`;

/**
 * Two SVGs, drawn at the same size over the same ground, compared.
 *
 * `mask` picks which pixels count. `all` is every pixel in the frame, for two
 * drawings that should be the same drawing. `b` is only where the *second* one
 * put ink — which is what a head laid back over a whole frog needs, since
 * outside the head the pose is still wearing a body.
 */
async function difference(page, a, b, { ground, mask, viewport }) {
  // Twice the source's own box, so a disagreement narrower than an art unit
  // still lands on a pixel nothing else is touching. See TOLERANCE.
  await page.setViewportSize(viewport);
  await page.setContent(
    `<!doctype html><meta charset="utf-8"><style>html,body{margin:0;background:${ground}}` +
    `img{position:absolute;inset:0;width:100%;height:100%;object-fit:contain}</style>` +
    `<img id="a" src="${dataURI(a)}"><img id="b" src="${dataURI(b)}">`,
    { waitUntil: 'load' }
  );
  return page.evaluate(async ({ bg, channel, flat: flatLimit, mask }) => {
    const imgs = [document.getElementById('a'), document.getElementById('b')];
    await Promise.all(imgs.map((i) => i.decode()));
    const W = innerWidth, H = innerHeight;
    const layer = (img, opaque) => {
      const cv = document.createElement('canvas');
      cv.width = W; cv.height = H;
      const cx = cv.getContext('2d');
      if (opaque) { cx.fillStyle = bg; cx.fillRect(0, 0, W, H); }
      const k = Math.min(W / img.naturalWidth, H / img.naturalHeight);
      const w = img.naturalWidth * k, h = img.naturalHeight * k;
      cx.drawImage(img, (W - w) / 2, (H - h) / 2, w, h);
      return cx.getImageData(0, 0, W, H).data;
    };
    const over = [layer(imgs[0], true), layer(imgs[1], true)];
    const alpha = mask === 'b' ? layer(imgs[1], false) : null;
    const [A, B] = over;
    /** How far apart two pixels are, on their furthest channel. */
    const gap = (p, i, q, j) => Math.max(
      Math.abs(p[i] - q[j]), Math.abs(p[i + 1] - q[j + 1]), Math.abs(p[i + 2] - q[j + 2])
    );
    let worst = 0, differing = 0, inside = 0, counted = 0, sum = 0;
    for (let i = 0; i < A.length; i += 4) {
      if (alpha && alpha[i + 3] < 200) continue;
      const x = (i / 4) % W, y = Math.floor(i / 4 / W);
      if (x === 0 || y === 0 || x === W - 1 || y === H - 1) continue;
      const d = gap(A, i, B, i);
      counted++; sum += d; worst = Math.max(worst, d);
      if (d <= channel) continue;
      differing++;
      // Interior: *both* drawings are flat here, so no amount of edge
      // antialiasing could have put this difference on this pixel. Both,
      // because a head laid back over its own pose has its silhouette running
      // across the body's flat green — an edge in one image and not the other
      // is still an edge.
      const onEdge = [A, B].some((px) => Math.max(
        gap(px, i, px, i - 4), gap(px, i, px, i + 4),
        gap(px, i, px, i - W * 4), gap(px, i, px, i + W * 4)
      ) >= flatLimit);
      if (!onEdge) inside++;
    }
    return {
      pctOver: counted ? differing / counted : 1,
      pctInside: counted ? inside / counted : 1,
      mean: counted ? sum / counted : 0,
      worst, counted,
    };
  }, { bg: ground, channel: CHANNEL, flat: FLAT, mask });
}

async function check() {
  const { chromium } = require('playwright');
  const { frame } = build({ quiet: true });
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  const twice = (box) => ({ width: Math.round(box.width * 2), height: Math.round(box.height * 2) });
  let bad = 0;

  const report = (label, stat) => {
    const ok = stat.pctInside <= TOLERANCE;
    if (!ok) bad++;
    console.log(
      `${ok ? '✓' : '✗'} ${label.padEnd(24)} ` +
      `interior ${(stat.pctInside * 100).toFixed(4)}% (limit ${(TOLERANCE * 100).toFixed(3)}%)` +
      `   ·   edges ${(stat.pctOver * 100).toFixed(3)}%, mean ${stat.mean.toFixed(2)}, ` +
      `of ${stat.counted} px compared`
    );
  };

  // 1. The frame. `idle`'s head, lifted out of the whole frog, against the
  //    head-only pose the generator draws independently. Same frame, every
  //    pixel: this is the one comparison with no excuses in it.
  console.log(`\nthe extraction, against hop-${REFERENCE}.svg (every pixel)`);
  for (const ground of ['#FFF9F2', '#14192A']) {
    report(`idle vs ${REFERENCE} on ${ground}`,
      await difference(page, path.join(ART, `hop-${REFERENCE}.svg`), path.join(PROOF, 'idle.svg'),
        { ground, mask: 'all', viewport: twice(frame.viewBox) }));
  }

  // 2. Every mood, laid back over the pose it came from, wherever it put ink.
  //    Outside the head the pose is still wearing a body, so the mask is the
  //    proof's own coverage — which is exactly the claim being made: every pixel
  //    the widget draws is the pixel the artwork draws there.
  //
  //    Minus the exterior outline, and that exclusion is structural rather than
  //    a tolerance. Hop's outline is drawn *under* the whole figure so the parts
  //    union without seams, so in a pose the band around the jaw is covered by
  //    the torso — while the widget draws a head with no body under it, where
  //    the same band is the edge of the drawing. A free-standing head has an
  //    outline where an attached one has a neck. That band is not unproven: it
  //    is check 1, against a head-only pose, every pixel, on both grounds.
  console.log('\neach mood, laid back over its own pose (where the head draws, outline aside)');
  for (const pose of MOODS) {
    report(`${pose} in place`,
      await difference(page, path.join(ART, `hop-${pose}.svg`), path.join(PROOF, `${pose}-in-place.svg`),
        { ground: '#FFF9F2', mask: 'b', viewport: twice(viewBoxOf(pose)) }));
  }

  await browser.close();
  if (bad) {
    console.log('\nThe emitted head no longer matches the artwork. Re-run Scripts/widget-face.js;');
    console.log("if it still fails, the extraction rule (the head's share of the outline,");
    console.log('then the whole of #head) has stopped describing what hop-art.js draws.');
  }
  console.log(`\n${bad ? `${bad} check(s) failed` : 'All widget-face checks passed'}`);
  process.exitCode = bad ? 1 : 0;
}

// ---------------------------------------------------------------------------
// --sheet: what the five families get, at the sizes they get it
// ---------------------------------------------------------------------------

/**
 * Every place `HopWidgetFace` is used, and how wide Hop's head is there.
 *
 * Keep this in step with the call sites in `NextPauseWidget.swift` and
 * `PottyPauseActivity.swift` — the sheet is worth having only while the sizes on
 * it are the sizes that ship.
 */
const USES = [
  { label: 'systemMedium', size: 72, mono: false },
  { label: 'Live Activity (lock screen)', size: 54, mono: false },
  { label: 'systemSmall', size: 48, mono: false },
  { label: 'Dynamic Island (expanded)', size: 46, mono: false },
  { label: 'accessoryRectangular', size: 30, mono: true },
  { label: 'accessoryCircular', size: 26, mono: true },
  { label: 'Dynamic Island (compact)', size: 22, mono: true },
  { label: 'Dynamic Island (minimal)', size: 20, mono: true },
];

/** sRGB relative luminance, for the naive-vibrancy comparison. */
function luminance(hex) {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

async function sheet() {
  const { chromium } = require('playwright');
  const { arts, frame, content } = build({ quiet: true });
  const alphas = stencil();

  const svgFor = (art, kind) => {
    const paint = {
      colour: (role) => ROLES[role].hex,
      // What the lock screen does to a coloured drawing if you let it: hue is
      // discarded and what survives is roughly luminance. Not what ships —
      // this is the panel that says why the stencil exists.
      naive: (role) => `rgba(255,255,255,${luminance(ROLES[role].hex).toFixed(3)})`,
      // What ships: one colour, and a tone per part chosen for this size.
      stencil: (role) => (alphas[role] === null ? null : `rgba(255,255,255,${alphas[role]})`),
    }[kind];
    return proofSVG(art, { viewBox: frame.viewBox, paint });
  };

  const cell = (art, use, kind) => {
    const svg = Buffer.from(svgFor(art, kind)).toString('base64');
    // The view fits `content` to the frame, so the img is scaled and shifted
    // to show the same crop the widget shows.
    const k = use.size / content.width;
    const w = frame.viewBox.width * k, h = frame.viewBox.height * k;
    return `<div class="cell" style="width:${use.size}px;height:${round(content.height * k)}px">` +
      `<img src="data:image/svg+xml;base64,${svg}" style="width:${w}px;height:${h}px;` +
      `margin-left:${-content.x * k}px;margin-top:${-content.y * k}px">` +
      `</div>`;
  };

  const grounds = {
    colour: 'linear-gradient(135deg,#E3F5EA,#FFF9F2)',
    naive: 'linear-gradient(160deg,#2b3a55,#7a6a8a 55%,#c9a06a)',
    stencil: 'linear-gradient(160deg,#2b3a55,#7a6a8a 55%,#c9a06a)',
  };

  const rows = (kind, uses) => uses.map((use) => `
    <tr><th>${use.label} · ${use.size}pt</th>
    ${arts.map((art) => `<td style="background:${grounds[kind]}">${cell(art, use, kind)}</td>`).join('')}
    </tr>`).join('');

  const html = `<!doctype html><meta charset="utf-8"><style>
    body{margin:0;padding:24px;background:#101418;color:#e9e4dc;
         font:13px/1.4 ui-rounded,system-ui,sans-serif}
    h2{font-size:15px;margin:26px 0 8px;font-weight:600}
    p{margin:0 0 10px;color:#9aa3ad;max-width:70ch}
    table{border-collapse:separate;border-spacing:8px}
    th{font-weight:500;text-align:right;color:#9aa3ad;white-space:nowrap;padding-right:6px}
    td{padding:10px;border-radius:10px;text-align:center;vertical-align:middle}
    thead td{background:none;color:#e9e4dc;font-weight:600}
    .cell{overflow:hidden;display:inline-block}
    .cell img{display:block;image-rendering:auto}
  </style>
  <h2>Colour — home screen, Live Activity, Dynamic Island expanded</h2>
  <p>The artwork's own head, fitted to the head's own box.</p>
  <table><thead><tr><td></td>${arts.map((a) => `<td>${a.pose}</td>`).join('')}</tr></thead>
  ${rows('colour', USES.filter((u) => !u.mono))}</table>

  <h2>Accessory, if the colour art were simply handed over</h2>
  <p>Vibrancy keeps roughly the luminance and throws the hue away. The pupils go
  first, then the mouth, and Hop becomes a pale disc with a bite out of it.</p>
  <table>${rows('naive', USES.filter((u) => u.mono))}</table>

  <h2>Accessory, as it ships — the stencil</h2>
  <p>Same geometry, one colour, a tone per part: the head steps back, the eyes
  and the mouth come forward, and everything under a point across is dropped.</p>
  <table>${rows('stencil', USES.filter((u) => u.mono))}</table>`;

  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 900, height: 900 }, deviceScaleFactor: 3 });
  await page.setContent(html, { waitUntil: 'load' });
  await page.waitForTimeout(300);
  fs.mkdirSync(PROOF, { recursive: true });
  const out = path.join(PROOF, 'families.png');
  await page.screenshot({ path: out, fullPage: true });
  await browser.close();
  console.log('rendered ->', path.relative(ROOT, out));
}

// ---------------------------------------------------------------------------

module.exports = { build, check, sheet, proofSVG, stencil, MOODS, ROLES, ROLE_ORDER, sourceDigest };

if (require.main === module) {
  const args = process.argv.slice(2);
  const run = args.includes('--check') ? check
    : args.includes('--sheet') ? sheet
      : async () => { build(); };
  run().catch((e) => { console.error(e); process.exit(1); });
}
