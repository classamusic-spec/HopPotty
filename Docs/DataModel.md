# Data Model

**Date:** 2026-09-01
**Domain types:** `HopPottyKit/Sources/HopPottyCore/Models/`
**Persistence:** `HopPotty/Services/Persistence/` (SwiftData, iOS 17+)

Domain types are declared once in `HopPottyCore` and mapped to SwiftData `@Model`
classes at the persistence boundary. That mapping is real work, and it is worth
it: a persistence framework's requirements never get to dictate the shape of the
domain, and swapping persistence later does not touch business logic
(`ADR/0001`).

**Unverified:** the SwiftData layer has never been compiled or run. Everything
below is the declared schema, not an observed one.

---

## 1. Entity map

```
ChildProfile 1───┬──n PottyEvent ────────┐
                 │                        │ sourceEventID (nullable, breakable)
                 ├──n RewardTransaction ◄─┘
                 ├──1 PondProgress          (cache of "what the stars bought")
                 ├──1 PottySchedule
                 ├──1 ScreenTimeConfiguration
                 ├──1 QuizProgress
                 └──1 GameProgress

AppSettings  ── device-wide, single row, id = "singleton"
```

There are **no SwiftData relationships**. Every link is an explicit `UUID` column
(`childID`, `sourceEventID`, `pauseSessionID`). Reasons: the domain types are
value types that must round-trip without an object graph; deletion is done by an
explicit, counted sweep rather than by a cascade rule nobody can see; and a
cascade that silently removed reward rows would break the one invariant a child
would notice.

---

## 2. Persisted entities and fields

### 2.1 `ChildProfile` → `StoredChildProfile`

| Field | Type | Notes |
| --- | --- | --- |
| `id` | UUID | `@Attribute(.unique)` |
| `nickname` | String? | Optional. Sanitised at construction: trimmed, empty → `nil`, capped at 24 chars (`maxNicknameLength`). Capping in the model rather than the text field means onboarding, settings and import all get the same guarantee. |
| `avatar` | `HopAvatarStyle` → `avatarRaw: String` | 8 illustrated options. Never a photograph. |
| `pondTheme` | `PondTheme` → `pondThemeRaw: String` | `meadowPond` ships; the enum exists so added worlds need no migration. |
| `createdAt`, `modifiedAt` | Date | |

Deliberately absent: legal name, birthday, age, gender, photo, height, weight,
school, address. Age-appropriate defaults come from the chosen routine, not from
personal data.

### 2.2 `PottyEvent` → `StoredPottyEvent`

The highest-volume table — perhaps a dozen rows a day, a few thousand over a full
training arc.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | UUID | `@Attribute(.unique)` |
| `childID` | UUID | Every query is child-scoped. |
| `timestamp` | Date | When it **happened**, not when it was recorded. Backdatable. The sort key everywhere. |
| `kind` | `tried \| pee \| poop \| accident` → `kindRaw` | Unreadable rows fall back to `.tried` — the neutral participation kind. Guessing `.accident` would invent a negative fact about a child. |
| `source` | `childRoutine \| parentManual \| pauseCompletion \| restored` → `sourceRaw` | Determines how much the insights engine trusts the timestamp. |
| `note` | String? | Caregiver free text. Frequently the most sensitive field in the store: never logged, never shown to the child, excluded from an export when the caregiver says so. |
| `pauseSessionID` | UUID? | Relates an outcome to the pause that prompted it, so insights need not infer from timestamps. |
| `createdAt`, `modifiedAt` | Date | `createdAt` is diagnostics only. |

`PottyEventKind` semantics: `isChildLoggable` is false only for `.accident`;
`countsAsParticipation` is true for all three child-loggable kinds *equally*;
`producedOutput` exists solely for parent-facing descriptive statistics and never
for rewards.

### 2.3 `RewardTransaction` → `StoredRewardTransaction`

| Field | Type | Notes |
| --- | --- | --- |
| `id` | UUID | `@Attribute(.unique)` |
| `childID` | UUID | Part of the idempotency identity — two siblings finishing the same routine must both be rewarded. |
| `timestamp` | Date | |
| `reason` | `RewardReason` → `reasonRaw` | 7 cases, one star each. |
| `quantity` | Int | Always positive. **Written once, never updated.** |
| `sourceEventID` | UUID? | Nullable. `nil` on an event-linked reason *is* the orphan marker. |
| `idempotencyKey` | String | **`@Attribute(.unique)`** — the store rejects a double award, not only the in-memory ledger. |

