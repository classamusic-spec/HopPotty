import React from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  View,
  useWindowDimensions,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import Svg, { Circle, Ellipse, Path, Rect } from 'react-native-svg';

import { HopText } from '../../design-system/components';
import { useHopTheme, type HopTheme } from '../../design-system/theme';
import type { HopTypeStyleName } from '../../design-system/tokens.generated';
import { HopCharacter } from '../../mascot/HopCharacter';
import type { ParentTabParamList } from '../../navigation/types';

/**
 * The caregiver surface, in parts.
 *
 * Parent Mode is a grouped-list product: a title, sections of rows, a footer
 * that explains the section it sits under. Eight screens draw that same
 * furniture, so it is built once here rather than eight times slightly
 * differently — the thing `Docs/ReactNativeConventions.md` is written to stop.
 *
 * It lives in `features/settings` rather than in the design system only because
 * the design system is owned elsewhere this phase. Everything here is a
 * candidate to move up once it can: none of it knows anything about Settings.
 *
 * Nothing below invents a value. Sizes are spacing tokens, touch targets are
 * hit-target tokens, colour is semantic. Where a token is genuinely missing the
 * code says so out loud instead of reaching for a hex.
 */

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

/** iPad, in the only sense a layout cares about: a regular-width window. */
const REGULAR_WIDTH = 768;

export interface ParentLayout {
  /** True at iPad width. A sidebar layout, not a stretched phone. */
  readonly isRegular: boolean;
  /** The page's horizontal margin. */
  readonly pageInset: number;
  /** How wide a column of prose is allowed to get before it stops being read. */
  readonly readingWidth: number;
}

export function useParentLayout(): ParentLayout {
  const { width } = useWindowDimensions();
  const theme = useHopTheme();
  const isRegular = width >= REGULAR_WIDTH;
  return {
    isRegular,
    pageInset: isRegular ? theme.spacing.pageRegular : theme.spacing.pageCompact,
    // Twenty-odd ems at parent body size. Full-bleed body text on an iPad is
    // the definition of a stretched phone.
    readingWidth: theme.type.parentBody.size * 26,
  };
}

/** The ground a grouped utility screen stands on. Never Home's pond. */
export function parentPageGround(theme: HopTheme): string {
  return theme.color.surfaceSunken;
}

/**
 * The tint of a control that destroys something.
 *
 * There is no destructive colour in the design tokens — the Swift side paints
 * these with `HopDestructiveButton`, whose tint the token export does not
 * carry. `warning` is the closest honest semantic the tokens have, and this
 * function exists so the day a `destructive` token lands there is exactly one
 * place to change. It is deliberately not a hex.
 */
export function destructiveTint(theme: HopTheme): string {
  return theme.color.warning;
}

/**
 * A pale backing for a tinted mark.
 *
 * The palette's `*Soft` tints are near-white by design, so in a dark
 * appearance they punch a hole in the screen. There is no `surfaceTinted`
 * semantic colour to ask for, so dark falls back to the elevated surface —
 * the mark keeps its colour and the backing stops shouting.
 */
export function softBacking(theme: HopTheme, lightTint: string): string {
  return theme.isDark ? theme.color.surfaceElevated : lightTint;
}

/**
 * Glyph sizes, off the spacing scale.
 *
 * A symbol has a size the way a margin has a size, and the type scale has no
 * opinion about it. Naming three off the same rhythm keeps every row's mark the
 * same weight as its neighbour's.
 */
export function glyphSizes(theme: HopTheme): { s: number; m: number; l: number } {
  return { s: theme.spacing.l, m: theme.spacing.xl, l: theme.spacing.xxl };
}

// ---------------------------------------------------------------------------
// Glyphs
// ---------------------------------------------------------------------------

/**
 * The system-symbol stand-ins the parent surfaces need.
 *
 * These are chrome, not illustration: a chevron, a bell, a lock. `HopArtwork`
 * is the app's picture catalogue and carries no UI symbols, and SF Symbols are
 * not redistributable, so the shapes are the same ones `Scripts/screens/kit.js`
 * draws — which is what the reference renders were made from. Illustration
 * still goes through `HopArtwork`, and Hop still goes through `HopCharacter`.
 */
