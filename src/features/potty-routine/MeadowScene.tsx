import React from 'react';
import { StyleSheet } from 'react-native';
import Svg, { Circle, Defs, Ellipse, G, LinearGradient, Path, RadialGradient, Rect, Stop } from 'react-native-svg';

import { useHopTheme } from '../../design-system/theme';

/**
 * The HopPotty outdoors: warm sky, a low sun, two soft hills and a grass shelf
 * for a character to stand on.
 *
 * Two screens in the routine happen outside — the arrival, where Hop walks up
 * the path to the bathroom door, and the celebration. Neither has a
 * `HopIllustrationKey`: the generated catalogue carries the five bathroom scenes
 * and the eight game scenes, and no meadow. Rather than crop a game backdrop
 * into a place it is not, this paints the same bands the render harness paints
 * (`Scripts/screens/scenes.js`, `meadow`) out of palette tokens. Adding
 * `scene.meadow` to `Scripts/art-keys.sh` would replace the whole file with one
 * `HopArtwork` call, and should.
 *
 * `horizon` is the fraction of the frame the sky occupies. Everything taller
 * than a blade of grass waits until `propsOffset` below it, so a headline over
 * the field never lands on a flower.
 */
export interface MeadowSceneProps {
  readonly width: number;
  readonly height: number;
  readonly horizon?: number;
  readonly propsOffset?: number;
  /**
   * The bathroom door at the end of the path.
   *
   * "Let's hop to the potty" said to a two-year-old without a picture of *where*
   * is only words, so the destination is drawn on the screen that asks them to
   * walk to it.
   */
  readonly showsDoor?: boolean;
}

export function MeadowScene({
  width,
  height,
  horizon = 0.6,
  propsOffset = 60,
  showsDoor = false,
}: MeadowSceneProps): React.ReactElement {
  const theme = useHopTheme();
  const p = theme.palette;
  const ns = React.useId().replace(/[^A-Za-z0-9]/g, '');
  const skyId = `meadowSky${ns}`;
  const nearId = `meadowNear${ns}`;
  const sunId = `meadowSun${ns}`;

  const w = width;
  const h = height;
  const y0 = h * horizon;
  const py = y0 + propsOffset;

  // The door sits up the path, small, so Hop reads as heading somewhere rather
  // than standing beside a prop.
  const doorX = w * 0.84;
  const doorGround = h * 0.5;
  const doorScale = 0.52;

  return (
    <Svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={StyleSheet.absoluteFill}>
      <Defs>
        <LinearGradient id={skyId} x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor={p.pondBlueLight} />
          <Stop offset="0.55" stopColor={p.pondBlueSoft} />
          <Stop offset="1" stopColor={p.cloud} />
        </LinearGradient>
        <LinearGradient id={nearId} x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor={p.hopGreenLight} />
          <Stop offset="1" stopColor={p.hopGreen} />
        </LinearGradient>
        <RadialGradient id={sunId} cx="0.5" cy="0.5" r="0.5">
          <Stop offset="0" stopColor={p.sunshine} stopOpacity={0.42} />
          <Stop offset="1" stopColor={p.sunshine} stopOpacity={0} />
        </RadialGradient>
      </Defs>

      <Rect x={0} y={0} width={w} height={h} fill={`url(#${skyId})`} />
      <Circle cx={w * 0.82} cy={h * 0.13} r={w * 0.34} fill={`url(#${sunId})`} />
      <Circle cx={w * 0.82} cy={h * 0.13} r={w * 0.085} fill={p.sunshineSoft} />

      <Cloud x={w * 0.2} y={h * 0.13} scale={0.95} fill={p.cloud} opacity={0.8} />
      <Cloud x={w * 0.72} y={h * 0.27} scale={0.62} fill={p.cloud} opacity={0.6} />
      <Cloud x={w * 0.05} y={h * 0.33} scale={0.5} fill={p.cloud} opacity={0.45} />

      {/* far hills */}
      <Path
        d={
          `M 0 ${y0 - 40} C ${w * 0.18} ${y0 - 92}, ${w * 0.42} ${y0 - 88}, ${w * 0.58} ${y0 - 44} ` +
          `C ${w * 0.74} ${y0 - 4}, ${w * 0.9} ${y0 - 18}, ${w} ${y0 - 46} L ${w} ${h} L 0 ${h} Z`
        }
        fill={p.hopGreenSoft}
      />
      <Path
        d={
          `M 0 ${y0 - 6} C ${w * 0.22} ${y0 - 46}, ${w * 0.5} ${y0 - 40}, ${w * 0.7} ${y0 - 12} ` +
          `C ${w * 0.85} ${y0 + 8}, ${w * 0.94} ${y0 - 2}, ${w} ${y0 - 14} L ${w} ${h} L 0 ${h} Z`
        }
        fill={p.hopGreenLight}
      />

      {/* near ground */}
      <Path
        d={
          `M 0 ${y0 + 26} C ${w * 0.26} ${y0 - 2}, ${w * 0.62} ${y0 + 2}, ${w} ${y0 + 30} ` +
          `L ${w} ${h} L 0 ${h} Z`
        }
        fill={`url(#${nearId})`}
      />

      {showsDoor ? (
        <>
          <Path
            d={
              `M ${w * 0.34} ${h} C ${w * 0.4} ${h - 130}, ${doorX - 26} ${doorGround + 90}, ` +
              `${doorX - 10} ${doorGround + 2} L ${doorX + 24} ${doorGround + 2} ` +
              `C ${doorX + 20} ${doorGround + 96}, ${w * 0.66} ${h - 120}, ${w * 0.78} ${h} Z`
            }
            fill={p.sand100}
            opacity={0.92}
          />
          <Doorway x={doorX} groundY={doorGround} scale={doorScale} />
        </>
      ) : null}

      {/* distant tufts sit on the horizon; anything taller waits for propsOffset */}
      <Tuft x={w * 0.34} y={y0 + 12} scale={0.5} tone={p.hopGreen} />
      <Tuft x={w * 0.62} y={y0 + 16} scale={0.45} tone={p.hopGreen} />
      <Reeds x={w * 0.08} y={py + 4} scale={0.85} />
      <Reeds x={w * 0.94} y={py + 12} scale={0.72} />
      <Tuft x={w * 0.24} y={py} scale={1} tone={p.hopGreenDeep} />
      <Tuft x={w * 0.79} y={py + 8} scale={0.85} tone={p.hopGreenDeep} />
      <Flower x={w * 0.16} y={py + 20} scale={0.9} petal={p.sunshine} heart={p.sunshineDeep} />
      <Flower x={w * 0.88} y={py + 28} scale={0.8} petal={p.peachPop} heart={p.sunshineSoft} />
      <Flower x={w * 0.36} y={py + 36} scale={0.7} petal={p.cloud} heart={p.sunshine} />
    </Svg>
  );
}

