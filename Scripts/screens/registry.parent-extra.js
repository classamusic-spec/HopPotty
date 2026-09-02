/**
 * 31–44. Merged into `registry.js` automatically; see the loop at its foot.
 *
 * Kept in its own file so this set and the child set can be authored at the
 * same time without two people editing one registry.
 */
const x = require('./parent-extra');

module.exports = {
  '31-onboarding-screen-time-ask': { render: x.screenTimeAsk, appearance: 'light' },
  '32-onboarding-child-profile': { render: x.childProfile, appearance: 'light' },
  '33-onboarding-first-pause-set': { render: x.firstPauseSet, appearance: 'light' },
  '34-settings-hub': { render: x.settingsHub, appearance: 'light' },
  '35-child-profiles': { render: x.childProfiles, appearance: 'light' },
  '36-paywall-family': { render: x.paywallFamily, appearance: 'light' },
  '37-parent-gate': { render: x.parentGate, appearance: 'light' },
  '38-delete-data-confirm': { render: x.deleteDataConfirm, appearance: 'light' },
  '39-error-access-restored': { render: x.accessRestored, appearance: 'light' },
  '40-progress-empty': { render: x.progressEmpty, appearance: 'light' },
  '41-quick-reminder-sheet': { render: x.quickReminderSheet, appearance: 'light' },
  '42-widgets': { render: x.widgets, appearance: 'light' },
  '43-live-activity': { render: x.liveActivity, appearance: 'light' },
  '44-insights-ipad': { render: x.insightsPad, appearance: 'light', device: 'ipad' },
};
