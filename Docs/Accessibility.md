# Accessibility

**Date:** 2026-09-01
**Status:** Commitments are designed in and partly enforced by tests. **The QA
checklist in §3 has never been executed against a running app** — there is no
Xcode build, no simulator and no device in this environment (`BUILD_STATUS.md`).
Treat every checkbox as *open*, not as passing.

---

## 1. Commitments

### 1.1 VoiceOver

- Every interactive element has a label, and a hint where the action is not
  obvious from the label.
- **Illustrations on child surfaces are never decorative.** They carry the
  instruction, so `PottyRoutineStep` and `QuizOption` both require an
  `illustrationLabel` / `label` at the type level — there is no way to construct
  one without it.
- Decorative art on parent surfaces is hidden from the accessibility tree.
- Reading order follows visual order; grouped rows are combined so a timeline
  entry reads as one element ("Tried, 2:15pm, logged by your child"), not four.
- The character stage, star badge, progress dots and pond scene have labels in
  `AccessibilityCopy` — child-facing ones held to the same warmth and length rules
  as anything Hop says aloud.
- Live regions announce state changes that are not user-initiated: a pause
  starting, a star landing, an error appearing.

### 1.2 Dynamic Type

- Every text style scales, with exactly one exception: `timerHero` (72pt), which
  is already far above body size and would break the illustrated layout it sits
  inside. Documented on the token (`scalesWithDynamicType: false`).
- Layouts reflow rather than truncate. Buttons grow; labels wrap.
- Accessibility sizes (AX1–AX5) are a first-class case: rows become vertical
  stacks, side-by-side metrics stack, and the child's single primary button stays
  a single primary button.
- Line heights are multiples (`lineHeightMultiple`), so leading scales with the
  text rather than clamping.

### 1.3 Switch Control and full keyboard access

- Every action is reachable without a gesture. Nothing depends on a swipe, a
  long-press-only path, a drag, or multi-touch.
- Focus order matches reading order; modal presentations trap focus and restore
  it on dismissal.
- One focus indicator for the whole app (`HopFocusRingModifier`) — a person who
  learns what focus looks like on the parent dashboard should not have to relearn
  it on the child's routine screen. Its contrast is asserted against every ground
  in every appearance.
- The parent gate is operable by Switch Control: hold-and-answer must have a
  non-gestural equivalent, and `deviceOwner` (Face ID / passcode) is the
  alternative style for anyone who needs it.

### 1.4 Reduce Motion

- Every animation routes through `theme.animation(_:)`, which degrades any spring
  to a 0.20s cross-fade (`HopMotion.reducedMotionFade`) in one place. **Never
  call `withAnimation` directly** — that is the only way the guarantee holds.
- Ambient character motion (breathing, blinking) stops entirely.
- The celebration becomes a static state change with the same information: the
  star arrives, the pond item appears, nothing moves.
- Parallax and any scene depth effect are off.
- The shield cannot animate at all, so it satisfies this trivially.

### 1.5 Reduce Transparency

- Blurs are replaced with solid `surface` fills from the semantic palette.
- Scrims become opaque at the token level rather than per-view.
- The shield's blur style is a value in `ShieldPresentation`, so the pre-resolved
  payload can choose a solid background — subject to what
  `ManagedSettingsUI` actually allows, which is **UNVERIFIED**.

### 1.6 Contrast

- WCAG 2.1 AA enforced **by tests, in all four appearances**: 4.5:1 for body
  text, 3.0:1 for large/de-emphasised text and for meaningful non-text marks
  (`ContrastTests`). A failing colour fails the build.
- Colours are composited over their ground before measuring, so a translucent
  token cannot pass on its own opacity.
- Two dedicated high-contrast appearances (`lightHighContrast`,
  `darkHighContrast`) resolve automatically from `colorSchemeContrast`.
- The amber that failed (`#C79214`, 2.78:1) was darkened to `#A87A0C` rather than
  waived. See `DesignSystem.md` §2.3.

### 1.7 Captions

- Every spoken line ships with a written caption. `HopVoiceLine` has no empty
  caption default — a type that cannot express a caption-less line is the
  enforcement.
- Captions are **on by default** (`AppSettings.spokenTextCaptionsEnabled`).
- The setting governs *presentation*, never *availability*: with captions off,
  VoiceOver still reads the caption text.
- No voice assets ship yet, so every line is caption-only today. That path is the
  normal one, not an error state (`HopVoiceAssetState.planned`).
