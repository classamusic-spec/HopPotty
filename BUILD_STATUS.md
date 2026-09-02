# HopPotty — Build Status

**Updated:** 2026-09-02 (first compile)
**Branch:** `claude/hoppotty-ios-build-6zzfjf`

> **Read this first.** This repository now has a **macOS CI job** that generates
> the Xcode project and builds the app and all four extensions with a real
> Xcode on every push (`.github/workflows/ci.yml`, job "App and extensions").
> There is still no simulator run and no physical device here, so "tested" below
> still means a test was executed and passed, and anything needing a device is
> still listed as unobserved.

---

## Verification status at a glance

| Layer | Compiles | Tests run | How |
| --- | --- | --- | --- |
| `HopPottyCore` (domain, scheduling, rewards, state machine, insights, content) | ✅ Yes | ✅ Yes | Swift 6.2 and 6.0 on Linux — **464 tests, 34 suites, all passing** |
| `HopPottyDesignTokens` | ✅ Yes | ✅ Yes | Same — includes WCAG contrast assertions |
| Four app extensions (three Screen Time, one WidgetKit/ActivityKit) | ✅ Yes | ❌ No | Xcode 26.3 / iOS 26.2 SDK on `macos-15`, Swift 6 language mode with complete strict concurrency and warnings-as-errors |
| `HopPotty` app target (SwiftUI, 182 files) | ⚠️ **In progress** | ❌ No | Same job. Type-checked repeatedly; see `Docs/FirstBuild.md` for every diagnostic found and fixed, and for whatever the last run still reports |
| Screen Time runtime behaviour | ❌ **Unobserved** | ❌ No | Needs a physical device + entitlement |

**No Screen Time behaviour has been observed on hardware, and no entitlement has
been requested or approved.** Nothing about the CI job changes that: it builds
the mock scheme, which swaps the whole Family Controls layer out at compile
time, and it never signs — so it can prove nothing about entitlements,
provisioning or App Groups either. `Docs/FirstBuild.md` has a table of the
failures it structurally cannot catch.

---

## Current phase

**The first compile.** `Docs/FirstBuild.md` is the record: what the compiler
found, layer by layer, in the order it surfaced, and why each fix is the right
one. The headline numbers are that the four extensions now build, and the app
target went from never having been type-checked to a short and shrinking list.

The phase after this is a device.

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
- **Hop character art.** Redrawn to the product owner's approved reference
  (`hop_mascot.svg`), recoloured from its #64C157 onto the brand ramp. The
  reference is one fused outline, so the generator rebuilds it as articulated
  parts in the reference's own 150×160 space; eleven states (idle, blink, talk,
  wave, walk, wait, jump, land, cheer, sleep, face) are parameter sets over
  those parts and interpolate rather than cut. Reviewed against rendered output.
- **Screen render harness.** Renders screens from the *exported design tokens*,
  so a render cannot drift from what the app compiles against.

- **Scheduling engine.** 115 tests across 9 suites. Wall-clock membership is
  tested by converting an instant to hour/minute components rather than comparing
  against precomputed boundary Dates — a 01:00–03:00 quiet window is one real hour
  in spring and three in autumn, and no instant ever reads 02:xx on a
  spring-forward day. Both trigger bases (`.screenActivity`, `.clockTime`) are
  separate code paths.
- **Content.** 426 copy entries, 17 quiz questions, 5 routine steps, 31 voice
  lines (all `.planned`; the app degrades explicitly to captions). The safety
  tests caught real shame language in first-draft copy — "No stars yet" on the
  pond screen — and it was fixed.
- **SwiftUI design system.** 37 files, every component in `DesignSystemAPI.md`,
  67 previews. Hop drawn as animatable paths with poses that interpolate. Exactly
  one `accessibilityReduceMotion` reader in the app.
- **Screen Time layer.** Services, three Screen Time extensions, App Group store, a pure
  `ShieldReconciler` that runs on every launch, foreground, monitor callback and
  shield-configuration invocation, a mock that cannot ship, and a DEBUG-only lab.
  22 assumptions marked `UNVERIFIED — confirm on device` with a test step each.
