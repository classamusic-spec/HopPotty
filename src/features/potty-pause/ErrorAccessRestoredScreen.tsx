import React from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { HopButton, HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import type { AuthorizationStatus } from '../../services/screen-time/types';
import {
  ListGroup,
  ParentIcon,
  SecondaryButton,
  glyphSizes,
  softBacking,
  useParentLayout,
  type ParentIconName,
} from '../settings/ParentKit';
import { REVIEW_LABEL } from './screenTimeCopy';

/**
 * Potty Pause needs attention.
 *
 * Reference: `Art/render/screens/39-error-access-restored.png`.
 *
 * Authorization can end without anyone in the family doing anything wrong: a
 * child's account graduating to an adult one, a change in iOS Settings, or
 * another parental-controls app taking over. So this is a reassuring state, not
 * an alarm.
 *
 * Three things it deliberately does not do. Hop is not on it — a smiling frog
 * with a warning badge is the app being cheerful at a caregiver who has just
 * lost a feature; the mark is a plain glyph on a neutral disc, which is what
 * iOS does. The heading and the first line do not contradict each other: the
 * title says permission may have changed, and *what still works* says screen
 * access is back. And the paragraph explaining that iOS can revoke
 * authorization on its own is gone from above the buttons.
 *
 * What stays is the list of three things that are unaffected, because that is
 * the reassurance a caregiver actually needs.
 */

export interface ErrorAccessRestoredScreenProps {
  status: AuthorizationStatus;
  onBack?: () => void;
  onReviewSettings?: () => void;
  onDismiss?: () => void;
}

interface Reason {
  readonly title: string;
  readonly body: string;
  readonly canReviewSettings: boolean;
}

/**
 * What is honest to say in each state.
 *
 * `denied` and `unavailable` take the app's own error copy verbatim so the two
 * platforms cannot promise different things. `unavailable` offers no way into
 * iOS Settings, because on a managed device there is nothing there that helps.
 */
const REASON: Readonly<Record<AuthorizationStatus, Reason>> = {
  approved: {
    title: 'Potty Pause needs attention',
    body: 'Screen Time permission may have changed, so apps are not being paused.',
    canReviewSettings: true,
  },
  notDetermined: {
    title: 'Potty Pause needs attention',
    body: 'Screen Time permission may have changed, so apps are not being paused.',
    canReviewSettings: true,
  },
  denied: {
    title: 'Screen Time permission is off',
    body: 'Potty Pause needs Screen Time permission to pause apps. Reminders keep working without it.',
    canReviewSettings: true,
  },
  unavailable: {
    title: 'Screen Time is unavailable here',
    body: 'This device is managed by someone else, so HopPotty is unable to pause apps on it. Gentle reminders still work.',
    canReviewSettings: false,
  },
};

export function ErrorAccessRestoredScreen({
  status,
  onBack,
  onReviewSettings,
  onDismiss,
}: ErrorAccessRestoredScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const { pageInset, readingWidth, isRegular } = useParentLayout();
  const g = glyphSizes(theme);
  const reason = REASON[status];
  const disc = theme.hitTarget.parentMinimum + theme.spacing.xl;

  const still = (name: ParentIconName, colour: string, text: string) => ({
    id: text,
    label: text,
    labelVariant: 'parentCallout' as const,
    tone: 'secondary' as const,
    align: 'top' as const,
    leading: <ParentIcon name={name} color={colour} size={g.m} />,
  });

  return (
    <View style={[styles.page, { backgroundColor: theme.color.backgroundPrimary }]}>
      <View style={{ paddingHorizontal: pageInset, paddingTop: theme.spacing.s }}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Back"
          onPress={onBack}
          hitSlop={theme.spacing.m}
          style={styles.backRow}
        >
          <ParentIcon name="chevronLeft" color={theme.color.brandAction} size={g.m} />
        </Pressable>
      </View>

      <View
        style={[
          {
            paddingHorizontal: pageInset,
            width: '100%',
            maxWidth: isRegular ? readingWidth : undefined,
            alignSelf: 'center',
          },
        ]}
      >
        <View
          style={[
            styles.centre,
            {
              width: disc,
              height: disc,
              borderRadius: disc / 2,
              alignSelf: 'center',
              backgroundColor: softBacking(theme, theme.palette.sunshineSoft),
            },
          ]}
        >
          <ParentIcon name="warning" color={theme.color.warning} size={theme.spacing.xxxl} />
        </View>

        <HopText
          variant="parentLargeTitle"
          style={[styles.centred, { marginTop: theme.spacing.l }]}
        >
          {reason.title}
        </HopText>
        <HopText
          variant="parentCallout"
          tone="secondary"
          style={[styles.centred, { marginTop: theme.spacing.s }]}
        >
          {reason.body}
        </HopText>

        <ListGroup
          style={{ marginTop: theme.spacing.xxl }}
          header="What still works"
          rows={[
            still(
              'check',
              theme.color.success,
              'Screen access is back. Any pause that was running has ended.',
            ),
            still('bell', theme.color.eventTried, 'Hop still checks in on your schedule.'),
            still('star', theme.color.celebration, 'Stars and pond decorations are untouched.'),
          ]}
        />
      </View>

      <View style={styles.grow} />

      <View
        style={{
          paddingHorizontal: pageInset,
          paddingBottom: theme.spacing.l,
          rowGap: theme.spacing.s,
          width: '100%',
          maxWidth: isRegular ? readingWidth : undefined,
          alignSelf: 'center',
        }}
      >
        {reason.canReviewSettings ? (
          <HopButton label={REVIEW_LABEL} onPress={onReviewSettings} />
        ) : null}
        <SecondaryButton label="Not Now" onPress={onDismiss} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  page: { flex: 1 },
  grow: { flex: 1 },
  centre: { alignItems: 'center', justifyContent: 'center' },
  centred: { textAlign: 'center' },
  backRow: { flexDirection: 'row', alignItems: 'center' },
});
