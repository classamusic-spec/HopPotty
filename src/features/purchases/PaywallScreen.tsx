import React from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';

import { HopButton, HopText } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import {
  HopFaceDisc,
  IconTile,
  ParentIcon,
  SecondaryButton,
  SheetHeader,
  glyphSizes,
  softBacking,
  useParentLayout,
  type ParentIconName,
} from '../settings/ParentKit';

/**
 * HopPotty Family.
 *
 * Reference: `Art/render/screens/36-paywall-family.png`, laid out in
 * `Scripts/screens/parent-extra.js`.
 *
 * One purchase, one price, no pressure. There is no countdown, no expiring
 * discount, no pre-ticked anything and no guilt-worded dismissal — the purchase
 * service has no API for any of them, and this screen has no place to put one.
 * Restore is a full-width control with a plain word on it, beside the buy
 * button rather than hidden under the footer.
 *
 * The price arrives as a string because it is the storefront's, formatted by
 * StoreKit. It is never written down in code, and never converted here.
 *
 * The last line is the one that matters most and it is not marketing: nothing
 * a child earned is behind the purchase, in either version.
 */

export interface PaywallBenefit {
  readonly id: string;
  readonly title: string;
  readonly body: string;
}

export interface PaywallScreenProps {
  /** `Product.displayPrice`, e.g. "$19.99". Never a number, never converted. */
  displayPrice: string;
  /** True while StoreKit has the purchase or the restore in flight. */
  isBusy?: boolean;
  onDismiss?: () => void;
  /** Gated: a grown-up answers first. */
  onPurchase?: () => void;
  /** Gated: a grown-up answers first. */
  onRestore?: () => void;
}

const BENEFITS: readonly (PaywallBenefit & { icon: ParentIconName; tint: 'brand' | 'pond' | 'lavender' | 'sun' })[] = [
  {
    id: 'children',
    icon: 'people',
    tint: 'brand',
    title: 'More than one child',
    body: 'Give each child their own pond, stars and schedule.',
  },
  {
    id: 'pond',
    icon: 'pond',
    tint: 'pond',
    title: 'The whole pond',
    body: 'Every decoration Hop can unlock, across all three ponds.',
  },
  {
    id: 'patterns',
    icon: 'clock',
    tint: 'lavender',
    title: 'Detailed patterns',
    body: 'Longer windows and time-of-day comparisons.',
  },
  {
    id: 'routines',
    icon: 'check',
    tint: 'sun',
    title: 'Custom routines',
    body: 'Choose the steps and how long each one lasts.',
  },
  {
    id: 'export',
    icon: 'export',
    tint: 'pond',
    title: 'Export your data',
    body: 'Take a copy of the timeline with you.',
  },
];

const PROMISES: readonly string[] = [
  'One purchase, not a subscription. The price is the price.',
  'Shared with everyone in your Family Sharing group.',
  'No ads, no analytics, no tracking — in either version.',
];

const FOOTER =
  'The free version keeps one child, the full routine and every reminder. Nothing your child earned is ever behind the purchase.';

