# Privacy Architecture

**Date:** 2026-09-01
**Position:** Local-first. No account. No analytics SDK. No ads. No network
request carrying family data.

HopPotty holds a record of when a three-year-old used a toilet. That is a health
record about a child who cannot consent, kept in a consumer app. The design
question was never "how do we secure the pipeline" — it was "what pipeline?"

---

## 1. The four commitments

1. **No account.** No sign-up, no email, no password, no Apple Sign-In, no
   device identifier. Onboarding never asks who you are.
2. **No analytics SDK.** No Firebase, Amplitude, Segment, Mixpanel, Sentry,
   AppsFlyer, Adjust, Branch, or any successor. The app has **zero third-party
   runtime dependencies**; `Package.swift` declares no external packages.
3. **No advertising.** No ad SDK, no house ads, no cross-promotion, no IDFA. The
   app declares no `NSUserTrackingUsageDescription` because there is nothing to
   ask for.
4. **No child data leaves the device.** There is no server. The only network
   traffic the app can generate is Apple's own: StoreKit, and whatever the system
   does for Family Controls authorization. Neither carries a `PottyEvent`, a
   nickname, a note, a star, or a Screen Time token.

Entitlements deliberately **not** requested: push notifications, iCloud/CloudKit,
keychain sharing, background modes beyond DeviceActivity, and
`com.apple.developer.family-controls.app-and-website-usage` (which would hand us
real app identifiers we have no use for). See `Docs/Entitlements.md` §1.

---

## 2. Complete data inventory

Everything the app holds. If it is not in this table, HopPotty does not store it.

| DATA | WHY IT EXISTS | WHERE STORED | RETENTION | SYNC STATUS | WHO CAN ACCESS | DELETION METHOD |
| --- | --- | --- | --- | --- | --- | --- |
| **Child nickname** (optional, ≤24 chars) | So Hop can address the child by name; the UI falls back to neutral phrasing without it | SwiftData, app container | Until deleted by the caregiver | **Never synced.** No iCloud, no CloudKit, no backend | The app process only. Never logged, never exported without the caregiver initiating an export, never sent to an extension | Settings → Child → Remove; or Delete everything. Clearing the field also removes it |
| **Avatar + pond theme** | The child's chosen character and world | SwiftData | Until deleted | Never synced | App only | Deleted with the profile |
| **Child UUID** | Scopes every row to one child | SwiftData; also inside App Group only as a *derived pause session id*, never the child id itself | Until profile deletion | Never synced | App only. Logs carry a per-launch 4-hex tag, never the UUID | Deleted with the profile |
| **Potty events** (timestamp, kind, source, `pauseSessionID`) | The timeline and every insight | SwiftData | Until deleted; nothing expires on its own | Never synced | App only | Clear history · Delete this child · Delete everything |
| **Caregiver note on an event** (free text) | A parent's private aide-mémoire | SwiftData | Until the event is deleted | Never synced | **Caregiver only.** Never shown to the child, never logged, and excluded from an export when the caregiver says so | Delete the event, or clear the note |
| **Reward transactions** (ledger rows: reason, quantity, timestamp, idempotency key) | Hop Stars, and the ability to answer "why do I have 34 stars?" | SwiftData, `idempotencyKey` unique | Until "Reset rewards" or profile deletion | Never synced | App only | Reset rewards · Delete this child · Delete everything |
| **Pond progress** (unlocked item ids + dates) | So the pond remembers when each thing arrived | SwiftData | As above | Never synced | App only | As above |
| **Potty schedule** (mode, basis, interval, warning, duration, cooldown, active window/days, quiet windows, suspension) | The whole timer system | SwiftData | Until changed or the child is deleted | Never synced | App only | Deleted with the profile; reset by Delete everything |
| **Screen Time configuration** (3 counts + authorization status + last registration/failure) | So the parent UI can explain itself instead of silently doing nothing | SwiftData | Until changed | Never synced | App only | Deleted with the profile |
| **`FamilyActivitySelection`** (opaque Apple tokens) | The monitor extension cannot shield without it | App Group container, `selection.json`, as Apple's own `Codable` blob | Until the caregiver changes the selection, or authorization is lost | Never synced. **Included in device backups** by virtue of being in the container | App + the three extensions holding the entitlement | Change or clear the selection; Delete everything; uninstalling removes the container |
| **App settings** (sound, captions, haptics, notification prefs, gate style, active child, onboarding flag) | Device-wide preferences | SwiftData, single row | Until changed | Never synced | App only | Delete everything resets to defaults |
| **Quiz / game play counts** | "How many times did you play", for the caregiver | SwiftData | Until profile deletion | Never synced | App only | Deleted with the profile |
| **App Group: `pause.json`** (schemaVersion, opaque session id, coarse state, three instants, failure code) | The one source of truth for "is a pause running" across four processes | App Group container | Overwritten per pause; removed when the pause ends | Never synced. In device backups | App + three extensions | Ends with the pause; Delete everything clears the container; uninstall removes it |
| **App Group: `widget.json`** (schemaVersion, next pause instant, pause end instant, quick reminder instant, schedule-enabled flag, Hop pose name, generated-at; child display name is a field that is **off by default**) | The home-screen widget and Live Activity run in their own process and can only show what the app hands them | App Group container | Overwritten on every schedule or pause change | Never synced. In device backups | App + widget extension (no Family Controls entitlement) | Delete everything clears the file; uninstall removes the container. Carries no outcomes, no counts, no app tokens — see `Docs/Widgets.md` |
| **App Group: `shield.json`** (four final strings + four RGBA colours + blur style) | The configuration extension must return immediately and cannot compute | App Group container | Overwritten when the shield design or copy changes | Never synced | App + ShieldConfiguration extension | As above |
| **App Group: `outbox/*.json`** (`pauseID`, `endedAt`, reason) | Extensions report an outcome the app drains later | App Group container | Deleted by the app on drain | Never synced | App + extensions | Drained automatically; Delete everything clears |
| **App Group: `heartbeat/*` breadcrumbs** (callback kind, timestamp, optional failure enum — **no `String` field exists**) | Parent-facing diagnostics and on-device verification of the UNVERIFIED items | App Group container, capped ring | Overwritten | Never synced | App + extensions | Capped ring; Delete everything clears |
| **`ManagedSettingsStore(named: "pottyPause")`** shield state | The pause itself | **iOS system state**, outside HopPotty's container | Cleared when the pause ends, and by every fail-safe path | Never synced | The system; HopPotty can set and clear it | Any pause end path · Restore Screen Access · uninstall |
| **"Authorization was once granted" flag** | Apple's `authorizationStatus` starts at `.notDetermined` every launch, so without it HopPotty cannot tell a returning authorized family from a new one | App's **private** `UserDefaults` (deliberately not the App Group — no extension needs it) | Until authorization is revoked or the app is deleted | Never synced | App only | Delete everything; uninstall |
| **OSLog entries** | Debugging a family's problem | System log, on device | Apple's own log rotation | Never synced by HopPotty | Anyone with the unlocked device and a Mac; included in sysdiagnose | Not deletable by HopPotty — which is exactly why nothing identifying is ever put in one (§4) |
| **StoreKit purchase state** | One non-consumable unlock | Apple's account systems | Apple's | **Synced by Apple** to the family's Apple Account | Apple + the app | Apple's process. HopPotty stores no receipt of its own |
| **Exported file** (caregiver-initiated) | The caregiver's right to a copy | The app's own container, then wherever the caregiver moves it | Until the caregiver removes it | Never uploaded by HopPotty | The caregiver, and whatever they share it with | Delete the file |

