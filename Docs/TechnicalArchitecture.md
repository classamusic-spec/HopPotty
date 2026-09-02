# Technical Architecture

**Date:** 2026-09-01
**Related:** `CONTRACTS.md` (boundaries), `ADR/0001` (why the package exists),
`ADR/0002` (iOS 17 floor), `ScreenTimeArchitecture.md` (Apple's constraints),
`BUILD_STATUS.md` (what is actually verified)

**Verification boundary, stated once and meant throughout:** `HopPottyKit`
compiles and its tests execute on Swift 6.2 for Linux — **350 tests across 28
suites, all passing** (observed 2026-09-01). Nothing in `HopPotty/` or
`Extensions/` has ever been compiled: there is no Xcode, no simulator, no device,
and no Family Controls entitlement in this environment.

---

## 1. Module topology

```
HopPottyKit/                        SPM package. Foundation only.
  Sources/HopPottyCore              models · scheduling · rewards ·
                                    state machine · insights · content
  Sources/HopPottyDesignTokens      colour · type · spacing · motion · metrics
  Sources/HopPottyFixtures          deterministic sample data
  Sources/hoptokens                 executable: exports tokens.json for the
                                    render harness
        ▲ linked by all four targets, depends on none of them
        │
HopPotty.app  ── SwiftUI · SwiftData · FamilyControls · ManagedSettings ·
   │             DeviceActivity · StoreKit
   ├─ Extensions/HopPottyDeviceActivityMonitor
   ├─ Extensions/HopPottyShieldConfiguration
   └─ Extensions/HopPottyShieldAction
```

The rule (`CONTRACTS.md` §1): if a type can be expressed without Apple UI
frameworks, it belongs in `HopPottyCore`. Business logic in a `View` is a defect.

`HopPottyCore` imports **only Foundation** — no SwiftUI, no SwiftData, no
FamilyControls/DeviceActivity/ManagedSettings — and must keep compiling on Linux.
That constraint is what makes the riskiest code testable: interval arithmetic
across DST, quiet-hour precedence, reward idempotency under crash, and shield
restoration are all pure functions of an injected `Calendar` and an explicit
`now`.

---

## 2. The four Xcode targets

The Xcode project does not exist yet; targets are declared in `project.yml`
(XcodeGen) plus `Config/*.xcconfig`, and the four `Info.plist` / `.entitlements`
files are hand-written so the `NSExtension` dictionaries are reviewable in a diff.

| Target | Bundle ID (placeholder) | Links | Never links | Job |
| --- | --- | --- | --- | --- |
| **HopPotty** (app) | `com.hoppotty` | FamilyControls, ManagedSettings, DeviceActivity, SwiftUI, SwiftData, StoreKit, HopPottyKit | ManagedSettingsUI | Authorization, picker, schedules, starting a pause, reconciliation. **The only SwiftData writer.** |
| **DeviceActivityMonitor ext** | `…​.monitor` | DeviceActivity, ManagedSettings, HopPottyCore | SwiftUI, SwiftData, DesignTokens | Timer-driven end of pause + the 15-minute backstop |
| **ShieldConfiguration ext** | `…​.shieldconfig` | ManagedSettingsUI, ManagedSettings | DeviceActivity, SwiftData, SwiftUI | Read a pre-resolved payload → return a `ShieldConfiguration`. Zero computation. |
| **ShieldAction ext** | `…​.shieldaction` | ManagedSettings, HopPottyCore | ManagedSettingsUI, SwiftData, SwiftUI | Handle taps, clear the store, append an outcome |

A fifth extension type exists (`DeviceActivityReportExtension`) and is
**deliberately not shipped** — it is an engagement surface that reads as a
judgement of the child's day.

Four files must be members of all four targets:
`ScreenTimeIdentifiers.swift`, `AppGroupStore.swift`, `SharedPauseTypes.swift`,
`ShieldReconciler.swift`. A disagreement about the `ManagedSettingsStore` *name*
between app and extension is precisely the bug that strands a shield the app
cannot clear. A shared embedded framework was rejected: it adds launch cost to
three latency-sensitive extensions to express what three lines of build config
already express.

### 2.1 Build configurations

| Configuration | Conditions | Notes |
| --- | --- | --- |
| Debug | `DEBUG`, `HOPPOTTY_DEBUG_TOOLS` | Warnings are errors here, deliberately not in Release |
| DebugMock | + `HOPPOTTY_MOCKS` | Every external service replaced by an in-memory fake, chosen at **compile** time. Display name "HopPotty Mock". |
| Release | none of the above | Additionally strips `HopPotty/Developer/*` via `EXCLUDED_SOURCE_FILE_NAMES`, so an unguarded debug file cannot ship. `EXCLUDED_SOURCE_FILE_NAMES` in this spelling is **UNVERIFIED** until Xcode exists; the `#if` guards remain primary. |

Swift 6 language mode with `SWIFT_STRICT_CONCURRENCY = complete` on all targets.
Deployment target 17.0 everywhere, matching `.iOS(.v17)` in `Package.swift`.

---

## 3. Service boundaries

Every service is a protocol ending in `Providing`, so the concrete type keeps the
good name (`CONTRACTS.md` §3). The app ships a real conformance and an in-memory
fake for previews, simulator runs and UI tests.

| Protocol | Concrete | Responsibility | Explicitly not its job |
| --- | --- | --- | --- |
| `ScreenTimeProviding` | `ScreenTimeService` | The **only** file importing FamilyControls/ManagedSettings. Authorization, selection persistence, monitoring registration, apply/clear shield, emergency clear. | Deciding anything. The state machine decides; this performs. |
| `NotificationProviding` | `NotificationService` / `MockNotificationService` | Local notifications only: the pre-pause warning and the optional daily summary. | Push. There is no `aps-environment` entitlement. |
| `QuickReminderProviding` | `QuickReminderService` / `MockQuickReminderService` | One-off caregiver reminders: plan, schedule, cancel, reconcile. Rules live in `QuickReminderPlanner` (Core). | Shielding anything. It touches no ManagedSettings and no schedule. |
| `PurchaseProviding` | — | StoreKit product load, purchase, entitlement. `displayPrice` is never composed by HopPotty. | Gating anything a child earned. |
| `DataExportProviding` | — | Writes a file into the app's own container. | Networking. Nothing leaves the device. |
| `DataDeletionProviding` | `DataDeletionService` | Counts first, deletes second, reports a receipt. | Estimating. Counts come from rows. |
| Repositories (7 protocols) | `SwiftData*Repositories` / `InMemory*Repositories` | Domain values in, domain values out. | Leaking `@Model` types upward. |
| `ShieldReconciler` | — | The fail-safe. Runs at app foreground, every monitor callback, every shield draw, every shield tap. | Deciding a pause should continue. |
| `HopClock` | `SystemClock` / `FixedClock` | The single source of "what time is it". | Being called `Date()` behind a test's back. |

### 3.1 Two rules that keep the boundary honest

1. **Nothing but `ScreenTimeService` imports a Screen Time framework.** The answer
   to "what can shield a child's apps?" is one file long.
2. **Nothing but the app opens the `ModelContainer`.** Extensions read and write
   plain `Codable` structs from `HopPottyCore`. SwiftData never crosses the App
   Group boundary.

---

## 4. The Potty Pause state machine

`HopPottyKit/Sources/HopPottyCore/StateMachine/`

One pure, **total** function: `reduce(state:event:context:) -> TransitionOutcome`,
defined for every one of the 14 state kinds. Those expand to **50 distinct state
values** — one per `ScreenTimeFailure` (13 cases) for each of the three error
states — and there are **21 events**, so the totality and fail-safe suites walk
all **1,050 pairs**. Plus one recovery entry point, `recoverFromColdStart`.

### 4.1 States — `PottyPauseState`

`disabled` · `authorizationRequired` · `ready` · `monitoring` ·
`warningApproaching` · `pauseTriggered` · `shieldActive` · `routineActive` ·
`completing` · `restoring` · `cooldown` · `errorRecoverable(failure)` ·
`errorRequiresParent(failure)` · `errorAccessRestored(failure)`

Three derived predicates carry the safety semantics:

| Predicate | Meaning | Used for |
| --- | --- | --- |
| `isShieldConfirmedUp` | A shield is *known* up | Child-facing UI only |
| `mayHaveShieldUp` | A shield *might* be up — the conservative reading | **Every fail-safe rule** |
| `isPersistable` | Worth writing to disk | Integrity check on the persisted session |

`pauseTriggered` counts as possibly-shielded because a partially applied
`ManagedSettings` store is indistinguishable from a fully applied one.
`completing` and `restoring` count because a clear is in flight and unconfirmed.
Error states count unless the failure provably preceded any shield
(`ScreenTimeFailure.couldLeaveShieldUp`, a switch written without a `default` so a
new failure case cannot be added without someone choosing a side).

### 4.2 Events — `PottyPauseEvent`

21 cases, **none carrying a payload.** Everything a transition needs — the
instant, the schedule, the authorization status, the in-flight session — arrives
in `PottyPauseContext`. That keeps the event set `CaseIterable`, which is what
makes the "every state × every event" totality test writable at all.

Three events are accepted from **every** state and never refused:
`parentRestoredAccess`, `scheduleDisabled`, `authorizationRevoked`.

### 4.3 Effects — `PottyPauseEffect`

The reducer performs no I/O. It returns an ordered list of effects, which reduces
the iOS layer to `for effect in outcome.effects { perform(effect) }` with no
decisions of its own. **`.clearShield` is always first in any bundle containing
it**, so a crash part-way through a bundle still leaves the child's apps usable.
`.clearShield` is `store.clearAllSettings()` — idempotent by construction, so it
is emitted whenever it might help, including on paths that "know" the shield is
already down.

### 4.4 Rejection is explicit

`TransitionOutcome` has no `nil`, no `throws` and no silent no-op. An event a
state has no meaning for comes back with a `TransitionRejection` naming the state,
the event and the reason. A silent no-op is the same thing with the evidence
thrown away.

---

## 5. Data flow across the App Group

`ScreenTimeArchitecture.md` §10 is normative; this is the engineering summary.

```
<group container>/HopPotty/
  pause.json          active pause record     (app, monitor, shieldAction write)
  shield.json         pre-resolved appearance (app writes → shieldConfig reads)
  selection.json      encoded FamilyActivitySelection (app writes → monitor reads)
  heartbeat/<target>  one file per target, single writer each
  outbox/<uuid>.json  extension → app reports (extensions append, app drains)
```

**Files, not `UserDefaults`.** `Data.write(to:options:.atomic)` renames a
complete file into place, so a reader sees either the whole previous record or
the whole new one. Across four processes that can be woken and killed at
arbitrary moments, that is the difference between "a redundant clear" and "a
record that half-parses".

**One writer per file**, with one considered exception: `pause.json` has three
writers. It is safe because every lost update resolves toward clearing —
`startedAt`, `plannedEndAt` and `backstopEndAt` are `let`, written once at pause
start, so **no process can lengthen a pause**. That is `CONTRACTS.md` §4.1
expressed in the type system.

`outbox/` is a directory of single-record files rather than one array, so
appending is a create and draining is a delete — no read-modify-write across a
process boundary.

**Every payload is versioned.** A reader that finds a `schemaVersion` it does not
understand treats the record as absent — and absence means "clear the shield",
which is the correct reading of a downgrade, a restored backup, or a hand-edited
container. An extension must never crash on it, because a crashing shield
extension yields Apple's default shield with Apple's copy.

**What never crosses:** child identifier, nickname, age, notes, any `PottyEvent`,
the star ledger, the schedule, or free text of any kind. The prohibition is
structural — `ExtensionReport` has no `String` field a caller could fill in;
everything it can say, it says with an enum. Application tokens *are* permitted in
`selection.json` (opaque, `Codable` is Apple's own route, the monitor cannot
shield without them) and may never be logged, hashed into a key, or sent
off-device.

---

## 6. Fail-safe design — and the bug it caught

The failure mode of this product is not "a pause does not happen". It is **a
child whose games never come back**, with no in-app way to explain it, because
every process that knew about the pause is gone.

Five rules, all pointing the same way:

1. `.clearShield` is idempotent and emitted whenever it might help.
2. Every transition leaving a possibly-shielded state emits `.clearShield` first.
3. **Every transition into an error state emits `.clearShield`** — an error state
   is by definition one where HopPotty does not know what is true.
4. `parentRestoredAccess`, `scheduleDisabled` and `authorizationRevoked` are
   accepted from all fourteen states.
5. Cold start always clears, whatever it finds, including when nothing was
   persisted.

`ShieldReconciler` runs the same check in four places: app foreground, every
`DeviceActivityMonitor` callback, **every `ShieldConfigurationDataSource`
invocation**, and every `ShieldActionDelegate` invocation. The third is the
strongest guarantee in the design: iOS calls the configuration extension whenever
it needs to *draw* the shield — the exact moment a child is looking at a blocked
app — so a stranded shield is self-healing with no tap required. After a reboot,
the shield extensions run first, because nothing else is scheduled to.

### 6.1 `errorAccessRestored(failure)` — evidence the invariants are executable

The fail-safe suite found a real defect: the emergency "Restore Screen Access"
path re-accepted whichever error state it was already in. For a
shield-*ambiguous* failure (`shieldApplyFailed`, `authorizationConflict`,
`unknown`), `mayHaveShieldUp` stayed true — so HopPotty kept reporting a possible
shield **after it had issued a clear**.

Both available answers were wrong. Discarding the failure would claim Potty Pause
was fine when it was not; keeping the old error state would claim the child's apps
might still be blocked when a clear had been issued.

The fix was to name the fact the enum was missing:

```swift
/// A failure is still unresolved, but the child's apps have been given back
/// and a clear has been issued: the shield is no longer in question.
case errorAccessRestored(ScreenTimeFailure)
```

`mayHaveShieldUp` is `false` for it — and if the clear did not take, the executor
reports `shieldClearFailed` and the machine re-enters an error that *does* claim a
possible shield.

This is the argument for the whole architecture in one incident: the invariant was
not a paragraph in a design document that a reviewer might or might not check. It
was a test, it ran on Linux with no entitlement and no device, and it failed.

---

## 7. Dependency injection

- **Compile-time, not runtime.** `AppBuildConfiguration` selects live or mock
  services via `#if HOPPOTTY_MOCKS`. A runtime switch that can select mock
  services is a switch that can be flipped in a shipping build — by a debug menu
  someone forgot to remove, by a URL scheme, or by a bug. "The release binary
  physically does not contain the mock store" is worth more than the convenience.
- One justified runtime check: `XCODE_RUNNING_FOR_PREVIEWS`, set by the preview
  process itself, which no shipping process has.
- **`HopClock` everywhere.** Every date-sensitive decision is a pure function of
  an explicit `now`. `FixedClock` is the test seam.
- **`Calendar` is injected, never `.current`.** Travel and DST become ordinary
  test inputs rather than field reports.
- **`ParentAuthorization` is a value, not a `Bool`.** Destructive actions, the
  purchase surface and export take one. A `Bool parentApproved` can be passed
  `true` by any convenient caller; a value that must be *obtained* makes the
  omission visible at the call site. Honest limitation, recorded in the source:
  the app is one module, so `private init` is a speed bump, not a wall — what it
  buys is a single greppable mint point, a log line per mint, and a documented
  signature. The gate UI and a contract test are the real enforcement.
  Authorization expires after 15 minutes.

---

## 8. Logging

`HopLog`, subsystem `com.hoppotty.app`, eight closed categories:
`authorization`, `scheduling`, `monitoring`, `shield`, `restoration`,
`persistence`, `notification`, `purchase`. The set is closed on purpose — a
category meaning "everything else" becomes the category everything is logged to.

The rule is not "be careful what you log". It is **the identifying value never
enters the logging call**:

| Never logged | Why |
| --- | --- |
| Nicknames | It is the child's name — the whole of the identity HopPotty holds |
| Free-text notes | Often intimate or medical |
| App / category selections | Reveals what the child watches, and the household |
| Raw child UUIDs | Stable across launches; joins a log archive to an export or crash report |
| An event kind tied to a time | "poop at 14:03" is a health record with a timestamp |

`HopLog.tag(for:)` yields a four-hex-digit tag stable **within one launch only**
(`UUID.hashValue` is seeded per process) — enough to follow one child through a
debugging session, not enough to correlate two sysdiagnoses a week apart.
`HopLog.safeDescription(_:)` reduces an error to `domain#code`, because
`localizedDescription` on a SwiftData failure can interpolate the offending row's
values into the message.

---

## 9. Testing strategy

Full plan in `Docs/QATestPlan.md`. The architectural point:

| Layer | How it is verified | Status |
| --- | --- | --- |
| `HopPottyCore`, `HopPottyDesignTokens` | Swift Testing suites on Linux | **350 tests, 28 suites, passing** |
| App target, extensions | Xcode build + XCTest/XCUITest | **Never compiled** |
| Screen Time runtime behaviour | Physical device + approved entitlement | **Never observed** |

Test suites use Swift Testing (`@Suite`, `@Test`, `#expect`), not XCTest.
Property-style suites carry the load: the totality suite walks every
(state, event) pair; the fail-safe suite asserts the invariants directly
("entering an error state always clears" runs 1,050 cases); the contrast suite
runs every colour pairing across four appearances.

Roughly half this product's risk lives in logic that has nothing to do with
UIKit. That half is genuinely verified. The other half is written and unverified,
and this repository does not pretend otherwise.
