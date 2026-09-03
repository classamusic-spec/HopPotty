/**
 * First-run setup: twelve parent-facing screens, one per file.
 *
 * Every one is presentational. The step machine, the draft and the three side
 * effects the flow has (asking for permissions, saving the child, running a
 * test pause) live in `OnboardingModel` on the Swift side and will land in the
 * state layer here — a screen that owned its own data could not be previewed
 * or tested, which is exactly what this migration needs it for.
 */

export { MeetHopScreen, type MeetHopScreenProps } from './MeetHopScreen';
export { TheIdeaScreen, type TheIdeaScreenProps } from './TheIdeaScreen';
export {
  NicknameScreen,
  MAX_NICKNAME_LENGTH,
  HOP_AVATAR_STYLES,
  type NicknameScreenProps,
  type HopAvatarStyleId,
} from './NicknameScreen';
export {
  ChooseRoutineScreen,
  POTTY_PAUSE_MODES,
  type ChooseRoutineScreenProps,
  type PottyPauseModeId,
} from './ChooseRoutineScreen';
export {
  IntervalScreen,
  INTERVAL_PRESETS,
  INTERVAL_MIN,
  INTERVAL_MAX,
  type IntervalScreenProps,
} from './IntervalScreen';
export { WhyScreenTimeScreen, type WhyScreenTimeScreenProps } from './WhyScreenTimeScreen';
export { AuthorizationScreen, type AuthorizationScreenProps } from './AuthorizationScreen';
export {
  ChooseAppsScreen,
  summarySentence,
  type ChooseAppsScreenProps,
} from './ChooseAppsScreen';
export {
  QuietHoursScreen,
  type QuietHoursScreenProps,
  type QuietWindowOption,
  type QuietWindowLabel,
} from './QuietHoursScreen';
export {
  NotificationsScreen,
  type NotificationsScreenProps,
  type NotificationPermission,
} from './NotificationsScreen';
export { TestPauseScreen, type TestPauseScreenProps } from './TestPauseScreen';
export { ReadyScreen, type ReadyScreenProps } from './ReadyScreen';

export {
  OnboardingScaffold,
  OnboardingStepDots,
  ONBOARDING_STEP_IDS,
  stepPosition,
  useHopScreenLayout,
  type OnboardingScaffoldProps,
  type OnboardingStepId,
  type OnboardingStepPosition,
} from './OnboardingScaffold';
