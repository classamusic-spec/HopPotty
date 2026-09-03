import React from 'react';
import { StyleSheet, View } from 'react-native';

import type { HopIllustrationKey } from '../../art/HopArtwork';
import { GameHost } from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { MatchTile, type TileState } from './boardTray';
import { GameBoard } from './GameBoard';
import { useBoardFrame } from './useBoardFrame';
import { HopSprite } from './sprites';

/**
 * Bathroom Match — the calm one, and the only game with no ending of its own.
 *
 * Reference: `Art/render/screens/23-game-bathroom-match.png`.
 *
 * The shelf reshuffles as long as a child wants it to, so "All done" is the
 * only way this round finishes and it is on screen from the first frame. A tile
 * that has found its pair is marked with a tick as well as a border, and a tile
 * still face down is drawn as an open outline rather than as a gap — nothing on
 * this board is ever wrong and nothing is ever lost.
 */

export interface BathroomMatchTile {
  readonly id: string;
  readonly artwork: HopIllustrationKey;
  readonly label: string;
  readonly state: TileState;
  /** The one the nudge is pointing at. A pulse, never a countdown. */
  readonly hinted?: boolean;
}

export interface BathroomMatchGameProps {
  tiles?: readonly BathroomMatchTile[];
  onTapTile?: (id: string) => void;
  onDone?: () => void;
  onGrownUp?: () => void;
}

/** Hop, watching from beside the bath mat. */
const HOP = { cx: 470, groundY: 430, size: 221 } as const;
const ROW = 3;

/** The shelf the render draws: one pair found, one card waiting to be turned. */
export const BATHROOM_MATCH_TILES: readonly BathroomMatchTile[] = [
  { id: 'soap-a', artwork: 'icon.quiz.soap', label: 'Soap', state: 'matched' },
  { id: 'towel', artwork: 'icon.quiz.towel', label: 'Towel', state: 'faceUp' },
  { id: 'down-a', artwork: 'icon.quiz.sink', label: 'A card, face down', state: 'faceDown' },
  {
    id: 'down-b',
    artwork: 'icon.quiz.toilet',
    label: 'A card, face down',
    state: 'faceDown',
    hinted: true,
  },
  { id: 'soap-b', artwork: 'icon.quiz.soap', label: 'Soap', state: 'matched' },
  { id: 'paper', artwork: 'icon.quiz.toiletPaper', label: 'Toilet paper', state: 'faceUp' },
];

export function BathroomMatchGame({
  tiles = BATHROOM_MATCH_TILES,
  onTapTile,
  onDone,
  onGrownUp,
}: BathroomMatchGameProps): React.ReactElement {
  const theme = useHopTheme();
  const { frame, onSlotLayout } = useBoardFrame();

  const rows: BathroomMatchTile[][] = [];
  for (let i = 0; i < tiles.length; i += ROW) rows.push(tiles.slice(i, i + ROW));

  return (
    <GameHost
      title="Bathroom Match"
      instruction="Find the two that go together."
      onDone={onDone}
      onGrownUp={onGrownUp}
      board={
        <View style={styles.board} pointerEvents="box-none">
          <View style={styles.bandSlot} pointerEvents="box-none" onLayout={onSlotLayout}>
            <GameBoard scene="scene.games.bathroomMatch" frame={frame}>
              <HopSprite
                frame={frame}
                cx={HOP.cx}
                groundY={HOP.groundY}
                size={HOP.size}
                state="talk"
                label="Hop"
              />
            </GameBoard>
          </View>

          <View style={[styles.shelf, { gap: theme.spacing.s + 1 }]}>
            {rows.map((row, i) => (
              <View key={i} style={[styles.row, { gap: theme.spacing.s + 1 }]}>
                {row.map((tile) => (
                  <MatchTile
                    key={tile.id}
                    artwork={tile.artwork}
                    label={tile.label}
                    state={tile.state}
                    hinted={tile.hinted ?? false}
                    {...(onTapTile ? { onPress: () => onTapTile(tile.id) } : null)}
                  />
                ))}
              </View>
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
  shelf: { alignItems: 'center' },
  row: { flexDirection: 'row' },
});

export default BathroomMatchGame;
