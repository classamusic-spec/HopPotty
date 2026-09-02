# App Store Readiness

**Date:** 2026-09-02
**Status of the app:** never compiled, never run, never signed, never installed.
**Status of this document:** the authoritative list of what stands between the
repository as it is today and a build in App Review.

This document exists because "what is this app missing?" has two very different
answers, and both matter:

1. Things Apple will not let you submit without. Most of them are not code.
2. Things that are written down as finished but have never been executed, which
   in an iOS project is the same as not being finished.

It supersedes nothing. `Docs/ReleaseChecklist.md` remains the per-build
submission ritual; `Docs/Entitlements.md` remains the entitlement reference;
`Docs/AppReviewStrategy.md` remains the positioning argument. This document is
the map that says which of them to open, in what order, and what is not covered
by any of them.

**Where a requirement of Apple's is cited, it is either quoted from Apple's own
documentation (with the URL) or explicitly marked as unverified.** Apple changes
submission requirements without announcement; every dated claim below should be
re-checked against App Store Connect on the day you submit.

---

## 0. The short version

| # | Blocker | Who | Needs | Rough lead time |
| --- | --- | --- | --- | --- |
| **B1** | Family Controls **distribution** entitlement approved for four App IDs | Account Holder | Apple's approval | **Unknown and unbounded.** Start on day one |
| **B2** | Apple Developer Program membership, an owned bundle prefix, four App IDs, one App Group | Account Holder | Paid account | 1 day + Apple's enrolment time |
| **B3** | The app and its four extensions have never been compiled | Engineer | Mac + Xcode | Days, not hours |
| **B4** | The asset catalog contains **zero images** — no app icon, and no illustration for any of the 65 keys the content layer references | Engineer + designer | Mac | 2–4 days |
| **B5** | No `PrivacyInfo.xcprivacy` anywhere in the repository | Engineer | Nothing external | Half a day |
| **B6** | No privacy policy, terms or support page exists; the app links to `hoppotty.app`, a domain nobody owns | Owner | A domain + hosting | 1–3 days |
| **B7** | The in-app purchase identifier in Swift does not match the one everywhere else, so the only product cannot load | Engineer | Nothing external | 10 minutes |
| **B8** | Screen Time behaviour has never been observed on hardware; nine documented unknowns are still open | Engineer | Device + B1/B2 | 2–5 days of testing |

B1 is the single external dependency that can stop the product outright, and it
is the only one you cannot buy, build or schedule your way past. Everything else
on this list is work. **Submit the entitlement request the day the App IDs
exist, not the day the app is finished.**

---

## 1. Blockers — you cannot submit without these

### B1. The Family Controls distribution entitlement

**What it is.** `com.apple.developer.family-controls` comes in two forms.
The *development* form you enable yourself in Xcode. The *distribution* form —
the one required for TestFlight, Ad Hoc and the App Store — Apple must approve
and add to your account as a managed capability.

> "Before you distribute an app that uses Family Controls, your Apple Developer
> **Account Holder** must request permission to use the Family Controls
> entitlement." — [Requesting the Family Controls entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)

**Who must do it.** The **Account Holder**, personally. Not an admin, not a
developer, not an agency. If the account is in a company's name, the person
whose Apple Account holds the Account Holder role has to sign in and submit it.

