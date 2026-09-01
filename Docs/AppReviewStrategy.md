# App Review Strategy

**Date:** 2026-09-01
**Related:** `Docs/Entitlements.md` §5 holds the drafted App Review note and the
entitlement request process — this document decides the *positioning* and does
not restate it. `Docs/ReleaseChecklist.md` owns submission mechanics.

**Status:** No app has been built, submitted, or reviewed. Nothing here is
observed behaviour of App Review; it is a plan with the reasoning attached.

---

## 1. Category and metadata

| Field | Proposal | Reasoning |
| --- | --- | --- |
| **Primary category** | **Health & Fitness** | The app's purpose is a caregiver's tool for a developmental milestone. It is where a parent looks for a potty-training aid. |
| Secondary category | **Education** | Quizzes and the routine are genuinely instructional; Education is where "teaching a child a habit" sits. |
| Alternative considered | Lifestyle / Utilities | Rejected — too vague to be found, and it obscures what the app does. |
| **Age rating** | **4+** | No violence, no mature themes, no user-generated content, no unrestricted web. |
| **Made for Kids** | **No** — see §2 | |
| Price | Free with one non-consumable IAP | |
| **Privacy Nutrition Label** | **Data Not Collected**, every category | Statement of fact: no network request carries user data (`PrivacyArchitecture.md`). |
| Tracking | None. No `NSUserTrackingUsageDescription`, no IDFA | |
| Supported devices | iPhone + iPad, iOS/iPadOS 17.0+ | `TARGETED_DEVICE_FAMILY = 1,2`; Mac Catalyst, "Designed for iPad" on Mac, and visionOS are all explicitly **off** — Family Controls authorization fails outright on visionOS. |

---

## 2. The Kids Category decision — a real analysis

**Recommendation: do not opt into the Kids Category. Ship as a 4+ app in Health &
Fitness, positioned as a caregiver tool.**

This is a genuine trade with costs on both sides.

### 2.1 What the Kids Category would buy

| Benefit | Weight |
| --- | --- |
| Placement in the App Store's Kids tab, browsable by age band | Moderate. Real discovery for a 2–5 audience. |
| A strong parental trust signal — the badge means Apple has applied stricter rules | High for this audience. |
| Forces good behaviour we already commit to (no third-party analytics, no ads, no unrestricted external links) | Low *marginal* value: HopPotty already does all of it by architecture. |

### 2.2 What it would cost

| Cost | Weight |
| --- | --- |
| **Kids apps must not include third-party analytics or advertising, and must not transmit personally identifiable information to third parties.** HopPotty already complies — no cost, and no benefit either. | None |
| **Any link out of the app, purchase, or commerce must sit behind a parental gate.** HopPotty already gates all of it. | None |
| **The app is primarily *for* the child.** This is the crux. HopPotty is primarily a **caregiver's tool operated on a child's device**: the caregiver configures a schedule, reads patterns, manages purchases and holds every destructive action. The child's surface is a few screens deep inside it. Marketing an app whose main surface is a parent dashboard as a Kids app misrepresents it in both directions. | **High** |
| **Family Controls + Kids Category is an unusual combination.** A Kids app that shields other apps is a parental-controls app wearing a children's badge. Reviewers reasonably scrutinise it, and the entitlement review is already the hardest part of shipping. | **High** |
| **Age-band choice is bad in every option.** The child is 2–5 and the operator is an adult. "5 and under" describes the child but not the user who does the work. | Moderate |
| **Kids apps get extra restrictions on future features** — analytics for crash triage, a support email flow, any web content. HopPotty may legitimately want a support path. | Moderate |
| Loses the Health & Fitness placement where a searching parent actually looks | Moderate |

### 2.3 The decision

The Kids Category exists to protect a child using an app **on their own**.
HopPotty's child surface is deliberately narrow, entirely offline, entirely
gated, and reached by a caregiver handing the device over. The category's rules
are ones the app already exceeds, so the badge would buy trust signalling and
discovery at the price of describing the app as something it is not — in the one
review process where being misdescribed is most expensive.

**Ship 4+ in Health & Fitness.** Earn the trust in the listing instead: the
privacy label reads "Data Not Collected", the description says local-only in the
first paragraph, and the first screenshot is the caregiver dashboard, not the
frog.

