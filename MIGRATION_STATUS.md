# React Native migration — status

Updated continuously. Branch `react-native`.

---

## Current phase

**Phase 3 complete; Phases 1 and 2 written but unverified.**

The design system and the mascot are done and provably correct. The React
Native foundation and the Screen Time bridge are written but **cannot be
verified in this environment** — see Blockers.

---

## Completed

| | What | Verified by |
|---|---|---|
| **0** | Repository audit — `Docs/ReactNativeMigrationAudit.md` | Two independent passes over the repo |
| **0** | Screen inventory — `Docs/ScreenMigrationMatrix.md` | 51 screen-level views catalogued |
| **0** | Stack version research — `Docs/ReactNativeStack.md` | Live npm registry + official release notes |
| **3** | Design system generated from the Swift design tokens | `build-tokens.js --check`; drift gate tested by dirtying the file |
| **8a** | Hop's 15 poses as a typed scene graph, 32 named parts | **1,948 elements verified identical to the art rig**, every build |
| **8b** | `HopCharacter` — pose states, blink by part swap, gaze offset, one accessible element | Renders in a browser; see the preview |
| — | Browser preview deployed | **https://hoppotty-rn.vercel.app** — bundle byte-identical to the locally rendered one |
| — | CI gate for generated-source drift | Added to the `configuration` job |

## In progress

- **Phase 4 — Parent Home.** First pass built against render `01`; needs the
  pond backdrop animation, the error state, iPad layout and visual QA.

## Written but NOT verified

These are real implementations that no one has compiled or run. Do not treat
them as working.

- **Phase 1 — RN foundation.** `package.json`, TypeScript, Babel, Metro,
  ESLint, Jest config. Never installed or run: `npm install` for the full
  native toolchain has not happened, Metro has never started.
- **Phase 2 — Screen Time bridge.** `specs/NativeScreenTime.ts` (codegen
  spec), the typed facade, the dev mock and the web stub exist. **The Swift
  side does not exist yet** — see Next.
- Brownfield integration into the Xcode project: not started. `project.yml` is
  untouched, so the four extension targets are exactly as they were.

## Blockers

| Blocker | Effect |
|---|---|
| **This container is Linux.** No Xcode, CocoaPods, simulator or signing. | Phases 1, 2, 15, 20 cannot be verified here. The `macos-15` CI job is the only arbiter. |
| **Family Controls *Distribution* entitlement.** Must be approved by Apple, requested by the Account Holder, **per bundle ID and separately per extension** — HopPotty ships four. Days to weeks. | Cannot ship to TestFlight or the App Store without it. **Start these requests now**; they run in parallel with all remaining work. |
| **Physical device required** for the §67 16-step test. | Migration cannot be called complete without it. |
| `Config/Secrets.xcconfig` (Team ID) is empty and git-ignored. | Signing remains a human step. Pre-existing. |

## Needs a physical device

The whole of §67: authorization, picker, schedule save, monitoring start,
threshold trigger, shield appearance, shield action, restore, force-quit
survival, reboot survival, state reconciliation.

## Visual QA pending

Every migrated screen, against its render in `Art/render/screens/`. Parent Home
is the only screen built, and has not been compared yet.

## SwiftUI screens remaining

**51 of 51.** Nothing has been retired, and nothing may be until it meets §59.
Parent Home has a React Native counterpart but the SwiftUI original remains
authoritative.

## React Native screens completed

**0 by the §59 definition.** One built (Parent Home), zero through QA.

## Launch blockers

1. Family Controls Distribution entitlement × 4 targets — **not started, start now**
2. The Swift half of the Screen Time TurboModule — not written
3. Brownfield integration into `project.yml` — not started
4. 50 screens
5. Data migration from the SwiftData store — untested
6. The physical-device test — not run

---

## Next

1. Write the Swift side of the bridge: `RCTNativeScreenTime.mm` + a Swift
   implementation calling the existing `ScreenTimeService`. Evaluate Nitro
   Modules first — `FamilyControls` and `ManagedSettings` are Swift-only, so
   the stock TurboModule path needs a hand-written flattening layer that Nitro
   removes entirely.
2. Add React Native to `project.yml` **without touching the extension targets**,
   and get `Scripts/verify-config.sh` and the macOS CI job green.
3. Render one TypeScript screen inside the existing app (Phase 1's real goal).
4. Then Phase 4 properly: navigation, Parent Home to QA standard.

## Honest notes

- The Vercel preview is a **UI preview, not the app**. Screen Time, StoreKit
  and notifications are absent by construction. `NativeScreenTime.web.ts`
  rejects rather than returning plausible values so the preview cannot imply
  the feature works.
- Reanimated and Gesture Handler are declared but not yet used. The animation
  work (§27–29) beyond blink and gaze has not started.
- Navigation is not wired. The preview's tab switcher is scaffolding and is
  explicitly not the eventual router.
