# HopPotty

An iOS and iPadOS app that helps a family build a potty-training rhythm on a
device the child is already holding. At an interval the caregiver chooses,
HopPotty briefly shields the apps the caregiver selected, invites the child to
try the potty, celebrates the attempt, and gives the screen back.

```
PLAY  →  WARNING  →  PAUSE  →  POTTY  →  CELEBRATE  →  RESUME
```

It is a training aid for a caregiver, operated on a child's device. It is not a
game, not a tracker a child is measured by, and not a medical product.

Three product rules shape almost every technical decision in this repository,
and they are enforced by tests rather than by good intentions:

1. **Screen access is never contingent on a biological outcome.** A pause ends on
   its timer, on completion, or on a caregiver override. There is no fourth way,
   and no code path may inspect what the child produced.
2. **Stars are never removed.** The reward ledger is append-only. No decay, no
   expiry, no streak that can break.
3. **No engagement mechanics.** No loss aversion, no randomised rewards, no
   "come back" notifications, no leaderboards.

The full list is `Docs/CONTRACTS.md` §4. Read it before writing anything.

---

## Verification status — read this first

This repository was built in an environment with **no Xcode, no iOS Simulator and
no physical device**. That constrains what can honestly be claimed, and the
claims are kept separate:

| Layer | Status |
| --- | --- |
| `HopPottyKit` — domain logic, ~28 test suites | **Tested.** Compiles and its tests run on Linux, in CI, on every push. |
| `Config/*.xcconfig`, entitlements, identifiers | **Checked** by `Scripts/verify-config.sh`, which runs in CI. Text-level agreement only. |
| `project.yml` | **Never generated.** No XcodeGen has run against it. |
| The app, the three extensions, all SwiftUI | **Never compiled.** |
| Any Screen Time behaviour | **Never observed on hardware.** |

