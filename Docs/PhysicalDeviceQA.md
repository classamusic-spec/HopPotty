# Physical Device QA — Screen Time layer

**Status: NOTHING IN THIS DOCUMENT HAS BEEN OBSERVED.**

Every "Expected" below is a hypothesis derived from Apple's documentation
(`Docs/ScreenTimeArchitecture.md`) or from HopPotty's own design. This repository
has no Xcode, no simulator and no iOS device (`Docs/RepositoryAudit.md`), so no
Screen Time behaviour has ever been run, let alone verified. The **Observed**
column is empty on purpose and is the only column that will ever constitute
evidence.

A test that has not been run is not a test that passed.

---

## How to use this document

1. Work top to bottom. Later sections assume earlier ones passed.
2. Fill in **Observed** with what actually happened, in words, not a tick. "Shield
   appeared after ~2s, Hop icon rendered, buttons read 'I'm going!' / 'Ask a
   grown-up'" is a result. "OK" is not.
3. When Observed differs from Expected, record it and stop treating the
   downstream sections as meaningful until it is understood.
4. Every `// UNVERIFIED — confirm on device:` comment in the source has a
   corresponding step here. When you resolve one, delete the comment in the same
   commit that fills in the row, and update
   `Docs/ScreenTimeArchitecture.md` §12.

### Devices

Run the whole plan on at least two devices, because several open questions
(callback punctuality, store persistence across reboot) are plausibly
OS-version-dependent.

| | Device | iOS version | Apple Account region | Date | Tester |
| --- | --- | --- | --- | --- | --- |
| A | | | | | |
| B | | | | | |

### Prerequisites

- A real Apple Account signed in on the device. Family Controls needs one.
- A device passcode set (`FamilyControlsError.authenticationMethodUnavailable`
  exists specifically for devices without one).
- No other parental-controls app authorized on the device — that produces
  `.authorizationConflict`, which §4.4 tests deliberately later.
- A DEBUG build, so the Potty Pause Lab is reachable (long-press the parent home
  screen for 2 seconds). A release build **must not** be able to reach it; §12.1
  checks that.

---

## 1. Fresh install

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 1.1 | Delete HopPotty if present. Restart the device. Install a fresh DEBUG build. | Installs. | |
| 1.2 | Launch. Do not tap anything. | No system authorization prompt appears. HopPotty does not ask before onboarding has explained why. | |
| 1.3 | Open the Potty Pause Lab. Read **Environment**. | `Container: reachable`. If it says UNREACHABLE, the App Group entitlement or `ScreenTimeIdentifiers.appGroupID` is wrong — stop and fix; every later result is meaningless. | |
| 1.4 | Read **Authorization → Status**. | `notDetermined`. | |
| 1.5 | Read **Extension heartbeats**. | `app` has a timestamp. The other three read `— never —`. Correct at this point: no extension has been invoked yet. | |
| 1.6 | Read **App Group dump**. | `— no pause record —`, no selection payload, 0 reports. | |

---

## 2. Configuration sanity

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 2.0 | Run `bash Scripts/verify-config.sh`. | All checks pass. It cross-checks the App Group and all four bundle IDs between `Config/Base.xcconfig` and `ScreenTimeIdentifiers.swift`, confirms the four shared files are members of all three extension targets, and confirms Release defines neither `DEBUG` nor `HOPPOTTY_DEBUG_TOOLS`. Anything it catches is cheaper to fix before the device is out of the drawer. | |
| 2.1 | Lab → Environment. Compare the `ManagedSettings store` row with the name in the entitlement/source. | Both read `hoppotty.pottypause`. | |
| 2.2 | Confirm the DEBUG assertion in `ShieldReconciler.assertStoreNamesAgree()` did not trip on launch. | No assertion failure. If it trips, check whether `String(describing:)` on `ManagedSettingsStore.Name` actually contains the name — the assertion may be the thing that is wrong, not the names. | |
| 2.3 | Confirm all four targets list the same App Group in their entitlements. | Identical strings. | |

---

## 3. Authorization

