# Repository Audit — Phase 0

**Date:** 2026-09-01
**Auditor:** Founding engineering pass, prior to any architecture work.

## What was here

Nothing. The repository contained a `.git` directory with **zero commits** on
`claude/hoppotty-ios-build-6zzfjf` and no other branches, no source, no project
file, no documentation, and no dependency manifests.

```
/home/user/HopPotty
└── .git/          (no commits, no refs)
```

## Reusable work identified

None. There is no prior code to preserve, no technical debt to pay down, and no
risk of destroying working functionality. Every decision from here is greenfield.

## Build environment audit

This matters more than usual for an iOS project, because it constrains what can
honestly be claimed as verified.

| Tool | Status | Consequence |
| --- | --- | --- |
| Xcode / `xcodebuild` | **Not available** | The app target, extensions and all SwiftUI cannot be compiled or run here. |
| iOS Simulator | **Not available** | No UI tests, no snapshot verification, no runtime behaviour checks. |
| Physical iOS device | **Not available** | Screen Time behaviour cannot be observed. |
| Swift toolchain | **Installed — Swift 6.2 for Linux** | Pure-Swift logic compiles and its tests run for real. |
| Swift Testing | **Working on Linux** | Core engine tests execute in CI-like conditions. |
| Chromium + Playwright | Available | SVG art can be rendered to raster and visually inspected. |

### The architectural consequence

Because roughly half this product's risk lives in logic that has nothing to do
with UIKit — interval arithmetic across daylight-saving boundaries, quiet-hour
precedence, reward idempotency, shield-restoration state transitions — that
logic was deliberately placed in **`HopPottyKit`**, a platform-agnostic Swift
package with no dependency on SwiftUI, SwiftData, or any Screen Time framework.

That package compiles and its tests run here, for real, on every change. The
SwiftUI and Screen Time layers sit on top of it and require Xcode.

This is not a workaround for a limited environment; it is the structure a
testable iOS app should have anyway. The environment just made the payoff
immediate. See `Docs/ADR/0001-platform-agnostic-core.md`.

## Honest verification boundary

Throughout this repository, a claim that something is *tested* means a test was
executed and passed. Anything that requires Xcode, a simulator, or a physical
device is listed as **unverified** in `BUILD_STATUS.md` with the exact steps
needed to verify it. No Screen Time behaviour has been observed on hardware.
