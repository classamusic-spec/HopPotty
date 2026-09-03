import React from 'react';

import type { ScreenEntry, ScreenGroup } from './ScreenBrowser';
import { DeviceViewport, type DeviceName } from './DeviceViewport';

import { palette } from '../src/design-system/tokens.generated';
import type { AuthorizationStatus, SelectionSummary } from '../src/services/screen-time/types';

import { SplashScreen } from '../src/features/splash';
import { ParentHomeScreen, type PottyEntry } from '../src/features/parent-home/ParentHomeScreen';
import {
  AuthorizationScreen,
  ChooseAppsScreen as OnboardingChooseAppsScreen,
  ChooseRoutineScreen,
  IntervalScreen,
  MeetHopScreen,
  NicknameScreen,
  NotificationsScreen,
  QuietHoursScreen as OnboardingQuietHoursScreen,
  ReadyScreen,
  TestPauseScreen,
  TheIdeaScreen,
  WhyScreenTimeScreen,
  MAX_NICKNAME_LENGTH,
  type QuietWindowOption,
} from '../src/features/onboarding';
import {
  ChooseAppsScreen as PauseChooseAppsScreen,
  ErrorAccessRestoredScreen,
  PottyPauseSettingsScreen,
  QuietHoursScreen as PauseQuietHoursScreen,
  type QuietWindow,
} from '../src/features/potty-pause';
import {
  PottyRoutineScreen,
  RoutineCompleteScreen,
  RoutinePauseScreen,
} from '../src/features/potty-routine';
import { HopHubScreen } from '../src/features/child-hub';
import { PondScreen, POND_UNLOCK_ORDER, type PondItemId } from '../src/features/pond';
import { QuizRoundScreen, type QuizAnswer } from '../src/features/quizzes';
import {
  ProgressDashboardScreen,
  type ProgressBar,
  type ProgressObservation,
} from '../src/features/progress';
import { PaywallScreen } from '../src/features/purchases';
import {
  LogVisitSheet,
  QuickReminderSheet,
  type ReminderReason,
} from '../src/features/quick-reminder';
import { ParentGateScreen } from '../src/features/parent-gate';
import {
  ChildProfileEditorScreen,
  ChildProfilesScreen,
  type AvatarChoice,
  type ChildProfileSummary,
} from '../src/features/profiles';
import {
  AcknowledgementsScreen,
  DeleteDataScreen,
  SettingsRootScreen,
  type SettingsChildSummary,
} from '../src/features/settings';
import {
  BathroomMatchGame,
  BodySignalGame,
  BubbleWashGame,
  FlushWaveGame,
  FlySnackGame,
  GamesHubScreen,
  MudOffGame,
  PottyOrderGame,
  PottyPathGame,
  BUBBLE_WASH_BUBBLES,
  BUBBLE_WASH_SPOTS,
  MUD_OFF_BOARD,
} from '../src/features/games';

/**
 * Every ported screen, with the fixture data the design renders were drawn
 * with, laid out in the order the product happens in.
 *
 * The screens in `src/features/` are presentational by design — props in,
 * callbacks out — which is what lets them appear here at all. That is also the
 * whole point of this file: it is the only place in the preview that knows what
 * a screen's data looks like, so a screen can be reviewed against
 * `Art/render/screens/` without a store, a navigator or a device behind it.
 *
 * The fixtures are the renders' own. Maya has 13 stars and the next pause is at
 * 28:14 because `01-parent-home.png` says so, and matching it is the only way a
 * side-by-side comparison means anything. Every callback is a no-op: this file
 * shows screens, it does not run the app.
 */

// ---------------------------------------------------------------------------
// Fixtures — the numbers and names the design renders were drawn with.
// ---------------------------------------------------------------------------

const CHILD = 'Maya';
const SIBLING = 'Sam';
const STARS = 13;

/** 28:14, as `01-parent-home.png` counts down. */
const NEXT_PAUSE_SECONDS = 28 * 60 + 14;

const TODAY = { checks: 9, tried: 5, pee: 3, poop: 1 } as const;

const TODAY_ENTRIES: readonly PottyEntry[] = [
  { id: 'e1', time: '1:42 PM', kind: 'Pee' },
  { id: 'e2', time: '12:54 PM', kind: 'Tried' },
  { id: 'e3', time: '11:58 AM', kind: 'Poop' },
];

/** "4 apps, 1 category" — counts, because counts are all HopPotty may know. */
const SELECTION: SelectionSummary = {
  applicationCount: 4,
  categoryCount: 1,
  webDomainCount: 0,
  isEmpty: false,
};