The model class has **no `apply(_:)`**. The single legitimate edit — clearing
`sourceEventID` when a caregiver deletes the event — goes through
`orphanSourceEvent()`, which cannot touch anything else.

### 2.4 `PondProgress` → `StoredPondProgress`

| Field | Type | Notes |
| --- | --- | --- |
| `childID` | UUID | `@Attribute(.unique)` |
| `unlockedData` | Data | `[PondItemID.rawValue: Date]` as JSON |
| `unlockedCount` | Int | Denormalised so the dashboard can show "12 of 41" and the deletion preview can count, both without decoding |
| `modifiedAt` | Date | |

Strictly a **cache of what the star total already bought**, kept so unlock *dates*
survive. `PondProgressService` can always rebuild the set from the ledger; it
cannot rebuild when each item appeared. If the row is lost, a complete pond
regenerates with today's date and the child loses nothing visible.

An unknown `PondItemID` (a store written by a newer build) is silently dropped
rather than failing the row, so the child's other decorations still appear.

### 2.5 `PottySchedule` → `StoredPottySchedule`

One per child. Fields: `mode`, `triggerBasis`, `intervalMinutes`,
`warningOffset`, `pauseDuration`, `cooldown`, `quietWindowsData` (JSON array),
`activeDayValues: [Int]`, `activeWindowStartMinutes`, `activeWindowEndMinutes`,
`isEnabled`, `suspensionData` (JSON, `ScheduleSuspension`), timestamps.

Two decisions worth reading twice:

- **Wall-clock times are `LocalTimeOfDay`, stored as minutes-since-midnight —
  never a `Date`.** "Naps start at 12:30" means 12:30 on the wall clock in
  whatever zone the family is in today. An absolute `Date` would shift every
  window by an hour at a DST boundary and by the whole offset when a family
  travels. `LocalTimeOfDay` normalises out-of-range input rather than trapping: a
  corrupted persisted value should degrade to a sane time, not crash a parenting
  app on launch.
- **`ScheduleSuspension` is one value, not a set of booleans**, so "skip the next
  one" and "pause until tomorrow" cannot both be half-true.

`activeDays` empty means *every day*. The initialiser normalises this, but
`Codable` bypasses initialisers, so the schedule service re-checks: a decoded
empty set must never mean "never".

### 2.6 `ScreenTimeConfiguration` → `StoredScreenTimeConfiguration`

| Field | Type |
| --- | --- |
| `childID` | UUID, unique |
| `selectedApplicationCount`, `selectedCategoryCount`, `selectedWebDomainCount` | Int |
| `authorizationStatus` | `notDetermined \| denied \| approved \| restricted` |
| `lastMonitoringRegistration` | Date? |
| `lastRegistrationFailure` | `ScreenTimeFailure?` |

**Counts, never identities.** See §5.

### 2.7 `AppSettings` → `StoredAppSettings`

Device-wide, single row keyed `"singleton"`. Sound (voice, effects, ambient,
haptics, captions), notifications (warning, daily summary + time), child
experience (mini-games, quizzes, sit timer + duration), `parentGateStyle`,
`activeChildID`, `hasCompletedOnboarding`, `lastSeenReleaseVersion`.

Defaults that are product decisions: `spokenTextCaptionsEnabled = true` (helps
pre-readers' caregivers, deaf and hard-of-hearing families, and anyone with sound
off); `routineSitTimerEnabled = false` (a visible countdown is stressful for some
children); `dailySummaryEnabled = false` (an app should not notify by default);
`ambientAudioEnabled = false`.

### 2.8 `QuizProgress` / `GameProgress`

`[id: completionCount]` and `[id: lastCompletedDate]` as JSON, plus a
denormalised total. **Plays, not scores.** There is no percentage, no grade and
no high score — a high-score field would turn a two-minute hand-washing game into
something a child can fail at, and would give the app a number that can go down.
Both counters are monotonic by construction.

---

## 3. The reward ledger

### 3.1 Append-only by design

`RewardLedger` is a **value type** — it can be handed to the insights engine, a
preview or a test without anyone mutating the copy the app holds. Its only
mutation is `append`, which cannot remove, reduce or reorder.

