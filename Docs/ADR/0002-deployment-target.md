# ADR 0002 — Minimum iOS deployment target

**Status:** Accepted
**Date:** 2026-09-01
**Supersedes:** nothing. **Ratifies:** the `.iOS(.v17)` floor already declared in
`HopPottyKit/Package.swift`.
**Related:** `Docs/ScreenTimeArchitecture.md`, `Docs/ADR/0001-platform-agnostic-core.md`

## Decision

**iOS 17.0** is HopPotty's minimum deployment target, for the app and all three
extensions. Every API newer than 17.0 is used behind `if #available`, never as a
floor.

## Context

The floor is decided by two things pulling in opposite directions: the APIs the
architecture actually requires, and how many families a floor excludes. Both were
measured rather than assumed.

### What the architecture requires

Availability, verified from Apple's documentation on 2026-09-01
(full table in `Docs/ScreenTimeArchitecture.md` §2):

| Requirement | Introduced | Source |
| --- | --- | --- |
| FamilyControls, ManagedSettings, ManagedSettingsUI, DeviceActivity | **iOS 15.0** | [Screen Time Technology Frameworks](https://developer.apple.com/documentation/screentimeapidocumentation) |
| `requestAuthorization(for:)` + `FamilyControlsMember` (the non-deprecated authorization path) | **iOS 16.0** | [doc](https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization(for:)) |
| `ManagedSettingsStore(named:)` + `clearAllSettings()` — the whole store-per-lifetime design | **iOS 16.0** | [doc](https://developer.apple.com/documentation/managedsettings/managedsettingsstore/init(named:)) |
| **SwiftData** | **iOS 17.0** | [doc](https://developer.apple.com/documentation/swiftdata) |
| **Observation** (`@Observable`) | **iOS 17.0** | [doc](https://developer.apple.com/documentation/observation) |
| `DeviceActivityEvent.includesPastActivity` | iOS 17.4 | [doc](https://developer.apple.com/documentation/deviceactivity/deviceactivityevent/includespastactivity) |
| `ShieldConfiguration.secondaryButtonSubmenuItems` + submenu `ShieldAction`s | iOS 26.4 | [doc](https://developer.apple.com/documentation/managedsettingsui/shieldconfiguration/secondarybuttonsubmenuitems) |
| `ShieldActionResponse.openParentalControlsApp` (a shield can open HopPotty) | iOS 26.5 | [doc](https://developer.apple.com/documentation/managedsettings/shieldactionresponse/openparentalcontrolsapp) |

The decisive observation: **the entire Potty Pause mechanism is available at iOS
16.0.** Nothing HopPotty needs was added between 16.0 and 17.0. The floor is
therefore set by SwiftData and Observation, not by Screen Time.

### What the floor costs in reach

| Fact | Value | Source |
| --- | --- | --- |
| iPhones on iOS 26, all devices | **79%** | [App Store support](https://developer.apple.com/support/app-store/) — "As measured by devices that transacted on the App Store on June 7, 2026" |
| iPhones on iOS 26, devices introduced in the last four years | **86%** | same |
| Devices an iOS 17 floor admits | every device that can run iOS 17 or later — a strict superset of the 79% above | |
| Devices an iOS 17 floor excludes | those whose maximum OS is iOS 16 or earlier: **iPhone 8, 8 Plus and X, and older** | [iPhone models compatible with iOS 17](https://support.apple.com/guide/iphone/iphe3fa5df43/17.0/ios/17.0) |

That exclusion is the real cost, and it is not academic for this product: a
hand-me-down iPhone 8 or X is exactly the kind of device a family gives a small
child. It is a 2017-era device that has been out of OS support since 2023.

## Options considered

### A. iOS 16.0 — maximum reach

Buys: iPhone 8 / 8 Plus / X families.
Costs: **SwiftData and Observation both disappear.** The entire persistence layer
becomes Core Data (or hand-rolled `Codable` files) and the entire view layer
becomes `ObservableObject` + `@Published`. That is not a compatibility shim; it is
a different app architecture, permanently, for the sake of a shrinking tail of
2017 hardware.
Rejected. The engineering tax is paid on every screen, forever, and the affected
devices are already several years past their last security update — not a
platform to recommend to a parent for a child's device.

### B. iOS 17.0 — the SwiftData floor *(chosen)*

Buys: SwiftData, Observation, and every Screen Time API the Potty Pause needs.
Costs: the iPhone 8 / 8 Plus / X tail.
The floor is set by exactly one thing — the two iOS 17 frameworks — and there is
no Screen Time API between 16.0 and 17.0 that we forgo by *not* choosing 16.0.
Clean and defensible.

### C. iOS 18.0 — "one back from current-minus-one"

Buys: nothing HopPotty needs. No Screen Time API, no persistence API, no
Observation change we depend on.
Costs: excludes iOS-17-capable devices that have not moved on, for no return.
Rejected: a floor should be bought, not adopted out of habit.

### D. iOS 26.5 — buy `openParentalControlsApp`

Buys: the shield can bring HopPotty forward when the child taps "All done!",
which is genuinely the nicer experience
(`Docs/ScreenTimeArchitecture.md` §7).
Costs: 26.5 is a point release from mid-2026. Even iOS 26 as a whole was at 79%
on 7 June 2026, and 26.5 is a subset of that. For an app whose users are parents
of toddlers — not early adopters — this trades most of the addressable audience
for one interaction improvement.
Rejected as a floor, **adopted as a runtime-gated enhancement**:

```
// iOS 17.0–26.4: end the pause in the extension, return .close.
// iOS 26.5+:     end the pause and return .openParentalControlsApp.
```

The pre-26.5 path is the designed experience, not a degraded one: the star is
earned at the tap and shown next time HopPotty opens, and the ledger's
append-only idempotency (Contract §4.2) makes the deferred drain safe.

## Consequences

**Good**

- SwiftData + `@Observable` throughout the app, matching the Contract's "business
  logic in a `View` is a defect" rule with the least ceremony.
- One floor for all four targets, matching `HopPottyKit/Package.swift`'s existing
  `.iOS(.v17)`; no per-target availability drift to reason about.
- No `if #available` noise anywhere in the Potty Pause core — the whole mechanism
  is iOS 16-era API.
- Every family on a device Apple still supports can install HopPotty.

**Bad**

- iPhone 8 / 8 Plus / X families cannot install HopPotty. If caregiver research
  later shows this cohort matters, the fix is expensive (Option A) — so measure it
  *before* the persistence layer calcifies, not after.
- We inherit SwiftData's iOS 17.0 behaviour as our baseline, including any early
  17.x defects, and cannot use `#Index`/`#Unique` or custom `DataStore` without a
  gate.

**Neutral**

- `includesPastActivity` (17.4) is unavailable at the floor. HopPotty does not use
  usage thresholds — a Potty Pause is wall-clock, not usage-driven
  (`Docs/ScreenTimeArchitecture.md` §4) — so this costs nothing today. If a future
  feature needs it, gate it.

## Rules this decision imposes

1. `IPHONEOS_DEPLOYMENT_TARGET = 17.0` on the app and all three extension targets,
   and `.iOS(.v17)` in `HopPottyKit/Package.swift`. These must not diverge.
2. No API newer than 17.0 without `if #available`, and no `@available` on a type
   in `HopPottyCore` — the package must keep compiling on Linux (Contract §1).
3. Every gated enhancement needs a designed, tested, non-apologetic fallback. The
   iOS 17 path is the product; anything newer is a bonus.

## Revisit triggers

Re-open this ADR when any of these becomes true:

- iOS 26.5+ passes ~90% of *our own* installed base (not the App Store average),
  making a shield-opens-app-first design worth considering.
- Caregiver research shows a material share of target families on iPhone 8/X.
- SwiftData at iOS 17.0 turns out to have a defect we cannot work around, making
  an 18.0 floor a bug fix rather than a preference.
- A future Screen Time API removes the 15-minute `DeviceActivitySchedule` floor
  (`Docs/ScreenTimeArchitecture.md` §11.2) — that would change the pause
  architecture enough to re-price the whole decision.

## Sources

All URLs retrieved 2026-09-01.

- App Store — iOS and iPadOS adoption — https://developer.apple.com/support/app-store/
- iPhone models compatible with iOS 17 — https://support.apple.com/guide/iphone/iphe3fa5df43/17.0/ios/17.0
- SwiftData — https://developer.apple.com/documentation/swiftdata
- Observation — https://developer.apple.com/documentation/observation
- Screen Time Technology Frameworks — https://developer.apple.com/documentation/screentimeapidocumentation