const NO_SELECTION: SelectionSummary = {
  applicationCount: 0,
  categoryCount: 0,
  webDomainCount: 0,
  isEmpty: true,
};

const APPS_SUMMARY = '4 apps, 1 category';
const VERSION = '1.0 (12)';
const PRICE = '$19.99';

const SCHEDULE_SUMMARY =
  'Hop invites Maya about every 45 minutes, with a 2-minute heads-up. Pauses last 3 minutes and stay quiet at nap and bedtime.';

const ONBOARDING_QUIET_WINDOWS: readonly QuietWindowOption[] = [
  { id: 'nap', label: 'nap', start: '12:30 PM', end: '2:30 PM', isEnabled: true },
  { id: 'bedtime', label: 'bedtime', start: '7:30 PM', end: '7:00 AM', isEnabled: true },
  { id: 'school', label: 'school', start: '9:00 AM', end: '3:00 PM', isEnabled: false },
  { id: 'mealtime', label: 'mealtime', start: '5:30 PM', end: '6:15 PM', isEnabled: false },
];

const PAUSE_QUIET_WINDOWS: readonly QuietWindow[] = [
  { id: 'nap', label: 'Nap', span: '12:30 – 2:30 PM', isEnabled: true, wrapsMidnight: false },
  { id: 'bedtime', label: 'Bedtime', span: '7:30 PM – 7:00 AM', isEnabled: true, wrapsMidnight: true },
  { id: 'school', label: 'School', span: '9:00 AM – 3:00 PM', isEnabled: false, wrapsMidnight: false },
];

/** What 13 stars has bought: the first twelve of `PondCatalog`, in order. */
const POND_UNLOCKED_COUNT = 12;
const POND_UNLOCKED: readonly PondItemId[] = POND_UNLOCK_ORDER.slice(0, POND_UNLOCKED_COUNT);
const POND_TOTAL = POND_UNLOCK_ORDER.length;

const PROGRESS_BARS: readonly ProgressBar[] = [
  { label: 'M', value: 2 },
  { label: 'T', value: 4 },
  { label: 'W', value: 1 },
  { label: 'T', value: 3 },
  { label: 'F', value: 4 },
  { label: 'S', value: 2 },
  { label: 'S', value: 2 },
];

const PROGRESS_OBSERVATIONS: readonly ProgressObservation[] = [
  { id: 'interval', label: 'Common interval', value: '45–55 min' },
  { id: 'consistent', label: 'Most consistent time', value: '9–11 AM' },
  { id: 'participation', label: 'Routine participation', value: '12 of 14' },
  { id: 'washing', label: 'Hand-washing completed', value: '11 of 12' },
  { id: 'accidents', label: 'Accidents recorded', value: '4' },
];

const WEEK_COUNTS = { checks: 38, tried: 31, pee: 19, poop: 6 } as const;

const REMINDER_REASONS: readonly ReminderReason[] = [
  { id: 'drink', label: 'After a drink' },
  { id: 'leaving', label: 'Before leaving' },
  { id: 'nap', label: 'Before a nap' },
];

const MAYA_PROFILE: ChildProfileSummary = {
  id: 'maya',
  name: CHILD,
  schedule: 'Guided routine · every 45 minutes',
  tint: palette.hopGreenSoft,
  isCurrentlyShown: true,
  today: { tried: 5, pee: 3, poop: 1, stars: STARS },
  pondUnlocked: POND_UNLOCKED.length,
  pondTotal: POND_TOTAL,
};

const SAM_PROFILE: ChildProfileSummary = {
  id: 'sam',
  name: SIBLING,
  schedule: 'Gentle · every 60 minutes',
  tint: palette.pondBlueSoft,
  isCurrentlyShown: false,
  today: { tried: 2, pee: 1, poop: 0, stars: 4 },
  pondUnlocked: 2,
  pondTotal: POND_TOTAL,
};

const PROFILES: readonly ChildProfileSummary[] = [MAYA_PROFILE, SAM_PROFILE];

const SETTINGS_CHILDREN: readonly SettingsChildSummary[] = [
  { id: 'maya', name: CHILD, sublabel: 'Currently shown', tint: palette.hopGreenSoft },
  { id: 'sam', name: SIBLING, tint: palette.pondBlueSoft },
];

const AVATARS: readonly AvatarChoice[] = [
  { id: 'green', tint: palette.hopGreenSoft, name: 'green' },
  { id: 'blue', tint: palette.pondBlueSoft, name: 'pond blue' },
  { id: 'sun', tint: palette.sunshineSoft, name: 'sunshine' },
  { id: 'peach', tint: palette.peachSoft, name: 'peach' },
  { id: 'lavender', tint: palette.lavenderSoft, name: 'lavender' },
];