export type ParentIconName =
  | 'chevron'
  | 'chevronLeft'
  | 'chevronDown'
  | 'plus'
  | 'close'
  | 'check'
  | 'clock'
  | 'bell'
  | 'star'
  | 'lock'
  | 'trash'
  | 'export'
  | 'apps'
  | 'warning'
  | 'minus'
  | 'people'
  | 'pond'
  | 'drop'
  | 'swirl'
  | 'ring'
  | 'home'
  | 'chart'
  | 'gear'
  | 'search';

type IconDraw = (color: string) => React.ReactElement;

const STROKE = {
  hairline: 2,
  regular: 2.2,
  heavy: 2.8,
} as const;

const ICONS: Readonly<Record<ParentIconName, IconDraw>> = {
  chevron: (c) => (
    <Path d="M9 5l7 7-7 7" fill="none" stroke={c} strokeWidth={STROKE.heavy} strokeLinecap="round" strokeLinejoin="round" />
  ),
  chevronLeft: (c) => (
    <Path d="M15 5l-7 7 7 7" fill="none" stroke={c} strokeWidth={STROKE.heavy} strokeLinecap="round" strokeLinejoin="round" />
  ),
  chevronDown: (c) => (
    <Path d="M6 9l6 6 6-6" fill="none" stroke={c} strokeWidth={STROKE.heavy} strokeLinecap="round" strokeLinejoin="round" />
  ),
  plus: (c) => (
    <Path d="M12 5.4v13.2M5.4 12h13.2" fill="none" stroke={c} strokeWidth={STROKE.heavy} strokeLinecap="round" />
  ),
  close: (c) => (
    <Path d="M6 6l12 12M18 6L6 18" fill="none" stroke={c} strokeWidth={STROKE.heavy} strokeLinecap="round" />
  ),
  check: (c) => (
    <Path d="M4.6 12.6 9.6 17.6 19.4 6.6" fill="none" stroke={c} strokeWidth={STROKE.heavy} strokeLinecap="round" strokeLinejoin="round" />
  ),
  clock: (c) => (
    <>
      <Circle cx={12} cy={12} r={8.6} fill="none" stroke={c} strokeWidth={STROKE.regular} />
      <Path d="M12 7.2V12l3.2 2" fill="none" stroke={c} strokeWidth={STROKE.regular} strokeLinecap="round" />
    </>
  ),
  bell: (c) => (
    <Path
      d="M12 22a2.3 2.3 0 0 0 2.3-2.1H9.7A2.3 2.3 0 0 0 12 22zm6.8-6.3v-4.7c0-3.2-1.8-5.7-4.6-6.4v-.7a2.2 2.2 0 0 0-4.4 0v.7c-2.8.7-4.6 3.2-4.6 6.4v4.7l-1.6 1.7v.8h16.8v-.8z"
      fill={c}
    />
  ),
  star: (c) => (
    <Path d="M12 2.4l2.95 6.1 6.7.92-4.87 4.66 1.2 6.6L12 17.55 6.02 20.68l1.2-6.6L2.35 9.42l6.7-.92z" fill={c} />
  ),
  lock: (c) => (
    <Path
      d="M7 10V8a5 5 0 0 1 10 0v2h.6A1.4 1.4 0 0 1 19 11.4v8.2a1.4 1.4 0 0 1-1.4 1.4H6.4A1.4 1.4 0 0 1 5 19.6v-8.2A1.4 1.4 0 0 1 6.4 10zm2.2 0h5.6V8a2.8 2.8 0 0 0-5.6 0z"
      fill={c}
    />
  ),
  trash: (c) => (
    <Path
      d="M9.4 3.2h5.2l.8 1.6h4.2v2.2H4.4V4.8h4.2zM6 8.6h12l-.9 11.1a1.6 1.6 0 0 1-1.6 1.5H8.5a1.6 1.6 0 0 1-1.6-1.5z"
      fill={c}
    />
  ),
  export: (c) => (
    <Path
      d="M12 15.4V3.6M7.8 7.8 12 3.6l4.2 4.2M4.6 14.6v4.4a1.4 1.4 0 0 0 1.4 1.4h12a1.4 1.4 0 0 0 1.4-1.4v-4.4"
      fill="none"
      stroke={c}
      strokeWidth={STROKE.regular}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  ),
  apps: (c) => (
    <>
      <Rect x={3.4} y={3.4} width={7.4} height={7.4} rx={2} fill={c} />
      <Rect x={13.2} y={3.4} width={7.4} height={7.4} rx={2} fill={c} opacity={0.55} />
      <Rect x={3.4} y={13.2} width={7.4} height={7.4} rx={2} fill={c} opacity={0.55} />
      <Rect x={13.2} y={13.2} width={7.4} height={7.4} rx={2} fill={c} />
    </>
  ),
  warning: (c) => (
    <>
      <Circle cx={12} cy={12} r={8.6} fill="none" stroke={c} strokeWidth={STROKE.regular} />
      <Path d="M12 7.6v5" fill="none" stroke={c} strokeWidth={STROKE.regular} strokeLinecap="round" />
      <Circle cx={12} cy={16.2} r={0.9} fill={c} />
    </>
  ),
  minus: (c) => (
    <>
      <Circle cx={12} cy={12} r={9} fill="none" stroke={c} strokeWidth={STROKE.hairline} />
      <Path d="M8 12h8" fill="none" stroke={c} strokeWidth={STROKE.hairline} strokeLinecap="round" />
    </>
  ),
  people: (c) => (
    <>
      <Circle cx={8.6} cy={8.2} r={3.6} fill={c} />
      <Circle cx={16.6} cy={9.4} r={2.8} fill={c} />
      <Path d="M2.4 19.4c0-3.3 2.8-5.6 6.2-5.6s6.2 2.3 6.2 5.6z" fill={c} />
      <Path d="M16.4 14.2c2.8 0 5.2 1.9 5.2 4.6h-4.3c0-1.8-.5-3.4-1.5-4.6z" fill={c} />
    </>
  ),
  pond: (c) => <Ellipse cx={12} cy={13} rx={9} ry={6} fill={c} />,
  drop: (c) => <Path d="M12 2.6c3.6 4.3 6.4 7.8 6.4 11a6.4 6.4 0 0 1-12.8 0c0-3.2 2.8-6.7 6.4-11z" fill={c} />,
  swirl: (c) => (
    <Path
      d="M9.6 6.2c0-1.9 1.3-3.2 2.6-3.2 1.6 0 2.3 1.2 2 2.4 2 .1 3 1.3 2.8 2.7 2 .2 3 1.6 3 2.9 1.7.4 2.6 1.7 2.6 3.1 0 2.2-2 3.9-4.6 3.9H6c-2.6 0-4.6-1.7-4.6-3.9 0-1.5 1-2.8 2.8-3.2-.1-1.6 1-2.9 2.8-3-.2-1.4.9-2.6 2.6-2.7z"
      fill={c}
    />
  ),
  ring: (c) => (
    <>
      <Circle cx={12} cy={12} r={8.4} fill="none" stroke={c} strokeWidth={2.3} />
      <Circle cx={12} cy={12} r={3} fill={c} />
    </>
  ),
  home: (c) => <Path d="M12 3.2 21 11h-2.4v8.2a1 1 0 0 1-1 1H14V15h-4v5.2H6.4a1 1 0 0 1-1-1V11H3z" fill={c} />,
  chart: (c) => (
    <>
      <Rect x={3} y={12} width={4} height={8.5} rx={1.4} fill={c} />
      <Rect x={10} y={7} width={4} height={13.5} rx={1.4} fill={c} />
      <Rect x={17} y={3.5} width={4} height={17} rx={1.4} fill={c} />
    </>
  ),
  gear: (c) => (
    <Path
      d="M12 8.4a3.6 3.6 0 1 0 0 7.2 3.6 3.6 0 0 0 0-7.2zm8.4 3.6c0 .5 0 1-.1 1.5l2 1.6-2 3.4-2.4-1a7.6 7.6 0 0 1-2.5 1.5l-.4 2.5h-4l-.4-2.5a7.6 7.6 0 0 1-2.5-1.5l-2.4 1-2-3.4 2-1.6a8.6 8.6 0 0 1 0-3l-2-1.6 2-3.4 2.4 1a7.6 7.6 0 0 1 2.5-1.5L10 2h4l.4 2.5a7.6 7.6 0 0 1 2.5 1.5l2.4-1 2 3.4-2 1.6c.1.5.1 1 .1 1.5z"
      fill={c}
    />
  ),
  search: (c) => (
    <>
      <Circle cx={10.6} cy={10.6} r={6.8} fill="none" stroke={c} strokeWidth={STROKE.regular} />
      <Path d="M15.6 15.6 20 20" fill="none" stroke={c} strokeWidth={STROKE.regular} strokeLinecap="round" />
    </>
  ),
};

