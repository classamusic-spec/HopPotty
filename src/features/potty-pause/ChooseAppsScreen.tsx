import React from 'react';
import { StyleSheet, View } from 'react-native';

import { HopButton, HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import type { AuthorizationStatus, SelectionSummary } from '../../services/screen-time/types';
import {
  IconTile,
  ParentNavBar,
  ParentPage,
  SecondaryButton,
  softBacking,
} from '../settings/ParentKit';
import {
  CHOOSE_LABEL,
  GRANT_LABEL,
  NO_SELECTION_BODY,
  NO_SELECTION_TITLE,
  REVIEW_LABEL,
  SCREEN_TIME_NOTICE,
} from './screenTimeCopy';

/**
 * Apps that pause.
 *
 * Reference: `Art/render/screens/05-choose-apps.png`, laid out in
 * `Scripts/screens/settings.js`.
 *
 * ## Why this screen does not list apps
 *
 * Apple hands a selection over as opaque tokens. HopPotty cannot read a name,
 * an icon, or what an app is, so `SelectionSummary` holds counts and nothing
 * else. A list of app names with switches would be unbuildable, and it would
 * contradict the privacy promise printed on this very screen.
 *
 * So this screen shows exactly what HopPotty holds — how many apps, how many
 * categories, how many websites — and hands the choosing to Apple's
 * `FamilyActivityPicker`. That picker is a system view: it is presented, never
 * reimplemented, and `onChooseApps` is where the seam is. The render draws the
 * picker in system chrome on purpose; the seam between our design and Apple's
 * is real and a designer should see it.
 */

export interface ChooseAppsScreenProps {
  selection: SelectionSummary;
  status: AuthorizationStatus;
  onBack?: () => void;
  /** Presents Apple's picker. Gated: a grown-up answers first. */
  onChooseApps?: () => void;
  /** Asks iOS for Family Controls authorization. Gated. */
  onRequestAuthorization?: () => void;
  onReviewSystemSettings?: () => void;
}

const PRIVACY_TITLE = 'HopPotty never learns which apps';
const PRIVACY_BODY =
  'It can pause the ones you pick, and nothing else. It cannot read their names or see inside them.';

export function ChooseAppsScreen({
  selection,
  status,
  onBack,
  onChooseApps,
  onRequestAuthorization,
  onReviewSystemSettings,
}: ChooseAppsScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const notice = SCREEN_TIME_NOTICE[status];

  return (
    <ParentPage>
      <ParentNavBar title="Apps that pause" backLabel="Settings" onBack={onBack} />

      <View
        style={{
          backgroundColor: theme.color.surface,
          borderRadius: theme.radius.l,
          borderWidth: StyleSheet.hairlineWidth,
          borderColor: theme.color.divider,
          padding: theme.spacing.l,
        }}
      >
        <HopText variant="parentHeadline">
          {selection.isEmpty ? NO_SELECTION_TITLE : summarySentence(selection)}
        </HopText>
        {selection.isEmpty ? (
          <HopText variant="parentCaption" tone="secondary" style={{ marginTop: theme.spacing.xs }}>
            {NO_SELECTION_BODY}
          </HopText>
        ) : null}

        <View style={[styles.tiles, { marginTop: theme.spacing.m }]}>
          <CountTile value={selection.applicationCount} label={plural(selection.applicationCount, 'App', 'Apps')} />
          <Rule />
          <CountTile value={selection.categoryCount} label={plural(selection.categoryCount, 'Category', 'Categories')} />
          <Rule />
          <CountTile value={selection.webDomainCount} label={plural(selection.webDomainCount, 'Website', 'Websites')} />
        </View>
      </View>

      <View
        style={[
          styles.promise,
          {
            columnGap: theme.spacing.m,
            padding: theme.spacing.m,
            borderRadius: theme.radius.l,
            backgroundColor: theme.color.surface,
            borderWidth: StyleSheet.hairlineWidth,
            borderColor: theme.color.divider,
          },
        ]}
      >
        <IconTile
          name="lock"
          color={theme.color.eventPee}
          background={softBacking(theme, theme.palette.pondBlueSoft)}
          size={theme.spacing.xxxl}
        />
        <View style={styles.grow}>
          <HopText variant="parentHeadline">{PRIVACY_TITLE}</HopText>
          <HopText variant="parentCaption" tone="secondary" style={{ marginTop: theme.spacing.xxs }}>
            {PRIVACY_BODY}
          </HopText>
        </View>
      </View>

      {notice === null ? null : (
        <View style={{ rowGap: theme.spacing.xxs, paddingHorizontal: theme.spacing.xs }}>
          <HopText variant="parentHeadline">{notice.title}</HopText>
          <HopText variant="parentCaption" tone="secondary">
            {notice.body}
          </HopText>
        </View>
      )}

      {notice === null ? (
        <HopButton label={CHOOSE_LABEL} onPress={onChooseApps} />
      ) : status === 'notDetermined' ? (
        <HopButton label={GRANT_LABEL} onPress={onRequestAuthorization} />
      ) : notice.canReviewSettings ? (
        <SecondaryButton label={REVIEW_LABEL} onPress={onReviewSystemSettings} />
      ) : null}
    </ParentPage>
  );
}

/** "4 apps and 1 category will pause". Counts only — never a name. */
function summarySentence(selection: SelectionSummary): string {
  const parts: string[] = [];
  if (selection.applicationCount > 0) {
    parts.push(`${selection.applicationCount} ${plural(selection.applicationCount, 'app', 'apps')}`);
  }
  if (selection.categoryCount > 0) {
    parts.push(
      `${selection.categoryCount} ${plural(selection.categoryCount, 'category', 'categories')}`,
    );
  }
  if (selection.webDomainCount > 0) {
    parts.push(
      `${selection.webDomainCount} ${plural(selection.webDomainCount, 'website', 'websites')}`,
    );
  }
  return `${listOf(parts)} will pause`;
}

function listOf(parts: readonly string[]): string {
  if (parts.length <= 1) return parts.join('');
  return `${parts.slice(0, -1).join(', ')} and ${parts[parts.length - 1] ?? ''}`;
}

function plural(count: number, one: string, many: string): string {
  return count === 1 ? one : many;
}

function CountTile({ value, label }: { value: number; label: string }): React.ReactElement {
  return (
    <View style={styles.tileCell}>
      <HopText variant="metric">{String(value)}</HopText>
      <HopText variant="parentCaption" tone="secondary">
        {label}
      </HopText>
    </View>
  );
}

function Rule(): React.ReactElement {
  const theme = useHopTheme();
  return <View style={{ width: StyleSheet.hairlineWidth, backgroundColor: theme.color.divider }} />;
}

const styles = StyleSheet.create({
  grow: { flex: 1 },
  tiles: { flexDirection: 'row', alignItems: 'stretch' },
  tileCell: { flex: 1, alignItems: 'center' },
  promise: { flexDirection: 'row', alignItems: 'flex-start' },
});
