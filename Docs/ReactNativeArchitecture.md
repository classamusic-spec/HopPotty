# React Native architecture

Where the boundary between TypeScript and Swift falls, and why.

---

## The shape

```
┌─────────────────────────────────────────────────────────┐
│  React Native + TypeScript                              │
│  screens · navigation · design system · mascot · games  │
│  interaction · view state                               │
└───────────────┬─────────────────────────────────────────┘
                │  typed native module (narrow, product verbs)
┌───────────────▼─────────────────────────────────────────┐
│  Swift                                                  │
│  HopPottyCore ── domain logic, 464 tests                │
│  ScreenTime  ── FamilyControls · DeviceActivity          │
│                 ManagedSettings · StoreKit · notifications│
└───────────────┬─────────────────────────────────────────┘
                │  App Group files (no JS involved)
┌───────────────▼─────────────────────────────────────────┐
│  Extensions — DeviceActivityMonitor · ShieldConfiguration │
│               ShieldAction                               │
│  Never contain React Native. Never depend on JS.         │
└─────────────────────────────────────────────────────────┘
```

React Native owns the product. Swift owns the platform. The extensions own
safety, and they own it alone.

---

## Decision 1 — `HopPottyCore` stays in Swift

The brief's §70 says React Native should own product state. Taken literally that
means porting 10,900 lines to TypeScript: schedule maths with daylight-saving
handling, the pause state machine and its totality tests, rewards idempotency,
insights aggregation, every catalogue and all the copy. And it means discarding
464 passing tests to do it.

**We keep it in Swift.** The reasoning:

- It is **verifiably platform-agnostic** — every import across the package is
  `Foundation` or a sibling. No UIKit, no SwiftUI, no `#if canImport`. It is not
  entangled with the UI layer; it simply is not written in TypeScript.
- Its tests run on Linux in CI today. A TypeScript port starts at zero coverage
  for logic where the bugs are subtle and the failures are a child being
  interrupted at the wrong time.
- The migration's purpose is product velocity on the UI. The domain layer is not
  where UI velocity is lost.

**What this costs, stated plainly:** Android cannot share the domain logic. If
Android becomes real, `HopPottyCore` is ported deliberately — with the Swift
tests as the executable specification — rather than as a side effect of a UI
migration. That is a better project than doing it now by accident.

## Decision 2 — the Screen Time boundary is narrow by construction

The native module exposes **product verbs**, not system access:

```ts
triggerTestPause()        // yes
restoreScreenAccess()     // yes
writeManagedSettings(x)   // never
```

There is no method taking an opaque payload that JavaScript could aim anywhere.
Apple's activity tokens never cross the bridge — the picker returns *counts*,
because "4 apps and 1 category will pause" is all a parent-facing screen needs,
and a token in JS is a token that can be logged.

Codegen has no unions, so statuses arrive as `string` and are narrowed exactly
once, at the boundary, in `ScreenTimeService.ts`. Nothing downstream sees an
unvalidated string.

`DeviceActivityReport` is deliberately absent. It is a SwiftUI view rendered in
a separate extension process; no bridge can carry its data. If we ever surface
it, it is as a native view hosted inside React Native.

## Decision 3 — JavaScript cannot strand a child

The brief's §17 requires that a JS failure never leave screen access blocked.
**The existing native architecture already guarantees this, and the migration's
job is to not disturb it.**

`ShieldReconciler.decide` is a pure function compiled into all four Screen Time
targets. Nine of its ten branches clear the shield; the tenth is the only path
that leaves one up. Four of the five restoration anchors run in processes that
have never heard of JavaScript — including the shield's own draw, so a stranded
shield self-heals with no app, no tap and no timer. The three time instants on
the shared pause record are `let`: no process can lengthen a pause.

A JS crash, a disconnected Metro, a failed Hermes init and a force-quit are
therefore all the same already-handled case: "the app is not running".

**Rules this imposes, permanently:**
- No React Native inside any extension target.
- No extension may read JS-owned state.
- `ShieldReconciler`, `AppGroupStore`, `SharedPauseTypes` and
  `ScreenTimeIdentifiers` do not move.

## Decision 4 — StoreKit stays native

One non-consumable product, family-shareable, with verified-transaction
entitlement caching, revocation handling and a background `Transaction.updates`
listener. It is complete and small. A React Native purchase abstraction would
add a dependency with its own opinions about entitlement caching and buy
nothing. Exposed to TypeScript as a purchase service, same pattern as Screen
Time.

## Decision 5 — design and art are generated, never ported

Three generators, all with `--check` gates in CI:

| Generator | From | To |
|---|---|---|
| `build-tokens.js` | `HopPottyDesignTokens` (Swift) via `Scripts/tokens.json` | `src/design-system/tokens.generated.ts` |
| `build-mascot.js` | `Scripts/hop-art.js` (the rig) | `src/mascot/poses.generated.ts` |
| `build-art.js` | `Art/` via `Scripts/art-keys.sh` | `src/art/artwork.generated.ts` |

This is the difference between a migration and a fork. Hand-porting a colour
means SwiftUI and React Native can disagree about it; generating it means they
cannot. Both art generators verify their output element-for-element against the
source on every build — 1,948 mascot elements and 4,135 illustration elements —
so a drawing that changes shape in transit fails the build instead of shipping.

The mascot is the sharpest case. `Scripts/hop-art.js` was already JavaScript and
already emitted named groups, so Hop is not redrawn for React Native: his
geometry is parsed from the rig and every part stays addressable, which is what
makes blinking, gaze and a waving arm possible at all.

## State

Four kinds, kept apart:

| Kind | Owner |
|---|---|
| View state | React, in the component |
| Product state (profiles, events, rewards, schedule) | Swift domain layer, surfaced through services |
| System state (authorization, monitoring, shield) | **Native is authoritative.** Never cached in JS. |
| Purchase state | StoreKit transaction state |

No global store yet, and none until the complexity earns one. The screens are
presentational — data in as props, intent out as callbacks — which is what makes
them previewable and testable before any of the above is wired.

**Native is authoritative for system truth.** An extension can raise or clear a
shield while this process is not running, so any JS cache of that state is a
second, stale answer that a screen might trust over the real one. Refresh on
foreground; never assume.

## Platform capability

Android has no Family Controls equivalent. `ScreenTimeService.capabilities()`
answers honestly per platform and the UI shows the real state.

**We never pretend apps are blocked when they are not.** That is the single
worst failure this product can have, and it is a capability check rather than a
comment because a comment does not fail a build.

## The browser preview

`react-native-web` + Vite, deployed to Vercel. It exists because everything
above is otherwise invisible without a Mac.

It is **a preview, not a second production target**. Screen Time is absent by
construction — the web stub rejects rather than returning plausible values —
and Reanimated on web runs on the JS main thread, so it is not a QA surface for
game feel. Both limits are stated on the page itself, not only here.
