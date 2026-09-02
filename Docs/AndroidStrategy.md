# Android Strategy

**Date:** 2026-09-02
**Audience:** whoever decides whether to fund this.
**Related:** `BUILD_STATUS.md` (what is actually verified), `Docs/ADR/0001-platform-agnostic-core.md`
(why a portable core exists), `Docs/ScreenTimeArchitecture.md` (the iOS mechanism this
document tries to reproduce), `Docs/ProductVision.md` (the rules a port may not break).

## How to read this document

| Marker | Meaning |
| --- | --- |
| **MEASURED** | Counted in this repository on 2026-09-02. The command is given or implied; re-run it. |
| **SOURCED** | Taken from a document published by Google or the Swift project, read on 2026-09-02, URL cited. |
| **JUDGEMENT** | My engineering opinion. Argue with it. |
| **UNVERIFIED** | I could not establish it with confidence. Listed again in §9. |

---

## 1. The blunt answer

**You can build an Android app. You cannot build *this* app on Android.** HopPotty's
defining mechanism — briefly shielding the child's games with a system-enforced block
that survives HopPotty's own process being killed — is a capability Google reserves for
itself. The Android role that corresponds to Apple's Family Controls (`SUPERVISION`) is
granted only by OEMs to preinstalled system apps; the enterprise route (`DevicePolicyManager`
device owner) gives real blocking but can only be provisioned on a factory-fresh device
through a process no ordinary parent will complete; and Digital Wellbeing's app limits have
no public third-party API. What is left is what every Android parental-control app actually
does: an `AccessibilityService` watching for the child opening a selected app and slamming
an activity over the top of it. That is permitted by Google Play policy today — there is an
explicit parental-control carve-out — but it is a *discretionary, reviewed* permission, it
was tightened again on 28 January 2026, Android 17's Advanced Protection Mode revokes it
outright from any app not classified as an accessibility tool, and it stops working entirely
whenever Samsung's or Xiaomi's battery manager decides your process has been idle too long.
The good news, and it is real: HopPotty's failure mode is unusually forgiving. Its contract
is "the pause is short and the play comes back", so a mechanism that fails *open* — a missed
interruption — is aligned with the product, where a stranded shield would be a catastrophe.
An Android HopPotty would therefore be an honest product with a **weaker promise**: "HopPotty
tries to interrupt the game; on most phones it will, on some it will miss," bought with four
to six permission grants during setup instead of iOS's single prompt. **My recommendation is
not to fund it now** — the iOS app has never been compiled, its own core premise has never
run on hardware, and there are zero families using either. Ship iOS, prove the mechanism,
then spend two to five days of the cheap insurance in §7 so the Android door stays open at
roughly no cost.

---

## 2. What HopPotty's mechanism actually is, stated precisely

Everything below turns on reproducing this, so it is worth being exact about what iOS gives
us (`Docs/ScreenTimeArchitecture.md` §5, §9):

1. HopPotty writes a set of opaque app tokens into a named `ManagedSettingsStore`.
2. **The operating system**, not HopPotty, refuses to show those apps and draws a shield.
3. The shield persists across HopPotty being backgrounded, killed, updated, or the device
   rebooting. HopPotty's process is irrelevant to whether the block holds.
4. HopPotty clears the store and the block ends.
5. Three app extensions — separate processes the OS wakes on its own schedule — can end the
   pause even when the app is gone.

Property (3) is the whole thing. It is why the iOS architecture spends its entire fail-safe
budget on *removal* (`ShieldReconciler`, five clear-always rules, `errorAccessRestored`): the
dangerous state is a shield nobody can take down. **Android inverts this.** On Android the
block *is* your process. Your process dying means the child gets their game back. That is a
worse enforcement guarantee and a better safety guarantee, and for this specific product the
trade is less bad than it looks (§3.8).

---

## 3. The Android app-blocking analysis

### 3.1 `SUPERVISION` role — the true equivalent, and it is closed

