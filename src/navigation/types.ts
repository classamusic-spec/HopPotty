import type { NavigatorScreenParams } from '@react-navigation/native';

/**
 * Every route in the app, typed.
 *
 * There is no stringly-typed navigation anywhere: a screen name that does not
 * exist, or a param that is missing, is a compile error rather than a blank
 * screen a tester finds later. Parent and child spaces are separate navigators
 * because they are separate products — the child never sees parent chrome, and
 * the parent gate sits on the boundary between them.
 */

export type MiniGameId =
  | 'bubbleWash'
  | 'pottyPath'
  | 'bathroomMatch'
  | 'flySnack'
  | 'mudOff'
  | 'bodySignal'
  | 'flushWave'
  | 'pottyOrder';

export type RoutineStepId = 'try' | 'wipe' | 'flush' | 'wash' | 'highFive';

/** Parent tabs — the four destinations in the tab bar. */
export type ParentTabParamList = {
  Home: undefined;
  Progress: undefined;
  Pond: undefined;
  Settings: undefined;
};

/** Parent stack — everything pushed over the tabs. */
export type ParentStackParamList = {
  Tabs: NavigatorScreenParams<ParentTabParamList>;
  PottyPauseSettings: undefined;
  QuietHours: undefined;
  ChooseApps: undefined;
  ChildProfiles: undefined;
  ChildProfileEditor: { childId: string | null };
  Paywall: undefined;
  ParentGate: { reason: ParentGateReason };
  LogVisit: undefined;
  QuickReminder: undefined;
  DeleteData: { childName: string };
  Acknowledgements: undefined;
  ScreenTimeLab: undefined;
};

/** Why a grown-up is being asked to prove they are one. */
export type ParentGateReason =
  | 'screenTimeSettings'
  | 'purchase'
  | 'restorePurchase'
  | 'deleteData'
  | 'exportData'
  | 'profileSettings'
  | 'restoreScreenAccess'
  | 'leaveChildMode';

/** Child space — deliberately shallow, with no visible navigator chrome. */
export type ChildStackParamList = {
  Hub: undefined;
  Routine: { startAt?: RoutineStepId } | undefined;
  RoutineComplete: { earnedStar: boolean };
  Pond: undefined;
  Games: undefined;
  Game: { id: MiniGameId };
  Quiz: undefined;
};

/** Onboarding — a linear flow, one step per route. */
export type OnboardingStackParamList = {
  MeetHop: undefined;
  TheIdea: undefined;
  Nickname: undefined;
  ChooseRoutine: undefined;
  Interval: undefined;
  WhyScreenTime: undefined;
  Authorization: undefined;
  ChooseApps: undefined;
  QuietHours: undefined;
  Notifications: undefined;
  TestPause: undefined;
  Ready: undefined;
};

export type RootStackParamList = {
  Splash: undefined;
  Onboarding: NavigatorScreenParams<OnboardingStackParamList>;
  Parent: NavigatorScreenParams<ParentStackParamList>;
  Child: NavigatorScreenParams<ChildStackParamList>;
};

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace ReactNavigation {
    interface RootParamList extends RootStackParamList {}
  }
}