const QUIZ_ANSWERS: readonly QuizAnswer[] = [
  { id: 'wash', illustration: 'icon.quiz.washHands', label: 'Wash hands' },
  { id: 'snack', illustration: 'icon.quiz.apple', label: 'Have a snack' },
  { id: 'play', illustration: 'icon.quiz.keepPlaying', label: 'Keep playing' },
];

// ---------------------------------------------------------------------------
// Entry helpers
// ---------------------------------------------------------------------------

/**
 * A callback that does nothing, deliberately.
 *
 * The preview shows screens; it does not run the app. A button that navigated
 * would make this a second, wrong implementation of `src/navigation/`.
 */
const noop = (): void => {};

function screen(
  id: string,
  label: string,
  element: React.ReactNode,
  options: { render?: string; device?: DeviceName } = {},
): ScreenEntry {
  const device: DeviceName = options.device ?? 'phone';
  return {
    id,
    label,
    render: options.render,
    device,
    // The screen measures the frame the browser draws, not the browser window.
    element: <DeviceViewport device={device}>{element}</DeviceViewport>,
  };
}

/** One `AuthorizationScreen` per state, because each says something different. */
function authorization(status: AuthorizationStatus, label: string): ScreenEntry {
  return screen(
    `onboarding-authorization-${status}`,
    label,
    <AuthorizationScreen
      status={status}
      onRequestAuthorization={noop}
      onContinue={noop}
      onOpenSystemSettings={noop}
      onBack={noop}
    />,
  );
}

// ---------------------------------------------------------------------------
// The groups, in flow order.
// ---------------------------------------------------------------------------

const ONBOARDING: ScreenGroup = {
  title: 'Onboarding',
  tint: palette.hopGreen,
  screens: [
    screen('splash', 'Splash', <SplashScreen onFinished={noop} />, { render: '00-splash.png' }),
    screen('onboarding-meet-hop', 'Meet Hop', <MeetHopScreen onGetStarted={noop} onSkip={noop} />, {
      render: '02-onboarding-meet-hop.png',
    }),
    screen(
      'onboarding-the-idea',
      'The Idea',
      <TheIdeaScreen onContinue={noop} onSkip={noop} onBack={noop} />,
      { render: '03-onboarding-idea.png' },
    ),
    screen(
      'onboarding-nickname',
      'Nickname',
      <NicknameScreen
        nickname={CHILD}
        onChangeNickname={noop}
        avatar="frogGreen"
        onChangeAvatar={noop}
        onContinue={noop}
        onSkip={noop}
        onBack={noop}
      />,
    ),
    screen(
      'onboarding-nickname-empty',
      'Nickname — no name yet',
      <NicknameScreen
        nickname=""
        onChangeNickname={noop}
        avatar="frogBlue"
        onChangeAvatar={noop}
        onContinue={noop}
        onSkip={noop}
        onBack={noop}
      />,
    ),
    screen(
      'onboarding-choose-routine',
      'Choose Routine',
      <ChooseRoutineScreen mode="routine" onChangeMode={noop} onContinue={noop} onBack={noop} />,
    ),
    screen(
      'onboarding-interval',
      'Interval',
      <IntervalScreen
        intervalMinutes={45}
        onChangeInterval={noop}
        onContinue={noop}
        onBack={noop}
      />,
    ),
    screen(
      'onboarding-why-screen-time',
      'Why Screen Time',
      <WhyScreenTimeScreen onAllow={noop} onNotNow={noop} onBack={noop} />,
      { render: '31-onboarding-screen-time-ask.png' },
    ),
    authorization('notDetermined', 'Authorization — not determined'),
    authorization('denied', 'Authorization — denied'),
    authorization('approved', 'Authorization — approved'),
    authorization('unavailable', 'Authorization — unavailable'),
    screen(
      'onboarding-choose-apps',
      'Choose Apps',
      <OnboardingChooseAppsScreen
        selection={SELECTION}
        onChooseApps={noop}
        onContinue={noop}
        onBack={noop}
      />,
    ),
    screen(
      'onboarding-choose-apps-empty',
      'Choose Apps — nothing picked',
      <OnboardingChooseAppsScreen
        selection={NO_SELECTION}
        onChooseApps={noop}
        onContinue={noop}
        onBack={noop}
      />,
    ),
    screen(
      'onboarding-choose-apps-no-picker',
      'Choose Apps — no picker',
      <OnboardingChooseAppsScreen
        selection={NO_SELECTION}
        pickerAvailable={false}
        onChooseApps={noop}
        onContinue={noop}
        onBack={noop}
      />,
    ),
    screen(
      'onboarding-quiet-hours',
      'Quiet Hours',
      <OnboardingQuietHoursScreen
        windows={ONBOARDING_QUIET_WINDOWS}
        onToggleWindow={noop}
        onEditWindow={noop}
        onContinue={noop}
        onSkip={noop}
        onBack={noop}
      />,
    ),
    screen(
      'onboarding-notifications',
      'Notifications',
      <NotificationsScreen
        permission="notDetermined"
        onAllow={noop}
        onContinue={noop}
        onOpenSystemSettings={noop}
        onSkip={noop}
        onBack={noop}
      />,
    ),
    screen(
      'onboarding-notifications-denied',
      'Notifications — denied',
      <NotificationsScreen
        permission="denied"
        onAllow={noop}
        onContinue={noop}
        onOpenSystemSettings={noop}
        onSkip={noop}
        onBack={noop}
      />,
    ),
    screen(
      'onboarding-test-pause',
      'Test Pause',
      <TestPauseScreen
        didSucceed={null}
        onRunTestPause={noop}
        onContinue={noop}
        onSkip={noop}
        onBack={noop}
      />,
    ),
    screen(
      'onboarding-test-pause-worked',
      'Test Pause — it worked',
      <TestPauseScreen
        didSucceed
        onRunTestPause={noop}
        onContinue={noop}
        onSkip={noop}
        onBack={noop}
      />,
    ),
    screen(
      'onboarding-test-pause-failed',
      'Test Pause — it did not',
      <TestPauseScreen
        didSucceed={false}
        onRunTestPause={noop}
        onContinue={noop}
        onSkip={noop}
        onBack={noop}
      />,
    ),
    screen(
      'onboarding-ready',
      'Ready',
      <ReadyScreen
        scheduleSummary={SCHEDULE_SUMMARY}
        onRunTestPause={noop}
        onFinish={noop}
        onChangeSchedule={noop}
      />,
      { render: '33-onboarding-first-pause-set.png' },
    ),
    screen(
      'onboarding-ready-gentle',
      'Ready — gentle fallback',
      <ReadyScreen
        scheduleSummary={SCHEDULE_SUMMARY}
        fellBackToGentle
        canRunTestPause={false}
        onFinish={noop}
        onChangeSchedule={noop}
      />,
    ),
  ],
};

