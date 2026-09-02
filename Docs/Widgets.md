# Widgets and Live Activities

**Date:** 2026-09-02
**Status:** Not verified on hardware. This repository has no Xcode, no simulator
and no device (`Docs/RepositoryAudit.md`), so nothing below has been rendered.
The domain layer — the snapshot, the builder and the timeline plan — is compiled
and tested on Linux with the rest of `HopPottyKit`. The SwiftUI is reviewed
against Apple's documentation and marked **UNVERIFIED** wherever that is all it
is.

| Marker | Meaning |
| --- | --- |
| *(no marker)* | Stated in Apple's documentation, or true of code in this repository. |
| **UNVERIFIED — confirm on device** | Not observed. Prove it on hardware. |
| **DESIGN** | HopPotty's choice, not a platform constraint. |

---

## 1. What ships

One widget extension, `Extensions/HopPottyWidgets`, containing two widgets:

| | Where it appears | What it is |
| --- | --- | --- |
| **Next Potty Pause** (`NextPauseWidget`) | Home screen `systemSmall`, `systemMedium`; lock screen `accessoryCircular`, `accessoryRectangular`, `accessoryInline` | A countdown to the next Potty Pause — or to a caregiver's Quick Reminder, whichever is sooner — with Hop's face beside it. |
| **Potty Pause** (`PottyPauseLiveActivity`) | Lock screen and Dynamic Island, only while a pause is running | How long is left, and which step of the routine the child is on. |

Both are drawn by the widget extension. Neither computes anything: the app
resolves a `WidgetSnapshot` and writes it into the App Group, and the extension
formats it.

---

## 2. What is shown, and what is deliberately not

### Shown

- **The next Potty Pause**, as an instant, counted down by the system.
- **A pending Quick Reminder**, as an instant. Carried separately from the pause
  because the two are different promises: a pause may hold a child's apps, a
  Quick Reminder never does.
- **Whether Potty Pause is switched on.** Distinct from "nothing is scheduled" —
  a schedule can be on and still have nothing to project.
- **Hop's face**, in one of five moods, which is the widget's way of saying "not
  yet / soon / now" without a second line of text.
- **A pause in progress**, and when it is expected to end.
- **Optionally, the child's name.** Off by default. See below.

### Not shown, and not to be added

| Not shown | Why |
| --- | --- |
| Potty events, outcomes, accidents, "3 successes today", streaks | A health record about a three-year-old, rendered at readable size on a locked phone to whoever is holding it. `Docs/PrivacyArchitecture.md` §2. |
| Stars, pond items, quiz or game progress | The child's reward economy is the child's, seen inside the app. A star count on a home screen is a score a sibling can read. |
| The names, icons or **number** of shielded apps | The Screen Time boundary. Only the shield-configuration extension can legibly see app identity, and it is forbidden from persisting or forwarding it (`Docs/ScreenTimeArchitecture.md` §3). A count is not identity, but "6 apps blocked" on a lock screen is still a statement about how a family runs their household. |
| The child's UUID, age, pronouns, avatar, or caregiver notes | Nothing about a child crosses the App Group boundary. `Docs/PrivacyArchitecture.md` §5. |
| The routine step's *title* | "Wipe" on a lock screen is a fact about a three-year-old's morning, published to the room. The Live Activity shows `3 / 5` and no words. |
| Any control — skip, pause, start now | Every action with consequences is behind the parent gate (`Docs/CONTRACTS.md` §4.6). A button on a lock screen is not. |
| A `widgetURL` deep link | HopPotty declares no URL scheme at all: "a parental-controls app that can be driven from a link is a parental-controls app a child can drive" (`HopPotty/App/Info.plist`). Tapping the widget opens the app, which is the system default. |

### The child's name

`WidgetSnapshot.childDisplayName` exists, and is `nil` unless somebody asks for
it twice: `WidgetSnapshotBuilder` takes the nickname *and* a separate
`includeChildName` flag, and `WidgetRefreshService` is constructed with
`showsChildName: false`.

**DESIGN.** A widget is legible from a locked screen by anyone holding the
phone. The same name inside the app sits behind a parent gate; on a lock screen
it does not. So the neutral phrasing is the default — the same fallback every
other HopPotty surface uses for a family who never typed a nickname — and turning
it on is a caregiver's explicit choice.

