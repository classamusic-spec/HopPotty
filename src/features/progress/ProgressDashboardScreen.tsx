import React from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';

import { HopButton, HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { HopCharacter } from '../../mascot/HopCharacter';
import {
  HopFaceDisc,
  ListGroup,
  ParentIcon,
  ParentSidebar,
  SectionHeader,
  SegmentedControl,
  glyphSizes,
  parentPageGround,
  useParentLayout,
  type ParentIconName,
  type ParentListRowProps,
  type ParentSection,
} from '../settings/ParentKit';

/**
 * Progress.
 *
 * References: `Art/render/screens/13-insights.png`, `40-progress-empty.png`
 * and `44-insights-ipad.png`, with the layout in `Scripts/screens/insights.js`.
 *
 * ## What this screen is not allowed to say
 *
 * Descriptive statistics, never advice, and never a performance. No success
 * rate, no dry streak, no best day, no ranking — a "longest" is a record, a
 * record invites beating it, and the thing being scored would be a child's
 * body. What is here is counts and ranges: potty check-ins, routine
 * participation, the common interval, the most consistent time of day, and
 * hand-washing completion. Accidents are counted, on a line of their own,
 * never as a headline figure and never as a rate.
 *
 * The hedge is said once, as the footer of the group it qualifies, rather than
 * three times as a pill on three cards.
 */

export type ProgressPeriod = 'day' | 'week' | 'month';

export interface ProgressBar {
  /** The axis label under the column — a weekday initial, a date, a month. */
  readonly label: string;
  readonly value: number;
}

export interface ProgressCounts {
  readonly checks: number;
  readonly tried: number;
  readonly pee: number;
  readonly poop: number;
}

export interface ProgressObservation {
  readonly id: string;
  readonly label: string;
  readonly value: string;
}

export interface ProgressDashboardScreenProps {
  childName: string;
  period: ProgressPeriod;
  /** False shows the day-one empty state rather than an empty chart. */
  hasEntries: boolean;
  checkIns: number;
  /** "across 5 days with entries" — the caller counts, the screen prints. */
  checkInsCaption: string;
  bars: readonly ProgressBar[];
  counts: ProgressCounts;
  observations: readonly ProgressObservation[];
  /** The hedge. Descriptive of a period, never advice. */
  disclaimer?: string;
  onChangePeriod?: (period: ProgressPeriod) => void;
  onSelectChild?: () => void;
  onSelectObservation?: (id: string) => void;
  onLogVisit?: () => void;
  /** Regular width only: the split-view rail's destinations. */
  onSelectSection?: (section: ParentSection) => void;
}

/** The verbatim hedge from the reference. Exported so a caller can vary it. */
export const PROGRESS_DISCLAIMER =
  'Patterns in what you logged over 7 days. Descriptions of a period, not medical advice.';

const EMPTY_TITLE = 'Nothing logged yet today';
const EMPTY_BODY = 'Entries appear here as you and your child log them.';
const EMPTY_FOOTNOTE = 'Patterns need several days of entries before they describe anything.';

const PERIODS: readonly { readonly id: ProgressPeriod; readonly label: string }[] = [
  { id: 'day', label: 'Day' },
  { id: 'week', label: 'Week' },
  { id: 'month', label: 'Month' },
];

const PERIOD_SECTION: Readonly<Record<ProgressPeriod, string>> = {
  day: 'Today',
  week: 'This week',
  month: 'This month',
};

export function ProgressDashboardScreen({
  childName,
  period,
  hasEntries,
  checkIns,
  checkInsCaption,
  bars,
  counts,
  observations,
  disclaimer = PROGRESS_DISCLAIMER,
  onChangePeriod,
  onSelectChild,
  onSelectObservation,
  onLogVisit,
  onSelectSection,
}: ProgressDashboardScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const { isRegular, pageInset } = useParentLayout();

  const rows: readonly ParentListRowProps[] = observations.map((item) => ({
    id: item.id,
    label: item.label,
    value: item.value,
    chevron: true,
    onPress: onSelectObservation === undefined ? undefined : () => onSelectObservation(item.id),
  }));

  const segmented = (
    <SegmentedControl
      items={PERIODS}
      value={period}
      onChange={onChangePeriod}
      accessibilityLabel="Period"
    />
  );

  const chip = <ChildChip name={childName} onPress={onSelectChild} />;

  // ---- Regular width: a rail, then two columns. Not a stretched phone. ----
  if (isRegular) {
    return (
      <View style={[styles.split, { backgroundColor: parentPageGround(theme) }]}>
        <ParentSidebar
          active="Progress"
          childName={childName}
          onSelect={onSelectSection}
          onSwitchChild={onSelectChild}
        />
        <ScrollView style={styles.grow} contentContainerStyle={{ padding: pageInset }}>
          <View style={[styles.headerRow, { columnGap: theme.spacing.m }]}>
            <HopText variant="parentLargeTitle" style={styles.grow}>
              Progress
            </HopText>
            <View style={{ width: theme.spacing.giant * 4 }}>{segmented}</View>
            {chip}
          </View>

          {hasEntries ? (
            <View style={[styles.columns, { columnGap: theme.spacing.xxl, marginTop: theme.spacing.xl }]}>
              <View style={[styles.grow, { rowGap: theme.spacing.xxl }]}>
                <CheckInsCard
                  checkIns={checkIns}
                  caption={checkInsCaption}
                  bars={bars}
                  height={theme.spacing.giant * 2 + theme.spacing.huge}
                />
                <CountsCard counts={counts} />
              </View>
              <View style={styles.grow}>
                <SectionHeader title={PERIOD_SECTION[period]} />
                <ListGroup rows={rows} footer={disclaimer} />
              </View>
            </View>
          ) : (
            <View style={{ marginTop: theme.spacing.xl, rowGap: theme.spacing.m }}>
              <EmptyCard onLogVisit={onLogVisit} />
              <Footnote text={EMPTY_FOOTNOTE} />
            </View>
          )}
        </ScrollView>
      </View>
    );
  }

  // ---- Compact width. ----
  return (
    <ScrollView
      style={{ backgroundColor: parentPageGround(theme) }}
      contentContainerStyle={{
        paddingHorizontal: pageInset,
        paddingBottom: theme.spacing.huge,
        rowGap: theme.spacing.m,
      }}
    >
      <View style={[styles.headerRow, { paddingTop: theme.spacing.xs, columnGap: theme.spacing.m }]}>
        <HopText variant="parentLargeTitle" style={styles.grow}>
          Progress
        </HopText>
        {chip}
      </View>

      {segmented}

      {hasEntries ? (
        <>
          <CheckInsCard
            checkIns={checkIns}
            caption={checkInsCaption}
            bars={bars}
            height={theme.spacing.giant + theme.spacing.xxl}
          />
          <CountsCard counts={counts} />
          <View>
            <SectionHeader title={PERIOD_SECTION[period]} />
            <ListGroup rows={rows} footer={disclaimer} />
          </View>
        </>
      ) : (
        <>
          <EmptyCard onLogVisit={onLogVisit} />
          <Footnote text={EMPTY_FOOTNOTE} />
        </>
      )}
    </ScrollView>
  );
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

/** The child this period belongs to. A chip identifies; it does not report. */
function ChildChip({ name, onPress }: { name: string; onPress?: () => void }): React.ReactElement {
  const theme = useHopTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`Showing ${name}. Switch child`}
      onPress={onPress}
      style={[
        styles.chip,
        {
          columnGap: theme.spacing.s,
          paddingLeft: theme.spacing.xs,
          paddingRight: theme.spacing.m,
          paddingVertical: theme.spacing.xs,
          borderRadius: theme.radius.l,
          backgroundColor: theme.color.surface,
          borderWidth: StyleSheet.hairlineWidth,
          borderColor: theme.color.divider,
        },
      ]}
    >
      <HopFaceDisc size={theme.spacing.xxl} fill={theme.palette.hopGreenSoft} />
      <HopText variant="parentHeadline">{name}</HopText>
    </Pressable>
  );
}