export interface ParentIconProps {
  name: ParentIconName;
  color: string;
  size: number;
}

export function ParentIcon({ name, color, size }: ParentIconProps): React.ReactElement {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      {ICONS[name](color)}
    </Svg>
  );
}

/** A rounded tile of the kind iOS puts at the head of a row. */
export function IconTile({
  background,
  name,
  color,
  size,
}: {
  background: string;
  name: ParentIconName;
  color: string;
  size: number;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View
      style={[
        styles.centre,
        { width: size, height: size, borderRadius: theme.radius.s, backgroundColor: background },
      ]}
    >
      <ParentIcon name={name} color={color} size={Math.round(size * 0.56)} />
    </View>
  );
}

// ---------------------------------------------------------------------------
// Hop's face, on a disc
// ---------------------------------------------------------------------------

/**
 * The child avatar every caregiver screen shows.
 *
 * The rig draws a face-only pose in a 512×290 artboard inside its square
 * viewBox, so a square render leaves the lower part of the box empty; the two
 * numbers below re-seat that artboard inside a circular crop. They describe the
 * drawing, not a design choice.
 *
 * It asks for the rig's `face` pose because `HopAnimationState` has no state
 * for a portrait — a missing state rather than a licence to reach past the map,
 * and worth adding to `hopStates.ts` when the mascot is next opened.
 */