### 3.1 Granted

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 3.1.1 | Lab → **Request authorization**. | System sheet appears asking a grown-up to allow Screen Time access. | |
| 3.1.2 | Approve it. | `Last action: requestAuthorization → ok`. Status becomes `approved`. `Can shield: yes`. | |
| 3.1.3 | Force-quit. Relaunch. Read Status. | `approved`. **This is the important one:** Apple documents `authorizationStatus` as `.notDetermined` at every launch until a request succeeds, so HopPotty re-requests silently when it has previously been granted. If this reads `notDetermined`, `restoreAuthorizationIfPreviouslyGranted()` is not being called or the silent re-request shows UI. | |
| 3.1.4 | Note whether step 3.1.3 flashed any system UI. | No UI. | |
| 3.1.5 | Try to delete HopPotty from the Home Screen while authorized. | iOS refuses — a documented consequence of holding authorization. Record exactly what the user sees, because caregivers will hit this and support needs the wording. | |

### 3.2 Denied

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 3.2.1 | Revoke via Lab → **Revoke authorization**. Then **Request authorization** and decline the sheet. | Status stays `notDetermined` (a cancel is not a denial). `Last action` shows `ok`, not an error. | |
| 3.2.2 | If the OS produces a true `denied` state, record how. | Status `denied`, `Retry could help: yes`. | |
| 3.2.3 | With authorization absent, Lab → **Trigger a pause now**. | `applyShield → authorizationRevoked`. No shield. No pause record. | |

### 3.3 Revoked mid-pause — the one that matters

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 3.3.1 | Authorize, select apps (§4), start a 10-minute pause via the Lab. Confirm the shield is up. | Shield visible on a selected app. | |
| 3.3.2 | Without quitting HopPotty, go to Settings and turn off Screen Time / remove the authorization. | | |
| 3.3.3 | Return to HopPotty. | The apps are usable again. `ScreenTimeService.setStatus` clears everything the moment it observes a non-shielding status. Lab shows no pause record and an empty selection. | |
| 3.3.4 | Record how long between revoking and the apps working. | | |
| 3.3.5 | Record whether the change arrived via `AuthorizationCenter.$authorizationStatus` while backgrounded, or only on foreground. | Either is acceptable; the answer decides whether the publisher can be relied on. | |
| 3.3.6 | Check whether iOS itself removed the shield when authorization was revoked, independently of HopPotty. | Undocumented. Record the answer — it determines how much of §3.3.3 is HopPotty and how much is the system. | |

### 3.4 Restricted / conflicted

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 3.4.1 | Install a second parental-controls app and authorize it. Then request authorization in HopPotty. | `FamilyControlsError.authorizationConflict` → `Last action: authorizationConflict`. | |
| 3.4.2 | On a supervised/MDM device, or one already enrolled as a child device, request authorization. | `FamilyControlsError.restricted` → Status `restricted`, `Retry could help: no`. | |
| 3.4.3 | Sign out of the Apple Account and request. | `invalidAccountType`. | |
| 3.4.4 | Remove the device passcode and request. | `authenticationMethodUnavailable`. | |
| 3.4.5 | Turn on Airplane Mode and request. | `networkError`. | |
| 3.4.6 | For every case above, record the **exact `FamilyControlsError` case name** the SDK actually produces. | Confirms or corrects `ScreenTimeService.map(_:)`, whose case spellings are UNVERIFIED. | |

---

## 4. Selection

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 4.1 | With authorization approved, open the caregiver picker and choose 3 apps and 1 category. | Picker shows apps and categories from this device. | |
| 4.2 | Lab → **Selection**. | Applications 3, Categories 1, Web domains 0, Total 4. Within 50-token cap: yes. Payload on disk: present. | |
| 4.3 | Confirm the Lab shows **no app names anywhere**. | Counts only. If a name appears, a privacy rule has been broken — stop. | |
| 4.4 | Force-quit, relaunch, re-open the Lab. | Same counts. The encoded `FamilyActivitySelection` round-tripped. | |
| 4.5 | Update the app over the top (new build, same signing). | Counts survive? Record. **UNVERIFIED.** | |
| 4.6 | Delete and reinstall HopPotty. | Counts are 0 and the caregiver is routed back to the picker. Tokens do not survive a reinstall. Record what actually happens — a decode failure and a stale-but-decodable blob are very different outcomes. | |
| 4.7 | Attempt to select more than 50 apps. | HopPotty refuses and explains, rather than applying a shield of unknown behaviour. Record what iOS does if you force it past the cap by other means. **UNVERIFIED.** | |