**Not yet built:** the settings toggle that flips it. `showsChildName` is a
constructor parameter so the switch has somewhere to be wired to when the
settings screen gains one.

---

## 3. The timeline budget

WidgetKit does not redraw a widget when the app asks. It redraws when the system
decides, out of a daily allowance the system does not publish. A timeline asking
for an entry a minute all day is a timeline whose allowance is gone by lunchtime,
and a widget with no allowance left shows this morning's answer at bedtime.

`WidgetTimelinePlan` (in `HopPottyCore`, tested on Linux) shapes the plan like
the thing it describes:

| Distance to the next appointment | Entry every |
| --- | --- |
| more than 10 minutes | 15 minutes (`coarseStep`) |
| inside 10 minutes (`fineWindow`) | 1 minute (`fineStep`) |

plus the appointment itself, one entry a minute past it so the widget flips to
"now" without waiting to be asked, and a hard stop at a **4-hour horizon**. The
ceiling is 40 entries; the shape tops out around 28, so the ceiling is a backstop
against a future edit rather than a limit anything reaches.

**The countdown itself costs nothing.** `Text(date, style: .timer)` and
`Text(date, style: .relative)` are rendered by the system from a date: they keep
ticking with no entry, no reload and nothing charged against the budget. The
entries exist only for what a date cannot animate — which face Hop is wearing,
and the moment the words have to change.

That is why the fine window is *ten minutes* rather than an hour.
`WidgetSnapshotBuilder.approachWindow` is the instant Hop changes from waiting to
waving, and it is the same constant. A test asserts the two stay equal
(`WidgetSnapshotBuilderTests.windowsAgree`), because a gap between them is either
refreshes that redraw nothing or a change nobody scheduled a refresh for.

The reload policy is `.after(WidgetTimelinePlan.refreshDate(...))` — the last
entry — so a timeline is renewed exactly as it runs out.

**Staleness.** A snapshot more than 12 hours old is not drawn.
`WidgetSnapshotStore.loadForDisplay` substitutes the empty state instead.
"Next pause 09:15" at six in the evening is worse than showing nothing, because a
caregiver reads the first as a fact and the second as a prompt to open the app.

---

## 4. Hop, at widget size

**DESIGN.** The widget draws the real mascot — the head from
`Art/character/hop-{idle,wave,jump,cheer,sleep}.svg`, one file per
`HopWidgetMood` — without using `HopCharacterView` and without bundling any art.

`project.yml` gives the three Screen Time extensions four shared source files and
`HopPottyCore`, and nothing from `HopPotty/DesignSystem`. The
shield-configuration extension — the one other place a HopPotty extension draws
anything — follows the same rule: it reads pre-resolved strings and colours out
of the App Group. This widget keeps that boundary, because:

- a widget is redrawn from an archived view hierarchy, so `HopCharacterView`'s
  ambient motion, blink timer and pose animation are inert;
- pulling the design system into a widget target means pulling the shape layer,
  the theme environment and the glyph layer into a memory-limited process to draw
  one frog at thumbnail size.

So Hop crosses the boundary as **data**. `Scripts/widget-face.js` reads the
shipped art, takes everything from the crown ellipse onward — which in
`Scripts/hop-art.js` is exactly the head, the face and the sleeping z's —
resolves it to absolute coordinates and emits it into
`Extensions/HopPottyWidgets/HopWidgetFaceArt.swift` as `M`/`L`/`C`/`Q`/`Z` path
data. `HopWidgetFace` decodes that into `Path`s. It is the arrangement the splash
screen's lockup already uses (`Scripts/logo-art.js` → `HopLogoArtwork.swift`),
for the same reason: a drawing a diff can review, in a target that cannot have
the drawing.

Nothing about it is typed by hand, and two checks keep it that way:

- `node Scripts/widget-face.js --check` renders the emitted coordinates back over
  the artwork they came from and measures the difference — every mood over its
  own pose, and `idle` over `hop-face.svg`, which `hop-art.js` draws
  independently from the same anatomy;
- `Scripts/verify-config.sh` compares a digest of the five art files against the
  one recorded in the generated header, so art regenerated without re-running the
  generator is reported rather than shipped.

Colour comes from `HopPalette`, as before: the generator matches every fill in
the art back to a token *by value* and emits a role, and `HopWidgetFace` maps the
role to the token. Two of the face's colours — the mid-green of the forehead
spots and the tongue's pink — have no brand token and are carried as values, the
same two `HopCharacterPalette` declares that way in the app.

