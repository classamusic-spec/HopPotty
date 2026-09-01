# HopPotty — Build Status

**Updated:** 2026-09-01
**Branch:** `claude/hoppotty-ios-build-6zzfjf`

> **Read this first.** This environment has **no Xcode, no iOS simulator, and no
> physical device.** Below, "tested" means a test was executed and passed.
> Everything requiring Xcode is listed as unverified, with what to run.

---

## Verification status at a glance

| Layer | Compiles | Tests run | How |
| --- | --- | --- | --- |
| `HopPottyCore` (domain, rewards, state machine, insights, content) | ✅ Yes | ✅ Yes | Swift 6.2 on Linux — **164 tests, 13 suites, all passing** |
| `HopPottyCore` scheduling engine | ✅ Yes | ⚠️ **No tests yet** | Compiles; suite still being written |
| `HopPottyDesignTokens` | ✅ Yes | ✅ Yes | Same — includes WCAG contrast assertions |
| `HopPotty` app target (SwiftUI) | ❌ **Unverified** | ❌ No | Needs Xcode |
| Three app extensions (Screen Time) | ❌ **Unverified** | ❌ No | Needs Xcode |
| Screen Time runtime behaviour | ❌ **Unobserved** | ❌ No | Needs a physical device + entitlement |

**No Screen Time behaviour has been observed on hardware. No entitlement has
been requested or approved. The Xcode project has not been generated or built.**

---

## Current phase

Phase 4–7 in parallel: Screen Time implementation, design system, platform
services, and feature surfaces, on top of a completed and tested core.

## Completed

- **Phase 0 — Repository audit.** `Docs/RepositoryAudit.md`. Repo was empty; no
  prior work to preserve.
- **Phase 1 — Apple API research.** Verified against Apple's live documentation
  metadata, not memory. `Docs/ScreenTimeArchitecture.md`, `Docs/Entitlements.md`,
  `Docs/ADR/0002-deployment-target.md`. Findings that changed the design are
  listed under *Platform constraints* below.
- **Architecture.** `HopPottyKit` — a platform-agnostic Swift package holding
  every piece of logic that does not need Apple UI frameworks, so the riskiest
  code is genuinely testable. `Docs/ADR/0001-platform-agnostic-core.md`.
- **Design tokens.** Full semantic palette across light, dark, light
  high-contrast and dark high-contrast; type scale; spacing; motion; hit targets.
  Contrast is enforced by tests — the initial amber (#C79214, 2.78:1) failed and
  was darkened to #A87A0C.
- **Domain models.** Child, event, schedule, reward, pond, settings, Screen Time
  configuration. Wall-clock times are stored as `LocalTimeOfDay`, not `Date`, so
  quiet hours survive DST and travel.
- **Potty Pause state machine.** A total reducer over every (state, event) pair,
  returning side effects rather than performing them. The fail-safe suite caught
  a real invariant violation: the emergency "Restore Screen Access" path
  re-accepted whichever error state it was in, which for shield-ambiguous
  failures kept reporting a possible shield after a clear had been issued. Fixed
  by naming the fact the enum was missing — `errorAccessRestored(failure)`.
- **Rewards + pond progression.** Append-only ledger with crash-safe idempotency
  keys derived only from already-durable data. 41 pond items, deterministic
  curve, exhaustive at compile time. Stars are structurally impossible to remove.
- **Hop character art.** Eight poses generated from one parameterised anatomy
  definition, reviewed and iterated against rendered output.
- **Screen render harness.** Renders screens from the *exported design tokens*,
  so a render cannot drift from what the app compiles against.

## In progress

Scheduling engine · pause state machine · insights engine · copy and quiz
content · SwiftUI design system · Screen Time services and three extensions ·
platform services (SwiftData, StoreKit, notifications, audio, haptics) · pond and
scene art · Xcode project generation · screen renders.

---

## Platform constraints found during research

These are Apple's limits, not implementation shortcuts. Each is designed around
rather than worked around; none is solved with a private API.

1. **A shield cannot launch the containing app before iOS 26.5.**
   `ShieldActionResponse.openParentalControlsApp` is 26.5+. Below that, the
   ShieldAction extension clears the `ManagedSettingsStore` itself and records
   the outcome in the App Group; the app reconciles at next launch. Gated at
   runtime so 26.5+ gets the better path.
2. **`DeviceActivitySchedule`'s minimum interval is 15 minutes**, and
   `DeviceActivityEvent.threshold` counts *foreground usage*, not wall clock. A
   3-minute pause therefore cannot be timed by DeviceActivity alone; the pause
   ends by whichever of five paths comes first, including foreground
   reconciliation and caregiver override.
3. **The shield is a fixed layout** — blur, background colour, one static image,
   title/subtitle, button labels and colours. No custom views, fonts or
   animation. The branded shield is designed within exactly that.
4. **`FamilyControls.AuthorizationStatus` has no `.restricted` case.** HopPotty's
   `.restricted` is derived from `FamilyControlsError.restricted`.
5. **Hard caps:** 50 tokens per shield property, 20 monitored activities per app,
   50 named stores per process.

---

## Blockers requiring someone with an Apple account

None of these can be resolved from this environment.

| Blocker | Needed for | Notes |
| --- | --- | --- |
| **Family Controls distribution entitlement** | Any shipping build | Apple must approve a request. Development entitlement behaviour is **not** proof of distribution behaviour. |
| **Apple Developer team + signing** | Building at all | Bundle IDs and App Group must be created; `Scripts/bootstrap.sh` documents exactly what to replace. |
| **Physical iOS device** | All Screen Time verification | See `Docs/PhysicalDeviceQA.md` — every scenario is currently unobserved. |
| **Xcode** | Compiling the app and extensions | Nothing in `HopPotty/` or `Extensions/` has been compiled. |
| **Voice and audio assets** | Hop's spoken lines | Architecture degrades explicitly to captions; no synthesised speech ships. |
| **App Store Connect** | Submission | Metadata drafted, not uploaded. |

---

## Launch blockers still open

- Xcode project has never been generated or built.
- Every SwiftUI view is uncompiled.
- Screen Time loop unproven on hardware — the product's core premise.
- StoreKit paths untested against a real StoreKit configuration.
- Accessibility audit is written but not executed against a running app.
- No Instruments profiling.

## Next

1. Integrate all agent output; run the full `HopPottyKit` test suite.
2. Generate the Xcode project on a Mac and fix the first compile pass.
3. Run the Screen Time proof of concept on a physical device.
4. Work `Docs/PhysicalDeviceQA.md` and record observed behaviour.
