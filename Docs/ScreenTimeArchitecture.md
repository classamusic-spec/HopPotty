# Screen Time Architecture

**Date:** 2026-09-01
**Status:** Verified against Apple documentation on 2026-09-01. No behaviour has been
observed on hardware — this repository has no Xcode, no simulator and no device
(`Docs/RepositoryAudit.md`).

## How to read this document

| Marker | Meaning |
| --- | --- |
| *(no marker)* | Stated in Apple's own documentation. The URL is cited. |
| **UNVERIFIED — confirm on device** | Apple does not document it, or documents it ambiguously. Treat as a hypothesis and prove it on hardware before designing around it. |
| **DESIGN** | HopPotty's choice, not an Apple constraint. |

A claim without a citation in this document is a defect. Fix it or mark it
UNVERIFIED.

---

## 1. Framework map

Four Apple frameworks, collectively "Screen Time API"
([Screen Time Technology Frameworks](https://developer.apple.com/documentation/screentimeapidocumentation)):

| Framework | Role | HopPotty uses it in |
| --- | --- | --- |
| **FamilyControls** | Authorization gate + the app/category picker. Hands out opaque tokens. | App target only |
| **ManagedSettings** | Applies the shield. Owns the token types. Owns shield *actions*. | App + Monitor + ShieldAction extensions |
| **ManagedSettingsUI** | Appearance of the shield. | ShieldConfiguration extension |
| **DeviceActivity** | Runs our code on a schedule without the app launching. | App (registration) + Monitor extension |

> "Managed Settings can't function without a parent or guardian in the same Family
> Sharing group authorizing your app using Family Controls."
> — [Manage settings on devices in a Family Sharing group](https://developer.apple.com/documentation/managedsettings/connectionwithframeworks)

## 2. Availability — every symbol we depend on

| Symbol | Framework | iOS | Source |
| --- | --- | --- | --- |
| Framework: Family Controls | FamilyControls | 15.0 | [doc](https://developer.apple.com/documentation/familycontrols) |
| `AuthorizationCenter`, `.shared`, `$authorizationStatus` | FamilyControls | 15.0 | [doc](https://developer.apple.com/documentation/familycontrols/authorizationcenter) |
| `AuthorizationStatus` (`.notDetermined`/`.denied`/`.approved`) | FamilyControls | 15.0 | [doc](https://developer.apple.com/documentation/familycontrols/authorizationstatus) |
| `AuthorizationStatus.approvedWithDataAccess` | FamilyControls | **26.4** | [doc](https://developer.apple.com/documentation/familycontrols/authorizationstatus/approvedwithdataaccess) |
| `requestAuthorization(for:)` async | FamilyControls | **16.0** | [doc](https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization(for:)) |
| `FamilyControlsMember` (`.child` / `.individual`) | FamilyControls | **16.0** | [doc](https://developer.apple.com/documentation/familycontrols/familycontrolsmember) |
| `requestAuthorization(completionHandler:)` — **deprecated** | FamilyControls | 15.0 | [doc](https://developer.apple.com/documentation/familycontrols/authorizationcenter) |
| `revokeAuthorization(completionHandler:)` | FamilyControls | 15.0 | [doc](https://developer.apple.com/documentation/familycontrols/authorizationcenter/revokeauthorization(completionhandler:)) |
| `FamilyActivityPicker`, `FamilyActivitySelection` | FamilyControls | 15.0 | [doc](https://developer.apple.com/documentation/familycontrols/familyactivitypicker) |
| `FamilyActivitySelection.includeEntireCategory` | FamilyControls | 15.2 | [doc](https://developer.apple.com/documentation/familycontrols/familyactivityselection/includeentirecategory) |
| `Label(applicationToken)` (activity labels) | FamilyControls | 15.0 | [doc](https://developer.apple.com/documentation/familycontrols/displayingactivitylabels) |
| `.familyActivityPicker(isPresented:selection:)` | SwiftUI | 15.0 | [doc](https://developer.apple.com/documentation/swiftui/view/familyactivitypicker(ispresented:selection:)) |
| `.familyActivityPicker(headerText:footerText:isPresented:selection:)` | SwiftUI | **16.0** | [doc](https://developer.apple.com/documentation/swiftui/view/familyactivitypicker(headertext:footertext:ispresented:selection:)) |
| `.familyActivityPicker(title:headerText:footerText:isPresented:selection:)` | SwiftUI | **26.2** | [doc](https://developer.apple.com/documentation/swiftui/view/familyactivitypicker(title:headertext:footertext:ispresented:selection:)) |
| `FamilyControlsError` | FamilyControls | 15.0 | [doc](https://developer.apple.com/documentation/familycontrols/familycontrolserror) |
| `FamilyActivityData` | FamilyControls | **26.4** | [doc](https://developer.apple.com/documentation/familycontrols/familyactivitydata) |
| Framework: Managed Settings | ManagedSettings | 15.0 | [doc](https://developer.apple.com/documentation/managedsettings) |
| `ManagedSettingsStore`, `.shield`, `ShieldSettings` | ManagedSettings | 15.0 | [doc](https://developer.apple.com/documentation/managedsettings/managedsettingsstore) |
| `Token<T>`, `ApplicationToken`, `ActivityCategoryToken`, `WebDomainToken` | ManagedSettings | 15.0 | [doc](https://developer.apple.com/documentation/managedsettings/token) |
| `ManagedSettingsStore.Name`, `init(named:)`, `clearAllSettings()` | ManagedSettings | **16.0** | [doc](https://developer.apple.com/documentation/managedsettings/managedsettingsstore/init(named:)) |
| `isActive`, `deleteStore()`, `stores`, `refresh(_:)`, `TokenExpiryMessage` | ManagedSettings | **26.5** | [doc](https://developer.apple.com/documentation/managedsettings/managedsettingsstore/isactive) |
| `ShieldAction.primaryButtonPressed` / `.secondaryButtonPressed` | ManagedSettings | 15.0 | [doc](https://developer.apple.com/documentation/managedsettings/shieldaction) |
| `ShieldAction.*SecondarySubmenuItemPressed` (3 cases) | ManagedSettings | **26.4** | [doc](https://developer.apple.com/documentation/managedsettings/shieldaction/firstsecondarysubmenuitempressed) |
| `ShieldActionDelegate`, `ShieldActionResponse` (`.close`/`.defer`/`.none`) | ManagedSettings | 15.0 | [doc](https://developer.apple.com/documentation/managedsettings/shieldactionresponse) |
| `ShieldActionResponse.openParentalControlsApp` | ManagedSettings | **26.5** | [doc](https://developer.apple.com/documentation/managedsettings/shieldactionresponse/openparentalcontrolsapp) |
| Framework: Managed Settings UI, `ShieldConfiguration`, `ShieldConfigurationDataSource` | ManagedSettingsUI | 15.0 | [doc](https://developer.apple.com/documentation/managedsettingsui) |
| `ShieldConfiguration.secondaryButtonSubmenuItems` | ManagedSettingsUI | **26.4** | [doc](https://developer.apple.com/documentation/managedsettingsui/shieldconfiguration/secondarybuttonsubmenuitems) |
| Framework: Device Activity, `Center`/`Name`/`Schedule`/`Event`/`Monitor` | DeviceActivity | 15.0 | [doc](https://developer.apple.com/documentation/deviceactivity) |
| `DeviceActivityReport` | DeviceActivity | **16.0** | [doc](https://developer.apple.com/documentation/deviceactivity/deviceactivityreport) |
| `DeviceActivityAuthorization` | DeviceActivity | **17.0** | [doc](https://developer.apple.com/documentation/deviceactivity/deviceactivityauthorization) |
| `DeviceActivityEvent.includesPastActivity` | DeviceActivity | **17.4** | [doc](https://developer.apple.com/documentation/deviceactivity/deviceactivityevent/includespastactivity) |
| SwiftData | SwiftData | **17.0** | [doc](https://developer.apple.com/documentation/swiftdata) |
| Observation (`@Observable`) | Observation | **17.0** | [doc](https://developer.apple.com/documentation/observation) |

Nothing HopPotty needs sits between iOS 16.0 and 17.0. See
`Docs/ADR/0002-deployment-target.md`.

---

## 3. FamilyControls

### AuthorizationCenter

`AuthorizationCenter.shared` is a singleton `ObservableObject`. Two request forms:

```
requestAuthorization(for: FamilyControlsMember) async throws   // iOS 16+, use this
requestAuthorization(completionHandler:)                       // iOS 15, deprecated
```

Documented behaviour we rely on
([AuthorizationCenter](https://developer.apple.com/documentation/familycontrols/authorizationcenter),
[authorizationStatus](https://developer.apple.com/documentation/familycontrols/authorizationcenter/authorizationstatus)):

- "Always request authorization when your app first launches."
- `authorizationStatus` **initial value is always `.notDetermined`**; the system
  sets it "only after a call to `requestAuthorization(for:)` succeeds", and keeps
  it updated "until a call to `revokeAuthorization` succeeds or your app exits."
  → **Do not treat `.notDetermined` at launch as "never authorized."** Call
  `requestAuthorization(for:)` first; a previously authorized app gets no UI.
- "Only access the `authorizationStatus` property on the main queue."
- Status can change externally — "a child graduating to an adult account, or a
  parent or guardian changing the status in Settings."
- While authorized, the child cannot delete HopPotty and cannot sign out of
  iCloud.
- Revoking: "the system no longer enforces restrictions, such as preventing the
  user from deleting your app."
- visionOS: "In a compatible iPad or iPhone app running in visionOS,
  authorization attempts always fail."

### `AuthorizationStatus` — a correction to our model

Apple's enum has exactly four cases:
`.notDetermined`, `.denied`, `.approved`, and `.approvedWithDataAccess` (iOS 26.4+).
**There is no `.restricted` case.**

`HopPottyCore/Models/ScreenTimeConfiguration.swift` currently declares
`ScreenTimeAuthorizationStatus.restricted` with the comment "Mirrors
`FamilyControls.AuthorizationStatus`". That is not a mirror.

**DESIGN — required fix:** keep `.restricted` in our enum if the parent UI needs
it, but derive it from `FamilyControlsError.restricted` ("A restriction prevents
your app from using Family Controls on this device"), not from
`AuthorizationStatus`. Document the mapping in the adapter, and add
`.approvedWithDataAccess → .approved` (HopPotty never wants non-tokenized data;
see §11.7).

### Errors worth handling distinctly

[`FamilyControlsError`](https://developer.apple.com/documentation/familycontrols/familycontrolserror):

| Case | Apple's description | HopPotty maps to |
| --- | --- | --- |
| `.invalidAccountType` | Device isn't signed into a valid iCloud account | new `ScreenTimeFailure` case — caregiver must sign in |
| `.authorizationConflict` | **Another authorized app already provides parental controls** | new case — the single most likely real-world failure |
| `.authorizationCanceled` | Parent/guardian canceled | not a failure; return to the explainer screen |
| `.invalidArgument` | Arguments invalid | `.unknown` |
| `.unavailable` | System failed to set up Family Controls | `.extensionUnavailable`-adjacent; new case |
| `.restricted` | A restriction prevents use on this device | `.restricted` |
| `.networkError` | Device must be online to enrol | new case — retryable |
| `.authenticationMethodUnavailable` | Device must have a passcode set | new case — actionable |
| `.unauthorized` | Caller must be authorized | `.authorizationRevoked` |

**DESIGN:** `ScreenTimeFailure` in `HopPottyCore` currently has 8 cases and does
not cover `.authorizationConflict`, `.invalidAccountType`,
`.authenticationMethodUnavailable` or `.networkError`. Each of those needs its
own caregiver-facing sentence, because each has a different fix.

### FamilyActivityPicker / FamilyActivitySelection

- The picker returns opaque values: "To protect the user's privacy, the system
  uses opaque values to represent the selections."
  ([FamilyActivityPicker](https://developer.apple.com/documentation/familycontrols/familyactivitypicker))
- `FamilyActivitySelection` exposes `applications`/`categories`/`webDomains`
  (rich structs) and `applicationTokens`/`categoryTokens`/`webDomainTokens`
  (`Set<Token<…>>`).
  ([FamilyActivitySelection](https://developer.apple.com/documentation/familycontrols/familyactivityselection))
- Scope: "A `FamilyActivityPicker` shown on a parent device only displays
  applications and websites from authorized child devices within the Family
  Sharing Group. A `FamilyActivityPicker` shown on an individually authorized
  device includes applications and websites from that same device."
- We can render a selected item without learning what it is:
  `Label(applicationToken)`
  ([Displaying Activity Labels](https://developer.apple.com/documentation/familycontrols/displayingactivitylabels)).
  This is how the parent screen shows "these 6 apps" with real icons while
  HopPotty stays blind.

### Tokens — opaque, Codable, persistable, revocable

| Question | Answer | Source |
| --- | --- | --- |
| Opaque? | Yes. `Token<T>` exists "to preserve user privacy and prevent anyone outside of a Family Sharing group from identifying what apps and websites the family accesses." No readable payload is exposed. | [Token](https://developer.apple.com/documentation/managedsettings/token) |
| `Codable`? | Yes — `Token` conforms to `Decodable, Encodable, Equatable, Hashable`. `FamilyActivitySelection` conforms to `Decodable, Encodable, Equatable`. | [Token](https://developer.apple.com/documentation/managedsettings/token), [FamilyActivitySelection](https://developer.apple.com/documentation/familycontrols/familyactivityselection) |
| Persistable? | Yes, via `Codable`. **DESIGN:** persist the whole `FamilyActivitySelection` (one blob per child), not loose token sets — it round-trips `includeEntireCategory` too. |  |
| Lifetime? | "If a user, parent, or guardian revokes authorization of your app, any tokens that `FamilyActivitySelection` provided while your app was authorized are **voided**." | [FamilyActivitySelection](https://developer.apple.com/documentation/familycontrols/familyactivityselection) |
| Can they expire otherwise? | iOS 26.5 adds `ManagedSettingsStore.TokenExpiryMessage` — "posted in NotificationCenter when ManagedSettingsStore tokens are expired … Use these messages to refresh tokens in your database that are expired" — plus `static func refresh(_:)` for each token type. Expiry therefore exists as a concept. **UNVERIFIED — confirm on device:** whether tokens expire on iOS < 26.5, and what a stale token does to an active shield. | [TokenExpiryMessage](https://developer.apple.com/documentation/managedsettings/managedsettingsstore/tokenexpirymessage) |
| Identity leakage anywhere? | Only inside the ShieldConfiguration extension: `Application.bundleIdentifier` and `Application.localizedDisplayName` are non-`nil` there and `nil` everywhere else. | [bundleIdentifier](https://developer.apple.com/documentation/managedsettings/application/bundleidentifier) |

**DESIGN:** because a shield-configuration extension is the one place identity is
readable, HopPotty's ShieldConfiguration extension **must not** persist, log, or
forward `bundleIdentifier` / `localizedDisplayName` anywhere. It may use
`localizedDisplayName` transiently to compose the on-screen subtitle and nothing
else. This is a privacy rule, enforced by review.

---

## 4. DeviceActivity

### Registration (app side)

```
DeviceActivityCenter().startMonitoring(_ activity: DeviceActivityName,
                                       during: DeviceActivitySchedule,
                                       events: [DeviceActivityEvent.Name: DeviceActivityEvent]) throws
```

Documented constraints
([startMonitoring](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/startmonitoring(_:during:events:)),
[MonitoringError](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror)):

| Constraint | Value | Error case |
| --- | --- | --- |
| Minimum schedule interval | **15 minutes** | `.intervalTooShort` |
| Maximum schedule interval | **1 week** | `.intervalTooLong` |
| Max concurrent activities (app + all extensions) | **20** | `.excessiveActivities` |
| Not authorized | — | `.unauthorized` |
| Bad `DateComponents` | — | `.invalidDateComponents` |

- `DeviceActivityName` is unique: "Monitoring a second activity with the same
  name as a previous activity overwrites the schedule for the first one."
  ([DeviceActivityName](https://developer.apple.com/documentation/deviceactivity/deviceactivityname))
  → re-registering is the documented way to update.
- Registering a schedule whose interval is already in progress fires
  `intervalDidStart` immediately: "The application extension's
  `DeviceActivityMonitor` may begin receiving callbacks as soon as the system
  calls this method if the activity's scheduled interval is ongoing."
- Time-zone caveat: "If the device's time zone changes in the middle of a
  schedule's interval, any ongoing events include device activity that may have
  accumulated outside of the new time zone."
- `stopMonitoring([])` stops **everything**. Always pass explicit names.
  ([stopMonitoring](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/stopmonitoring(_:)))

### Schedule

```
DeviceActivitySchedule(intervalStart: DateComponents,
                       intervalEnd: DateComponents,
                       repeats: Bool,
                       warningTime: DateComponents? = nil)
```

- `repeats: false` → "the extension stops receiving callbacks when the interval
  ends for the first time."
- `warningTime` — "If the components specify a longer time interval than the
  schedule's interval, the system clamps the warning callbacks for each event's
  threshold to the start time of the interval."
  ([init](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule/init(intervalstart:intervalend:repeats:warningtime:)))
- "If the current date falls in between `intervalStart` and `intervalEnd`, the
  system calls `intervalDidStart(for:)` immediately upon starting to monitor."

### Event threshold semantics — read this twice

`DeviceActivityEvent.threshold` is a `DateComponents` of **accumulated foreground
usage of the named apps/categories/domains**, *not* wall-clock time:

> "Device activity is the amount of time an application, category, or web domain
> is frontmost on the screen and accumulates based on the time zone of the
> scheduled start date."
> — [DeviceActivityEvent](https://developer.apple.com/documentation/deviceactivity/deviceactivityevent)

> "An application's extension receives a callback once the combination of
> specified applications, categories, and webDomains have been in use longer than
> the event's threshold **within the activity's scheduled interval**. If your app
> didn't specify any `applications`, `categories`, or `webDomains`, the event
> includes all applications, categories, and web domains."
> — [init(…includesPastActivity:)](https://developer.apple.com/documentation/deviceactivity/deviceactivityevent/init(applications:categories:webdomains:threshold:includespastactivity:))

Consequences:
- An event **cannot** be used as a countdown timer for a Potty Pause. A child who
  puts the iPad down accrues nothing.
- Implicit expansion: "A small subset of popular App Store apps have known
  associated web domains that get included implicitly."
- `includesPastActivity` (iOS 17.4+) decides whether usage before
  `startMonitoring` counts, and rounds back to "the start of the nearest round
  hour."
- **UNVERIFIED — confirm on device:** the threshold's resolution/granularity
  (Apple documents no minimum threshold, unlike the 15-minute interval floor).

### Monitor extension callbacks

Subclass `DeviceActivityMonitor` and set it as the extension's principal class
([DeviceActivityMonitor](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor)):

| Callback | Fires when | Documented gating |
| --- | --- | --- |
| `intervalDidStart(for:)` | "someone first uses the device within the activity's scheduled time interval" | "the system only invokes this method **when the device is in use**" |
| `intervalDidEnd(for:)` | "someone first uses the device outside the activity's scheduled time interval, **or when your app stops monitoring an activity with an ongoing interval**" | same — device in use |
| `intervalWillStartWarning(for:)` | `warningTime` before start | not documented |
| `intervalWillEndWarning(for:)` | `warningTime` before end | not documented |
| `eventDidReachThreshold(_:activity:)` | usage reaches `threshold` | "the system invokes the `eventDidReachThreshold` function when an event reaches its threshold" |
| `eventWillReachThresholdWarning(_:activity:)` | `warningTime` before threshold | not documented |

Two things follow, and they are load-bearing:

1. **Callbacks are not alarms.** `intervalDidStart`/`intervalDidEnd` are explicitly
   deferred until the device is next in use
   ([DeviceActivityCenter](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter)).
   A pause that "ends at 10:05" ends the next time the device is picked up.
2. **UNVERIFIED — confirm on device:** whether the four `…Warning` callbacks are
   subject to the same "device in use" gating. Apple states the gate only for
   `intervalDidStart`/`intervalDidEnd`. Our restore path depends on
   `intervalWillEndWarning` firing promptly (§9); measure this before shipping.

### Extension execution limits

Apple documents no memory ceiling and no wall-clock budget for
`DeviceActivityMonitor`. The widely repeated "6 MB" figure traces to Apple
Developer Forums posts by non-Apple participants
([thread 735454](https://developer.apple.com/forums/thread/735454)), not to
documentation.

**UNVERIFIED — confirm on device:** the monitor extension's memory ceiling and
time budget.

**DESIGN — engineer as if the budget is tiny, because it costs us nothing:**

- No SwiftData, no Core Data, no `ModelContainer` in any extension.
- No image decoding, no `HopPottyDesignTokens` colour maths, no SwiftUI.
- Only: read a small JSON file from the App Group, mutate one
  `ManagedSettingsStore`, append one small JSON record, return.
- Every callback must be correct if it is *never called*. The app reconciles on
  next foreground (§9).

---

## 5. ManagedSettings

### Stores

- `ManagedSettingsStore()` — the default store. `ManagedSettingsStore(named:)` —
  iOS 16+. "Initializing multiple stores with the same name will share settings."
  ([Name](https://developer.apple.com/documentation/managedsettings/managedsettingsstore/name))
- Apple, WWDC22 *What's new in Screen Time API*: "in iOS 16, you can create up to
  50 Managed Settings Stores per process, each with their own unique name. **These
  named stores are also automatically shared between your app and all your app
  extensions.** Also, you can now remove all the settings in any given named store
  all at once."
  ([session 110336](https://developer.apple.com/videos/play/wwdc2022/110336/))
- "Changing the value of a setting to `nil` deletes your app's configuration for
  that setting from the device. **The system doesn't guarantee that the settings
  you specify govern the device's behavior.** The system is responsible for
  determining its effective state based on all the settings it receives."
  ([ManagedSettingsStore](https://developer.apple.com/documentation/managedsettings/managedsettingsstore))
- `clearAllSettings()` (iOS 16+) clears one store without touching others.
  ([doc](https://developer.apple.com/documentation/managedsettings/managedsettingsstore/clearallsettings()))
- iOS 26.5 adds `isActive` ("An inactive store is not included in the effective
  settings calculation"), `deleteStore()`, and `static var stores`.

**DESIGN — store layout.** One named store per independent lifetime, so that
ending one thing can never end another:

| Store name | Written by | Contents | Cleared by |
| --- | --- | --- | --- |
| `.pottyPause` | App (start), ShieldAction ext (child finishes), Monitor ext (timer/backstop) | `shield.applications`, `shield.applicationCategories` for the active pause | whoever ends the pause, via `clearAllSettings()` |
| *(default store)* | **nobody** | — | — |

Leaving the default store empty means a future feature (or a bug in one) cannot
strand a Potty Pause shield.

### Shield settings

[`ShieldSettings`](https://developer.apple.com/documentation/managedsettings/shieldsettings):

| Property | Type | Cap |
| --- | --- | --- |
| `applications` | `Set<ApplicationToken>?` | "up to **50** application tokens at once" |
| `applicationCategories` | `ShieldSettings.ActivityCategoryPolicy<Application>?` | "up to **50** category tokens and … up to **50** application tokens exceptions" |
| `webDomains` | `Set<WebDomainToken>?` | "up to **50** web domain tokens at once" |
| `webDomainCategories` | `ActivityCategoryPolicy<WebDomain>?` | — |

`ActivityCategoryPolicy` is `.none`, `.all(except:)`, or `.specific(_:except:)`.
"Your app is exempt from `.all`."
([applicationCategories](https://developer.apple.com/documentation/managedsettings/shieldsettings/applicationcategories-swift.property))

What a shield does: "Shielding an app dims the app's icon on the homescreen and
applies an hourglass symbol. When the app launches, the system covers it with a
view that your app can configure."
([DeviceActivityMonitor](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor))

**DESIGN:** enforce a 50-token cap in the caregiver picker flow and tell the
caregiver plainly when they exceed it. Apple does not document the failure mode
of exceeding it. **UNVERIFIED — confirm on device:** what happens at 51 tokens
(silent truncation vs. no shield vs. throw).

### Persistence across reboot

**UNVERIFIED — confirm on device.** Apple documents neither the lifetime of a
`ManagedSettingsStore`'s contents across restart nor across app termination. What
*is* documented is that the system, not our process, computes and applies
effective settings, and that Device Activity exists "to execute your code on
their device without launching your app"
([Screen Time Technology Frameworks](https://developer.apple.com/documentation/screentimeapidocumentation))
— both consistent with system-side persistence, neither a guarantee.

**DESIGN — do not depend on either answer.** HopPotty stores the authoritative
pause record in the App Group and reconciles on every app foreground and every
extension callback (§9). If a shield survives a reboot past its end time,
reconciliation clears it. If a shield is lost mid-pause, the pause simply ends
early — which the product rules already permit (a pause may end early; it may
never be extended for a biological reason).

---

## 6. ManagedSettingsUI — what is actually customizable

[`ShieldConfiguration`](https://developer.apple.com/documentation/managedsettingsui/shieldconfiguration).
"The system provides a default appearance for any properties you set to `nil`."

| Property | Type | Notes |
| --- | --- | --- |
| `backgroundBlurStyle` | `UIBlurEffect.Style?` | |
| `backgroundColor` | `UIColor?` | "for a shield to use in the background blur effect" |
| `icon` | `UIImage?` | "in the center of the shield" |
| `title` | `ShieldConfiguration.Label?` | `Label(text: String, color: UIColor)` |
| `subtitle` | `ShieldConfiguration.Label?` | "such as the reason for shielding" |
| `primaryButtonLabel` | `ShieldConfiguration.Label?` | topmost rounded-rect button |
| `primaryButtonBackgroundColor` | `UIColor?` | |
| `secondaryButtonLabel` | `ShieldConfiguration.Label?` | "borderless and has no background. If this is `nil`, then the shield doesn't have a secondary button." |
| `secondaryButtonSubmenuItems` | `[String]?` | **iOS 26.4+**, max 3; system adds a Cancel item |

**That is the entire surface.** There is no custom view, no layout control, no
font choice, no animation, no per-element positioning, no third button. The
`Label` type carries text and colour only — no font, no attributed string.

Data source
([`ShieldConfigurationDataSource`](https://developer.apple.com/documentation/managedsettingsui/shieldconfigurationdatasource)):

```
func configuration(shielding application: Application) -> ShieldConfiguration
func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration
func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration
func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration
```

Apple's constraints, verbatim:

> "The system provides your extension with the display names, bundle identifiers,
> and domains for each application, website, or category it shields. Your
> extension is expected to return an appropriate configuration **as quickly as
> possible** … your extension runs in a **sandbox. This sandbox prevents your
> extension from making network requests or moving sensitive content outside the
> extension's address space.** The system provides a default appearance for any
> methods that your subclass doesn't override, **or if it takes too long** to
> return a configuration."

**DESIGN:**
- The extension does zero computation. The app pre-resolves every string and
  every colour (as RGBA components from `HopPottyDesignTokens`) into the App
  Group payload; the extension reads and assembles.
- The Hop icon ships **inside the extension bundle** as a pre-rendered PNG at the
  needed size. No SVG rasterisation, no `Art/` pipeline at runtime.
- No `HopCopy` lookup logic in the extension. The app writes the four final
  strings. Copy still originates in `HopCopy` — resolution just happens in the
  app, which keeps the copy-safety test meaningful (Contract §5, §4.4).

### Shield actions

[`ShieldActionDelegate`](https://developer.apple.com/documentation/managedsettings/shieldactiondelegate),
three overloads (application / web domain / category):

```
func handle(action: ShieldAction, for application: ApplicationToken,
            completionHandler: @escaping (ShieldActionResponse) -> Void)
```

"The system doesn't provide the name of a shielded `Application`, `WebDomain`, or
`ActivityCategory` to preserve the Family Sharing group's privacy. Instead, the
system uses a token."

| `ShieldAction` | iOS |
| --- | --- |
| `.primaryButtonPressed` | 15.0 |
| `.secondaryButtonPressed` | 15.0 |
| `.firstSecondarySubmenuItemPressed` / `.second…` / `.third…` | 26.4 |

| `ShieldActionResponse` | iOS | Apple's description |
| --- | --- | --- |
| `.close` | 15.0 | "close the current application or web browser" |
| `.defer` | 15.0 | "delay an immediate response … the shield **redraws its UI**, which gives your extension … an opportunity to reconfigure the shield's appearance" |
| `.none` | 15.0 | "the system doesn't need to take any additional action" |
| `.openParentalControlsApp` | **26.5** | "open your parental controls app that is responsible for shielding the application or web browser" |

---

## 7. Can a shield open HopPotty? — the critical UX question

**Answer: only on iOS 26.5 and later, and only via `ShieldActionResponse.openParentalControlsApp`.**
([doc](https://developer.apple.com/documentation/managedsettings/shieldactionresponse/openparentalcontrolsapp))

Below iOS 26.5 there is **no documented mechanism**:

- The only responses are `.close`, `.defer`, `.none`. None of them launches an app.
- `ShieldActionDelegate` inherits from `NSObject`, not `UIViewController` — it has
  no `extensionContext`, so the usual app-extension `open(_:completionHandler:)`
  escape hatch is not available.
  ([ShieldActionDelegate](https://developer.apple.com/documentation/managedsettings/shieldactiondelegate))
- The sibling ShieldConfiguration extension is explicitly sandboxed against
  "moving sensitive content outside the extension's address space."
- Apple's own WWDC21 introduction lists exactly two outcomes: "close the shielded
  application or defer action and redraw the shield configuration."
  ([session 10123](https://developer.apple.com/videos/play/wwdc2021/10123/))

**Do not design the pre-26.5 experience around a deep link from the shield.**

### What we do instead

The shield does not need to open HopPotty, because **the shield-action extension
can end the pause itself** — `ManagedSettingsStore` is available to extensions and
named stores are shared with the app (§5). The closest supported experience:

| iOS | "I'm all done" tap on the shield |
| --- | --- |
| **17.0 – 26.4** | ShieldAction ext clears `.pottyPause` store → appends an outcome record to the App Group → returns `.close`. The child lands on the Home Screen with their app un-dimmed and re-openable. HopPotty is *not* brought forward; it drains the outcome record and awards the star the next time it is opened. |
| **26.5+** | Same, but return `.openParentalControlsApp` so HopPotty comes forward and the child sees the star land immediately. Runtime-gated with `if #available(iOS 26.5, *)`. |

**DESIGN — reward timing must be lag-tolerant.** The star for finishing a pause is
earned at the moment of the tap and *rendered* whenever HopPotty is next opened.
The ledger is append-only and idempotent (Contract §4.2), so a duplicate drain is
harmless. Never write child-facing copy that promises an immediate star.

**UNVERIFIED — confirm on device:** whether `.close` on a *shielded* app returns
to the Home Screen or to the previous app, and whether the shield redraws or
disappears when the store is cleared inside the same `handle` call.

---

## 8. Target topology

```
HopPottyKit/  (SPM, Foundation-only, no Apple UI/Screen Time)    ← linked by all four
 ├─ HopPottyCore          domain models, pause state machine, copy
 ├─ HopPottyDesignTokens  palette, type scale, motion
 └─ HopPottyFixtures      test data

HopPotty.app                             com.<team>.hoppotty
 ├─ Extensions/Monitor              (1)  …hoppotty.monitor        DeviceActivityMonitor
 ├─ Extensions/ShieldConfiguration  (2)  …hoppotty.shieldconfig   ShieldConfigurationDataSource
 └─ Extensions/ShieldAction         (3)  …hoppotty.shieldaction   ShieldActionDelegate
```

Xcode supplies the extension point identifiers via its Screen Time API templates
("Device Activity Monitor, Device Activity Report, Shield Action, or Shield
Configuration"), and enables Family Controls on them automatically
([Configuring Family Controls](https://developer.apple.com/documentation/xcode/configuring-family-controls)).
Do not hand-write `NSExtensionPointIdentifier`.

| Target | Links | Never links | Job |
| --- | --- | --- | --- |
| **HopPotty** (app) | FamilyControls, ManagedSettings, DeviceActivity, SwiftUI, SwiftData, HopPottyKit | ManagedSettingsUI | Authorization, picker, schedules, starting a pause, reconciliation, the only SwiftData writer |
| **Monitor ext** | DeviceActivity, ManagedSettings, HopPottyCore | SwiftUI, SwiftData, DesignTokens | Timer-driven end of pause + backstop |
| **ShieldConfiguration ext** | ManagedSettingsUI, ManagedSettings | DeviceActivity, SwiftData, SwiftUI | Read pre-resolved payload → build `ShieldConfiguration` |
| **ShieldAction ext** | ManagedSettings, HopPottyCore | ManagedSettingsUI, SwiftData, SwiftUI | Handle taps, clear the store, append outcome |

A fourth extension type exists (`DeviceActivityReportExtension`, iOS 16+) for
parent-facing usage charts. **HopPotty does not ship it.** Contract §4.7 forbids
engagement mechanics, and §4.5 forbids anything that reads as a judgement of the
child's day. Revisit only with a specific caregiver need.

---

## 9. Potty Pause — state and data flow

### The hard constraint

A Potty Pause is minutes long. `DeviceActivitySchedule`'s **minimum interval is 15
minutes** ([`.intervalTooShort`](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltooshort)),
and `DeviceActivityEvent.threshold` counts *usage*, not wall clock (§4). **There is
therefore no Screen Time mechanism that ends a 5-minute shield on a 5-minute
wall-clock timer while HopPotty is not running.**

### The design that works within it

Four independent end-paths, each of which alone is sufficient. The pause ends on
whichever fires first.

```
                    caregiver taps "Potty Pause"   (or a HopPotty reminder is acted on)
                                 │
        app: write PauseRecord ──┼── app: store.shield.applications = tokens
        to App Group             │   (ManagedSettingsStore(named: .pottyPause))
                                 │
        app: startMonitoring(.pottyPauseBackstop,
             schedule = [now, now+15min], repeats: false,
             warningTime = 15min − plannedDuration)
                                 │
   ┌─────────────┬───────────────┼────────────────┬──────────────────┐
   │             │               │                │                  │
 (A) child     (B) Monitor    (C) Monitor       (D) app foreground  (E) caregiver
 taps shield   intervalWill-  intervalDidEnd    reconcile           override
 button        EndWarning     (15-min backstop) (now >= plannedEnd) (parent gate)
   │             │               │                │                  │
   └─────────────┴───────────────┴────────────────┴──────────────────┘
                                 │
              clearAllSettings() on .pottyPause store
              + append PauseOutcome{ endedAt, reason } to App Group
              + stopMonitoring([.pottyPauseBackstop])
                                 │
              app (next foreground): drain outcomes → SwiftData → award star
```

| Path | Runs in | Latency | Reliability |
| --- | --- | --- | --- |
| (A) child taps the shield's primary button | ShieldAction ext | immediate | deterministic — requires a tap |
| (B) `intervalWillEndWarning` at the intended duration | Monitor ext | intended duration | **UNVERIFIED** — warning-callback gating and punctuality unmeasured (§4) |
| (C) `intervalDidEnd` at +15 min | Monitor ext | ≤ 15 min, and only "when the device is in use" | documented backstop |
| (D) reconciliation on foreground | App | next launch | deterministic |
| (E) caregiver override behind the parent gate | App | immediate | deterministic |

Worst case, with the device face-down and untouched: the shield outlives the
intended pause. That is acceptable — nobody is looking at the device — and it is
bounded by (C) and then (D).

**This satisfies Contract §4.1.** Every path ends the pause on time, on
completion, or on override. No path consults an outcome. There is no code that
*extends* a pause, and none may be added.

### Reconciliation is the load-bearing invariant

**DESIGN:** on every app foreground and at the top of every extension callback:

```
if let pause = appGroup.activePause, Date() >= pause.backstopEndAt {
    clear the .pottyPause store; append outcome(.backstop); stop monitoring
}
```

This is what makes the whole design robust against an undocumented reboot policy,
a missed callback, a killed extension, and a token that expired underneath us.

---

## 10. The App Group boundary

Apple documents app groups as the mechanism for sharing "data between an app
extension … and its host app," via `UserDefaults(suiteName:)` or
`containerURL(forSecurityApplicationGroupIdentifier:)`
([Configuring app groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)).
Apple does **not** document a Screen Time-specific requirement — but named
`ManagedSettingsStore`s are the only thing shared automatically (§5), so
everything else is on us.

### App → extensions (written by the app, read-only to extensions)

| Payload | Format | Read by | Why it must be pre-resolved |
| --- | --- | --- | --- |
| `Selection` — encoded `FamilyActivitySelection` per child | JSON file | Monitor | Extensions must never run the picker |
| `PauseRecord` — `id`, `childID`, `startedAt`, `plannedEndAt`, `backstopEndAt`, `activityName`, `storeName` | single JSON file, atomic write | Monitor, ShieldAction | The one source of truth for "is a pause running" |
| `ShieldPresentation` — `title`, `subtitle`, `primaryButtonLabel`, `secondaryButtonLabel` (final strings) + `titleColorRGBA`, `backgroundRGBA`, `primaryButtonRGBA`, `blurStyleRawValue` | JSON file | ShieldConfiguration | The data source must return "as quickly as possible" and cannot compute |
| `AuthorizationSnapshot` — status + last successful registration | JSON file | all three | Extensions must not call FamilyControls |

### Extensions → app (append-only; the app drains and deletes)

| Payload | Written by | Format | Consumed as |
| --- | --- | --- | --- |
| `PauseOutcome` — `pauseID`, `endedAt`, `reason` ∈ {`childCompleted`, `timer`, `backstop`, `overridden`} | ShieldAction, Monitor | one small JSON file per outcome in an `outbox/` directory | A `PottyEvent` + at most one `RewardTransaction`, keyed by `pauseID` for idempotency |
| `ExtensionBreadcrumb` — `callback`, `at`, optional `failure` | Monitor, ShieldAction, ShieldConfiguration | one file per record, capped ring | Parent-facing diagnostics + our own on-device verification of the UNVERIFIED items |

**DESIGN rules on the boundary:**

1. **One writer per file.** The app owns the inbound files; extensions own
   `outbox/`. No read-modify-write across the process boundary, which is why
   `outbox/` is a directory of single-record files rather than one array.
2. **SwiftData never crosses.** Only the app opens the `ModelContainer`.
   Extensions read and write plain `Codable` structs from `HopPottyCore`.
3. **Tokens stay in the payload.** They are `Codable` and opaque; they may be
   written to the App Group container. They may never be logged, hashed into an
   analytics key, or sent off-device.
4. **`bundleIdentifier` / `localizedDisplayName` never cross.** They are readable
   only inside the ShieldConfiguration extension, and they stay there (§3).
5. **Every payload is versioned** (`schemaVersion: Int`). An extension that reads
   a version it does not understand does nothing and appends a breadcrumb — it
   must never crash, because a crashing shield extension yields the system default
   shield, which carries Apple's copy, not ours.

---

## 11. Platform limitations and how we work within them

| # | Limitation | Source | How HopPotty works within it |
| --- | --- | --- | --- |
| 1 | **A shield cannot open HopPotty below iOS 26.5.** | [`.openParentalControlsApp` is iOS 26.5+](https://developer.apple.com/documentation/managedsettings/shieldactionresponse/openparentalcontrolsapp) | The shield-action extension *ends the pause itself* and returns `.close`; the star is drained and shown at next launch. `.openParentalControlsApp` is a runtime-gated enhancement, never a requirement. Child copy never promises an instant star. |
| 2 | **Minimum DeviceActivity interval is 15 minutes.** | [`.intervalTooShort`](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltooshort) | The intended duration is delivered by `warningTime` inside a 15-minute schedule; the 15-minute `intervalDidEnd` is the guaranteed backstop; foreground reconciliation is the floor. |
| 3 | **Callbacks fire only "when the device is in use."** | [DeviceActivityCenter](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter) | Nothing time-critical depends on a callback. Every end-path is idempotent and the app reconciles on foreground. |
| 4 | **The shield is a fixed layout.** Blur, background colour, one static `UIImage`, title, subtitle, primary button (label + colour), optional secondary button, and (26.4+) ≤3 submenu items. No custom views, no fonts, no animation. | [ShieldConfiguration](https://developer.apple.com/documentation/managedsettingsui/shieldconfiguration) | Hop appears as a single pre-rendered PNG. All warmth lives in colour and copy. Contract §6's Reduce Motion rule is trivially satisfied — the shield cannot animate. **The shield is the one child-facing surface where our design system does not apply; design it as its own artefact.** |
| 5 | **The configuration extension is sandboxed and time-limited**; slow or absent responses yield Apple's default shield. | [ShieldConfigurationDataSource](https://developer.apple.com/documentation/managedsettingsui/shieldconfigurationdatasource) | Zero computation in the extension; everything pre-resolved by the app (§10). Falling back to the system shield is a *user-visible copy failure* (Apple's words, not `HopCopy`'s), so treat a slow data source as a P1. |
| 6 | **50-token cap per shield property.** | [applications](https://developer.apple.com/documentation/managedsettings/shieldsettings/applications-swift.property) | Cap the picker; explain the cap in caregiver copy. Prefer categories over long app lists. |
| 7 | **Tokens are opaque and revocable**; identity is legible only inside the ShieldConfiguration extension; tokens are voided on revocation and can expire (26.5 adds refresh). | [FamilyActivitySelection](https://developer.apple.com/documentation/familycontrols/familyactivityselection), [TokenExpiryMessage](https://developer.apple.com/documentation/managedsettings/managedsettingsstore/tokenexpirymessage) | We store counts, never identities (`ScreenTimeConfiguration` already does this correctly). On `.unauthorized` we clear the selection and route the caregiver to re-authorize. HopPotty never requests `approvedWithDataAccess` — we have no use for real bundle identifiers, and asking for them would be a privacy regression. |
| 8 | **Authorization can be revoked or lost externally** (Settings, child ages out, another parental-controls app wins). | [authorizationStatus](https://developer.apple.com/documentation/familycontrols/authorizationcenter/authorizationstatus), [`.authorizationConflict`](https://developer.apple.com/documentation/familycontrols/familycontrolserror/authorizationconflict) | Subscribe to `$authorizationStatus`; on loss, clear the store, end any pause as `.overridden`, and show a caregiver explainer. Never fail silently — `ScreenTimeConfiguration.lastRegistrationFailure` exists for exactly this. |
| 9 | **`AuthorizationStatus` has no `.restricted` case.** | [AuthorizationStatus](https://developer.apple.com/documentation/familycontrols/authorizationstatus) | Derive `.restricted` from `FamilyControlsError.restricted` and fix the comment in `ScreenTimeConfiguration.swift` (§3). |
| 10 | **Max 20 monitored activities** app-wide. | [`.excessiveActivities`](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/excessiveactivities) | One backstop activity at a time, plus at most one scheduled activity per child. Reuse `DeviceActivityName`s (re-registering overwrites) rather than accumulating them. |
| 11 | **Authorization fails outright on visionOS.** | [Family Controls](https://developer.apple.com/documentation/familycontrols) | Not a target platform. Do not ship a visionOS-compatible build claiming pause support. |
| 12 | **The system decides effective settings**; ours are inputs, not guarantees. | [ManagedSettingsStore](https://developer.apple.com/documentation/managedsettings/managedsettingsstore) | Never tell a caregiver "these apps are blocked." Say what HopPotty asked for. Never assert a shield is up without having observed it. |

---

## 12. Consolidated UNVERIFIED list

Every item below must be measured on a physical device with a real Family
Controls authorization before any code depends on it. Log each result back into
this document with the date and the device/OS.

| # | Question | Blocks |
| --- | --- | --- |
| 1 | Do `ManagedSettingsStore` shield settings survive a reboot? A force-quit? An app update? | §5 reconciliation tuning |
| 2 | Are `intervalWillEndWarning` / `eventWillReachThresholdWarning` gated on "device in use" like the `did` callbacks, and how punctual are they? | Path (B) in §9 — the intended pause duration |
| 3 | The DeviceActivityMonitor extension's actual memory ceiling and time budget. | §4 extension budget |
| 4 | What happens when a shield property exceeds 50 tokens. | §5 picker cap |
| 5 | After the ShieldAction extension calls `clearAllSettings()` and returns `.close`, where does the child land, and does the shield redraw? | §7 child UX |
| 6 | Does `ApplicationToken` expire on iOS < 26.5, and what does a stale token do to a live shield? | §3 token lifetime |
| 7 | Does Family Controls authorization work at all in the iOS Simulator? Apple documents nothing either way. | Test strategy — see `Docs/Entitlements.md` |
| 8 | Minimum usable `DeviceActivityEvent.threshold` granularity. | Any future usage-based feature |
| 9 | Whether `Application.localizedDisplayName` is reliably non-`nil` in the ShieldConfiguration extension for every shielded app (Apple says it is provided; unproven for e.g. system apps). | Shield subtitle copy fallback |

---

## 13. Sources

All URLs retrieved 2026-09-01.

- Screen Time Technology Frameworks — https://developer.apple.com/documentation/screentimeapidocumentation
- Family Controls — https://developer.apple.com/documentation/familycontrols
- Managed Settings — https://developer.apple.com/documentation/managedsettings
- Managed Settings UI — https://developer.apple.com/documentation/managedsettingsui
- Device Activity — https://developer.apple.com/documentation/deviceactivity
- Manage settings on devices in a Family Sharing group — https://developer.apple.com/documentation/managedsettings/connectionwithframeworks
- Configuring Family Controls — https://developer.apple.com/documentation/xcode/configuring-family-controls
- Configuring app groups — https://developer.apple.com/documentation/xcode/configuring-app-groups
- WWDC21 *Meet the Screen Time API* — https://developer.apple.com/videos/play/wwdc2021/10123/
- WWDC22 *What's new in Screen Time API* — https://developer.apple.com/videos/play/wwdc2022/110336/
