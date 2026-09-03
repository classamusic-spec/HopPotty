# React Native migration — repository audit

Phase 0. What HopPotty is today, what must survive the migration untouched, and
where the boundary between React Native and Swift has to fall.

Audited at `68dc454` on branch `react-native`.

---

## 1. What exists

| | |
|---|---|
| Swift source files | 292 |
| SwiftUI screen-level views | 51 (+3 in extensions) |
| Vector assets | 347 SVG |
| Build targets | 7 |
| Kit tests | 464 across 34 suites, run by `swift test` on Linux |
| Deployment target | iOS 17.0 |

The `.xcodeproj` is **not** in the repository. `project.yml` is the source of
truth and `Scripts/bootstrap.sh` generates the project with XcodeGen. Any
migration step that assumes it can edit the Xcode project directly is wrong;
it must edit `project.yml`.

### Targets

| Target | Type | Bundle ID | Entitlements |
|---|---|---|---|
| `HopPotty` | application | `com.hoppotty` | Family Controls, App Group |
| `HopPottyDeviceActivityMonitor` | app-extension | `com.hoppotty.monitor` | Family Controls, App Group |
| `HopPottyShieldConfiguration` | app-extension | `com.hoppotty.shieldconfig` | Family Controls, App Group |
| `HopPottyShieldAction` | app-extension | `com.hoppotty.shieldaction` | Family Controls, App Group |
| `HopPottyWidgets` | app-extension | `com.hoppotty.widgets` | App Group only — Family Controls deliberately absent |
| `HopPottyTests` | unit-test | `com.hoppotty.tests` | — |
| `HopPottyUITests` | ui-testing | `com.hoppotty.uitests` | — |

`Tests/` and `UITests/` at the repo root are **empty directories**; all real
coverage lives in `HopPottyKit/Tests/`.

Three build configurations, not two: `Debug`, `DebugMock`, `Release`.

---

## 2. The single most important finding

