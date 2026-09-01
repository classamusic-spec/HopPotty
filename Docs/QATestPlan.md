# QA Test Plan

**Date:** 2026-09-01
**Related:** `Docs/PhysicalDeviceQA.md` (device scenarios), `Docs/Accessibility.md`
§3 (per-screen a11y checklist), `Docs/ReleaseChecklist.md` (submission gate)

---

## 1. Where the risk is, and where the tests are

| Risk | Consequence if wrong | Testable without Xcode? |
| --- | --- | --- |
| A shield outlives its pause | **A child holding a device that will not open anything** | Logic: yes. Runtime: **no** |
| A star awarded twice, or removed | The child notices, and it is the one thing they were promised | **Yes** |
| Quiet hours miscomputed across DST or travel | A pause fires during a nap | **Yes** |
| Shaming copy ships | Lands on a child who cannot argue back | **Yes** |
| A medical-sounding insight ships | A parent believes a claim about their child | **Yes** |
| An inaccessible colour ships | Text nobody can read | **Yes** |
| A view fails to lay out at AX5 | Truncated, unusable screens | **No** |
| Extensions never invoked (wrong extension point) | Looks exactly like a Screen Time bug | **No** |

The package boundary exists so that column three says "yes" as often as possible
(`ADR/0001`).

---

## 2. Current executable coverage

**`swift test` in `HopPottyKit/` — 350 tests across 28 suites, all passing**, on
Swift 6.2 for Linux (observed 2026-09-01). Swift Testing (`@Suite`, `@Test`,
`#expect`), not XCTest. This number moves as content lands; re-run it rather than
quoting it.

```bash
export PATH=/opt/swift/usr/bin:$PATH
cd HopPottyKit && swift test
```

| Suite | Covers |
| --- | --- |
| Potty Pause reducer totality | Every (state × event) pair — 14 state kinds, which expand to 50 distinct state values (one per `ScreenTimeFailure` for each of the three error cases), × 21 events = **1,050 pairs**. No pair is undefined; rejections are explicit and carry the evidence. |
| Potty Pause fail-safe invariants | "Entering an error state always clears" runs 1,050 cases. The parent exit is accepted from every state. No path holds a shield on an outcome. |
| Potty Pause lifecycle | The happy path, effect ordering, `.clearShield` first, access restored before the celebration. |
| Potty Pause cold-start recovery | All six verdicts; clock moved backwards; malformed and foreign-child records; star awarded only after real engagement. |
| Scheduling: quiet windows | Overlap precedence, back-to-back resumption, midnight wrap, half-open bounds. |
| Scheduling: DST and travel | Spring-forward gap, fall-back repeated hour, a 12:30 nap staying 12:30 across a zone change. |
| Scheduling: active window / active days / suspension / warnings / next pause (clock + activity) / summary | The whole gate, with `PauseBlockReason` precedence. |
| Reward service | Accidents earn nothing; duplicates collapse; reconciliation removes **zero** stars; day-scope keys are locale-proof. |
| Pond catalog · Pond progress | Monotonic prices, compile-time exhaustiveness, centroid stays centred, a lower total never shrinks a pond. |
| Insight thresholds · aggregates · interval suggestion | Below-threshold returns `nil`; determinism under event reordering; visit clustering; suggestion needs 20 gaps and a ≥10-minute delta. |
| Insight language safety | Every string the engine can emit, against ~70 forbidden fragments. |
| Child safety: copy | The whole `HopCopy` catalog and every `HopVoiceLine` against shame, medical and prescriptive vocabularies, plus length and non-empty checks — **and tests of the scanner itself**. |
| Copy catalog structure | Duplicate keys, placeholder/format-token agreement, name and plural variants. |
| Quiz · routine · mini-game · voice-line content | Every catalog is complete and internally consistent. |
| Palette contrast · colour value maths | WCAG AA across all four appearances; composite-then-measure. |

### 2.1 What "green" here does and does not mean

It means: the domain logic that decides when a pause happens, how it ends, what a
star is worth, and what words reach a family, behaves as specified under
adversarial inputs including crashes, clock changes and DST.

It does **not** mean the app builds, launches, lays out, or shields anything.

---

## 3. What needs Xcode

Not written; the project does not exist yet.

### 3.1 Unit tests (XCTest, app target)

| Area | Tests to write |
| --- | --- |
| SwiftData repositories | Round-trip every `@Model` ↔ domain value. Malformed blob → documented default, not a thrown error. Unknown enum raw → fallback. Unknown `PondItemID` dropped, siblings preserved. |
| Migration | V1 store opens. A synthetic V2 lightweight stage applies. Idempotency keys survive untouched. |
| `DataDeletionService` | Counts match rows for all four operations. Re-count before acting on a stale plan. **Orphaned stars kept, `starsRemoved == 0`.** A tenth child-scoped table is a compile error. |
| `AppGroupStore` | Atomic write is all-or-nothing. Unknown `schemaVersion` reads as absent. Outbox append/drain never read-modify-writes. Missing container degrades to "no session → clear". |
| `ShieldReconciler` | Every entry point clears when the record is expired, malformed, foreign or absent. |
| `ScreenTimeService` | Against a fake `AuthorizationCenter`: every `FamilyControlsError` maps to the right `ScreenTimeFailure`; `.cancelled` never presented as failure; clearing never fails from the caller's perspective. |
| `ParentAuthorization` | 15-minute expiry; reason scoping. |
| Presentation | Every `ScreenTimeFailure` and `ParentFailure` maps to exactly one presentation with the right recovery. |
| `HopLog` | The tag is stable within a launch; `safeDescription` never contains a message body. |

