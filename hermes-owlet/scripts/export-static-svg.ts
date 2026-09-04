/**
 * Emits the standalone Hermes Owlet asset from the same locked geometry the
 * React renderer uses, so the file in Art/ can never drift from the component.
 *
 *   npm run export:svg
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  ANCHORS,
  HEADPHONE,
  HERMES_COLORS as C,
  LID_TRAVEL,
  PATHS,
  STROKE,
  VIEW_BOX,
} from '../src/character/svg/geometry.ts';

const here = dirname(fileURLToPath(import.meta.url));
const targets = [
  resolve(here, '../../Art/hermes-owlet/hermes-owlet.svg'),
  resolve(here, '../public/hermes-owlet.svg'),
];

const e = ANCHORS.eye;
const halo = ANCHORS.halo;

const wing = (): string =>
  [
    ...PATHS.wingFeathers.map((d) => `        <path fill="${C.cream}" d="${d}"/>`),
    ...PATHS.wingAccents.map(
      (d) => `        <path fill="${C.gold}" stroke-width="${STROKE.fine}" d="${d}"/>`,
    ),
  ].join('\n');

const eye = (side: 'left' | 'right'): string => {
  const a = side === 'left' ? ANCHORS.leftEye : ANCHORS.rightEye;
  const sclera = side === 'left' ? PATHS.scleraLeft : PATHS.scleraRight;
  return `      <g id="${side}-eye" data-ho="${side}-eye" transform="translate(${a.x} ${a.y})">
        <g clip-path="url(#clip-eye-${side})">
          <path fill="${C.white}" stroke="none" d="${sclera}"/>
          <g id="${side}-pupil" data-ho="${side}-pupil" transform="translate(0 0)">
            <g clip-path="url(#clip-iris)">
              <circle fill="${C.cyan}" stroke="none" cx="0" cy="0" r="${e.irisRadius}"/>
              <circle id="${side}-pupil-core" data-ho="${side}-pupil-core" fill="${C.navyDeep}" stroke="none" cx="${e.coreOffset.x}" cy="${e.coreOffset.y}" r="${e.irisRadius}"/>
            </g>
            <circle id="${side}-highlight" fill="${C.white}" stroke="none" cx="${e.highlightOffset.x}" cy="${e.highlightOffset.y}" r="${e.highlightRadius}"/>
          </g>
          <g id="${side}-lid" data-ho="${side}-lid" transform="translate(0 ${LID_TRAVEL.upperParked})">
            <path fill="${C.cream}" stroke="${C.navy}" stroke-width="${STROKE.detail}" d="${PATHS.upperLid}"/>
          </g>
          <g id="${side}-lower-lid" data-ho="${side}-lower-lid" transform="translate(0 ${LID_TRAVEL.lowerParked})">
            <path fill="${C.cream}" stroke="${C.navy}" stroke-width="${STROKE.detail}" d="${PATHS.lowerLid}"/>
          </g>
        </g>
        <path fill="none" stroke="${C.navy}" stroke-width="${STROKE.silhouette}" d="${sclera}"/>
      </g>`;
};

const headphone = (side: 'left' | 'right'): string => {
  const a = side === 'left' ? ANCHORS.leftHeadphone : ANCHORS.rightHeadphone;
  return `      <g id="${side}-headphone" data-ho="${side}-headphone" transform="translate(${a.x} ${a.y})">
        <circle id="${side}-headphone-glow" data-ho="${side}-headphone-glow" r="${HEADPHONE.glowRadius}" fill="none" stroke="${C.cyanBright}" stroke-width="10" opacity="0"/>
        <circle r="${HEADPHONE.outerRadius}" fill="${C.gold}"/>
        <circle r="${HEADPHONE.cyanRadius}" fill="${C.cyanDim}" stroke-width="${STROKE.fine}"/>
        <circle id="${side}-headphone-lit" data-ho="${side}-headphone-lit" r="${HEADPHONE.cyanRadius}" fill="${C.cyan}" stroke-width="${STROKE.fine}" opacity="1"/>
        <circle r="${HEADPHONE.innerRadius}" fill="${C.navyDeep}" stroke="none"/>
      </g>`;
};

const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${VIEW_BOX.width} ${VIEW_BOX.height}" width="${VIEW_BOX.width}" height="${VIEW_BOX.height}" role="img" aria-label="Hermes Owlet">
  <title>Hermes Owlet</title>
  <defs>
    <clipPath id="clip-eye-left"><path d="${PATHS.scleraLeft}"/></clipPath>
    <clipPath id="clip-eye-right"><path d="${PATHS.scleraRight}"/></clipPath>
    <clipPath id="clip-iris"><circle cx="0" cy="0" r="${e.irisRadius}"/></clipPath>
  </defs>
  <g id="owlet-root" data-ho="owlet-root" stroke="${C.navy}" stroke-width="${STROKE.silhouette}" stroke-linejoin="round" stroke-linecap="round" fill="none">

    <g id="halo-group" data-ho="halo-group" transform="translate(0 0)">
      <ellipse id="halo-bloom" data-ho="halo-bloom" cx="${halo.cx}" cy="${halo.cy}" rx="${halo.rx}" ry="${halo.ry}" stroke="${C.goldBright}" stroke-width="${STROKE.halo + 12}" opacity="0" style="mix-blend-mode:screen"/>
      <ellipse id="halo" data-ho="halo" cx="${halo.cx}" cy="${halo.cy}" rx="${halo.rx}" ry="${halo.ry}" stroke="${C.gold}" stroke-width="${STROKE.halo}"/>
      <path id="halo-spark" data-ho="halo-spark" fill="${C.gold}" stroke="none" transform="translate(${halo.cx} ${halo.cy})" d="${PATHS.haloSpark}"/>
    </g>

    <g id="head-root" data-ho="head-root" transform="translate(0 0)">
      <path id="crown-tuft" data-ho="crown-tuft" fill="${C.navy}" transform="rotate(0)" d="${PATHS.crownTuft}"/>

      <g id="ear-wings-back">
        <g id="left-wing" data-ho="left-wing" transform="rotate(0)">
${wing()}
        </g>
        <g id="right-wing" data-ho="right-wing" transform="rotate(0)">
          <g transform="translate(${VIEW_BOX.width} 0) scale(-1 1)">
${wing()}
          </g>
        </g>
      </g>

      <path id="head-base" data-ho="head-base" fill="${C.navy}" d="${PATHS.headBase}"/>
      <path id="face-mask" data-ho="face-mask" fill="${C.cream}" d="${PATHS.faceMask}"/>

      <g id="effects" data-ho="effects">
        <path id="error-pulse" data-ho="error-pulse" fill="none" stroke="${C.concern}" stroke-width="7" opacity="0" d="${PATHS.headBase}"/>
        <g id="listening-glow" data-ho="listening-glow" fill="none" stroke="${C.cyanBright}" stroke-width="7" opacity="0">
          <circle cx="${ANCHORS.leftHeadphone.x}" cy="${ANCHORS.leftHeadphone.y}" r="44"/>
          <circle cx="${ANCHORS.rightHeadphone.x}" cy="${ANCHORS.rightHeadphone.y}" r="44"/>
        </g>
        <g id="speaking-pulse" data-ho="speaking-pulse" fill="none" stroke="${C.cyan}" stroke-width="5" opacity="0">
          <circle cx="${ANCHORS.leftHeadphone.x}" cy="${ANCHORS.leftHeadphone.y}" r="40"/>
          <circle cx="${ANCHORS.rightHeadphone.x}" cy="${ANCHORS.rightHeadphone.y}" r="40"/>
        </g>
        <path id="thinking-spark" data-ho="thinking-spark" fill="${C.goldBright}" stroke="none" opacity="0" transform="translate(${halo.cx} ${halo.cy}) scale(0.62)" d="${PATHS.haloSpark}"/>
      </g>

      <g id="forehead-star-group" data-ho="forehead-star-group" transform="translate(0 0)">
        <path id="forehead-star-bloom" data-ho="forehead-star-bloom" fill="${C.goldBright}" stroke="${C.goldBright}" stroke-width="11" opacity="0" style="mix-blend-mode:screen" d="${PATHS.foreheadStar}"/>
        <path id="forehead-star" data-ho="forehead-star" fill="${C.gold}" stroke="none" d="${PATHS.foreheadStar}"/>
      </g>

      <g id="eyes">
${eye('left')}
${eye('right')}
      </g>

      <g id="brows">
        <g id="left-brow" data-ho="left-brow" transform="translate(${ANCHORS.leftEye.x} ${ANCHORS.leftEye.y - 60})" opacity="0">
          <path fill="none" stroke="${C.navy}" stroke-width="${STROKE.brow}" d="${PATHS.brow}"/>
        </g>
        <g id="right-brow" data-ho="right-brow" transform="translate(${ANCHORS.rightEye.x} ${ANCHORS.rightEye.y - 60})" opacity="0">
          <path fill="none" stroke="${C.navy}" stroke-width="${STROKE.brow}" d="${PATHS.brow}"/>
        </g>
      </g>

      <g id="beak" data-ho="beak">
        <rect id="beak-gap" data-ho="beak-gap" x="241" y="374" width="30" height="2" rx="3" fill="${C.navyDeep}" stroke="none"/>
        <g id="upper-beak" data-ho="upper-beak">
          <path fill="${C.gold}" stroke="none" d="${PATHS.upperBeakFill}"/>
          <path fill="none" stroke-width="${STROKE.detail}" d="${PATHS.upperBeakEdge}"/>
        </g>
        <g id="lower-beak" data-ho="lower-beak" transform="translate(0 0)">
          <path fill="${C.gold}" stroke="none" d="${PATHS.lowerBeakFill}"/>
          <path fill="none" stroke-width="${STROKE.detail}" d="${PATHS.lowerBeakEdge}"/>
        </g>
      </g>

      <g id="headphones">
${headphone('left')}
${headphone('right')}
      </g>
    </g>
  </g>
</svg>
`;

for (const out of targets) {
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, svg, 'utf8');
  console.log(`wrote ${out} (${svg.length} bytes)`);
}
