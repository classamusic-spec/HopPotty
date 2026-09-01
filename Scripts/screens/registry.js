const parent = require('./parent');
const onboarding = require('./onboarding');
const settings = require('./settings');

module.exports = {
  '01-parent-home': { render: parent.parentHome, appearance: 'light' },
  '02-onboarding-meet-hop': { render: onboarding.meetHop, appearance: 'light' },
  '03-onboarding-idea': { render: onboarding.theIdea, appearance: 'light' },
  '04-timer-settings': { render: settings.timerSettings, appearance: 'light' },
  '05-choose-apps': { render: settings.chooseApps, appearance: 'light' },
};