- No spoken content is ever the sole carrier of an instruction.

### 1.8 Hit targets

| Audience | Minimum | Token |
| --- | --- | --- |
| Adult controls | 44pt | `HopHitTarget.parentMinimum` |
| Child controls | 72pt | `HopHitTarget.childMinimum` |
| Child primary action | 96pt | `HopHitTarget.childPrimary` |

`.hopHitTarget(_:)` expands the frame **and** sets `contentShape` — without the
content shape the extra frame is transparent to hit-testing and the target is
still too small. Adjacent targets are separated by at least `HopSpacing.s`.

### 1.9 Never colour alone

Every potty event kind has a distinct `HopGlyph` alongside its accent colour.
Status, selection and error states all carry a glyph or a text label. A person
with any form of colour vision deficiency loses no information —
`CONTRACTS.md` §6.

---

## 2. Where the commitments are enforced today

| Commitment | Enforcement | Runs on Linux? |
| --- | --- | --- |
| Contrast, four appearances | `HopPottyDesignTokensTests/ContrastTests.swift` | **Yes** |
| Every spoken line has a caption | Type-level: `HopVoiceLine` has no caption-less initialiser | Yes (compile) |
| Every routine step / quiz option has an image label | Type-level: required initialiser parameters | Yes (compile) |
| Child copy length is readable aloud | `ChildSafetyCopyTests` length assertions | **Yes** |
| Hit targets | Token constants + `HopButtonSize`; **visual verification pending** | No |
| VoiceOver, Dynamic Type, Switch Control, Reduce Motion/Transparency | **Manual only** — §3 | No |

---

## 3. QA checklist, per screen

Executable by one person with a device, roughly 90 minutes for a full pass.

**Setup for every screen:** run each of these five configurations —
(a) default; (b) VoiceOver on; (c) Dynamic Type at AX3; (d) Reduce Motion +
Reduce Transparency on; (e) Increase Contrast on, in both light and dark.

**Global pass/fail rules**
- [ ] No text truncates at AX3. No control is clipped or overlaps another.
- [ ] The page body never scrolls horizontally at any size.
- [ ] Every control is reachable by Switch Control in a sensible order.
- [ ] Nothing conveys meaning by colour alone.
- [ ] Focus indicator is visible on every ground, in every appearance.

### 3.1 Onboarding (6 screens)
- [ ] VoiceOver reads each screen's heading first, then body, then the action.
- [ ] "Skip for now" is reachable and clearly labelled as optional.
- [ ] The mode chooser announces each option's title *and* its explanatory body.
- [ ] The Screen Time explainer is readable at AX5 without truncation.
- [ ] The system authorization sheet is Apple's; confirm HopPotty's own screen
      before and after it makes sense with VoiceOver.
- [ ] Declining leads to a screen that says what still works — announced, not
      only shown.

### 3.2 Parent home ("Today")
- [ ] The hero timer card reads as one element with a meaningful summary, not as
      a stream of digits.
- [ ] The countdown does not spam VoiceOver — it updates as a live region at a
      sensible cadence, not every second.
- [ ] Today's counts read as "3 tries", "5 stars", not "3" then "tries".
- [ ] Each timeline row reads as one element: kind, time, source.
- [ ] Every event kind is distinguishable with colour filters on (glyph present).
- [ ] "Start a pause now" and "Log a visit" both ≥44pt with clear labels.
- [ ] At AX3 the metric cards stack instead of shrinking.

### 3.3 Patterns (insights)
- [ ] Every insight card reads its sentence *and* its "Pattern, not medical
      advice." label. The disclaimer must never be visually-only.
- [ ] The confidence band is announced in words, not only as a bar.
- [ ] The empty state ("not enough entries yet") is announced, not silent.
- [ ] Any chart has a text equivalent — a chart with no accessible summary fails.
- [ ] The interval *question* is announced as a question with two clear actions.

### 3.4 Potty Pause settings
- [ ] Every row states its current value in the label VoiceOver reads.
- [ ] Steppers and pickers announce the new value on change.
- [ ] Quiet-window rows read the label, the times, and the days.
- [ ] The footer that explains a setting is associated with it, not orphaned.
- [ ] "Disable Potty Pause" is announced as the significant action it is.
- [ ] At AX5 nothing in a settings row collides.

### 3.5 The shield (device only)
- [ ] Title and subtitle are legible at the device's largest text setting —
      **the shield does not honour Dynamic Type; confirm what it actually does.**
