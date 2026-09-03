import React from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';

import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import {
  IconTile,
  ParentIcon,
  SecondaryButton,
  SheetHeader,
  glyphSizes,
  useParentLayout,
} from './ParentKit';

/**
 * Deleting a child's data.
 *
 * Reference: `Art/render/screens/38-delete-data-confirm.png`.
 *
 * The counts are read at the moment the sheet opens and they are the whole
 * point: a caregiver approves a number, not a vibe. Three lines, each naming
 * one kind of thing and how many of it there are; then the sentence that
 * cannot be softened; then the reason there is no undo — none of this was ever
 * anywhere but this device.
 *
 * Cancel is the same width and the same weight as Delete. The screen presents
 * the choice; the grown-up gate the navigator wraps around `onDelete` is what
 * decides a grown-up made it.
 */

export interface DeleteDataCounts {
  readonly events: number;
  readonly stars: number;
  readonly decorations: number;
}

export interface DeleteDataScreenProps {
  childName: string;
  counts: DeleteDataCounts;
  onDelete?: () => void;
  onCancel?: () => void;
}

const LOCAL_ONLY =
  'Every event, star and note lives on your device. Deleting removes it here, right away, and there is no copy anywhere else.';

export function DeleteDataScreen({
  childName,
  counts,
  onDelete,
  onCancel,
}: DeleteDataScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const { pageInset, readingWidth, isRegular } = useParentLayout();
  const g = glyphSizes(theme);

  const lines: readonly string[] = [
    `${counts.events} logged potty events will be removed.`,
    `${counts.stars} earned stars will be removed.`,
    `${counts.decorations} pond decorations will be removed.`,
  ];

  return (
    <View style={[styles.sheet, { backgroundColor: theme.color.backgroundPrimary }]}>
      <View style={{ paddingHorizontal: pageInset }}>
        <SheetHeader title={`Delete ${childName}'s data?`} />
      </View>

      <ScrollView
        contentContainerStyle={{
          paddingHorizontal: pageInset,
          paddingTop: theme.spacing.m,
          paddingBottom: theme.spacing.l,
          rowGap: theme.spacing.m,
        }}
      >
        <View
          style={{
            width: '100%',
            maxWidth: isRegular ? readingWidth : undefined,
            alignSelf: 'center',
            rowGap: theme.spacing.m,
          }}
        >
          <View accessibilityRole="list" style={{ rowGap: theme.spacing.xs }}>
            {lines.map((line) => (
              <View key={line} style={[styles.line, { columnGap: theme.spacing.m }]}>
                <View style={{ paddingTop: theme.spacing.xxs }}>
                  <ParentIcon name="minus" color={theme.color.textSecondary} size={g.m} />
                </View>
                <HopText variant="parentBody" tone="secondary" style={styles.grow}>
                  {line}
                </HopText>
              </View>
            ))}
          </View>

          <HopText variant="parentHeadline">This cannot be undone.</HopText>

          <View
            style={[
              styles.note,
              {
                columnGap: theme.spacing.m,
                padding: theme.spacing.m,
                borderRadius: theme.radius.l,
                backgroundColor: theme.color.surfaceSunken,
                borderWidth: StyleSheet.hairlineWidth,
                borderColor: theme.color.divider,
              },
            ]}
          >
            <IconTile
              name="lock"
              color={theme.color.textSecondary}
              background={theme.color.surface}
              size={theme.spacing.xxl}
            />
            <HopText variant="parentCaption" tone="secondary" style={styles.grow}>
              {LOCAL_ONLY}
            </HopText>
          </View>
        </View>
      </ScrollView>

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
        <SecondaryButton label="Delete" tone="destructive" onPress={onDelete} />
        <SecondaryButton label="Cancel" onPress={onCancel} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  sheet: { flex: 1 },
  grow: { flex: 1 },
  line: { flexDirection: 'row', alignItems: 'flex-start' },
  note: { flexDirection: 'row', alignItems: 'flex-start' },
});
