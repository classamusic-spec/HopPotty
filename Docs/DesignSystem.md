# Design System

**Date:** 2026-09-01
**Token source of truth:** `HopPottyKit/Sources/HopPottyDesignTokens/`
**SwiftUI API contract:** `Docs/DesignSystemAPI.md` (signatures; do not duplicate here)

Colour, type, spacing, motion and hit-target values live in a Foundation-only
Swift package so they can be asserted in tests on any toolchain and exported to
the render harness. The SwiftUI layer converts them at the boundary; **nothing
else in the app holds a raw hex string.**

---

## 1. The font decision — stated plainly

The brand direction references **Fredoka** (display) and **Nunito Sans** (text).

**The app bundles no third-party fonts.** HopPotty uses the **system font's
rounded design** for display and child surfaces, and the system font's default
design for parent surfaces (`HopFontFamily.rounded` / `.standard`).

Why:

| Reason | Detail |
| --- | --- |
| Same warmth | The rounded system design gives the soft, friendly letterform the brand wants. |
| Optical sizing | Apple's system font is optically sized per point size; a bundled static face is not. |
| Language coverage | The system font covers every language iOS ships. A bundled face would degrade or fall back the moment HopPotty is localised. |
| Dynamic Type | Text styles, scaling curves and the accessibility sizes come for free and stay correct across OS releases. |
| Licensing | No embedding licence to audit, renew, or get wrong. |
| Binary size | Nothing added to the download, on an app whose audience installs on a hand-me-down device. |

**The render harness is different, and deliberately so.** `Scripts/screens/` runs
in a browser with no access to the iOS system font, so it uses **Nunito** and
**Fredoka** (both SIL Open Font License) purely to approximate the rounded system
design outside iOS. A render is a picture of the design system, not a simulator
screenshot; the fonts in it are an approximation and the app ships neither.
`Scripts/screens/README.md` says the same thing at the other end of the pipeline.

---

## 2. Palette

### 2.1 Brand hues — `HopPalette`

Views must **not** reference these directly; they read `HopSemanticPalette`.

| Token | Hex | Use |
| --- | --- | --- |
| `hopGreen` | `#63C88A` | Hop, primary brand hue |
| `pondBlue` | `#6FC7E8` | Water, secondary brand hue |
| `sunshine` | `#FFD769` | Stars, celebration |
| `peachPop` | `#FF9F8F` | Warm accent |
| `lavender` | `#AFA5EF` | Cool accent |
| `midnight` | `#243047` | Brand ink |
| `cloud` | `#FFF9F2` | Brand ground |

### 2.2 Ramps

Hand-tuned rather than programmatically darkened: the hues shift slightly as they
deepen so they stay warm instead of turning muddy. `Deep` and `Ink` variants exist
specifically to carry text at accessible contrast.

| Family | Soft | Light | Base | Deep | Ink |
| --- | --- | --- | --- | --- | --- |
| Green | `#E3F5EA` | `#8FDCAC` | `#63C88A` | `#2F8C57` | `#1B5E39` |
| Pond blue | `#E0F4FC` | `#9BDCF1` | `#6FC7E8` | `#2A87AC` | `#15566F` |
| Sunshine | `#FFF3D4` | `#FFC53D` *(bright, decorative only)* | `#FFD769` | `#A87A0C` | `#7A5A08` |
| Peach | `#FFE8E3` | — | `#FF9F8F` | `#C96755` | `#8A3F30` |
| Lavender | `#EFEDFB` | — | `#AFA5EF` | `#6F63C0` | `#453B85` |

Neutrals are a **warm-tinted** grey ramp — pure greys next to Cloud read as dirty:
`sand50 #FFFCF8`, `sand100 #F7F1E9`, `sand200 #EBE3D8`, `sand300 #D8CEC1`,
`sand400 #AFA69B`, `sand500 #7D766D`, `sand600 #5A544D`;
`night900 #14192A`, `night800 #1B2337`, `night700 #243047`, `night600 #33415C`,
`night500 #4C5A76`.

### 2.3 The contrast failure that was caught

The first amber, **`#C79214`, measured 2.78:1** against the light ground —
below the 3.0:1 non-text bar and far below 4.5:1 for text. `ContrastTests` failed
the build. The token was darkened to **`#A87A0C`** (`sunshineDeep`), which passes.

The lesson is the mechanism, not the colour: **contrast is a build failure, not a
design review note.** `HopColorValue` implements WCAG 2.1 relative luminance and
`contrastRatio`, and `HopPottyDesignTokensTests/ContrastTests.swift` asserts, for
all four appearances:

| Assertion | Bar |
| --- | --- |
| `textPrimary`, `textSecondary` on all five grounds | 4.5:1 |
| `textTertiary` on all five grounds (large/de-emphasised use only) | 3.0:1 |
| `textOnBrand` on `brandAction` | 4.5:1 |
| Status and event accents on `surface` and `backgroundPrimary` | 3.0:1 |
| Focus ring on every ground | 3.0:1 |