const PARENT: ScreenGroup = {
  title: 'Parent',
  tint: palette.pondBlueDeep,
  screens: [
    screen(
      'parent-home',
      'Parent Home',
      <ParentHomeScreen
        childName={CHILD}
        stars={STARS}
        nextPauseInSeconds={NEXT_PAUSE_SECONDS}
        counts={TODAY}
        entries={TODAY_ENTRIES}
        onSkip={noop}
        onStartNow={noop}
      />,
      { render: '01-parent-home.png' },
    ),
    screen(
      'parent-home-idle',
      'Parent Home — nothing scheduled',
      <ParentHomeScreen
        childName={SIBLING}
        stars={4}
        nextPauseInSeconds={null}
        counts={{ checks: 0, tried: 0, pee: 0, poop: 0 }}
        entries={[]}
        onSkip={noop}
        onStartNow={noop}
      />,
    ),
    screen(
      'progress',
      'Progress',
      <ProgressDashboardScreen
        childName={CHILD}
        period="week"
        hasEntries
        checkIns={18}
        checkInsCaption="across 5 days with entries"
        bars={PROGRESS_BARS}
        counts={WEEK_COUNTS}
        observations={PROGRESS_OBSERVATIONS}
        onChangePeriod={noop}
        onSelectChild={noop}
        onSelectObservation={noop}
        onLogVisit={noop}
      />,
      { render: '13-insights.png' },
    ),
    screen(
      'progress-empty',
      'Progress — day one',
      <ProgressDashboardScreen
        childName={CHILD}
        period="week"
        hasEntries={false}
        checkIns={0}
        checkInsCaption="no entries yet"
        bars={[]}
        counts={{ checks: 0, tried: 0, pee: 0, poop: 0 }}
        observations={[]}
        onChangePeriod={noop}
        onSelectChild={noop}
        onLogVisit={noop}
      />,
      { render: '40-progress-empty.png' },
    ),
    screen(
      'progress-ipad',
      'Progress — iPad',
      <ProgressDashboardScreen
        childName={CHILD}
        period="week"
        hasEntries
        checkIns={18}
        checkInsCaption="across 5 days with entries"
        bars={PROGRESS_BARS}
        counts={WEEK_COUNTS}
        observations={PROGRESS_OBSERVATIONS}
        onChangePeriod={noop}
        onSelectChild={noop}
        onSelectObservation={noop}
        onLogVisit={noop}
        onSelectSection={noop}
      />,
      { render: '44-insights-ipad.png', device: 'ipad' },
    ),
    screen(
      'quick-reminder',
      'Quick Reminder',
      <QuickReminderSheet
        preset="minutes30"
        time="2:15 PM"
        childName={CHILD}
        childTint={palette.hopGreenSoft}
        reasons={REMINDER_REASONS}
        selectedReasonId="drink"
        scheduleNote="A Potty Pause is already coming at about 2:20 PM. You can set this anyway."
        onDismiss={noop}
        onSelectPreset={noop}
        onPickTime={noop}
        onSelectChild={noop}
        onSelectReason={noop}
        onSetReminder={noop}
      />,
      { render: '41-quick-reminder-sheet.png' },
    ),
    screen(
      'log-visit',
      'Log Visit',
      <LogVisitSheet
        kind="pee"
        time="1:42 PM"
        note=""
        onChangeKind={noop}
        onPickTime={noop}
        onChangeNote={noop}
        onSave={noop}
        onCancel={noop}
      />,
    ),
    screen(
      'log-visit-saving',
      'Log Visit — saving',
      <LogVisitSheet
        kind="accident"
        time="12:54 PM"
        note="Just after a drink."
        isSaving
        onChangeKind={noop}
        onPickTime={noop}
        onChangeNote={noop}
        onSave={noop}
        onCancel={noop}
      />,
    ),
    screen(
      'parent-gate',
      'Parent Gate',
      <ParentGateScreen
        reason="screenTimeSettings"
        challenge={{ first: 7, second: 5 }}
        onPass={noop}
        onCancel={noop}
        onRequestNewChallenge={noop}
      />,
      { render: '37-parent-gate.png' },
    ),
    screen(
      'parent-gate-no-hold',
      'Parent Gate — sum only',
      <ParentGateScreen
        reason="deleteData"
        challenge={{ first: 8, second: 6 }}
        skipsHold
        onPass={noop}
        onCancel={noop}
        onRequestNewChallenge={noop}
      />,
    ),
    screen(
      'paywall',
      'Paywall — HopPotty Family',
      <PaywallScreen displayPrice={PRICE} onDismiss={noop} onPurchase={noop} onRestore={noop} />,
      { render: '36-paywall-family.png' },
    ),
    screen(
      'paywall-busy',
      'Paywall — purchasing',
      <PaywallScreen
        displayPrice={PRICE}
        isBusy
        onDismiss={noop}
        onPurchase={noop}
        onRestore={noop}
      />,
    ),
  ],
};

