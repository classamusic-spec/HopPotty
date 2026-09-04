import { forwardRef, useId } from 'react';
import {
  ANCHORS,
  HEADPHONE,
  HERMES_COLORS as C,
  LID_TRAVEL,
  PATHS,
  STROKE,
  VIEW_BOX,
} from './geometry';

export interface HermesOwletSVGProps {
  /** Rendered size. Any CSS length; defaults to filling the parent. */
  size?: number | string;
  className?: string;
  /** Accessible name. Set to null for a purely decorative instance. */
  title?: string | null;
}

const eyeLocal = (side: 'left' | 'right') => ({
  sclera: side === 'left' ? PATHS.scleraLeft : PATHS.scleraRight,
});

/**
 * The locked Hermes Owlet head, as layered vector art.
 *
 * Nothing here animates on its own: every feature that moves is its own group
 * with a stable `data-ho` name and a neutral transform, which the rig then
 * drives. Flat fills, one heavy navy outline, no filters, no gradients — so it
 * stays crisp from 64 px to 512 px and costs nothing to composite.
 */
export const HermesOwletSVG = forwardRef<SVGSVGElement, HermesOwletSVGProps>(
  function HermesOwletSVG({ size, className, title = 'Hermes Owlet' }, ref) {
    // Clip ids must be unique per instance; the human-readable names live on
    // `data-ho` and `id`, which the rig and design tooling read.
    const uid = useId().replace(/[^a-zA-Z0-9]/g, '');
    const clipEyeL = `${uid}-eye-l`;
    const clipEyeR = `${uid}-eye-r`;
    const clipIris = `${uid}-iris`;

    const e = ANCHORS.eye;
    const halo = ANCHORS.halo;

    return (
      <svg
        ref={ref}
        className={className}
        viewBox={`0 0 ${VIEW_BOX.width} ${VIEW_BOX.height}`}
        width={size ?? '100%'}
        height={size ?? '100%'}
        role={title ? 'img' : 'presentation'}
        aria-label={title ?? undefined}
        aria-hidden={title ? undefined : true}
        shapeRendering="geometricPrecision"
        style={{ overflow: 'visible', display: 'block' }}
      >
        {title ? <title>{title}</title> : null}
        <defs>
          <clipPath id={clipEyeL}>
            <path d={eyeLocal('left').sclera} />
          </clipPath>
          <clipPath id={clipEyeR}>
            <path d={eyeLocal('right').sclera} />
          </clipPath>
          <clipPath id={clipIris}>
            <circle cx={0} cy={0} r={e.irisRadius} />
          </clipPath>
        </defs>

        <g
          id="owlet-root"
          data-ho="owlet-root"
          stroke={C.navy}
          strokeWidth={STROKE.silhouette}
          strokeLinejoin="round"
          strokeLinecap="round"
          fill="none"
        >
          {/* ---------------------------------------------------------- halo */}
          <g id="halo-group" data-ho="halo-group" transform="translate(0 0)">
            {/* Bloom only appears at the very top of the glow range, so the
                halo never carries a permanent translucent haze. */}
            <ellipse
              id="halo-bloom"
              data-ho="halo-bloom"
              cx={halo.cx}
              cy={halo.cy}
              rx={halo.rx}
              ry={halo.ry}
              stroke={C.goldBright}
              strokeWidth={STROKE.halo + 12}
              opacity={0}
              style={{ mixBlendMode: 'screen' }}
            />
            <ellipse
              id="halo"
              data-ho="halo"
              cx={halo.cx}
              cy={halo.cy}
              rx={halo.rx}
              ry={halo.ry}
              stroke={C.gold}
              strokeWidth={STROKE.halo}
            />
            <path
              id="halo-spark"
              data-ho="halo-spark"
              d={PATHS.haloSpark}
              fill={C.gold}
              stroke="none"
              transform={`translate(${halo.cx} ${halo.cy})`}
            />
          </g>

          {/* ---------------------------------------------------------- head */}
          <g id="head-root" data-ho="head-root" transform="translate(0 0)">
            <path
              id="crown-tuft"
              data-ho="crown-tuft"
              d={PATHS.crownTuft}
              fill={C.navy}
              transform="rotate(0)"
            />

            <g id="ear-wings-back" data-ho="effects-anchor-wings">
              <g id="left-wing" data-ho="left-wing" transform="rotate(0)">
                {PATHS.wingFeathers.map((d, i) => (
                  <path key={`lf${i}`} d={d} fill={C.cream} />
                ))}
                {PATHS.wingAccents.map((d, i) => (
                  <path key={`la${i}`} d={d} fill={C.gold} strokeWidth={STROKE.fine} />
                ))}
              </g>
              <g id="right-wing" data-ho="right-wing" transform="rotate(0)">
                <g transform={`translate(${VIEW_BOX.width} 0) scale(-1 1)`}>
                  {PATHS.wingFeathers.map((d, i) => (
                    <path key={`rf${i}`} d={d} fill={C.cream} />
                  ))}
                  {PATHS.wingAccents.map((d, i) => (
                    <path key={`ra${i}`} d={d} fill={C.gold} strokeWidth={STROKE.fine} />
                  ))}
                </g>
              </g>
            </g>

            <path id="head-base" data-ho="head-base" d={PATHS.headBase} fill={C.navy} />
            <path id="face-mask" data-ho="face-mask" d={PATHS.faceMask} fill={C.cream} />

            {/* ------------------------------------------------------ effects */}
            <g id="effects" data-ho="effects">
              <path
                id="error-pulse"
                data-ho="error-pulse"
                d={PATHS.headBase}
                fill="none"
                stroke={C.concern}
                strokeWidth={7}
                opacity={0}
              />
              <g
                id="listening-glow"
                data-ho="listening-glow"
                fill="none"
                stroke={C.cyanBright}
                strokeWidth={7}
                opacity={0}
              >
                <circle cx={ANCHORS.leftHeadphone.x} cy={ANCHORS.leftHeadphone.y} r={44} />
                <circle cx={ANCHORS.rightHeadphone.x} cy={ANCHORS.rightHeadphone.y} r={44} />
              </g>
              <g
                id="speaking-pulse"
                data-ho="speaking-pulse"
                fill="none"
                stroke={C.cyan}
                strokeWidth={5}
                opacity={0}
              >
                <circle cx={ANCHORS.leftHeadphone.x} cy={ANCHORS.leftHeadphone.y} r={40} />
                <circle cx={ANCHORS.rightHeadphone.x} cy={ANCHORS.rightHeadphone.y} r={40} />
              </g>
              <path
                id="thinking-spark"
                data-ho="thinking-spark"
                d={PATHS.haloSpark}
                fill={C.goldBright}
                stroke="none"
                opacity={0}
                transform={`translate(${halo.cx} ${halo.cy}) scale(0.6)`}
              />
            </g>

            {/* -------------------------------------------------forehead star */}
            <g id="forehead-star-group" data-ho="forehead-star-group" transform="translate(0 0)">
              <path
                id="forehead-star-bloom"
                data-ho="forehead-star-bloom"
                d={PATHS.foreheadStar}
                fill={C.goldBright}
                stroke={C.goldBright}
                strokeWidth={11}
                opacity={0}
                style={{ mixBlendMode: 'screen' }}
              />
              <path
                id="forehead-star"
                data-ho="forehead-star"
                d={PATHS.foreheadStar}
                fill={C.gold}
                stroke="none"
              />
            </g>

            {/* ---------------------------------------------------------- eyes */}
            <g id="eyes">
              {(['left', 'right'] as const).map((side) => {
                const anchor = side === 'left' ? ANCHORS.leftEye : ANCHORS.rightEye;
                const clip = side === 'left' ? clipEyeL : clipEyeR;
                const sclera = eyeLocal(side).sclera;
                return (
                  <g
                    key={side}
                    id={`${side}-eye`}
                    data-ho={`${side}-eye`}
                    transform={`translate(${anchor.x} ${anchor.y})`}
                  >
                    <g clipPath={`url(#${clip})`}>
                      <path d={sclera} fill={C.white} stroke="none" />
                      <g id={`${side}-pupil`} data-ho={`${side}-pupil`} transform="translate(0 0)">
                        <g clipPath={`url(#${clipIris})`}>
                          <circle cx={0} cy={0} r={e.irisRadius} fill={C.cyan} stroke="none" />
                          <circle
                            id={`${side}-pupil-core`}
                            data-ho={`${side}-pupil-core`}
                            cx={e.coreOffset.x}
                            cy={e.coreOffset.y}
                            r={e.irisRadius}
                            fill={C.navyDeep}
                            stroke="none"
                          />
                        </g>
                        <circle
                          id={`${side}-highlight`}
                          cx={e.highlightOffset.x}
                          cy={e.highlightOffset.y}
                          r={e.highlightRadius}
                          fill={C.white}
                          stroke="none"
                        />
                      </g>
                      <g
                        id={`${side}-lid`}
                        data-ho={`${side}-lid`}
                        transform={`translate(0 ${LID_TRAVEL.upperParked})`}
                      >
                        <path
                          d={PATHS.upperLid}
                          fill={C.cream}
                          stroke={C.navy}
                          strokeWidth={STROKE.detail}
                        />
                      </g>
                      <g
                        id={`${side}-lower-lid`}
                        data-ho={`${side}-lower-lid`}
                        transform={`translate(0 ${LID_TRAVEL.lowerParked})`}
                      >
                        <path
                          d={PATHS.lowerLid}
                          fill={C.cream}
                          stroke={C.navy}
                          strokeWidth={STROKE.detail}
                        />
                      </g>
                    </g>
                    <path d={sclera} fill="none" stroke={C.navy} strokeWidth={STROKE.silhouette} />
                  </g>
                );
              })}
            </g>

            {/* --------------------------------------------------------- brows */}
            <g id="brows">
              <g
                id="left-brow"
                data-ho="left-brow"
                transform={`translate(${ANCHORS.leftEye.x} ${ANCHORS.leftEye.y - 60})`}
                opacity={0}
              >
                <path d={PATHS.brow} fill="none" stroke={C.navy} strokeWidth={STROKE.brow} />
              </g>
              <g
                id="right-brow"
                data-ho="right-brow"
                transform={`translate(${ANCHORS.rightEye.x} ${ANCHORS.rightEye.y - 60})`}
                opacity={0}
              >
                <path d={PATHS.brow} fill="none" stroke={C.navy} strokeWidth={STROKE.brow} />
              </g>
            </g>

            {/* ---------------------------------------------------------- beak */}
            <g id="beak" data-ho="beak">
              <rect
                id="beak-gap"
                data-ho="beak-gap"
                x={241}
                y={374}
                width={30}
                height={2}
                rx={3}
                fill={C.navyDeep}
                stroke="none"
              />
              <g id="upper-beak" data-ho="upper-beak">
                <path d={PATHS.upperBeakFill} fill={C.gold} stroke="none" />
                <path d={PATHS.upperBeakEdge} fill="none" strokeWidth={STROKE.detail} />
              </g>
              <g id="lower-beak" data-ho="lower-beak" transform="translate(0 0)">
                <path d={PATHS.lowerBeakFill} fill={C.gold} stroke="none" />
                <path d={PATHS.lowerBeakEdge} fill="none" strokeWidth={STROKE.detail} />
              </g>
            </g>

            {/* ---------------------------------------------------- headphones */}
            <g id="headphones">
              {(['left', 'right'] as const).map((side) => {
                const a = side === 'left' ? ANCHORS.leftHeadphone : ANCHORS.rightHeadphone;
                return (
                  <g
                    key={side}
                    id={`${side}-headphone`}
                    data-ho={`${side}-headphone`}
                    transform={`translate(${a.x} ${a.y})`}
                  >
                    <circle
                      id={`${side}-headphone-glow`}
                      data-ho={`${side}-headphone-glow`}
                      r={HEADPHONE.glowRadius}
                      fill="none"
                      stroke={C.cyanBright}
                      strokeWidth={10}
                      opacity={0}
                    />
                    <circle r={HEADPHONE.outerRadius} fill={C.gold} />
                    <circle r={HEADPHONE.cyanRadius} fill={C.cyanDim} strokeWidth={STROKE.fine} />
                    <circle
                      id={`${side}-headphone-lit`}
                      data-ho={`${side}-headphone-lit`}
                      r={HEADPHONE.cyanRadius}
                      fill={C.cyan}
                      strokeWidth={STROKE.fine}
                      opacity={0}
                    />
                    <circle r={HEADPHONE.innerRadius} fill={C.navyDeep} stroke="none" />
                  </g>
                );
              })}
            </g>
          </g>
        </g>
      </svg>
    );
  },
);
