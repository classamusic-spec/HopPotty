# Security Review

**Date:** 2026-09-01
**Scope:** The HopPotty app, its three Screen Time extensions, `HopPottyKit`, and
the repository itself.
**Status:** A design review against the code as written. **Nothing has been
built, run, fuzzed, or profiled.** No penetration test, no proxy capture, no
binary analysis has been performed, because there is no binary.

---

## 1. Threat model for a local-first child app

There is no server, no account and no network path carrying user data, so the
usual top of the list — credential theft, API abuse, server-side injection, token
leakage in transit — is **structurally absent**. What remains:

| # | Adversary | Capability | What they want | Severity |
| --- | --- | --- | --- | --- |
| 1 | **The child** | Holds the unlocked device; taps everything | To escape the pause, to buy something, to delete a sibling's stars — mostly by accident | **High likelihood, low impact** |
| 2 | **A bug in HopPotty** | Full app privileges | Nothing — but it can strand a shield, double a star, or leak a nickname into a log | **The dominant risk** |
| 3 | **Someone with the unlocked device** | Console.app over USB; Files; an export | The child's timeline, notes, nickname | Medium |
| 4 | **Someone with a device backup** | The app container and App Group container | Same | Medium; mitigated by Apple's backup encryption |
| 5 | **A support-desk chain** | A sysdiagnose the family was asked to send | Log contents | **Medium — the realistic leak path** |
| 6 | **A hostile app on the device** | Its own sandbox | HopPotty's container | Low — iOS sandbox; App Group is entitlement-scoped |
| 7 | **A malicious repository contributor** | A pull request | To weaken a safety rail or add telemetry | Medium |
| 8 | **A physical attacker with the locked device** | Whatever iOS allows | Everything | Out of scope; Data Protection is the control |

Two observations shape everything below. First, **the most likely attacker is a
four-year-old**, and the correct control is a parental gate, not cryptography.
Second, **the highest-impact failure is not a breach — it is a stranded shield**,
which is a safety property, handled in `TechnicalArchitecture.md` §6.

---

## 2. Storage protection

| Store | Protection | Notes |
| --- | --- | --- |
| SwiftData store (app container) | iOS Data Protection, default class | Encrypted at rest with the device passcode. **Action:** confirm the effective protection class once a device build exists, and consider `NSFileProtectionCompleteUntilFirstUserAuthentication` explicitly rather than relying on the default. |
| App Group container | Data Protection, readable by the four entitled targets | Deliberately carries the minimum: no child identifier, no free text, no ledger. |
| Private `UserDefaults` | One boolean ("authorization was once granted") | Not in the App Group — no extension needs it. |
| Keychain | **Not used.** No entitlement, no keychain group | There is no secret to store. |
| `ManagedSettingsStore` | System state, outside HopPotty's container | HopPotty can set and clear it; it cannot read another app's. |
| Exported file | Written into the app's own container, then moved by the caregiver | Once moved, it is the caregiver's file and the caregiver's risk. |

**No data is encrypted a second time by HopPotty.** Rolling our own encryption on
top of Data Protection would add a key-management problem and a data-loss mode in
exchange for no additional adversary being defeated.

---

## 3. Secrets in source