const POTTY_PAUSE: ScreenGroup = {
  title: 'Potty Pause',
  tint: palette.pondBlue,
  screens: [
    screen(
      'pause-settings',
      'Potty Pause Settings',
      <PottyPauseSettingsScreen
        childName={CHILD}
        mode="Guided routine"
        interval="45 minutes"
        warningBeforePause="2 minutes"
        pauseLength="3 minutes"
        quietHours="12:30 – 2:30 PM"
        bedtime="After 7:30 PM"
        appsSummary={APPS_SUMMARY}
        screenTimeStatus="approved"
        onBack={noop}
        onEditMode={noop}
        onEditInterval={noop}
        onEditWarning={noop}
        onEditPauseLength={noop}
        onEditQuietHours={noop}
        onEditBedtime={noop}
        onEditApps={noop}
        onTestPause={noop}
        onRestoreScreenAccess={noop}
        onReviewSystemSettings={noop}
      />,
      { render: '04-timer-settings.png' },
    ),
    screen(
      'pause-settings-denied',
      'Potty Pause Settings — permission off',
      <PottyPauseSettingsScreen
        childName={CHILD}
        mode="Gentle"
        interval="60 minutes"
        warningBeforePause={null}
        pauseLength="3 minutes"
        quietHours="12:30 – 2:30 PM"
        bedtime="After 7:30 PM"
        appsSummary="Nothing picked yet"
        screenTimeStatus="denied"
        onBack={noop}
        onEditMode={noop}
        onEditInterval={noop}
        onEditWarning={noop}
        onEditPauseLength={noop}
        onEditQuietHours={noop}
        onEditBedtime={noop}
        onEditApps={noop}
        onTestPause={noop}
        onRestoreScreenAccess={noop}
        onReviewSystemSettings={noop}
      />,
    ),
    screen(
      'pause-choose-apps',
      'Apps That Pause',
      <PauseChooseAppsScreen
        selection={SELECTION}
        status="approved"
        onBack={noop}
        onChooseApps={noop}
        onRequestAuthorization={noop}
        onReviewSystemSettings={noop}
      />,
      { render: '05-choose-apps.png' },
    ),
    screen(
      'pause-choose-apps-not-determined',
      'Apps That Pause — before permission',
      <PauseChooseAppsScreen
        selection={NO_SELECTION}
        status="notDetermined"
        onBack={noop}
        onChooseApps={noop}
        onRequestAuthorization={noop}
        onReviewSystemSettings={noop}
      />,
    ),
    screen(
      'pause-quiet-hours',
      'Quiet Hours',
      <PauseQuietHoursScreen
        windows={PAUSE_QUIET_WINDOWS}
        onBack={noop}
        onEditWindow={noop}
        onAddWindow={noop}
      />,
    ),
    screen(
      'pause-quiet-hours-empty',
      'Quiet Hours — none set',
      <PauseQuietHoursScreen windows={[]} onBack={noop} onEditWindow={noop} onAddWindow={noop} />,
    ),
    screen(
      'pause-error-denied',
      'Screen Time Off — denied',
      <ErrorAccessRestoredScreen
        status="denied"
        onBack={noop}
        onReviewSettings={noop}
        onDismiss={noop}
      />,
      { render: '39-error-access-restored.png' },
    ),
    screen(
      'pause-error-unavailable',
      'Screen Time Off — unavailable',
      <ErrorAccessRestoredScreen
        status="unavailable"
        onBack={noop}
        onReviewSettings={noop}
        onDismiss={noop}
      />,
    ),
  ],
};