const FACE_OVERSCAN = 1.25;
const FACE_CENTRE = 0.6;

export interface HopFaceDiscProps {
  size: number;
  fill: string;
  ring?: string;
  /** Named for the screen reader, or silent when a name sits beside it. */
  accessibilityLabel?: string;
}

export function HopFaceDisc({
  size,
  fill,
  ring,
  accessibilityLabel,
}: HopFaceDiscProps): React.ReactElement {
  const theme = useHopTheme();
  const drawn = size * FACE_OVERSCAN;
  const artboardRatio = 290 / 512;
  const top = size * FACE_CENTRE - (drawn * artboardRatio) / 2;

  return (
    <View
      accessible={accessibilityLabel !== undefined}
      accessibilityRole={accessibilityLabel !== undefined ? 'image' : undefined}
      accessibilityLabel={accessibilityLabel}
      importantForAccessibility={accessibilityLabel === undefined ? 'no-hide-descendants' : 'yes'}
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        backgroundColor: fill,
        borderWidth: ring === undefined ? 0 : StyleSheet.hairlineWidth * 3,
        borderColor: ring ?? theme.color.divider,
        overflow: 'hidden',
      }}
    >
      <View style={{ position: 'absolute', left: (size - drawn) / 2, top }}>
        <HopCharacter size={drawn} pose="face" animated={false} decorative />
      </View>
    </View>
  );
}

// ---------------------------------------------------------------------------
// Grouped lists
// ---------------------------------------------------------------------------

export interface ParentListRowProps {
  /** Stable identity for the list. Defaults to the label. */
  readonly id?: string;
  readonly label: string;
  readonly sublabel?: string;
  readonly value?: string;
  readonly leading?: React.ReactNode;
  /** Replaces the value-and-chevron pair entirely — a switch, say. */
  readonly accessory?: React.ReactNode;
  readonly chevron?: boolean;
  readonly onPress?: () => void;
  readonly tone?: 'primary' | 'secondary' | 'brand' | 'destructive';
  /** The label's type style. Rows of prose read as callouts, not as titles. */
  readonly labelVariant?: HopTypeStyleName;
  /** Multi-line rows hang their mark from the top rather than centring it. */
  readonly align?: 'centre' | 'top';
  readonly accessibilityHint?: string;
}

/** How far in from the leading edge a row's hairline starts. */
function rowInset(theme: HopTheme, row: ParentListRowProps): number {
  if (row.leading === undefined) return theme.spacing.l;
  return theme.spacing.l + theme.spacing.xxxl + theme.spacing.m;
}

