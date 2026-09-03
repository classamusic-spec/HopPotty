# Screen migration matrix

Every user-facing surface in HopPotty, its React Native destination, and where
it stands. Updated as screens move.

**51 screen-level SwiftUI views** in the app target (48 excluding three pure
routers), plus 3 views that live in extensions and are *not* migrating.

Status values: `not started` · `in progress` · `RN built` · `visual QA` ·
`done` (SwiftUI retired).

A screen is `done` only when it meets §59: interactions, persistence,
accessibility, loading/empty/error states, iPhone **and** iPad layout, polished
animation, and visual QA against its render — at which point the SwiftUI
version may be retired, and not before.

---

## Not migrating — these stay native

| Surface | File | Why |
|---|---|---|
| Potty Pause shield | `Extensions/HopPottyShieldConfiguration/…Extension.swift` | A `ShieldConfiguration`, not a view. Drawn by iOS outside our process. Render `06`. |
| Home-screen widget | `Extensions/HopPottyWidgets/NextPauseWidget.swift` | WidgetKit. Render `42`. |
| Live Activity | `Extensions/HopPottyWidgets/PottyPauseActivity.swift` | ActivityKit. Render `43`. |

React Native must never be embedded in these targets.

---

## App shell

| Screen | Source | Facing | Native deps | Render | Cx | RN destination | Status |
|---|---|---|---|---|---|---|---|
| `RootView` | `Features/Shared/RootView.swift` | parent | — | — | S | `src/app/Root.tsx` | not started |
| `ParentAppRootView` | `Features/Shared/ParentRootView.swift:303` | parent | — | — | S | `src/navigation/ParentRoot.tsx` | not started |
| `ParentRootView` | `Features/Shared/ParentRootView.swift:43` | parent | Screen Time | — | M | `src/navigation/ParentTabs.tsx` | not started |
| `HopSplashView` | `Features/Splash/HopSplashView.swift` | both | — | `00` | **H** | `src/features/splash/SplashScreen.tsx` | not started |
| `ParentGateView` | `Features/ParentGate/ParentGateView.swift` | parent | LocalAuthentication | `37` | **H** | `src/features/parent-gate/ParentGateScreen.tsx` | not started |

## Onboarding — 12 steps

| Screen | Source | Native deps | Render | Cx | Status |
|---|---|---|---|---|---|
| `OnboardingFlowView` | `OnboardingFlowView.swift` | — | — | M | not started |
| `MeetHopScreen` | `OnboardingIntroScreens.swift:8` | — | `02` | M | not started |
| `TheIdeaScreen` | `OnboardingIntroScreens.swift:42` | — | `03` | S | not started |
| `NicknameScreen` | `OnboardingIntroScreens.swift:95` | — | `32`* | M | not started |
| `ChooseRoutineScreen` | `OnboardingScheduleScreens.swift:12` | — | `32`* | M | not started |
| `IntervalScreen` | `OnboardingScheduleScreens.swift:86` | — | — | M | not started |
| `WhyScreenTimeScreen` | `OnboardingPermissionScreens.swift:33` | — | `31` | S | not started |
| `AuthorizationScreen` | `OnboardingPermissionScreens.swift:112` | **Screen Time** | — | M | not started |
| `ChooseAppsScreen` | `OnboardingPermissionScreens.swift:222` | **Screen Time** (native picker) | `05` | M | not started |
| `QuietHoursScreen` | `OnboardingFinishScreens.swift:8` | — | — | M | not started |
| `NotificationsScreen` | `OnboardingFinishScreens.swift:75` | notifications | — | M | not started |
| `TestPauseScreen` | `OnboardingFinishScreens.swift:131` | **Screen Time** | — | M | not started |
| `ReadyScreen` | `OnboardingFinishScreens.swift:173` | — | `33` | S | not started |

\* `32-onboarding-child-profile.png` is a composite of two steps; no 1:1 render.

All → `src/features/onboarding/`.

`ChooseAppsScreen` is a hard constraint: `FamilyActivityPicker` is a SwiftUI
view Apple requires to be presented natively. React Native must present it
through the native module, never reimplement it.

## Parent home

| Screen | Source | Native deps | Render | Cx | Status |
|---|---|---|---|---|---|
| `ParentHomeView` | `Features/ParentHome/ParentHomeView.swift` | Screen Time, Live Activity | `01`, `14` dark, `15` iPad, `39` error | **H** | not started |
| `LogVisitSheet` | `Features/ParentHome/LogVisitSheet.swift` | — | — | M | not started |
| `QuickReminderSheet` | `Features/QuickReminder/QuickReminderSheet.swift` | notifications | `41` | M | not started |

→ `src/features/parent-home/`. `PondBackdropView` is a `Canvas` with
`repeatForever` — the first real animation port.

## Potty Pause settings

| Screen | Source | Native deps | Render | Cx | Status |
|---|---|---|---|---|---|
| `PottyPauseSettingsView` | `PottyPauseSettingsView.swift` | Screen Time, notifications | `04` | M | not started |
| `QuietHoursEditor` | `QuietHoursEditor.swift:10` | — | — | M | not started |
| `QuietWindowSheet` | `QuietHoursEditor.swift:124` | — | — | M | not started |

## Potty routine — child

| Screen | Source | Render | Cx | Status |
|---|---|---|---|---|
| `PottyRoutineView` | `PottyRoutineView.swift` | `07`, `08`, `16`–`20` | **H** | not started |
| `RoutinePauseView` | `RoutinePauseView.swift` | (in `07`) | M | not started |
| `RoutineCelebrationView` | `RoutineCelebrationView.swift` | `09` | **H** | not started |

