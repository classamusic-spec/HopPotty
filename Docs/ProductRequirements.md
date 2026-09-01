# Product Requirements — MVP

**Date:** 2026-09-01
**Companion documents:** `ProductVision.md` (why), `InformationArchitecture.md`
(where), `UserFlows.md` (how), `CONTRACTS.md` (the rules that outrank this file).

Where a requirement is already implemented in code, the type is named. Where it
is not, it says so.

---

## 1. MVP definition in one paragraph

A caregiver sets up one child, chooses how HopPotty interrupts, picks the apps a
pause covers, and gets a repeating Potty Pause with quiet hours. The child sees a
branded shield, taps through to a guided routine, earns a star for trying, and
watches a pond grow. The caregiver gets a timeline, descriptive patterns, an
export, a delete, and one optional purchase. Everything is on-device.

---

## 2. The three modes

`PottyPauseMode` — `HopPottyKit/Sources/HopPottyCore/Models/PottySchedule.swift`

| Mode | Shields apps? | Needs Family Controls? | What the child sees |
| --- | --- | --- | --- |
| **Gentle** | No | No | A local notification and, if HopPotty is open, an in-app cue. Nothing is ever blocked. |
| **Pause** | Yes | Yes | The shield, then the Potty Pause screen: one invitation, one big button, a star. |
| **Routine** | Yes | Yes | The same, then Hop walks the five-step guided routine. |

Rules:

- Gentle is the default and the fallback. If authorization is denied, revoked or
  restricted, HopPotty keeps working in Gentle and says so — it never silently
  degrades (`ParentErrorPresentation.appStillUseful`).
- Mode is per child, on `PottySchedule`.
- No mode can extend a pause. `shieldsApps` changes what is *applied*, never how
  a pause *ends*.

---

## 3. The timer system

### 3.1 What starts the countdown — `PottyTriggerBasis`

| Basis | Fires on | Needs an app selection |
| --- | --- | --- |
| `screenActivity` | Accumulated foreground use of the selected apps, reported by `DeviceActivity`. | Yes |
| `clockTime` | Wall-clock cadence across the active window, regardless of device use. | No |

They are never mixed. A family that wants "every 45 minutes of iPad" and one that
wants "every hour in the afternoon" want different behaviour.

### 3.2 Intervals and bounds — `PottyInterval`, `PottySchedule`

| Setting | Default | Bounds | Constant |
| --- | --- | --- | --- |
| Interval | 45 min | presets 15/20/30/45/60/90; custom 10–240 | `PottyInterval.customRange` |
| Warning offset | 120 s | 0 (off) … interval − 60 s | `effectiveWarningOffset` |
| Pause duration | 180 s | 60–600 s, clamped again at the context boundary | `minimumPauseDuration` / `maximumPauseDuration` |
| Cooldown | 300 s | ≥ 0 | `PottySchedule.cooldown` |
| Active window | 07:00–19:30 | wall clock, `LocalTimeOfDay` | — |
| Active days | every day | empty set normalises to every day | — |

### 3.3 Quiet windows — `QuietWindow`, `PottyScheduleService`

- Labels: nap, bedtime, school, mealtime, custom. Label changes the icon and the
  sentence, never the behaviour.
- Half-open `[start, end)`, so a 07:00 wake-up boundary does not suppress a 07:00
  pause. Windows may wrap midnight; day membership follows the *start*.
- Overlap precedence is documented and total: ends latest → started earliest →
  label order → window id. `resumesAt` follows the whole chain of back-to-back
  windows, so nap + lunch resume once.
- Wall-clock membership is computed from components, never from precomputed
  boundary `Date`s, so DST and travel fall out correctly.

### 3.4 Why a pause may not start — `PauseBlockReason`

Strict precedence, one reason reported, so the parent UI is never silent:
`scheduleDisabled` (0) → `suspendedIndefinitely` (1) → `suspendedUntil` /
`suspendedUntilTomorrow` (2) → `inactiveDay` (3) → `outsideActiveWindow` (4) →
`quietWindow` (5) → `cooldown` (6) → `skippingNextPause` (7).

`skipNext` is last on purpose: it is consumed when a pause *would* have fired, so
it must not be spent on a day nothing was going to happen.

### 3.5 How a pause ends

Five independent paths, whichever fires first
(`ScreenTimeArchitecture.md` §9). No path consults an outcome.

| Path | Runs in | Note |
| --- | --- | --- |
| Child taps the shield button | ShieldAction extension | Deterministic |
| `intervalWillEndWarning` at the intended duration | Monitor extension | **UNVERIFIED** punctuality |
| `intervalDidEnd` at +15 min | Monitor extension | Documented backstop; 15 min is Apple's floor |
| Foreground reconciliation | App | Deterministic floor |
| Caregiver override behind the parent gate | App | Never refused, from any state |

---

## 4. Rewards

`HopPottyCore/Rewards/` and `Models/RewardTransaction.swift`.

