# Entitlements, Capabilities and Provisioning

**Date:** 2026-09-01
**Status:** Verified against Apple documentation on 2026-09-01. Nothing here has
been exercised against a real Apple Developer account from this repository — see
`Docs/RepositoryAudit.md`. Steps marked **UNVERIFIED** need a human with account
access to confirm.

Companion document: `Docs/ScreenTimeArchitecture.md` (what the APIs actually do).

---

## 1. Capability matrix

Four targets. Bundle IDs below are placeholders until the Xcode project exists;
`<team>` is the Team ID and the suffixes are **DESIGN** choices.

| Target | Bundle ID | Family Controls | App Groups | Other |
| --- | --- | --- | --- | --- |
| HopPotty (app) | `com.<team>.hoppotty` | ✅ required | ✅ required | Push: no. iCloud: no. Background Modes: no. |
| Device Activity Monitor ext | `com.<team>.hoppotty.monitor` | ✅ required | ✅ required | — |
| Shield Configuration ext | `com.<team>.hoppotty.shieldconfig` | ✅ required | ✅ required | — |
| Shield Action ext | `com.<team>.hoppotty.shieldaction` | ✅ required | ✅ required | — |

### Family Controls

Entitlement key, set automatically when you add the capability:

```xml
<key>com.apple.developer.family-controls</key>
<true/>
```

- Required before calling `requestAuthorization(for:)` or
  `revokeAuthorization(completionHandler:)`.
  ([entitlement reference](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.family-controls))