One SwiftUI view drives five of the renders (`16`–`20` are its step contents).

## Progress

| Screen | Source | Render | Cx | Status |
|---|---|---|---|---|
| `ProgressDashboardView` | `ProgressDashboardView.swift` | `13`, `44` iPad, `40` empty | M | not started |

## Pond — child

| Screen | Source | Render | Cx | Status |
|---|---|---|---|---|
| `PondScreen` | `Features/Pond/PondScreen.swift` | `10` | **H** | not started |

`PondSceneView.swift` is **1,636 lines** with four `Canvas` layers and
`repeatForever` ambient motion — the single heaviest port in the app.

## Child hub

| Screen | Source | Native deps | Render | Cx | Status |
|---|---|---|---|---|---|
| `HopHubView` | `Features/ChildMode/HopHubView.swift` | ActivityKit | `45` | **H** | not started |

## Games — all child-facing, no native deps

| Screen | Source | Render | Cx | Status |
|---|---|---|---|---|
| `GamesScreen` | `GamesScreen.swift` | `21`, `30` dark | M | not started |
| `BubbleWashScreen` / `BubbleWashGameView` | `BubbleWashGame.swift` | `11`, `46`, `18` | **H** | not started |
| `PottyPathGameView` | `PottyPathGame.swift` | `22` | **H** | not started |
| `BathroomMatchGameView` | `BathroomMatchGame.swift` | `23` | **H** | not started |
| `FlySnackGameView` | `FlySnackGame.swift` | `24`, `29` | M | not started |
| `MudOffGameView` | `MudOffGame.swift` | `25` | **H** | not started |
| `BodySignalGameView` | `BodySignalGame.swift` | `26` | M | not started |
| `FlushWaveGameView` | `FlushWaveGame.swift` | `27` | M | not started |
| `PottyOrderGameView` | `PottyOrderGame.swift` | `28` | **H** | not started |

Seven run inside `GameHostView`; Bubble Wash bypasses it and is also the
routine's wash step.

> **Known divergence, pre-existing.** The app's `MudOffGameView` draws Hop
> full-body in the `.scrub` pose; render `25` draws close-up hands. The renders
> and the app disagree here. Resolve during the port — do not silently pick one.

## Quizzes

| Screen | Source | Render | Cx | Status |
|---|---|---|---|---|
| `QuizRoundView` | `QuizRoundView.swift` | `12` | **H** | not started |

## Profiles

| Screen | Source | Native deps | Render | Cx | Status |
|---|---|---|---|---|---|
| `ChildProfilesView` | `ChildProfilesView.swift` | StoreKit (paywall gate) | `35` | M | not started |
| `ChildProfileEditor` | `ChildProfileEditor.swift` | — | `32`* | M | not started |

## Settings

| Screen | Source | Native deps | Render | Cx | Status |
|---|---|---|---|---|---|
| `SettingsRootView` | `SettingsRootView.swift` | StoreKit, notifications, Screen Time | `34` | M | not started |
| `DestructiveConfirmationSheet` | `DestructiveConfirmationSheet.swift` | — | `38` | S | not started |
| `AcknowledgementsView` | `SettingsAuxiliaryViews.swift:53` | — | — | S | not started |
| `DebugLabPlaceholderView` | `SettingsAuxiliaryViews.swift:80` | — | — | S | not started |
| `ExportShareSheet` | `SettingsAuxiliaryViews.swift:13` | UIKit share sheet | — | S | not started |

## Purchases

| Screen | Source | Native deps | Render | Cx | Status |
|---|---|---|---|---|---|
| `PaywallView` | `PaywallView.swift` | StoreKit | `36` | M | not started |

## Developer (DEBUG only)

| Screen | Source | Native deps | Cx | Status |
|---|---|---|---|---|
| `PottyPauseLab` | `Developer/PottyPauseLab.swift` | Screen Time | M | not started |

Rebuild per §48 as the Screen Time developer lab, calling the real native
module on iOS.

---

## The hard-port set

Gesture-driven or continuously animated, and therefore the screens where a
naive React Native port will visibly regress:

`PondScreen` · `HopHubView` · `ParentHomeView` · `HopSplashView` ·
`RoutineCelebrationView` · `PottyRoutineView` · `ParentGateView` · all 8 games

These need Gesture Handler + Reanimated on the UI thread. Routing high-frequency
gesture updates through React state will not meet the bar.

## Mascot consumers

`HopCharacterStage` is used by: `MeetHopScreen`, `ReadyScreen`, `HopHubView`,
`QuizRoundView`, `PondSceneView`, `RoutinePauseView`, `RoutineStepStage`,
`RoutineCelebrationView`, `GameHostView` (→ 7 games), and all six game views
that draw him directly, plus `ParentHomeScene`.

Every one of these is served by the single `src/mascot/HopCharacter.tsx`. No
screen may inline mascot SVG.

## Coverage gaps

**18 SwiftUI screens have no render** — mostly flows and sheets:
`RootView`, `ParentAppRootView`, `ParentRootView`, `OnboardingFlowView`,
`IntervalScreen`, `AuthorizationScreen`, `QuietHoursScreen`,
`NotificationsScreen`, `TestPauseScreen`, `LogVisitSheet`, `QuietHoursEditor`,
`QuietWindowSheet`, `HubRoutineFlow`, `AcknowledgementsView`,
`DebugLabPlaceholderView`, `ExportShareSheet`, `PottyPauseLab`,
`RoutinePauseView`.

These have no visual reference, so their ports need design review rather than
pixel comparison.

**9 renders are variants, not distinct screens** — `14`/`15`/`30`/`44` are
dark/iPad variants; `16`–`20` are step contents of one view; `46` and `29` are
end beats.