AOSP defines a `SUPERVISION` role whose stated purpose is *"to enable controls for a user's
parent or legal guardian to manage the device."* That is Family Controls, almost word for
word. Its requirements (**SOURCED**,
[source.android.com/docs/core/permissions/android-roles](https://source.android.com/docs/core/permissions/android-roles)):

> - The app is a system app or a preinstalled service
> - Only OEMs can grant this role to the app

**Verdict: dead end.** A Play-distributed app cannot hold it. Android 16 added a Supervision
settings page and Android 17 exposes on-device parental controls, but these drive Google's own
Family Link, and no public API lets a third party register as the supervisor. This is not a
gap you can lobby around in a product cycle.

### 3.2 `DevicePolicyManager` device owner — real blocking, unprovisionable

A device owner can call `setPackagesSuspended()`, which makes an app behave as if disabled and
shows a system "app is paused" dialog when tapped. That is functionally very close to a shield,
including the crucial property that it is enforced by the OS and survives your process.

The cost is provisioning (**SOURCED**,
[developer.android.com/reference/android/app/admin/DevicePolicyManager](https://developer.android.com/reference/android/app/admin/DevicePolicyManager),
[source.android.com/docs/devices/admin](https://source.android.com/docs/devices/admin)):

> Device owner provisioning can be performed only during the out-of-box setup (or on a
> factory reset device) […] the only way of resetting the device is if the device owner app
> calls a factory reset.

So the parent must factory-reset the child's tablet, and then either scan a provisioning QR
code or run an `adb` command from a computer, and accept that HopPotty now has total control
of the device and cannot be removed except by another factory reset. **JUDGEMENT: dead end for
a consumer app.** It is the correct mechanism and the wrong ask. A parent who will factory-reset
a tablet to install a potty-training app is not a market.

### 3.3 Managed profile (work profile) — the interesting middle, and probably still a dead end

A consumer app can historically fire `ACTION_PROVISION_MANAGED_PROFILE` and become **profile
owner** of a work profile on an ordinary personal device with no enterprise involved. This is
what Shelter and Island do. A profile owner *can* call `setPackagesSuspended()` on apps inside
that profile. No factory reset.

Why it still fails as a product (**JUDGEMENT**):

- The child's games must live *inside* the work profile — a separate copy, separate install,
  a briefcase badge on every icon. You are asking a parent to reinstall their child's apps
  into a second container.
- The work profile has a system-level off switch in Settings and in Quick Settings, and the
  user can delete the profile at will.
- Play's Device and Network Abuse review of an app whose purpose is to provision a work
  profile on a consumer device is **UNVERIFIED**; Island's own Play distribution has been
  intermittent. Shelter is F-Droid-only.
- Android 16 tightened the trust required to activate device owner
  (**SOURCED**, [androidenterprise.community](https://www.androidenterprise.community/android-enterprise-general-discussions-3/activating-device-owner-in-android-16-1434));
  whether profile-owner provisioning by a consumer app is similarly restricted in 16/17 is
  **UNVERIFIED** and is the single highest-value thing to test if anyone wants to revisit this.

Keep it on the shelf as "the answer if accessibility is ever closed off", not as the plan.

### 3.4 Digital Wellbeing / `AppUsageLimit` / Focus Mode — no public API

Digital Wellbeing's per-app time limits and Focus Mode are implemented against
`UsageStatsManager` observer APIs (`registerAppUsageObserver`, `registerAppUsageLimitObserver`)
gated behind `OBSERVE_APP_USAGE`, a permission held by the Digital Wellbeing package.
`UsageStatsManager`'s *public* surface for third parties is read-only usage history behind
`PACKAGE_USAGE_STATS`, which the docs describe as *"a system-level permission [that] will not
be granted to third-party apps"* — the user grants it manually in Settings → Special app access
(**SOURCED**, [developer.android.com/reference/android/app/usage/UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager)).

**Verdict: dead end for enforcement, useful for observation.** There is no public way to ask
the system to enforce a limit on your behalf. `PACKAGE_USAGE_STATS` gets you `queryEvents()`
and therefore a poll-based answer to "which app is in the foreground", at whatever latency and
battery cost your polling interval buys. It cannot push you an event, and it does not see apps
running as foreground services.

### 3.5 `AccessibilityService` — what everyone actually does

An `AccessibilityService` receives `TYPE_WINDOW_STATE_CHANGED` events with the package name of
whatever just came to the front. The standard blocker is four lines of intent: see the child
open a blocked package, immediately `startActivity()` your own full-screen activity over it,
optionally with a `SYSTEM_ALERT_WINDOW` overlay as a belt to the braces. Qustodio, Kaspersky
Safe Kids, Net Nanny, AppBlock and Stay Focused all work this way. It is event-driven rather
than polled, which is why it beats the `UsageStatsManager` approach on both latency and battery.

**This is the only viable mechanism for a Play-distributed consumer HopPotty.** Everything in
§4 assumes it.

### 3.6 The Play policy verdict — the critical question, answered

This is the question the whole business case rests on, so here is the actual policy text
rather than a summary of a summary.

**HopPotty is not eligible to declare `isAccessibilityTool="true"`.** The policy limits that
flag to *"services that are designed to help people with disabilities access their device or
otherwise overcome challenges stemming from their disabilities"*, and it names the ineligible
categories explicitly: *"antivirus software, automation tools, assistants, **monitoring apps**,
cleaners, password managers, and launchers"* (**SOURCED**,
[Use of the AccessibilityService API](https://support.google.com/googleplay/android-developer/answer/10964491)).
A parental-control app is a monitoring app. Do not attempt this flag; a false declaration is
the fastest route to account termination.

**A non-accessibility-tool app may still use the API**, narrowly, for a declared purpose, with
prominent disclosure and user consent, after completing a Permission Declaration Form and
receiving Play approval. Failure is not a rejection, it is *"a suspension of your app and/or
termination of your developer account."*

**The prohibited-uses list contains an explicit parental-control carve-out.** The Permissions
policy prohibits using the Accessibility API to:

> "Change user settings without their permission or prevent the ability for users to disable or
> uninstall any app or service **unless authorized by a parent or guardian through a parental
> control app** or by authorized administrators through enterprise management software."

(**SOURCED**, [Permissions and APIs that Access Sensitive Information](https://support.google.com/googleplay/android-developer/answer/16585319))

**The January 2026 tightening does not obviously catch HopPotty.** Enforcement from
28 January 2026 added:

> "Any use of the Accessibility API that enables an app to autonomously initiate, plan, and
> execute actions or decisions is strictly prohibited. This does not prohibit deterministic,
> rule-based automation, where behavior follows a static, human-defined script (for example,
> 'If Trigger X occurs, perform Action Y')."

"If the child foregrounds a parent-selected app while a pause the parent scheduled is running,
show the pause screen" is exactly the shape of the permitted example. The change was aimed at
LLM agents driving other apps' UIs, not at blockers.

**So: the verdict is *permitted, conditional, and fragile*.** Not prohibited — the carve-out
is real and current, and a shelf of parental-control apps ships on Play on the strength of it.
But three things make it materially riskier than an iOS entitlement:

1. **It is discretionary review, not a granted entitlement.** Apple's Family Controls
   distribution entitlement, once approved, is a durable capability. Play's accessibility
   declaration is re-examined at every review, by a reviewer whose incentive after a decade of
   accessibility-abused malware is to say no. Historical precedent: in late 2017 Google emailed
   developers that any non-disability use of accessibility would be removed, then backed down
   after developer backlash. The policy has been ratcheting back toward that position ever since.
2. **Android 17 Advanced Protection Mode revokes it.** With Advanced Protection on, the system
   blocks any app not flagged `isAccessibilityTool` from holding accessibility permissions,
   *revokes the permission from apps that already have it*, and prevents the user from granting
   it again without turning the mode off (**SOURCED**,
   [thehackernews.com](https://thehackernews.com/2026/03/android-17-blocks-non-accessibility.html),
   [androidauthority.com](https://www.androidauthority.com/android-17-beta-2-advanced-protection-mode-accessibility-apps-3648860/)).
   A security-conscious parent turning on the security feature silently breaks the safety app.
   You must detect this and tell them, and there is nothing else you can do.
3. **The policy could move again.** Nothing here is a contract. Budget for the possibility that
   the Android product's mechanism is withdrawn by a policy update you did not vote on.

### 3.7 The secondary Android taxes, which bite HopPotty specifically

HopPotty is an interval timer that must fire punctually and then seize the screen. Android has
spent five releases making both of those things hard.

| Constraint | What it does to HopPotty | Source |
| --- | --- | --- |
| **Exact alarms.** `USE_EXACT_ALARM` is a Play-restricted permission for *"alarm or timer"* and calendar apps only; `SCHEDULE_EXACT_ALARM` is denied by default on Android 13+ and must be granted by the user in Settings. | The pause schedule is the product. HopPotty plausibly qualifies as a timer app, but that is a review argument you must win, or a second Settings trip for the parent. | [Play policy](https://support.google.com/googleplay/android-developer/answer/16558241), [Android 14 changes](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms) |
| **Full-screen intents.** From Android 14, `USE_FULL_SCREEN_INTENT` is auto-granted only to calling and alarm apps; Play revokes it by default from everything else as of 22 January 2025. | The *warning* before a pause, and any pause on a locked device, wants a full-screen notification. Another declaration, another possible no, another user grant. | [Play policy](https://support.google.com/googleplay/android-developer/answer/13392821) |
| **Overlays.** `SYSTEM_ALERT_WINDOW` is a Special App Access grant; from Android 15 an app needs a *visible* overlay window before it may start a foreground service from the background. | A third Settings trip. Usable, but it is a permission with a bad reputation that parents are told to be suspicious of. | [Android 15 behavior changes](https://developer.android.com/about/versions/15/behavior-changes-15) |
| **Usage access.** `PACKAGE_USAGE_STATS` is a fourth Special App Access grant. | Needed if you want usage-based scheduling (`.screenActivity` trigger basis — `HopPottyCore/Models/PottySchedule.swift` supports it and iOS gets it free from DeviceActivity). | [UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager) |
| **App visibility.** `QUERY_ALL_PACKAGES` is Play-restricted; the inventory of installed apps is treated as personal and sensitive, permitted only where it is the app's core purpose. | The parent's app picker. iOS solves this with `FamilyActivityPicker`, which hands back opaque tokens and never reveals identities — the reason `Docs/PrivacyArchitecture.md` can claim what it claims. On Android you either win a `QUERY_ALL_PACKAGES` declaration and *do* learn what the child uses, or you build a much worse picker from launcher intents. **This is a privacy regression, not just a technical one.** | [Play policy](https://support.google.com/googleplay/android-developer/answer/10158779) |
| **OEM process killing.** Samsung sleeps apps with no foreground activity for three days; Xiaomi/HyperOS is rated "very high" aggression; `isIgnoringBatteryOptimizations()` can return true while the OEM manager kills you anyway. | The blocker is your process. Dead process, no pause. This is not solvable in code — it is solvable only by a per-OEM onboarding screen begging the parent to whitelist you, which is what every affected app ships. | [dontkillmyapp.com](https://dontkillmyapp.com/samsung) |

Count the Settings trips: accessibility service, overlay, usage access, notifications,
battery-optimisation exemption, and on many devices an OEM autostart toggle. **Six grants
versus iOS's one system prompt.** For an app whose onboarding currently makes a virtue of
asking for almost nothing, that is a product problem before it is an engineering one.

### 3.8 So what would the Android product actually be?

Not a weaker version of the same claim. A different, honestly smaller claim.

**What it can do, reliably enough to sell:**

- Schedule the interval, quiet hours, active window, cooldown — all of `HopPottyCore`'s
  scheduling engine works identically; it is arithmetic.
- Fire the pre-pause warning as a notification.
- At pause time, put HopPotty's own pause screen in front of the child *if HopPotty's process
  is alive and the accessibility service is running*, and hold it there while the child opens
  the selected games.
- Run the entire rest of the product unchanged in substance: the routine, the celebration,
  the star ledger, the pond, the eight mini-games, the quizzes, the insights, the parent gate,
  the export and deletion.

**What it cannot do:**

- Guarantee the interruption. On a phone with an aggressive OEM battery manager, or with
  Advanced Protection Mode on, or after the OS has killed the service, the pause silently does
  not happen. HopPotty will not always know that it did not happen.
- Block anything while HopPotty is not running.
- Keep the child's app list private from HopPotty, if it wants a decent picker.

**And here is the part that makes this survivable.** HopPotty is not a punitive blocker. Its
threat model is a two-to-five-year-old, not a teenager evading supervision; the rules in
`Docs/ProductVision.md` §5 say the product exists to be *stopped using*; a missed pause costs a
family one skipped bathroom prompt. Android's failure mode is fail-open — the game keeps
working — which is the direction HopPotty's own contract already prefers. On iOS, an enormous
amount of the architecture exists to prevent a stranded shield; on Android that class of
failure is nearly impossible, because the block cannot outlive the process that draws it.

**The Android product is therefore: a potty-training routine app with best-effort game
interruption, sold as best-effort.** If the store listing says "pauses your child's games" full
stop, you will earn one-star reviews from every Xiaomi owner. If it says "HopPotty interrupts
the game to invite your child to the potty — on some phones the interruption can be delayed or
missed, and here is how to make it reliable", you have a product that keeps its promises. The
copy catalog's honesty rules (`Docs/ChildSafety.md`, `CONTRACTS.md`) already point this way;
`Docs/ScreenTimeArchitecture.md` §11.12 — *"never tell a caregiver these apps are blocked"* —
turns out to have been written for Android too.

---

## 4. What is actually in this repository — measured, not estimated

All figures **MEASURED** on 2026-09-02 at commit `2e50c39`.

### 4.1 Size

| Layer | Files | Lines | Portable? |
| --- | ---: | ---: | --- |
| `HopPottyKit/Sources/HopPottyCore` | 48 | 11,292 | Foundation only |
| `HopPottyKit/Sources/HopPottyDesignTokens` | 6 | 663 | Foundation only |
| `HopPottyKit/Sources/HopPottyFixtures` | 2 | 184 | Foundation only |
| `HopPottyKit/Sources/hoptokens` | 1 | 127 | Foundation only |
| **`HopPottyKit` sources, total** | **57** | **12,266** | **yes** |
| `HopPottyKit/Tests` | 36 | 8,025 | yes — 464 `@Test`, 34 `@Suite` |
| `HopPotty/` (SwiftUI app) | 182 | 43,108 | Apple-only |
| `Extensions/` (3 Screen Time + 1 WidgetKit) | 8 | 1,717 | Apple-only, and conceptually iOS-only |
| **Everything** | **284** | **65,147** | |

Non-test source is 57,091 lines. **`HopPottyKit` is 21.5% of it.**

The 464 tests and 34 suites claimed in `BUILD_STATUS.md` are confirmed by count
(`grep -c '@Test'` over `HopPottyKit/Tests`); `Docs/TechnicalArchitecture.md` still says
350/28 and is stale.

### 4.2 Is the core genuinely free of Apple types? Yes — and it is better than that

Every `import` statement in `HopPottyKit/Sources`:

```
57  import Foundation
 2  import HopPottyCore
 1  import HopPottyDesignTokens
```

No SwiftUI. No UIKit. No SwiftData. No FamilyControls, ManagedSettings, DeviceActivity,
Combine, OSLog, CoreGraphics. The boundary in `ADR/0001` has held.

More usefully, the *shape* of the code is unusually portable:

| Property | Count | Why it matters for a Kotlin port |
| --- | ---: | --- |
| `public struct` | 87 | → Kotlin `data class`, near mechanical |
| `public enum` | 75 | → `enum class` / `sealed interface`; Kotlin `when` over a sealed type is exhaustive, so the totality argument survives |
| `class` declarations | **0** | No reference semantics, no inheritance, no identity to reason about |
| `actor` declarations | **0** | No concurrency model to translate |
| `protocol` declarations | 3 | Almost no abstraction to re-express |
| `@propertyWrapper`, `@resultBuilder`, macros | **0** | No Swift-only metaprogramming to unwind |

The Foundation surface it actually touches is tiny: `Date` (264 uses), `UUID` (107),
`Calendar` (33), `TimeZone` (2), `DateComponents` (1), `DateInterval` (1), and `Mirror` in
exactly one place. `DateFormatter` and `Timer` appear only in comments explaining why they were
*not* used. Every one of these has a direct `kotlinx-datetime` / `kotlin.uuid` equivalent except
`Mirror`, which is used solely to derive `HopCopy.allEntries` by reflection
(`HopPottyKit/Sources/HopPottyCore/Content/HopCopyEntry.swift:504`) — replaceable in Kotlin by
reflection or, better, by a build-time codegen step from an exported catalog (§7.2).

**JUDGEMENT: this is close to the best case for a domain port.** 11,292 lines of pure value
types and total functions with a 7-symbol platform surface is a specification you can transcribe,
not a system you have to reverse-engineer. The 8,025 lines of tests transcribe with it and tell
you when you got it wrong.

### 4.3 How much logic leaked above the boundary

Of 190 Swift files in `HopPotty/` and `Extensions/`, **139 import an Apple framework and 51 do
not** — 9,023 lines of view models, mini-game session logic, service protocols, formatting and
App Group plumbing that is Foundation-shaped but living in the app target. Roughly 1,300 lines
of that (`AppGroupStore`, `MonitoringPlan`, `PottyPauseEffectExecutor`) is Screen-Time-shaped and
would not survive a port anyway. The remaining ~7,700 lines — `OnboardingModel`,
`ParentHomeModel`, the eight `*Session` game models, `QuizRoundModel`, `InsightPresentation`,
`ParentFormatting` — are portable in design if not in syntax, and several of them arguably belong
in `HopPottyCore` already.

### 4.4 The non-Swift assets, which are the quiet win

| Asset | Measured | Android portability |
| --- | --- | --- |
| `Art/` SVG sources | **153 SVGs** (plus 385 throwaway PNG renders, 86 MB) | Android `VectorDrawable` covers the features in use. Across all 153: **0** use `filter`, `mask`, `pattern` or `<use>`; 82 use `linearGradient` and 86 `radialGradient` (both supported since API 24); 29 use `clipPath` (supported); 93 use `transform` (baked by Android Studio's importer). Only **6** use `stroke-dasharray` and **2** contain `<text>` — the entire manual conversion burden. |
| Design tokens | `hoptokens` already emits `Scripts/tokens.json` (7.5 KB): 4 appearances × 24 semantic colours, spacing, radius, hit targets, typography, motion | Feeds a generated Compose `Theme.kt` exactly as it already feeds the web prototype. Zero rework. |
| Copy catalog | 426 entries, keys dot-separated, English beside the key, translator comments inline, audience tagged | Ports as data — *once there is an exporter* (§7.2). Today it is Swift source. |
| Child-safety rules | Forbidden-word lists + `CopySafetyScanner` + `InsightLanguagePolicy` | Pure logic over strings. Ports with the catalog and stays enforced by tests. |
| Generators + render harness | `Scripts/*.js`, Node + Playwright, 20 modules | Already platform-neutral. They read `tokens.json` and the SVGs and know nothing about Apple. `Scripts/web/build-prototype.js` already renders the entire product in a browser — **existence proof that the design layer is not Apple-bound.** |

---

## 5. The options

Effort figures are **JUDGEMENT**, in engineer-weeks for one competent developer, and assume the
Android mechanism of §3.5. "Reused" means from this repository as it stands today.

| # | Option | Effort | Risk | Reused | What the iOS codebase suffers | What the Android product is |
| --- | --- | ---: | --- | --- | --- | --- |
| **1** | **Kotlin/Compose app, domain hand-ported to Kotlin.** Transcribe `HopPottyCore` + `HopPottyDesignTokens` into Kotlin; port the 464 tests as Kotlin tests; regenerate tokens into a Compose theme; convert the SVGs; rebuild the UI in Compose; write the accessibility blocker. | **16–24 wk** | Medium. Known technologies end to end. The domain port is transcription against a test suite that tells you when you are wrong. Chief risk is the blocker and the six permission grants, not the code. | Domain *as specification* (11,292 lines), all 464 test cases, 153 SVGs, tokens.json, copy, safety rules, generators, docs. **0 lines of Swift compile.** | **Nothing.** iOS is untouched and keeps its Swift 6 guarantees. | The §3.8 product. Two independent codebases that must be kept in step by discipline and a shared spec. |
| **2** | **Kotlin Multiplatform.** Rewrite `HopPottyCore` in Kotlin *once*, in `commonMain`; SwiftUI consumes it through the Kotlin/Native Obj-C framework; Compose consumes it directly. | **22–32 wk**, of which **6–9 wk is spent breaking and rebuilding the working iOS app** | **High, and mostly borne by iOS.** Gradle + a Kotlin toolchain enter the iOS build. Swift's exhaustive `switch` over enums-with-payloads — the mechanism that caught the `errorAccessRestored` bug (`TechnicalArchitecture.md` §6.1) — does not survive Obj-C interop: sealed classes arrive in Swift as plain classes with no exhaustiveness. `Sendable` and strict concurrency checking do not cross either. | The same as option 1, *plus* one domain instead of two thereafter. | iOS loses type-level guarantees it currently relies on, gains a build dependency, and pays a migration before the second app exists. | Same product as option 1, one shared brain. The right structure **if and only if** Android is committed and long-lived. |
| **3** | **Swift SDK for Android** (Swift 6.3, first official release March 2026 — **SOURCED**, [swift.org/blog/nightly-swift-sdk-for-android](https://www.swift.org/blog/nightly-swift-sdk-for-android/)). Compile `HopPottyCore` unchanged for Android; call it from Kotlin via `swift-java` JNI; Compose UI on top. | **18–28 wk**, plus a **1–2 wk spike first** | **Medium-high, and novel.** The toolchain is six months old; 2,200+ packages build for Android, but the JNI bridging of 87 structs and 75 enums is hand-written surface, and you are among the first to ship a consumer app this way. | **The only option where the 12,266 lines and 464 tests literally run**, unchanged, on both platforms. | Nothing, unless the shared core has to change shape to bridge well. | Same product; one *actual* codebase for the domain, at the price of a Swift toolchain in the Android build and a JNI layer to maintain. |
| **4** | **Flutter or React Native rewrite** of both platforms. | **28–40 wk** | High. | Art (as SVG, natively), tokens, copy, safety rules, docs. **Throws away 43,108 lines of SwiftUI and 12,266 of Swift domain.** | **Destroyed and rewritten.** | You still write the Android blocker in Kotlin (no plugin abstracts `AccessibilityService`) *and* the iOS Screen Time layer in Swift (no plugin abstracts Family Controls, extensions, or the shield). You pay for a cross-platform framework and then write both hard parts natively anyway. React Native additionally loses the custom vector character animation cheaply; Flutter handles that fine. **JUDGEMENT: the worst option on the table for this specific product.** |
| **5** | **Compose Multiplatform.** Compose for iOS went stable in 1.8.0 (May 2025) and is production-credible in 2026 (**SOURCED**, [JetBrains](https://blog.jetbrains.com/kotlin/2025/05/compose-multiplatform-1-8-0-released-compose-multiplatform-for-ios-is-stable-and-production-ready/)). | **30–42 wk** | High. | As option 4. | **Destroyed and rewritten**, and the iOS UI becomes non-native for a child-facing app whose whole design is bespoke motion and vector character work. | Option 2's downsides plus option 4's rewrite. Only sane if you were starting from nothing today. |
| **6** | **Do nothing. Stay iOS-only.** | **0** | Low, and honest. | Everything. | Nothing. | No Android product. |

---

## 6. Recommendation

### 6.1 Do not fund an Android port now. Option 6, with the §7 insurance.

The reasoning, in order of weight:

1. **The iOS product does not exist yet.** `BUILD_STATUS.md` is unambiguous: the Xcode project
   has never been generated, no SwiftUI file has ever been type-checked, the four extensions have
   never compiled, no Family Controls entitlement has been requested, and **the Screen Time loop
   — the product's core premise — has never run on hardware.** Funding a second platform before
   the first one has compiled is funding two unproven products. Every hour spent on Android is an
   hour not spent on the first device test, which is the single highest-information action
   available to this project.
2. **The Android mechanism is exactly the part of the product you have the least evidence about.**
   You are proposing to reproduce, on a hostile platform, a mechanism you have not yet observed
   working on the friendly one. You do not yet know how long a pause should be, whether children
   respond to a shield, whether parents complete the setup, or which of the five end-paths
   actually fires. Those answers change the Android design.
3. **Android's version is a different product, and you should learn whether the weaker version is
   worth selling *from iOS data*.** If it turns out families ignore the shield and use the routine
   and the pond, the Android product is nearly as good as the iOS one and you should build it. If
   the shield is the entire value, the Android product is a pale imitation and you should not.
   **You cannot know this today, and one month of real iOS usage answers it.**
4. **The reuse economics get *better* with delay, not worse.** The domain is already portable, the
   tests already pass, the art already converts, and every month the Swift-on-Android toolchain and
   Compose Multiplatform mature. There is no first-mover advantage in a potty-training app.

### 6.2 When you do build it, build option 1 — with option 3 spiked first

If Android becomes committed:

- **Spend one to two weeks on the option 3 spike before anything else.** Try to build
  `HopPottyKit` with the Swift 6.3 Android SDK and call `PottyPauseMachine.reduce` from Kotlin.
  If it works and the JNI surface is bearable, you keep 12,266 tested lines and 464 passing tests
  *literally*, across both platforms, forever. That is the highest-value experiment available and
  it is cheap. If it does not work, you have lost two weeks and learned the answer.
- **Otherwise take option 1: hand-port to Kotlin, Compose UI, two codebases.** Not because two
  codebases are good, but because the alternative (option 2, KMP) pays its migration cost *now*, in
  the working, tested, verified half of a product whose other half has never compiled — to buy a
  saving on a second app that may never ship. That trade is backwards. The domain is 11,292 lines
  of value types with a test suite that tells you the moment the transcription drifts; it is one of
  the few codebases where "write it twice" is genuinely defensible.
- **Adopt KMP (option 2) only at the point where Android is proven, permanent, and the two
  domains have already drifted once.** That is the moment the shared-brain argument beats the
  don't-break-what-works argument. Not before.
- **Do not consider options 4 or 5.** They rewrite the working platform to serve the hypothetical
  one, and they do not save you from writing either hard part natively.

### 6.3 What I would need to know to be more certain

| Question | Why it moves the decision | How to answer it |
| --- | --- | --- |
| Does the iOS Screen Time loop actually work, and do families use it? | If the shield is not the value, Android is nearly a peer product and worth funding. If it is the whole value, Android is a lesser product. | `Docs/PhysicalDeviceQA.md`, then real families. |
| What fraction of the target market is on Android, in the markets you care about? | Globally Android is the majority; in US/UK families with a spare tablet for a toddler, iPad is heavily over-represented. This number could be 20% or 70%. | Not answerable from this repository. |
| Would Play approve HopPotty's accessibility declaration? | Binary gate on the whole Android product. | A throwaway skeleton app on an internal test track with the real declaration text. **Roughly one week, and it is the cheapest way to buy certainty about §3.6.** |
| Does the Swift 6.3 Android SDK build `HopPottyCore`, and is the JNI surface tolerable? | Decides option 1 vs option 3, and changes the effort estimate by weeks. | The spike in §6.2. |
| Can a consumer app still provision a managed profile on Android 16/17? | Would reopen §3.3 — a genuinely enforced pause with no factory reset. | An afternoon on a real device running Android 16 and 17. |

---

## 7. What to do now, cheaply, to keep the door open

Two to five days of work, worth doing whether or not Android ever happens, because every item is
also good iOS hygiene.

### 7.1 Keep the domain free of Apple types — and add a test that says so

**It already is** (§4.2), and the CI job already proves it by compiling on Linux. The gap is that
nothing states the rule as a check. Add a one-line CI step that fails if `HopPottyKit/Sources`
contains an import of anything but `Foundation` and its own targets. Today it would pass; that is
the point — it is a ratchet, not a repair.

**Cost: 1 hour.** **Value: the boundary that makes every option in §5 affordable stops depending
on code review remembering.**

### 7.2 Export the copy catalog as data — the single highest-leverage item

426 entries currently exist only as Swift declarations with reflection-derived enumeration. Add a
`hopcopy` executable target beside `hoptokens` that walks `HopCopy.allEntries` and emits JSON with
key, English, audience, surface, comment, and placeholder list. From that one file you can generate
`Localizable.xcstrings` for iOS, `strings.xml` for Android, and the web prototype's strings — and
the child-safety scanner can run against the export in any language.

This is also the fix for the only real portability wart in the core: `Mirror`. Once the catalog is
exported at build time, the Kotlin side never needs reflection at all.

**Cost: 1 day.** **Value: turns the largest single body of product content from Swift code into
data, and makes localisation possible on iOS too.**

### 7.3 Do not let iOS concepts leak into the core

The core is clean today, but three iOS-shaped ideas sit just outside it and will migrate inward if
nobody watches: `ScreenTimeConfiguration` (already in Core, and already correctly stores *counts*
rather than tokens — keep it that way), `WidgetSnapshot`/`WidgetTimelinePlan` (in Core, named after
WidgetKit but structurally just "what to show and when" — fine, consider renaming if Android ever
lands), and the App Group vocabulary in `HopPotty/Services/ScreenTime/`. The rule to write into
`CONTRACTS.md`: **the core may model *that access is paused*; it may never model *how*.** It
currently obeys this — `PottyPauseEffect` says `.clearShield`, not `store.clearAllSettings()`.

**Cost: 1 hour of documentation.**

### 7.4 Move the leaked logic down

The ~7,700 portable lines identified in §4.3 — the eight `*Session` mini-game models,
`QuizRoundModel`, `ParentFormatting`, `InsightPresentation`, `OnboardingFlow` — are Foundation-only
already and would be tested on Linux if they lived in `HopPottyCore`. Moving them raises the ported
fraction from 21.5% toward ~35% *and* raises today's verified fraction on iOS. Do it opportunistically,
not as a project.

**Cost: incremental.** **Value: pays on both platforms.**

### 7.5 Verify the art pipeline against Android once

Run the 153 SVGs through Android Studio's Vector Asset importer or `svg2vector` and see what breaks.
§4.4 predicts only 6 dashed-stroke files and 2 text files need attention, but that is a prediction
from grep, not an observation. One afternoon converts the prediction into a fact and, if it holds,
removes art from the risk register permanently.

**Cost: half a day.** **UNVERIFIED until someone runs it.**

### 7.6 Keep the render harness honest about platforms

`Scripts/screens/` already renders every screen from `tokens.json`. If Android ever happens, the
same harness should render the Android screens, so the two products cannot drift visually without
a diff showing it. Nothing to build now — just do not let the harness acquire iOS assumptions.

### 7.7 What *not* to do now

Do not adopt KMP "just in case". Do not restructure the app layer for a hypothetical Compose port.
Do not add abstraction layers between the app and Screen Time in the name of portability — the
`ScreenTimeProviding` protocol that already exists is the right amount, and a second layer would
make the iOS code worse to serve an app that does not exist.

---

## 8. What is genuinely irreducible

These get written twice — or three times — no matter which option you choose. There is no
architecture that avoids them, and they are the honest floor on the cost of an Android product.

| Irreducible | iOS | Android | Why nothing shares |
| --- | --- | --- | --- |
| **The blocking mechanism itself** | `ScreenTimeService`, `MonitoringPlan`, `PottyPauseEffectExecutor`, `AppGroupStore`, `ShieldReconciler` — ~2,900 lines | `AccessibilityService`, foreground service, overlay/activity launcher, six permission flows, per-OEM whitelist guidance | Different capability, different guarantee, different failure mode. Not a difference of API, a difference of what the OS will do. |
| **The three Screen Time extensions** | 831 lines across Monitor / ShieldConfiguration / ShieldAction | No analogue exists. Android has no OS-hosted process that draws your block. | The whole extension topology (`TechnicalArchitecture.md` §2) is an iOS artefact. |
| **The App Group protocol** | Versioned atomic-file IPC across four processes | One process. The problem does not exist. | ~1,400 lines that Android simply does not need — the one place where Android is *simpler*. |
| **The shield / pause surface** | A fixed system layout: blur, one static image, title, subtitle, two buttons, no animation (`ScreenTimeArchitecture.md` §11.4) | Your own full-screen activity — full design freedom, and therefore a *different* design | Ironically the Android version can be the nicer one. It is also a completely separate design artefact. |
| **Widget / Live Activity** | WidgetKit + ActivityKit, 886 lines | Android App Widgets (RemoteViews, a far weaker model) or an ongoing notification | Almost nothing transfers except the `WidgetSnapshot` data model, which is already in Core. |
| **Purchases** | StoreKit 2, 522 lines | Google Play Billing | Different SDK, different entitlement model, different receipt story. |
| **Persistence** | SwiftData, ~2,900 lines with a versioned schema and migration plan | Room, or SQLDelight if you ever go KMP | The domain types are shared; the mapping layer is not. `ADR/0001` already anticipated paying this cost once. |
| **Notifications, haptics, audio, biometric parent gate** | `UNUserNotificationCenter`, CoreHaptics, AVFoundation, LocalAuthentication — ~1,300 lines | `NotificationManager` + exact-alarm dance, `VibratorManager`, `MediaPlayer`, BiometricPrompt | Thin, but every one is a separate implementation and a separate set of platform restrictions. |
| **The UI** | 43,108 lines of SwiftUI, including 3,144 lines of hand-parameterised Bézier character animation | Compose, including a transcription of that same geometry into `androidx.compose.ui.graphics.Path` | **The numbers survive; the syntax does not.** Compose's `Path` has the same primitives (`moveTo`, `cubicTo`, `quadraticTo`), so the eleven Hop poses port as *data* — but every view, every transition and every preview is rewritten. This is the largest single line item in any option. |
| **Store presence** | App Store listing, Family Controls entitlement request, App Review | Play listing, accessibility Permission Declaration, exact-alarm and full-screen-intent declarations, Families/target-audience settings, Data safety form | Two review processes with different rules, different reviewers, and different failure modes. Budget calendar time, not engineering time. |

Roughly: **the domain, the content, the art and the design system are shared or transcribable
(~35–43% of the product's substance). The mechanism, the platform services, the persistence
mapping and the entire UI are not (~57–65%).** That ratio is as good as it gets for a native app,
and it is good *because* `ADR/0001` was decided correctly in the first week.

---

## 9. What I could not establish with confidence

Listed so nobody mistakes an inference for a fact.

1. **Whether Play would actually approve *this* app's accessibility declaration.** The policy
   carve-out for parental-control apps is real, current and quoted verbatim in §3.6, and a shelf of
   competitors ships on it. But approval is discretionary, per-app, per-review, and I found no
   public record of a review outcome for a child-directed app of this shape. §6.3 gives the one-week
   experiment that settles it. **This is the largest single unknown in the document.**
2. **Whether Advanced Protection Mode exempts parental-control apps.** Every report of the
   Android 17 behaviour says only `isAccessibilityTool="true"` apps survive, and none mentions a
   parental-control exemption — but none says there isn't one either. If an exemption exists it
   materially improves the Android case. Needs a device running Android 17.
3. **Whether a consumer app can still provision a managed profile on Android 16/17** (§3.3), and
   whether Play permits an app that does. Android 16 demonstrably hardened *device owner*
   activation; profile owner is a separate path and I could not confirm its current state.
4. **The current public status of `registerAppUsageLimitObserver` / `OBSERVE_APP_USAGE`.** I am
   confident there is no *public* third-party API for Digital Wellbeing limits, and the public
   `UsageStatsManager` documentation supports that, but I did not find a Google document that
   states the negative outright. Treat §3.4 as high-confidence rather than certain.
5. **How well `swift-java` JNI bridging handles 87 structs and 75 enums in practice.** The Swift
   6.3 Android SDK is officially released and 2,200+ packages build for Android, but "a package
   compiles" and "a 75-enum domain is pleasant to call from Kotlin" are different claims and I can
   only verify the first from documentation. Hence the spike.
6. **Every effort estimate in §5.** They are calibrated judgement, not measurements, and they
   assume a developer already fluent in Kotlin and Compose. A team learning Compose on this project
   should add 30–50%.
7. **The Android share of this product's actual market.** Not knowable from this repository, and it
   is arguably the most important input to the decision that this document cannot supply.

---

## 10. One paragraph for the person signing the cheque

HopPotty's core mechanism is an Apple capability with no Android equivalent available to a
consumer app; the nearest Android substitute is a permitted-but-fragile accessibility service that
six different system behaviours can silently disable, and the Android product would therefore be
the same routine, rewards, art and content with a *best-effort* interruption instead of a
guaranteed one. That may still be a good product — HopPotty tolerates a missed pause far better
than a stranded one, and Android fails in the forgiving direction — but it is a different promise
and must be sold as one. The port itself is unusually well set up: 12,266 lines of domain logic and
464 passing tests are already free of every Apple framework, the design tokens already export as
JSON, and 145 of 153 drawings convert to Android vectors mechanically. None of that expires. The
iOS app, meanwhile, has never been compiled and its central premise has never run on a device.
**Spend the next money there, spend two to five days on the §7 insurance, and revisit Android when
you can answer "does the shield actually work, and do families care?" with data instead of
argument.**
