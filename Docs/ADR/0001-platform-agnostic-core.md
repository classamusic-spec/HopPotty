# ADR 0001 — A platform-agnostic core package

**Status:** Accepted
**Date:** 2026-09-01

## Context

HopPotty is a SwiftUI iOS app whose defining feature depends on Apple-only
frameworks (FamilyControls, DeviceActivity, ManagedSettings). The obvious
structure is a single app target with everything inside it.

But the parts of this product most likely to be *wrong* are not the views:

- interval arithmetic across daylight-saving transitions and timezone changes
- quiet-hour precedence when several windows overlap
- reward idempotency when the app is killed mid-write
- shield-restoration state transitions after a crash or reboot

Every one of those is pure logic. None of it needs a `View`, a `ModelContext`,
or an entitlement. All of it is where a defect hurts a family — a child locked
out of their apps, a star awarded twice, a nap interrupted.

## Decision

Business logic lives in **`HopPottyKit`**, a Swift package with three targets
that import only Foundation:

- `HopPottyCore` — models, scheduling, rewards, state machine, insights, content
- `HopPottyDesignTokens` — colour, type, spacing, motion values
- `HopPottyFixtures` — deterministic sample data

The app target, the design system's SwiftUI layer, SwiftData persistence and the
Screen Time services sit on top and depend on it. Nothing in `HopPottyKit`
depends on them.

## Consequences

**Good.** The riskiest code compiles and its tests run on any Swift toolchain,
including CI without a Mac. Tests are fast and hermetic: an injected `Calendar`
and an explicit `now` make DST cases reproducible instead of dependent on when
the suite happens to run. Contrast ratios are assertable, so an inaccessible
colour fails the build rather than a design review. Business rules that matter —
stars are never removed, accidents never reach the reward system, screen access
is never contingent on a biological outcome — become executable assertions
instead of documentation.

**Cost.** Domain types are declared once in Core and mapped to SwiftData
`@Model` classes at the persistence boundary. That mapping is real work and real
lines of code. It is worth it: it keeps a persistence framework's requirements
from dictating the shape of the domain, and it means swapping persistence later
does not touch business logic.

**Discipline required.** The boundary only holds if it is enforced. A `View`
that computes a next-pause time, or a service that inlines a reward rule, has
put untestable logic somewhere it cannot be reached. `Docs/CONTRACTS.md` states
the rule; code review has to hold it.

## Note on this environment

The environment where HopPotty was first built had no Xcode, which made the
payoff immediate rather than eventual. That is not why the decision was made —
this is the structure a testable iOS app should have regardless — but it did
mean roughly half the product's risk could be genuinely verified rather than
merely written.