**The accessory families are the hard case.** Lock-screen widgets and the Dynamic
Island are composited into a single-colour vibrant layer, which keeps roughly
each colour's luminance and discards its hue. Handing that the coloured drawing
makes Hop's dark pupils and dark mouth — the two things that make a face a face —
the *dimmest* things on screen; what survives is a pale disc.
`HopWidgetFace(isMonochrome: true)` therefore paints the same geometry as a
stencil: `Color.primary` at a tone per part, inverted (the drawing's darkest
parts are the brightest here), stepped so each feature contrasts with the one
under it, with anything under a point across dropped and a floor under the stroke
widths. The table is in `HopWidgetFace.swift` under `MARK: Stencil`, and
`node Scripts/widget-face.js --sheet` renders it over a wallpaper at every size
the widget uses — beside what the naive version would have looked like.

---

## 5. Why this extension holds no Family Controls entitlement

`Extensions/HopPottyWidgets/HopPottyWidgets.entitlements` declares **one**
capability: the App Group. It deliberately does **not** declare
`com.apple.developer.family-controls`.

The other three extensions need it because they touch ManagedSettings,
ManagedSettingsUI or DeviceActivity. This one draws a countdown from a JSON file.
Granting it would mean a fifth App ID in the Family Controls distribution request
(`Docs/Entitlements.md` §2), a widget process linking frameworks it never calls,
and the capability handed to the one HopPotty target rendered on a locked screen.
All cost, no function.

The same reasoning shapes the file set. The widget does **not** compile
`ScreenTimeIdentifiers.swift`, `AppGroupStore.swift`, `SharedPauseTypes.swift` or
`ShieldReconciler.swift` — those import ManagedSettings and DeviceActivity.
Instead it compiles `WidgetSnapshotStore.swift`, which is Foundation and
WidgetKit only and re-declares the one constant it needs:

```swift
public static let widgetAppGroupID = "group.com.hoppotty"
```

That duplication is only safe while something checks it.
`Scripts/verify-config.sh` compares it against `HOPPOTTY_APP_GROUP` in
`Config/Base.xcconfig` and, transitively, against
`ScreenTimeIdentifiers.appGroupID`. A drift is silent, total, and looks exactly
like a broken widget.

No `aps-environment` either. HopPotty has no server and no push entitlement, so
`Activity.request` is called with `pushType: nil` and every Live Activity update
happens in-process while the app is running.

---

## 6. How the snapshot gets written

```
                     ┌────────────────────────────┐
   schedule edit ───▶ │  WidgetRefreshService      │
   foreground    ───▶ │  (app, ServiceContainer)   │─┐
   reminder set  ───▶ └────────────────────────────┘ │
                                                     │  widget.json
   pause starts ────▶ ┌────────────────────────────┐ │  (App Group)
   with app closed    │ HopPottyDeviceActivity     │─┤
                      │ MonitorExtension           │ │
                      └────────────────────────────┘ │
                                                     ▼
                                        ┌──────────────────────────┐
                                        │  HopPottyWidgets         │
                                        │  NextPauseProvider       │
                                        └──────────────────────────┘
```

Three writers, one reader.

1. **`WidgetRefreshService`** (`HopPotty/Services/Widgets/WidgetRefreshing.swift`)
   is the ordinary path. It reads the active child from `AppSettings`, its
   schedule from the repository, projects with `PottyScheduleService`, and hands
   the lot to `WidgetSnapshotBuilder`. Called from `ServiceContainer.start()` and
   `ServiceContainer.refresh()` via `refreshWidget()`, which is also where the
   Quick Reminder feature is joined to it — deliberately in the container rather
   than inside the widget layer, so the widget never reaches into another
   feature's store.

2. **`PottyPauseEffectExecutor`** calls `scheduleDidChange()` after
   `registerMonitoring` / `cancelMonitoring`, and `pauseDidStart` /
   `pauseDidEnd` around the shield. Injected as optionals defaulted to `nil`:
   a build that wires neither behaves exactly as it did before they existed.

3. **The DeviceActivity monitor extension** writes when it starts a pause with
   the app closed, and when it clears one. This matters more than it looks: a
   clock schedule can fire at 10:00 with the app closed and stay closed until
   bedtime, and without this the home screen would count down to a pause that
   already happened and keep counting through the pause itself. `WidgetCenter` is
   available to app extensions, which is what makes it possible.