function Cloud({
  x,
  y,
  scale,
  fill,
  opacity,
}: {
  x: number;
  y: number;
  scale: number;
  fill: string;
  opacity: number;
}): React.ReactElement {
  return (
    <G opacity={opacity} transform={`translate(${x} ${y}) scale(${scale})`}>
      <Ellipse cx={0} cy={6} rx={52} ry={17} fill={fill} />
      <Circle cx={-18} cy={-2} r={19} fill={fill} />
      <Circle cx={8} cy={-9} r={24} fill={fill} />
      <Circle cx={32} cy={0} r={16} fill={fill} />
    </G>
  );
}

function Tuft({
  x,
  y,
  scale,
  tone,
}: {
  x: number;
  y: number;
  scale: number;
  tone: string;
}): React.ReactElement {
  return (
    <G transform={`translate(${x} ${y}) scale(${scale})`}>
      <Path d="M -9 0 C -8 -8, -6 -13, -3 -17" stroke={tone} strokeWidth={4} fill="none" strokeLinecap="round" />
      <Path d="M 0 0 C 0 -10, 1 -16, 3 -22" stroke={tone} strokeWidth={4} fill="none" strokeLinecap="round" />
      <Path d="M 9 0 C 8 -8, 7 -13, 4 -18" stroke={tone} strokeWidth={4} fill="none" strokeLinecap="round" />
    </G>
  );
}

function Reeds({ x, y, scale }: { x: number; y: number; scale: number }): React.ReactElement {
  const theme = useHopTheme();
  return (
    <G transform={`translate(${x} ${y}) scale(${scale})`}>
      <Path
        d="M -6 0 C -8 -26, -4 -44, 2 -58"
        stroke={theme.palette.hopGreen}
        strokeWidth={4}
        fill="none"
        strokeLinecap="round"
      />
      <Path
        d="M 8 0 C 8 -22, 10 -38, 14 -52"
        stroke={theme.palette.hopGreen}
        strokeWidth={4}
        fill="none"
        strokeLinecap="round"
      />
      <Ellipse cx={2} cy={-62} rx={5} ry={11} fill={theme.palette.sand300} />
      <Ellipse cx={14} cy={-56} rx={4} ry={9} fill={theme.palette.sand200} />
    </G>
  );
}

function Flower({
  x,
  y,
  scale,
  petal,
  heart,
}: {
  x: number;
  y: number;
  scale: number;
  petal: string;
  heart: string;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <G transform={`translate(${x} ${y}) scale(${scale})`}>
      <Path
        d="M 0 0 C 1 -10, 0 -18, -1 -24"
        stroke={theme.palette.hopGreenDeep}
        strokeWidth={3}
        fill="none"
        strokeLinecap="round"
      />
      <G transform="translate(-1 -26)">
        {[0, 72, 144, 216, 288].map((angle) => (
          <Ellipse key={angle} cx={0} cy={-7} rx={5} ry={7} fill={petal} transform={`rotate(${angle})`} />
        ))}
        <Circle r={3.6} fill={heart} />
      </G>
    </G>
  );
}

/**
 * The bathroom door at the end of the path.
 *
 * Small and up the path, drawn with the same shape the render harness draws so
 * the arrival screen and its reference PNG agree about where the child is going.
 */
function Doorway({
  x,
  groundY,
  scale,
}: {
  x: number;
  groundY: number;
  scale: number;
}): React.ReactElement {
  const theme = useHopTheme();
  const p = theme.palette;
  return (
    <G transform={`translate(${x} ${groundY}) scale(${scale})`}>
      <Ellipse cx={0} cy={4} rx={66} ry={10} fill={p.midnight} opacity={0.08} />
      <Rect x={-52} y={-8} width={104} height={12} rx={5} fill={p.sand200} />
      <Rect x={-44} y={-116} width={88} height={110} rx={4} fill={p.sand300} />
      <Path d="M -60 -116 L 0 -168 L 60 -116 Z" fill={p.hopGreenDeep} />
      <Path d="M -60 -116 L 0 -168 L 0 -116 Z" fill={p.hopGreenLight} opacity={0.35} />
      <Rect x={-32} y={-104} width={64} height={92} rx={30} fill={p.peachDeep} opacity={0.35} />
      <Rect x={-24} y={-96} width={48} height={40} rx={21} fill={p.sunshineSoft} />
      <Circle cx={18} cy={-52} r={5} fill={p.sunshineBright} />
    </G>
  );
}
