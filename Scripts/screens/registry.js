const splash = require('./splash');
const parent = require('./parent');
const onboarding = require('./onboarding');
const settings = require('./settings');
const child = require('./child');
const pond = require('./pond');
const insights = require('./insights');

module.exports = {
  '00-splash': { render: splash.splash, appearance: 'light' },
  '01-parent-home': { render: parent.parentHome, appearance: 'light' },
  '02-onboarding-meet-hop': { render: onboarding.meetHop, appearance: 'light' },
  '03-onboarding-idea': { render: onboarding.theIdea, appearance: 'light' },
  '04-timer-settings': { render: settings.timerSettings, appearance: 'light' },
  '05-choose-apps': { render: settings.chooseApps, appearance: 'light' },
  '06-potty-pause-shield': { render: child.pottyPauseShield, appearance: 'light' },
  '07-routine-step1': { render: child.routineStepOne, appearance: 'light' },
  '08-routine-step3': { render: child.routineOutcome, appearance: 'light' },
  '09-routine-complete': { render: child.routineComplete, appearance: 'light' },
  '10-hops-pond': { render: pond.hopsPond, appearance: 'light' },
  '11-game-bubble-wash': { render: child.bubbleWash, appearance: 'light' },
  '12-quiz': { render: child.quiz, appearance: 'light' },
  '13-insights': { render: insights.insights, appearance: 'light' },
  '14-parent-home-dark': { render: parent.parentHome, appearance: 'dark' },
  '15-parent-home-ipad': { render: parent.parentHomePad, appearance: 'light', device: 'ipad' },
};

// Extra screen sets live in their own registries so parallel authors never edit
// one file at once. Missing files are simply absent from the render.
for (const extra of ['./registry.child', './registry.parent-extra']) {
  try { Object.assign(module.exports, require(extra)); } catch (e) { if (e.code !== 'MODULE_NOT_FOUND') throw e; }
}
