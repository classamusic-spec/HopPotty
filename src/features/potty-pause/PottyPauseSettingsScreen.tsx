import React from 'react';
import { StyleSheet, View } from 'react-native';

import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import type { AuthorizationStatus } from '../../services/screen-time/types';
import {
  ListGroup,
  ParentIcon,
  ParentNavBar,
  ParentPage,
  glyphSizes,
  softBacking,
} from '../settings/ParentKit';
import { SCREEN_TIME_NOTICE } from './screenTimeCopy';

/**
 * Potty Pause.
 *
 * Reference: `Art/render/screens/04-timer-settings.png`, laid out in
 * `Scripts/screens/settings.js`.
 *
 * Grouped sections in the order the brief gives — Potty Pause · Schedule ·
 * Apps · Test · Safety — because that is what `PottyPauseSettingsView` is: a
 * plain `Form`. The sentence explaining a group lives in that group's footer
 * rather than in a tinted card above it, and Safety is its own section because
 * Restore Screen Access is the one row a caregiver might reach for in a hurry.
 *
 * The screen never claims Screen Time is working. When authorization is
 * anything but `approved` the honest notice sits above the Apps section, and
 * the rows that depend on it say what they can actually do.
 */

export interface PottyPauseSettingsScreenProps {
  /** The child this schedule belongs to. Every child owns their own. */
  childName: string;
  /** "Guided routine" — the mode, named the way a caregiver named it. */
  mode: string;
  /** "45 minutes". */
  interval: string;
  /** "2 minutes", or null when the heads-up is off. */
  warningBeforePause: string | null;
  /** "3 minutes". */
  pauseLength: string;
  /** "12:30 – 2:30 PM". */
  quietHours: string;
  /** "After 7:30 PM". */
  bedtime: string;
  /** "4 apps, 1 category" — counts, because that is all HopPotty may know. */
  appsSummary: string;
  screenTimeStatus: AuthorizationStatus;
  onBack?: () => void;
  onEditMode?: () => void;
  onEditInterval?: () => void;
  onEditWarning?: () => void;
  onEditPauseLength?: () => void;
  onEditQuietHours?: () => void;
  onEditBedtime?: () => void;
  onEditApps?: () => void;
  onTestPause?: () => void;
  onRestoreScreenAccess?: () => void;
  onReviewSystemSettings?: () => void;
}

/**
 * The sentence that used to be a tinted card of its own.
 *
 * It describes the four rows above it, which is precisely what a grouped
 * list's footer is for. The second half is the promise the whole product
 * rests on and is never conditional: a pause ends on its timer, not on a
 * result.
 */
function pauseFooter(childName: string, interval: string, warning: string | null): string {
  const opening =
    warning === null
      ? `Hop invites ${childName} about every ${interval}.`
      : `Hop invites ${childName} about every ${interval}, with a ${warning} heads-up.`;
  return `${opening} A pause always ends when its time is up, whatever happened in the bathroom.`;
}

const SCHEDULE_FOOTER = 'HopPotty stays silent during these.';
const SAFETY_FOOTER = 'Restoring lifts any pause that is running right now.';

export function PottyPauseSettingsScreen({
  childName,
  mode,
  interval,
  warningBeforePause,
  pauseLength,
  quietHours,
  bedtime,
  appsSummary,
  screenTimeStatus,
  onBack,
  onEditMode,
  onEditInterval,
  onEditWarning,
  onEditPauseLength,
  onEditQuietHours,
  onEditBedtime,
  onEditApps,
  onTestPause,
  onRestoreScreenAccess,
  onReviewSystemSettings,
}: PottyPauseSettingsScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const g = glyphSizes(theme);
  const notice = SCREEN_TIME_NOTICE[screenTimeStatus];

  return (
    <ParentPage>
      <ParentNavBar title="Potty Pause" backLabel="Settings" onBack={onBack} />

      <ListGroup
        header="Potty Pause"
        footer={pauseFooter(childName, interval, warningBeforePause)}
        rows={[
          { id: 'mode', label: 'Mode', value: mode, chevron: true, onPress: onEditMode },
          { id: 'every', label: 'Every', value: interval, chevron: true, onPress: onEditInterval },
          {
            id: 'warning',
            label: 'Warning before a pause',
            value: warningBeforePause ?? 'Off',
            chevron: true,
            onPress: onEditWarning,
          },
          {
            id: 'length',
            label: 'Pause length',
            value: pauseLength,
            chevron: true,
            onPress: onEditPauseLength,
          },
        ]}
      />

      <ListGroup
        header="Schedule"
        footer={SCHEDULE_FOOTER}
        rows={[
          {
            id: 'quiet',
            label: 'Quiet hours',
            value: quietHours,
            chevron: true,
            onPress: onEditQuietHours,
          },
          { id: 'bedtime', label: 'Bedtime', value: bedtime, chevron: true, onPress: onEditBedtime },
        ]}
      />

      {notice === null ? null : (
        <View
          style={[
            styles.notice,
            {
              columnGap: theme.spacing.m,
              padding: theme.spacing.m,
              borderRadius: theme.radius.l,
              backgroundColor: softBacking(theme, theme.palette.sunshineSoft),
              borderWidth: StyleSheet.hairlineWidth,
              borderColor: theme.color.divider,
            },
          ]}
        >
          <View style={{ paddingTop: theme.spacing.xxs }}>
            <ParentIcon name="warning" color={theme.color.warning} size={g.m} />
          </View>
          <View style={styles.grow}>
            <HopText variant="parentHeadline">{notice.title}</HopText>
            <HopText variant="parentCaption" tone="secondary" style={{ marginTop: theme.spacing.xxs }}>
              {notice.body}
            </HopText>
          </View>
        </View>
      )}

      <ListGroup
        header="Apps"
        rows={[
          {
            id: 'apps',
            label: 'Apps that pause',
            value: notice === null ? appsSummary : 'Paused apps are off',
            chevron: true,
            onPress: onEditApps,
            accessibilityHint: 'Asks a grown-up first',
          },
        ]}
      />

      <ListGroup
        header="Test"
        rows={[{ id: 'test', label: 'Test Potty Pause', tone: 'brand', onPress: onTestPause }]}
      />

      <ListGroup
        header="Safety"
        footer={SAFETY_FOOTER}
        rows={[
          {
            id: 'restore',
            label: 'Restore Screen Access',
            tone: 'brand',
            onPress: onRestoreScreenAccess,
            accessibilityHint: 'Asks a grown-up first',
          },
          ...(notice !== null && notice.canReviewSettings
            ? [
                {
                  id: 'review',
                  label: 'Review Settings',
                  tone: 'brand' as const,
                  onPress: onReviewSystemSettings,
                },
              ]
            : []),
        ]}
      />
    </ParentPage>
  );
}

const styles = StyleSheet.create({
  grow: { flex: 1 },
  notice: { flexDirection: 'row', alignItems: 'flex-start' },
});