- **Platform services.** SwiftData models with a versioned schema and migration
  plan, repositories with in-memory doubles, corruption recovery that never
  crashes, export with no identifiers, deletion that returns counts, StoreKit 2
  with prices only from StoreKit, notifications as a closed two-case enum.
- **Features.** 73 files across onboarding, parent home, timer settings,
  progress, settings, parent gate, purchases, routine, pond, games and quizzes.
  `RootView` wires the app entry point to the feature graph.
- **Xcode project definition.** `project.yml`, xcconfigs, plists, entitlements,
  StoreKit config, bootstrap script, a config verifier (52 checks passing), CI.
- **Documentation.** 20+ documents including a complete privacy data inventory.
- **Vector art.** 150+ SVGs: Hop in 15 states generated from one parameterised
  drawing (`Scripts/hop-art.js`) that matches the supplied reference mascot in
  the brand green, a layered pond with all 41 items, five routine scenes, eight
  mini-game scenes, shield hero, the full quiz icon set, event glyphs, app icon.
- **Screen renders.** Every parent and child screen, the routine steps, the
  games hub and all eight games, settings, paywall, error states, widgets and
  Live Activity, rendered from the exported design tokens
  (`Scripts/screens`, output in `Art/render/screens`).
- **Mini-games.** Eight games in `MiniGameCatalog` (Bubble Wash, Potty Path,
  Bathroom Match, Fly Snack, Mud Off, Listen to Your Body, Flush and Wave,
  Potty Order), each with a session model, a SwiftUI board, scene art and a
  render. Fly Snack ends with Hop needing the potty and hands off into the
  routine. No game has a score, a countdown or a failure state.
- **Quick Reminder.** A one-off parent-set nudge (presets or a time) as a local
  notification: planner and repository in Core with tests, a service over
  `UNUserNotificationCenter`, a sheet and a chip on the Home screen, withdrawn
  on profile deletion.
- **Widget and Live Activity.** `Extensions/HopPottyWidgets`: Hop and the next
  Potty Pause countdown in five widget families, a Live Activity for a pause in
  progress. The App Group snapshot carries no outcomes, counts, names (off by
  default) or app tokens. Timeline plan and snapshot builder are tested.
- **Child mode.** The Hop tab opens a full-screen hub (routine, pond, games,
  questions) that only the parent gate can leave; the routine opens itself when
  the app becomes active during a pause, reading the pause and never changing it.
- **Web prototype.** `Scripts/web/build-prototype.js` turns the same screen
  modules, tokens and SVGs into a static, tappable walkthrough (`web/dist`:
  prototype, gallery of every screen and Hop state, product docs). It is a
  design prototype, not a port: nothing on the web can pause an app. It is
  deployed at https://hoppotty.vercel.app for review.

## Known gaps (tracked, not hidden)

- **Art coverage.** `Scripts/check-art.sh` reports every illustration key
  referenced by content resolved (65 of 65); the placeholder path in the app
  remains for any key added later without a drawing.
- **Renders are not screenshots.** Nothing here has run on a simulator or a
  device; every picture is a design render from the token export. Two earlier
  renders that over-promised the platform (a named-app list and a custom shield
  layout) were redrawn to what iOS actually allows.
- **Copy conflicts resolved in favour of the brief**: shield buttons are
  "Let's Go!" / "Need a grown-up?" and the unlock is "HopPotty Family".
- **Kids Category**: `AppReviewStrategy.md` recommends 4+ Health & Fitness;
  `ReleaseChecklist.md` presumed Kids Category. Flagged as an open decision.

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

1. Generate the Xcode project on a Mac (`Scripts/bootstrap.sh`) and fix the
   first compile pass across the app and four extensions; every SwiftUI file
   was self-reviewed and parsed but never type-checked.
2. Run the Screen Time proof of concept on a physical device.
3. Work `Docs/PhysicalDeviceQA.md` and record observed behaviour.
4. Replace the SF Symbol on the Hop tab with a rasterised Hop face asset
   (SwiftUI tab items accept only `Image`), and add pond decoration assets to
   the asset catalog so the Home backdrop can show unlocked items.
