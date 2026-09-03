import React, { useState } from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';

import { HopText } from '../design-system/components';
import { useHopTheme } from '../design-system/theme';
import { appearances, palette, typography } from '../design-system/tokens.generated';
import { HopCharacter } from '../mascot/HopCharacter';
import { HOP_POSES } from '../mascot/poses.generated';
import { ParentHomeScreen } from '../features/parent-home/ParentHomeScreen';

/**
 * The React Native application shell.
 *
 * Deliberately small. Navigation lands with Phase 4, when the parent tab
 * structure is ported; until then this switches between the surfaces that
 * exist so they can be reviewed. Nothing here is the eventual router.
 */

type Tab = 'home' | 'mascot' | 'tokens';

const TABS: readonly { id: Tab; label: string }[] = [
  { id: 'home', label: 'Parent Home' },
  { id: 'mascot', label: 'Hop' },
  { id: 'tokens', label: 'Tokens' },
];

export function App(): React.ReactElement {
  const theme = useHopTheme();
  const [tab, setTab] = useState<Tab>('home');

  return (
    <View style={[styles.root, { backgroundColor: theme.color.backgroundPrimary }]}>
      <View style={styles.body}>
        {tab === 'home' ? <HomeTab /> : tab === 'mascot' ? <MascotTab /> : <TokensTab />}
      </View>

      <View
        style={[
          styles.tabBar,
          { backgroundColor: theme.color.surface, borderTopColor: theme.color.divider },
        ]}
      >
        {TABS.map((t) => (
          <View
            key={t.id}
            accessibilityRole="tab"
            accessibilityState={{ selected: tab === t.id }}
            onTouchEnd={() => setTab(t.id)}
            style={styles.tab}
          >
            <HopText variant="parentFootnote" tone={tab === t.id ? 'brand' : 'secondary'}>
              {t.label}
            </HopText>
          </View>
        ))}
      </View>
    </View>
  );
}

function HomeTab(): React.ReactElement {
  return (
    <ParentHomeScreen
      childName="Maya"
      stars={13}
      nextPauseInSeconds={28 * 60 + 14}
      counts={{ checks: 9, tried: 5, pee: 3, poop: 1 }}
      entries={[
        { id: '1', time: '1:42 PM', kind: 'Pee' },
        { id: '2', time: '12:54 PM', kind: 'Tried' },
        { id: '3', time: '11:58 AM', kind: 'Poop' },
      ]}
    />
  );
}

/** Every pose the rig draws, so a regression is visible rather than reported. */
function MascotTab(): React.ReactElement {
  const theme = useHopTheme();
  const poses = Object.keys(HOP_POSES) as (keyof typeof HOP_POSES)[];
  return (
    <ScrollView contentContainerStyle={{ padding: theme.spacing.l }}>
      <HopText variant="parentTitle">Hop</HopText>
      <HopText variant="parentCallout" tone="secondary" style={{ marginBottom: theme.spacing.l }}>
        {poses.length} poses, generated from the art rig and verified element for element against
        it. Blinking is a pose swap; the pupils follow a gaze target.
      </HopText>
      <View style={styles.grid}>
        {poses.map((pose) => (
          <View key={pose} style={styles.poseCell}>
            <View style={[styles.poseArt, { backgroundColor: theme.color.surface }]}>
              <HopCharacter size={128} pose={pose} decorative />
            </View>
            <HopText variant="parentFootnote" tone="secondary">
              {pose}
            </HopText>
          </View>
        ))}
      </View>
    </ScrollView>
  );
}

/** The generated design system, shown so drift would be obvious. */
function TokensTab(): React.ReactElement {
  const theme = useHopTheme();
  const semantic = Object.entries(appearances[theme.appearance]);
  const brand = Object.entries(palette);
  const styles2 = Object.keys(typography) as (keyof typeof typography)[];

  return (
    <ScrollView contentContainerStyle={{ padding: theme.spacing.l }}>
      <HopText variant="parentTitle">Design tokens</HopText>
      <HopText variant="parentCallout" tone="secondary" style={{ marginBottom: theme.spacing.l }}>
        Generated from the app&apos;s Swift design tokens. Nothing here is written by hand.
      </HopText>

      <HopText variant="parentHeadline">Semantic — {theme.appearance}</HopText>
      <View style={[styles.swatches, { marginBottom: theme.spacing.xl }]}>
        {semantic.map(([name, value]) => (
          <Swatch key={name} name={name} value={value} />
        ))}
      </View>

      <HopText variant="parentHeadline">Palette</HopText>
      <View style={[styles.swatches, { marginBottom: theme.spacing.xl }]}>
        {brand.map(([name, value]) => (
          <Swatch key={name} name={name} value={value} />
        ))}
      </View>

      <HopText variant="parentHeadline">Type scale</HopText>
      {styles2.map((name) => (
        <View key={name} style={{ marginTop: theme.spacing.m }}>
          <HopText variant="parentFootnote" tone="tertiary">
            {name} · {typography[name].size}pt
          </HopText>
          <HopText variant={name}>Pause. Potty. Play.</HopText>
        </View>
      ))}
    </ScrollView>
  );
}

function Swatch({ name, value }: { name: string; value: string }): React.ReactElement {
  return (
    <View style={styles.swatch}>
      <View style={[styles.swatchChip, { backgroundColor: value }]} />
      <HopText variant="parentFootnote" tone="secondary" numberOfLines={1}>
        {name}
      </HopText>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  body: { flex: 1 },
  tabBar: { flexDirection: 'row', borderTopWidth: StyleSheet.hairlineWidth, paddingVertical: 10 },
  tab: { flex: 1, alignItems: 'center', paddingVertical: 6 },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12 },
  poseCell: { alignItems: 'center', width: 140 },
  poseArt: { borderRadius: 20, padding: 6, marginBottom: 4 },
  swatches: { flexDirection: 'row', flexWrap: 'wrap', gap: 10, marginTop: 8 },
  swatch: { width: 92 },
  swatchChip: { height: 44, borderRadius: 10, marginBottom: 4 },
});

export default App;
