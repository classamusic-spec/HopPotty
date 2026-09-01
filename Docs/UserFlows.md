# User Flows

**Date:** 2026-09-01
**Status:** Specification. Every flow below is implemented in domain logic and
tested (`HopPottyCore`) or written and uncompiled (`HopPotty/`). No flow has been
executed on a device.

Denial and error branches are shown alongside the happy path, because in this
product the error branches are the ones that matter: a stranded shield is the
failure that gets a parenting app deleted.

---

## 1. Onboarding

Six steps, all skippable except the first and last. No account, no email, no
network request.

```mermaid
flowchart TD
    A[Welcome — Pause. Potty. Play.] --> B[Everything stays on this device]
    B --> C{Nickname?}
    C -->|Types one| D[Pick a friend]
    C -->|Skip for now| D
    D --> E[How often is a good rhythm?]
    E --> F{How should HopPotty interrupt?}
    F -->|Gentle| K[You are all set]
    F -->|Pause or Guided routine| G[HopPotty uses Screen Time]
    G --> H[[requestAuthorization]]
    H -->|approved| I[Pick the apps that pause]
    H -->|denied| D1[Screen Time permission is off]
    H -->|cancelled| D2[Return to the mode step, nothing recorded]
    H -->|restricted| D3[Screen Time is unavailable here]
    H -->|authorizationConflict| D4[Another parental-controls app is in charge]
    D1 --> J[Continue in Gentle mode]
    D3 --> J
    D4 --> J
    I -->|selection made| K
    I -->|nothing picked| D5[No apps picked yet → Gentle until you pick some]
    D5 --> J
    J --> K
    K --> L[Parent home]
```

Branch rules:

- **Cancelled is not a failure.** `ScreenTimeAuthorizationOutcome.cancelled` maps
  to `.notDetermined`, not `.denied`, and is never presented as an error.
- **Restricted offers no retry.** `ScreenTimeAuthorizationStatus.isRetryable` is
  false, so the UI must not show a button that cannot work.
- **Gentle is a real destination, not a consolation.** Reminders, the routine,
  stars and the pond all work with no Screen Time authorization at all.

---

## 2. A full Potty Pause lifecycle

The state machine is `HopPottyCore/StateMachine/PottyPauseMachine.swift` — a
pure, total reducer returning effects. Effects are ordered, and `.clearShield` is
always first in any bundle that contains it.

```mermaid
stateDiagram-v2
    [*] --> disabled
    disabled --> ready: scheduleEnabled (gates pass)
    disabled --> authorizationRequired: scheduleEnabled (no authorization)
    ready --> monitoring: monitoringRegistered
    ready --> errorRecoverable: monitoringRegistrationFailed
    monitoring --> warningApproaching: warningThresholdReached
    monitoring --> pauseTriggered: pauseThresholdReached
    warningApproaching --> pauseTriggered: pauseThresholdReached
    pauseTriggered --> shieldActive: shieldApplied
    pauseTriggered --> errorRequiresParent: shieldApplyFailed
    shieldActive --> routineActive: childAcknowledged
    shieldActive --> restoring: pauseTimerExpired
    routineActive --> completing: routineCompleted
    routineActive --> restoring: pauseTimerExpired
    completing --> cooldown: completionAcknowledged
    restoring --> cooldown: shieldCleared
    cooldown --> monitoring: cooldownElapsed
    shieldActive --> errorAccessRestored: parentRestoredAccess
    routineActive --> errorAccessRestored: parentRestoredAccess
    errorRecoverable --> ready: retryRequested (gates pass)
    errorRequiresParent --> errorAccessRestored: parentRestoredAccess
    errorAccessRestored --> disabled: scheduleDisabled
```

### 2.1 The happy path, in order

| # | Event | State after | Effects (ordered) |
| --- | --- | --- | --- |
| 1 | `scheduleEnabled` | `ready` | clearShield, registerMonitoring |
| 2 | `monitoringRegistered` | `monitoring` | scheduleWarningNotification |
| 3 | `warningThresholdReached` | `warningApproaching` | presentWarning |
| 4 | `pauseThresholdReached` | `pauseTriggered` | applyShield, startPauseTimer, persistSession |
| 5 | `shieldApplied` | `shieldActive` | presentPauseScreen |
| 6 | `childAcknowledged` | `routineActive` | awardParticipation(.answeredPottyPause) |
| 7 | `routineCompleted` | `completing` | **clearShield**, logPauseOutcome(.completedRoutine), awardParticipation |
| 8 | `completionAcknowledged` | `cooldown` | dismissPauseScreen, clearPersistedSession, beginCooldown |
| 9 | `cooldownElapsed` | `monitoring` | — |