### Never collected, at all

Legal name · date of birth · age · gender · address · phone number · email ·
photographs · contacts · precise or coarse location · IP-derived geography ·
device identifiers (IDFA, IDFV, advertising id) · health data from HealthKit ·
microphone or camera input · biometric data (Face ID is verified by the system;
HopPotty receives a yes/no) · browsing history · the identity of any app the
child uses · crash reports containing user data · any usage telemetry of any kind.

---

## 3. Why local-first, concretely

- **There is no server to breach.** A breach requires a database; there is not one.
- **There is no subpoena target.** HopPotty's operators cannot produce a family's
  data because they never have it.
- **There is no "we updated our privacy policy".** The architecture, not the
  policy, is the promise.
- **Nutrition Label:** "Data Not Collected" for every category. The app makes no
  network request that carries user data, so this is a statement of fact rather
  than an interpretation.
- **COPPA / GDPR-K:** with no collection, no transmission and no third party,
  the compliance surface is the device itself. Verifiable parental consent is not
  required because there is nothing to consent to — but the parent gate still
  guards every action with consequences.

The trade accepted: **no cross-device sync and no cloud backup of HopPotty's own
data.** A family that replaces a device restores from an iCloud device backup
(which includes the app container) or starts fresh. That is a real cost, taken
knowingly. If sync is ever added it must be an explicit, gated, per-family
opt-in, and this document changes first.

---

## 4. What is never logged, and why the rule is structural

`HopLog` (`HopPotty/Core/HopLog.swift`). A log line is not a private place:
`OSLog` messages are readable in Console.app by anyone with the device unlocked
and a Mac, they are collected into sysdiagnose archives that get emailed to
support desks, and public-formatted values are retained on disk.

