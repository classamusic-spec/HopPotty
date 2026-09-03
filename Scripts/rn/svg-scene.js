/**
 * Shared SVG → scene-graph conversion for the React Native generators.
 *
 * Both generators — the mascot rig and the illustration catalogue — turn SVG
 * into a typed tree at build time so React Native does no parsing at runtime
 * and the drawing it renders is provably the drawing on disk. They had two
 * copies of this logic; one copy means a fix to the parser fixes both, and the
 * fidelity check cannot pass for one and silently not exist for the other.
 */

/** react-native-svg takes camelCase props; SVG files use attribute names. */
const PROP = {
  'stroke-width': 'strokeWidth',
  'stroke-linecap': 'strokeLinecap',
  'stroke-linejoin': 'strokeLinejoin',
  'stroke-opacity': 'strokeOpacity',
  'stroke-dasharray': 'strokeDasharray',
  'stroke-miterlimit': 'strokeMiterlimit',
  'fill-opacity': 'fillOpacity',
  'fill-rule': 'fillRule',
  'clip-path': 'clipPath',
  'clip-rule': 'clipRule',
  'stop-color': 'stopColor',
  'stop-opacity': 'stopOpacity',
  'font-family': 'fontFamily',
  'font-size': 'fontSize',
  'font-weight': 'fontWeight',
  'text-anchor': 'textAnchor',
  'letter-spacing': 'letterSpacing',
  'gradientUnits': 'gradientUnits',
  'gradientTransform': 'gradientTransform',
  'clipPathUnits': 'clipPathUnits',
};

/**
 * A deliberately small parser for well-formed, generated or hand-authored SVG.
 *
 * Not a general SVG parser: the inputs are this repository's own art files, so
 * there is no CDATA, no comments in the body, no unquoted attributes and no
 * namespaces beyond the root. A tokeniser over the tag grammar is both
 * sufficient and much harder to get subtly wrong than walking indices — and it
 * throws on anything it does not recognise rather than dropping it, because a
 * silently dropped element is a missing limb or a missing sky.
 */
function parse(svg) {
  const TAG = /<(\/?)([A-Za-z][\w:-]*)((?:\s+[\w:-]+="[^"]*")*)\s*(\/?)>/g;
  const root = { t: '#root', p: {}, c: [] };
  const stack = [root];
  let m;
  let consumed = 0;

  // Strip XML declarations and comments, which carry nothing we render.
  const body = svg.replace(/<\?[^>]*\?>/g, '').replace(/<!--[\s\S]*?-->/g, '');

  while ((m = TAG.exec(body)) !== null) {
    const [full, closing, name, attrs, selfClose] = m;
    const between = body.slice(consumed, m.index);
    if (between.trim()) {
      const open = stack[stack.length - 1];
      if (open === root) throw new Error(`text outside the root: ${JSON.stringify(between.trim())}`);
      open.x = (open.x ?? '') + between.trim();
    }
    consumed = m.index + full.length;

    if (closing) {
      const open = stack.pop();
      if (!open || open.t !== name) {
        throw new Error(`mismatched </${name}> (open was ${open ? open.t : 'nothing'})`);
      }
      continue;
    }
    const props = {};
    for (const a of attrs.matchAll(/([\w:-]+)="([^"]*)"/g)) {
      props[PROP[a[1]] ?? a[1]] = a[2];
    }
    const node = { t: name, p: props };
    (stack[stack.length - 1].c ??= []).push(node);
    if (!selfClose) {
      node.c = [];
      stack.push(node);
    }
  }

  if (stack.length !== 1) throw new Error(`${stack.length - 1} unclosed element(s)`);
  const tail = body.slice(consumed);
  if (tail.trim()) throw new Error(`trailing text ${JSON.stringify(tail.trim().slice(0, 40))}`);
  if (root.c.length !== 1) throw new Error(`expected one root element, got ${root.c.length}`);

  const prune = (n) => {
    if (n.c) {
      if (!n.c.length) delete n.c;
      else n.c.forEach(prune);
    }
    return n;
  };
  return prune(root.c[0]);
}

/** Numeric-looking attribute values become numbers, so RN skips a parse. */
function tighten(node, { drop = ['xmlns'] } = {}) {
  const p = {};
  for (const [k, v] of Object.entries(node.p)) {
    if (drop.includes(k)) continue;
    p[k] = /^-?\d+(\.\d+)?$/.test(v) ? Number(v) : v;
  }
  const out = { t: node.t, p };
  if (node.x !== undefined) out.x = node.x;
  if (node.c) out.c = node.c.map((c) => tighten(c, { drop }));
  return out;
}

/**
 * Proves a tree is the file's drawing, not a lookalike.
 *
 * The tree builder is the part that could plausibly be wrong — dropping a node,
 * reordering siblings, losing an attribute — so the check does not reuse it. It
 * re-scans the source with a flat regex and compares that sequence element for
 * element and attribute for attribute. A mismatch fails the build rather than
 * shipping subtly wrong art.
 */
function verifyFaithful(label, svg, tree, { skipRoot = null, rewrite = null, syntheticRoot = false } = {}) {
  const flatten = (node, out = []) => {
    const keys = Object.keys(node.p).sort();
    out.push(`${node.t}|${keys.map((k) => `${k}=${node.p[k]}`).join(',')}`);
    (node.c ?? []).forEach((c) => flatten(c, out));
    return out;
  };
  // A generator may wrap the file's children in a group of its own; that node
  // has no counterpart in the source and must not be compared against one.
  const fromTree = syntheticRoot ? flatten(tree).slice(1) : flatten(tree);

  const body = svg.replace(/<\?[^>]*\?>/g, '').replace(/<!--[\s\S]*?-->/g, '');
  const fromScan = [];
  for (const m of body.matchAll(/<(?!\/)([A-Za-z][\w:-]*)((?:\s+[\w:-]+="[^"]*")*)\s*\/?>/g)) {
    if (skipRoot && m[1] === skipRoot) continue;
    const props = {};
    for (const a of m[2].matchAll(/([\w:-]+)="([^"]*)"/g)) {
      if (a[1] === 'xmlns') continue;
      const name = PROP[a[1]] ?? a[1];
      let v = rewrite ? rewrite(name, a[2]) : a[2];
      props[name] = /^-?\d+(\.\d+)?$/.test(v) ? Number(v) : v;
    }
    const keys = Object.keys(props).sort();
    fromScan.push(`${m[1]}|${keys.map((k) => `${k}=${props[k]}`).join(',')}`);
  }

  if (fromTree.length !== fromScan.length) {
    throw new Error(`${label}: tree has ${fromTree.length} elements, the file has ${fromScan.length}`);
  }
  for (let i = 0; i < fromTree.length; i += 1) {
    if (fromTree[i] !== fromScan[i]) {
      throw new Error(`${label}: element ${i} differs\n  tree: ${fromTree[i]}\n  file: ${fromScan[i]}`);
    }
  }
  return fromTree.length;
}

module.exports = { PROP, parse, tighten, verifyFaithful };
