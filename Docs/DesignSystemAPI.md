# Design System API Contract

Feature work is written against these signatures. The design system target owns
the implementations; feature targets own the call sites. Neither may change this
file without telling the other.

All components live in `HopPotty/DesignSystem/Components/` and are `public` to
the app target.

## Foundation

```swift
// Environment access — resolves the appearance (light/dark/high contrast)
// automatically from colorScheme + colorSchemeContrast.
@Environment(\.hopTheme) var theme      // HopTheme
theme.color.textPrimary                 // SwiftUI Color, from HopSemanticPalette
theme.font(.parentBody)                 // SwiftUI Font, from HopTypography
theme.spacing.l                         // CGFloat, from HopSpacing
theme.radius.xl                         // CGFloat
theme.elevation(.raised)                // ViewModifier applying shadow

// Motion. Always route through this so Reduce Motion is honoured in one place.
theme.animation(.childCelebrate)        // Animation, degrades to a fade
```

## Buttons

```swift
HopPrimaryButton(_ title: String, icon: String? = nil, size: HopButtonSize = .parent, action: () -> Void)
HopSecondaryButton(_ title: String, icon: String? = nil, action: () -> Void)
HopIconButton(systemImage: String, accessibilityLabel: String, action: () -> Void)
HopDestructiveButton(_ title: String, action: () -> Void)

enum HopButtonSize { case parent, child, childPrimary }   // 44 / 72 / 96 pt minimum
```

## Containers

```swift
HopCard<Content: View>(elevation: HopElevation = .resting, content: () -> Content)
HopSection<Content: View>(_ title: String?, footer: String? = nil, content: () -> Content)
HopSheet<Content: View>(title: String, onDismiss: () -> Void, content: () -> Content)
```

## Parent data display

```swift
HopMetricCard(value: String, label: String, glyph: HopGlyph, tint: Color)
HopTimerCard(state: PottyPauseDisplayState, onSkip: () -> Void, onStartNow: () -> Void)
HopProgressRing(progress: Double, lineWidth: CGFloat = 12, tint: Color)
HopTimelineRow(event: PottyEvent, isLast: Bool)
HopInsightCard(insight: Insight, onAction: ((InsightAction) -> Void)?)
HopSettingsRow(title: String, value: String?, icon: String, action: () -> Void)
HopToggleRow(title: String, subtitle: String?, icon: String, isOn: Binding<Bool>)
HopSectionHeader(_ title: String, action: (title: String, handler: () -> Void)? = nil)
HopPill(_ text: String, tint: Color, glyph: HopGlyph? = nil)
```

## Child surfaces

```swift
HopCharacterStage(pose: HopPose, size: CGFloat, ambient: Bool = true)
HopSpeechBubble(_ text: String, tail: HopBubbleTail = .bottomLeading)
HopStarBadge(count: Int, animatesArrival: Bool = false)
HopCelebrationView(stars: Int, unlocked: PondItemID?, onComplete: () -> Void)
HopStepIndicator(total: Int, current: Int)
HopAudioButton(line: HopVoiceLine)          // replay spoken prompt
HopAvatar(style: HopAvatarStyle, size: CGFloat)
HopModeSelector(selection: Binding<PottyPauseMode>)
```

## States

```swift
HopEmptyState(glyph: HopGlyph, title: String, message: String, action: (String, () -> Void)?)
HopErrorState(failure: ScreenTimeFailure, onReviewSettings: () -> Void, onDismiss: () -> Void)
HopLoadingState(message: String?)
HopLockedState(feature: PaywallFeature, onUnlock: () -> Void)   // behind parent gate
```

## Gate

```swift
HopParentGate(style: ParentGateStyle, onPass: () -> Void, onCancel: () -> Void)
// Modifier form, the one features should normally use:
.hopParentGated(isPresented: Binding<Bool>, onPass: () -> Void)
```

## Glyphs

`HopGlyph` is an enum wrapping SF Symbol names plus HopPotty's own illustrated
marks, so meaning is never carried by colour alone:

```swift
enum HopGlyph { case tried, pee, poop, accident, star, check, pause, play,
                     timer, quietHours, shield, wash, flush, wipe, highFive, pond }
```

## Poses

```swift
enum HopPose { case idle, blink, wave, jump, walk, wait, cheer }
```
Matches the generated art in `Art/character/hop-<pose>.svg` one-to-one.
