# React Native stack

Versions verified against the live npm registry and official release notes on
2026-09-03. **Four packages are deliberately not on their `latest` tag** — see
Pins below. Taking `latest` for those breaks the build in ways whose error
messages do not point at the version.

## Runtime

| Package | Version | Note |
|---|---|---|
| `react-native` | 0.87.1 | Requires Node ≥ 22.13, Xcode 26.0, iOS ≥ 15.1 |
| `react` | 19.2.3 | Exact — RN is sensitive to renderer drift |
| `@react-navigation/native` | ^7.3.18 | v8 is alpha; do not ship it |
| `@react-navigation/native-stack` | ^7.18.10 | |
| `@react-navigation/bottom-tabs` | ^7.18.18 | |
| `react-native-screens` | ^4.27.0 | Ships web files |
| `react-native-safe-area-context` | ^5.9.1 | Explicit web support |
| `react-native-reanimated` | 4.6.0 | **Version-locked** to worklets 0.12.x |
| `react-native-worklets` | 0.12.1 | Mismatch with Reanimated = runtime crash |
| `react-native-gesture-handler` | ^3.2.1 | 3.x is a breaking major, ESM-only |
| `react-native-svg` | ^15.15.5 | Real web compatibility layer |

## Pins — do NOT take `latest`

| Package | We use | `latest` | Why |
|---|---|---|---|
| `typescript` | **6.0.3** | 7.0.2 | TS 7 is the Go rewrite and ships **without a stable programmatic API** until 7.1. `@typescript-eslint/parser` declares `>=4.8.4 <6.1.0`, excluding it. RN's own template pins `^6.0.3`. |
| `jest` | **29.7.0** | 30.5.1 | `@react-native/jest-preset@0.87.1` depends on Jest **29** internals. Mixing majors under one preset fails opaquely. |
| `eslint` | **9.39.5** | 10.9.1 | `@react-native/eslint-config@0.87.1` peers `^8 \|\| ^9`. |
| `prettier` | **^3.9.6** | 3.9.6 | The inverse: 3.9.6 is correct, but the RN template still pins 2.8.8. Don't copy the template. |

## New Architecture

**Mandatory, not default.** Since RN 0.82 the opt-outs are ignored, and 0.87
removed the `useTurboModules` flag entirely. Every dependency above is
New-Architecture-native.

Note: `reactnative.dev/docs/the-new-architecture/*` still documents
`newArchEnabled=false`. Those pages are stale — trust the 0.82 and 0.87
release posts.

## Native module authoring

Codegen emits C++, Objective-C++ and Java — **not Swift**. The generated spec
requires implementing a method returning `std::shared_ptr<TurboModule>`, and
Swift cannot conform to a protocol with C++ types, so the stock path needs an
Objective-C++ shim:

```
specs/NativeScreenTime.ts          the codegen source (written)
ios/RCTNativeScreenTime.h/.mm      ObjC++ shim                (not written)
ios/ScreenTimeImpl.swift           the real FamilyControls code (not written)
```

**Evaluate Nitro Modules (`react-native-nitro-modules` 0.37.1) first.**
`FamilyControls`, `DeviceActivity` and `ManagedSettings` are **Swift-only
frameworks with no Objective-C surface** — `FamilyActivitySelection`,
`ManagedSettingsStore` and friends cannot be touched from `.mm` directly. The
stock path therefore requires hand-writing a Swift → `@objc`-safe → ObjC++ →
JSI flattening layer for every call. Nitro uses Swift↔C++ interop and removes
that layer entirely.

The tradeoff is real: Nitro is a third-party dependency on the critical path
and its peer range is a wildcard, so it promises no compatibility you can lean
on. Decide by building one method both ways.

## Brownfield iOS integration

`RCTRootView` is legacy. The current approach is `RCTReactNativeFactory` +
`.rootViewFactory`, instantiable in any view controller — which is exactly the
shape wanted here: React Native lives inside one view controller the existing
app pushes, and the app keeps its window and root.

`RCTAppDependencyProvider` is **required**; it wires the codegen'd module
provider, i.e. the Screen Time TurboModule.

**0.87 breaking change:** bare angle includes now need the namespace —
`#import <React/RCTReactNativeFactory.h>`, not `#import <RCTReactNativeFactory.h>`.
The docs' Objective-C sample is stale on this.

Worth evaluating: `@callstack/react-native-brownfield@5.1.0` wraps the factory
lifecycle and handles reusing a single RN instance across multiple view
controllers — which matters, because a second factory per screen is a real
mistake that is easy to make.

**Stay on CocoaPods.** SwiftPM support (`npx react-native spm`) is experimental
in 0.87 and explicitly not recommended for production.

## Web preview

`react-native-web` 0.21.2 + `react-dom` 19.2.3, bundled by **Vite** — Metro's
web support is undocumented outside Expo and would be a bespoke build to own.

Deployed: **https://hoppotty-rn.vercel.app**

Known limits, and why the preview is scoped as a preview:

- **RNW is the stack's stale dependency** — published 2025-10, eleven months
  without a release while RN shipped five minors. Not abandoned, but no longer
  tracking RN's release train, and nothing replaces it for non-Expo web.
- **It ships no TypeScript types.** `@types/react-native-web` is two minors
  behind. The web build will typecheck methods that then throw at runtime, so
  smoke tests matter more than `tsc` here.
- **Reanimated on web runs entirely on the JS main thread.** No UI-thread
  worklets. Gesture interactions that feel native on device will feel worse in
  a browser. This is why the preview is not a QA surface for game feel.
- `react-native-svg` **does** work on web and maps to real DOM `<svg>`. It is
  the most solid part of the web story, which is why the mascot is faithful.

### One integration trap, recorded

`react-native-web` imports the asset registry by its React Native package name.
Installing `@react-native/assets-registry@0.87.1` to satisfy it **breaks the
build**: that package is a thin re-export of `AssetRegistry` from
`react-native`, which the web config has aliased to `react-native-web`, which
has no such named export — so it resolves to `undefined` and throws on the
first asset registration, before anything renders. Alias the specifier to
`react-native-web/dist/modules/AssetRegistry` instead.

## Package manager

**npm**, with `package-lock.json` committed. One manager, everywhere.

The browser preview keeps its own `web-preview/package.json` with a much
smaller dependency set, so a preview deploy never needs the native toolchain.