function ListRow({ row }: { row: ParentListRowProps }): React.ReactElement {
  const theme = useHopTheme();
  const g = glyphSizes(theme);

  const labelColour =
    row.tone === 'brand'
      ? theme.color.brandAction
      : row.tone === 'destructive'
        ? destructiveTint(theme)
        : row.tone === 'secondary'
          ? theme.color.textSecondary
          : theme.color.textPrimary;

  const body = (
    <View
      style={[
        styles.row,
        {
          alignItems: row.align === 'top' ? 'flex-start' : 'center',
          minHeight: theme.hitTarget.parentMinimum,
          paddingHorizontal: theme.spacing.l,
          paddingVertical: theme.spacing.s,
          columnGap: theme.spacing.m,
        },
      ]}
    >
      {row.leading === undefined ? null : (
        <View style={[styles.centre, { width: theme.spacing.xxxl }]}>{row.leading}</View>
      )}
      <View style={styles.rowLabel}>
        <HopText variant={row.labelVariant ?? 'parentBody'} style={{ color: labelColour }}>
          {row.label}
        </HopText>
        {row.sublabel === undefined ? null : (
          <HopText variant="parentCaption" tone="secondary">
            {row.sublabel}
          </HopText>
        )}
      </View>
      <View style={[styles.rowAccessory, { columnGap: theme.spacing.xs }]}>
        {row.accessory ??
          (row.value === undefined ? null : (
            <HopText variant="parentCallout" tone="secondary" style={styles.rightText}>
              {row.value}
            </HopText>
          ))}
        {row.chevron === true ? (
          <ParentIcon name="chevron" color={theme.color.textTertiary} size={g.s} />
        ) : null}
      </View>
    </View>
  );

  if (row.onPress === undefined) return body;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={row.value === undefined ? row.label : `${row.label}, ${row.value}`}
      accessibilityHint={row.accessibilityHint}
      onPress={row.onPress}
      style={({ pressed }) => ({
        backgroundColor: pressed ? theme.color.surfaceSunken : 'transparent',
      })}
    >
      {body}
    </Pressable>
  );
}

export interface ListGroupProps {
  header?: string;
  footer?: string;
  rows: readonly ParentListRowProps[];
  style?: StyleProp<ViewStyle>;
}

/** A grouped-list section: an uppercase header, a card of rows, a footer. */
export function ListGroup({ header, footer, rows, style }: ListGroupProps): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View style={style}>
      {header === undefined ? null : (
        <HopText
          variant="parentFootnote"
          tone="secondary"
          style={[
            styles.groupHeader,
            { paddingHorizontal: theme.spacing.l, paddingBottom: theme.spacing.xs },
          ]}
        >
          {header.toUpperCase()}
        </HopText>
      )}
      <View
        style={{
          backgroundColor: theme.color.surface,
          borderRadius: theme.radius.l,
          overflow: 'hidden',
          borderWidth: StyleSheet.hairlineWidth,
          borderColor: theme.color.divider,
        }}
      >
        {rows.map((row, index) => (
          <React.Fragment key={row.id ?? row.label}>
            <ListRow row={row} />
            {index === rows.length - 1 ? null : (
              <View
                style={{
                  height: StyleSheet.hairlineWidth,
                  marginLeft: rowInset(theme, row),
                  backgroundColor: theme.color.divider,
                }}
              />
            )}
          </React.Fragment>
        ))}
      </View>
      {footer === undefined ? null : (
        <HopText
          variant="parentCaption"
          tone="secondary"
          style={{ paddingHorizontal: theme.spacing.l, paddingTop: theme.spacing.s }}
        >
          {footer}
        </HopText>
      )}
    </View>
  );
}

/** A heading in the shape Apple Health puts above a group. */
export function SectionHeader({
  title,
  action,
  onAction,
}: {
  title: string;
  action?: string;
  onAction?: () => void;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View style={[styles.sectionHeader, { paddingBottom: theme.spacing.s, paddingHorizontal: theme.spacing.xs }]}>
      <HopText variant="parentHeadline">{title}</HopText>
      {action === undefined ? null : (
        <Pressable accessibilityRole="button" accessibilityLabel={action} onPress={onAction}>
          <HopText variant="parentCallout" tone="brand">
            {action}
          </HopText>
        </Pressable>
      )}
    </View>
  );
}

// ---------------------------------------------------------------------------
// Controls
// ---------------------------------------------------------------------------

/** The platform switch, tinted. Drawing our own would be a worse switch. */
export function ParentToggle({
  value,
  onValueChange,
  label,
}: {
  value: boolean;
  onValueChange?: (next: boolean) => void;
  label: string;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <Switch
      accessibilityRole="switch"
      accessibilityLabel={label}
      value={value}
      onValueChange={onValueChange}
      trackColor={{ false: theme.color.surfaceSunken, true: theme.color.success }}
      thumbColor={theme.color.surface}
      ios_backgroundColor={theme.color.surfaceSunken}
    />
  );
}