Every one of those calls is best-effort. **Nothing about a pause depends on the
widget.** A refresh that fails, a spent budget, an unreachable container — none
of them changes what happens to a child's device.

"Delete everything" clears `widget.json` (`DataDeletionService.resetApp`),
because a countdown for a child who no longer exists is the one piece of HopPotty
a caregiver could still see after asking for it all to go.

---

## 7. Copy

Every string comes from `HopCopy` in `HopPottyCore`, which the widget process
links:

| Surface | Entry |
| --- | --- |
| "Next Potty Pause" | `parentHome.hero.title` |
| "Potty Pause is off" | `parentHome.hero.disabled` |
| "Nothing waiting right now." | `quickReminder.emptyState` |
| "Quick Reminder" | `quickReminder.title` |
| "Potty time!" | `shield.title` |
| "Your game comes back soon." | `shield.returning` |
| Widget gallery description | `brand.tagline` |

Two exceptions, both recorded here rather than hidden:

- **`quickReminder.emptyState` is reused off-surface.** It stands in for "the
  schedule is on but there is nothing to project", which is true whatever the
  reason — a skipped pause, a closed active window, a quiet hour — and the
  snapshot deliberately does not carry which, because that is a fact about a
  family's day.
- **The routine step position is formatted as `3 / 5`**, from two integers, in
  `PottyPauseActivityCopy`. Not yet a catalogue entry.

Neither justifies adding a `widget` surface to `HopCopySurface`: that is a schema
change to the copy catalogue, and it should be made once, deliberately, with the
strings a designer actually wants rather than the seven borrowed above.

---

## 8. Live Activity lifecycle

```
   applyShield succeeds
        │
        ├─ monitoring.registerBackstop(for: record)      ← safety first
        ├─ liveActivities.start(sessionID:…)             ← courtesy second
        └─ widgets.pauseDidStart(endingAt:)
                     │
                     │   routine advances a step
                     │        └─ liveActivities.update(stepIndex:…)
                     │
   any clearShield path
        │
        ├─ liveActivities.end(at:)                       ← retracted FIRST
        ├─ widgets.pauseDidEnd()
        └─ screenTime.clearShield(reason:)
```

The asymmetry is the design.

**Start is best-effort and late.** It happens only after the shield is up and
the backstop is armed, because an announcement of a pause that failed to start
tells a caregiver their child's apps are held when they are not.

**End is unconditional and early.** It happens *before* the clear is attempted,
on every path. A Live Activity that outlives its pause is the one failure this
layer can actually cause. If the clear then fails, the machine lands in
`errorRequiresParent(.shieldClearFailed)` and the caregiver gets a screen with a
"Restore Screen Access" button on it — which is a better thing to be looking at
than a countdown.

`end` also sweeps `Activity<PottyPauseAttributes>.activities`, so an activity
left behind by a process that was killed mid-pause is cleared by the next launch
that ends anything.

Other details:

- **`plannedEndAt`, never `backstopEndAt`.** The backstop is the 15-minute
  ceiling under the worst case (`Docs/ScreenTimeArchitecture.md` §9); putting it
  on a lock screen would tell a family a three-minute pause lasts a quarter of an
  hour.
- **No per-second updates.** `Text(timerInterval:countsDown:)` and
  `ProgressView(timerInterval:)` are drawn by the system from a `ClosedRange<Date>`
  in the content state. ActivityKit budgets updates; spending one a second on a
  number the system already draws would leave nothing for the routine step that
  actually changes.
- **`staleDate` is the expected end plus two minutes.** A stale date is the
  promise "after this, do not trust what is on screen", and here the thing on
  screen is a claim about whether a child's apps are held.
- **`NSSupportsLiveActivities`** is in the **app's** Info.plist, not the
  extension's. The app starts activities; the extension only draws them. Without
  the key every `Activity.request` throws and the lock screen simply stays empty
  — indistinguishable from a family who switched the feature off, which is why
  `Scripts/verify-config.sh` checks for it.

### The routine step, and how it gets here

`LiveActivityController.update(stepIndex:…)` **is wired.** The path is four
hops, and every one of them carries two integers and nothing else:

```
PottyRoutineView        model.stage changes (and once on appear)
     │                  onStepChange(currentStepNumber - 1, stepCount)
     ▼
HubRoutineFlow          passes the closure straight through
     ▼
HopHubView              guard liveActivities.isRunning
     │                  liveActivities.update(stepIndex:stepCount:
     ▼                                        expectedEndAt: nil, mood: .cheer)
LiveActivityController  guard let activity  → Activity.update(content)
```

- **Zero-based at the boundary.** `PottyRoutineModel.currentStepNumber` is
  1-based, because it feeds the step indicator and its VoiceOver label;
  `ContentState.stepIndex` is 0-based. The conversion happens in exactly one
  place, in `PottyRoutineView.reportStep()`.
- **Two guards, not one.** `HopHubView` checks `isRunning` before calling, and
  the controller checks its own `activity` again. The routine is a door on Hop's
  screen that a child can open at any time, so most runs of it have no pause and
  no activity behind them at all — that has to cost nothing rather than throw.
- **Still no titles.** Only the index and the count cross into the activity.
  §2 of this document is the reason, and it has not changed: a Live Activity is
  drawn on a locked screen. The widget process has `PottyRoutineContent`
  compiled in and could render the words itself if that ever became the right
  call; the app does not send them.
- **`.cheer`, the mood the activity started with.** `update` writes
  `hopPoseName` on every call, so passing anything else here would make Hop
  change face on every step for no reason a caregiver could explain.

---

## 9. Testing

### On Linux, now

```
cd HopPottyKit && swift test
```

`WidgetSnapshotTests`, `WidgetSnapshotBuilderTests` and `WidgetTimelinePlanTests`
cover the snapshot's shape, the builder's mood and resolution rules, and every
edge of the timeline plan — including two tests that are really privacy
assertions: `onlyOneStringField` and `snapshotCarriesNoHistory` encode the field
list, so adding anything to the App Group payload breaks a test rather than
shipping quietly.

### Configuration, now

```
Scripts/verify-config.sh
```

Checks the widget's extension point identifier, the *absence* of a principal
class, the presence of `@main` and a `WidgetBundle`, that the Live Activity
attributes are compiled into the app target as well, that
`NSSupportsLiveActivities` is on the app and not on the extension, that the
widget holds the App Group and does **not** hold Family Controls, and that
`widgetAppGroupID` matches the xcconfig.

### On a device — the parts nothing here can prove

1. **Extension point identifier.** Create a Widget Extension target in Xcode with
   "Include Live Activity" ticked, and diff the generated `Info.plist` against
   `Extensions/HopPottyWidgets/Info.plist`. If they differ, Xcode is right.
   **UNVERIFIED — confirm on device.**
2. **The widget appears in the gallery** after a build, and each of the five
   families renders without clipping at the largest Dynamic Type size.
3. **Lock screen legibility.** All three accessory families, in both the tinted
   and the untinted lock screen styles, and against a photo wallpaper.
4. **The countdown ticks with the app killed.** Force-quit HopPotty, watch the
   small widget for two minutes. `Text(_:style:.timer)` should keep counting;
   Hop's face should not change until a timeline entry lands.
5. **The minute-by-minute window.** With a pause 12 minutes out, confirm the face
   changes to waving at 10 minutes and to jumping at 2, and that nothing redraws
   in between beyond the clock.
6. **The extension path.** Set a clock schedule, force-quit the app, leave the
   phone alone until the pause fires. The widget must show the pause running
   without the app being opened. This is the single most valuable test here, and
   it is the one that cannot be simulated.
7. **Live Activity.** Start a pause and check the lock screen, the Dynamic Island
   compact and minimal presentations, and the expanded presentation (long-press).
   End the pause four ways — the routine completing, the timer expiring, a
   caregiver override, and a force-quit followed by a relaunch — and confirm the
   activity is gone every time.
8. **Live Activities off.** Settings › Face ID & Passcode › Live Activities off,
   or the per-app switch. Start a pause. Everything must work; only the lock
   screen is empty.
9. **App Group unreachable.** Break `HOPPOTTY_APP_GROUP` in a scratch build. The
   widget must draw the empty state rather than a placeholder that looks like
   real data.
10. **Delete everything**, then look at the home screen. The widget must be empty
    within one refresh.

`Docs/PhysicalDeviceQA.md` is where these belong once someone has a device.