/** A card. The one object on this screen that earns one. */
function Card({
  children,
  style,
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <View
      style={[
        {
          backgroundColor: theme.color.surface,
          borderRadius: theme.radius.l,
          borderWidth: StyleSheet.hairlineWidth,
          borderColor: theme.color.divider,
          padding: theme.spacing.l,
        },
        style,
      ]}
    >
      {children}
    </View>
  );
}

function CheckInsCard({
  checkIns,
  caption,
  bars,
  height,
}: {
  checkIns: number;
  caption: string;
  bars: readonly ProgressBar[];
  height: number;
}): React.ReactElement {
  const theme = useHopTheme();
  return (
    <Card>
      <HopText variant="parentCallout" tone="secondary">
        Potty check-ins
      </HopText>
      <View style={[styles.metricRow, { columnGap: theme.spacing.s }]}>
        <HopText variant="parentLargeTitle">{String(checkIns)}</HopText>
        <HopText variant="parentCallout" tone="secondary" style={styles.shrink}>
          {caption}
        </HopText>
      </View>
      <View style={{ marginTop: theme.spacing.m }}>
        <ColumnChart bars={bars} height={height} />
      </View>
    </Card>
  );
}

/**
 * Daily counts as columns.
 *
 * Seven daily counts are seven discrete facts; a smoothed curve through them
 * invents values between the days and implies a trend the data does not carry.
 */