Colours are composited over their ground before measuring, so a translucent
token cannot pass on its own opacity.

---

## 3. The four appearances

`HopAppearance`: `light`, `dark`, `lightHighContrast`, `darkHighContrast`.
Resolved automatically from `colorScheme` + `colorSchemeContrast`; no view ever
branches on appearance.

`HopSemanticPalette` — 24 roles, grouped: grounds (5), text (4), brand (3),
status (4), event accents (4), structure (4).

| Role | Light | Dark | Light HC | Dark HC |
| --- | --- | --- | --- | --- |
| `backgroundPrimary` | `#FFF9F2` | `#14192A` | `#FFFFFF` | `#000000` |
| `surface` | `#FFFFFF` | `#1B2337` | `#FFFFFF` | `#11172A` |
| `textPrimary` | `#243047` | `#F3F1ED` | `#14192A` | `#FFFFFF` |
| `textSecondary` | `#5A544D` | `#B4BCCB` | `#413B34` | `#D7DDE8` |
| `brandPrimary` | `#63C88A` | `#8FDCAC` | `#2F8C57` | `#A8E8C2` |
| `brandAction` | `#2A7F4E` | `#8FDCAC` | `#1B5E39` | `#A8E8C2` |
| `warning` / `celebration` | `#A87A0C` | `#FFD769` | `#7A5A08` | `#FFE49A` |
| `focusRing` | `#1C6FA8` | `#7CC4F0` | `#0B4E7C` | `#A5D8F7` |

`brandAction` is separate from `brandPrimary` for one reason: `#63C88A` is a
decorative hue that cannot legally carry white text. The action fill is deeper.

High contrast darkens text and strengthens dividers while leaving decorative
tints in place, so the brand does not visually collapse.

### 3.1 Event accents are never the only signal

`eventTried` / `eventPee` / `eventPoop` / `eventAccident` each pair with a
distinct `HopGlyph`. Meaning is never carried by colour alone — `CONTRACTS.md` §6.

---

## 4. Type scale — `HopTypography`

| Style | Family | Size | Weight | Line | Notes |
| --- | --- | --- | --- | --- | --- |
| `hero` | rounded | 44 | heavy | 1.08 | Brand moments |
| `childTitle` | rounded | 34 | bold | 1.14 | |
| `childInstruction` | rounded | 24 | semibold | 1.28 | The routine's instruction line |
| `celebration` | rounded | 38 | heavy | 1.10 | |
| `buttonLarge` | rounded | 22 | bold | 1.15 | Child buttons |
| `parentLargeTitle` | rounded | 32 | bold | 1.14 | |
| `parentTitle` | rounded | 22 | semibold | 1.20 | |
| `parentHeadline` | standard | 17 | semibold | 1.29 | |
| `parentBody` | standard | 17 | regular | 1.35 | |
| `parentCallout` | standard | 15 | regular | 1.33 | |
| `parentCaption` | standard | 13 | regular | 1.31 | |
| `parentFootnote` | standard | 12 | medium | 1.33 | |
| `metric` | rounded | 28 | bold | 1.10 | Dashboard numbers |
| `timer` | rounded | 56 | bold | 1.00 | |
| `timerHero` | rounded | 72 | heavy | 1.00 | **The only style that opts out of Dynamic Type** |

`timerHero` sets `scalesWithDynamicType: false` because it is already far above
body size and would break the illustrated layout it sits inside. Every other
style scales. Monospaced digits are applied at the SwiftUI layer so countdowns do
not jitter.

---

## 5. Spacing, radii, elevation

**Spacing** — 4pt scale, `HopSpacing`: xxs 2 · xs 4 · s 8 · m 12 · l 16 · xl 20 ·
xxl 24 · xxxl 32 · huge 40 · giant 56. Page margins: `pageCompact` 20,
`pageRegular` 32. Ad-hoc values are what make a layout feel arbitrary.

**Radii** — `HopRadius`: xs 6 · s 10 · m 14 · l 20 · xl 26 · xxl 34 · hero 44 ·
pill 999. Hierarchy comes partly from cards being rounder than the controls
inside them.

**Elevation** — `HopElevation(radius, yOffset, opacityScale)`; the colour comes
from `HopSemanticPalette.shadow` so dark mode does not glow.

| Step | Radius | Y | Opacity × | Use |
| --- | --- | --- | --- | --- |
| `flat` | 0 | 0 | 0 | Rows inside an already-elevated card |
| `resting` | 14 | 4 | 1.00 | Dashboard cards |
| `raised` | 24 | 8 | 1.15 | The primary action on a scene, and any card that must lift off a drawing |
| `floating` | 40 | 16 | 1.30 | Sheets, popovers, the celebration overlay |

---

## 6. Motion — `HopMotion`

Parent motion is quick and nearly flat; it should feel like the OS. Child motion
carries bounce because it is doing narrative work for a pre-reader.

