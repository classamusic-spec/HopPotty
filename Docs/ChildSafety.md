# Child Safety

**Date:** 2026-09-01
**Status:** The rules are enforced by executable tests that run today. Two of them
have already caught real copy — see §9.

This document is the complete safety position for a product that talks to a
two-year-old about something they cannot fully control, at the exact moment they
are most likely to feel bad about it. One careless sentence lands on a child who
has no way to argue back.

---

## 1. The ten commitments

1. **Never shame.** No child-facing string says "failed", "wrong", "bad",
   "naughty", "lost", "no stars", "hurry" or "late", and none negates the child's
   effort.
2. **Never punish an accident.** An accident is a neutral timeline fact. It earns
   nothing, costs nothing, and appears in no counter framed as a rate.
3. **Never make screen access contingent on a biological outcome.** No code path
   may keep a shield up because a child did not pee. A pause ends on its timer, on
   completion, or on caregiver override — nothing else.
4. **No engagement mechanics.** No variable reinforcement, no "come back"
   notifications, no daily login rewards, no session-length goals.
5. **No streaks that break.** There is no streak. `QuizProgress` and
   `GameProgress` count plays and can only go up.
6. **No loss aversion.** Nothing a child has is ever shown as at risk. The pond
   cannot shrink; `PondProgressService.apply` unions and never subtracts, even
   when the star total handed to it is *lower* than last time.
7. **No randomised rewards.** The pond is a published price list: 41 items, fixed
   prices, same order for every child on every install. No crates, no rolls, no
   "rare" items, no limited-time drops.
8. **No leaderboards or comparison.** Not between siblings, not against other
   families, not against an "average child" — that phrase is on the forbidden list.
9. **No ads.** None. No ad SDK, no house ads, no cross-promotion, no third-party
   network of any kind.
10. **No child data collection.** No account, no analytics SDK, no telemetry, no
    identifier that leaves the device. `Docs/PrivacyArchitecture.md`.

---

## 2. Reward philosophy: reward the trying, not the output

A child cannot control whether their body cooperates. Rewarding output would make
the star a lottery on physiology and would teach the child that a visit which
produced nothing was a wasted trip.

So every `RewardReason` names an *action the child chose to take*:

| Reason | What it rewards |
| --- | --- |
| `triedThePotty` | Going and sitting down. The core reward of the product. |
| `completedRoutine` | Finishing the five steps. |
| `washedHands` | Hand washing, specifically. |
| `toldAGrownUp` | Saying they needed to go. |
| `answeredPottyPause` | Responding to the pause at all. |
| `completedQuiz`, `completedGame` | Finishing something, not scoring in it. |

`RewardService.reason(for:)` maps `.tried`, `.pee` and `.poop` to **the same
reason and the same single star.** Paying more for `pee` than for `tried` would
make the star a reward for a biological outcome. `.accident` maps to `nil` — the
reward path is unreachable from an accident even by mistake, because there is no
case it could map to.

### 2.1 Stars only ever go up

`RewardLedger` has no `remove`, `subtract`, `clear`, `expire` or `decay`. The rule
is easiest to keep when the API that would break it does not exist.

- `RewardTransaction.quantity` is `let` and clamped non-negative.
- Awarding is keyed, not counted:
  `hop.reward.v1|<childID>|<reason>|<scope>`, every component derived from
  already-durable data, so a crash-and-retry produces one star rather than two
  (`RewardIdempotency`). The store repeats the guarantee with
  `@Attribute(.unique) idempotencyKey`.
- Deleting an event **never** removes its star. `RewardService.reconcile` breaks
  the link, keeps the row, the quantity and the key, and reports
  `starsRemoved` — a value that is always zero and is asserted in a test.

The reason is written into the source: a pond that shrinks is a punishment the
child cannot attribute to anything they did, delivered by an adult they trust, in
an app they were told is theirs. That is loss aversion aimed at a three-year-old.

### 2.2 The pond curve

41 items, 3 → 616 stars. First unlock at **3 stars** — one good routine, so the
pond visibly changes on day one. Steps grow slowly and are bounded, so the late
pond stays achievable and the curve has no wall and no cliff. Prices are constants
a caregiver can read out loud, and `PondCatalogTests` asserts monotonicity,
compile-time exhaustiveness over `PondItemID`, and that partially-unlocked ponds
stay visually centred.

---

## 3. Why accidents are parent-recorded only

`PottyEventKind.isChildLoggable` is `false` for `.accident`, and only that.

