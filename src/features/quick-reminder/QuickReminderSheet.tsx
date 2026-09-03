import React from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';

import { HopButton, HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import {
  ChoiceChip,
  HopFaceDisc,
  ListGroup,
  ParentIcon,
  SheetHeader,
  glyphSizes,
  softBacking,
  useParentLayout,
} from '../settings/ParentKit';

/**
 * A quick reminder.
 *
 * Reference: `Art/render/screens/41-quick-reminder-sheet.png`, laid out in
 * `Scripts/screens/parent-extra.js`.
 *
 * One timer, once. A quick reminder never shields an app, never repeats, never
 * snoozes and never touches the schedule — the sheet says so under its own
 * title, because that sentence is the whole difference between this and a Potty
 * Pause. When the schedule already has a pause near the chosen time the sheet
 * mentions it, advisory only: nothing here is allowed to move a pause or refuse
 * a reminder.
 *
 * The reason chips are optional by construction. The heading says so, and no
 * chip is selected by default in a fresh sheet.
 */

export type ReminderPreset = 'minutes15' | 'minutes30' | 'minutes60' | 'pickATime';

export interface ReminderReason {
  readonly id: string;
  readonly label: string;
}

export interface QuickReminderSheetProps {
  /** Which chip is lit, or null when the caregiver picked a time by hand. */
  preset: ReminderPreset | null;
  /** "2:15 PM" — already formatted for the caregiver's locale. */
  time: string;
  childName: string;
  /** The disc behind the child's face. */
  childTint: string;
  reasons: readonly ReminderReason[];
  selectedReasonId: string | null;
  /** "A Potty Pause is already coming at about 2:20 PM." Advisory, never a bar. */
  scheduleNote?: string;
  onDismiss?: () => void;
  onSelectPreset?: (preset: ReminderPreset) => void;
  onPickTime?: () => void;
  onSelectChild?: () => void;
  onSelectReason?: (id: string | null) => void;
  onSetReminder?: () => void;
}

const SUBTITLE = 'One reminder, once. Nothing is paused and your schedule is untouched.';
const REASON_HEADING = 'WHY, IF YOU LIKE';

const PRESETS: readonly { readonly id: ReminderPreset; readonly label: string }[] = [
  { id: 'minutes15', label: 'In 15 minutes' },
  { id: 'minutes30', label: 'In 30 minutes' },
  { id: 'minutes60', label: 'In 1 hour' },
  { id: 'pickATime', label: 'Pick a time' },
];

export function QuickReminderSheet({
  preset,
  time,
  childName,
  childTint,
  reasons,
  selectedReasonId,
  scheduleNote,
  onDismiss,
  onSelectPreset,
  onPickTime,
  onSelectChild,
  onSelectReason,
  onSetReminder,
}: QuickReminderSheetProps): React.ReactElement {
  const theme = useHopTheme();
  const { pageInset, readingWidth, isRegular } = useParentLayout();
  const g = glyphSizes(theme);

  const column = {
    width: '100%' as const,
    maxWidth: isRegular ? readingWidth : undefined,
    alignSelf: 'center' as const,
  };

  const reasonTint = {
    fill: softBacking(theme, theme.palette.pondBlueSoft),
    border: theme.color.eventPee,
    text: theme.color.textPrimary,
  };

  return (
    <View style={[styles.page, { backgroundColor: theme.color.backgroundPrimary }]}>
      <View style={{ paddingHorizontal: pageInset }}>
        <SheetHeader title="Quick reminder" subtitle={SUBTITLE} onClose={onDismiss} />
      </View>

      <ScrollView
        contentContainerStyle={{
          paddingHorizontal: pageInset,
          paddingTop: theme.spacing.l,
          paddingBottom: theme.spacing.l,
          rowGap: theme.spacing.m,
        }}
      >
        <View style={[column, { rowGap: theme.spacing.m }]}>
          <View style={[styles.chipGrid, { columnGap: theme.spacing.s, rowGap: theme.spacing.s }]}>
            {PRESETS.map((option) => (
              <ChoiceChip
                key={option.id}
                label={option.label}
                selected={option.id === preset}
                style={styles.chip}
                onPress={() =>
                  option.id === 'pickATime' ? onPickTime?.() : onSelectPreset?.(option.id)
                }
              />
            ))}
          </View>

          <ListGroup
            rows={[
              {
                id: 'time',
                label: 'Remind me at',
                leading: (
                  <View
                    style={[
                      styles.tile,
                      {
                        width: theme.spacing.xxxl,
                        height: theme.spacing.xxxl,
                        borderRadius: theme.radius.s,
                        backgroundColor: softBacking(theme, theme.palette.hopGreenSoft),
                      },
                    ]}
                  >
                    <ParentIcon name="clock" color={theme.color.brandAction} size={g.s} />
                  </View>
                ),
                onPress: onPickTime,
                accessory: (
                  <View
                    style={{
                      paddingHorizontal: theme.spacing.m,
                      paddingVertical: theme.spacing.xs,
                      borderRadius: theme.radius.s,
                      backgroundColor: theme.color.surfaceSunken,
                    }}
                  >
                    <HopText variant="parentBody">{time}</HopText>
                  </View>
                ),
              },
              {
                id: 'child',
                label: 'For',
                value: childName,
                leading: <HopFaceDisc size={theme.spacing.xxxl} fill={childTint} />,
                chevron: true,
                onPress: onSelectChild,
              },
            ]}
          />

          <View>
            <HopText variant="parentFootnote" tone="secondary" style={styles.eyebrow}>
              {REASON_HEADING}
            </HopText>
            <View
              style={[
                styles.chipRow,
                { columnGap: theme.spacing.s, rowGap: theme.spacing.s, marginTop: theme.spacing.s },
              ]}
            >
              {reasons.map((reason) => {
                const on = reason.id === selectedReasonId;
                return (
                  <ChoiceChip
                    key={reason.id}
                    label={reason.label}
                    selected={on}
                    tint={reasonTint}
                    style={styles.reasonChip}
                    onPress={() => onSelectReason?.(on ? null : reason.id)}
                  />
                );
              })}
            </View>
          </View>

          {scheduleNote === undefined ? null : (
            <View style={[styles.note, { columnGap: theme.spacing.m, paddingHorizontal: theme.spacing.xs }]}>
              <View style={{ paddingTop: theme.spacing.xxs }}>
                <ParentIcon name="bell" color={theme.color.textSecondary} size={g.s} />
              </View>
              <HopText variant="parentCaption" tone="secondary" style={styles.grow}>
                {scheduleNote}
              </HopText>
            </View>
          )}
        </View>
      </ScrollView>

      <View
        style={[column, { paddingHorizontal: pageInset, paddingBottom: theme.spacing.l }]}
      >
        <HopButton label="Set reminder" onPress={onSetReminder} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  page: { flex: 1 },
  grow: { flex: 1 },
  chipGrid: { flexDirection: 'row', flexWrap: 'wrap' },
  chip: { flexBasis: '47%', flexGrow: 1 },
  chipRow: { flexDirection: 'row', flexWrap: 'wrap' },
  reasonChip: { flexGrow: 1, flexShrink: 1 },
  eyebrow: { textTransform: 'uppercase', letterSpacing: 0.5 },
  note: { flexDirection: 'row', alignItems: 'flex-start' },
  tile: { alignItems: 'center', justifyContent: 'center' },
});
