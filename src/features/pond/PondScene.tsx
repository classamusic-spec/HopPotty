import React from 'react';
import { StyleSheet, View } from 'react-native';
import Svg, { Defs, Ellipse, LinearGradient, Path, RadialGradient, Rect, Stop } from 'react-native-svg';

import { HopArtwork } from '../../art/HopArtwork';
import { useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';
import { HOP_FEET_FRACTION } from '../../mascot/poses.generated';
import {
  POND_ANCHORS,
  POND_FOREGROUND_LAYERS,
  POND_HOP,
  POND_ITEM_EXTENT,
  POND_LAYERS,
  pondArtwork,
  pondPoint,
  pondStageBox,
  type PondItemId,
} from './pondLayout';

/**
 * The pond, as a place.
 *
 * The child's own decorations are drawn *in the water*, at `PondCatalog`'s
 * anchors and at the size the app draws them, rather than as a row of trophies
 * under a wallpaper. That is the whole difference between a pond and a cabinet,
 * and it is why the anchors are shared with the app rather than re-eyeballed.
 *
 * ## Why the ground is drawn here instead of loaded
 *
 * Every decoration is real art (`pond.<id>`), but the *backdrop* is not
 * reachable: `Art/pond/pond-stage.svg` exists on disk and is what the app and
 * the design renders draw, yet it has no `HopIllustrationKey` — the generated
 * catalogue only carries the forty-one `PondItemID` decorations, so there is no
 * key to ask for. Rather than invent a picture, this paints the same five bands
 * the stage drawing has — sky, far bank, field, water, near shore — from the
 * palette tokens, at the stage's own proportions, so the anchors still land
 * where they should. Adding `scene.pond` to `Scripts/art-keys.sh` would let this
 * be one `HopArtwork` call.
 */
export interface PondSceneProps {
  readonly width: number;
  readonly height: number;
  /** The decorations this child has unlocked. Order does not matter. */
  readonly unlocked?: readonly PondItemId[];
  /** Whether Hop sits on his pad in the middle of the water. */
  readonly showsHop?: boolean;
  readonly hopAccessibilityLabel?: string;
}

export function PondScene({
  width,
  height,
  unlocked = [],
  showsHop = true,
  hopAccessibilityLabel,
}: PondSceneProps): React.ReactElement {
  const box = pondStageBox(width, height);
  const has = (id: PondItemId): boolean => unlocked.includes(id);

  const hopCentre = pondPoint(box, POND_HOP.x, POND_HOP.y);
  const hopSide = box.width * POND_HOP.extent;

  const layer = (ids: readonly PondItemId[]): React.ReactElement[] =>
    ids.filter(has).map((id) => {
      const [ux, uy, scale] = POND_ANCHORS[id];
      const side = box.width * POND_ITEM_EXTENT * scale;
      const centre = pondPoint(box, ux, uy);
      return (
        <View
          key={id}
          pointerEvents="none"
          style={{
            position: 'absolute',
            left: centre.x - side / 2,
            top: centre.y - side / 2,
            width: side,
            height: side,
          }}
        >
          <HopArtwork artwork={pondArtwork(id)} width={side} height={side} decorative />
        </View>
      );
    });

  return (
    <View pointerEvents="none" style={[StyleSheet.absoluteFill, { width, height }]}>
      <PondGround width={width} height={height} />

      {POND_LAYERS.map((ids, i) => (
        <React.Fragment key={i}>{layer(ids)}</React.Fragment>
      ))}

      {showsHop ? (
        <>
          <HopLilyPad width={width} height={height} />
          <View
            style={{
              position: 'absolute',
              left: hopCentre.x - hopSide / 2,
              top: hopCentre.y - hopSide * HOP_FEET_FRACTION,
              width: hopSide,
              height: hopSide,
            }}
          >
            <HopCharacter
              size={hopSide}
              state="sit"
              decorative={hopAccessibilityLabel === undefined}
              accessibilityLabel={hopAccessibilityLabel}
            />
          </View>
        </>
      ) : null}

      {POND_FOREGROUND_LAYERS.map((ids, i) => (
        <React.Fragment key={i}>{layer(ids)}</React.Fragment>
      ))}
    </View>
  );
}

/** The pad Hop sits on, and the shadow that seats him on the water. */
function HopLilyPad({ width, height }: { width: number; height: number }): React.ReactElement {
  const theme = useHopTheme();
  const box = pondStageBox(width, height);
  const centre = pondPoint(box, POND_HOP.x, POND_HOP.y);
  const side = box.width * POND_HOP.extent;
  const r = side * 0.62;

  return (
    <Svg
      width={width}
      height={height}
      viewBox={`0 0 ${width} ${height}`}
      style={StyleSheet.absoluteFill}
    >
      <Path
        d={
          `M ${centre.x - r} ${centre.y} a ${r} ${r * 0.3} 0 1 0 ${r * 2} 0 ` +
          `a ${r} ${r * 0.3} 0 1 0 ${-r * 2} 0 Z ` +
          `M ${centre.x} ${centre.y} L ${centre.x + r * 0.86} ${centre.y - r * 0.2} ` +
          `L ${centre.x + r * 0.7} ${centre.y - r * 0.27} Z`
        }
        fill={theme.palette.hopGreenDeep}
        fillRule="evenodd"
      />
      <Ellipse
        cx={centre.x - r * 0.22}
        cy={centre.y - r * 0.155}
        rx={r * 0.5}
        ry={r * 0.085}
        fill={theme.palette.cloud}
        opacity={0.18}
      />
      <Ellipse
        cx={centre.x}
        cy={centre.y}
        rx={side * 0.26}
        ry={side * 0.055}
        fill={theme.palette.pondBlueDeep}
        opacity={0.2}
      />
    </Svg>
  );
}

/**
 * Sky, far bank, field, water and near shore — the ground everything else
 * stands on.
 */
function PondGround({ width, height }: { width: number; height: number }): React.ReactElement {
  const theme = useHopTheme();
  const p = theme.palette;
  const box = pondStageBox(width, height);
  // Gradient ids are global to the document, so two ponds on one screen — the
  // hub's backdrop and its pond door's thumbnail — would capture each other's
  // sky. The same collision the art generator namespaces for.
  const ns = React.useId().replace(/[^A-Za-z0-9]/g, '');
  const skyId = `pondSky${ns}`;
  const fieldId = `pondField${ns}`;
  const waterId = `pondWater${ns}`;
  const sunId = `pondSun${ns}`;

  const horizon = box.y + box.height * 0.44;
  const water = pondPoint(box, 0.5, 0.62);
  const waterRx = box.width * 0.4;
  const waterRy = box.height * 0.145;
  const nearGrass = box.y + box.height * 0.92;

  return (
    <Svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} style={StyleSheet.absoluteFill}>
      <Defs>
        <LinearGradient id={skyId} x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor={p.pondBlue} />
          <Stop offset="0.72" stopColor={p.pondBlueLight} />
          <Stop offset="1" stopColor={p.pondBlueSoft} />
        </LinearGradient>
        <LinearGradient id={fieldId} x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor={p.hopGreenLight} />
          <Stop offset="1" stopColor={p.hopGreen} />
        </LinearGradient>
        <LinearGradient id={waterId} x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor={p.pondBlueLight} />
          <Stop offset="0.34" stopColor={p.pondBlue} />
          <Stop offset="1" stopColor={p.pondBlueDeep} />
        </LinearGradient>
        <RadialGradient id={sunId} cx="0.5" cy="0.5" r="0.5">
          <Stop offset="0" stopColor={p.sunshine} stopOpacity={0.45} />
          <Stop offset="1" stopColor={p.sunshine} stopOpacity={0} />
        </RadialGradient>
      </Defs>

      {/* sky, continuing above the stage so a tall phone reads as more air */}
      <Rect x={0} y={0} width={width} height={horizon + 2} fill={`url(#${skyId})`} />
      <Ellipse
        cx={width * 0.18}
        cy={box.y + box.height * 0.2}
        rx={width * 0.42}
        ry={width * 0.42}
        fill={`url(#${sunId})`}
      />

      {/* the far bank, and the bushes standing on it */}
      <Path
        d={
          `M 0 ${horizon + 10} C ${width * 0.24} ${horizon - 26}, ${width * 0.6} ${horizon - 20}, ` +
          `${width * 0.8} ${horizon + 6} C ${width * 0.9} ${horizon + 18}, ${width * 0.96} ${horizon + 10}, ` +
          `${width} ${horizon + 2} L ${width} ${height} L 0 ${height} Z`
        }
        fill={p.hopGreenSoft}
      />
      <Ellipse cx={width * 0.08} cy={horizon} rx={width * 0.13} ry={width * 0.07} fill={p.hopGreenLight} />
      <Ellipse cx={width * 0.36} cy={horizon - 8} rx={width * 0.1} ry={width * 0.055} fill={p.hopGreenLight} />
      <Ellipse cx={width * 0.72} cy={horizon + 2} rx={width * 0.14} ry={width * 0.065} fill={p.hopGreenLight} />
      <Ellipse cx={width * 0.96} cy={horizon - 4} rx={width * 0.09} ry={width * 0.05} fill={p.hopGreenLight} />

      {/* the field the pond is cut into */}
      <Path
        d={
          `M 0 ${horizon + 30} C ${width * 0.26} ${horizon + 12}, ${width * 0.66} ${horizon + 14}, ` +
          `${width} ${horizon + 34} L ${width} ${height} L 0 ${height} Z`
        }
        fill={`url(#${fieldId})`}
      />

      {/* the water, with the sandy rim the app draws around it */}
      <Ellipse
        cx={water.x}
        cy={water.y}
        rx={waterRx + box.width * 0.022}
        ry={waterRy + box.height * 0.016}
        fill={p.sand200}
      />
      <Ellipse cx={water.x} cy={water.y} rx={waterRx} ry={waterRy} fill={`url(#${waterId})`} />
      <Path
        d={`M ${water.x - waterRx * 0.62} ${water.y - waterRy * 0.2} q ${waterRx * 0.2} ${-waterRy * 0.16} ${waterRx * 0.4} 0`}
        fill="none"
        stroke={p.cloud}
        strokeOpacity={0.3}
        strokeWidth={4}
        strokeLinecap="round"
      />
      <Path
        d={`M ${water.x + waterRx * 0.1} ${water.y + waterRy * 0.42} q ${waterRx * 0.18} ${-waterRy * 0.14} ${waterRx * 0.36} 0`}
        fill="none"
        stroke={p.cloud}
        strokeOpacity={0.22}
        strokeWidth={4}
        strokeLinecap="round"
      />

      {/* the near shore, closest to the child */}
      <Path
        d={
          `M 0 ${nearGrass + 12} C ${width * 0.3} ${nearGrass - 10}, ${width * 0.7} ${nearGrass - 8}, ` +
          `${width} ${nearGrass + 10} L ${width} ${height} L 0 ${height} Z`
        }
        fill={p.hopGreenDeep}
        opacity={0.55}
      />
    </Svg>
  );
}