There is deliberately no `remove`, `subtract`, `clear`, `expire` or `decay`.
`CONTRACTS.md` §4.2 is easiest to keep when the API that would break it does not
exist.

- Totals are **summed from rows, never stored.** A crash mid-write can lose *an
  award* (which the next attempt re-adds) but can never corrupt *a balance*.
- The key index (`idempotencyKey → id`) is derived state, rebuilt on decode rather
  than encoded, so it cannot disagree with the rows.
- `init(_ transactions:)` drops rows that violate the invariants: first writer
  wins on a duplicate key (the earliest row is the one the child saw a
  celebration for); non-positive quantities are dropped as unrepresentable.
- `append` returns `awarded` / `duplicate(existing:)` /
  `rejectedNonPositiveQuantity`. The distinction matters at the call site: a
  duplicate is a normal retry and must not surface as an error, while a
  non-positive quantity is a caller bug worth logging. `duplicate` returns the
  existing row so the caller can show the same celebration it would have shown
  the first time.

### 3.2 Idempotency scheme

```
hop.reward.v1|<childID lowercased>|<reason rawValue>|<scope>

scope ∈  event:<uuid>          a PottyEvent, written before the star
         session:<uuid>        a pause / quiz / game session, minted at start
         day:yyyy-MM-dd        rewards with no row of their own
         custom:<text>         imports and migrations that carry their own identity
```

Every component is a **pure function of data that was already durable before the
award was attempted.** A key containing a fresh `UUID()` or a wall-clock timestamp
would be unique per *attempt* — exactly wrong, because the retry after a crash
would look like a new award and the child would be credited twice for one routine.

Three details that are load-bearing:

| Detail | Why |
| --- | --- |
| UUID text is lowercased at the single point of construction | `UUID.uuidString` is uppercase in Swift, but keys also arrive from imports, JSON and older builds. A key must never fail to match itself on case. |
| `day:` is built from calendar **components**, not a `DateFormatter` | A formatter carries a locale, which can render a non-Gregorian year or non-ASCII digits. That would make the key depend on device settings, so the same day could award twice after a traveller changes region. |
| `version` is `v1` and changing it re-opens every collapsed award | So it never changes casually. |

Enforced in three places: the in-memory ledger's key index, the store's
`@Attribute(.unique) idempotencyKey`, and the `pauseID`-keyed drain of the
extension outbox.

### 3.3 Reconciliation after a caregiver deletes events

`RewardService.reconcile(ledger:against:)` breaks the link and **keeps the star.**
The transaction keeps its id, timestamp, quantity and — importantly — its
idempotency key, so a queued retry for the deleted event still collapses instead
of re-awarding. `RewardReconciliation.starsRemoved` is exposed purely so the
invariant is visible in a debugger and assertable in a test; it is always zero.

The one operation that does remove reward rows is the explicit **"Reset rewards"**
deletion (`DeletionOperation.resetRewards`): a caregiver exercising control over
records held about their family, on their device, behind the parent gate, after
reading the count. It is all-or-nothing on purpose — a selective "remove these
three stars" would be a punishment mechanism with a data-management label on it.

---

## 4. Migration strategy

`HopSchemaV1` is declared **on day one**, with `HopMigrationPlan` alongside it.
Retrofitting a plan later means the first release's store has no version stamp to
migrate *from*, and the second release either wipes a family's history or fails to
open.

`HopCurrentSchema` is a `typealias` — one symbol to change when a version ships.

The five rules:

1. **Additive by default.** New properties with defaults, or whole new models.
   Both are lightweight migrations: no code, no data loss.
2. **Never rename or retype in place.** The safe sequence spans two releases: V2
   adds the new property and backfills it in a custom stage; V3 stops writing the
   old one and drops it. Families skipping a release still land correctly because
   stages run in order.
3. **Enums are stored as their raw `String`.** A new `RewardReason` case is then a
   *content* change, not a schema change, and a row written by a newer build maps
   to a documented fallback (`HopStoredCoding.decodeEnum`) rather than failing the
   whole store.
4. **Composite values are JSON blobs** (`quietWindowsData`, `suspensionData`,
   `unlockedData`) encoded with a pinned strategy. A malformed blob degrades to a
   documented default inside the mapping layer — a caregiver opening the timeline
   must never see an error sheet about a JSON column.
