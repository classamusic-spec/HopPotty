# The first build

**What this is:** the record of the first time anyone handed this repository to
a compiler, what it found, and what was done about each thing. Written while it
happened, in the order it happened, so the shape of the failure is visible and
not just the fix.

**Why it reads oddly:** every Swift file in the app and its four extensions was
written without a compiler ever seeing it (`Docs/RepositoryAudit.md`). Several
authors worked in parallel against each other's *described* APIs rather than
their real ones. So the errors below are not a normal bug list. They are what
you get when a large, carefully-designed codebase meets a type checker for the
first time, and they cluster exactly where you would predict: at the seams
between things different people wrote.

---

## How it was compiled

`.github/workflows/ci.yml`, job **App and extensions (Xcode)**, on a `macos-15`
runner: XcodeGen generates the project, then

```
xcodebuild build -project HopPotty.xcodeproj -scheme HopPotty-Mock \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

Four facts about that command shape everything below.

| | |
| --- | --- |
| **`SWIFT_VERSION = 6.0` with `SWIFT_STRICT_CONCURRENCY = complete`** | Actor-isolation and `Sendable` violations are errors, not advice. |
| **`SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`** | A warning fails the build. `@preconcurrency import`, which only downgrades a concurrency error to a warning, is therefore **not** a fix here. |
| **Target triple is `…-ios17.0-simulator`, SDK is iOS 26.2** | Availability *is* checked against the 17.0 deployment target, so using an API newer than iOS 17 without a guard is a real error and CI does catch it. What CI cannot catch is a symbol that exists only in an SDK newer than 26.2 — see layer 2. |
| **`CODE_SIGNING_ALLOWED=NO`** | The job never signs, so it can prove nothing about entitlements, provisioning or App Groups. Those failures are in the table at the end. |

**A build stops at the first failing target**, and the app target depends on all
four extensions. So the layers below are strictly sequential: nothing in the app
was type-checked until every extension compiled.

---

## Layer 1 — Screen Time concurrency and a `Name` that was never a literal

*Run 54, the first build ever. 6 errors, one file family, one framework.*

`ManagedSettings` predates Swift 6 and annotates nothing `Sendable`.

* **`ManagedSettingsStore.Name` does not conform to `ExpressibleByStringLiteral`.**
  A genuine API mistake rather than a concurrency complaint: the store name had
  been written as a string literal, and the comment above it admitted the author
  had guessed at exactly that. Now uses the unlabelled `init(_:)`, which the next
  build confirmed exists.
* **`Name` and `Token<T>` are not `Sendable`** (5 errors). Marked
  `nonisolated(unsafe)` and `@unchecked Sendable` with the reasoning written in
  place: a `Name` is an immutable `String` wrapper and a `Token` is an opaque,
  immutable, `Codable` value, so both are genuinely safe to send. This is the
  standard the rest of the file follows.

---

## Layer 2 — a widget asking for a sentence nobody had written

*Run 56. 1 error.*

```
NextPauseWidget.swift:339:41: error: value of type 'QuickReminderCopy'
                              has no member 'emptyState'
```

The predicted seam failure, in its purest form. The widget reached for
`HopCopy.quickReminder.emptyState` — a Quick Reminder string, on a Potty Pause
widget — which would have been the wrong sentence even if it had existed.

What the widget actually needed was a line for *"the schedule is on and nothing
is projected"*, and no such string existed anywhere. The parent home card never
needed one, because it has `blockReason` and can be specific ("Quiet until 2:30
PM", "Skipping the next one"). `WidgetSnapshot` deliberately carries no reason:
the reason a family's afternoon is quiet is a fact about that family, and a lock
screen is read by whoever is standing nearby.

So the fix is a **new** entry rather than a redirect to an existing one —
`parentHome.hero.nothingScheduled`, *"Nothing waiting right now."* — worded to
be true whichever reason applies, which is the property the widget needs.

**This was checked for scale, not just fixed.** All 261 `HopCopy.x.y` references
across the app and four extensions were resolved against the declared members of
all 19 sections. This was the only one that did not exist.

---

## Layer 3 — the iOS 26.5 shield gate, measuring the wrong thing

*Run 57. 1 error. **This one still needs a decision.***

```
HopPottyShieldActionExtension.swift:222:21: error: type 'ShieldActionResponse'
                                           has no member 'openParentalControlsApp'
