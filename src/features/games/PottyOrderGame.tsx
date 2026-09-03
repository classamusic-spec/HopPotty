import React, { useMemo } from 'react';
import { Pressable, StyleSheet, View, useWindowDimensions } from 'react-native';

import type { HopIllustrationKey } from '../../art/HopArtwork';
import { GameHost } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { HandCard } from './boardTray';
import { GameBoard } from './GameBoard';
import { boardFrame } from './sceneFrame';
import { IconSprite, Sparkle } from './sprites';

/**
 * Potty Order — the order of the routine, rehearsed away from the bathroom
 * where there is all the time in the world to think about it.
 *
 * Reference: `Art/render/screens/28-game-potty-order.png`.
 *
 * The scene already carries the four dashed slots and the arrows between them,
 * so the only sprites here are the cards. A card put in a slot it does not
 * belong in bounces back with the same warm invitation the quizzes use, which
 * is why nothing on this board is ever marked wrong, nothing is counted, and
 * the board stays open for as long as a child wants to rearrange it.
 *
 * The slots are named in words rather than numbers — First, Next, Then, Last —
 * because "spot three of four" is a fact about a list and "then" is a fact
 * about a story.
 */

export type OrderCardId = 'pantsDown' | 'sit' | 'wipe' | 'wash';

export interface PottyOrderCard {
  readonly id: OrderCardId;
  /** The slot it is sitting in, or null while it is still in hand. */
  readonly slot: number | null;
  /** Picked up, on its way down to a slot. */
  readonly lifted?: boolean;
}

export interface PottyOrderGameProps {
  cards?: readonly PottyOrderCard[];
  /** The card the child is holding, if any. */
  held?: OrderCardId | null;
  onPickUp?: (id: OrderCardId) => void;
  onPlace?: (slot: number) => void;
  onDone?: () => void;
  onGrownUp?: () => void;
}

const CARD_ART: Readonly<Record<OrderCardId, HopIllustrationKey>> = {
  pantsDown: 'icon.games.card.pantsDown',
  sit: 'icon.games.card.sit',
  wipe: 'icon.games.card.wipe',
  wash: 'icon.games.card.wash',
};

const CARD_LABEL: Readonly<Record<OrderCardId, string>> = {
  pantsDown: 'Pants down',
  sit: 'Sit on the potty',
  wipe: 'Wipe',
  wash: 'Wash hands',
};

/** What the empty slot for each step is called. Words, never numbers. */
const SLOT_LABEL: readonly string[] = ['First', 'Next', 'Then', 'Last'];

/** The path, in the scene's own coordinates: four slots, evenly spaced. */
const SLOT = { first: 93, step: 146, y: 220, width: 104, height: 124 } as const;
/** How much of `icon.games.card.*` the card itself fills. */
const CARD_FILL = 88 / 120;
/** How far a lifted card floats above its slot. */
const LIFT = 56;

export const POTTY_ORDER_CARDS: readonly PottyOrderCard[] = [
  { id: 'pantsDown', slot: 0 },
  { id: 'sit', slot: 1 },
  { id: 'wipe', slot: 2, lifted: true },
  { id: 'wash', slot: null },
];

const slotAt = (i: number): { x: number; y: number } => ({
  x: SLOT.first + i * SLOT.step,
  y: SLOT.y,
});

export function PottyOrderGame({
  cards = POTTY_ORDER_CARDS,
  held = null,
  onPickUp,
  onPlace,
  onDone,
  onGrownUp,
}: PottyOrderGameProps): React.ReactElement {
  const theme = useHopTheme();
  const { width } = useWindowDimensions();
  const frame = useMemo(() => boardFrame(width), [width]);
  const cardBox = SLOT.width / CARD_FILL;
  const placed = cards.filter((c) => c.slot !== null);

  return (
    <GameHost
      title="Potty Order"
      instruction="Four cards, one path. Which one comes first?"
      caption={placed.length > 0 ? 'That one fits!' : undefined}
      onDone={onDone}
      onGrownUp={onGrownUp}
      board={
        <View style={styles.board} pointerEvents="box-none">
          <View style={styles.bandSlot} pointerEvents="box-none">
            <GameBoard scene="scene.games.pottyOrder" frame={frame}>
              {/* Every slot is a target, so a card can be put down by tapping
                  as well as by dragging. */}
              {SLOT_LABEL.map((name, i) => {
                const at = slotAt(i);
                const taken = cards.some((c) => c.slot === i);
                return (
                  <Pressable
                    key={name}
                    accessibilityRole="button"
                    accessibilityLabel={name}
                    accessibilityState={{ disabled: taken }}
                    disabled={taken || !onPlace}
                    onPress={onPlace ? () => onPlace(i) : undefined}
                    style={{
                      position: 'absolute',
                      left: frame.x(at.x) - frame.len(SLOT.width) / 2,
                      top: frame.y(at.y) - frame.len(SLOT.height) / 2,
                      width: frame.len(SLOT.width),
                      height: frame.len(SLOT.height),
                      borderRadius: theme.radius.m,
                    }}
                  />
                );
              })}

              {placed.map((card) => {
                const at = slotAt(card.slot ?? 0);
                return (
                  <IconSprite
                    key={card.id}
                    artwork={CARD_ART[card.id]}
                    frame={frame}
                    cx={at.x}
                    cy={card.lifted ? at.y - LIFT : at.y}
                    size={cardBox}
                    rotate={card.lifted ? -6 : 0}
                    label={CARD_LABEL[card.id]}
                  />
                );
              })}

              <Sparkle
                frame={frame}
                cx={slotAt(1).x + SLOT.width * 0.52}
                cy={slotAt(1).y - SLOT.height * 0.46}
                radius={13}
                opacity={0.95}
              />
            </GameBoard>
          </View>

          {/* A card that has found its place leaves its outline behind rather
              than vanishing, so the hand never looks emptied. */}
          <View style={[styles.hand, { gap: theme.spacing.l - theme.spacing.xxs }]}>
            {cards
              .filter((card) => card.slot === null || card.lifted === true)
              .map((card) => (
                <HandCard
                  key={card.id}
                  artwork={CARD_ART[card.id]}
                  label={CARD_LABEL[card.id]}
                  placed={card.slot !== null}
                  held={held === card.id}
                  {...(onPickUp ? { onPress: () => onPickUp(card.id) } : null)}
                />
              ))}
          </View>
        </View>
      }
    />
  );
}

const styles = StyleSheet.create({
  board: { flex: 1 },
  bandSlot: { flex: 1, justifyContent: 'center' },
  hand: { flexDirection: 'row', justifyContent: 'center', alignItems: 'center' },
});

export default PottyOrderGame;