5. **The idempotency key is never rewritten by a migration.** Rewriting it would
   re-open every previously collapsed award.

App Group payloads carry their own independent `schemaVersion: Int`. A reader that
finds a version it does not understand treats the record as **absent**, and
absence means "clear the shield" — the correct reading of a downgrade, a restored
backup, or a hand-edited container.

---

## 5. Screen Time tokens — what HopPotty holds and what it refuses to

Apple hands out `ApplicationToken`, `ActivityCategoryToken` and
`WebDomainToken` as **opaque** values. HopPotty treats them accordingly.

| Rule | Detail |
| --- | --- |
| **Never inspected** | No bundle identifier, no display name, no icon is read from a token in the app. The one place identity is legible in the system is inside the ShieldConfiguration extension, and it stays there. |
| **Never persisted as an identity** | `ScreenTimeConfiguration` stores three **counts** and an authorization status. There is no column anywhere for what was selected. |
| **Persisted only as Apple's own opaque blob** | The whole `FamilyActivitySelection` round-trips as `Codable` `Data` into `selection.json` in the App Group, because the monitor extension cannot shield without it, and because the whole selection round-trips correctly where loose token sets do not. |
| **Never logged** | Not raw, not hashed, not truncated, not counted into an analytics key. |
| **Never sent off-device** | There is no network path that could carry one. |
| **Never requested with data access** | `com.apple.developer.family-controls.app-and-website-usage` (iOS 26.4+) would give real identifiers. HopPotty declines it — there is no use for them and asking would be a privacy regression. |
| **Assumed revocable and expirable** | Tokens are voided on revocation and can expire. On `.unauthorized` the app clears the selection and routes the caregiver to re-authorize; it never silently keeps a dead selection. |
| **Capped** | Apple's limit is 50 tokens per shield property. The picker is capped and the cap is explained in caregiver copy; categories are preferred over long app lists. |

The consequence for the parent UI: HopPotty can say *"4 apps and 1 category will
pause"*. It cannot say *"YouTube will pause"*, and it must never imply it knows.

---

## 6. Repository layer

Seven protocols, all `@MainActor` (the whole dataset is a few thousand small rows;
a background context would buy contention, not throughput):

`ChildProfileRepository` · `PottyEventRepository` · `RewardRepository` ·
`PondProgressRepository` · `ScheduleRepository` ·
`ScreenTimeConfigurationRepository` · progress repositories.

Cross-cutting: **`ChildScopedRepository`** with `deleteAll(for:) -> Int` and
`count(for:) -> Int`. The counts are not a nicety — they are what the confirmation
sheet quotes back before the caregiver taps. Every child-scoped table conforms, so
`DataDeletionService` iterates a list instead of remembering nine method names,
and "we forgot to delete the quiz rows" becomes a compile error when a tenth table
is added.

`PottyEventQuery` is a struct rather than four defaulted parameters, so "did the
export use the same window as the chart?" is answerable. `childID` is **always
required**: there is no query in HopPotty that reads across children, because an
unscoped fetch is the bug that shows Maya's accidents on Sam's dashboard. The one
deliberate exception is `allSchedules()`, which exists to re-arm monitoring at
launch.

`RepositoryError` is deliberately small — unavailable, write failed, read failed,
not found. A malformed blob or an enum raw value from the future is handled inside
the mapping layer by degrading to a documented default.

---

## 7. Volumes and retention

| Entity | Rows for one child, one year | Retention |
| --- | --- | --- |
| `PottyEvent` | ~2,000–4,000 | Until the caregiver deletes it |
| `RewardTransaction` | ~1,500–3,000 | Until "Reset rewards" or profile deletion |
| `PondProgress` | 1 | " |
| `PottySchedule`, `ScreenTimeConfiguration`, quiz/game progress | 1 each | " |
| App Group `pause.json` | 1, overwritten | Deleted when the pause ends |
| App Group `outbox/*` | one per pause outcome | Deleted on drain |
| App Group `heartbeat/*` | 4, capped ring | Overwritten |

Nothing expires on its own. There is no retention timer, no auto-purge, and no
server-side copy. `Docs/PrivacyArchitecture.md` has the complete inventory.