| Token | Duration | Bounce |
| --- | --- | --- |
| `parentTap` | 0.22 | 0.10 |
| `parentTransition` | 0.34 | 0.00 |
| `parentSheet` | 0.42 | 0.08 |
| `childTap` | 0.30 | 0.34 |
| `childArrive` | 0.55 | 0.28 |
| `childCelebrate` | 0.70 | 0.42 |

Ambient: `breathePeriod` 3.4s, `blinkInterval` 2.8–6.5s, `blinkDuration` 0.14s.
Lists stagger by `stagger(index:step:cap:)` — 0.045s per item, capped at 0.36s.

Two hard rules:

1. **`celebrationMaxDuration` is 3.5s.** The product's premise is a *short*
   interruption; a long reward animation works against it.
2. **Every animation has a Reduce Motion path.** Route through
   `theme.animation(_:)`, which degrades any spring to
   `reducedMotionFade` (0.20s cross-fade) in one place. Never call
   `withAnimation` directly. The shield cannot animate at all, so it satisfies
   this trivially.

---

## 7. Hit targets — `HopHitTarget`

| Token | Value | Applies to |
| --- | --- | --- |
| `parentMinimum` | 44pt | Every adult control (the HIG floor) |
| `childMinimum` | 72pt | Every child control |
| `childPrimary` | 96pt | The child's primary action on a screen |

`HopButtonSize` maps `.parent` / `.child` / `.childPrimary` onto these.
`.hopHitTarget(_:)` expands the frame **and** sets `contentShape` — without the
content shape the extra frame is transparent to hit-testing and the target is
still too small.

---

## 8. Component inventory

Signatures live in `Docs/DesignSystemAPI.md`. Implementation status is against
`HopPotty/DesignSystem/` as of this date; **nothing here has been compiled.**

| Group | Components | File | Status |
| --- | --- | --- | --- |
| Foundation | `HopTheme`, `@Environment(\.hopTheme)`, `HopColor+SwiftUI`, `HopTypography+SwiftUI`, `HopElevation+SwiftUI`, `HopLayout`, `HopStrings`, `HopPresentationModels`, `HopDurationFormat`, `HopScreenTimeFailure+Copy` | `Foundation/` | written |
| Motion | `HopAnimationToken`, `HopAmbientMotion` | `Motion/` | written |
| Buttons | `HopPrimaryButton`, `HopSecondaryButton`, `HopIconButton`, `HopDestructiveButton`, `HopButtonStyle`, `HopBareButtonStyle` | `Components/HopButtons.swift`, `HopButtonStyle.swift` | written |
| Containers | `HopCard`, `HopSection`, `HopSheet`, `HopRowDivider` | `Components/HopContainers.swift` | written |
| Parent data | `HopMetricCard`, `HopProgressRing`, `HopTimerCard`, `HopTimelineRow`, `HopInsightCard`, `HopSettingsRow`, `HopToggleRow`, `HopSectionHeader`, `HopPill` | `Components/` | written |
| Glyphs | `HopGlyph` (16 cases), `HopGlyphShape`, `HopGlyphView` | `Foundation/` | written |
| Child surfaces | `HopCharacterStage`, `HopSpeechBubble`, `HopStarBadge`, `HopCelebrationView`, `HopStepIndicator`, `HopAudioButton`, `HopAvatar`, `HopModeSelector` | — | **not yet present** |
| States | `HopEmptyState`, `HopErrorState`, `HopLoadingState`, `HopLockedState` | — | **not yet present** |
| Gate | `HopParentGate`, `.hopParentGated(...)` | — | **not yet present** |

`HopGlyph` cases: `tried, pee, poop, accident, star, check, pause, play, timer,
quietHours, shield, wash, flush, wipe, highFive, pond`. Eight map to SF Symbols;
the eight that carry HopPotty-specific meaning are drawn shapes. Every case has a
VoiceOver description in `HopStrings`.

`HopPose` (character art) is `idle, blink, wave, jump, walk, wait, cheer`,
matching `Art/character/hop-<pose>.svg` one-to-one.

---

## 9. Rules a contributor has to keep

1. No raw hex outside `HopPottyDesignTokens`.
2. No `HopPalette` reference in a view — semantic roles only.
3. No string literal in a view — everything through `HopCopy` (product copy) or
   `HopStrings` (component mechanics).
4. No `withAnimation` — `theme.animation(_:)`, so Reduce Motion is honoured once.
5. No spacing or radius value that is not a token.
6. Meaning is never carried by colour alone: every event kind has a glyph.
7. A new colour pairing that a view will render needs an assertion in
   `ContrastTests`, added in the same commit as the colour.

---

## 10. Render harness

`Scripts/screens/render-screens.js` renders screens to PNG from
`Scripts/tokens.json`, which is generated by `swift run hoptokens`. Every colour,
radius, spacing step and type size in a render therefore comes from the same
package the app compiles against — a render cannot show a value the app does not
use.

They are **design renders, not simulator screenshots.** Nothing in
`Art/render/screens/` is evidence that any SwiftUI code compiles or lays out as
drawn.