function ColumnChart({ bars, height }: { bars: readonly ProgressBar[]; height: number }): React.ReactElement {
  const theme = useHopTheme();
  const max = bars.reduce((peak, bar) => Math.max(peak, bar.value), 1);
  const floor = theme.spacing.xs + theme.spacing.xxs;

  return (
    <View accessibilityRole="image" accessibilityLabel={chartLabel(bars)}>
      <View style={[styles.chart, { height, columnGap: theme.spacing.s }]}>
        {bars.map((bar) => (
          <View key={bar.label} style={styles.chartSlot}>
            <View
              style={{
                width: '100%',
                maxWidth: theme.spacing.xxl,
                height: Math.max(floor, Math.round((bar.value / max) * height)),
                borderRadius: theme.radius.xs,
                backgroundColor: bar.value === 0 ? theme.color.divider : theme.color.success,
              }}
            />
          </View>
        ))}
      </View>
      <View style={[styles.chartAxis, { columnGap: theme.spacing.s, marginTop: theme.spacing.xs }]}>
        {bars.map((bar) => (
          <HopText key={bar.label} variant="parentFootnote" tone="secondary" style={styles.axisLabel}>
            {bar.label}
          </HopText>
        ))}
      </View>
    </View>
  );
}

function chartLabel(bars: readonly ProgressBar[]): string {
  return `Potty check-ins by day: ${bars.map((bar) => `${bar.label}, ${bar.value}`).join('; ')}`;
}

/** The period's totals, in the compact row Home uses for the day. */
function CountsCard({ counts }: { counts: ProgressCounts }): React.ReactElement {
  const theme = useHopTheme();
  const cells: readonly { key: string; value: number; label: string; icon: ParentIconName; tint: string }[] = [
    { key: 'checks', value: counts.checks, label: 'Checks', icon: 'check', tint: theme.color.success },
    { key: 'tried', value: counts.tried, label: 'Tried', icon: 'ring', tint: theme.color.eventTried },
    { key: 'pee', value: counts.pee, label: 'Pee', icon: 'drop', tint: theme.color.eventPee },
    { key: 'poop', value: counts.poop, label: 'Poop', icon: 'swirl', tint: theme.color.eventPoop },
  ];
  const g = glyphSizes(theme);

  return (
    <Card style={{ paddingHorizontal: 0, paddingVertical: theme.spacing.m }}>
      <View style={styles.counts}>
        {cells.map((cell, index) => (
          <React.Fragment key={cell.key}>
            {index === 0 ? null : (
              <View style={{ width: StyleSheet.hairlineWidth, backgroundColor: theme.color.divider }} />
            )}
            <View style={[styles.count, { paddingHorizontal: theme.spacing.m, rowGap: theme.spacing.xxs }]}>
              <HopText variant="parentMetric">{String(cell.value)}</HopText>
              <View style={[styles.countLabel, { columnGap: theme.spacing.xs }]}>
                <ParentIcon name={cell.icon} color={cell.tint} size={g.s} />
                <HopText variant="parentCaption" tone="secondary">
                  {cell.label}
                </HopText>
              </View>
            </View>
          </React.Fragment>
        ))}
      </View>
    </Card>
  );
}

/**
 * Day one.
 *
 * Nothing here is phrased as a shortfall: an empty period is a fact about the
 * period, not about the child. This is one of the few places Hop is allowed on
 * a parent surface — a blank Progress screen is exactly where a caregiver needs
 * a friendly reason not to worry, and it is a state they see once.
 */
function EmptyCard({ onLogVisit }: { onLogVisit?: () => void }): React.ReactElement {
  const theme = useHopTheme();
  return (
    <Card style={{ paddingVertical: theme.spacing.xxl }}>
      <View style={styles.centre}>
        <HopCharacter size="medium" state="think" decorative />
        <HopText variant="parentHeadline" style={[styles.centreText, { marginTop: theme.spacing.s }]}>
          {EMPTY_TITLE}
        </HopText>
        <HopText
          variant="parentCallout"
          tone="secondary"
          style={[styles.centreText, { marginTop: theme.spacing.xs }]}
        >
          {EMPTY_BODY}
        </HopText>
      </View>
      <HopButton
        label="Log a visit"
        onPress={onLogVisit}
        style={{ marginTop: theme.spacing.l, alignSelf: 'stretch' }}
      />
    </Card>
  );
}

function Footnote({ text }: { text: string }): React.ReactElement {
  const theme = useHopTheme();
  return (
    <HopText variant="parentCaption" tone="secondary" style={{ paddingHorizontal: theme.spacing.xs }}>
      {text}
    </HopText>
  );
}

const styles = StyleSheet.create({
  grow: { flex: 1 },
  shrink: { flexShrink: 1 },
  split: { flex: 1, flexDirection: 'row' },
  headerRow: { flexDirection: 'row', alignItems: 'center' },
  columns: { flexDirection: 'row', alignItems: 'flex-start' },
  chip: { flexDirection: 'row', alignItems: 'center' },
  metricRow: { flexDirection: 'row', alignItems: 'baseline' },
  chart: { flexDirection: 'row', alignItems: 'flex-end' },
  chartSlot: { flex: 1, alignItems: 'center', justifyContent: 'flex-end' },
  chartAxis: { flexDirection: 'row' },
  axisLabel: { flex: 1, textAlign: 'center' },
  counts: { flexDirection: 'row', alignItems: 'stretch' },
  count: { flex: 1, alignItems: 'flex-start' },
  countLabel: { flexDirection: 'row', alignItems: 'center' },
  centre: { alignItems: 'center' },
  centreText: { textAlign: 'center' },
});
