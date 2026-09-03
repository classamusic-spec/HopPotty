import type { AuthorizationStatus } from '../../services/screen-time/types';

/**
 * What HopPotty is allowed to say about Screen Time, per authorization state.
 *
 * The rule the whole app is built around: never claim Screen Time works. Every
 * screen that touches it handles all four states and says the honest thing in
 * each — the strings below are `HopCopy.errors` and `HopCopy.onboarding`
 * verbatim, so the React Native screens and the SwiftUI ones cannot drift into
 * making different promises.
 */
export interface ScreenTimeNotice {
  readonly title: string;
  readonly body: string;
  /** Whether the caregiver can usefully be sent to iOS Settings from here. */
  readonly canReviewSettings: boolean;
  /** Whether Apple's picker can be presented at all in this state. */
  readonly canChooseApps: boolean;
}

export const SCREEN_TIME_NOTICE: Readonly<Record<AuthorizationStatus, ScreenTimeNotice | null>> = {
  approved: null,
  notDetermined: {
    title: 'HopPotty uses Screen Time',
    body: 'iOS does the pausing. HopPotty asks permission to pause only the apps you pick, and never sees what happens inside them.',
    canReviewSettings: false,
    canChooseApps: false,
  },
  denied: {
    title: 'Screen Time permission is off',
    body: 'Potty Pause needs Screen Time permission to pause apps. Reminders keep working without it.',
    canReviewSettings: true,
    canChooseApps: false,
  },
  unavailable: {
    title: 'Screen Time is unavailable here',
    body: 'This device is managed by someone else, so HopPotty is unable to pause apps on it. Gentle reminders still work.',
    canReviewSettings: false,
    canChooseApps: false,
  },
};

export const NO_SELECTION_TITLE = 'No apps picked yet';
export const NO_SELECTION_BODY = 'Pick at least one app for HopPotty to pause.';

/** The picker is Apple's, and this is the label on the control that opens it. */
export const GRANT_LABEL = 'Allow Screen Time';
export const CHOOSE_LABEL = 'Choose apps';
export const REVIEW_LABEL = 'Review Settings';