Access is restored at **step 7**, not step 8. The celebration runs on top of
unshielded apps: holding a shield open for an animation is holding it open for no
reason.

### 2.2 The five ways it ends

```mermaid
flowchart LR
    P[Pause in flight] --> A[Child taps the shield button]
    P --> B[intervalWillEndWarning at the intended duration]
    P --> C[intervalDidEnd at +15 min — Apple's floor]
    P --> D[App foreground reconciliation]
    P --> E[Caregiver override behind the gate]
    A --> Z[clearAllSettings · append outcome · stop monitoring]
    B --> Z
    C --> Z
    D --> Z
    E --> Z
    Z --> Y[App drains the outbox → PottyEvent + at most one star, keyed by pauseID]
```

No path consults an outcome. No path can extend a pause: `startedAt`,
`plannedEndAt` and `backstopEndAt` are `let` on `SharedPauseRecord` and written
once.

### 2.3 Cold start after process death

`PottyPauseMachine.recoverFromColdStart` — **every branch clears first**,
including the branch where nothing was persisted.

| Finding | Verdict | Star? |
| --- | --- | --- |
| Nothing on disk | `noSessionFound` | no |
| Malformed, or another child's record | `sessionMalformed` | no |
| `startedAt` in the future (clock moved back) | `clockMovedBackwards` | no |
| `expiresAt` already passed | `sessionExpired` | no |
| Genuinely mid-pause | `interruptedMidPause` | no |
| Mid-pause **and** the child had engaged | `interruptedAfterEngagement` | **yes** |

Order of effects: `clearShield` → `cancelPauseTimer` →
`cancelWarningNotification` → `dismissPauseScreen` → tidy-up. If the process dies
again part-way through, it dies with the shield already down.

The mirror-image decision — "only 40 seconds in, put the shield back" — is never
taken. A pause interrupted by a crash is over.

---

## 3. The child routine

Five steps (`PottyRoutineContent`), fitting inside the default 180-second pause
with room to spare.

```mermaid
flowchart TD
    S[Shield: I'm going!] --> T["Try — sit down and give it a try (90s, skippable)"]
    T --> W1[Wipe — front to back, skippable]
    W1 --> F[Flush]
    F --> W2[Wash — 20 seconds]
    W2 --> H[High five]
    H --> C[Celebration: star lands, ≤3.5s]
    C --> R[Access already restored — back to play]
    T -.->|Leaves at any step| R
    W1 -.->|Leaves at any step| R
    F -.->|Leaves at any step| R
    W2 -.->|Leaves at any step| R
```

Rules:

- **Leaving is always allowed and never costs anything.** `isSkippable` governs
  whether a "Skip this" control appears, not whether the child may leave.
- The sit timer on step 1 is **off by default** — a visible countdown is
  stressful for some children (`AppSettings.routineSitTimerEnabled`).
- Stars: `triedThePotty` on step 1, `washedHands` on step 4, `completedRoutine`
  at the end. All idempotent, all keyed to the durable session id.
- Every step's illustration carries the instruction, so all of them have
  accessibility labels; illustrations here are never decorative.
- With no voice assets bundled, every line is caption-only. That is the normal
  path, not an error state (`HopVoiceAssetState.planned`).

---

## 4. Logging an accident

Parent-recorded only. The child is never asked to self-report one.

```mermaid
flowchart TD
    A[Parent home → Log a visit] --> B[Kind: Tried · Pee · Poop · Accident]
    B --> C{Accident?}
    C -->|Yes| D[Available only here, in Parent Space]
    C -->|No| E[Also available to the child in the routine]
    D --> F[Time — defaults to now, backdatable]
    E --> F
    F --> G[Optional private note — parent-only, never exported without consent]
    G --> H[Save]
    H --> I[Timeline row with a distinct glyph]
    H --> J{Reward?}
    J -->|tried / pee / poop| K[One star, reason triedThePotty, keyed to the event id]
    J -->|accident| L[Nothing. No star, no penalty, no counter]
```

- `PottyEventKind.isChildLoggable` is false for `.accident` and gates the child
  UI. `RewardService.reason(for: .accident)` returns `nil`, so the reward path is
  unreachable from an accident even by mistake.
- Timestamp is *when it happened*, not when it was recorded — a parent logging
  twenty minutes late can backdate.
- Insight copy never uses the phrase "accident rate"; it is on the forbidden list.

---

## 5. Emergency restore

The path a caregiver takes when something is wrong and they do not care why.