1. **A child should never be asked to self-report a failure state.** The tap
   itself would be the shaming act, regardless of the copy around it.
2. **A three-year-old cannot reliably distinguish the categories.** Self-reported
   accident data would be noise fed into the one part of the app a caregiver
   might read as meaningful.
3. **It keeps the child's surface entirely positive.** In Child Space every
   button leads somewhere good. There is no button whose meaning is "I did the
   bad thing".
4. **The record belongs to the caregiver.** An accident is an observation an
   adult makes about their household, backdatable, with a private note — not a
   confession extracted from a child.

The event is still first-class: it appears on the timeline with its own glyph and
feeds the "longest stretch with no accident recorded" insight. It is simply never
a thing the child does, and never a thing the reward system reads.

---

## 4. The forbidden-language lists — ENFORCED BY TESTS

Three separate rails, in two modules, checked by two independent implementations.

### 4.1 Child-facing and catalog-wide — `CopySafetyScanner`

`HopPottyKit/Tests/HopPottyCoreTests/Content/CopySafetyScanner.swift`
Applied by `HopPottyKit/Tests/HopPottyCoreTests/Content/ChildSafetyCopyTests.swift`

Deliberately implemented in the *test* target, not in `HopPottyCore`: if the
catalog and the thing that checks the catalog shared an implementation, a bug in
the matcher would hide the very strings it exists to find. This is the second
opinion.

Matching is **word-level, not substring**, because substring matching fires on
"close" (lose), "plate" (late), "badge" (bad), "mustard" (must), "stopper"
(stop). Inflections are enumerated explicitly. Typographic apostrophes are folded
to ASCII, so copy edited in a word processor cannot slip past on a curly quote.

| List | Contents |
| --- | --- |
| `shameWords` (child-facing) | fail, fails, failed, failing, failure, failures · wrong, wrongly · lost, lose, loses, losing, loser · disappoint(+4) · bad, badly, worse, worst · naughty · don't, dont · can't, cant, cannot · stop, stops, stopped · never · must, mustn't · should, shouldn't · hurry(+3) · late |
| `shamePhrases` | "no stars", "do not", "did not", "too slow", "too late" |
| `medicalStems` (**whole catalog**, parent copy included) | prevent, treat, cure, diagnos, condition, disorder, normal, abnormal, delayed |
| `prescriptiveWords` (parent-facing) | should, shouldn't, must, ought |

The suite also asserts the scanner itself: that it does **not** fire on innocent
words, that it **does** catch what it is for, that apostrophe folding works, and
that medical stems match word beginnings rather than substrings. A safety test
that cannot fail is not a safety test.

Length limits are checked too: child-facing strings stay short enough for a
pre-reader and spoken lines short enough to hold attention.

### 4.2 Parent-facing insights — `InsightLanguagePolicy`

`HopPottyKit/Sources/HopPottyCore/Insights/InsightLanguagePolicy.swift`
Asserted by `HopPottyKit/Tests/HopPottyCoreTests/Insights/InsightLanguageTests.swift`

~70 forbidden fragments, matched case-insensitively as substrings (a blunter
instrument on purpose — this module's whole output is enumerable, so false
positives are cheap to fix and a miss is not). Grouped by the harm each does:

| Group | Examples |
| --- | --- |
| Prescriptive | should, must, ought, need to, recommend, supposed to, make sure |
| Diagnostic | diagnos, symptom, disorder, syndrome, constipat, infection, incontinen, retention |
| Normative | normal, abnormal, typical for, average child, delay, behind, on track, regress, milestone, age-appropriate, too long, too often |
| Clinical action | treat, cure, prevent, therapy, medication, dose, clinical |
| Causal | cause, leads to, due to, results in, proves, guarantee, explains why |
| Shame and loss | fail, wrong, poor, worse, problem, concern, lost, streak, success rate, accident rate, bad |

Two structural properties make the check **total** rather than a sample:

1. Every generated string is assembled from module constants and integers. No
   nickname, caregiver note or other free text is ever interpolated, so a family
   cannot smuggle language past the rail and the rail cannot be defeated by data.
2. `InsightsReport.allGeneratedStrings` and `InsightsEngine.allStaticStrings`
   enumerate everything with a path to a screen.

`InsightLanguagePolicy.checked(_:)` is defence in depth at runtime: it traps in
debug and degrades to `"Pattern from recorded entries."` in release rather than
showing a parent a sentence this policy forbids.

### 4.3 The contract itself