**There are none, and there is nothing that needs one.** No API key, no shared
secret, no certificate, no receipt-validation key (StoreKit 2 verification is
Apple's).

| Control | State |
| --- | --- |
| `Config/Secrets.xcconfig` (Team ID) | **Git-ignored.** Only the `.example.` template is tracked, and it holds an identifier, not a credential. |
| `.gitignore` | Blocks `*.p12`, `*.mobileprovision`, `*.cer`, `Secrets.xcconfig` |
| `DEVELOPMENT_TEAM` in tracked config | Deliberately **empty**, so a missing team is a loud Xcode error rather than a wrong value baked into a commit |
| Bundle IDs / App Group | Placeholders (`com.hoppotty`, `group.com.hoppotty`) with instructions to replace them; a verification script is referenced by the configs to keep the Swift constants and the build settings from drifting |
| Third-party dependencies | **Zero at runtime.** `Package.swift` declares no external packages, so there is no supply chain to audit and no transitive dependency that could exfiltrate anything |

**Verification:** `git grep -nEi "api[_-]?key|secret|password|token *=|BEGIN (RSA|EC|PRIVATE)"`
should return only documentation and the Screen Time *token* discussion.
Recommended as a CI step; also add a secret-scanning hook before the first public
push.

---

## 4. Logging

Reviewed in full in `PrivacyArchitecture.md` §4. The security-relevant summary:

- A log line is not a private place. `OSLog` output is readable in Console.app by
  anyone with the unlocked device and a Mac, and is collected into sysdiagnose
  archives that families email to support desks. **This is the realistic leak
  path for this app.**
- The rule is structural: **the identifying value never enters the logging call.**
  Never logged — nicknames, free-text notes, app/category selections, raw child
  UUIDs, or an event kind tied to a time.
- Child identity in logs is a four-hex tag from `UUID.hashValue`, which Swift
  seeds per process: usable within one launch, useless across two sysdiagnoses.
- Errors are logged as `domain#code`, because `localizedDescription` on a
  SwiftData failure can interpolate the offending row's values into the message.
- Eight closed categories; a catch-all category is forbidden by design.

**Gap:** no automated check that a new `HopLog` call does not interpolate a
nickname. A lint rule or a test asserting that no logging call site takes a
`String` from a domain model would close it. **Not written.**

---

## 5. Export sanitisation

The export is the one deliberate egress. Requirements:

1. **Caregiver-initiated only**, behind the parent gate (`exportData`), never
   automatic and never scheduled.
2. **Written into the app's own container.** HopPotty performs no upload; the
   caregiver moves the file.
3. **Caregiver notes are opt-in at export time**, because they are frequently the
   most sensitive field in the store.
4. **Never exported:** Screen Time tokens or any encoded `FamilyActivitySelection`
   (opaque, and useless outside this device anyway); log material; App Group
   breadcrumbs; internal idempotency keys; the "authorization was once granted"
   flag.
5. **Identifiers:** raw child UUIDs should be replaced with a per-export
   sequential label ("Child 1"), since the UUID is useful only for joining an
   export back to a log archive.
6. **Injection safety:** a CSV export must neutralise formula injection — a note
   beginning `=`, `+`, `-` or `@` opens as a formula in a spreadsheet. Prefix with
   `'` or quote defensively. JSON must be produced by `JSONEncoder`, never by
   string concatenation.
7. **Determinism:** the same data exports identically twice, so a caregiver can
   diff two exports.

**Status: unverified.** `DataExportProviding` is declared; the implementation is
not present at review time. Items 5 and 6 must be checked when it lands.

---

## 6. Internal state validation

Every value that crosses a trust boundary — disk, an App Group file, a decoded
blob, a migration — is validated rather than assumed.

| Input | Validation | Failure behaviour |
| --- | --- | --- |
| `PersistedPauseSession` | `isWellFormed`: state must be persistable, duration > 0 and ≤ max + slack; `belongs(to:)`; `isFromTheFuture` | Any failure → **clear the shield** and continue |
| App Group records | `schemaVersion` must match | Unknown version → treat as absent → clear |
| `pause.json` end instants | `let`, written once at pause start | No process can lengthen a pause |
| Pause duration from a schedule | Re-clamped at the context boundary (`PottyPauseContext.pauseDuration`) | A corrupted or migrated schedule cannot write an hour-long shield |
| `LocalTimeOfDay` | Normalises out-of-range values modulo 1440 | Degrades to a sane time; never traps |
| `activeDays` decoded empty | Treated as *every day* | `Codable` bypasses initialisers, so this is re-checked in the service |
| Nickname | Trimmed, empty → `nil`, capped at 24 | Applied in the model, so import and UI get the same guarantee |
| `RewardTransaction.quantity` | Clamped non-negative; ledger rejects ≤ 0 | Rejected, logged as a caller bug |
| Duplicate idempotency key | First writer wins in the ledger; `@Attribute(.unique)` in the store | Duplicate collapses silently — a normal retry |
| Enum raw values from a newer build | `HopStoredCoding.decodeEnum` documented fallback | Row survives; the whole store does not fail |
| Unknown `PondItemID` | Dropped | The child's other decorations still appear |
| Malformed JSON blob | Documented default inside the mapping layer | A caregiver never sees an error sheet about a JSON column |
| Insight strings | `InsightLanguagePolicy.checked` | Traps in debug; neutral fallback in release |

The reducer itself is **total**: every (state, event) pair is defined, so there is
no undefined transition an attacker or a bug could steer into. Rejections are
explicit values carrying the state, the event and the reason.

**A crash in a Screen Time extension is a security-relevant event**, not just a
bug: a crashing shield extension yields Apple's default shield, which carries
Apple's copy instead of HopPotty's. Every extension path is written to do nothing
and record a breadcrumb rather than to fail.

---

## 7. Debug surfaces

The **Potty Pause Lab** can start and end pauses without a real Screen Time
authorization. A build that can reach it must never reach a customer. Two
independent mechanisms, because one of them is a promise and the other is a fact:

1. `HOPPOTTY_DEBUG_TOOLS` is defined **only** in `Debug.xcconfig`, so
   `#if HOPPOTTY_DEBUG_TOOLS` code is not compiled into Release.
2. `Release.xcconfig` additionally removes `HopPotty/Developer/*` from the
   compiled sources via `EXCLUDED_SOURCE_FILE_NAMES`, so a file someone forgot to
   wrap still cannot ship.

Similarly, mock services are selected at **compile** time
(`AppBuildConfiguration`), never at runtime. A runtime switch that can select mock
services is a switch that can be flipped in a shipping build.

Release also carries no `DEBUG` and no mock condition. `Scripts/verify-config.sh`
asserts exactly that — plus that `DebugMock` defines `HOPPOTTY_MOCKS`, matching
the `#if` in `AppConfiguration.swift` — and passes today.

| Item | Status |
| --- | --- |
| `EXCLUDED_SOURCE_FILE_NAMES` in this absolute-path spelling | **UNVERIFIED.** Documented as glob patterns and used in Apple's own templates, but never exercised here. Confirm before the first submission; the `#if` guards remain primary. |
| `HopPotty/Developer/` | Exists: `DeveloperSurface.swift` (a `#if`/`#else` debug/release seam) and `PottyPauseLab.swift` (wholly inside a debug-only condition). `Scripts/verify-config.sh` asserts both. |
| No URL scheme | `CFBundleURLTypes` is deliberately absent — a parental-controls app that can be driven from a link is one a child can drive. |
| No background modes beyond DeviceActivity | Deliberate; anything else invites App Review questions we cannot answer well. |

---

## 8. Attack surface inventory

| Surface | Exposure | Control |
| --- | --- | --- |
| Network | **None.** No backend, no analytics, no remote config, no runtime asset fetch | Nothing to attack. Verify with a proxy capture on device. |
| URL schemes / universal links | **None** | Not declared |
| Share extensions, document types, drag-and-drop import | **None** | Not declared |
| App Group container | Four entitled targets | Minimal payloads, versioned, no free text, no child identity |
| Pasteboard | Not used for sensitive data | Confirm on device |
| Screenshots / app switcher | Timeline visible in the snapshot | Consider obscuring on backgrounding — **open question**, weighed against a caregiver's convenience |
| Third-party code | **None at runtime** | No supply chain |
| IPC | Only Apple's extension mechanism | Nothing custom |
| StoreKit | Apple's | Verification is StoreKit 2's; HopPotty stores no receipt |

---

## 9. Findings and actions

| # | Finding | Severity | Action |
| --- | --- | --- | --- |
| 1 | Data Protection class relied on by default, never confirmed | Medium | Set and verify an explicit protection class on the SwiftData store and App Group files on the first device build |
| 2 | No automated guard against a future `HopLog` call interpolating user text | Medium | Add a lint rule or a test over logging call sites |
| 3 | Export sanitisation (identifier replacement, CSV formula injection) unimplemented | Medium | Implement with the exporter; test both |
| 4 | `EXCLUDED_SOURCE_FILE_NAMES` spelling unverified | Medium | Verify by deleting a `#if` guard in a Lab file and confirming Release still builds |
| 5 | App-switcher snapshot may show a child's timeline | Low | Decide deliberately; document either way |
| 6 | Bundle IDs and App Group are placeholders (`com.hoppotty`, `group.com.hoppotty`) in two places | Low, but silent at runtime | `Scripts/verify-config.sh` already asserts the two agree and passes; it needs a CI job, and the placeholders need replacing with an owned prefix before the first device build |
| 7 | No secret scanning in CI | Low | Add before the repository is public |
| 8 | No binary, so no static analysis, fuzzing or Instruments run | — | Blocked on Xcode |

---

## 10. What this review cannot say

It cannot say the app is secure. It says the design has no server to breach, no
secret to leak, no third-party code to trust, and a set of validation rules that
resolve every ambiguity toward the child having access to their apps.

Confirming that the built product behaves that way requires a build, a device,
and a proxy — none of which exist yet (`BUILD_STATUS.md`).