```mermaid
flowchart TD
    A[Settings → Restore Screen Access] --> B[Parent gate]
    B -->|passed| C[[parentRestoredAccess — accepted from every state]]
    B -->|failed| B2[Another question. No lockout, no counter.]
    C --> D[clearShield first, then cancel timers and monitoring]
    D --> E{Clear confirmed?}
    E -->|Yes| F[Access restored · notifyParent .accessRestoredByParent]
    E -->|No, shieldClearFailed| G[errorRequiresParent .shieldClearFailed]
    G --> H["Apps are still paused" — with the steps to clear it in iOS Settings]
    C --> I{Was there an unresolved failure?}
    I -->|Yes| J[errorAccessRestored: the failure stands, the shield does not]
    I -->|No| F
```

`errorAccessRestored(failure)` exists because "something is broken" and "a shield
may be standing" are separate facts, and the emergency exit resolves only the
second. It was added when the fail-safe suite caught the restore path
re-accepting whichever error state it was in — see `TechnicalArchitecture.md` §6.

---

## 6. Purchase

```mermaid
flowchart TD
    A[Locked feature or Settings → Unlock HopPotty] --> B[Parent gate: purchase]
    B --> C{StoreKit answered?}
    C -->|No / offline| D[Show the features, hide the price. Never invent one.]
    C -->|Yes| E[HopPotty Family · displayPrice · one purchase, no subscription]
    E --> F[[Product.purchase]]
    F -->|purchased| G[Entitlement .family · everything unlocked]
    F -->|cancelled| H[Back to where they were. No nag, no discount offer.]
    F -->|pending| I["Waiting for approval — Ask to Buy sent to your family organiser"]
    F -->|failed| J["The purchase did not complete. You were not charged."]
    A2[Settings → Restore purchase] --> B2[Parent gate: restorePurchase]
    B2 --> K[[AppStore.sync / current entitlements]]
    K -->|found| G
    K -->|none| L[Nothing to restore. Stated plainly, not as an error.]
```

Free tier keeps one child, the full routine and every reminder. Nothing a child
earned is ever behind the purchase.

---

## 7. Data deletion

Four operations, each with its own receipt (`DeletionOperation`).

```mermaid
flowchart TD
    A[Settings → Privacy and data] --> B{Which?}
    B --> C[Clear history]
    B --> D[Reset rewards]
    B --> E[Delete this child]
    B --> F[Delete everything]
    C --> G[Parent gate: deleteData]
    D --> G
    E --> G
    F --> G
    G --> H[Count rows FIRST — DeletionPlan, never an estimate]
    H --> I["N potty events · M stars · K decorations will be removed"]
    I --> J{Confirm?}
    J -->|Cancel| K[Nothing touched]
    J -->|Delete| L[Re-count — a plan left open for an hour is stale]
    L --> M[Delete, then reconcile]
    M --> N[Receipt: what was removed, and starsKept for orphaned rewards]
```

Per-operation behaviour:

| Operation | Removes | Keeps | Star effect |
| --- | --- | --- | --- |
| **Clear history** | Potty events | Child, stars, pond, schedule | Stars from deleted events are **unlinked, never removed**. The receipt names the count kept. |
| **Reset rewards** | Ledger + pond for one child | Child, events, schedule | The only operation that removes a star — data deletion by a caregiver, not a game mechanic. All-or-nothing on purpose: a selective "remove three stars" is a punishment with a data-management label. |
| **Delete child** | Everything for one child, profile included | Other children | Removed with the child. |
| **Reset app** | Every child, every table, settings to defaults | Nothing | Removed. |

Every child-scoped table conforms to `ChildScopedRepository`, so a tenth table
added later is a compile error rather than a row nobody deleted.

---

## 8. Error branches worth designing for explicitly

| Situation | Where it surfaces | What the caregiver is told |
| --- | --- | --- |
| Authorization revoked mid-pause | `authorizationRevoked`, accepted from every state | The shield may still be standing and HopPotty may no longer have permission to lift it — the one case where the caregiver has to act in iOS Settings. |
| Another parental-controls app holds authorization | `.authorizationConflict` | Resolvable only outside HopPotty. Treated as shield-ambiguous, so it clears. |
| Adult Apple Account where a child account is required | `.invalidAccountType` | No retry offered. |
| Device cannot present Family Controls authentication | `.authenticationMethodUnavailable` | Needs a passcode and biometrics; explained, not retried. |
| Apple's 20-activity cap reached | `.monitoringLimitReached` | Not self-recoverable; the app reuses `DeviceActivityName`s rather than accumulating them. |
| Shield extension too slow | Apple's default shield appears | A **user-visible copy failure** in Apple's words, not HopPotty's. Treated as P1. |
| Storage unavailable | `ParentFailure.storageUnavailable` | "HopPotty could not save that", with the app still usable read-only. |