/** iOS segmented control: a sunken track with one raised selected pill. */
export function SegmentedControl<T extends string>({
  items,
  value,
  onChange,
  accessibilityLabel,
}: {
  items: readonly { readonly id: T; readonly label: string }[];
  value: T;
  onChange?: (next: T) => void;
  accessibilityLabel: string;
}): React.ReactElement {
  const theme = useHopTheme();
  const pillHeight = theme.spacing.xxxl;
  const slop = Math.max(0, Math.round((theme.hitTarget.parentMinimum - pillHeight) / 2));

  return (
    <View
      accessibilityRole="tablist"
      accessibilityLabel={accessibilityLabel}
      style={[
        styles.segmented,
        {
          padding: theme.spacing.xxs,
          columnGap: theme.spacing.xxs,
          borderRadius: theme.radius.m,
          backgroundColor: theme.color.surfaceSunken,
          borderWidth: StyleSheet.hairlineWidth,
          borderColor: theme.color.divider,
        },
      ]}
    >
      {items.map((item) => {
        const on = item.id === value;
        return (
          <Pressable
            key={item.id}
            accessibilityRole="tab"
            accessibilityState={{ selected: on }}
            accessibilityLabel={item.label}
            hitSlop={{ top: slop, bottom: slop }}
            onPress={() => onChange?.(item.id)}
            style={[
              styles.segment,
              {
                height: pillHeight,
                borderRadius: theme.radius.s,
                backgroundColor: on ? theme.color.surface : 'transparent',
              },
            ]}
          >
            <HopText variant={on ? 'parentHeadline' : 'parentCallout'} tone={on ? 'primary' : 'secondary'}>
              {item.label}
            </HopText>
          </Pressable>
        );
      })}
    </View>
  );
}

/** A secondary, unfilled caregiver button. Same height as the primary. */
export function SecondaryButton({
  label,
  onPress,
  tone = 'neutral',
  style,
}: {
  label: string;
  onPress?: () => void;
  tone?: 'neutral' | 'destructive';
  style?: StyleProp<ViewStyle>;
}): React.ReactElement {
  const theme = useHopTheme();
  const destructive = tone === 'destructive';
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={onPress}
      style={({ pressed }) => [
        styles.centre,
        {
          minHeight: theme.hitTarget.parentMinimum + theme.spacing.s,
          borderRadius: theme.radius.xl,
          borderWidth: destructive ? 0 : StyleSheet.hairlineWidth * 3,
          borderColor: theme.color.divider,
          backgroundColor: destructive ? theme.color.surfaceSunken : 'transparent',
          opacity: pressed ? 0.7 : 1,
        },
        style,
      ]}
    >
      <HopText
        variant="parentHeadline"
        tone="secondary"
        style={destructive ? { color: destructiveTint(theme) } : undefined}
      >
        {label}
      </HopText>
    </Pressable>
  );
}

/** A pill chip. Selected chips fill; the rest are outlined. */
export function ChoiceChip({
  label,
  selected,
  onPress,
  tint,
  style,
}: {
  label: string;
  selected: boolean;
  onPress?: () => void;
  /** Overrides the brand fill — the reason chips are pond blue, not green. */
  tint?: { readonly fill: string; readonly border: string; readonly text: string };
  style?: StyleProp<ViewStyle>;
}): React.ReactElement {
  const theme = useHopTheme();
  const fill = selected ? (tint?.fill ?? theme.color.brandAction) : theme.color.surface;
  const border = selected ? (tint?.border ?? theme.color.brandAction) : theme.color.divider;
  const text = selected ? (tint?.text ?? theme.color.textOnBrand) : theme.color.textSecondary;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected }}
      accessibilityLabel={label}
      onPress={onPress}
      style={({ pressed }) => [
        styles.centre,
        {
          minHeight: theme.hitTarget.parentMinimum,
          paddingHorizontal: theme.spacing.m,
          borderRadius: theme.hitTarget.parentMinimum / 2,
          backgroundColor: fill,
          borderWidth: StyleSheet.hairlineWidth * 3,
          borderColor: border,
          opacity: pressed ? 0.8 : 1,
        },
        style,
      ]}
    >
      <HopText variant={selected ? 'parentHeadline' : 'parentCallout'} style={{ color: text }}>
        {label}
      </HopText>
    </Pressable>
  );
}

