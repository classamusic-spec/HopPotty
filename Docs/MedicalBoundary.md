# Medical Boundary

**Date:** 2026-09-01
**Enforced by:** `HopPottyCore/Insights/InsightLanguagePolicy.swift`,
`Tests/HopPottyCoreTests/Insights/InsightLanguageTests.swift`,
`Tests/HopPottyCoreTests/Content/CopySafetyScanner.swift`,
`Tests/HopPottyCoreTests/Content/ChildSafetyCopyTests.swift`

---

## 1. The line

> **HopPotty describes what a family recorded. It never says what that means,
> what a child needs, or what anyone ought to do about it.**

HopPotty is **not** a medical device, not a diagnostic tool, not a screening
instrument, and not a source of clinical guidance. It counts events a caregiver
or child tapped into a phone and reports them back.

The line is easy to write down and easy to cross by accident three sprints later,
which is why it is enforced mechanically rather than by review.

---

## 2. Why this matters more here than in most apps

1. **The data looks clinical.** Timestamped elimination records with categories
   are, in another context, a bladder diary. A sentence next to them inherits
   authority the app has not earned.
2. **The reader is emotionally invested.** A parent reading a statistic about
   their own child will believe it, and may act on it — by pushing harder, by
   worrying, or by *not* seeing a paediatrician because an app said things looked
   fine.
3. **The sample is tiny and biased.** The data is "when someone got round to
   tapping a button", not observed physiology. It cannot support a claim about a
   child's body.
4. **A false reassurance is the worst outcome available.** Constipation, urinary
   tract infection and retention are real, common, and treatable. An app that
   implies "this is normal" can delay a visit. HopPotty must never be the reason
   a family waited.

---

## 3. Permitted phrasings

Descriptive, past tense, about **the log** rather than about the child, with the
sample size available.

| Permitted | Why it is safe |
| --- | --- |
| "Most visits were 45–55 minutes apart." | Describes recorded gaps. Makes no claim about need. |
| "12 visits recorded this week, 9 last week." | Two counts. No comparison verdict. |
| "Mornings had an entry on 5 of 7 days; afternoons on 2 of 7." | Coverage of the log, stated as a fraction with its denominator. |
| "Longest stretch with no accident recorded: 3 days, 4 hours." | "Recorded" is load-bearing — it describes the log, not the child. |
| "Based on 20 recorded gaps." | States the evidence. |
| "Not enough entries yet to describe a pattern." | The honest empty state. Better than a hedged statistic. |
| "Your pause interval is 45 minutes. Most recorded gaps were about 60 minutes apart. **Would you like to try 60?**" | A question, with the observation that prompted it. The caregiver decides; the app cannot apply it. |
| "Pattern, not medical advice." | Attached to **every** insight, without exception. |

### 3.1 Three structural guarantees behind those sentences

1. **`disclaimerRequired` is a computed constant that is always `true`.** It has
   no initialiser parameter, no setter, and no code path that yields `false`, so
   no future caller can produce an insight that travels without its label.
2. **Nothing user-written is ever interpolated into an insight.** Every string is
   assembled from module constants and integers, so a family cannot smuggle
   language past the rail and the rail cannot be defeated by data. That is what
   makes the language test **total** rather than a sample.
3. **`IntervalSuggestion` cannot act.** It is an immutable value with no
   `mutating` member and no method that takes a `PottySchedule`. Its initialiser
   is internal to the module. There is literally nothing to call that would change
   a family's settings.

---

## 4. Forbidden phrasings

Every fragment below is in `InsightLanguagePolicy.forbiddenFragments`, matched
case-insensitively as a substring so inflections are caught ("cause" catches
"caused", "causes", "because"). A generated string containing one **fails the
build**.

| Category | Forbidden | Example of what it would wrongly claim |
| --- | --- | --- |
| **Prescriptive** | should, must, ought, need to, needs to, required, require, recommend, supposed to, have to, make sure | "Maya should go every 2 hours" — HopPotty has no basis for an instruction. |
| **Diagnostic** | diagnos*, symptom, disorder, condition, syndrome, dysfunction, constipat*, infection, incontinen*, retention, bladder issue | "This may be a symptom of constipation" — that is a clinician's sentence. |
| **Normative** | normal, abnormal, typical for, average child, delay, behind, on track, ahead of, expected for, regress*, milestone, age-appropriate, healthy interval, too long, too often, too few | "Longer than normal for a 3-year-old" — there is no population here to be normal against. |
| **Clinical action** | treat, cure, prevent, therapy, medication, dose, clinical | Implies HopPotty is part of care. |
| **Causal** | cause, leads to, due to, results in, proves, guarantee, means that, explains why | "Fewer accidents because you shortened the interval" — this engine counts events; it does not explain them. |
| **Shame and loss** | fail, wrong, poor, worse, problem, concern, lost, losing, streak, success rate, accident rate, bad | Barred by the product contract as well as by taste. Note **"accident rate"** and **"success rate"** specifically: a rate frames a child's body as a performance metric. |

The child-facing scanner adds a whole-word medical stem list applied to the
**entire** catalog, parent copy included: `prevent`, `treat`, `cure`, `diagnos`,
`condition`, `disorder`, `normal`, `abnormal`, `delayed`.