**How.** Either the standalone form at
[developer.apple.com/contact/request/family-controls-distribution](https://developer.apple.com/contact/request/family-controls-distribution/),
or Certificates, Identifiers & Profiles → Identifiers → *your identifier* →
**Capability Requests**
([reference](https://developer.apple.com/help/account/capabilities/capability-requests/)).

**Once per App ID — four times.** The app, the Device Activity Monitor
extension, the Shield Configuration extension and the Shield Action extension.
The widget extension holds no Family Controls entitlement and needs no request
(`Docs/Widgets.md` §5, `project.yml` widget target comment).

> "If your app includes a Screen Time API app extension, submit the same request
> for the extension." — same source.

**What Apple asks for.** The form asks what the app does, why it needs the
Screen Time APIs, and which capabilities it will use. The answer HopPotty should
give is already drafted, sentence by sentence, in `Docs/Entitlements.md` §5 and
summarised in `Docs/AppReviewStrategy.md` §3. Three things make that draft
strong and are worth preserving in whatever final wording is submitted:

1. **The feature is impossible any other way.** Shielding requires
   ManagedSettings; restoring access while the app is backgrounded requires
   DeviceActivity. A notification cannot interrupt the app the child is holding.
2. **The scope is minimal and stated.** One named store (`pottyPause`), one
   setting (`shield.applications`), cleared when the pause ends. No account
   lock, no passcode restriction, no web filter, no media rating, no app limits.
3. **The mechanism is self-terminating and never coercive.** A pause always ends
   on its own, no code path can extend one, and screen access is never
   contingent on a biological outcome.

**Lead time: unknown.** Apple publishes no turnaround for this request, and this
repository has never submitted one. Treat it as an unbounded wait, not a
formality. **UNVERIFIED — do not plan a launch date around a guess.**

**What makes a request fail.** Apple documents no rejection criteria. What is
widely reported by developers — and should be treated as informed hearsay rather
than as Apple's stated policy — is that requests are declined when the app is
not clearly a screen-time or parental-control tool, when the justification is
vague, when the feature could plausibly be built without the entitlement, or
when there is nothing demonstrable to review. Two consequences for HopPotty:

- **Have something to show.** A short screen recording of the Potty Pause loop,
  or a build, makes the request concrete. Chicken-and-egg is real here: the
  entitlement gates TestFlight, but a development-signed build on your own
  device does not need approval, and that build is the evidence.
- **Mind the tension in the positioning.** `Docs/AppReviewStrategy.md` argues,
  correctly, that HopPotty is *not* a parental-controls app for App Review
  purposes. The entitlement reviewer may be looking for exactly the opposite
  signal. The story that satisfies both is one sentence: *a caregiver-configured
  screen-time interruption, minutes long, used to build a toileting routine.*
  It is a screen-time management feature with a narrow purpose — say that, and
  do not let the two audiences receive two different descriptions of the app.

**If it is refused.** This is worth deciding before you ask, not after. The app
already ships **Gentle mode**, which runs the entire product — schedule,
reminders, routine, rewards, pond, games, insights — with no shielding at all.
That is the fallback product, and it is a legitimate one. If the entitlement is
refused, the options are: ship Gentle mode as the whole app (and remove the
Screen Time framework usage from the build, since an unusable entitlement in an
archive is its own rejection); appeal with more detail; or do not ship. Verify
that Gentle mode is complete and coherent on its own during Phase 2 — it is
insurance whose premium is already paid.

**Also verify after approval:** click the info button next to the granted
capability and confirm **Provisioning Support** lists Development, Ad Hoc *and*
App Store. An approval missing App Store distribution passes every local check
and fails at upload (`Docs/Entitlements.md` §2).

---

### B2. An Apple Developer Program account and an owned identifier

The bundle identifiers in this repository are placeholders under a domain
nobody here owns:

| Target | Placeholder |
| --- | --- |
| App | `com.hoppotty` |
| Monitor extension | `com.hoppotty.monitor` |
| Shield Configuration | `com.hoppotty.shieldconfig` |
| Shield Action | `com.hoppotty.shieldaction` |
| Widgets | `com.hoppotty.widgets` |
| App Group | `group.com.hoppotty` |

Changing them touches two places that must agree —
`HOPPOTTY_APP_BUNDLE_ID` in `Config/Base.xcconfig` and the literals in
`HopPotty/Services/ScreenTime/ScreenTimeIdentifiers.swift` — and
`Scripts/verify-config.sh` fails if they drift. Note the knock-on effect: the
in-app purchase identifier is derived from the bundle prefix
(`HOPPOTTY_IAP_FAMILY_PRODUCT_ID = $(HOPPOTTY_APP_BUNDLE_ID).family`), so
changing the prefix changes the product ID that must be created in App Store
Connect. Decide the identifier once, before the App IDs are registered; product
identifiers cannot be reused or renamed after creation.

Family Controls is **not available to a free Apple Developer account.** Without
the paid programme the headline feature cannot run at all, even on your own
device.

---

### B3. The app has never been compiled

Every SwiftUI view, every service, all four extensions: written, self-reviewed,
never type-checked. `HopPottyKit` compiles and passes **464 tests across 34
suites** (re-run and confirmed green on 2026-09-02, Swift 6.2 on Linux) — that
is genuinely verified, and it is roughly half the product's risk. The other half
has never been near a compiler.

The project file itself does not exist: `HopPotty.xcodeproj` is generated from
`project.yml` by `Scripts/bootstrap.sh`, and XcodeGen has never run against that
file either. Expect the first pass to surface, in rough order of likelihood:
XcodeGen schema mismatches (the `storeKitConfiguration` scheme key is flagged
UNVERIFIED in `project.yml`), Swift 6 strict-concurrency diagnostics across the
`@MainActor` service layer, SwiftData model/schema compile errors, missing
imports, and extension `Info.plist` key errors that only fail at runtime.

Budget days, not hours. Nothing else in this document can be finished until this
is done.

---

### B4. There are no images in the app

`HopPotty/Resources/Assets.xcassets` contains exactly four files, all of them
`Contents.json`. There is **not one image** in the app bundle. Two separate
consequences, both blocking:

**B4a — no app icon.** `AppIcon.appiconset/Contents.json` declares three
1024×1024 slots (light, dark, tinted) and none of them names a file. An archive
without an app icon fails App Store Connect validation at upload. The artwork
exists as `Art/appicon/appicon-1024.svg`; what is missing is the export into the
catalog. Apple's requirements: 1024×1024 PNG; the light ("Any Appearance") icon
must be **opaque, with no alpha channel**; the dark and tinted variants follow
the iOS 18+ [app icon guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons)
and are composited by the system. Since Xcode 14 the icon ships in the app's
asset catalog, not as a separate upload.

**B4b — every illustration renders a placeholder.**
`HopPotty/Features/PottyRoutine/Support/ChildArtwork.swift` resolves a
`HopIllustrationKey` to an asset-catalog name by replacing dots with dashes
(`icon.quiz.soap` → `icon-quiz-soap`), and falls back to
`HopArtworkPlaceholder` — "a soft, warm, slightly organic blob" — when
`UIImage(named:)` returns nil. Today it returns nil for **all 65 keys**.

`Scripts/check-art.sh` reports 65 of 65 resolved, but it checks that an **SVG
exists in `Art/`**, not that an image exists in the bundle. There is no step
anywhere in `Scripts/` that writes into `.xcassets` — the pipeline stops at SVG
and PNG rasters under the git-ignored `Art/render/`. The design renders that
look finished are not what the app will draw.

Shipping this would mean a child's routine, quizzes, games and pond rendering as
abstract blobs: a Guideline 2.1 (App Completeness) rejection on sight, and a
product that does not work for a pre-reader regardless of what Apple says.

**The fix is an art export step**, not more drawing: render each `Art/**/*.svg`
to a PDF (vector, single-scale) or to @1x/@2x/@3x PNGs, generate the
`.imageset` directory and `Contents.json` for each, and make
`Scripts/check-art.sh` assert the *bundle* result rather than the source SVG.
Recommendation only — the code is another agent's to write.

---

### B5. There is no privacy manifest

`PrivacyInfo.xcprivacy` does not exist anywhere in the repository.

Apple requires apps to declare the reasons they call **required reason APIs** in
a privacy manifest; uploads that use those APIs without an approved declaration
are rejected (the ITMS-91053 "Missing API declaration" family of errors).
Reference: [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files/describing-use-of-required-reason-api).

HopPotty calls three of those API categories today:

| Category | Where | Reason code to declare |
| --- | --- | --- |
| `NSPrivacyAccessedAPICategoryUserDefaults` | `ScreenTimeService`, `EntitlementCache`, `OnboardingStateStore` — all `UserDefaults.standard` | **CA92.1** (data accessible only to the app itself). Add **1C8F.1** only if app-group defaults are ever introduced — today the App Group uses files, not defaults |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `AppGroupStore.swift` reads `.contentModificationDateKey` when ordering outbox files | **C617.1** (timestamps of files inside the app container or app group container) |
| `NSPrivacyAccessedAPICategorySystemBootTime` | `ProcessInfo.processInfo.systemUptime` in `AppGroupStore`, `ScreenTimeService`, `ShieldReconciler` and the monitor extension — used to detect reboots and measure elapsed time | **35F9.1** (measure elapsed time between events within the app) |

Also declare, and all three are simple statements of fact for this app:

```
NSPrivacyTracking           = false
NSPrivacyTrackingDomains    = []          (empty array)
NSPrivacyCollectedDataTypes = []          (empty array — nothing is collected)
```

**Which bundles need one.** The app certainly. The three Screen Time extensions
all compile `AppGroupStore.swift`, and the monitor extension reads
`systemUptime` directly, so each should carry its own manifest; the widget
extension should too unless someone verifies its sources touch none of the three
categories. Adding a manifest to a bundle that does not need one costs nothing.

**Two caveats, stated honestly.** First, verify each four-character reason code
against Apple's current documentation before shipping — the list has been
extended since it was introduced and this document's codes are from memory of
that page, not a fresh read. Second, the enforcement posture (email warning vs.
hard upload rejection) has tightened over time; assume rejection.

The third-party-SDK half of the privacy-manifest rules does not apply here.
HopPotty has **zero third-party runtime dependencies** — `Package.swift`
declares no external packages — so there is no vendored SDK manifest or
signature to collect.

---

### B6. There is no privacy policy, and the links in the app point nowhere

`HopPotty/Features/Settings/SettingsGate.swift` declares:

```swift
enum HopLegalLinks {
    static let privacyPolicy = URL(string: "https://hoppotty.app/privacy")
    static let terms         = URL(string: "https://hoppotty.app/terms")
    static let support       = URL(string: "https://hoppotty.app/support")
}
```

None of those pages exists. The domain is not owned. The repository contains no
privacy policy text of any kind — `Docs/PrivacyArchitecture.md` is an
engineering document, not a parent-facing policy.

**App Store Connect requires a privacy policy URL for every app**, and it must
resolve for the reviewer. For an app used by children it is not a formality: a
reviewer applying Guideline 5.1.4 will open it.

The good news is that the policy writes itself from the data inventory in
`Docs/PrivacyArchitecture.md` §2, and every claim in it is architecturally true
rather than aspirational. A parent-facing policy must say, in plain language:

- **Nothing leaves the device.** There is no server, no account, no analytics, no
  advertising, no third party. The only network traffic the app can generate is
  Apple's own (StoreKit, and the system's Family Controls authorization).
- **What is stored, and where.** Child nickname (optional), avatar, potty events
  with timestamps and an optional caregiver note, reward ledger, pond progress,
  the schedule, app settings, and the opaque Screen Time selection token — all in
  the app's own container and its App Group container on the device.
- **That this includes a health-adjacent record about a child** — timestamped
  toileting events — and that it is never transmitted, never sold, never used for
  advertising, and never used to train anything.
- **Device backups are the one exception**, at the family's own direction: the
  app's containers are included in an encrypted iCloud or local backup. The app
  does not opt out, so a family that loses a device does not lose their child's
  pond. That is Apple's encryption, not HopPotty's.
- **Purchases are Apple's.** The one-time unlock is handled by the App Store; the
  developer receives no payment details and stores no receipt.
- **Deletion.** The four operations (clear history, reset rewards, delete this
  child, delete everything), what each removes, and that deleting the app removes
  the app container, the App Group container and the private defaults with it.
- **Children's privacy.** No personal information is collected from a child, no
  persistent identifier leaves the device, and no third party receives anything —
  therefore no verifiable parental consent mechanism is required under COPPA,
  because there is nothing to consent to. Say this explicitly; a parent
  evaluating a children's app looks for the COPPA paragraph.
- **Who to contact**, and under GDPR, who the controller is and in what
  jurisdiction. This requires naming a real legal entity and a real email
  address — an owner decision, not an engineering one.
- **A date, and a change history.**

**Terms.** Apple applies its standard EULA by default and does not require a
custom one for a non-subscription app. But the app has a **Terms** row in
Settings, so either the page exists or the row goes. Given the medical boundary,
a short terms page is worth having anyway, if only to carry the "not a medical
device, not medical advice" statement in a place a lawyer can point at.

**Support URL.** Also required by App Store Connect, and it must resolve. See
§4.4 for what it has to say on day one.

---

### B7. The in-app purchase cannot load — the identifier does not match

`HopPotty/Services/Purchases/PurchaseService.swift:27`:

```swift
case familyUnlock = "com.hoppotty.family.unlock"
```

Everything else says `com.hoppotty.family`:

- `Config/Base.xcconfig`: `HOPPOTTY_IAP_FAMILY_PRODUCT_ID = $(HOPPOTTY_APP_BUNDLE_ID).family`
- `HopPotty/Resources/HopPotty.storekit`: `"productID": "com.hoppotty.family"`
- `HopPotty/App/Info.plist`: `HPFamilyUnlockProductIdentifier` = the xcconfig value
- `Docs/ProductRequirements.md` §9

Consequences: `Product.products(for:)` returns an empty array, the paywall goes
to its `.unavailable` phase forever, `purchase()` returns `.productUnavailable`,
and `refreshEntitlements()` can never match a transaction — so even a family who
paid stays locked. In review this reads as "the in-app purchase does not work",
which is a Guideline 2.1 rejection.

Two further notes for whoever fixes it:

- `Scripts/verify-config.sh` does **not** catch this. It compares the xcconfig
  to the `.storekit` file and stops there; it never looks at the Swift literal.
  Extending it to check the Swift source too would close the gap permanently.
- The `Info.plist` key `HPFamilyUnlockProductIdentifier` is documented as being
  "read at runtime by the purchases layer so the identifier is configured in
  exactly one place" — and **nothing in the Swift code reads it.** Wiring the
  service to that key is the fix that makes the comment true and makes the drift
  impossible.

Recommendation only; the Swift file belongs to another agent.

---

### B8. The Screen Time loop has never run

Not an Apple requirement — a judgement about what it is defensible to ship. The
app's headline feature takes a child's games away and gives them back. If it
fails to give them back, the failure is a four-year-old holding a device that
will not open anything, and a caregiver with no idea why.

Today nothing about that loop has been observed: `Docs/PhysicalDeviceQA.md`
carries the whole plan with an empty **Observed** column, and
`Docs/ScreenTimeArchitecture.md` §12 carries **nine numbered questions about
Apple behaviour that Apple does not document** — including whether shield
settings survive a reboot, how punctual the interval-end callbacks are, and
whether `ApplicationToken` expires — with shipping code already depending on the
answers.

The specific scenarios that must pass on hardware before submission are already
enumerated in `Docs/ReleaseChecklist.md` §6. The load-bearing ones are
force-quit mid-pause, reboot mid-pause, authorization revoked mid-pause, and the
caregiver's emergency **Restore Screen Access**.

---

## 2. Required before submission — you will be rejected without these

### 2.1 The paywall sells things that are not gated, and one thing that does not exist

`PaywallFeature` advertises five unlocks: additional children, the full pond
collection, detailed insights, custom routines, and data export.

Only one is enforced anywhere in the app. `ParentEnvironment.canAddChild` checks
`ParentEntitlement.freeChildLimit`; that is the entire entitlement logic in the
codebase. Nothing checks the entitlement before showing insights, before
exporting, or before the pond. And **custom routines do not exist** — there is
no routine editor, no "choose the steps and how long each one lasts" surface,
nothing. The string is the whole feature.

This is a Guideline 2.1 and 3.1.1 problem before it is a product problem: an
in-app purchase whose advertised features either already work without paying or
have no implementation is a rejection, and outside the App Store it is a
consumer-protection question about what $19.99 buys.

Three honest ways out, in order of preference:

1. **Cut the list to what is real and gated.** Additional children (already
   enforced) plus data export (implemented in
   `HopPotty/Services/Persistence/DataExport.swift`; needs an entitlement check
   at its entry point). Sell two things that work rather than five that do not.
2. **Build the missing gates**, and build the routine editor. More work, and it
   adds a feature nobody has asked for yet.
3. **Change the model.** If the honest answer is "everything is free and the
   unlock is a way to support the app", say that — but then it is a tip jar, and
   Apple has rules about how those are presented.

This needs an owner decision before any code moves.

### 2.2 Store assets that do not exist yet

Everything in this table is missing. None of it can be produced without a Mac
and a running app.

| Asset | Requirement | State |
| --- | --- | --- |
| **App icon** | 1024×1024 in the asset catalog, opaque, no alpha (plus the declared dark/tinted variants) | **Missing** — see B4a |
| **iPhone screenshots** | App Store Connect currently takes a single 6.9-inch iPhone set and derives smaller sizes; up to 10 per localization. **Verify the required sizes at submission — Apple has changed them repeatedly** | **None.** Everything in `Art/render/screens` is a design render from the token export, not a screenshot of a running app, and `Art/render/` is git-ignored |
| **iPad screenshots** | Required because `TARGETED_DEVICE_FAMILY = 1,2`. Currently a 13-inch set | **None** |
| **App preview video** | Optional. Up to three per localization, 15–30s, captured from a device | **None.** Worth having: this product is a 20-second loop that is hard to describe and obvious to watch |
| **App name / subtitle** | 30 characters each | Not drafted |
| **Promotional text / description / keywords** | 170 / 4000 / 100 characters | Not drafted |
| **Support URL** | Required, must resolve | **Missing** — see B6 |
| **Marketing URL** | Optional | Missing |
| **Privacy policy URL** | Required, must resolve | **Missing** — see B6 |
| **Copyright, primary/secondary category** | Health & Fitness / Education per §3 | Decided, not entered |
| **Age rating questionnaire** | Answered per §2.3 | Not answered |
| **Export compliance** | `ITSAppUsesNonExemptEncryption = false` is already in `Info.plist`, which suppresses the per-upload question | **Done in code.** Re-confirm each release: adding any custom cryptography makes that declaration false, and a false declaration to Apple is not a small thing |
| **Content rights / advertising identifier questions** | "No third-party content", "does not use the Advertising Identifier" | Not answered |
| **App Store Connect app record + the IAP** | The non-consumable must exist, be priced, have Family Sharing on, be **Ready to Submit**, and be **attached to this version** | Not created |

Two things about screenshots specifically, for an app in this category:

- **The first screenshot should be the caregiver dashboard, not the frog**
  (`Docs/AppReviewStrategy.md` §2.3). It is what tells a parent, and a reviewer,
  who the app is for.
- **No real child's data may appear.** Use `HopPottyFixtures` — Maya and Sam are
  invented by construction.
- Screenshots must show the shipping UI. Substituting design renders for real
  screenshots is a Guideline 2.3.3 problem, and here it would also be a lie: the
  renders show illustrations the app currently cannot draw (B4b).

### 2.3 Age rating and the questionnaire

**Target: 4+.** Nothing in the content is above it: no violence, no mature
themes, no user-generated content, no unrestricted web access, no messaging, no
gambling, no third-party ads.

Two answers deserve deliberate thought rather than a reflex:

- **Medical / treatment information: None.** This is the right answer and it is
  the one `Docs/MedicalBoundary.md` earns. HopPotty describes a log; it never
  interprets it, never names a condition, never advises. If anyone is tempted to
  answer otherwise "to be safe", read §3 and §4 of that document first — the
  answer follows from the enforced language policy, not from the subject matter.
- **In-app purchases: yes**, and Apple asks about them separately from content.

**Unverified:** Apple rebuilt the age-rating questionnaire in 2025 (new bands,
new capability questions) and required existing apps to re-answer it. This
document does not have a fresh read of the current question set. Answer from the
app's actual behaviour, question by question, and do not copy answers from
another app.

### 2.4 EU distribution: trader status

Apple requires developers distributing in the EU to provide trader contact
details (legal name, address, phone, email) in App Store Connect, and displays
them publicly on the product page. Apps without it cannot be distributed in the
EU.

**Partially unverified** — the exact deadline and enforcement state have moved
since this was introduced under the Digital Services Act. What is certain enough
to plan around: **if you intend to sell in the EU, an individual developer's
home address and phone number may become public**, and that is a decision to
make before submission, not after. Check the "Business" section of App Store
Connect early.

### 2.5 App Review notes and the demo path

`Docs/Entitlements.md` §5 and `Docs/AppReviewStrategy.md` §6 carry the drafted
note. Before it is pasted in, four things must be true of the shipped build:

1. The stated **default pause duration** matches what actually ships.
2. The **demo caregiver passcode** is filled in and verified on a clean install.
3. The sentence about the **Simulator** is either verified on a Simulator or
   removed. `Docs/Entitlements.md` §5 currently asserts "Family Controls does not
   function in the Simulator" while §4 marks the same claim UNVERIFIED. **Do not
   submit a note containing a claim the repository flags as unverified.** The
   safe wording is the one already in `AppReviewStrategy.md` §5.1: recommend a
   physical device, and say nothing about the Simulator either way.
4. The reviewer is told that Screen Time authorization requires a device signed
   into iCloud with a passcode set — otherwise the authorization sheet cannot
   complete and the reviewer concludes the feature is broken.

And the note must never mention the Potty Pause Lab, which is Debug-only by two
independent mechanisms and must not exist in a Release binary.

### 2.6 Guideline walk — the ones that actually bite

| Guideline | How it applies here | Standing |
| --- | --- | --- |
| **1.3 Kids Category** | Governs the category and its age bands. HopPotty is not entering it (§3), but a reviewer may still read the app as kid-directed | Low risk once §3 is recorded and the positioning is consistent |
| **5.1.4 Kids apps** | Applies to apps **primarily intended for children regardless of category**: COPPA/GDPR compliance, a privacy policy, and a parental gate in front of commerce, external links and consequential actions | **Already satisfied by architecture** — every purchase, every destructive action, every external link and the entire Parent Space sit behind `hopParentGated`. The gate (press-and-hold plus a two-digit sum, or Face ID/passcode) is the kind Apple accepts. **Blocked only by B6:** the privacy policy must exist |
| **2.1 App Completeness** | The reviewer must be able to see the feature work | **The live risk.** Today: placeholder art everywhere (B4b), an IAP that cannot load (B7), a paywall selling a feature that does not exist (2.1 above). "Start a pause now" exists specifically so a reviewer can see the loop in under a minute — keep it |
| **2.3.1 Hidden features** | Debug surfaces in a shipping binary | Two mechanisms guard the Lab; `EXCLUDED_SOURCE_FILE_NAMES` spelling is UNVERIFIED (`Docs/SecurityReview.md` §7) and must be checked on the first Release build |
| **2.5.1 / 2.5.2** | No private APIs, no downloaded executable code | Clean. Zero third-party runtime dependencies |
| **2.5.4** | Background modes must be justified | `UIBackgroundModes` is deliberately absent; DeviceActivity is the sanctioned mechanism |
| **3.1.1 In-app purchase** | All digital unlocks through IAP; a restore path; no external purchase links | Correct by design: StoreKit 2, `Product.displayPrice` only, restore implemented, purchase behind the parent gate. **Blocked by B7 and 2.1** |
| **4.2 Minimum functionality** | Perceived thinness | Not a real risk — routine, insights, rewards, eight games, quizzes, widget, Live Activity, multi-child |
| **5.1.1 Data collection and storage** | The privacy label must match reality; permission requests must be justified | "Data Not Collected" is a statement of fact here. The Family Controls authorization prompt is system copy and needs no usage-description string — `Info.plist` says so and marks it UNVERIFIED |
| **5.1.2 Data use and sharing** | No sharing without consent | Nothing is shared; there is nowhere to share it to |
| **1.4.1 Physical harm** | Medical claims | Enforced in code by `InsightLanguagePolicy` and the copy scanners. **Extend the discipline to the App Store listing:** the description and screenshots may not describe HopPotty as tracking, monitoring or improving a child's health outcome (`Docs/MedicalBoundary.md` §7) |
| **2.3.3 / 2.3.7** | Screenshots must show the app; metadata must be accurate | See §2.2 |

---

## 3. The Kids Category decision — resolved

> **Decision: HopPotty ships as a 4+ app with Health & Fitness as its primary
> category and Education as its secondary. It does not enter the Kids Category.**
> Recorded 2026-09-02, adopting the analysis in `Docs/AppReviewStrategy.md` §2.
> `Docs/ReleaseChecklist.md` §10 has been corrected to match.

This resolves the open conflict flagged in `BUILD_STATUS.md`, where
`AppReviewStrategy.md` recommended 4+ Health & Fitness and `ReleaseChecklist.md`
presumed the Kids Category.

**What the Kids Category would cost.** In App Store Connect, "Kids" is itself a
primary category with a mandatory age band (5 and under / 6–8 / 9–11). Choosing
it therefore *replaces* Health & Fitness as the primary category and moves the
app out of the place a parent searching for a potty-training aid actually looks.
It also brings the Guideline 1.3 rules: no third-party analytics, no third-party
advertising, no transmission of personally identifiable information to third
parties, and a parental gate in front of commerce and external links.

**What it would buy.** Placement in the Kids tab, browsable by age band, and a
trust signal that Apple has applied stricter rules.

**Why the answer is no.**

1. **The rules cost nothing because the app already exceeds them** — no
   analytics, no ads, no third parties, no network path at all, and every
   commercial or consequential action already gated. So the badge buys signalling,
   not protection.
2. **The protections arrive anyway.** Guideline 5.1.4 applies to apps primarily
   intended for children *regardless of category*. HopPotty must behave as a
   kid-directed app either way, and it does.
3. **The app is not primarily for the child, and the age band proves it.** The
   caregiver configures the schedule, reads the patterns, holds every destructive
   action and makes the purchase. The child's surface is deliberately narrow and
   reached by an adult handing the device over. No age band describes "operated by
   an adult, used by a two-year-old", and picking one misdescribes the app in the
   one process where being misdescribed is most expensive.
4. **Kids badge plus Family Controls entitlement is an unusual pairing.** A Kids
   app that shields other apps is a parental-controls app wearing a children's
   badge. The entitlement approval (B1) is already the highest-risk gate in the
   project; do not add an unusual signal to it.
5. **Asymmetry of reversibility.** The category is metadata and can be changed in
   a later version at the cost of a fresh review. A refused entitlement, or a
   review that concludes the app misrepresents its audience, is far more
   expensive.

**What this decision does not license.** 4+ Health & Fitness is not an escape
from kid-directed obligations. The parental gate stays in front of every
purchase, every external link and every destructive action; there are no ads and
no analytics; the privacy policy is mandatory; and the app remains COPPA-clean
by having nothing to collect. The category changes where the app is listed, not
how it behaves.

**Revisit if:** the product ships a child-only mode families install *for the
child*; caregiver research shows the Kids tab is the real discovery path; or
Apple's guidance changes so a parental-controls app can carry the badge without
ambiguity.

---

## 4. Legal, product and the parent-facing promise

### 4.1 The medical boundary holds — check the listing, not the code

`Docs/MedicalBoundary.md` is unusually strong: the forbidden-language lists are
enforced by tests over the *complete* output set of the insight engine,
`disclaimerRequired` is a constant that cannot be false, and nothing
user-written is ever interpolated into an insight. The copy scanner has already
caught real shame language in first-draft copy. Verified as far as it can be
verified without a build.

The gap is outside the code: **the App Store listing, the screenshots, the
website and the marketing copy are not covered by any test.** A description that
says "improves your child's toileting outcomes" or "track your child's bladder
health" would undo the whole document and put the app near Guideline 1.4.1.
Whoever writes the listing should read `MedicalBoundary.md` §3 and §4 first, and
the same forbidden vocabulary should be applied to it by hand.

### 4.2 COPPA, GDPR-K and the UK Children's Code

With no collection, no transmission and no third party, the compliance surface
is the device itself:

- **COPPA.** The rule governs operators that collect personal information from
  children under 13 online, including persistent identifiers. HopPotty collects
  none and transmits none, so verifiable parental consent is not required —
  because there is nothing to consent to. This should be stated plainly in the
  privacy policy rather than left to be inferred. Note that the FTC amended the
  COPPA Rule in 2025; the amendments principally tighten third-party disclosure
  consent, data retention and security-programme requirements, none of which bite
  on an app with no collection. **Partially unverified** — confirm with counsel
  if the product ever adds a support email flow, a crash reporter, or sync.
- **GDPR / GDPR-K (Art. 8).** No personal data reaches the developer, so the
  developer is not processing it. The policy still has to name the legal entity,
  its jurisdiction, and a contact route.
- **UK Age Appropriate Design Code.** Applies to services likely to be accessed
  by children that process personal data. The processing here is local and
  developer-inaccessible; a short conformance statement in the policy ("data
  minimisation by architecture: nothing leaves the device") is cheap and
  appropriate.

None of this is legal advice, and the entity naming and jurisdiction questions
are an owner decision.

### 4.3 What the privacy policy must say

See B6 — the full content list is there, derived from the data inventory in
`Docs/PrivacyArchitecture.md` §2. The three items most often forgotten, and most
relevant to a suspicious parent, are: **the App Group and SwiftData containers
are included in device backups** (the one way data leaves the device, at the
family's own direction); **the Screen Time selection is stored as opaque Apple
tokens the developer cannot read**; and **OSLog entries can be collected into a
sysdiagnose** — which is exactly why nothing identifying is ever logged.

### 4.4 The support page has one job on day one

`Docs/ReleaseChecklist.md` closes by asking: *if a family reports their child's
apps are stuck, what do we tell them tonight?* The answer today is "delete
HopPotty" — removing the app removes its `ManagedSettings` store, and the child's
apps come back.

**That sentence must be on the support page before the first release, not after
the first report**, and it should be findable without an account, without a
search, and without reading anything else. Ideally it is also reachable *inside*
the app, since a parent whose child's device is shielded may be holding the
device that cannot open a browser tab comfortably.

---

## 5. Engineering gaps that block shipping

Distinguished from polish: each of these changes what you can honestly claim
about the build.

| Gap | Why it blocks | Effort |
| --- | --- | --- |
| **No accessibility audit has ever been executed** | `Docs/Accessibility.md` §3 is a written checklist with every box open. Contrast is genuinely enforced by tests; VoiceOver labels, Dynamic Type at AX5, Switch Control, focus order and Reduce Motion are all unrun. `performAccessibilityAudit` in XCUITest gets the mechanical half cheaply once the app builds | 2–3 days after B3 |
| **No Instruments profiling** | The Shield Configuration extension is on a hard clock: too slow and iOS renders Apple's default shield with Apple's copy instead of yours. That is a user-visible copy failure the app cannot detect, and the only way to know the margin is to measure it on a device. The monitor extension's real memory ceiling is one of the nine open unknowns | 1 day, device |
| **StoreKit never exercised** | The `.storekit` file has never been loaded; sandbox purchase, restore, Ask-to-Buy `pending`, and restore-on-a-second-device are all untested paths in code that has never compiled. Fix B7 first or every test fails identically | 1 day, needs sandbox accounts |
| **No CI builds the iOS target** | CI runs `HopPottyKit` tests on Linux and `verify-config.sh`. It cannot compile a single SwiftUI file. Until a macOS runner exists, a green tick says the domain logic is sound and nothing about the app | Half a day once a Mac runner is available |
| **English only** | No `.lproj`, no `.strings`, no String Catalog; `HopPotty/Resources/Localization/` is an empty directory. Copy lives in `HopCopy` as Swift constants routed through `.localized`, and `SWIFT_EMIT_LOC_STRINGS = YES` is set, so the structure is there and the extraction is not. 426 copy entries plus 31 voice lines. Not a submission blocker — English-only apps ship every day — but for a 2–5-year-old product in a global market it is the largest single growth constraint, and retrofitting it after launch costs more | 1–2 weeks per language including review of child-facing tone |
| **No crash visibility** | Deliberate (see §7) but it has a cost: the first field crash will be invisible unless someone reads Xcode Organizer. Use it — Apple's own crash reports come through the Organizer, involve no SDK, no third party and no change to the privacy label | Nothing to build; a habit to adopt |
| **`DataExportProviding` sanitisation unverified** | `Docs/SecurityReview.md` §5 requires per-export sequential child labels instead of raw UUIDs and CSV formula-injection neutralisation. The service exists; those two properties have never been tested | Half a day |
| **Data Protection class never confirmed** | The SwiftData store and App Group files rely on the default class. `Docs/SecurityReview.md` finding #1 asks for an explicit class, verified on device | Half a day |
| **`EXCLUDED_SOURCE_FILE_NAMES` spelling unverified** | It is the second of two mechanisms keeping the debug Lab out of Release. Verify by deleting a `#if` guard in a Lab file and confirming Release still builds | 1 hour |

---

## 6. What the app is missing as a product

Judged as a caregiver would judge it, not as a checklist. These are genuine
holes, not invented scope.

**1. Hop has no voice, and the audience cannot read.**
All 31 voice lines are `.planned`. There are no audio files in the repository at
all — no voice, no sound effects, no ambient bed. `AudioService` degrades
explicitly to captions, and the architecture around that is careful and correct.
But the user is two to five years old and pre-literate: a caption is not a
degraded delivery for them, it is no delivery. The child-facing routine is
designed around a character who speaks and currently says nothing. Three
Settings toggles (voice, effects, ambient) would control nothing, which is its
own small Guideline 2.1 problem — either the audio ships or those rows go.
**This is the biggest product gap in the app**, and unlike most items here it
needs casting and recording, not engineering.

**2. Everything must be done on the child's device.**
Family Controls is device-local: the caregiver configures the schedule, reads
the timeline and manages the purchase on the same device the child uses. There
is no companion app on the parent's phone and, given Apple's APIs, no
straightforward way to build one. Caregivers will expect otherwise. Say so in
the App Store description and in onboarding rather than letting a parent
discover it after buying.

**3. One caregiver, one device, no sync.**
No account means two parents cannot both see the timeline, and a new device
starts empty unless restored from an iCloud device backup. Both are deliberate
and documented (`Docs/PrivacyArchitecture.md` §3 calls the trade out explicitly),
and both will generate support mail. The mitigation is expectation-setting, not
architecture: say it in onboarding, in the description and on the support page.

**4. No in-app help.**
Three Settings rows link out to a domain that does not exist. There is no FAQ, no
troubleshooting, and — most importantly — no in-app answer to "my child's apps
are stuck". See §4.4.

**5. The training vocabulary is narrow.**
Four event kinds (tried / pee / poop / accident). Families mid-training commonly
want to record night-time and nap-time separately, and many potty-training
regimes revolve around fluid intake and timing. Nothing here is required for a
v1 — and the medical boundary rightly limits how far this can go — but a
caregiver two weeks into training may find the log thinner than their situation.
Worth a deliberate "not in v1" rather than an oversight.

**6. Nothing leaves the app that a family would want to keep.**
The pond is lovely and lives only on one device. There is no printable reward
chart, no shareable "Maya's first dry week" card, no photo of the pond to send a
grandparent. Export produces JSON. For a milestone product, an artefact a family
can keep is the natural emotional endpoint, and it is missing. (Anything added
here must stay behind the parent gate and must not become a sharing or social
feature — see `Docs/ChildSafety.md`.)

**7. No quick capture for a parent whose hands are full.**
Logging a visit requires opening the app and passing the gate. An App Intent, a
Control Center control, a Lock Screen widget button or a Siri phrase would fit
this product exactly. The widget already exists and shows the countdown; it
cannot record anything.

**8. Nothing tells a family what to expect on day one.**
The app has insights that deliberately refuse to advise, which is right. But
between "here is your log" and "we cannot tell you anything" there is room for
plain, non-clinical, non-prescriptive orientation — what a potty-training week
usually looks like, why accidents are normal, why the app never punishes one.
That is content, not analysis, and it does not cross the medical boundary if
written as general information rather than as a claim about *this* child.

---

## 7. Deliberate omissions

Things a reviewer, a parent or a new engineer might expect to find and will not.
Every one is a decision with a reason, not a gap. This table is worth keeping
current: it is the difference between "they forgot" and "they decided".

| Omitted | Reason |
| --- | --- |
| **Analytics of any kind** | No Firebase, Amplitude, Segment, Mixpanel or successor. The app has zero third-party runtime dependencies and no network path carrying family data, which is what makes "Data Not Collected" a fact rather than an interpretation (`PrivacyArchitecture.md` §1) |
| **Third-party crash reporting** | A crash reporter that transmits is a network path out of a children's app. Apple's own Organizer reports are the substitute, and they cost the family nothing |
| **Advertising, IDFA, house ads, cross-promotion** | None, at any age rating. `NSUserTrackingUsageDescription` is deliberately absent because there is nothing to ask for |
| **An account, a login, a profile** | Onboarding never asks who you are. Nothing to breach, nothing to subpoena, nothing to leak |
| **iCloud / CloudKit sync** | The reward ledger and potty timeline are the most sensitive data in the app. Kept on-device until there is an explicit, gated, per-family opt-in. Cost accepted: no cross-device sync (`PrivacyArchitecture.md` §3) |
| **Push notifications** | No push entitlement. All three notification kinds are local, and there is no "come back" notification by contract |
| **The Family Controls App and Website Usage entitlement** | Would hand the app real bundle identifiers and domain names instead of opaque tokens. HopPotty needs to shield a selection, not to know what is in it. Declining it keeps the privacy surface small (`Entitlements.md` §1) |
| **A URL scheme / universal links** | A parental-controls app that can be driven from a link is one a child can drive |
| **Streaks, daily-login rewards, randomised rewards, loot** | `ChildSafety.md` §1. The pond is a published price list: 41 items, fixed prices, same order for every child. There is no streak to break and nothing a child has can ever be taken back |
| **Leaderboards, sibling or population comparison** | No comparison of any kind. "average child" is on the forbidden-language list |
| **Scores, timers or failure states in the mini-games** | Eight games, none of which can be lost |
| **Any medical claim, threshold, red flag or symptom checker** | `MedicalBoundary.md`. The referral pointer is unconditional and never triggered by data |
| **HealthKit** | The app would have to claim its data is clinically meaningful to justify writing there. It is not |
| **Rewarding outcomes rather than effort** | `.tried`, `.pee` and `.poop` all earn the same single star; `.accident` earns nothing and cannot reach the reward path at all |
| **A child-visible purchase surface, price or external link** | Child Space does not contain them — not hidden, absent |
| **The Kids Category** | §3 |
| **Mac Catalyst, "Designed for iPad" on Mac, visionOS** | Family Controls authorization fails outright on visionOS and the Screen Time frameworks do not exist on macOS. Shipping either would ship a build whose headline feature cannot work |
| **A DeviceActivityReport extension** | HopPotty reports on its own log, not on the device's app usage. Adding one would mean reading usage data the app has no use for |
| **Background modes beyond DeviceActivity** | DeviceActivity is the sanctioned mechanism; anything else invites App Review questions with no good answer |
| **A remote kill switch, feature flags, remote config, remote content** | Everything ships in the bundle. Nothing about the app can change without a review |

---

## 8. A realistic sequence from today to submission

Markers: **[Now]** possible in this repository today · **[Mac]** needs a Mac with
Xcode · **[$]** needs a paid Apple Developer account · **[Apple]** waits on
Apple · **[Decide]** needs a human decision, not work.

### Phase 0 — Decisions and paperwork (parallel with everything; start today)

1. **[Decide]** Confirm the Kids Category decision in §3. *(Recorded; needs the
   owner's assent, not new analysis.)*
2. **[Decide]** Choose the real reverse-DNS bundle prefix and buy the matching
   domain. Everything downstream — App IDs, the App Group, the IAP identifier,
   the legal URLs — depends on it.
3. **[Decide]** Resolve what the $19.99 actually unlocks (§2.1). This gates code,
   copy and the App Store Connect product.
4. **[Decide]** Name the legal entity and the support email for the privacy
   policy and, if selling in the EU, the trader details (§2.4).
5. **[Now]** Write the privacy policy, terms and support page (B6, §4.3, §4.4).
   All the source material is in `Docs/PrivacyArchitecture.md` §2.
6. **[Now]** Fix the IAP identifier mismatch (B7) — ten minutes, and it unblocks
   every purchase test later.
7. **[Now]** Draft the App Store description, subtitle and keywords, checked
   against `MedicalBoundary.md` §7 for accidental health claims.

### Phase 1 — Account and the long pole (day one of having money)

8. **[$]** Enrol in the Apple Developer Program.
9. **[$]** Register the five App IDs and the App Group; enable Family Controls
   on the four that need it (`Entitlements.md` §3 has the checklist).
10. **[$][Apple]** **Submit the Family Controls distribution request for all four
    App IDs the same day.** Do not wait for the app to build. Attach or link a
    screen recording of the loop as soon as one exists.
11. **[$]** Create the App Store Connect record and the `…family` non-consumable:
    $19.99, Family Sharing on, identifier matching `Config/Base.xcconfig` exactly.

### Phase 2 — Make it compile (the first Mac day)

12. **[Mac]** `Scripts/bootstrap.sh`; fix XcodeGen schema issues; generate the
    project.
13. **[Mac]** First compile pass across the app and four extensions. Expect Swift
    6 concurrency diagnostics and SwiftData schema errors.
14. **[Mac]** Run the `HopPotty-Mock` scheme in the Simulator end to end:
    onboarding → schedule → simulated pause → routine → star → pond.
15. **[Mac]** Verify **Gentle mode** is a complete, coherent product with no
    shielding — it is the fallback if B1 is refused.
16. **[Mac]** Write and run the app-layer tests listed in `QATestPlan.md` §3.1.

### Phase 3 — Make it look like the renders

17. **[Mac]** Build the SVG → asset-catalog export step; populate all 65
    illustration keys; make `check-art.sh` assert the bundle, not the source
    (B4b).
18. **[Mac]** Export the app icon at 1024×1024 in its three appearances (B4a).
19. **[Decide]** Commission voice and sound, or cut the audio toggles (§6.1).

### Phase 4 — The device (needs Phase 1's App IDs, not Apple's approval)

20. **[Mac][$]** Development-signed build on a real device with real Family
    Controls authorization.
21. **[Mac][$]** Work `Docs/PhysicalDeviceQA.md` top to bottom and fill in the
    **Observed** column. Answer all nine unknowns in
    `ScreenTimeArchitecture.md` §12 and write the answers back with the date and
    OS version.
22. **[Mac][$]** The `ReleaseChecklist.md` §6 safety scenarios: force-quit,
    reboot, revoked authorization, clock moved backwards, emergency restore.
23. **[Mac][$]** Instruments on the Shield Configuration extension; proxy capture
    to prove the "no network traffic carrying family data" claim.
24. **[Mac][$]** StoreKit sandbox: purchase, restore, Ask-to-Buy, restore on a
    second device.
25. **[Mac]** Accessibility audit executed against the running app
    (`Accessibility.md` §3).

### Phase 5 — Submission mechanics

26. **[Mac]** Add `PrivacyInfo.xcprivacy` to the app and each extension (B5).
27. **[Mac]** Capture screenshots at the required sizes from the running app, on
    both iPhone and iPad, using fixture data only.
28. **[Now]** Complete App Store Connect: metadata, categories, age-rating
    questionnaire, privacy nutrition label ("Data Not Collected" throughout),
    content rights, advertising identifier, trader status.
29. **[Now]** Paste the App Review note; fill in the demo passcode; remove the
    unverified Simulator sentence.

### Phase 6 — TestFlight (gated on Apple)

30. **[Apple]** Wait for the entitlement. TestFlight is gated on it, not just the
    App Store.
31. **[Mac]** Archive Release, inspect it per `ReleaseChecklist.md` §5, upload.
32. **[Mac]** Install from TestFlight on a device that has **never** had a
    development build — a distribution-signed extension that fails to launch is
    invisible on a device that already trusts a development one.
33. **Repeat every Phase 4 safety scenario on the TestFlight build.** Development
    and distribution signing are different entitlement paths.
34. Real families, if you can get them. Nothing in this document substitutes for
    watching a three-year-old meet the shield.

### Phase 7 — Submit

35. Work `Docs/ReleaseChecklist.md` from the top. It is the per-build ritual and
    it assumes everything above is done.

**The critical path is B1 → Phase 6.** Everything else can be worked in
parallel, and most of it can start before there is a Mac in the room.

---

## 9. What this document is not sure about

Stated plainly, because a confident wrong answer about a submission requirement
costs a review cycle.

1. **The Family Controls review turnaround.** Apple publishes none. The failure
   modes in B1 are developer-reported, not Apple-documented.
2. **The exact privacy-manifest reason codes.** CA92.1, C617.1 and 35F9.1 are
   given from memory of Apple's required-reason API page. The categories are
   certainly right; verify the code strings against the live page.
3. **Whether every app extension needs its own privacy manifest**, or whether the
   app's covers the bundle. Adding one per extension is the safe reading.
4. **The current screenshot sizes.** Apple has changed these repeatedly and now
   derives smaller sizes from one large set. Read App Store Connect on the day.
5. **The 2025 age-rating questionnaire's current question set.**
6. **EU trader-status deadlines and enforcement**, and exactly what becomes
   public for an individual developer.
7. **The minimum SDK for new submissions.** Apple raises it roughly annually
   (the iOS 18 SDK became the floor in April 2025). `README.md` claims Xcode 16;
   expect a newer floor by the time you submit and check before buying a plan
   around an old Xcode.
8. **Whether Family Controls functions in the iOS Simulator.** Undocumented by
   Apple and unverified here — which is precisely why it must not appear as an
   assertion in the App Review note.

---

## 10. Related documents

| Document | What it owns |
| --- | --- |
| `Docs/ReleaseChecklist.md` | The per-build submission ritual, top to bottom |
| `Docs/Entitlements.md` | Capabilities, provisioning, the entitlement request, the App Review note draft |
| `Docs/AppReviewStrategy.md` | Positioning, the category analysis, the reviewer's fast path |
| `Docs/PrivacyArchitecture.md` | The complete data inventory the privacy policy is written from |
| `Docs/MedicalBoundary.md` | What the app may and may not say about a child's body |
| `Docs/ChildSafety.md` | The ten commitments and the language rails |
| `Docs/PhysicalDeviceQA.md` | The device plan, with an empty Observed column |
| `Docs/QATestPlan.md` | Where the tests are and what green means |
| `Docs/SecurityReview.md` | Threat model and the open security findings |
| `Docs/ScreenTimeArchitecture.md` §12 | The nine open questions about Apple's behaviour |
| `BUILD_STATUS.md` | What has and has not been verified, today |