---

## 5. Trigger reached — screen activity

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 5.1 | Lab → Monitoring → Basis `screenActivity`, Interval 10 min. **Register plan**. | `register → 1 activity`. `hoppotty.usage` appears under "System reports". | |
| 5.2 | Read the **note** rows. | None for a 10-minute usage interval. | |
| 5.3 | Quit HopPotty entirely. Use a selected app continuously for 10 minutes. | The shield appears without HopPotty being opened. | |
| 5.4 | Record the delay between 10 minutes of use and the shield appearing. | | |
| 5.5 | Reopen the Lab → **Extension heartbeats**. | `monitor` has a timestamp. If it reads `— never —` after a shield appeared, the monitor extension is not installed, not signed, or not a member of the App Group. | |
| 5.6 | Lab → **Drain reports**. | Reports include `monitor/eventDidReachThreshold` and `monitor/pauseStarted`. | |
| 5.7 | Continue using the device for another 10 minutes of accumulated time. | A **second** pause fires. This is the whole reason for the event ladder — if only one pause ever fires per day, the ladder is not working and `MonitoringPlan.usagePlan` is wrong. | |
| 5.8 | Put the device down for 20 minutes without using it. | **No** pause fires. Thresholds count foreground usage, not wall-clock time. | |
| 5.9 | Switch to an app that is **not** selected and use it for 15 minutes. | A pause still fires: HopPotty's events specify no applications, so they accumulate across everything. Confirm — if it does not, the "child avoids every pause by switching apps" hole is open. **UNVERIFIED.** | |
| 5.10 | Record the finest interval at which a threshold reliably fires (try 10 min). | Apple documents no minimum threshold granularity. **UNVERIFIED.** | |

---

## 6. Trigger reached — clock time

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 6.1 | Lab → Basis `clockTime`, Interval 15 min. **Register plan**. | Several `hoppotty.clock.N` activities, at most 8. | |
| 6.2 | Set Interval to 10 min and re-register. | A note row reads `cadence 10m → 15m (platform floor)`. A caregiver must be told this; confirm the parent UI says it too, not just the Lab. | |
| 6.3 | Quit HopPotty. Wait for the next slot with the device in use. | Shield appears at the slot time. | |
| 6.4 | Repeat with the device **asleep** across the slot, then wake it. | Apple gates `intervalDidStart` on the device being in use. Record how late the pause is. A pause that fires 40 minutes late when a child picks the device back up may be worse than one that does not fire — record it as a product question, not just a number. | |
| 6.5 | Configure a quiet window covering the next slot. Re-register. | That slot is not registered at all. No pause during the quiet window. | |
| 6.6 | Re-register several times in a row. | Activity count stays the same. No accumulation, no orphans. | |

---

