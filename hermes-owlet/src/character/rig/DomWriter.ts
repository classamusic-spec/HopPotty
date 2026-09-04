import { round } from '../animation/easing';
import type { RigNodeKey, RigNodes } from './RigNodes';

type Cache = Map<string, string | number>;

/**
 * Writes SVG attributes only when they actually change. At 60 Hz the rig
 * touches around forty properties a frame; skipping the unchanged ones keeps
 * the character effectively free when it is sitting still, which matters for a
 * companion that is on screen all day.
 */
export class DomWriter {
  private readonly cache: Cache = new Map();

  constructor(private nodes: RigNodes) {}

  setNodes(nodes: RigNodes): void {
    this.nodes = nodes;
    this.cache.clear();
  }

  private el(key: RigNodeKey): SVGElement | undefined {
    return this.nodes[key];
  }

  transform(key: RigNodeKey, value: string): void {
    const cacheKey = key + '|t';
    if (this.cache.get(cacheKey) === value) return;
    const el = this.el(key);
    if (!el) return;
    this.cache.set(cacheKey, value);
    el.setAttribute('transform', value);
  }

  opacity(key: RigNodeKey, value: number): void {
    const v = round(value, 3);
    const cacheKey = key + '|o';
    if (this.cache.get(cacheKey) === v) return;
    const el = this.el(key);
    if (!el) return;
    this.cache.set(cacheKey, v);
    el.setAttribute('opacity', String(v));
  }

  attr(key: RigNodeKey, name: string, value: string | number): void {
    const cacheKey = key + '|' + name;
    if (this.cache.get(cacheKey) === value) return;
    const el = this.el(key);
    if (!el) return;
    this.cache.set(cacheKey, value);
    el.setAttribute(name, String(value));
  }

  /** CSS custom property on the SVG root, for anything driven by stylesheet. */
  cssVar(name: string, value: string): void {
    const cacheKey = 'var|' + name;
    if (this.cache.get(cacheKey) === value) return;
    const el = this.el('owlet-root');
    if (!el) return;
    this.cache.set(cacheKey, value);
    el.style.setProperty(name, value);
  }
}

/** `translate(x, y)` with two decimals, allocation-light. */
export const translate = (x: number, y: number): string =>
  `translate(${round(x)} ${round(y)})`;

export const rotateAbout = (deg: number, cx: number, cy: number): string =>
  `rotate(${round(deg, 3)} ${round(cx)} ${round(cy)})`;

export const scaleAbout = (sx: number, sy: number, cx: number, cy: number): string =>
  `translate(${round(cx)} ${round(cy)}) scale(${round(sx, 4)} ${round(sy, 4)}) translate(${round(-cx)} ${round(-cy)})`;