- Xcode adds it for you: "If you add a new target in your Xcode project using a
  Screen Time API extension template such as Device Activity Monitor, Device
  Activity Report, Shield Action, or Shield Configuration, **Xcode enables Family
  Controls automatically**."
  ([Configuring Family Controls](https://developer.apple.com/documentation/xcode/configuring-family-controls))
- All four targets need it — including the extensions, and including their App
  IDs in Certificates, Identifiers & Profiles.
- If the app target has no entitlements file, "remove then re-add the Family
  Controls capability."
- If you ever remove the capability in Xcode, also disable it for the App ID,
  regenerate the profile, and re-sign. Leaving it half-removed is a signing
  failure that looks like a code bug.

### Family Controls App and Website Usage — **HopPotty does not use this**

`com.apple.developer.family-controls.app-and-website-usage` (iOS 26.4+) unlocks
`AuthorizationStatus.approvedWithDataAccess` and `FamilyActivityData`, which
return **real bundle identifiers and domain names** instead of opaque tokens.
([entitlement reference](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.family-controls.app-and-website-usage))

**DESIGN — deliberately declined.** HopPotty needs to shield a caregiver's
selection, not to know what it contains; `ScreenTimeConfiguration` already stores
counts rather than identities. Requesting this entitlement would enlarge our
privacy surface for no product gain, and Apple restricts it further anyway:
customer devices can only reach `approvedWithDataAccess` "in the EU … signed in
with an Apple Account with an EU country or region," and only one app per device
may hold it.
([approvedWithDataAccess](https://developer.apple.com/documentation/familycontrols/authorizationstatus/approvedwithdataaccess))
Do not add it. If someone proposes it, the burden is to show a caregiver need
that tokens cannot serve.

### App Groups

One group, shared by all four targets:

```
group.com.<team>.hoppotty
```

Rules ([Configuring app groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)):

- "A container ID must begin with `group.` and then a custom string."
- Register it for iOS in the developer account; add every target as a member.
- Access via `UserDefaults(suiteName:)` or
  `containerURL(forSecurityApplicationGroupIdentifier:)`.
- Max 1,000 app groups per account (irrelevant here; noted for completeness).

**DESIGN:** use `containerURL(...)` + small versioned JSON files, not
`UserDefaults`. Two reasons: the extensions-to-app channel is append-only and a
directory of one-record files avoids cross-process read-modify-write races
(`Docs/ScreenTimeArchitecture.md` §10); and `UserDefaults` gives no atomicity
guarantee we can reason about across four processes. Keep exactly one
`AppGroup.identifier` constant in `HopPottyCore` — never a literal at a call site.

> **Note:** named `ManagedSettingsStore`s are shared between the app and its
> extensions *automatically*, with no App Group involvement (WWDC22
> [session 110336](https://developer.apple.com/videos/play/wwdc2022/110336/)).
> The App Group carries **our** data only.

### Capabilities we must NOT add

| Capability | Why not |
| --- | --- |
| Push Notifications | Contract §4.7 — no "come back" notifications. Local notifications need no entitlement. |
| iCloud / CloudKit | The reward ledger and potty timeline are the most sensitive data in the app. Keep it on-device until there is an explicit, gated caregiver request for sync. |
| Background Modes | Device Activity is the sanctioned background mechanism; adding others invites App Review questions we cannot answer well. |
| Family Controls App and Website Usage | See above. |

---

## 2. Development vs distribution

These are two different things and conflating them is the classic way to lose a
week.

| | Development | Distribution |
| --- | --- | --- |
| How you get it | Add the capability in Xcode. "you can access the entitlement through the Apple Developer Program **during development**" | Apple must approve a request and add it "to your developer account using **managed capabilities**" |
| Covers | Development-signed builds on registered devices | TestFlight, Ad Hoc, App Store |
| Waiting on Apple? | **No** | **Yes** |
| Per target? | Yes — configure each App ID | Yes — "If your app includes a Screen Time API app extension, submit the same request for the extension" |

Sources: [Configuring Family Controls](https://developer.apple.com/documentation/xcode/configuring-family-controls),
[Requesting the Family Controls entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement).

### The request process

1. **The Account Holder submits it.** "Before you distribute an app that uses
   Family Controls, your Apple Developer **Account Holder** must request
   permission to use the Family Controls entitlement."
2. Submit at **[Family Controls distribution](https://developer.apple.com/contact/request/family-controls-distribution/)**
   (sign-in required), or via the **Capability Requests** tab in Certificates,
   Identifiers & Profiles → Identifiers → *your identifier*
   ([Capability Requests](https://developer.apple.com/help/account/capabilities/capability-requests/)).
3. **Submit once per App ID** — the app *and* each of the three extensions.
4. "Apple reviews your app, and if it's approved, adds the entitlement to your
   developer account using managed capabilities."
5. Check status: the capability shows **Assigned** when approved. "Click the info
   button next to the capability. In the dialog that appears, check that
   **Provisioning Support** lists all the distribution methods you need." — do
   this explicitly; an approval that omits App Store distribution is a silent
   trap.

**UNVERIFIED:** Apple publishes no review turnaround for this request. Plan the
release schedule around an unknown, and submit the request on the day the four
App IDs exist — not when the app is feature-complete.

---

## 3. Provisioning notes

**Automatic signing (recommended).** "If you use automatic signing, Xcode
automatically enables Family Controls for your app's App ID in Certificates,
Identifiers & Profiles and requests a new provisioning profile." And after
approval: "If your Xcode project already includes the Family Controls capability
for development and you use automatic signing, Xcode automatically updates your
app to use this capability for distribution."
([Configuring Family Controls](https://developer.apple.com/documentation/xcode/configuring-family-controls),
[Requesting the entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement))

**Manual signing.** Enable the capability for each App ID, regenerate each
profile, download and install. "If your app includes a Screen Time API extension,
use the same steps to update the provisioning profile of the extension." Four
targets means four profiles; a stale extension profile produces a build that
installs and then does nothing when a shield should appear.

**Checklist before any device build:**

- [ ] All four App IDs exist and have Family Controls enabled.
- [ ] All four App IDs belong to `group.com.<team>.hoppotty`.
- [ ] Extension bundle IDs are prefixed by the app's bundle ID.
- [ ] The `.entitlements` of each target contains
      `com.apple.developer.family-controls` = `true` and the app-group array.
- [ ] Deployment target on all four targets matches
      `Docs/ADR/0002-deployment-target.md`, and matches `HopPottyKit/Package.swift`.
- [ ] `Secrets.xcconfig` (git-ignored) holds the Team ID; no signing material is
      committed — `.gitignore` already blocks `*.p12`, `*.mobileprovision`,
      `*.cer`.

---

## 4. What is testable before Apple approves the entitlement

### Testable now, no approval, no device

Everything in `HopPottyKit` — the pause state machine, interval arithmetic,
quiet-hour precedence, reward idempotency, copy safety, contrast. This is the
point of the package boundary (`Docs/ADR/0001-platform-agnostic-core.md`).

### Testable with development signing only (no Apple approval)

On a registered physical device, with the development entitlement:

| Verifiable | Notes |
| --- | --- |
| `requestAuthorization(for:)` and the real authorization sheet | Needs iCloud sign-in; `.child` needs a Family Sharing group, `.individual` needs a device passcode + biometrics ([FamilyControlsError.authenticationMethodUnavailable](https://developer.apple.com/documentation/familycontrols/familycontrolserror/authenticationmethodunavailable)) |
| `FamilyActivityPicker` and real token round-tripping | |
| Applying and clearing a shield; the dimmed icon + hourglass | |
| Our custom `ShieldConfiguration` rendering | Including the "too slow → Apple's default shield" failure mode |
| `ShieldActionDelegate` taps, `.close` behaviour | |
| `DeviceActivityCenter.startMonitoring` and all six monitor callbacks | Including the 15-minute floor and the 20-activity cap |
| **All nine UNVERIFIED items** in `ScreenTimeArchitecture.md` §12 | This is the main reason to get a device build early |

### NOT testable before approval

- **TestFlight.** "When you submit your app to TestFlight and the App Store,
  request permission to use the Family Controls entitlement." Treat TestFlight as
  gated on approval.
- Ad Hoc and App Store builds.
- Anything requiring a beta cohort — caregiver onboarding research, real family
  devices you cannot register individually.

### Simulator

**UNVERIFIED — confirm on device/simulator.** Apple's documentation says nothing
about Family Controls in the iOS Simulator. Do not assume either way, and do not
build a test strategy that depends on it.

**DESIGN — the mitigation that makes this survivable.** Every Screen Time call
sits behind a `ScreenTimeProviding` protocol (Contract §3). The app ships two
conformances: the real one, and an in-memory `PreviewScreenTimeService` that
simulates authorization, selection, shield application and pause expiry. All
SwiftUI previews, all UI tests, and every simulator run use the fake. The real
implementation is thin enough to be read in one sitting — because everything it
would otherwise contain lives in `HopPottyCore`.

---

## 5. Proposed App Review notes

Paste into App Store Connect → App Review Information → Notes. Keep it factual;
every sentence must be true of the shipped build. **Update the demo credentials
and the pause duration before each submission.**

> **Why HopPotty requires the Family Controls entitlement**
>
> HopPotty is a potty-training aid for young children, used by a caregiver on the
> child's device. Its core feature, "Potty Pause," is the reason the app needs
> Family Controls: at a time the caregiver chooses, HopPotty briefly shields the
> apps the caregiver selected so the child sets the device down and takes a potty
> break, then restores access automatically.
>
> This cannot be built without the Screen Time APIs. Shielding another app's
> access is only possible through ManagedSettings, which requires Family Controls
> authorization; running the restore reliably when HopPotty is not in the
> foreground is only possible through DeviceActivity. There is no alternative
> implementation — a reminder notification does not interrupt the app the child
> is holding, and nothing else in the SDK can restore access on a timer.
>
> **What we do with each framework**
> - **FamilyControls** — one `requestAuthorization(for:)` call at first run, and
>   `FamilyActivityPicker` so the caregiver chooses which apps a pause covers. We
>   never see which apps they are; we hold only opaque tokens and store only
>   counts.
> - **ManagedSettings** — a single named store, `pottyPause`, that holds the
>   shield for an active pause and is cleared when the pause ends. We set no
>   other managed setting: no account lock, no passcode restriction, no media
>   rating, no web filter.
> - **ManagedSettingsUI** — a gentle, age-appropriate shield ("Time for a potty
>   break!") with one button the child can press when they are done.
> - **DeviceActivity** — one short, non-repeating schedule per pause, used only to
>   guarantee that access is restored.
>
> **Design commitments a reviewer can verify**
> - A pause is short (default N minutes) and **always ends on its own**. It ends
>   on its timer, when the child presses the button, or when the caregiver ends
>   it. No code path can extend a pause.
> - **Access is never contingent on a biological outcome.** HopPotty never asks
>   whether the child used the toilet before restoring access, and never keeps a
>   shield up because they did not.
> - Rewards are additive only. Stars are never removed, and there are no streaks,
>   no leaderboards, no randomised rewards, and no re-engagement notifications.
> - Every destructive action is behind a caregiver gate.
> - All data stays on the device. There is no account, no analytics SDK, no
>   network request carrying child data, and no third-party tracking. App and
>   website tokens never leave the device.
>
> **How to test**
> 1. Launch HopPotty and complete caregiver setup. When prompted, approve the
>    Screen Time authorization request.
> 2. Tap "Choose apps" and select one or two apps to include in a pause.
> 3. Tap "Start a potty break." The selected apps are shielded.
> 4. Open one of the selected apps to see the HopPotty shield. Press "All done!"
>    — access is restored immediately.
> 5. Alternatively, wait for the pause to end on its own; access is restored
>    without any input.
>
> Demo caregiver passcode: `<fill in>`.
> Note: Screen Time authorization requires a device signed into iCloud with a
> passcode set. Family Controls does not function in the Simulator.

**UNVERIFIED:** the final sentence about the Simulator — remove or confirm it
before submitting (§4).

---

## 6. Open items for a human with account access

| # | Item | Blocks |
| --- | --- | --- |
| 1 | Confirm the Team ID and lock the four bundle IDs. | Xcode project creation |
| 2 | Register `group.com.<team>.hoppotty` and add all four App IDs. | Any extension work |
| 3 | Submit the Family Controls distribution request for all four App IDs. | TestFlight — start this early |
| 4 | After approval, verify **Provisioning Support** lists Development, Ad Hoc and App Store. | Release |
| 5 | Get one registered physical device with a Family Sharing child account **and** one with an individual account. | The nine UNVERIFIED items in `ScreenTimeArchitecture.md` §12 |

---

## 7. Sources

All URLs retrieved 2026-09-01.

- Configuring Family Controls — https://developer.apple.com/documentation/xcode/configuring-family-controls
- Requesting the Family Controls entitlement — https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement
- Family Controls entitlement key — https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.family-controls
- Family Controls App and Website Usage entitlement key — https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.family-controls.app-and-website-usage
- Configuring app groups — https://developer.apple.com/documentation/xcode/configuring-app-groups
- Capability Requests — https://developer.apple.com/help/account/capabilities/capability-requests/
- Family Controls distribution request form — https://developer.apple.com/contact/request/family-controls-distribution/
- WWDC22 *What's new in Screen Time API* — https://developer.apple.com/videos/play/wwdc2022/110336/
