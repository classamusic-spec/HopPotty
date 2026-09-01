# Engineering Contract

Every contributor — human or agent — builds against this. It is deliberately
short. If something here conflicts with a feature spec, this wins.

## 1. Module boundaries

```
HopPottyKit/                    Swift package. NO SwiftUI, NO SwiftData,
  Sources/HopPottyCore          NO FamilyControls/DeviceActivity/ManagedSettings.
  Sources/HopPottyDesignTokens  Only Foundation. Must compile on Linux.
  Sources/HopPottyFixtures
HopPotty/                       iOS app target. SwiftUI + SwiftData + Screen Time.
Extensions/                     Three app extensions. Lightweight, deterministic.
```

**Rule:** if a type can be expressed without Apple UI frameworks, it belongs in
`HopPottyCore`. Business logic in a `View` is a defect.

## 2. Verifying your work

Core and DesignTokens changes MUST typecheck. From `HopPottyKit/`:

```bash
export PATH=/opt/swift/usr/bin:$PATH
# Typecheck your files together with the model layer (safe to run in parallel
# with other agents; does not touch the shared .build directory):
swiftc -typecheck -swift-version 6 \
  Sources/HopPottyCore/Models/*.swift \
  Sources/HopPottyCore/<YourArea>/*.swift
```

Do not run `swift build` or `swift test` on the shared package while other
agents are working — the shared `.build` directory will produce spurious
failures from other people's in-progress files. Integration runs a full
`swift test` at the end.

## 3. Naming

- Types: `Hop`-prefixed only in the design system (`HopPrimaryButton`,
  `HopCard`). Domain types are unprefixed (`PottyEvent`, `ChildProfile`).
- Services end in `Service`; protocols they satisfy end in `Providing`
  (`ScreenTimeProviding`) so the concrete type keeps the good name.
- Test suites use Swift Testing (`@Suite`, `@Test`, `#expect`), not XCTest.

## 4. Non-negotiable product rules

These are enforced by tests. Breaking one is a build failure, not a discussion.

1. **Screen access is never contingent on a biological outcome.** No code path
   may keep a shield up because a child did not pee. A pause ends on its timer,
   on completion, or on caregiver override — nothing else.
2. **Stars are never removed.** `RewardTransaction.quantity` is non-negative and
   the ledger is append-only. There is no decay, no expiry, no streak loss.
3. **`accident` never reaches the reward system.** It is a neutral timeline fact.
4. **No shame language.** Child-facing copy never contains "failed", "wrong",
   "lost", "disappointed", "no stars", or a negation of the child's effort.
5. **No medical claims.** Parent-facing insights describe observed patterns and
   say so. Never "should", never a diagnosis, never a recommended frequency.
6. **Every destructive action passes the parent gate** and states exactly what
   will be removed, with counts.
7. **No engagement mechanics.** No streaks that can break, no loss aversion, no
   randomised rewards, no "come back" notifications, no leaderboards.

## 5. Copy

All user-visible text goes through `HopCopy` (`Sources/HopPottyCore/Content/`).
No string literals in views. Keys are stable; English values live beside them.
This is what makes localisation and the child-safety copy test possible.

## 6. Accessibility

- Child controls: minimum 72pt, primary actions 96pt (`HopHitTarget`).
- Never encode meaning in colour alone — every event kind has a glyph.
- Every animation has a Reduce Motion path; use `HopMotion.reducedMotionFade`.
- Every spoken line has a written caption.

## 7. Comments

Explain *why*. `// Increment the counter` is noise; `// Half-open so a 07:00
wake-up boundary does not suppress a 07:00 pause` is the reason the code is
correct. No TODOs in logic that ships.