## 7. The shield itself

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 7.1 | With a pause active, open a shielded app. | HopPotty's shield, not Apple's default. | |
| 7.2 | Read the title. | "Potty time!" | |
| 7.3 | Read the subtitle. | "Let's hop to the potty. Your game will be here when you get back." | |
| 7.4 | Read both button labels **verbatim**. | Whatever `HopCopy` resolves — currently "I'm going!" and "Ask a grown-up". | |
| 7.5 | Compare with the Lab's `primary: HopCopy / fallback` and `secondary:` rows. | If they are red, the compiled-in fallback disagrees with `HopCopy`. **This is a known, deliberately unresolved conflict** — see `ShieldPresentation.fallback`. One of the two must change before shipping. Record which was chosen. | |
| 7.6 | Confirm the words "blocked", "denied", "limit", "restricted" and "not allowed" appear nowhere on the shield. | They do not. If they do, the system default shield is being shown — meaning the configuration extension was too slow or crashed. | |
| 7.7 | Check the background. | Cloud (#FFF9F2). Record whether the shielded app is visible through it — `backgroundBlurStyle` is `nil` and it is **UNVERIFIED** whether that yields a solid background. | |
| 7.8 | Check the icon. | The programmatic Hop face renders. Note: this is a placeholder and must be replaced with a pre-rendered PNG before shipping. | |
| 7.9 | Check the primary button colour. | Hop Green (#63C88A) with Midnight text. | |
| 7.10 | Home Screen: look at a shielded app's icon. | Dimmed, with an hourglass. | |
| 7.11 | Switch the device to Dark Mode and re-open a shielded app. | Record whether the colours change. **UNVERIFIED** whether dynamic `UIColor` resolves in this extension. | |
| 7.12 | Time from tapping a shielded app to the shield being fully drawn. | Record. A slow data source causes the system to substitute its own screen. | |
| 7.13 | Lab → heartbeats. | `shieldcfg` has a timestamp. | |

---

## 8. Shield actions

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 8.1 | With a pause active, tap the **primary** button. | The pause ends. | |
| 8.2 | Record **where you land**: Home Screen, or the app you were in. **UNVERIFIED.** | | |
| 8.3 | Immediately re-open the same app. | It opens normally. No shield. | |
| 8.4 | Record whether the shield visibly disappeared, redrew, or froze before closing. **UNVERIFIED.** | | |
| 8.5 | Open HopPotty. | The star for finishing is awarded now, on drain — not at the moment of the tap. Confirm the child-facing copy never promised an immediate star. | |
| 8.6 | Lab → Drain reports. | `shieldAction/shieldPrimaryButtonTapped` and `shieldAction/pauseEnded` with outcome `completedRoutine`. | |
| 8.7 | On iOS 26.5+, repeat 8.1. | HopPotty comes forward (`.openParentalControlsApp`). If the build does not compile against that case, delete the block — `.close` is the shipping behaviour. | |
| 8.8 | Start a new pause. Tap the **secondary** button. | The shield **stays up**. Nothing unlocks. This is deliberate: a three-year-old is holding the device. | |
| 8.9 | Open HopPotty. | A grown-up request is waiting, surfaced behind the parent gate. | |
| 8.10 | Wait out the remainder of that pause without touching anything. | It ends on its own timer. Contract §4.1: the secondary button never traps a child. | |
| 8.11 | Lab → heartbeats. | `shieldact` has a timestamp. | |

---

## 9. Restore — manual and automatic

### 9.1 Automatic, intended duration

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 9.1.1 | Lab → Test pause 60 s → **Trigger a pause now**. Quit HopPotty. Keep using a shielded app. | The shield lifts at about 60 seconds. | |
| 9.1.2 | Record the actual elapsed time. | This measures `intervalWillEndWarning` punctuality — **the single most important UNVERIFIED item in the layer.** If it fires many minutes late, the intended pause duration is not deliverable while HopPotty is closed and the product's minimum pause must change to match. | |
| 9.1.3 | Repeat with a 5-minute pause. | | |
| 9.1.4 | Repeat with the device untouched across the intended end, then pick it up. | Record the delay. Callbacks may be gated on the device being in use. | |

### 9.2 Automatic, the 15-minute backstop

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 9.2.1 | Start a pause. Use the Lab to confirm `hoppotty.backstop` is registered. | Present. | |
| 9.2.2 | Leave the device alone for 16 minutes, then use a shielded app. | The shield is gone. Path (C). | |
| 9.2.3 | Lab → Drain reports. | `monitor/pauseEnded` with clear reason `backstopElapsed`. | |

### 9.3 Manual — the emergency path

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 9.3.1 | Start a 10-minute pause. In HopPotty, use "Restore Screen Access" behind the parent gate. | Apps work immediately. | |
| 9.3.2 | Record the elapsed time from tap to a shielded app opening. | | |
| 9.3.3 | Lab → Monitoring. | Zero HopPotty activities. `restoreScreenAccess` cancels monitoring too, so nothing re-raises the shield a moment later. | |
| 9.3.4 | Press "Restore Screen Access" again with nothing shielded. | Nothing breaks. Idempotent. | |
| 9.3.5 | Press it five times rapidly. | Nothing breaks. | |
| 9.3.6 | Turn Potty Pause off entirely in Settings during a pause. | Shield clears, monitoring stops. | |

---

## 10. Fail-safe — the section this whole layer exists for

Every step here stages a way a shield could outlive its session. **A shield still
standing at the end of any of these is a release blocker, not a bug.**

### 10.1 App force-quit mid-pause

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 10.1.1 | Start a 5-minute pause. Force-quit HopPotty from the app switcher. | | |
| 10.1.2 | Open a shielded app. | Shield still up (correct — the pause is genuine and has not expired). | |
| 10.1.3 | Wait past 5 minutes, then open a shielded app. | Shield gone, cleared by the monitor or by the shield configuration extension. | |
| 10.1.4 | Reopen HopPotty. | Lab shows no pause record; a report exists explaining the end. | |

### 10.2 Stranded shield — no session at all

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 10.2.1 | Lab → **Shield now (no session)**. This raises a shield and deletes the record behind it. | Lab says `orphan shield staged — expect auto-clear`. | |
| 10.2.2 | Open a shielded app **without touching HopPotty**. | The shield either does not appear, or appears once and is gone on retry. The shield configuration extension reconciles when the system asks it to draw. **UNVERIFIED** whether a store write from that extension is honoured — this step is the test. | |
| 10.2.3 | If it did appear, tap either button. | The shield action extension clears it and returns `.close`. | |
| 10.2.4 | Reopen HopPotty. | Reconciliation on foreground clears anything left. Lab: verdict `clear(noSession)`. | |
| 10.2.5 | Record **which of the three paths** actually did the clearing. | This tells us how much the design depends on the unverified configuration-extension write. | |

### 10.3 Device restart mid-pause

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 10.3.1 | Start a 10-minute pause. Confirm the shield. Power the device off and on. | | |
| 10.3.2 | Before opening HopPotty, open a shielded app. | **Record whether the shield survived the reboot at all** — Apple documents neither answer, and this is UNVERIFIED item 1. | |
| 10.3.3 | Whatever the answer, the shield must not persist. | `ProcessInfo.systemUptime` has reset, so `ShieldReconciler` returns `clear(deviceRestarted)` at the first opportunity. | |
| 10.3.4 | Open HopPotty. Lab → last clear reason. | `deviceRestarted`. | |
| 10.3.5 | Confirm the caregiver is told the apps were unlocked after an interruption. | A `ParentNotice.accessRestoredAfterInterruption` surfaces. From the child's side the apps silently came back; somebody should know why. | |

### 10.4 Clock moved backwards

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 10.4.1 | Start a 10-minute pause. Settings → General → Date & Time → turn off Set Automatically → move the clock back 2 hours. | | |
| 10.4.2 | Open a shielded app, then HopPotty. | Shield cleared. Verdict `clear(clockMovedBackwards)`. Without this rule a backwards clock would make `plannedEndAt` unreachable and the pause effectively permanent — the single most dangerous clock bug available. | |
| 10.4.3 | Restore automatic time. | | |
| 10.4.4 | Repeat, moving the clock **forward** 2 hours mid-pause. | Shield clears immediately: `plannedEndAt` has passed. Erring early, never late. | |

### 10.5 Time zone and DST

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 10.5.1 | Start a 10-minute pause. Change the device time zone by +8 hours mid-pause. | The pause still ends 10 minutes after it began. Instants are absolute; a change of zone cannot reinterpret one. | |
| 10.5.2 | With a `clockTime` schedule registered, change the time zone. | Pause slots follow the new local wall clock. That is what a family flying to another country expects. | |
| 10.5.3 | Set the device to the day before a DST spring-forward with a slot inside the skipped hour. | That slot does not occur. The next one does. A missing hour may delay a pause; it can never extend one. | |
| 10.5.4 | Repeat for a DST fall-back with a slot inside the repeated hour. | Record whether the slot fires once or twice. Firing twice is a nuisance, not a safety problem, but it should be known. | |
| 10.5.5 | Confirm quiet windows still land correctly after both transitions. | A nap window is wall-clock, so it moves with the clock. | |

### 10.6 Broken App Group

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 10.6.1 | Build with a deliberately wrong App Group identifier. Launch. | Lab: `Container: UNREACHABLE` in red, first row on the screen. | |
| 10.6.2 | Try to start a pause. | Refused. `applyShield → extensionUnavailable`. | |
| 10.6.3 | If a shield somehow exists, reconcile. | Verdict `clear(sharedStateUnavailable)`. Total ignorance resolves toward clearing. | |
| 10.6.4 | Restore the correct identifier. | Everything works again. | |

### 10.7 Stale and corrupt state

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 10.7.1 | With the device connected, edit `pause.json` in the App Group container so `plannedEndAt` is before `startedAt`. Reconcile. | `clear(malformedSession)`. | |
| 10.7.2 | Edit it so the pause lasts 3 hours. Reconcile. | `clear(malformedSession)` — the structural check rejects anything past `PottySchedule.maximumPauseDuration`. | |
| 10.7.3 | Set `schemaVersion` to 99. Reconcile. | `clear(noSession)`. An unreadable record is no record. | |
| 10.7.4 | Delete `pause.json` while a shield is up. Reconcile. | `clear(noSession)`. | |
| 10.7.5 | Corrupt the file to invalid JSON. Reconcile. | `clear(noSession)`. No crash. | |

### 10.8 Extension crash

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 10.8.1 | Add a deliberate crash to the monitor extension. Trigger a threshold. | The extension dies. | |
| 10.8.2 | Wait past the pause duration and open HopPotty. | Foreground reconciliation clears anything left. | |
| 10.8.3 | Confirm the system did not show its own default shield at any point. | A crashing **configuration** extension yields Apple's copy, which is a user-visible copy failure. Test that case separately by crashing the config extension. | |
| 10.8.4 | Remove the deliberate crash. | | |

---

## 11. Multi-child

HopPotty shields the **device**, and iOS has one Screen Time authorization per
device. Only one child's schedule can be armed at a time — the one in
`AppSettings.activeChildID`. This section tests that switching is clean, not that
two children can be paused at once, which is not possible.

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 11.1 | Create two child profiles with different intervals and different quiet windows. | | |
| 11.2 | Make child A active. Register monitoring. Lab → note the activity names. | Names contain **no child identifier** — role plus integer slot only. | |
| 11.3 | Switch the active child to B. | Monitoring re-registers for B. A's activities are gone, not merely superseded. Activity count does not grow. | |
| 11.4 | Repeat the switch ten times. | Activity count stays constant. If it grows, orphans are accumulating toward the 20-activity cap. | |
| 11.5 | Start a pause as A. Mid-pause, switch to B. | Record what happens. The intended behaviour is that the running pause ends — a shield belonging to a child who is no longer active is a shield nobody owns. | |
| 11.6 | Confirm the star from A's pause is credited to **A**, not B. | The app maps `sessionID` to the child from its own private store; the App Group never carries a child identifier. | |
| 11.7 | Delete child A while a pause of A's is running. | Shield clears. | |

---

## 12. Release-build safety

| # | Step | Expected | Observed |
| --- | --- | --- | --- |
| 12.1 | Build a Release configuration. Long-press the parent home screen for 5 seconds. Try every gesture you can think of. | The Potty Pause Lab is unreachable. It is not in the binary. | |
| 12.2 | `strings` the release binary for "Potty Pause Lab". | No match. | |
| 12.3 | `strings` the release binary for "MockScreenTimeService". | No match. | |
| 12.4 | Confirm the release build still reconciles on launch. | The fail-safe is not DEBUG-only. | |
| 12.5 | Build and run the **HopPotty-Mock** scheme (`DebugMock`). | Every Screen Time call goes to `MockScreenTimeService`; nothing touches Family Controls. `DebugMock.xcconfig` includes `Debug.xcconfig`, so `DEBUG` is defined and the mock exists. A green run here proves nothing about Screen Time — that is the point of the scheme, and of this row. | |
| 12.6 | Build the **HopPotty** scheme (`Debug`) on a device. | Uses the real service. A Debug build is what you install to watch a real shield go up; it must not quietly use a fake. | |

---

## 13. Consolidated UNVERIFIED register

Mirrors `Docs/ScreenTimeArchitecture.md` §12 and the `// UNVERIFIED — confirm on
device:` comments in the source. **Delete the source comment in the same commit
that fills in a row here.**

| # | Question | Section | Source location | Answer |
| --- | --- | --- | --- | --- |
| 1 | Do shield settings survive a reboot? A force-quit? An app update? | 10.3 | `ShieldReconciler.clearAllShields` | |
| 2 | Is `intervalWillEndWarning` gated on "device in use", and how punctual is it? | 9.1 | `MonitoringPlan.backstop` | |
| 3 | The monitor extension's real memory ceiling and time budget. | 5 | monitor extension header | |
| 4 | What happens above 50 tokens on a shield property. | 4.7 | `SelectionSummary.exceedsShieldLimit` | |
| 5 | Where `.close` leaves the child, and whether the shield redraws. | 8.2, 8.4 | shield action extension | |
| 6 | Do `ApplicationToken`s expire below iOS 26.5, and what does a stale one do to a live shield? | 4.5, 4.6 | `ShieldTokens` | |
| 7 | Does Family Controls authorization work in the Simulator at all? | — | `ScreenTimeProviding` | |
| 8 | Minimum usable `DeviceActivityEvent.threshold` granularity. | 5.10 | `ActivityMonitoringService.start` | |
| 9 | Is `Application.localizedDisplayName` reliably non-`nil` in the config extension? | 7 | shield config extension | |
| 10 | Is a `ManagedSettingsStore` write from the **ShieldConfiguration** extension honoured? | 10.2.2 | `ShieldReconciler.clearAllShields` | |
| 11 | Do `ManagedSettingsStore` reads reflect writes made moments earlier, in-process and cross-process? | 9.3.2 | `PottyPauseEffectExecutor.performClear` | |
| 12 | Is `ProcessInfo.systemUptime` measured from boot, and does sleep break the reboot comparison? | 10.3.3 | `ShieldReconciler.decide` | |
| 13 | Does an event with no applications/categories/webDomains accumulate across all apps? | 5.9 | `ActivityMonitoringService.start` | |
| 14 | Exact `FamilyControlsError` case spellings. | 3.4.6 | `ScreenTimeService.map(_:)` | |
| 15 | Exact `DeviceActivityCenter.MonitoringError` case spellings. | 6 | `ActivityMonitoringService.map(_:)` | |
| 16 | Does `DeviceActivityName` have an unlabelled `init(_:)`? | build | `ScreenTimeIdentifiers` | |
| 17 | Does `backgroundBlurStyle = nil` yield a solid background? | 7.7 | `ShieldPresentation` | |
| 18 | Does a dynamic `UIColor` resolve to the system appearance in the config extension? | 7.11 | shield config extension | |
| 19 | Does `AuthorizationCenter.$authorizationStatus` publish while backgrounded? | 3.3.5 | `ScreenTimeService.observeAuthorization` | |
| 20 | Does `.openParentalControlsApp` exist and open the containing app? | 8.7 | shield action extension | |
| 21 | Does `String(describing:)` on `ManagedSettingsStore.Name` contain its string? | 2.2 | `ShieldReconciler.assertStoreNamesAgree` | |
| 22 | Are overlapping `DeviceActivitySchedule` intervals permitted? | 6.1 | `MonitoringPlan.clockPlan` | |

---

## 14. Sign-off

This layer is not shippable until every row above has an entry in **Observed**
and every item in §13 has an **Answer**.

| | Name | Date | Verdict |
| --- | --- | --- | --- |
| Ran the plan | | | |
| Reviewed the results | | | |