`Docs/CONTRACTS.md` §4 states the seven non-negotiable rules. Breaking one is a
build failure, not a discussion.

### 4.4 Where to look

| File | Enforces |
| --- | --- |
| `HopPottyKit/Tests/HopPottyCoreTests/Content/ChildSafetyCopyTests.swift` | shame, medical, prescriptive, length, non-empty, over the whole `HopCopy` catalog and every `HopVoiceLine` |
| `HopPottyKit/Tests/HopPottyCoreTests/Content/CopySafetyScanner.swift` | the matcher, and the tests of the matcher |
| `HopPottyKit/Tests/HopPottyCoreTests/Insights/InsightLanguageTests.swift` | every string the insights engine can emit |
| `HopPottyKit/Tests/HopPottyCoreTests/Rewards/RewardServiceTests.swift` | accidents earn nothing; stars are never removed; reconciliation removes zero stars; idempotency collapses retries |
| `HopPottyKit/Tests/HopPottyCoreTests/Rewards/PondProgressServiceTests.swift` | a lower star total never shrinks a pond |
| `HopPottyKit/Tests/HopPottyCoreTests/StateMachine/PottyPauseFailSafeTests.swift` | no path holds a shield on an outcome; every error clears; the parent exit is accepted from every state |

---

## 5. What the child can and cannot reach

| Child Space contains | Child Space never contains |
| --- | --- |
| Hop, the routine, the pond, games, quizzes | A price, a purchase, a restore |
| One big button per screen | A setting that changes the schedule |
| Replay-the-line audio control | A destructive action |
| A star badge | An external link, a web view, a share sheet |
| | Another child's data |

`Docs/InformationArchitecture.md` §5 lists every transition that requires the
parent gate.

---

## 6. Copy rules for anyone writing a child-facing string

1. Address the child, not the behaviour. "Let's give it a try" — not "you need to
   try".
2. Never negate their effort. There is no sentence in HopPotty that begins with
   "Don't".
3. The child's own words for their own actions: "I'm going!", "All done!".
4. Never promise timing HopPotty cannot keep — the star may land at next launch,
   so no copy says "here's your star!" at the moment of a shield tap.
5. Assume it will be read aloud by a caregiver at 7am to a child who is already
   cross.

---

## 7. Games and quizzes cannot be failed

- `MiniGameCompletion` has exactly two cases — `whenTaskComplete` and
  `whenChildIsDone`. There is no `.failed` and no `.timeUp`, because a game that
  can be lost turns a bathroom trip into something a child can be bad at, and a
  countdown turns it into something to rush.
- `QuizAnswerOutcome` has `affirm` and `redirect`. A redirect leaves the options
  tappable and the question open; nothing is counted, so nothing can be lost.
- Rounds are 3 questions, games 30–90 seconds. Bounded so the reward never
  becomes the reason to go to the bathroom.

---

## 8. Safety of the shield itself

The most serious safety failure available to this product is not a bad sentence —
it is **a child holding a device that will not open anything**, with no way to
explain the problem.

Every ambiguity in the pause system therefore resolves toward the child having
access: `.clearShield` is idempotent and emitted whenever it might help; every
error state clears; cold start always clears whatever it finds; and
`parentRestoredAccess` is accepted from all fourteen states and never refused.
`Docs/TechnicalArchitecture.md` §6.

---

## 9. The rails have already caught real copy

This is not a theoretical mechanism. During integration the suites went red on
two strings that had been written in good faith:

| Test | String as written | Matched | Key |
| --- | --- | --- | --- |
| "No child-facing string contains shame language" | `"No stars yet"` | the phrase `no stars` | `pond.starCount.zero` |
| "No parent-facing string tells a caregiver what they should do" | `"What should Hop call your child?"` | `should` | `onboarding.name.title` |

Neither was intended as shaming or prescriptive — both were over-triggers of a
deliberately blunt rail. **The copy moved anyway**, to
`"Ready for your first star!"` and `"What can Hop call your child?"`, and both
suites are green again.

That is the intended outcome. The list is the product rule; when a string and the
list disagree, the string changes. Weakening either vocabulary requires an edit to
`CONTRACTS.md` §4 and a reviewer who says so out loud.

**Status of the whole domain suite:** `swift test` in `HopPottyKit/` reports
**350 tests across 28 suites, all passing**, on Swift 6.2 for Linux
(observed 2026-09-01). Everything above the package boundary — the SwiftUI views,
the three Screen Time extensions, and every runtime safety behaviour on a real
device — is **unverified**. See `BUILD_STATUS.md`.