const ROUTINE: ScreenGroup = {
  title: 'Routine',
  tint: palette.hopGreenLight,
  screens: [
    screen(
      'routine-pause',
      'Potty Pause',
      <RoutinePauseScreen childName={CHILD} onGo={noop} onAskForGrownUp={noop} />,
      { render: '06-potty-pause-shield.png' },
    ),
    screen(
      'routine-pause-no-name',
      'Potty Pause — no nickname',
      <RoutinePauseScreen childName={null} onGo={noop} onAskForGrownUp={noop} />,
    ),
    screen(
      'routine-try',
      'Routine — Try',
      <PottyRoutineScreen step="try" onNext={noop} onSkip={noop} onGrownUp={noop} />,
      { render: '07-routine-step1.png' },
    ),
    screen(
      'routine-try-timer',
      'Routine — Try, with timer',
      <PottyRoutineScreen
        step="try"
        timerFraction={0.62}
        onNext={noop}
        onSkip={noop}
        onGrownUp={noop}
      />,
      { render: '20-routine-try-timer.png' },
    ),
    screen(
      'routine-outcome',
      'Routine — All done trying?',
      <PottyRoutineScreen
        step="try"
        isAwaitingOutcome
        onNext={noop}
        onOutcome={noop}
        onGrownUp={noop}
      />,
      { render: '08-routine-step3.png' },
    ),
    screen(
      'routine-wipe',
      'Routine — Wipe',
      <PottyRoutineScreen step="wipe" onNext={noop} onSkip={noop} onGrownUp={noop} />,
      { render: '16-routine-step-wipe.png' },
    ),
    screen(
      'routine-flush',
      'Routine — Flush',
      <PottyRoutineScreen step="flush" onNext={noop} onSkip={noop} onGrownUp={noop} />,
      { render: '17-routine-step-flush.png' },
    ),
    screen(
      'routine-wash',
      'Routine — Wash',
      <PottyRoutineScreen step="wash" onNext={noop} onSkip={noop} onGrownUp={noop} />,
      { render: '18-routine-step-wash.png' },
    ),
    screen(
      'routine-high-five',
      'Routine — High five',
      <PottyRoutineScreen step="highFive" onNext={noop} onGrownUp={noop} />,
      { render: '19-routine-step-highfive.png' },
    ),
    screen(
      'routine-complete',
      'Routine Complete',
      <RoutineCompleteScreen starsEarned={1} onBackToPlay={noop} onSeePond={noop} />,
      { render: '09-routine-complete.png' },
    ),
    screen(
      'routine-complete-no-stars',
      'Routine Complete — left early',
      <RoutineCompleteScreen starsEarned={0} onBackToPlay={noop} onSeePond={noop} />,
    ),
  ],
};