// ---------------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------------

/** A back chevron with the destination's name, then the screen's large title. */
export function ParentNavBar({
  title,
  backLabel,
  onBack,
  trailing,
}: {
  title: string;
  backLabel?: string;
  onBack?: () => void;
  trailing?: React.ReactNode;
}): React.ReactElement {
  const theme = useHopTheme();
  const g = glyphSizes(theme);
  return (
    <View style={{ paddingBottom: theme.spacing.xs }}>
      <View style={[styles.navRow, { minHeight: theme.hitTarget.parentMinimum }]}>
        {onBack === undefined && backLabel === undefined ? (
          <View />
        ) : (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={backLabel === undefined ? 'Back' : `Back to ${backLabel}`}
            onPress={onBack}
            style={[styles.backRow, { columnGap: theme.spacing.xxs }]}
          >
            <ParentIcon name="chevronLeft" color={theme.color.brandAction} size={g.m} />
            {backLabel === undefined ? null : (
              <HopText variant="parentBody" tone="brand">
                {backLabel}
              </HopText>
            )}
          </Pressable>
        )}
        {trailing}
      </View>
      <HopText variant="parentLargeTitle">{title}</HopText>
    </View>
  );
}

/** The grabber and title bar a sheet carries. */
export function SheetHeader({
  title,
  subtitle,
  onClose,
}: {
  title: string;
  subtitle?: string;
  onClose?: () => void;
}): React.ReactElement {
  const theme = useHopTheme();
  const g = glyphSizes(theme);
  return (
    <View>
      <View style={[styles.centre, { paddingVertical: theme.spacing.s }]}>
        <View
          style={{
            width: theme.spacing.huge,
            height: theme.spacing.xs + 1,
            borderRadius: theme.radius.xs,
            backgroundColor: theme.color.divider,
          }}
        />
      </View>
      <View style={[styles.sheetTitleRow, { columnGap: theme.spacing.m }]}>
        <View style={styles.rowLabel}>
          <HopText variant="parentTitle">{title}</HopText>
          {subtitle === undefined ? null : (
            <HopText variant="parentCallout" tone="secondary" style={{ marginTop: theme.spacing.xxs }}>
              {subtitle}
            </HopText>
          )}
        </View>
        {onClose === undefined ? null : (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Close"
            onPress={onClose}
            style={[
              styles.centre,
              {
                width: theme.spacing.xxxl,
                height: theme.spacing.xxxl,
                borderRadius: theme.spacing.l,
                backgroundColor: theme.color.surfaceSunken,
              },
            ]}
            hitSlop={theme.spacing.s}
          >
            <ParentIcon name="close" color={theme.color.textTertiary} size={g.s} />
          </Pressable>
        )}
      </View>
    </View>
  );
}

/**
 * The iPad split-view rail.
 *
 * §44 asks for intentional split navigation rather than a stretched phone, and
 * `44-insights-ipad` draws it: a sunken ground, the selected row a filled
 * capsule in the brand colour, and the child switcher parked at the foot where
 * iPadOS puts an account. It is the same rail on every regular-width screen so
 * the two iPad layouts are visibly the same app.
 */
export type ParentSection = keyof ParentTabParamList;

export const PARENT_SECTION_LABEL: Readonly<Record<ParentSection, string>> = {
  Home: 'Home',
  Progress: 'Progress',
  Pond: "Hop's Pond",
  Settings: 'Settings',
};

const SECTION_ICON: Readonly<Record<ParentSection, ParentIconName>> = {
  Home: 'home',
  Progress: 'chart',
  Pond: 'pond',
  Settings: 'gear',
};

const SECTION_ORDER: readonly ParentSection[] = ['Home', 'Progress', 'Pond', 'Settings'];

export const SIDEBAR_WIDTH = 244;

