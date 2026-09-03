import React from 'react';

import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import {
  ListGroup,
  ParentIcon,
  ParentNavBar,
  ParentPage,
  glyphSizes,
  type ParentIconName,
  type ParentListRowProps,
} from '../settings/ParentKit';

/**
 * Quiet times.
 *
 * No render for this one; it is drawn in the house style from
 * `HopPotty/Features/PottyPause/QuietHoursEditor.swift`, which is a grouped
 * list of windows and an add row — the same furniture Potty Pause settings uses.
 *
 * A quiet window is wall-clock, so a window whose end is at or before its start
 * wraps midnight. That is how bedtime is expressed, so the row says so rather
 * than the screen rejecting it as invalid input.
 *
 * Removing a window makes HopPotty *more* likely to interrupt, so it is
 * confirmed rather than swiped away silently — and it is not gated, because
 * nothing is destroyed and nothing about the child is lost.
 */

export type QuietWindowLabel = 'Nap' | 'Bedtime' | 'School' | 'Mealtime' | 'Quiet time';

export interface QuietWindow {
  readonly id: string;
  readonly label: QuietWindowLabel;
  /** "12:30 – 2:30 PM", already formatted for the caregiver's locale. */
  readonly span: string;
  readonly isEnabled: boolean;
  /** True when the window runs past midnight — stated, never corrected. */
  readonly wrapsMidnight: boolean;
}

export interface QuietHoursScreenProps {
  windows: readonly QuietWindow[];
  onBack?: () => void;
  onEditWindow?: (id: string) => void;
  onAddWindow?: () => void;
}

const FOOTER = 'HopPotty stays silent during these. Naps, meals and bedtime are the usual ones.';
const EMPTY = 'No quiet times yet.';
const OVERNIGHT = 'Runs overnight, into the next day.';

const LABEL_ICON: Readonly<Record<QuietWindowLabel, ParentIconName>> = {
  Nap: 'clock',
  Bedtime: 'clock',
  School: 'clock',
  Mealtime: 'clock',
  'Quiet time': 'clock',
};

export function QuietHoursScreen({
  windows,
  onBack,
  onEditWindow,
  onAddWindow,
}: QuietHoursScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const g = glyphSizes(theme);

  const rows: readonly ParentListRowProps[] =
    windows.length === 0
      ? [{ id: 'empty', label: EMPTY, tone: 'secondary' as const }]
      : windows.map((window) => ({
          id: window.id,
          label: window.label,
          sublabel: window.wrapsMidnight ? `${window.span} · ${OVERNIGHT}` : window.span,
          leading: (
            <ParentIcon
              name={LABEL_ICON[window.label]}
              color={window.isEnabled ? theme.color.brandPrimary : theme.color.neutral}
              size={g.m}
            />
          ),
          value: window.isEnabled ? undefined : 'Paused',
          chevron: true,
          onPress: onEditWindow === undefined ? undefined : () => onEditWindow(window.id),
        }));

  return (
    <ParentPage>
      <ParentNavBar title="Quiet times" backLabel="Potty Pause" onBack={onBack} />

      <ListGroup rows={rows} footer={FOOTER} />

      <ListGroup
        rows={[
          {
            id: 'add',
            label: 'Add a quiet time',
            tone: 'brand',
            leading: <ParentIcon name="plus" color={theme.color.brandAction} size={g.m} />,
            onPress: onAddWindow,
          },
        ]}
      />

      <HopText variant="parentCaption" tone="secondary" style={{ paddingHorizontal: theme.spacing.l }}>
        A quiet time is a wall-clock range, so it applies every day at the same hour.
      </HopText>
    </ParentPage>
  );
}
