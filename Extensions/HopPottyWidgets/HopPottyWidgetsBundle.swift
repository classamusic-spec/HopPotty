import SwiftUI
import WidgetKit

/// The widget extension's entry point.
///
/// ## Why there is no `NSExtensionPrincipalClass`
///
/// The other three HopPotty extensions name a principal class in their
/// `Info.plist`, and `Scripts/verify-config.sh` checks that the class exists —
/// because a misspelled principal class builds, signs, embeds, installs and is
/// then never instantiated. A WidgetKit extension is different: it declares the
/// `com.apple.widgetkit-extension` extension point and is entered through
/// `@main` on a `WidgetBundle`, with no principal class at all. `verify-config.sh`
/// checks the *opposite* thing for this target: that the extension point is the
/// WidgetKit one, and that no principal class is declared.
///
/// ## Two widgets, one bundle
///
/// - ``NextPauseWidget`` — the home-screen and lock-screen countdown. Always
///   present, drawn from the App Group snapshot.
/// - ``PottyPauseLiveActivity`` — the lock screen and Dynamic Island while a
///   pause is actually running. Present in the bundle whether or not a pause is
///   ever started; ActivityKit only asks for it when the app has started one.
///
/// A `WidgetBundle` with a Live Activity in it needs no availability check on
/// iOS 17 — `ActivityConfiguration` arrived in 16.1, well below HopPotty's
/// deployment target (`Docs/ADR/0002-deployment-target.md`).
@main
struct HopPottyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextPauseWidget()
        PottyPauseLiveActivity()
    }
}
