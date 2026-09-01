# Product Vision

**Date:** 2026-09-01
**Status:** Settled. Changes here need a reason, not a preference.

## 1. What HopPotty is

HopPotty is an iOS and iPadOS app that helps a family build a potty-training
rhythm on a device a child is already holding. At an interval the caregiver
chooses, the app briefly interrupts play, invites the child to try the potty,
celebrates the attempt, and gives the screen back.

It is a *training aid for a caregiver*, operated on the child's device. It is not
a game, not a tracker a child is measured by, and not a medical product
(`Docs/MedicalBoundary.md`).

## 2. The insight

Potty training fails at one specific moment: a child absorbed in a screen does
not notice their body until it is too late. Reminders that only reach the
caregiver arrive at the wrong person. Reminders that arrive as a notification are
dismissed by the same thumb that is already tapping.

The interruption has to happen **inside the thing the child is doing**, and it
has to end on its own:

```
PLAY  →  WARNING  →  PAUSE  →  POTTY  →  CELEBRATE  →  RESUME
```

| Stage | What happens | Who acts |
| --- | --- | --- |
| **PLAY** | The child uses the apps the caregiver selected. HopPotty is not on screen. | child |
| **WARNING** | Optional, default 2 minutes ahead. A gentle cue so the interruption is never a surprise. | app |
| **PAUSE** | The selected apps are shielded. Hop appears with one invitation. | app |
| **POTTY** | The child goes, or does not. Either way the timer is running. | child + caregiver |
| **CELEBRATE** | A star lands for *going and trying*. The pond grows. | app |
| **RESUME** | Access is restored. Cooldown starts so the child is not re-interrupted. | app |

The pause ends on its timer, on the child tapping through, or on a caregiver
override — and on nothing else. There is no fourth exit, and no branch anywhere
in the codebase that asks what the child produced
(`HopPottyCore/StateMachine/PottyPauseMachine.swift`, `CONTRACTS.md` §4.1).

## 3. North star

> **Pause. Potty. Play.**

Three words in the order the child experiences them. The pause is short, the
potty is the point, and the play comes back. Every design argument resolves by
asking which of the three a change serves — and whether it shortens the middle
one.

## 4. Who it is for

| | Primary | Secondary |
| --- | --- | --- |
| **The caregiver** | A parent of a 2–5 year old who is actively potty training and whose child uses an iPad or iPhone. Sets everything up, reads the patterns, owns every destructive action. | A grandparent, childminder or co-parent handed the same device. |
| **The child** | 2–5, pre-reading. Cannot read a sentence, can recognise a frog, can press a big button. Every child-facing surface is audio-first with an illustration carrying the meaning. | A 5–6 year old still working on night-time or public bathrooms. |

Design consequences that follow directly from "pre-reading":

- Child controls are ≥72pt, primary actions ≥96pt (`HopHitTarget`).
- Every spoken line ships with a written caption; no audio ships yet, so the
  caption path is the *normal* path, not a fallback (`HopVoiceAssetState`).
- Illustrations are never decorative on child surfaces — they carry the
  instruction, so they all have accessibility labels.

## 5. The rule this product exists to keep

> **HopPotty exists to *reduce* screen time, not to compete for it.**

A feature that increases compulsive engagement without improving potty
independence is rejected. Not de-prioritised — rejected. This is the test, and it
has already removed things:

| Rejected | Why |
| --- | --- |
| Daily streaks | A streak that breaks is a punishment for a family that had a hard week. `CONTRACTS.md` §4.7. |
| Randomised rewards / crates | Variable reinforcement is the engagement mechanic; the pond is a fixed, published price list instead (`PondCatalog`). |
| Leaderboards, sibling comparison | Turns a bodily function into a competition between children. |
| A `DeviceActivityReport` usage dashboard | Available for free (iOS 16+) and deliberately not shipped: it reads as a judgement of the child's day. `ScreenTimeArchitecture.md` §8. |
| "Come back!" notifications | The app has no reason to want the child in it. Only two notification kinds exist: the pre-pause warning and an optional caregiver daily summary. |
| Longer celebrations | Capped at 3.5s (`HopMotion.celebrationMaxDuration`). The whole premise is a short interruption. |
| A high score in the mini-games | `MiniGameCompletion` has no `.failed` and no `.timeUp` case. |

The app's own success metric is *time not spent in HopPotty*. A session where a
child sees the shield, goes, taps once, and returns to their game in ninety
seconds is a perfect session.

## 6. Anti-goals

**HopPotty will not:**

1. **Make screen access contingent on a biological outcome.** Never "you can have
   your game back when you pee." Enforced by the state machine and its tests.
2. **Shame a child.** No "failed", "wrong", "lost", "no stars", "hurry", "late".
   Enforced by `ChildSafetyCopyTests` over the whole copy catalog.
3. **Punish an accident.** `accident` is a neutral timeline fact that never
   reaches the reward system (`RewardService.reason(for:)` returns `nil`).
4. **Take a star back.** The ledger is append-only with no `remove`, `decay` or
   `expire` (`RewardLedger`).
5. **Give medical advice.** No diagnosis, no "normal", no recommended frequency.
   `Docs/MedicalBoundary.md`.
6. **Collect data about a child.** No account, no analytics SDK, no ads, no
   network request carrying family data. `Docs/PrivacyArchitecture.md`.
7. **Be a general parental-control app.** One named `ManagedSettingsStore`, one
   setting (`shield.applications`), cleared when the pause ends. No web filter, no
   app limits, no account lock.
8. **Become the destination.** Games and quizzes exist as a small thank-you after
   a routine, bounded to 30–90 seconds, and can be switched off entirely.
9. **Sell a subscription.** One non-consumable unlock. Nothing a child earned is
   ever behind it (`purchase.freeFooter`).
10. **Claim a shield is up.** The system decides effective settings; HopPotty
    reports what it *asked for*. `ScreenTimeArchitecture.md` §11.12.

## 7. What "done" looks like for a family

A caregiver sets an interval once, picks two apps, and stops thinking about it.
The child learns that Hop shows up, the game waits, and going to the bathroom is
a small ordinary thing with a frog at the end of it. Some weeks later the family
turns HopPotty off, because it worked.

That is the intended end state. The product is designed to be *stopped using*.

## 8. Honest status

No Xcode build, no simulator run, no device test, and no Family Controls
entitlement exist as of this date. The domain layer compiles and its tests
execute on Linux; everything above the package boundary is written but
unverified. `BUILD_STATUS.md` is the authority and is deliberately blunt about it.