const CHILD_AND_POND: ScreenGroup = {
  title: 'Child & Pond',
  tint: palette.pondBlueLight,
  screens: [
    screen(
      'hop-hub',
      "Hop's Hub",
      <HopHubScreen
        childName={CHILD}
        stars={STARS}
        onPottyTime={noop}
        onPond={noop}
        onGames={noop}
        onQuestions={noop}
        onGrownUps={noop}
      />,
      { render: '45-hop-hub.png' },
    ),
    screen(
      'hop-hub-no-name',
      "Hop's Hub — no nickname",
      <HopHubScreen
        childName={null}
        stars={0}
        onPottyTime={noop}
        onPond={noop}
        onGames={noop}
        onQuestions={noop}
        onGrownUps={noop}
      />,
    ),
    screen(
      'pond',
      "Hop's Pond",
      <PondScreen
        childName={CHILD}
        stars={STARS}
        unlocked={POND_UNLOCKED}
        collectionTotal={POND_TOTAL}
        nextUnlock={{
          id: 'dragonfly',
          name: 'a dragonfly',
          starsNeeded: 3,
          starCost: 16,
          progress: 13 / 16,
        }}
        onBack={noop}
      />,
      { render: '10-hops-pond.png' },
    ),
    screen(
      'pond-empty',
      "Hop's Pond — day one",
      <PondScreen
        childName={CHILD}
        stars={0}
        unlocked={[]}
        collectionTotal={POND_TOTAL}
        nextUnlock={null}
        onBack={noop}
      />,
    ),
    screen(
      'quiz',
      "Hop's Question",
      <QuizRoundScreen
        question="What do we do after using the potty?"
        answers={QUIZ_ANSWERS}
        onAnswer={noop}
        onHearAgain={noop}
        onGrownUp={noop}
      />,
      { render: '12-quiz.png' },
    ),
  ],
};

const GAMES: ScreenGroup = {
  title: 'Games',
  tint: palette.sunshine,
  screens: [
    screen('games-hub', 'Games Hub', <GamesHubScreen onOpen={noop} onBack={noop} />, {
      render: '21-games-hub.png',
    }),
    screen(
      'game-bubble-wash',
      'Bubble Wash',
      <BubbleWashGame
        stage="rub"
        spots={BUBBLE_WASH_SPOTS}
        bubbles={BUBBLE_WASH_BUBBLES}
        onPopBubble={noop}
        onRubSpot={noop}
        onDone={noop}
        onGrownUp={noop}
      />,
      { render: '11-game-bubble-wash.png' },
    ),
    screen(
      'game-bubble-wash-clean',
      'Bubble Wash — clean',
      <BubbleWashGame
        stage="clean"
        spots={BUBBLE_WASH_SPOTS.map((spot) => ({ ...spot, done: true }))}
        bubbles={BUBBLE_WASH_BUBBLES.map((bubble) => ({ ...bubble, popped: true }))}
        onPopBubble={noop}
        onRubSpot={noop}
        onDone={noop}
        onGrownUp={noop}
      />,
      { render: '46-bubble-wash-clean.png' },
    ),
    screen(
      'game-potty-path',
      'Potty Path',
      <PottyPathGame reached={3} onHopTo={noop} onDone={noop} onGrownUp={noop} />,
      { render: '22-game-potty-path.png' },
    ),
    screen(
      'game-bathroom-match',
      'Bathroom Match',
      <BathroomMatchGame onTapTile={noop} onDone={noop} onGrownUp={noop} />,
      { render: '23-game-bathroom-match.png' },
    ),
    screen(
      'game-fly-snack',
      'Fly Snack',
      <FlySnackGame onCatch={noop} onDone={noop} onGrownUp={noop} />,
      { render: '24-game-fly-snack.png' },
    ),
    screen(
      'game-fly-snack-handoff',
      'Fly Snack — hand-off',
      <FlySnackGame
        phase="handOff"
        fed={6}
        flies={[]}
        onCatch={noop}
        onStartRoutine={noop}
        onDone={noop}
        onGrownUp={noop}
      />,
      { render: '29-game-fly-snack-handoff.png' },
    ),
    screen(
      'game-mud-off',
      'Mud Off',
      <MudOffGame patches={MUD_OFF_BOARD} onWipe={noop} onDone={noop} onGrownUp={noop} />,
      { render: '25-game-mud-off.png' },
    ),
    screen(
      'game-body-signal',
      'Listen to Your Body',
      <BodySignalGame
        noticed={1}
        bubbleShowing
        onTapBubble={noop}
        onTapHop={noop}
        onDone={noop}
        onGrownUp={noop}
      />,
      { render: '26-game-body-signal.png' },
    ),
    screen(
      'game-flush-wave',
      'Flush and Wave',
      <FlushWaveGame flushes={1} onFlush={noop} onDone={noop} onGrownUp={noop} />,
      { render: '27-game-flush-wave.png' },
    ),
    screen(
      'game-potty-order',
      'Potty Order',
      <PottyOrderGame held="wipe" onPickUp={noop} onPlace={noop} onDone={noop} onGrownUp={noop} />,
      { render: '28-game-potty-order.png' },
    ),
  ],
};

