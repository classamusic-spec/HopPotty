import React from 'react';
import { ScrollView, StyleSheet, TextInput, View } from 'react-native';

import { HopButton, HopText } from '../../design-system/components';
import { textStyle, useHopTheme } from '../../design-system/theme';
import {
  ListGroup,
  ParentIcon,
  SecondaryButton,
  SegmentedControl,
  SheetHeader,
  glyphSizes,
  softBacking,
  useParentLayout,
  type ParentIconName,
} from '../settings/ParentKit';

/**
 * Logging a visit by hand.
 *
 * No render for this one; it is drawn in the house style from
 * `HopPotty/Features/ParentHome/LogVisitSheet.swift`.
 *
 * Four kinds, the same size and the same weight. `tried` comes first because it
 * is the primary event and never a lesser one. An accident sits with the others
 * and carries one line of plain explanation rather than a warning colour — a
 * caregiver recording an accident is doing exactly what the app asked them to
 * do, and the entry never touches the child's stars.
 *
 * The timestamp is editable and defaults to now: a parent who noticed twenty
 * minutes late should be able to say so, because the event's time is when it
 * happened, not when it was typed.
 */

export type PottyEventKind = 'tried' | 'pee' | 'poop' | 'accident';

export interface LogVisitSheetProps {
  kind: PottyEventKind;
  /** "2:15 PM", already formatted. The picker itself is the platform's. */
  time: string;
  note: string;
  /** True while the entry is being written. */
  isSaving?: boolean;
  onChangeKind?: (kind: PottyEventKind) => void;
  onPickTime?: () => void;
  onChangeNote?: (note: string) => void;
  onSave?: () => void;
  onCancel?: () => void;
}

const KINDS: readonly { readonly id: PottyEventKind; readonly label: string }[] = [
  { id: 'tried', label: 'Tried' },
  { id: 'pee', label: 'Pee' },
  { id: 'poop', label: 'Poop' },
  { id: 'accident', label: 'Accident' },
];

const KIND_ICON: Readonly<Record<PottyEventKind, ParentIconName>> = {
  tried: 'ring',
  pee: 'drop',
  poop: 'swirl',
  accident: 'warning',
};

const ACCIDENT_FOOTER =
  "Recorded as a neutral fact. Accidents never touch your child's stars, and your child never sees this entry.";
const NOTE_PLACEHOLDER = 'Note for yourself';
const NOTE_FOOTER = 'Private to you. Hop never reads it out and your child never sees it.';

export function LogVisitSheet({
  kind,
  time,
  note,
  isSaving = false,
  onChangeKind,
  onPickTime,
  onChangeNote,
  onSave,
  onCancel,
}: LogVisitSheetProps): React.ReactElement {
  const theme = useHopTheme();
  const { pageInset, readingWidth, isRegular } = useParentLayout();
  const g = glyphSizes(theme);

  // An accident is drawn in the palette's neutral grey, like every other
  // entry. Never a red, never a warning mark, never emphasis.
  const KIND_TINT: Readonly<Record<PottyEventKind, string>> = {
    tried: theme.color.eventTried,
    pee: theme.color.eventPee,
    poop: theme.color.eventPoop,
    accident: theme.color.eventAccident,
  };
  const KIND_SOFT: Readonly<Record<PottyEventKind, string>> = {
    tried: theme.palette.lavenderSoft,
    pee: theme.palette.pondBlueSoft,
    poop: theme.palette.peachSoft,
    accident: theme.palette.sand100,
  };

  const column = {
    width: '100%' as const,
    maxWidth: isRegular ? readingWidth : undefined,
    alignSelf: 'center' as const,
  };

  return (
    <View style={[styles.page, { backgroundColor: theme.color.backgroundPrimary }]}>
      <View style={{ paddingHorizontal: pageInset }}>
        <SheetHeader title="Log a visit" onClose={onCancel} />
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
          <SegmentedControl
            items={KINDS}
            value={kind}
            onChange={onChangeKind}
            accessibilityLabel="What happened"
          />

          {kind === 'accident' ? (
            <HopText
              variant="parentCaption"
              tone="secondary"
              style={{ paddingHorizontal: theme.spacing.l }}
            >
              {ACCIDENT_FOOTER}
            </HopText>
          ) : null}

          <ListGroup
            rows={[
              {
                id: 'time',
                label: 'When it happened',
                value: time,
                chevron: true,
                onPress: onPickTime,
                leading: (
                  <View
                    style={[
                      styles.tile,
                      {
                        width: theme.spacing.xxxl,
                        height: theme.spacing.xxxl,
                        borderRadius: theme.radius.s,
                        backgroundColor: softBacking(theme, KIND_SOFT[kind]),
                      },
                    ]}
                  >
                    <ParentIcon name={KIND_ICON[kind]} color={KIND_TINT[kind]} size={g.s} />
                  </View>
                ),
              },
            ]}
            footer="Defaults to now. Change it if you noticed later than it happened."
          />

          <View>
            <View
              style={{
                borderRadius: theme.radius.l,
                backgroundColor: theme.color.surface,
                borderWidth: StyleSheet.hairlineWidth,
                borderColor: theme.color.divider,
                paddingHorizontal: theme.spacing.l,
                paddingVertical: theme.spacing.m,
              }}
            >
              <TextInput
                accessibilityLabel={NOTE_PLACEHOLDER}
                value={note}
                onChangeText={onChangeNote}
                placeholder={NOTE_PLACEHOLDER}
                placeholderTextColor={theme.color.textTertiary}
                selectionColor={theme.color.brandAction}
                multiline
                style={[
                  textStyle('parentBody'),
                  styles.field,
                  { color: theme.color.textPrimary, minHeight: theme.hitTarget.parentMinimum },
                ]}
              />
            </View>
            <HopText
              variant="parentCaption"
              tone="secondary"
              style={{ paddingHorizontal: theme.spacing.l, paddingTop: theme.spacing.s }}
            >
              {NOTE_FOOTER}
            </HopText>
          </View>
        </View>
      </ScrollView>

      <View
        style={[
          column,
          { paddingHorizontal: pageInset, paddingBottom: theme.spacing.l, rowGap: theme.spacing.s },
        ]}
      >
        <HopButton label="Save" onPress={onSave} disabled={isSaving} />
        <SecondaryButton label="Cancel" onPress={onCancel} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  page: { flex: 1 },
  field: { textAlignVertical: 'top' },
  tile: { alignItems: 'center', justifyContent: 'center' },
});