> **Open conflict to resolve before submission.** `Docs/ReleaseChecklist.md` §10
> currently reads "In the Kids Category that is not a preference; it is a review
> rule", which presumes the opposite decision. Only one of the two documents can
> be right. This one carries the analysis; whoever owns the checklist should
> either adopt this recommendation or record the counter-argument there.

**Revisit if:** the product ever ships a child-only mode a family would install
*for the child*; or caregiver research shows the Kids tab is the discovery path;
or Apple's guidance changes such that a parental-controls app can carry the badge
without ambiguity.

---

## 3. Family Controls entitlement justification

The full request text is drafted in `Docs/Entitlements.md` §5. The argument in
three lines:

1. **The feature cannot be built any other way.** Shielding another app's access
   is possible only through `ManagedSettings`, which requires Family Controls
   authorization. Restoring access reliably while HopPotty is not foregrounded is
   possible only through `DeviceActivity`. A notification does not interrupt the
   app the child is holding.
2. **The scope is minimal.** One named store (`pottyPause`), one setting
   (`shield.applications`). No account lock, no passcode restriction, no media
   rating, no web filter, no app limits. The store is cleared when the pause ends.
3. **The mechanism is bounded and self-terminating.** A pause is minutes long and
   always ends on its own. **No code path can extend one** — the instants on the
   shared pause record are `let`, written once. Access is never contingent on a
   biological outcome.

Process notes that matter for scheduling: the **Account Holder** must submit the
request, **once per App ID** — the app and all three extensions — and Apple
publishes no turnaround. Submit the day the four App IDs exist, not when the app
is feature-complete. Development entitlement behaviour is **not** proof of
distribution behaviour.

---

## 4. Parental gate compliance

Guideline 1.3 / 5.1.4 expect a parental gate in front of anything commercial or
consequential in an app used by children. HopPotty's gate
(`HopParentGate`, `ParentAuthorization`) is documented in
`InformationArchitecture.md` §5. For a reviewer:

| Behind the gate | Not gated |
| --- | --- |
| Entering Parent Space at all | Handing the device to the child |
| Every schedule change, including suspension and the emergency restore | Anything inside the child's routine |
| Every destructive action, each stating exact counts first | Ending a pause by any of its five paths |
| Export | |
| The paywall, purchase and restore | |
| Every external link (privacy policy, support) | |

Two properties a reviewer can check: a passed gate **expires after 15 minutes**,
and destructive or financial actions **re-prompt regardless** of a live
authorization. The default challenge is press-and-hold plus a two-digit sum — it
defeats a preschooler without demanding a passcode from a caregiver whose hands
are full; `deviceOwner` (Face ID / passcode) is the alternative.

---

## 5. Reviewer instructions

### 5.1 Prerequisites the reviewer must know

- Family Controls authorization requires a device **signed into iCloud with a
  passcode set**. Without that, the authorization sheet cannot complete.
- **Whether Family Controls works in the Simulator is undocumented by Apple and
  unverified by us** (`ScreenTimeArchitecture.md` §12.7). The reviewer should use a
  physical device. Confirm this before it goes into the submission note — do not
  assert something we have not tested.
- The demo caregiver passcode goes in the App Review note and must be updated per
  submission.

### 5.2 How a reviewer triggers a Potty Pause in under a minute

This is the single most important thing to get right in the note: a reviewer who
cannot see the feature will reject the entitlement.

```
1. Launch HopPotty → complete caregiver setup (≈30s, no account needed).
2. When prompted, approve the Screen Time authorization.
3. Tap "Choose apps" and pick one app you can open — Photos or Calculator is fine.
4. On the parent home, tap  ►  "Start a pause now".
      ← this is the shortcut. It does not wait for an interval.
5. Press the Home gesture and open the app you selected.
      → HopPotty's shield appears: "Time for a potty break!"
6. Tap "I'm going!".
      → the shield clears immediately and the app is usable again.
   (iOS 26.5+: HopPotty comes forward and the star lands on screen.
    Below 26.5 the star is recorded and shown the next time HopPotty opens —
    that is by design, see below.)
7. To see the automatic end instead: repeat step 4 and simply wait.
   The pause ends on its own at the configured duration, with no input at all.
   Shorten it first in Settings → Potty Pause → Pause length (minimum 1 minute).
```

Also worth pointing at in the note:

- **Settings → Restore Screen Access** — the emergency exit. Clears every shield
  HopPotty owns, from any state, immediately.