```

The interesting part is why the guard did not save it. The block was wrapped in
`#if compiler(>=6.2)`, and the comment above it explained — correctly — that
`#available` is a *runtime* check and the case must exist in the SDK at compile
time. It then gated on the compiler version anyway.

**Compiler version does not track SDK version.** Xcode 26.3 ships a Swift 6.2
compiler alongside a 26.2 SDK, so `compiler(>=6.2)` is satisfied and the missing
case is reached regardless. The guard measured the toolchain; the risk was in
the SDK.

Swift has no `#if the SDK has this symbol`. The options were:

1. delete the block — which the original comment invited ("if the case name is
   wrong, delete this block");
2. an `[sdk=iphoneos26.5*]` condition in the xcconfig — which would silently
   switch the behaviour on for whoever happens to have a newer Xcode, i.e. a
   shield that launches an app in front of a child on one machine and not
   another, decided by nobody;
3. a flag a person turns on deliberately, once, where the reasoning lives.

It is now (3): **`HOPPOTTY_SHIELD_CAN_OPEN_APP`**, declared and commented out in
`Config/Base.xcconfig`.

Nothing is lost while it is off, and that is why it can be a flag rather than a
decision that had to be made now. By the time that line is reached the store is
cleared, the report is filed and the star is banked in an append-only idempotent
ledger. It only decides *where the child ends up*, and `.close` is what the rest
of the design assumes and what every child-facing string is already worded for —
no copy anywhere promises an immediate star.

> **Decision needed from a human.** Whether to enable the flag once an SDK that
> has `ShieldActionResponse.openParentalControlsApp` is in hand — and, before
> that, to confirm on hardware that it opens HopPotty rather than a Settings
> pane. It has never been verified that this case exists under this spelling at
> all; the class doc used to promise "on iOS 26.5+ the child does see it land
> immediately", and that promise has been withdrawn.

---

## Layer 4 — the app target, 48 diagnostics, seven causes

*Run 59. The first time any of the 182 SwiftUI files was type-checked.*

48 Swift diagnostics, 0 linker or resource errors. **A list of 48 looks like a
rewrite; the seven causes underneath it look like an afternoon.**

### 4.1 `ScreenTimeFailure` did not conform to `Error` — 23 errors, 9 files

It is the failure half of nineteen `Result<_, ScreenTimeFailure>` signatures
across the Screen Time layer, and `Result` constrains `Failure: Error`. One
missing word in one conformance list, reported once per call site.

`Error` requires nothing to implement, so nothing else changed. What it adds is
the ability to `throw` one, which is the right capability for this type anyway.

### 4.2 Three `ButtonStyle`s had a nested view named `Body` — 6 errors, 3 files

```
error: struct 'Body' must be as accessible as its enclosing type
       because it matches a requirement in protocol 'ButtonStyle'
error: type 'HopButtonStyle' does not conform to protocol 'ButtonStyle'
```

A trap worth remembering. `ButtonStyle` declares `associatedtype Body: View`,
and **a nested type whose name matches an associated type wins inference over
the `some View` that `makeBody` actually returns.** So a deliberately `private`
implementation view silently became the style's associated type — and was then
less accessible than the style itself.

Renamed to `StyleBody` rather than made `internal`: the view is private on
purpose, and the only thing wrong was a name colliding with a protocol
requirement. Every site now carries a comment saying so, because this will be
walked into again.

### 4.3 Two `Animatable` conformances crossed the main actor — 2 errors

```
error: conformance of 'HopPageShift' to protocol 'Animatable' crosses into
       main actor-isolated code and can cause data races
```

`ViewModifier` is a `@MainActor` protocol, so conforming to it makes the struct
main-actor isolated. `Animatable` is not, and SwiftUI's animation machinery
drives `animatableData` on its own terms.

`nonisolated` is the fix, and it is a **safe** one rather than a silencing one:
both types are value types whose every stored property is a `Double`, so the two
domains animate separate copies and there is nothing to race over. That is also
why the compiler *permits* `nonisolated` to touch the storage at all — SE-0434
allows it for `Sendable` storage in a global-actor-isolated value type. Had any
property been a reference, the compiler would have refused and the fix would
have had to be a real one. Written down at both sites.

### 4.4 `NotificationPermission` was not `Codable` — 2 errors

Reported against `OnboardingDraft`, which *is* `Codable`, is persisted after
every change so an interrupted setup resumes with the nickname already typed,
and stores one of these. The error named the container; the omission was in the
member.

### 4.5 Four `DeletionReceipt` construction sites used an initializer that does not exist — 10 errors, 2 files

They passed `childName:events:stars:decorations:children:` — which are the
receipt's *computed read accessors*, not its stored properties. The real
initializer takes `scope:childNickname:counts:completedAt:`.

Fixed at the call sites rather than by adding a convenience initializer: all
four are preview code, and a preview that builds the real value the real way is
worth more than one that compiles through a shim built for it.

### 4.6 Two `public` declarations took internal parameter types — 3 errors, 2 files

`ScreenTimeEnvironment.resolved` (internal `AppBuildConfiguration`) and
`PottyPauseEffectExecutor.init` (internal `WidgetRefreshing`,
`LiveActivityControlling`).

Demoted to `internal` rather than promoting the types. This is an app target, so
`public` is inert in it, and both were outliers — `ServiceContainer.resolved` and
`LiveActivityController.resolved` are the peers they mirror, and both were
already internal.

### 4.7 The two earlier fixes

Layers 2 and 3 above, which had to land before the app target compiled at all.

---

## Layer 5 — the last three, one of each kind

*Run 60. 48 down to 3, and the three are one clean example each of the three
kinds of thing that were ever wrong here.*

**An actor-isolation slip.**

```
SchedulePreviewCard.swift:146:54: error: main actor-isolated static property
                                  'previewCalendar' can not be referenced from
                                  a nonisolated context
```

`ParentEnvironment` is `@MainActor`, so everything hanging off it is too. A
file-scope `private func` is nonisolated by default, which made `previewSummary`
the one caller of `previewCalendar` that was not already on the main actor.
Annotated `@MainActor`: every call site is a `#Preview` body, which is
main-actor anyway, so the annotation costs nothing and states what was already
true.

**A wrong-shaped write.**

```
SettingsModel.swift:68:24: error: cannot assign to property: 'childName'
                           is a get-only property
```

`DeletionReceipt.childName` is a read accessor over a `let`. The receipt is
immutable on purpose — a receipt that can be edited after the fact is not a
receipt. The line was also redundant: `DataDeletionService` already resolves the
nickname from `repositories.profiles` while it counts, which is the same fact
from a more authoritative place at a better moment (read from the store as the
numbers are taken, rather than from this screen's in-memory copy afterwards).
Removed, with the reasoning in place.

**An API that does not exist.**

```
ScreenTimeService.swift:264:15: error: type 'FamilyControlsError' has no
                               member 'unauthorized'
```

`ScreenTimeFailure.map(_:)` carried a note: *"UNVERIFIED — confirm the exact
spelling of every case below. If one does not exist, delete the case; the
`default` branch already maps it to `.unknown`."* The compiler has now checked
all seven against the iOS 26.2 SDK. **Six exist. `.unauthorized` does not**, and
has been removed on that instruction. `.authorizationCanceled` and `.restricted`,
used by the two predicates beside it, both exist.

Note what this does and does not settle. The *spellings* are now verified. Which
of these the framework actually raises, and for what, still needs a device and
an approved entitlement.

---

## What was checked by reading rather than by building

A compiler reports the first thing it trips over, not the size of the hole. So
each error class above was also audited across the whole repository, to tell
"one mistake" apart from "the first of forty". All of these came back clean:

| Audit | Result |
| --- | --- |
| Every `HopCopy.<section>.<member>` reference resolved against all 19 declared sections | 261 references, **1** failure (§4.2 above), now 0 |
| `theme.color`, `theme.spacing`, `theme.radius`, `theme.hitTarget` member references | 44 distinct members used, **0** undeclared |
| Argument labels at every `Hop*` initializer call site vs. declared initializers | 235 types, **0** mismatches |
| Project-named types referenced but never declared | **0** (every unresolved capitalised name was an Apple framework) |
| Named asset lookups (`Image("…")`, `Color("…")`) vs. the near-empty asset catalogue | **0** lookups — everything is drawn in code, so the catalogue cannot bite |
| `@available`/`#available` usage above the iOS 17.0 floor | 1 site, layer 3, handled |

The DesignSystem ↔ Features and Services ↔ Features seams turned out to be in
much better shape than the parallel-authorship history predicted. The failures
were concentrated, not spread.

---

## What CI still cannot tell you

The macOS job builds for the Simulator and **never signs anything**. That makes
a whole family of failures invisible to it — they appear the first time a person
builds to a device. It also cannot exercise Screen Time at all: the mock scheme
swaps the Family Controls layer out at compile time, and the Simulator has no
meaningful implementation either way.

### If you see X, it means Y

Signing, provisioning and entitlements — none of which CI touches:

| What you see | What it means |
| --- | --- |
| `Signing for "HopPotty" requires a development team` | `HOPPOTTY_DEVELOPMENT_TEAM` is empty in `Config/Secrets.xcconfig`. That file is created by `Scripts/bootstrap.sh` from the template, git-ignored, and starts empty — which is correct for CI, and not enough for a device. `Docs/RunningLocally.md` Step 6. |
| `Failed to register bundle identifier` | `com.hoppotty` is a placeholder nobody here owns. Change `HOPPOTTY_APP_BUNDLE_ID` in `Config/Base.xcconfig` **and** the matching literals in `HopPotty/Services/ScreenTime/ScreenTimeIdentifiers.swift`, in the same commit — `Scripts/verify-config.sh` fails if the two drift. |
| `Provisioning profile … doesn't include the com.apple.developer.family-controls entitlement` | Family Controls needs a **paid** Apple Developer account, and the *distribution* entitlement needs Apple's approval. `Docs/Entitlements.md`. |
| The same error on an *extension's* profile only | An extension's App ID needs the capability enabled separately. All three Screen Time extensions carry it; the widget extension deliberately does not. |
| Everything builds, installs, runs — and nothing ever pauses | Almost always the App Group. `HOPPOTTY_APP_GROUP` must equal `ScreenTimeIdentifiers.appGroupID` **exactly**, and every target must be a member. A mismatch is silent at build time and total at runtime: `UserDefaults(suiteName:)` returns `nil`, the container URL is unavailable, and the app and its extensions stop seeing each other's state while every target still builds and signs. |
| A shield appears and never clears, or a star is never awarded | Same cause as above, one layer down. Check the App Group before anything else. |

XcodeGen and target membership — CI runs `Scripts/bootstrap.sh`, so it catches
most of these, but not the ones that only bite an existing checkout:

| What you see | What it means |
| --- | --- |
| `xcodegen: command not found` / `bootstrap failed: XcodeGen is not installed` | `brew install xcodegen`. |
| `bootstrap failed: XcodeGen … is older than project.yml requires` | `project.yml` uses `optional: true` on a source path; older XcodeGen rejects it. `brew upgrade xcodegen`. |
| `bootstrap failed: Config/Secrets.xcconfig is tracked by git` | It was committed by mistake. `git rm --cached Config/Secrets.xcconfig`. Signing material must never be tracked. |
| `Multiple commands produce …/Info.plist` | A file consumed through `INFOPLIST_FILE` or `CODE_SIGN_ENTITLEMENTS` is also being picked up as a resource. The `excludes:` list in `project.yml` exists to prevent exactly this; something was added without being excluded. |
| `Cannot find 'AppGroupStore' in scope` in an *extension* | A shared source file lost its target membership. Four files must be members of all three Screen Time extensions (`AppGroupStore`, `SharedPauseTypes`, `ShieldReconciler`, `ScreenTimeIdentifiers`) and `WidgetSnapshotStore` of the widget and monitor extensions. `Scripts/verify-config.sh` checks each one. |
| An extension builds but the system never invokes it | It is built but not **embedded**. `project.yml` embeds all four explicitly (`embed: true`), because `transitivelyLinkDependencies` is off on purpose so that list stays honest. |
| Xcode behaves strangely right after a `git pull` | `HopPotty.xcodeproj` is a build artefact and goes stale whenever files are added or renamed. Re-run `Scripts/bootstrap.sh`. Never edit the project in Xcode's target editor and expect it to survive. |

---

## Layer 6 — a wrong diagnosis, and what it was worth anyway

*Runs 61 and 62. No new errors — a detour, written down because it is the kind
of mistake that looks like evidence.*

For forty-six minutes the GitHub Actions API reported run 61's Build step as
still running. Every earlier build had finished in about two minutes, so the
obvious reading was that this one had finally type-checked clean and was now
doing the code generation and linking that failing builds never reach — or that
it had hit the classic SwiftUI runaway type-check.

**Both readings were wrong.** The job had actually finished at minute two. The
API's job status was stale by more than forty minutes; the job *log*, fetched
directly, had the answer the whole time. The tell was visible and got explained
away: the two Linux test jobs, which take about forty seconds, were also being
reported as forty minutes into a build step.

The lesson is small and general: **the run log is evidence, the run status is a
cache.** When they disagree, believe the log — and read the timestamps *inside*
the log, which are the only clock in the picture that is not lagging.

One further trap, learned the same way: log *availability* lags too. Asking for
a job's log and getting a 404 does not mean the job is still running; it means
the log is not published yet. Runs 62 and 63 each took **about ninety seconds**
while returning 404s and `in_progress` for the better part of an hour.

The changes made on the strength of the wrong diagnosis were kept, because each
stands on its own without it:

* **`timeout-minutes: 45`.** The GitHub default is six hours. A runaway
  type-check is a real SwiftUI failure mode and would have burned all six while
  reporting nothing. Ordinary hygiene, arrived at by an unnecessary route.
* **`ARCHS=arm64`.** A generic Simulator destination builds `arm64` *and*
  `x86_64` by default: two complete passes over the whole app to answer one
  question. Type checking, actor isolation and every Swift diagnostic this job
  exists to catch are architecture-independent.
* **`CLANG_ENABLE_CODE_COVERAGE=NO`.** The scheme gathers coverage for its
  *test* action and this job never runs tests — but the setting still reached
  the compiler as `-profile-generate -profile-coverage-mapping`, instrumenting
  every function for a profile nothing would read. (This one was not a guess:
  the flags are in the run 59 log.)

The summary step also learned to say something when there is nothing to say: a
job with no diagnostics *and* no `** BUILD SUCCEEDED **` now prints the last ten
compile tasks, so a real timeout names the file it died on instead of looking
like a job that did nothing.

---

## Layer 7 — what the previous layer's fixes uncovered

*Run 61's actual result: 17 diagnostics, two causes.*

Both are diagnostics that could not appear until the errors in front of them
were gone — which is the normal rhythm of this work, and the reason "48 down to
3" was never going to mean "3 left".

### 7.1 Five Screen Time failures had no caregiver-facing words — 2 errors

```
HopScreenTimeFailure+Copy.swift:11:9: error: switch must be exhaustive
HopScreenTimeFailure+Copy.swift:24:9: error: switch must be exhaustive
```

`ScreenTimeFailure` has thirteen cases. `title` and `recoveryMessage` handled
eight. The five missing ones — `authorizationConflict`, `invalidAccountType`,
`networkError`, `authenticationMethodUnavailable`, `monitoringLimitReached` —
are exactly the five added to the enum *after* this file was written.

This is worth more than its two error lines. `authorizationConflict` is
documented on the enum itself as *"in practice the most likely real-world
failure"* — another parental-controls app already holds Family Controls
authorization — and until now a caregiver who hit it would have got **no
sentence at all**. Each of the five now names what HopPotty could not do and
what the caregiver can change, in the voice the other eight use.

### 7.2 Main-actor isolation, in the two places SE-0434 does not reach — 15 errors

`ViewModifier` is a `@MainActor` protocol, so every small value type conforming
to it is main-actor isolated. SE-0434 makes that mostly invisible for value
types: *instance* storage of `Sendable` type stays reachable from nonisolated
code. Two things fall outside that exemption, and both showed up at once:

**A `static let`** (14 errors). Global storage stays isolated, so the
`AnyTransition` factories could construct `HopPageShift(travel:…)` — instance
storage, exempt — and then not name `HopPageShift.identity` two lines later:

```
error: main actor-isolated static property 'identity' can not be referenced
       from a nonisolated context
```

**An explicit initializer** (1 error). The implicit memberwise initializer is
exempt; a hand-written one inherits the type's isolation. `HopTheme.elevation(_:)`
is an ordinary nonisolated method and it calls one:

```
error: call to main actor-isolated initializer 'init(level:shadow:)'
       in a synchronous nonisolated context
```

Both are `nonisolated`, and in both cases that is a description rather than a
suppression: `identity` is one immutable all-`Double` value that is read and
copied and never mutated, and `HopElevationModifier.init` takes two immutable
`Sendable` tokens and only stores them. There is nothing for two domains to
share in either.

---

## Layer 8 — one warning, which is one build failure

*Run 63. 1 diagnostic.*

```
ChildProfileEditor.swift:57:20: error: immutable value 'childID' was never used;
                                consider replacing with '_' or removing it
```

Note the word `error`. That is a **warning** — and this project sets
`SWIFT_TREAT_WARNINGS_AS_ERRORS`, so it stops the build like anything else. It
is the reason the CI summary lists warnings and errors in one block rather than
tucking warnings into a collapsed `<details>`.

`if let childID, parent.children.count > 1` bound a value the block never used.
The condition is about *whether* this editor is editing an existing child, not
about which one, and the file already has a name for that: `isNew`. Every other
`if let childID` in the file does use the value; this was the one that did not.

---

## Layer 9 — one file that had invented two APIs

*Run 64. 3 diagnostics, all in `Features/Shared/FeatureDependencies.swift`.*

```
FeatureDependencies.swift:140:32: error: type 'ScreenTimeFailure' has no member 'restricted'
FeatureDependencies.swift:233:61: error: cannot convert value of type 'PottySchedule'
                                  to expected argument type '[MonitoringPlan.Activity]'
FeatureDependencies.swift:233:82: error: extra argument 'now' in call
```

`FeatureDependencies` is the seam between `Features/` and `Services/` — the
place the parallel-authorship risk was always going to concentrate. It had
invented two APIs, and both inventions are instructive.

**`ScreenTimeFailure.restricted` never existed, and should not.** The line read
`failure == .restricted ? .restricted : .failed(failure)`. But
`ScreenTimeService.requestAuthorization` catches `FamilyControlsError.restricted`
and returns `.success(.restricted)` for it — which the branch six lines above
already handles. Restriction is a **status** in this design, never a failure,
and the check was for something the service is built never to produce.

**`MonitoringPlan(schedule:now:)` never existed either.** `MonitoringPlan.init`
takes `activities:`; the factory is `MonitoringPlan.make(for:hasSelection:)`.
The project's two other callers — `PottyPauseEffectExecutor` and the Lab — both
use the factory correctly. This one place invented a shape for it.

That second one is more than a signature mismatch. `hasSelection` is not a
formality: a `.screenActivity` trigger with nothing picked can never fire, and
`make` returns an empty plan carrying `.selectionRequired` rather than
registering a monitoring activity that would be a lie. Going through the
invented initializer would have skipped that reasoning entirely.

---

## Reading a failed build

`.github/workflows/ci.yml` ends with a **Summarise diagnostics** step,
deliberately placed last and printed to stdout as well as to the job summary.
The raw `xcodebuild` log is tens of thousands of lines, most of them a single
compiler invocation wrapped onto one line, with the dozen that matter scattered
through it. Tailing the job now gives the de-duplicated diagnostic list and
nothing else.

It lists **warnings alongside errors**, because `SWIFT_TREAT_WARNINGS_AS_ERRORS`
is on and a warning here is a build failure, not a footnote.

The full log is also uploaded as the `xcodebuild-log` artifact, kept 14 days,
for the times when the first error is explained by something a hundred lines
above it.