**The failsafe requirement in the migration brief (§17 — "the React Native
runtime must never become a single point of failure for restoring screen
access") is already satisfied by the existing architecture, and the migration's
job is to not disturb it.**

`ShieldReconciler` (`HopPotty/Services/ScreenTime/ShieldReconciler.swift`, 401
lines) is a stateless `enum` compiled by explicit file membership into **all
four** Screen Time targets. Its core, `decide(_:) -> Verdict`, is a pure
function that touches no Apple framework — which is why the whole rulebook is
unit-tested on Linux.

Every guard fires on the *absence* of information, and only one branch of ten
leaves a child shielded:

| Condition | Verdict |
|---|---|
| App Group container unreachable | clear |
| No pause record, or unknown schema version | clear |
| Record malformed (duration ≤ 0, over maximum, backstop before planned end) | clear |
| Device restarted (uptime went backwards) | clear |
| Clock moved backwards | clear |
| Past the backstop instant | clear |
| Past the planned end | clear |
| Newest heartbeat older than 3× the maximum pause | clear |
| *otherwise* | **leave shield up** |

There are five independent restoration anchors, and **four of them do not
involve the app process at all**:

1. App cold start and every foreground.
2. Every `DeviceActivityMonitor` callback.
3. **Every shield draw** — the shield reconciles itself as it renders, so a
   stranded shield self-heals with no app, no tap and no timer.
4. Every shield tap.
5. Authorization loss observed by the app.

Plus a hard ceiling: `backstopEndAt = startedAt + 15 minutes`, and the three
time instants on the shared record are `let` — **no process can lengthen a
pause.**

### What this means for React Native

React Native sits strictly *above* this layer. It can ask for a pause and
configure a schedule; it is structurally incapable of preventing a restore,
because every restore path runs in a process that has never heard of
JavaScript. A JS crash, a disconnected Metro, a failed Hermes init and a
force-quit are all already-handled cases, indistinguishable from "the app is
not running".

**Therefore:** no migration step may move `ShieldReconciler`, `AppGroupStore`,
`SharedPauseTypes` or `ScreenTimeIdentifiers` out of native, embed React Native
into any extension, or make an extension depend on JS state. These four files
(2,071 lines) are the safety kernel.

---

## 3. Native code that must remain native

### The Screen Time layer — 12 files, ~3,662 lines

`HopPotty/Services/ScreenTime/`. Four of these are compiled into all four
targets by **file-level membership**, not a shared framework (a framework was
rejected for extension launch cost):

- `ScreenTimeIdentifiers.swift` — activity names, store names, platform limits
- `AppGroupStore.swift` — the cross-process file store
- `SharedPauseTypes.swift` — every shared payload type
- `ShieldReconciler.swift` — the safety kernel

Their target membership is machine-checked by `Scripts/verify-config.sh`.

### The extensions — ~859 lines

- **DeviceActivityMonitor** (385 lines) — the only place a shield goes up with
  the app not running. Eight numbered guards, all failing toward *not*
  shielding. Explicitly forbidden SwiftUI, SwiftData and DesignTokens.
- **ShieldConfiguration** (228 lines) — draws the shield from a pre-resolved
  `shield.json` the app publishes. Computes nothing.
- **ShieldAction** (246 lines) — handles the child's tap.

These stay small, deterministic and native. React Native must not be embedded
in any of them.

### App Group — `group.com.hoppotty`

Verbatim, and it must agree byte-for-byte in three places
(`Config/Base.xcconfig`, `ScreenTimeIdentifiers.swift`,
`WidgetSnapshotStore.swift`). `Scripts/verify-config.sh` compares all three.

State is **files, not `UserDefaults`** — `Data.write(options: .atomic)` renames
a complete file into place, giving cross-process atomicity that
`UserDefaults(suiteName:)` does not.

| File | Payload | Writers | Readers |
|---|---|---|---|
| `pause.json` | `SharedPauseRecord` | app, monitor, shieldAction | all four |
| `shield.json` | `ShieldPresentation` | app | shieldConfig |
| `selection.json` | encoded `FamilyActivitySelection` (opaque) | app | app |
| `tokens.json` | `ShieldTokens` | app | monitor |
| `gate.json` | `MonitoringGate` | app | monitor |
| `cooldown.json` | `CooldownRecord` | app, shieldAction, monitor | monitor |
| `grownup.json` | `GrownUpRequest` | shieldAction | app (read-and-delete) |
| `heartbeat/<t>.json` | `Heartbeat` | one per target | app |
| `outbox/<uuid>.json` | `ExtensionReport` | 3 extensions + app | app drains |
| `widget.json` | `WidgetSnapshot` | app, monitor | widget ext |

A deliberate privacy boundary: no child identifier, nickname, age, pronouns,
notes, events, star ledger or free text ever crosses into the App Group.
`ExtensionReport` **structurally has no `String` free-text field**, so an
extension that can read an app's display name cannot write one out.

### StoreKit

StoreKit 2, `HopPotty/Services/Purchases/`. **One product**, non-consumable,
family-shareable: `com.hoppotty.family`. Entitlement cached in `UserDefaults`
with no expiry; revocation clears immediately. Restore is gated behind the
parent gate. A background `Transaction.updates` listener covers Ask-to-Buy.

**Recommendation: keep StoreKit native (Option A in the brief, §37).** The
implementation is complete, correct and small, the product surface is a single
non-consumable, and no React Native purchase abstraction would add anything
except a dependency with its own entitlement-caching opinions.

### Notifications

Local only — `UserNotifications`. **No push anywhere**; `aps-environment` is
absent from every entitlements file, and Live Activities are updated
in-process. Exactly three schedulable kinds, structurally enforced: a private
initialiser with three factories, and `schedule(_:)` refuses any identifier
lacking a permitted prefix.

---

## 4. What is already portable

### `HopPottyKit` — verifiably platform-agnostic

Every `import` across the whole package is one of exactly three: `Foundation`
(57×), `HopPottyCore` (2×), `HopPottyDesignTokens` (1×). Zero `UIKit`,
`SwiftUI`, `AppKit`, `CoreGraphics`, `Combine`, `ManagedSettings`,
`DeviceActivity`, `FamilyControls`; zero `#if canImport`.

| Product | Files | Lines | Public types |
|---|---|---|---|
| `HopPottyCore` | 42 | ~10,900 | 154 |
| `HopPottyDesignTokens` | 6 | 732 | 14 |
| `HopPottyFixtures` | 2 | 184 | 2 |

This is the domain layer: schedule maths, the pause state machine, rewards,
insights, quiz and game catalogues, and all copy. It is pure logic with a test
suite that runs on Linux.

**Migration consequence:** this is the largest single decision of the project.
See §6.

### The design tokens already export to JSON

`HopPottyDesignTokens` → the `hoptokens` executable → `Scripts/tokens.json` →
consumed by the render harness. Four appearances × 24 semantic colours, 26
palette entries, 16 type styles, 5 motion curves, plus spacing, radius and
hit-target scales.

**There is already one source of truth for design, and it already speaks JSON.**
React Native becomes a third consumer rather than a second copy — see
`Scripts/rn/build-tokens.js`.

### The mascot rig is already JavaScript

`Scripts/hop-art.js` builds Hop's fifteen poses parametrically and emits SVG
with **named groups** — `head`, `belly`, `left-pupil`, `right-arm`, `mouth`,
`cheeks`, all four limbs, hands, feet, `accent-details`. That list is almost
exactly the group list the migration brief demands (§25).

**Consequence:** Hop does not need redrawing for React Native. His geometry is
parsed from the rig at build time into a typed scene graph, and 1,948 elements
are verified identical to the rig's output on every build. See
`Scripts/rn/build-mascot.js`.

### The render harness is a pixel-exact QA reference

`Scripts/screens/` renders 47 screens at true device scale. Every migrated
React Native screen has an existing PNG to be compared against — the brief's
§58 design-regression QA has its reference set already built.

---

## 5. Migration risks

| Risk | Severity | Mitigation |
|---|---|---|
| **The environment cannot build iOS.** This container is Linux: no Xcode, no CocoaPods, no simulator, no signing. Phases 1–2 cannot be *verified* here, only written. | **High** | The repo's existing `macos-15` CI job is the only verification route. Every iOS claim must wait for CI. |
| Adding React Native pods to a hand-maintained XcodeGen project could disturb the four extension targets. | **High** | Never run an Expo prebuild or CNG. Edit `project.yml` only; keep extension target definitions untouched; `Scripts/verify-config.sh` must stay green. |
| `Config/Secrets.xcconfig` (Team ID) is git-ignored and empty. | Medium | Unchanged by this migration; signing remains a human step. |
| `PottyPauseEffectExecutor` is **constructed nowhere** — the state machine → executor → Screen Time loop is written but not wired to a feature. | Medium | Pre-existing, not caused by migration. The RN bridge should wire to it rather than reimplementing the loop. |
| The Kit's 464 tests are Swift. Migrating domain logic to TypeScript would abandon them. | **High** | See §6 — this is why the Kit stays. |
| Many Apple API spellings carry inline `UNVERIFIED` markers; `project.yml` states nothing here has been built with XcodeGen. | Medium | Pre-existing. CI is the arbiter. |
| 187 KB of generated mascot geometry in the JS bundle. | Low | Vector art for 15 poses; acceptable, and measured. |

---

## 6. The central architectural decision: keep `HopPottyCore` in Swift

The brief's §70 says React Native should own product state. Taken literally
that would mean porting 10,900 lines of tested domain logic — schedule maths
with daylight-saving handling, the pause state machine and its totality tests,
rewards idempotency, insights aggregation — into TypeScript, and discarding 464
passing tests to do it.

**Recommendation: do not.** Instead:

- `HopPottyCore` stays Swift and stays the domain authority on iOS.
- React Native owns presentation, navigation, interaction, animation and view
  state.
- The native bridge exposes *domain operations*, not database rows.

This is the same boundary the brief already draws for Screen Time (§70), simply
applied to the layer that is also already platform-agnostic and already tested.
It costs Android sharing of domain logic — which is a real cost, and the honest
alternative is to port `HopPottyCore` to TypeScript later, deliberately, with
the Swift tests as the specification, rather than as a side effect of a UI
migration.

Recorded in full in `Docs/ReactNativeArchitecture.md`.

---

## 7. Proposed migration sequence

Phases follow the brief. Deviations noted.

| Phase | Status in this environment |
|---|---|
| 0 — Audit | **Doable and done** |
| 1 — RN foundation | Writable; **not verifiable** (needs macOS) |
| 2 — Screen Time bridge | Writable; **not verifiable** (needs device) |
| 3 — Design system | **Doable and verifiable** — generated from Swift tokens |
| 8 — Hop rig | **Doable and verifiable** — generated from the art rig |
| 4–7, 9–14 — screens | Doable; visual QA against the 47 renders |
| 15 — data migration | **Blocked** — needs a device and a prior install |
| 16–18 — iPad, a11y, perf | Partly doable; final QA needs devices |
| 19 — retire SwiftUI | **Must not start** until screens pass QA on device |
| 20 — release hardening | **Blocked** — needs macOS, devices, signing |

Per §67, the migration is not complete until the 16-step physical-device test
passes. Nothing in this environment can substitute for it.
