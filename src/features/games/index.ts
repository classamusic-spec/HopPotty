/**
 * The games.
 *
 * Nine screens: the hub, and the eight boards behind it. Every board sits
 * inside `GameHost`, so all eight agree about the four things they are not
 * allowed to disagree about — the way out is on screen from the first frame, in
 * the same corner; there is no clock; there is no score; and every ending is
 * the same ending, whether the board finished itself or the child said when.
 *
 * Each screen is presentational: the board arrives as props and every intent
 * leaves as a callback, so a game can be previewed and tested without a session
 * behind it.
 */

export { GamesHubScreen, GAMES_HUB_ENTRIES } from './GamesHubScreen';
export type { GamesHubScreenProps, GamesHubEntry } from './GamesHubScreen';

export { BubbleWashGame, BUBBLE_WASH_SPOTS, BUBBLE_WASH_BUBBLES } from './BubbleWashGame';
export type {
  BubbleWashGameProps,
  WashStage,
  WashSpot,
  WashBubble,
} from './BubbleWashGame';

export { PottyPathGame } from './PottyPathGame';
export type { PottyPathGameProps } from './PottyPathGame';

export { BathroomMatchGame, BATHROOM_MATCH_TILES } from './BathroomMatchGame';
export type { BathroomMatchGameProps, BathroomMatchTile } from './BathroomMatchGame';

export { FlySnackGame, FLY_SNACK_FLIES } from './FlySnackGame';
export type { FlySnackGameProps, Fly, FlyKind } from './FlySnackGame';

export { MudOffGame, MUD_OFF_BOARD } from './MudOffGame';
export type { MudOffGameProps, MudPatch, MessKind } from './MudOffGame';

export { BodySignalGame } from './BodySignalGame';
export type { BodySignalGameProps } from './BodySignalGame';

export { FlushWaveGame } from './FlushWaveGame';
export type { FlushWaveGameProps } from './FlushWaveGame';

export { PottyOrderGame, POTTY_ORDER_CARDS } from './PottyOrderGame';
export type { PottyOrderGameProps, PottyOrderCard, OrderCardId } from './PottyOrderGame';

export { GameBoard } from './GameBoard';
export type { GameBoardProps } from './GameBoard';
export { boardFrame, sceneFrame, SCENE, MAX_BOARD_WIDTH } from './sceneFrame';
export type { SceneFrame } from './sceneFrame';