- **Currency:** Hop Stars. Append-only ledger, never a stored total. Every number
  is summed from rows.
- **Reasons:** `triedThePotty`, `completedRoutine`, `washedHands`,
  `toldAGrownUp`, `completedQuiz`, `completedGame`, `answeredPottyPause`. One
  star each. `tried`, `pee` and `poop` all map to `triedThePotty` — paying more
  for output would make the star a reward for a biological outcome.
- **Accidents earn nothing and cost nothing.** `RewardService.reason(for:)`
  returns `nil` for `.accident`; there is no `RewardReason` case it could map to.
- **Idempotency:** key = `hop.reward.v1|<childID>|<reason>|<scope>`, every
  component derived from already-durable data (`RewardIdempotency`). A crash
  between "event saved" and "star written" produces one star on retry, not two.
  The store enforces it again with `@Attribute(.unique) idempotencyKey`.
- **Deleting an event never removes its star.** Reconciliation breaks the link
  and keeps the row, quantity and key (`RewardService.reconcile`;
  `RewardReconciliation.starsRemoved` is always 0 and is asserted).
- **Pond:** 41 items, fixed prices 3 → 616 stars, published in advance, same
  order for every child on every install. First unlock at 3 stars — reachable in
  one good routine. `PondCatalog`, exhaustive over `PondItemID` at compile time.
- **No randomness, no crates, no timed items, no decay, no expiry, no streaks.**

---

## 5. Games

`MiniGameCatalog` — three games, 30–90 s each, off-switchable per family.

| Game | Ends | Practises |
| --- | --- | --- |
| Bubble Wash | when the board is clear | Makes 20 seconds of scrubbing worth finishing |
| Potty Path | when the board is clear | Rehearses the trip as a small journey with an ending |
| Bathroom Match | when the child taps Done | Vocabulary: soap, towel, paper, flush |

`MiniGameCompletion` has exactly two cases and neither is a loss. No score, no
timer, no failure state. `GameProgress` counts plays, never scores.

---

## 6. Quizzes

`QuizContent` — 17 questions across 7 topics (after-potty order, body signals,
telling a grown-up, what belongs in the toilet, hand washing, wiping, flushing).
Three questions per round (`questionsPerRound`).

- Audio-first: the answer is a picture, because a three-year-old cannot read
  "front to back". Labels exist for VoiceOver and the adult alongside.
- `QuizAnswerOutcome` has `affirm` and `redirect` — **no `wrong`, no score, no
  round-ending failure.** A redirect leaves the options tappable and the question
  open.
- `QuizProgress` records plays and last-played, nothing else.

---

## 7. Insights

`HopPottyCore/Insights/` — descriptive statistics over the family's own log.

| Insight | Minimum sample | Constant |
| --- | --- | --- |
| Typical gap between visits (IQR) | 12 gaps | `minimumGapSamples` |
| Interval *question* to the caregiver | 20 gaps, and ≥10 min from the configured interval | `minimumSuggestionGapSamples`, `minimumSuggestionDeltaMinutes` |
| Participation summary | 3 visits | `minimumParticipationVisits` |
| Time-of-day consistency | 5 days, 5 visits per segment, 0.2 rate gap | `minimumConsistencyDays`, `minimumSegmentVisits`, `minimumConsistencyRateDifference` |
| Longest stretch with no accident recorded | 3 distinct days | `minimumDryStretchDays` |

Rules:

- Below threshold the engine returns `nil`. It never hedges — a hedge on a
  dashboard reads as a finding.
- Entries within 5 minutes collapse into one visit (`visitClusterWindow`);
  minutes are rounded to 5 (`reportingStepMinutes`) because the underlying
  timestamps are "when someone got round to tapping".
- Every insight carries `disclaimerRequired == true` (computed, no setter) and
  the label "Pattern, not medical advice."
- `IntervalSuggestion` is an immutable value with no method that takes a
  `PottySchedule`. It cannot change a family's settings; only a caregiver can.
- Every emitted string is assembled from module constants and integers — no
  nickname or note is ever interpolated — so `InsightLanguagePolicy` is
  enforceable over the *complete* output set.

---

## 8. Multi-child

- `ChildProfile` holds a nickname (optional, ≤24 chars, sanitised at every entry
  point), an illustrated avatar, and a pond theme. No legal name, no birthday, no
  photo.
- Everything child-scoped is keyed by `childID`: schedule, events, ledger, pond,
  quiz and game progress, Screen Time configuration.
- Every child-scoped table conforms to `ChildScopedRepository`, so deleting a
  profile iterates a list rather than nine remembered method names — and a tenth
  table is a compile error, not a leak.
- No query reads across children except `allSchedules()`, which exists to re-arm
  monitoring on launch.
- Free tier: one child (`ParentEntitlement.freeChildLimit`).

---

## 9. Purchases