- [ ] Button labels are unambiguous to a caregiver reading them to a child.
- [ ] The image has enough contrast against the chosen background in both
      appearances.
- [ ] VoiceOver reads the shield (Apple's implementation) intelligibly.
- [ ] With Reduce Transparency on, the shield background is still acceptable.

### 3.6 Potty Pause screen (child)
- [ ] The single primary button is ≥96pt in every configuration.
- [ ] Hop's line displays its caption; VoiceOver reads it whether or not captions
      are switched on.
- [ ] With Reduce Motion, Hop is still — no breathing, no bounce — and the screen
      still communicates that it is waiting.
- [ ] Nothing on this screen requires reading.

### 3.7 Guided routine (5 steps)
- [ ] Each step's illustration has a label that describes the *action*.
- [ ] The step indicator announces "Step 2 of 5".
- [ ] "Skip this" is reachable and does not look like the primary action.
- [ ] The sit timer, when on, is a filling circle with an accessible value — and
      when Reduce Motion is on it updates without animating.
- [ ] A child can leave from any step, and leaving is announced as fine.
- [ ] The whole routine is completable using Switch Control alone.

### 3.8 Celebration
- [ ] With Reduce Motion the star arrives as a state change with the same
      information, in ≤0.20s.
- [ ] The star count change is announced once, not per particle.
- [ ] A newly unlocked pond item is announced by name.
- [ ] Total duration never exceeds 3.5s in any configuration.

### 3.9 Hop's Pond
- [ ] The scene has an overall label plus a labelled list of unlocked items — a
      pond that reads as "image" is a fail.
- [ ] The next unlock announces its name and its exact star price.
- [ ] Progress toward the next item is announced as a value, not only a ring.
- [ ] Locked items are announced as "not yet unlocked", never as "lost".

### 3.10 Games and quizzes
- [ ] Each game states what to do, in audio and in a caption.
- [ ] Bubble Wash is completable with Switch Control (no drag required).
- [ ] Quiz options are announced with their labels; the hint "Tap a picture to
      answer" is present.
- [ ] A redirect ("try another") is announced warmly and the options stay live.
- [ ] Nothing announces a score, a timer or a failure.

### 3.11 Parent gate
- [ ] The hold-and-answer challenge has a non-gestural path for Switch Control.
- [ ] The arithmetic question is announced clearly; the answer field is labelled.
- [ ] A wrong answer is announced neutrally — no counter, no lockout, no alarm.
- [ ] The `deviceOwner` style states its reason before invoking Face ID.

### 3.12 Deletion and export
- [ ] The confirmation sheet announces the **exact counts** before the action.
- [ ] The destructive button is announced as destructive.
- [ ] The receipt afterwards is announced, including "0 stars removed" where true.
- [ ] Export announces where the file was written.

### 3.13 Paywall
- [ ] Features are announced as what unlocking *adds*, never as what is missing.
- [ ] The price is announced with "once" so it cannot be mistaken for a
      subscription.
- [ ] Restore is reachable and labelled.
- [ ] The free-tier footer is announced, not visual-only.

### 3.14 Error states
- [ ] Every error announces title, one sentence, and its buttons.
- [ ] Where HopPotty is still useful (Gentle mode works), that is announced.
- [ ] "Restore Screen Access" is reachable from Settings under VoiceOver in ≤4
      moves — this is the emergency path and it must be fast.

---

## 4. Known gaps and open questions

| # | Item | Status |
| --- | --- | --- |
| 1 | The entire checklist above | **Never executed.** No device. |
| 2 | Whether the shield honours Dynamic Type or any accessibility setting | **UNVERIFIED.** Apple documents a fixed layout; behaviour under large text is unknown. |
| 3 | VoiceOver behaviour on the shield | Apple's implementation; must be observed. |
| 4 | Whether `FamilyActivityPicker` is usable under Switch Control | Apple's UI; not ours to fix, but must be documented for caregivers if it is poor. |
| 5 | Voice assets | None recorded. Every line is caption-only. When audio ships, each line needs a caption re-check. |
| 6 | Localisation | English only. `HopCopy` keys are stable and placeholder-checked, so the structure is ready; no second language has been proofed. |
| 7 | Automated accessibility audit | An `XCUIApplication` audit pass should run in CI once an Xcode project exists. Not written. |

**Nothing in this document should be read as "HopPotty is accessible".** It is a
statement of what the app is built to do and a plan for proving it.
