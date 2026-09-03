# React Native screen conventions

Read this before writing a screen. It exists so twelve screens written by
different hands read as one product.

## The reference is the render, not your judgement

Every screen has a PNG in `Art/render/screens/` and, for most, the JavaScript
that produced it in `Scripts/screens/`. That harness holds the **exact** layout
numbers — positions, sizes, colours, copy. Read it. Do not re-derive a layout
you can copy, and do not improve the design while porting it; a port that looks
different is a regression even when it looks nicer.

Copy is also in the harness, and in `HopPottyKit/Sources/HopPottyCore/Content/HopCopy.swift`.
Use the real strings, verbatim.

## Never write a literal

| Instead of | Use |
|---|---|
| `#63C88A` | `theme.palette.hopGreen` or a semantic `theme.color.*` |
| `fontSize: 22` | `<HopText variant="parentTitle">` |
| `padding: 16` | `theme.spacing.l` |
| `borderRadius: 20` | `theme.radius.l` |
| `<Text>` | `<HopText>` |
| a hand-drawn SVG | `<HopArtwork artwork="scene.…">` or `<HopCharacter>` |

`useHopTheme()` gives you `color`, `palette`, `spacing`, `radius`, `hitTarget`,
`type` and `motion`. All of it is generated from the app's Swift design tokens.
If you need a value that is not there, that is a missing token — say so, do not
invent a number.

## The components you have

```tsx
import { HopText, HopButton, HopCard, ChildStage, GameHost, ProgressMarks, GrownUpButton }
  from '../../design-system/components';
import { useHopTheme } from '../../design-system/theme';
import { HopArtwork } from '../../art/HopArtwork';
import { HopCharacter } from '../../mascot/HopCharacter';
```

- `<HopText variant tone>` — `variant` is a type-scale name (`parentTitle`,
  `childTitle`, `childInstruction`, `parentBody`, `parentCallout`,
  `parentFootnote`, `parentCaption`, `parentHeadline`, `parentMetric`,
  `celebration`, `timer`, `timerHero`, `buttonLarge`, `hero`, `metric`,
  `parentLargeTitle`). `tone` is `primary | secondary | tertiary | onBrand | brand`.
- `<HopButton label onPress variant audience>` — `audience="child"` gets the
  large touch target child surfaces require.
- `<HopCard>` — a parent-surface surface.
- `<ChildStage scene veilFrom veilHeight veilStrength>` — a full-bleed child
  screen. The scene bleeds to every edge; controls float on the veil.
- `<GameHost title instruction scene board progress caption …>` — the shared
  game chrome. **Every game uses it.** It guarantees the way out is always on
  screen, there is no clock, no score, and one ending.
- `<HopArtwork artwork="scene.games.mudOff" fit="cover" decorative />` — the
  app's real illustration, by the same key SwiftUI uses. Valid keys are the
  union type `HopIllustrationKey`; TypeScript will reject a wrong one.
- `<HopCharacter size state lookTarget />` — Hop. `state` is a product state
  (`idle`, `wave`, `celebrate`, `think`, `reassure`, `hop`, `sit`, `wash`, …),
  never a rig pose name.

## Parent Mode vs Child Mode

They are different products and must not converge.

**Parent Mode** is a restrained Apple-like utility: neutral surfaces, real
typography, one accent, low visual noise, subtle motion. Cards, lists, forms.

**Child Mode** is a premium animated storybook: full-bleed scenes, huge touch
targets (`theme.hitTarget.childPrimary`), rounded type, Hop present and
expressive. No dense text, no small controls, no navigator chrome.

## Rules that are not style preferences

- **No score, no timer, no streak, no leaderboard** in any game. Progress is
  dots. A number would turn a toy into a test.
- **Every child screen carries the way out** — the grown-up button, same corner.
- **Never claim Screen Time works.** Any screen touching it must handle
  `notDetermined | denied | approved | unavailable` and say the honest thing.
- **The parent gate guards** Screen Time settings, purchases, deletion, export,
  profile settings and restoring access. Never add a route that bypasses it.
- **Accessibility is not optional.** Every control has an
  `accessibilityRole` and `accessibilityLabel`. Decorative art passes
  `decorative` so it does not pollute the screen reader. Hop is one element.
- **iPad is a first-class layout**, not a stretched phone. Use
  `useWindowDimensions()`; at `width >= 768` use a wider layout with a
  `maxWidth` on reading columns, never full-bleed body text.

## File layout

```
src/features/<area>/<ScreenName>Screen.tsx
```

One screen per file, named `<Something>Screen`. Props are an exported
interface. Screens are **presentational**: they take data as props and report
intent through callbacks. Do not fetch, do not touch the native module, do not
hold app state — that arrives later with the state layer, and a screen that
owns its own data cannot be previewed or tested.

Export from `src/features/<area>/index.ts`.

## Definition of done

A screen is done when it renders correctly at 393×852 **and** at iPad width,
every control is reachable and labelled, empty and error states exist where the
render shows them, and it visually matches its reference PNG. Not before.