- **Settings → Potty Pause → Mode → Gentle** — proves the app is fully functional
  with no shielding at all, which is what a family gets if they decline Screen
  Time.

### 5.3 What a reviewer should *not* be asked to do

- Wait 45 minutes for a natural interval.
- Install a StoreKit configuration or a TestFlight-only build.
- Use a child Apple Account (`.individual` authorization is enough for the
  reviewer's own device).
- Find the Potty Pause Lab — it is a **Debug-only** developer surface, absent
  from Release builds by both `#if HOPPOTTY_DEBUG_TOOLS` and
  `EXCLUDED_SOURCE_FILE_NAMES`. It must never appear in review instructions.

---

## 6. Proposed App Review note

`Docs/Entitlements.md` §5 holds the full, sentence-by-sentence draft that should
be pasted into App Store Connect. What follows is the short covering note that
goes *above* it, addressed to the specific worry a reviewer will have about a
non-parental-controls app holding a parental-controls entitlement.

> **HopPotty — note for App Review**
>
> HopPotty is a potty-training aid for children aged about two to five, set up by
> a caregiver and used on the child's device. It is listed as a 4+ Health &
> Fitness app rather than a Kids-category app because the person who configures
> and operates it is an adult.
>
> **Why the Family Controls entitlement.** The app's core feature, "Potty Pause",
> briefly shields the apps a caregiver chose so the child sets the device down
> and takes a potty break, then restores access automatically. Shielding is only
> possible through ManagedSettings, and restoring access while HopPotty is not in
> the foreground is only possible through DeviceActivity. We use one named
> ManagedSettings store, we set only `shield.applications`, and we clear it when
> the pause ends. We set no other managed setting of any kind.
>
> **Three commitments the review team can verify in the build.**
> 1. A pause always ends on its own — on its timer, when the child taps the
>    shield button, or when the caregiver ends it. There is no code path that
>    extends a pause; the pause record's end instants are immutable once written.
> 2. Screen access is never contingent on whether the child used the toilet. The
>    app never asks, and no branch anywhere reads an outcome.
> 3. All data stays on the device. No account, no analytics SDK, no advertising,
>    no network request carrying family data. App and website tokens are opaque
>    to us and never leave the device; we store counts, not identities.
>
> **Fastest way to see the feature** — full steps below; the short version is:
> approve Screen Time → *Choose apps* → **Start a pause now** → open the app you
> picked → the shield appears → tap **I'm going!** and access is restored.
> *Settings → Restore Screen Access* clears any shield at any time.
>
> Screen Time authorization needs a device signed into iCloud with a passcode set.
> Demo caregiver passcode: `<fill in>`.

**Before submitting, someone must check:** the pause duration quoted matches the
shipped default; the demo passcode is current; the Simulator sentence in
`Entitlements.md` §5 is either verified or removed; and the paywall title matches
the App Store Connect product name ("HopPotty Complete" in copy vs "HopPotty
Family" in the StoreKit file — one of them has to change).

---

## 7. Guideline risk register

| Guideline | Risk | Mitigation |
| --- | --- | --- |
| **5.1.4 Kids** | Reviewer treats an app used by children as a Kids app and applies its rules | We already exceed them. The note states the caregiver-operated positioning up front. |
| **2.5.x / Family Controls scope** | "This is a parental-controls app, not a potty app" | Scope is minimal and stated: one store, one setting, cleared on end. No other managed setting. |
| **3.1.1 IAP** | Purchase not behind a gate | Paywall, purchase and restore are all gated; price comes from StoreKit. |
| **1.3 Age rating** | Rated too low for an app that blocks apps | Nothing in the content is above 4+. Shielding is a caregiver-configured behaviour, not content. |
| **5.1.1 Data collection** | Label mismatch | Nothing is collected; the label is "Data Not Collected" in every category. |
| **2.1 Completeness** | Reviewer cannot trigger a pause | "Start a pause now" exists specifically so the loop is demonstrable in seconds. |
| **4.2 Minimum functionality** | Perceived thinness | The app has a routine, insights, rewards, games, quizzes and multi-child support; the Screen Time loop is one feature among several. |
| **2.3.1 Hidden features** | Debug surfaces in the binary | The Potty Pause Lab is excluded from Release by a compilation condition **and** by source exclusion. |
| **Entitlement approval** | Distribution entitlement not yet requested | The critical-path blocker. Submit for all four App IDs the day they exist; TestFlight is gated on it. |