export function ParentSidebar({
  active,
  childName,
  onSelect,
  onSwitchChild,
}: {
  active: ParentSection;
  childName: string;
  onSelect?: (section: ParentSection) => void;
  onSwitchChild?: () => void;
}): React.ReactElement {
  const theme = useHopTheme();
  const g = glyphSizes(theme);

  return (
    <View
      accessibilityRole="menu"
      accessibilityLabel="HopPotty sections"
      style={{
        width: SIDEBAR_WIDTH,
        backgroundColor: theme.color.surfaceSunken,
        borderRightWidth: StyleSheet.hairlineWidth,
        borderRightColor: theme.color.divider,
        paddingTop: theme.spacing.xxl,
      }}
    >
      <View style={{ paddingHorizontal: theme.spacing.xl, paddingBottom: theme.spacing.m }}>
        <HopText variant="parentLargeTitle">HopPotty</HopText>
      </View>
      <View style={{ paddingHorizontal: theme.spacing.m, rowGap: theme.spacing.xxs }}>
        {SECTION_ORDER.map((section) => {
          const on = section === active;
          return (
            <Pressable
              key={section}
              accessibilityRole="menuitem"
              accessibilityState={{ selected: on }}
              accessibilityLabel={PARENT_SECTION_LABEL[section]}
              onPress={() => onSelect?.(section)}
              style={[
                styles.sidebarRow,
                {
                  height: theme.hitTarget.parentMinimum,
                  paddingHorizontal: theme.spacing.m,
                  columnGap: theme.spacing.m,
                  borderRadius: theme.radius.s,
                  backgroundColor: on ? theme.color.brandAction : 'transparent',
                },
              ]}
            >
              <ParentIcon
                name={SECTION_ICON[section]}
                color={on ? theme.color.textOnBrand : theme.color.textSecondary}
                size={g.l}
              />
              <HopText
                variant={on ? 'parentHeadline' : 'parentBody'}
                style={{ color: on ? theme.color.textOnBrand : theme.color.textPrimary }}
              >
                {PARENT_SECTION_LABEL[section]}
              </HopText>
            </Pressable>
          );
        })}
      </View>
      <View style={styles.grow} />
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Currently showing ${childName}. Switch child`}
        onPress={onSwitchChild}
        style={[
          styles.sidebarRow,
          {
            paddingHorizontal: theme.spacing.xl,
            paddingBottom: theme.spacing.l,
            columnGap: theme.spacing.s,
          },
        ]}
      >
        <HopFaceDisc size={theme.spacing.xxxl} fill={theme.palette.hopGreenSoft} />
        <HopText variant="parentHeadline" style={styles.grow}>
          {childName}
        </HopText>
        <ParentIcon name="chevronDown" color={theme.color.textTertiary} size={g.s} />
      </Pressable>
    </View>
  );
}

/**
 * A page: the utility ground, the safe margins, and a reading column that stops
 * growing at iPad width.
 */
export function ParentPage({
  children,
  contentWidth,
  scrolls = true,
}: {
  children: React.ReactNode;
  /** Cap the column. Defaults to the reading width at regular size. */
  contentWidth?: number;
  scrolls?: boolean;
}): React.ReactElement {
  const theme = useHopTheme();
  const { isRegular, pageInset, readingWidth } = useParentLayout();
  const max = contentWidth ?? readingWidth;

  const inner = (
    <View
      style={{
        paddingHorizontal: pageInset,
        paddingBottom: theme.spacing.huge,
        rowGap: theme.spacing.m,
        width: '100%',
        maxWidth: isRegular ? max : undefined,
        alignSelf: 'center',
      }}
    >
      {children}
    </View>
  );

  if (!scrolls) {
    return <View style={[styles.grow, { backgroundColor: parentPageGround(theme) }]}>{inner}</View>;
  }
  return (
    <ScrollView
      style={{ backgroundColor: parentPageGround(theme) }}
      contentContainerStyle={styles.pageContent}
    >
      {inner}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  centre: { alignItems: 'center', justifyContent: 'center' },
  grow: { flex: 1 },
  pageContent: { flexGrow: 1 },
  row: { flexDirection: 'row' },
  rowLabel: { flex: 1, minWidth: 0 },
  rowAccessory: { flexDirection: 'row', alignItems: 'center', flexShrink: 0 },
  rightText: { textAlign: 'right' },
  groupHeader: { textTransform: 'uppercase', letterSpacing: 0.5 },
  sectionHeader: { flexDirection: 'row', alignItems: 'baseline', justifyContent: 'space-between' },
  segmented: { flexDirection: 'row' },
  segment: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  navRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  backRow: { flexDirection: 'row', alignItems: 'center' },
  sheetTitleRow: { flexDirection: 'row', alignItems: 'flex-start' },
  sidebarRow: { flexDirection: 'row', alignItems: 'center' },
});