Nothing in this repository has produced a running app. The first person with a
Mac should expect to fix things — the likely candidates are collected under
[Known unknowns](#known-unknowns) rather than buried in commit messages.

`Docs/ScreenTimeArchitecture.md` §12 carries nine numbered questions about Apple
behaviour that Apple does not document. Every one of them needs a physical device
before code depends on it.

---

## Requirements

| | |
| --- | --- |
| **Xcode** | 16 or newer. Swift 6 language mode (`SWIFT_VERSION = 6.0`) with strict concurrency, and the iOS 17 SDK. |
| **macOS** | Whatever that Xcode requires. |
| **XcodeGen** | 2.38.0 or newer — `brew install xcodegen`. There is no `.xcodeproj` in the repository; it is generated. |
| **Apple Developer Program** | Required. Family Controls is not available to a free account, and without it the app's headline feature cannot run at all. |
| **A physical iOS device** | Required for anything Screen Time. Whether Family Controls works in the Simulator is undocumented by Apple and unverified here. |
| **Swift toolchain (Linux or macOS)** | Optional, for `HopPottyKit` alone. `swift test` in `HopPottyKit/` needs no Xcode and no Apple platform. |

---

## Setup

```bash
git clone <this repo> && cd HopPotty
Scripts/bootstrap.sh
open HopPotty.xcodeproj
```

`Scripts/bootstrap.sh` is idempotent and safe to re-run. It:

1. reports the toolchains it can find,
2. creates `Config/Secrets.xcconfig` from the template if it is missing, and
   never overwrites it,
3. runs `Scripts/verify-config.sh` and refuses to continue if anything fails,
4. generates `HopPotty.xcodeproj` from `project.yml`,
5. prints the manual steps below, with the current identifiers filled in.

Run it again after switching branches or after anyone adds, moves or renames a
file — the project is a function of the file system.

`Scripts/bootstrap.sh --check` runs the checks and generates nothing.

### What no script can do

**1. Team ID.** Put your ten-character Team ID in `Config/Secrets.xcconfig`:

```
HOPPOTTY_DEVELOPMENT_TEAM = A1B2C3D4E5
```

That file is git-ignored and must stay that way. No signing material — no `.p12`,
no `.mobileprovision`, no `.cer` — is ever committed; `.gitignore` blocks all
three and `verify-config.sh` fails if any is tracked.

**2. Bundle identifiers.** The four identifiers are placeholders under a domain
nobody here owns:

| Target | Identifier |
| --- | --- |
| App | `com.hoppotty` |
| Device Activity Monitor extension | `com.hoppotty.monitor` |
| Shield Configuration extension | `com.hoppotty.shieldconfig` |
| Shield Action extension | `com.hoppotty.shieldaction` |

To change them, edit `HOPPOTTY_APP_BUNDLE_ID` in `Config/Base.xcconfig` (or
override it in `Config/Secrets.xcconfig` for a personal build) **and** the
matching literals in `HopPotty/Services/ScreenTime/ScreenTimeIdentifiers.swift`.
`verify-config.sh` fails if the two disagree, which is the whole reason it exists:
nothing in the toolchain checks it, and a mismatch is invisible until a family's
shield fails to clear.

Register all four App IDs and enable **Family Controls** on each.

**3. App Group.** Create one, and add all four App IDs to it:

```
group.com.hoppotty
```

This is how the three extensions see the app's pause state. If it is missing or
misspelled nothing fails at build time — `UserDefaults(suiteName:)` returns
`nil`, the container URL is unavailable, and shields stop coming down.

(Named `ManagedSettingsStore`s are shared between an app and its extensions
automatically and need no App Group. The App Group carries HopPotty's own
payloads only.)

**4. The Family Controls entitlement — start this on day one.**

Development signing works as soon as the capability is enabled on the App IDs.
Distribution, *including TestFlight*, does not:

- your Apple Developer **Account Holder** must submit the request; nobody else can;
- submit it once per App ID — the app **and** each of the three extensions;
- <https://developer.apple.com/contact/request/family-controls-distribution/>;
- Apple publishes no turnaround time;
- when it is granted, open the info button beside the capability and confirm
  **Provisioning Support** lists Development, Ad Hoc *and* App Store. An approval
  that omits App Store distribution is a silent trap.

`Docs/Entitlements.md` has the citations, the provisioning notes, and a draft of
the App Review notes explaining why the app needs the entitlement at all.

---

## Repository architecture

```
HopPottyKit/                Swift package. Foundation only.
  Sources/HopPottyCore        domain models, scheduling, rewards, insights,
                              the Potty Pause state machine, all user-facing copy
  Sources/HopPottyDesignTokens  palette, type scale, spacing, motion
  Sources/HopPottyFixtures      test data
  Tests/                        ~28 suites, run on Linux in CI

HopPotty/                   The iOS app target.
  App/                        entry point, composition root, launch hooks
  Core/                       build configuration, clock, parent authorization, logging
  DesignSystem/               SwiftUI realisation of the design tokens
  Features/                   one directory per surface
  Services/                   SwiftData persistence, Screen Time, purchases, audio…
  Developer/                  the Potty Pause Lab. Debug builds only.
  Resources/                  asset catalog, StoreKit configuration, audio, strings

Extensions/                 Three Screen Time app extensions.
  HopPottyDeviceActivityMonitor/   ends a pause on the clock; the 15-minute backstop
  HopPottyShieldConfiguration/     draws the shield the child sees
  HopPottyShieldAction/            handles the child's tap on the shield

Config/                     xcconfig files. All build settings live here.
Scripts/                    bootstrap, configuration checks, art rendering
Docs/                       contracts, architecture, ADRs, release checklist
project.yml                 the canonical project definition (XcodeGen)
```

### The one rule that explains the layout

> If a type can be expressed without Apple UI frameworks, it belongs in
> `HopPottyCore`.

`HopPottyKit` imports no SwiftUI, no SwiftData and no Screen Time framework, and
must keep compiling on Linux. That is not a portability exercise — it is what
makes the product's hardest logic testable at all. Daylight-saving arithmetic,
quiet-hour precedence, reward idempotency and the shield state machine are all
pure functions of an explicit `now`, so they run in a Linux container in seconds
instead of needing a device, an entitlement and a family.

The app layer on top is deliberately thin: it performs effects the state machine
decided on, and holds no rules of its own. Business logic in a `View` is a defect
(`Docs/CONTRACTS.md` §1).

### Target topology

| Target | Links | Never links |
| --- | --- | --- |
| **HopPotty** (app) | FamilyControls, ManagedSettings, DeviceActivity, SwiftUI, SwiftData, HopPottyKit | ManagedSettingsUI |
| **Monitor ext** | DeviceActivity, ManagedSettings, HopPottyCore | SwiftUI, SwiftData |
| **ShieldConfiguration ext** | ManagedSettingsUI, ManagedSettings, HopPottyCore | DeviceActivity, SwiftData, SwiftUI |
| **ShieldAction ext** | ManagedSettings, HopPottyCore | ManagedSettingsUI, SwiftData, SwiftUI |

Four files in `HopPotty/Services/ScreenTime/` are members of **all four** targets:
`ScreenTimeIdentifiers.swift`, `AppGroupStore.swift`, `SharedPauseTypes.swift`
and `ShieldReconciler.swift`. They are listed per-target in `project.yml`, and
`verify-config.sh` checks that each is listed for all three extensions. A shared
embedded framework would express this better; it is deliberately not used,
because it would add launch cost to three latency-sensitive extensions in
exchange for a fact three lines of build configuration already express.

`Docs/ScreenTimeArchitecture.md` is the authority on all of this, with citations.

---

## Build configuration

All build settings live in `Config/*.xcconfig`. `project.yml` sets only what is
target *identity* — bundle identifier, `Info.plist`, entitlements — so a target's
identity is readable in one place and everything else is readable in another.

| Configuration | `HOPPOTTY_DEBUG_TOOLS` | `HOPPOTTY_MOCKS` | Use |
| --- | --- | --- | --- |
| **Debug** | yes | no | Everyday development. Real Screen Time; needs a signed device build. |
| **DebugMock** | yes | yes | In-memory fakes everywhere. Simulator, UI tests, screenshots, and any work before the entitlement is approved. |
| **Release** | **no** | **no** | What families install. |

Both Debug configurations compile with `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`;
Release does not. That asymmetry is deliberate: a warning should stop the person
who introduced it, seconds after they wrote it — it should not stop a hotfix six
months later because a new Xcode deprecated an API the code still uses correctly.

### Real services versus fakes

Chosen by **build configuration**, never by a runtime flag. `AppEnvironment`
resolves it once, at launch:

- **Release** compiles only the live branch. The fake Screen Time service is not
  in the binary, so no debug menu, no URL scheme and no bug can reach it.
- **Debug** compiles both, and uses the live one — except inside an Xcode preview
  or a test host, which `AppBuildConfiguration.resolved` detects at runtime.
  Previews must never touch the real store or a StoreKit sandbox account.
- **DebugMock** uses fakes for everything.

A green DebugMock run proves nothing about Screen Time. It is for the layers
above it.

---

## Debug tools

The **Potty Pause Lab** (`HopPotty/Developer/`) can start and end pauses,
inspect the App Group, and force reconciliation verdicts without a real
authorization. A build that can reach it must never reach a family, so two
independent mechanisms keep it out of Release:

1. `HOPPOTTY_DEBUG_TOOLS` is defined only in `Config/Debug.xcconfig`, so
   `#if HOPPOTTY_DEBUG_TOOLS` code is not compiled into a Release build; and
2. `Config/Release.xcconfig` removes `HopPotty/Developer/*` from the compiled
   sources entirely via `EXCLUDED_SOURCE_FILE_NAMES`, so a file someone forgot to
   guard still cannot ship.

The second is what makes it structural rather than a convention. If a Release
build ever fails with *cannot find 'PottyPauseLab' in scope*, the mechanism is
working and the unguarded reference is the defect.

`verify-config.sh` fails if `HOPPOTTY_DEBUG_TOOLS`, `HOPPOTTY_MOCKS` or `DEBUG`
ever appears in the Release configuration.

---

## Tests

### Domain logic — no Xcode, no simulator, any platform

```bash
cd HopPottyKit
swift test
```

This is where the risk is, so this is where the tests are: the pause state
machine and its cold-start recovery, schedule arithmetic across daylight saving,
quiet-window precedence, reward idempotency and the append-only ledger, the
insight language policy, and a scanner that fails the build on shame language in
child-facing copy. It runs on Linux, in CI, on every push.

Swift Testing (`@Suite` / `@Test` / `#expect`), never XCTest.

### App layer — needs Xcode

```bash
xcodebuild test -scheme HopPotty-Mock \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

`HopPottyTests` and `HopPottyUITests` cover the app layer only: SwiftUI, SwiftData
and the service seams. Anything testable in `HopPottyKit` should be tested there
instead — it runs in seconds and needs nothing.

### Configuration

```bash
Scripts/verify-config.sh
```

Text-level agreement between the xcconfigs, the entitlements, the Swift
constants, the ADR and the StoreKit file. No Xcode required; runs in CI.

---

## StoreKit testing

`HopPotty/Resources/HopPotty.storekit` describes the single product — **HopPotty
Family**, a one-time non-consumable at $19.99, family-shareable. Both schemes
select it, so the paywall works in the Simulator with no sandbox account and no
network.

A non-consumable, deliberately: a subscription would make a family's continued
access to their own child's history contingent on a renewal.

The product identifier `com.hoppotty.family` appears in three places and all
three must agree — `Config/Base.xcconfig` (which surfaces it to the app through
the `HPFamilyUnlockProductIdentifier` key in `Info.plist`), the `.storekit` file,
and App Store Connect. `verify-config.sh` checks the first two. Only a human can
check the third.

Local StoreKit testing says nothing about the real transaction flow. Ask To Buy,
Family Sharing propagation and restore-on-a-second-device all need a sandbox
account on real hardware.

---

## Release process

The full pre-submission checklist is `Docs/ReleaseChecklist.md`. In outline:

1. `Scripts/bootstrap.sh` — regenerate, and let the configuration checks pass.
2. `cd HopPottyKit && swift test` — green.
3. `xcodebuild test -scheme HopPotty-Mock …` — green.
4. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig`.
   They are set once, at project level, for all four targets — an extension whose
   version disagrees with its host app is rejected at upload.
5. Archive the **HopPotty** scheme (Release).
6. Confirm the archive contains three `.appex` bundles in `PlugIns/`, that each
   carries the Family Controls entitlement and the App Group, and that no
   `HopPotty/Developer/` symbol survives.
7. Upload, then complete the App Review notes from `Docs/Entitlements.md` §5.
   Update the demo credentials and the pause duration first; every sentence in
   those notes must be true of the build being submitted.

---

## Known unknowns

Things a person with a Mac should expect to fix or confirm. They are marked
`UNVERIFIED` in place, next to the code they affect.

- **The three `NSExtensionPointIdentifier` values** in the extensions'
  `Info.plist` files. `Docs/ScreenTimeArchitecture.md` §8 says not to hand-write
  them, because Xcode's Screen Time target templates supply them — but this
  project is generated by XcodeGen and has no templates, so they *are*
  hand-written. Create each extension once with File > New > Target in Xcode and
  diff the generated `NSExtension` dictionary against ours. A wrong value does not
  fail the build; the extension is simply never invoked, which looks exactly like
  a Screen Time bug.
- **`NSExtensionPrincipalClass`** must match the Swift class name the extension
  actually declares, unnested and spelled exactly.
- **`EXCLUDED_SOURCE_FILE_NAMES`** in `Config/Release.xcconfig` — the glob form
  is from Apple's own templates but has not been exercised here.
- **`storeKitConfiguration`** in the schemes — an XcodeGen key that may need to be
  set in Xcode's scheme editor instead.
- **Family Controls in the Simulator** — Apple documents nothing either way.
- The nine device-only questions in `Docs/ScreenTimeArchitecture.md` §12.

---

## Where to start reading

| If you want | Read |
| --- | --- |
| The rules you must not break | `Docs/CONTRACTS.md` |
| What the product is and why | `Docs/ProductVision.md` |
| How Screen Time actually works, with citations | `Docs/ScreenTimeArchitecture.md` |
| Capabilities, provisioning, App Review | `Docs/Entitlements.md` |
| Why iOS 17 | `Docs/ADR/0002-deployment-target.md` |
| Why the domain logic is a separate package | `Docs/ADR/0001-platform-agnostic-core.md` |
| What the design system offers | `Docs/DesignSystemAPI.md` |
| What to check before submitting | `Docs/ReleaseChecklist.md` |