So the rule is not "be careful what you log" — it is **the identifying value never
enters the logging call in the first place.**

| Never | Why |
| --- | --- |
| Nicknames | It is the child's name. That is the whole of the identity HopPotty holds. |
| Free-text notes | Caregiver-written, often intimate or medical. |
| App / category selections | Reveals what the child watches and, transitively, the household. |
| Raw child UUIDs | Stable across launches, so a log archive can be joined to an export or a crash report. |
| An event kind tied to a time | "poop at 14:03" is a health record with a timestamp on it. |

What *is* logged: counts, durations, enum case names for **configuration** (not
outcomes), failure kinds, and state-machine transitions. Child identity in a log
is a four-hex-digit tag from `UUID.hashValue`, which Swift seeds per process —
stable within one launch, different on the next, so it cannot correlate two
sysdiagnoses taken a week apart. Errors are reduced to `domain#code`, because
`localizedDescription` on a SwiftData failure can interpolate the offending row's
values into the message.

---

## 5. The App Group boundary as a privacy boundary

An App Group container is readable by **every target holding the entitlement** and
is included in device backups. A parenting app puts the least it can across that
line, not the most it conveniently could.

Nothing about a child crosses it: no identifier, nickname, age, pronouns or
notes; no `PottyEvent`; no ledger; no schedule; no insight. The pause record
carries an **opaque per-pause session id** — a random UUID, not derived from and
not resolvable to a child. The app keeps the session-to-child mapping in its own
private store, which is where that mapping belongs.

The prohibition on free text is structural rather than advisory:
`ExtensionReport` has **no `String` field a caller could fill in.** Everything it
can say, it says with an enum. That is the only way to be sure that the one
extension which *can* read `Application.localizedDisplayName` never writes one out
by accident.

---

## 6. Export

- Caregiver-initiated only, behind the parent gate (`exportData`).
- Written into the app's own container; the caregiver moves it wherever they
  like. **Nothing is uploaded.**
- Caregiver notes are the most sensitive field in the store, so their inclusion
  is an explicit choice at export time, not a default.
- The export contains no Screen Time token, no raw internal identifier that is
  useful outside the app, and no log material. See `Docs/SecurityReview.md` §5.

---

## 7. Deletion

Four operations, each behind the parent gate, each stating **exact counts before
it runs** and returning a receipt afterwards (`CONTRACTS.md` §4.6):

| Operation | Removes |
| --- | --- |
| Clear history | Potty events. Stars from deleted events are unlinked, never removed — and the receipt says how many were kept. |
| Reset rewards | Ledger + pond for one child. All-or-nothing. |
| Delete this child | Every row belonging to that child, profile included. |
| Delete everything | Every child, every table, settings back to defaults, App Group container cleared. |

Deleting the app removes the app container, the App Group container, and the
private `UserDefaults`. The `ManagedSettingsStore` is system state and is cleared
by every pause-end path, by "Restore Screen Access", and by uninstalling the app.

**No data is retained after deletion**, because there is nowhere for it to be
retained.

---

## 8. Third parties

None at runtime. To be explicit about what a reviewer might expect to find:

| Category | HopPotty |
| --- | --- |
| Analytics / crash reporting | None. Not even Apple's opt-in analytics is read by the app. |
| Advertising / attribution | None |
| A/B testing, feature flags, remote config | None. No remote kill switch, no remote content. |
| Push / messaging | None. No push entitlement. |
| Backend, auth, sync | None |
| Fonts, images, sounds fetched at runtime | None. Everything ships in the bundle. |
| Payment | Apple StoreKit only |
| Build-time only | XcodeGen (project generation), and the render harness's OFL fonts, which are not in the app |

---

## 9. Honest limits

1. **Device backups.** SwiftData and the App Group container are included in an
   encrypted iCloud or local backup. HopPotty does not opt out — a family losing
   a device should not lose their child's pond. This is Apple's encryption, not
   ours, and it means the data does leave the device *at the user's own direction*.
2. **Logs.** OSLog entries are outside HopPotty's control once written, which is
   why §4 is a hard rule rather than a preference.
3. **StoreKit.** Purchase state is Apple's and syncs across the family's devices.
   HopPotty stores no receipt.
4. **Not yet verified.** Nothing in this document has been checked against a
   running app, because no app has run. The claims are structural — "there is no
   networking code" is checkable by reading; "no data was transmitted" needs a
   proxy capture on a device, and is on the QA plan
   (`Docs/QATestPlan.md`, `Docs/SecurityReview.md`).
