/**
 * The child's remaining screens.
 *
 * A separate registry so this set and the parent's can be authored side by side
 * without two people editing `registry.js`; `registry.js` merges whatever it
 * finds here.
 */
const childExtra = require('./child-extra');
const hub = require('./hub');

module.exports = {
  '16-routine-step-wipe': { render: childExtra.routineWipe, appearance: 'light' },
  '17-routine-step-flush': { render: childExtra.routineFlush, appearance: 'light' },
  '18-routine-step-wash': { render: childExtra.routineWash, appearance: 'light' },
  '19-routine-step-highfive': { render: childExtra.routineHighFive, appearance: 'light' },
  '20-routine-try-timer': { render: childExtra.routineTryTimer, appearance: 'light' },
  '21-games-hub': { render: childExtra.gamesHub, appearance: 'light' },
  '22-game-potty-path': { render: childExtra.gamePottyPath, appearance: 'light' },
  '23-game-bathroom-match': { render: childExtra.gameBathroomMatch, appearance: 'light' },
  '24-game-fly-snack': { render: childExtra.gameFlySnack, appearance: 'light' },
  '25-game-mud-off': { render: childExtra.gameMudOff, appearance: 'light' },
  '26-game-body-signal': { render: childExtra.gameBodySignal, appearance: 'light' },
  '27-game-flush-wave': { render: childExtra.gameFlushWave, appearance: 'light' },
  '28-game-potty-order': { render: childExtra.gamePottyOrder, appearance: 'light' },
  '29-game-fly-snack-handoff': { render: childExtra.gameFlySnackHandoff, appearance: 'light' },
  '30-games-hub-dark': { render: childExtra.gamesHub, appearance: 'dark' },
  '45-hop-hub': { render: hub.hopHub, appearance: 'light' },
};