- One non-consumable, family-shareable: `com.hoppotty.family`, "HopPotty Family",
  $19.99 in the StoreKit test file (`HopPotty/Resources/HopPotty.storekit`).
- Behind the paywall: additional children, the full pond collection, detailed
  insights, custom routines, data export (`PaywallFeature`).
- Free forever: one child, the full routine, every reminder, the Potty Pause
  itself.
- **Nothing a child earned is behind the purchase.** Stated in copy
  (`purchase.freeFooter`) and treated as a product commitment.
- No subscription, no countdown, no expiring discount. `PurchaseOutcome` models
  Ask-to-Buy `pending` explicitly.
- The purchase surface and Restore both sit behind the parent gate.
- Price always comes from `Product.displayPrice`; HopPotty never composes one.

> **Inconsistency to resolve before submission:** the paywall title in `HopCopy`
> is "HopPotty Complete" while the product name in the StoreKit file and
> `Config/Base.xcconfig` is "HopPotty Family". Pick one.

---

## 10. Notifications

Exactly two kinds, both local, no push entitlement:

1. **Warning before a pause** — child-facing wording, default on, offset from the
   schedule.
2. **Daily summary** — caregiver-facing, default **off**, time configurable.

No re-engagement notification of any kind exists or may be added
(`CONTRACTS.md` §4.7).

---

## 11. The 28-point "MVP complete" checklist

A reviewer can walk this in order. Each line is either demonstrable on a device
or points at the file that makes it true. **None of the runtime items has been
executed — there is no Xcode build yet (`BUILD_STATUS.md`).**

### Setup and permission
- [ ] **1.** Fresh install reaches the parent home in ≤6 onboarding steps with no account, no email, no network call.
- [ ] **2.** Declining Screen Time leaves a fully working Gentle-mode app and an honest explanation, not a dead end.
- [ ] **3.** A restricted device (`FamilyControlsError.restricted`) shows the "unavailable here" state and offers no retry that cannot work.
- [ ] **4.** The app picker caps the selection and explains Apple's 50-token limit in caregiver language.

### The pause loop
- [ ] **5.** A pause can be started on demand from the parent home ("Start a pause now").
- [ ] **6.** The selected apps show HopPotty's own shield — colours, copy and Hop's image, not Apple's default.
- [ ] **7.** Tapping the shield's primary button clears the shield and the child lands back on the Home Screen (iOS < 26.5) or in HopPotty (26.5+).
- [ ] **8.** A pause left untouched ends on its own at the configured duration, and at worst at the 15-minute backstop.
- [ ] **9.** Force-quitting the app mid-pause, then relaunching, restores access and records `interruptedByProcessDeath`.
- [ ] **10.** Rebooting the device mid-pause clears the shield the first time the shield extension or the app runs.
- [ ] **11.** "Restore Screen Access" in Settings clears the shield from **every** state, including every error state.
- [ ] **12.** No sequence of taps produces a pause longer than `maximumPauseDuration`.

### Child experience
- [ ] **13.** Every child control is ≥72pt, primary actions ≥96pt, verified with the accessibility inspector.
- [ ] **14.** Every spoken line displays its caption; with no audio bundled, captions are the normal path.
- [ ] **15.** The five-step routine completes inside the default 180-second pause with time to spare.
- [ ] **16.** A child can leave the routine at any step and access is never withheld for leaving.
- [ ] **17.** A star lands for *trying*, with the same celebration whether or not anything was produced.
- [ ] **18.** The pond shows the next item and its exact price; nothing is random and nothing is timed.
- [ ] **19.** Quizzes never end on a wrong answer; a redirect leaves the question open.
- [ ] **20.** Mini-games have no score, no countdown and no failure state.

### Caregiver surfaces
- [ ] **21.** The timeline shows tried / pee / poop / accident with a distinct glyph for each — meaning never carried by colour alone.
- [ ] **22.** An accident can be logged and backdated by a caregiver, and cannot be logged by the child.
- [ ] **23.** Deleting an event shows exact counts first, and the receipt afterwards states that **0 stars were removed**.
- [ ] **24.** Insights are absent below their sample thresholds and every one that appears carries "Pattern, not medical advice."
- [ ] **25.** Export produces a file inside the app container with no network access, and note inclusion is a caregiver choice.

### Commerce and compliance
- [ ] **26.** The paywall, Restore, export and every destructive action sit behind the parent gate; a passed gate expires after 15 minutes.
- [ ] **27.** Purchase, cancel, Ask-to-Buy pending and restore all resolve to a stated outcome, and the free tier keeps one child fully functional.
- [ ] **28.** A Release build contains no debug menu, no mock services and no `HopPotty/Developer/` source (`Release.xcconfig`).

### Gate on the checklist itself
Every item from 5 to 12 requires a physical device and an approved Family
Controls entitlement. Until then they are **unverifiable, not passing** — see
`Docs/PhysicalDeviceQA.md` and `BUILD_STATUS.md`.