const SETTINGS_AND_DATA: ScreenGroup = {
  title: 'Settings & Data',
  tint: palette.lavender,
  screens: [
    screen(
      'settings',
      'Settings',
      <SettingsRootScreen
        childProfiles={SETTINGS_CHILDREN}
        pauseMode="Guided routine"
        appsSummary={APPS_SUMMARY}
        warningBeforePause
        version={VERSION}
        onSelectChild={noop}
        onAddChild={noop}
        onOpenPottyPause={noop}
        onOpenApps={noop}
        onChangeWarningBeforePause={noop}
        onOpenFamily={noop}
        onExportData={noop}
        onDeleteEverything={noop}
      />,
      { render: '34-settings-hub.png' },
    ),
    screen(
      'settings-ipad',
      'Settings — iPad',
      <SettingsRootScreen
        childProfiles={SETTINGS_CHILDREN}
        pauseMode="Guided routine"
        appsSummary={APPS_SUMMARY}
        warningBeforePause
        version={VERSION}
        onSelectChild={noop}
        onAddChild={noop}
        onOpenPottyPause={noop}
        onOpenApps={noop}
        onChangeWarningBeforePause={noop}
        onOpenFamily={noop}
        onExportData={noop}
        onDeleteEverything={noop}
        onSelectSection={noop}
      />,
      { device: 'ipad' },
    ),
    screen(
      'child-profiles',
      'Children',
      <ChildProfilesScreen
        profiles={PROFILES}
        isFamilyUnlocked
        onBack={noop}
        onSelectProfile={noop}
        onAddChild={noop}
        onOpenFamily={noop}
      />,
      { render: '35-child-profiles.png' },
    ),
    screen(
      'child-profiles-locked',
      'Children — Family locked',
      <ChildProfilesScreen
        profiles={[MAYA_PROFILE]}
        isFamilyUnlocked={false}
        onBack={noop}
        onSelectProfile={noop}
        onAddChild={noop}
        onOpenFamily={noop}
      />,
    ),
    screen(
      'child-profile-editor',
      'Child Profile',
      <ChildProfileEditorScreen
        nickname={CHILD}
        nicknameLimit={MAX_NICKNAME_LENGTH}
        avatars={AVATARS}
        selectedAvatarId="green"
        startingPoint="gettingTheHangOfIt"
        submitLabel="Save"
        onBack={noop}
        onChangeNickname={noop}
        onSelectAvatar={noop}
        onSelectStartingPoint={noop}
        onSubmit={noop}
      />,
      { render: '32-onboarding-child-profile.png' },
    ),
    screen(
      'child-profile-editor-new',
      'Child Profile — new child',
      <ChildProfileEditorScreen
        nickname=""
        nicknameLimit={MAX_NICKNAME_LENGTH}
        avatars={AVATARS}
        selectedAvatarId="blue"
        startingPoint="justStarting"
        submitLabel="Continue"
        onBack={noop}
        onChangeNickname={noop}
        onSelectAvatar={noop}
        onSelectStartingPoint={noop}
        onSubmit={noop}
      />,
    ),
    screen(
      'delete-data',
      'Delete Data',
      <DeleteDataScreen
        childName={CHILD}
        counts={{ events: 47, stars: 31, decorations: 6 }}
        onDelete={noop}
        onCancel={noop}
      />,
      { render: '38-delete-data-confirm.png' },
    ),
    screen(
      'acknowledgements',
      'Acknowledgements',
      <AcknowledgementsScreen onBack={noop} />,
    ),
    screen(
      'acknowledgements-notices',
      'Acknowledgements — with notices',
      <AcknowledgementsScreen
        notices={[
          { id: 'rn', name: 'React Native', licence: 'MIT', onOpen: noop },
          { id: 'svg', name: 'react-native-svg', licence: 'MIT', onOpen: noop },
        ]}
        onBack={noop}
      />,
    ),
  ],
};

export const SCREEN_GROUPS: ScreenGroup[] = [
  ONBOARDING,
  PARENT,
  POTTY_PAUSE,
  ROUTINE,
  CHILD_AND_POND,
  GAMES,
  SETTINGS_AND_DATA,
];
