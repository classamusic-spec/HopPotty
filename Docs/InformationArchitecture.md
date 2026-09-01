# Information Architecture

**Date:** 2026-09-01
**Status:** Design of record. The SwiftUI navigation code is being written and has
never been compiled (`BUILD_STATUS.md`), so treat this as the specification the
views must satisfy, not a description of a running app.

---

## 1. The one boundary that matters

HopPotty has two spaces, and the line between them is the app's most important
structural decision.

| | **Parent Space** | **Child Space** |
| --- | --- | --- |
| Audience | Adult | Pre-reader, 2–5 |
| Type | Standard system font, 17pt body | Rounded design, 24pt+ instructions |
| Hit targets | ≥44pt | ≥72pt, primary ≥96pt |
| Reads | Timeline, patterns, settings, purchase | Hop, the routine, the pond, games |
| Can destroy data | Yes, behind the gate | Never |
| Can change a schedule | Yes | Never |
| Sees another child's data | Only by switching child, explicitly | Never |
| Sees a price, a purchase, an external link | Yes | **Never** |

**A child in Child Space cannot reach anything that costs money, deletes data,
changes a setting, or leaves the app.** That is not a matter of hiding controls:
Child Space simply does not contain them. The gate exists for the transition, not
as a lock on individual buttons.

---

## 2. Navigation — iPhone (compact)

```
HopPotty
├─ Onboarding  (modal, full screen, first launch only)
│
├─ Parent Space  — TabView, 3 tabs
│   ├─ Today          parent home: next pause, today's counts, timeline
│   │   ├─ Log a visit                 (sheet)
│   │   ├─ Event detail / edit         (sheet)
│   │   └─ Start a pause now           (inline action)
│   ├─ Patterns       insights for the selected window
│   │   └─ Window picker: today · this week · last 7/30 days
│   └─ Settings
│       ├─ Potty Pause  (mode, basis, interval, warning, duration, cooldown,
│       │                active hours/days, quiet times, enable/disable)
│       ├─ Child        (nickname, character, pond, add child, remove child)
│       ├─ Sound and voice
│       ├─ What your child sees   (mini-games, questions, sit timer)
│       ├─ Notifications
│       ├─ Privacy and data       (export, delete child, delete everything)
│       ├─ Grown-up gate          (hold+sum · Face ID/passcode)
│       ├─ Restore Screen Access  ← the emergency exit, always reachable
│       ├─ Unlock HopPotty        (paywall, restore)
│       └─ About                  (version, privacy policy, support)
│
└─ Child Space  — full-screen cover, no tab bar, no navigation chrome
    ├─ Potty Pause screen      (Hop, one invitation, one big button)
    ├─ Guided routine          (try → wipe → flush → wash → high five)
    ├─ Celebration             (star lands, ≤3.5s)
    ├─ Hop's Pond              (the scene, next unlock and its price)
    ├─ Play                    (three mini-games)
    └─ Hop's questions         (quiz round of 3)
```

The child-switcher lives in the Today tab's header, not in a tab. Switching child
is a Parent Space action; Child Space runs as exactly one child
(`ChildContext`, installed once at the root of a child flow).

---

## 3. Navigation — iPad (regular width)

Same information, different frame. iPad is **not** the phone layout stretched.

```
Parent Space  — NavigationSplitView
┌───────────────┬──────────────────────────────────────────┐
│ Sidebar       │ Detail                                    │
│ • Today       │  content capped at HopLayout.readableWidth│
│ • Patterns    │  (640pt) and centred — a settings row must│
│ • Potty Pause │  not become a label at one edge and a     │
│ • Child       │  value at the other                       │
│ • Sound       │                                           │
│ • Privacy     │  page margin 32pt (HopSpacing.pageRegular)│
│ • About       │                                           │
└───────────────┴──────────────────────────────────────────┘

Child Space   — full-screen cover over the whole window, sidebar hidden.
                Stage size is capped (ChildStage), not scaled: a 600pt frog
                is not a better frog. Content width ≤ 760pt
                (HopLayout.childContentWidth), centred, with the scene
                breathing around it.
```

Layout constants: `HopLayout.pageMargin(for:)` → 20pt compact / 32pt regular;
`readableWidth` 640; `childContentWidth` 760.

Multiple scenes are **off** (`UIApplicationSupportsMultipleScenes = false`): a
pause is device-wide and single-child, and two live copies of the pause UI on one
iPad would be two readings of state that must have one.

---

## 4. Surfaces outside the app

Three surfaces the app does not draw, and cannot style beyond what Apple allows:

