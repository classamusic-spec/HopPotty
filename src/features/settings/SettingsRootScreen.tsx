import React from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';

import { HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import {
  HopFaceDisc,
  ListGroup,
  ParentIcon,
  ParentSidebar,
  ParentToggle,
  destructiveTint,
  glyphSizes,
  parentPageGround,
  useParentLayout,
  type ParentIconName,
  type ParentListRowProps,
  type ParentSection,
} from './ParentKit';

/**
 * Settings.
 *
 * Reference: `Art/render/screens/34-settings-hub.png`, laid out in
 * `Scripts/screens/parent-extra.js`.
 *
 * A plain grouped list, because that is what `SettingsRootView` is in the app
 * and because a caregiver already knows how to read one. The rounded coloured
 * tiles a settings screen tends to grow are deliberately absent: the mark is
 * the symbol itself at brand ink, and the only colour on the screen belongs to
 * the child avatars — those identify a person rather than label a setting.
 *
 * Everything a grown-up gate guards leaves through a callback. There is no
 * route from here to a purchase, a deletion, an export or the Screen Time
 * settings that does not pass through the gate the navigator wraps around it.
 */

export interface SettingsChildSummary {
  readonly id: string;
  readonly name: string;
  /** "Currently shown" on the child the app is displaying, else absent. */
  readonly sublabel?: string;
  /** The disc behind the face. A palette tint, chosen at profile creation. */
  readonly tint: string;
}

export interface SettingsRootScreenProps {
  childProfiles: readonly SettingsChildSummary[];
  /** "Guided routine" — the mode, in the caregiver's words. */
  pauseMode: string;
  /** "4 apps, 1 category" — counts, because that is all HopPotty may know. */
  appsSummary: string;
  warningBeforePause: boolean;
  /** Marketing version and build, e.g. "1.0 (12)". */
  version: string;
  onSelectChild?: (id: string) => void;
  onAddChild?: () => void;
  onOpenPottyPause?: () => void;
  onOpenApps?: () => void;
  onChangeWarningBeforePause?: (next: boolean) => void;
  onOpenFamily?: () => void;
  onExportData?: () => void;
  onDeleteEverything?: () => void;
  onSelectSection?: (section: ParentSection) => void;
}

const PAUSE_FOOTER = 'The pause ends when this time is up, whatever happened in the bathroom.';
const FAMILY_FOOTER =
  'The free version keeps one child, the full routine and every reminder. Nothing your child earned is ever behind the purchase.';

export function SettingsRootScreen({
  childProfiles,
  pauseMode,
  appsSummary,
  warningBeforePause,
  version,
  onSelectChild,
  onAddChild,
  onOpenPottyPause,
  onOpenApps,
  onChangeWarningBeforePause,
  onOpenFamily,
  onExportData,
  onDeleteEverything,
  onSelectSection,
}: SettingsRootScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const { isRegular, pageInset, readingWidth } = useParentLayout();
  const g = glyphSizes(theme);

  const mark = (name: ParentIconName, colour?: string): React.ReactElement => (
    <ParentIcon name={name} color={colour ?? theme.color.brandAction} size={g.m} />
  );

  const childRows: readonly ParentListRowProps[] = [
    ...childProfiles.map((child) => ({
      id: child.id,
      label: child.name,
      sublabel: child.sublabel,
      leading: <HopFaceDisc size={theme.spacing.xxxl} fill={child.tint} />,
      chevron: true,
      onPress: onSelectChild === undefined ? undefined : () => onSelectChild(child.id),
      accessibilityHint: 'Opens this child’s profile',
    })),
    {
      id: 'add-child',
      label: 'Add a child',
      tone: 'brand' as const,
      leading: mark('plus'),
      onPress: onAddChild,
    },
  ];

  const body = (
    <>
      <HopText variant="parentLargeTitle" style={{ paddingBottom: theme.spacing.xs }}>
        Settings
      </HopText>

      <ListGroup header="Children" rows={childRows} />

      <ListGroup
        footer={PAUSE_FOOTER}
        rows={[
          {
            id: 'potty-pause',
            label: 'Potty Pause',
            value: pauseMode,
            leading: mark('clock'),
            chevron: true,
            onPress: onOpenPottyPause,
          },
          {
            id: 'apps',
            label: 'Apps that pause',
            value: appsSummary,
            leading: mark('apps'),
            chevron: true,
            onPress: onOpenApps,
            accessibilityHint: 'Asks a grown-up first',
          },
          {
            id: 'warning',
            label: 'Warning before a pause',
            leading: mark('bell'),
            accessory: (
              <ParentToggle
                value={warningBeforePause}
                onValueChange={onChangeWarningBeforePause}
                label="Warning before a pause"
              />
            ),
          },
        ]}
      />

      <ListGroup
        footer={FAMILY_FOOTER}
        rows={[
          {
            id: 'family',
            label: 'HopPotty Family',
            leading: mark('star'),
            chevron: true,
            onPress: onOpenFamily,
          },
        ]}
      />

      <ListGroup
        rows={[
          {
            id: 'export',
            label: 'Export my data',
            leading: mark('export'),
            chevron: true,
            onPress: onExportData,
            accessibilityHint: 'Asks a grown-up first',
          },
          {
            id: 'delete',
            label: 'Delete everything',
            tone: 'destructive' as const,
            leading: mark('trash', destructiveTint(theme)),
            onPress: onDeleteEverything,
            accessibilityHint: 'Asks a grown-up first',
          },
        ]}
      />

      <HopText
        variant="parentCaption"
        tone="secondary"
        style={[styles.version, { paddingTop: theme.spacing.l }]}
      >
        {`Version ${version}`}
      </HopText>
    </>
  );

  const page = (
    <ScrollView
      style={{ backgroundColor: parentPageGround(theme) }}
      contentContainerStyle={{
        paddingHorizontal: pageInset,
        paddingBottom: theme.spacing.huge,
        rowGap: theme.spacing.m,
      }}
    >
      <View
        style={{
          rowGap: theme.spacing.m,
          width: '100%',
          maxWidth: isRegular ? readingWidth : undefined,
          alignSelf: 'center',
        }}
      >
        {body}
      </View>
    </ScrollView>
  );

  if (!isRegular) return page;

  return (
    <View style={[styles.split, { backgroundColor: parentPageGround(theme) }]}>
      <ParentSidebar
        active="Settings"
        childName={childProfiles[0]?.name ?? ''}
        onSelect={onSelectSection}
        onSwitchChild={
          onSelectChild === undefined || childProfiles[0] === undefined
            ? undefined
            : () => onSelectChild(childProfiles[0]?.id ?? '')
        }
      />
      <View style={styles.grow}>{page}</View>
    </View>
  );
}

const styles = StyleSheet.create({
  grow: { flex: 1 },
  split: { flex: 1, flexDirection: 'row' },
  version: { textAlign: 'center' },
});