### 3.2 Integration tests (simulator, `HOPPOTTY_MOCKS`)

Family Controls behaviour in the Simulator is **UNVERIFIED**, so every simulator
test runs against the fake `ScreenTimeProviding`.

- Onboarding → first pause → star → pond unlock, end to end.
- Denied / cancelled / restricted authorization each land on the right screen and
  leave Gentle mode fully working.
- Kill the app mid-pause; relaunch clears and records `interruptedByProcessDeath`.
- Purchase, cancel, Ask-to-Buy pending, restore — all four outcomes.
- Delete a child while a pause is in flight for that child.
- Two children, switching between them, no cross-contamination.

### 3.3 UI tests (XCUITest)

- Parent gate blocks Parent Space; passing it opens; it expires after 15 minutes.
- A child cannot reach any purchase, destructive action or external link from
  Child Space.
- Every destructive confirmation shows counts before the action.
- The full routine is completable, and leaving mid-routine is always allowed.
- Quizzes never end on a wrong answer.
- Accessibility audit pass (`performAccessibilityAudit`) on every screen.
- Screenshot generation at default and AX3, light and dark.

### 3.4 Manual, device-only

`Docs/PhysicalDeviceQA.md` is the authority. The nine open UNVERIFIED items from
`ScreenTimeArchitecture.md` §12 are the priority, because code already depends on
the answers:

1. Do shield settings survive a reboot? A force-quit? An app update?
2. Are `intervalWillEndWarning` callbacks gated on "device in use", and how
   punctual are they? *(This is the intended pause duration.)*
3. The monitor extension's real memory ceiling and time budget.
4. What happens when a shield property exceeds 50 tokens.
5. After `clearAllSettings()` + `.close`, where does the child land, and does the
   shield redraw?
6. Does `ApplicationToken` expire below iOS 26.5, and what does a stale token do
   to a live shield?
7. Does Family Controls authorization work in the Simulator at all?
8. Minimum usable `DeviceActivityEvent.threshold` granularity.
9. Is `Application.localizedDisplayName` reliably non-`nil` in the shield
   configuration extension?

Plus the scenarios that only hardware can produce:

- Airplane mode during authorization.
- Low Power Mode across a pause.
- Device restart mid-pause (the shield extensions must self-heal).
- Storage full during a write.
- Authorization revoked in iOS Settings while a shield is up.
- A second parental-controls app installed → `authorizationConflict`.
- Time zone change and a DST transition with a live schedule.
- Manually changing the device clock backwards mid-pause.
- The shield rendered under every accessibility setting.

---

## 4. Test data

`HopPottyFixtures` provides deterministic sample data. Rules:

- No fixture uses a real child's name.
- Every date-sensitive fixture takes an explicit `now` and `Calendar`; nothing
  reads `Date()` or `TimeZone.current`.
- DST fixtures use real transition dates in named zones, not synthetic offsets.

---

## 5. Regression policy

| Class of bug | Required response |
| --- | --- |
| A shield outlived its pause | A failing test in the fail-safe or cold-start suite **before** the fix, plus a device scenario in `PhysicalDeviceQA.md`. |
| A star doubled or removed | A failing test in the reward suite before the fix. |
| Shaming or medical copy shipped | The vocabulary list grows in the same commit as the copy fix. |
| A contrast failure | The colour changes; the assertion is never relaxed. |
| A pause fired in a quiet window | A scheduling test with the exact instant and zone. |

Weakening a safety vocabulary or a contrast bar requires an edit to
`CONTRACTS.md` and a named reviewer.

---

## 6. CI (proposed; no CI exists yet)

| Stage | Runs on | Gate |
| --- | --- | --- |
| `swift build && swift test` in `HopPottyKit` | Linux | **Blocking.** Already possible today. |
| `swift run hoptokens` diff against `Scripts/tokens.json` | Linux | Blocking — a token change must not silently skip the render harness. |
| `Scripts/verify-config.sh` | Linux | Blocking — bundle IDs, App Group, deployment target, Release-build conditions, entitlements, extension principal classes, StoreKit product id and shared-file target membership. **Exists and passes today** (52 checks, exit 0); it just needs a CI job to run it. |
| `xcodebuild build` (4 targets) | macOS | Blocking, once a project exists. |
| `xcodebuild test` (unit + UI) | macOS | Blocking. |
| Release-build check: no `HOPPOTTY_DEBUG_TOOLS`, no mock condition, no `Developer/` source | macOS | Blocking. |
| Device suite | Manual | Release gate, recorded in `PhysicalDeviceQA.md`. |

---

## 7. Honest coverage summary

| Layer | State |
| --- | --- |
| `HopPottyCore` + `HopPottyDesignTokens` | **350 tests, 28 suites, passing.** Genuinely verified. |
| App target (SwiftUI, SwiftData, services) | Written, **never compiled**, zero tests. |
| Three Screen Time extensions | Written, **never compiled**, zero tests. |
| Screen Time runtime behaviour | **Never observed.** No device, no entitlement. |
| Accessibility | Contrast enforced by tests; the rest is a written, **unexecuted** checklist. |
| Performance | No Instruments profiling has been done. |
| Localisation | English only; keys and placeholders are structurally checked. |

Roughly half the product's risk is genuinely tested. The other half is written and
unverified, and no claim in this repository should be read otherwise.