### 4.1 Runtime defence in depth

`InsightLanguagePolicy.checked(_:)` traps in debug — so a mistake is caught by the
suite the moment it is written — and in release degrades to:

> **"Pattern from recorded entries."**

A parent sees a deliberately empty sentence rather than one this policy forbids.

---

## 5. Sample-size thresholds are part of the boundary

A pattern claimed from thin data is a guess wearing a statistic's clothes.
Below its threshold the engine returns `nil` — it does **not** return a hedged
version, because a hedge on a dashboard reads as a finding.

| Insight | Minimum | Why that number |
| --- | --- | --- |
| Typical gap (IQR) | 12 gaps | Leaves ≥3 observations below Q1 and ≥3 above Q3; roughly three days of ordinary use. |
| Interval question | 20 gaps, ≥10 min delta | Describing a pattern is one thing; inviting a family to change how often their day is interrupted is another, and should rest on about a week. |
| Participation | 3 visits | One or two entries is not a period; a headline over a nearly empty log reads as a verdict on the log. |
| Time-of-day consistency | 5 days, 5 visits/segment, 0.2 rate gap | Five is the smallest denominator where a difference is not one day going differently. |
| Longest dry stretch | 3 distinct days | A "longest stretch" inside one afternoon is an artefact of when the family opened the app. |

Two shaping constants that are also honesty measures: entries within **5 minutes**
collapse into one visit (a child tapping "tried" then "pee" is one trip), and
reported minutes are rounded to **5** because the underlying timestamps are
button-press times, and printing to the minute would claim precision the data does
not have.

`InsightConfidence` deliberately has **no `.high` band and no percentage** — this
engine counts events in one family's log; it has no population to compare against
and no basis for a number that would look like statistical power.

---

## 6. Paediatrician-referral language

HopPotty does not decide when a family should see a doctor, and it does not
withhold the idea either. The approach is **a standing, unconditional pointer,
never a triggered alert.**

### 6.1 Where it appears

1. In **Settings → About**, permanently.
2. In the **Patterns** surface footer, alongside "Pattern, not medical advice."
3. In the **onboarding privacy/expectations screen**, once.

### 6.2 The exact permitted wording

> **HopPotty is not medical advice.**
> HopPotty shows what you recorded. It cannot tell you anything about your
> child's health.
>
> If anything about your child's toileting worries you — pain, blood, straining,
> a change you did not expect, or simply a feeling that something is not right —
> talk to your paediatrician or family doctor. You do not need a reason from an
> app.

Why it is phrased that way:

- **"anything ... worries you"** puts the trigger with the parent, where it
  belongs, rather than with a threshold in the app.
- The listed signs are **plain observations a parent can make**, not diagnostic
  criteria, and the app never claims to detect them.
- **"You do not need a reason from an app"** is the sentence that undoes the
  harm this whole document exists to prevent: a family should never wait for
  HopPotty to say something is wrong.
- It contains no forbidden fragment. It sits in `HopCopy`, so the copy tests scan
  it like any other string.

### 6.3 What is forbidden around referral

| Forbidden | Why |
| --- | --- |
| A triggered alert ("your data suggests you should see a doctor") | That is triage. HopPotty is not qualified, and a false positive frightens a family while a false negative delays care. |
| A threshold that hides the referral text when things "look fine" | Implicit reassurance is the failure mode this section exists to prevent. The pointer is unconditional. |
| Any symptom checker, red-flag list framed as criteria, or severity scale | All diagnostic instruments. |
| Naming a condition, even to say the app cannot detect it | "This is not a sign of constipation" still puts the word in a parent's head. |
| A doctor-finder, a telehealth referral, or any clinical partner | Turns the boundary into a funnel and creates a commercial interest in a family's worry. |
| Anything implying the app's data is clinically useful | A caregiver may show an export to a clinician if they choose; HopPotty never suggests it is a medical record. |

---

## 7. Disclaimer placement rules

| Surface | Requirement |
| --- | --- |
| Every insight card | "Pattern, not medical advice." — `disclaimerRequired` is always true and there is no code path that omits it |
| The Patterns screen | The full non-medical statement in the footer, plus the referral paragraph |
| Any share or export of insight text | Carries the disclaimer with it |
| Onboarding | The statement once, before any data exists |
| App Store description and screenshots | May not describe HopPotty as tracking, monitoring or improving a child's health outcome |

The disclaimer must never be visual-only: it is read by VoiceOver as part of the
insight (`Accessibility.md` §3.3).

---

## 8. If someone wants to cross the line

Adding a claim, a threshold, a red flag or a normative comparison is not a copy
change. It requires, in order:

1. A change to `CONTRACTS.md` §4.5.
2. Removal of the relevant fragments from `InsightLanguagePolicy`, in a commit a
   named reviewer approves.
3. Qualified clinical review, and legal review of the regulatory position —
   claiming to detect or advise on a condition can make the product a regulated
   medical device.
4. A revision of this document explaining the new line.

Until all four have happened, **the tests are the policy**, and they fail the
build.