export function PaywallScreen({
  displayPrice,
  isBusy = false,
  onDismiss,
  onPurchase,
  onRestore,
}: PaywallScreenProps): React.ReactElement {
  const theme = useHopTheme();
  const { pageInset, readingWidth, isRegular } = useParentLayout();
  const g = glyphSizes(theme);

  const tints: Readonly<Record<'brand' | 'pond' | 'lavender' | 'sun', { ink: string; soft: string }>> = {
    brand: { ink: theme.color.brandAction, soft: theme.palette.hopGreenSoft },
    pond: { ink: theme.color.eventPee, soft: theme.palette.pondBlueSoft },
    lavender: { ink: theme.color.eventTried, soft: theme.palette.lavenderSoft },
    sun: { ink: theme.color.celebration, soft: theme.palette.sunshineSoft },
  };

  const column = {
    width: '100%' as const,
    maxWidth: isRegular ? readingWidth : undefined,
    alignSelf: 'center' as const,
  };

  return (
    <View style={[styles.page, { backgroundColor: theme.color.backgroundPrimary }]}>
      <View style={{ paddingHorizontal: pageInset }}>
        <SheetHeader title="HopPotty Family" onClose={onDismiss} />
      </View>

      <ScrollView
        contentContainerStyle={{
          paddingHorizontal: pageInset,
          paddingTop: theme.spacing.m,
          paddingBottom: theme.spacing.l,
          rowGap: theme.spacing.m,
        }}
      >
        <View style={[column, { rowGap: theme.spacing.m }]}>
          <View
            style={[
              styles.hero,
              {
                columnGap: theme.spacing.l,
                padding: theme.spacing.l,
                borderRadius: theme.radius.xl,
                backgroundColor: softBacking(theme, theme.palette.hopGreenSoft),
              },
            ]}
          >
            <HopFaceDisc
              size={theme.hitTarget.parentMinimum}
              fill={theme.color.surface}
              ring={theme.palette.hopGreenLight}
            />
            <View style={styles.grow}>
              <HopText variant="parentTitle">One purchase.</HopText>
              <HopText variant="parentTitle" tone="brand">
                Every feature, for good.
              </HopText>
            </View>
          </View>

          <View style={{ rowGap: theme.spacing.m }}>
            {BENEFITS.map((benefit) => {
              const tint = tints[benefit.tint];
              return (
                <View key={benefit.id} style={[styles.benefit, { columnGap: theme.spacing.m }]}>
                  <IconTile
                    name={benefit.icon}
                    color={tint.ink}
                    background={softBacking(theme, tint.soft)}
                    size={theme.spacing.xxxl}
                    glyphSize={g.m}
                  />
                  <View style={styles.grow}>
                    <HopText variant="parentHeadline">{benefit.title}</HopText>
                    <HopText
                      variant="parentCaption"
                      tone="secondary"
                      style={{ marginTop: theme.spacing.xxs }}
                    >
                      {benefit.body}
                    </HopText>
                  </View>
                </View>
              );
            })}
          </View>

          <View
            style={{
              padding: theme.spacing.m,
              rowGap: theme.spacing.xs,
              borderRadius: theme.radius.l,
              backgroundColor: theme.color.surfaceSunken,
              borderWidth: StyleSheet.hairlineWidth,
              borderColor: theme.color.divider,
            }}
          >
            {PROMISES.map((promise) => (
              <View key={promise} style={[styles.promise, { columnGap: theme.spacing.s }]}>
                <View style={{ paddingTop: theme.spacing.xxs }}>
                  <ParentIcon name="check" color={theme.color.success} size={g.s} />
                </View>
                <HopText variant="parentCaption" tone="secondary" style={styles.grow}>
                  {promise}
                </HopText>
              </View>
            ))}
          </View>
        </View>
      </ScrollView>

      <View
        style={[
          column,
          {
            paddingHorizontal: pageInset,
            paddingBottom: theme.spacing.l,
            rowGap: theme.spacing.s,
          },
        ]}
      >
        <HopText variant="parentTitle" style={styles.centred}>
          {`${displayPrice} once`}
        </HopText>
        <HopButton label="Unlock HopPotty" onPress={onPurchase} disabled={isBusy} />
        <SecondaryButton label="Restore purchase" onPress={onRestore} />
        <HopText variant="parentCaption" tone="secondary" style={styles.centred}>
          {FOOTER}
        </HopText>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  page: { flex: 1 },
  grow: { flex: 1 },
  centred: { textAlign: 'center' },
  hero: { flexDirection: 'row', alignItems: 'center' },
  benefit: { flexDirection: 'row', alignItems: 'flex-start' },
  promise: { flexDirection: 'row', alignItems: 'flex-start' },
});