| Surface | Owner | HopPotty's control |
| --- | --- | --- |
| **The shield** | ManagedSettingsUI, drawn by the system | Blur style, background colour, one static image, title, subtitle, primary button (label + colour), optional secondary, ≤3 submenu items on 26.4+. No custom views, no fonts, no animation. Pre-resolved by the app into `ShieldPresentation` and read by the extension. |
| **The Family Controls authorization sheet** | FamilyControls | None. System copy; Apple documents no usage-description key. |
| **`FamilyActivityPicker`** | FamilyControls | None beyond presentation. HopPotty never learns what was picked — only counts. |

The shield is the one child-facing surface where the design system does not
apply. It is designed as its own artefact (`ScreenTimeArchitecture.md` §11.4).

---

## 5. Where the parent gate is required

`HopParentGate` / `.hopParentGated(...)`, styles `holdAndArithmetic` (default) and
`deviceOwner`. A pass mints a `ParentAuthorization`, valid **15 minutes**
(`ParentAuthorization.validity`), scoped by `Reason`.

### 5.1 Transitions that REQUIRE the gate

| # | Transition | Gate reason |
| --- | --- | --- |
| 1 | Child Space → Parent Space (any entry) | `openParentArea` |
| 2 | Change any Potty Pause setting: mode, basis, interval, warning, duration, cooldown, active hours/days, quiet windows, enable/disable | `changeSchedule` |
| 3 | Suspend: skip next · pause until tomorrow · disable | `changeSchedule` |
| 4 | **Restore Screen Access** (the emergency exit) | `changeSchedule` |
| 5 | Open the app picker / change the Screen Time selection | `changeSchedule` |
| 6 | Add, rename or remove a child; switch active child | `changeSchedule` |
| 7 | Delete a potty event or clear history | `deleteData` |
| 8 | Reset rewards · delete a child · reset the app | `deleteData` |
| 9 | Export data | `exportData` |
| 10 | Open the paywall, buy, or restore a purchase | `purchase` / `restorePurchase` |
| 11 | Open the privacy policy, support, or any external link | `openParentArea` |
| 12 | Change sound, caption, notification or gate settings | `openParentArea` |

Because #1 gates the whole space, #2–#12 are re-gated only when the
authorization has expired, or when the action is destructive or financial — those
always re-prompt regardless of a live authorization, and always state exactly
what will be removed, with counts (`CONTRACTS.md` §4.6, `DeletionPlan`).

### 5.2 Transitions that must NOT be gated

| Transition | Why |
| --- | --- |
| Parent Space → Child Space ("Hand it to your child") | Handing the device over must be instant. |
| Anything inside Child Space: routine steps, pond, games, quizzes, replaying a line | A gate mid-routine is a wall in front of a three-year-old. |
| Dismissing the shield's own primary button | It is the child's button. |
| Ending a pause by any of the five paths | Access is never gated on anything. |
| Viewing today's timeline read-only from the Today tab | Already inside Parent Space. |

### 5.3 The rule for the emergency exit

**"Restore Screen Access" is gated but never blocked.** It is behind the parent
gate because it changes system state; it is accepted from *every* machine state
and never refused (`PottyPauseEvent.parentRestoredAccess`). A caregiver must
never have to be right about what HopPotty thinks is happening in order to give
their child their apps back.

---

## 6. Entry points into Child Space

1. **"Hand it to your child"** on the parent home — deliberate handover.
2. **A Potty Pause fires** while HopPotty is foregrounded — the pause screen
   presents itself over whatever was on screen.
3. **The child taps the shield's primary button** on iOS 26.5+, where
   `.openParentalControlsApp` brings HopPotty forward. Below 26.5 the shield
   clears and the child lands on the Home Screen; the star is drained and shown
   the next time HopPotty is opened. Child copy therefore never promises an
   immediate star.

Exiting Child Space is always the same gesture: a small, adult-shaped control in
a corner that raises the parent gate.

---

## 7. Empty, error and locked states

Every surface has four defined states, from `ParentLoadState` and the
`HopEmptyState` / `HopErrorState` / `HopLoadingState` / `HopLockedState`
components:

| State | Rule |
| --- | --- |
| First load | Skeleton, not a spinner, and only on the first read. |
| Empty | Distinct from "loaded with nothing". Only "nothing yet" gets an invitation to log something. |
| Error | Title, one sentence, at most two buttons, mapped once in `ParentErrorPresentation` so the same problem never gets two explanations. Says whether HopPotty is still useful (Gentle mode keeps working). |
| Locked | `HopLockedState(feature:)` names what unlocking *adds*, never what the family is missing. Always behind the gate. |
