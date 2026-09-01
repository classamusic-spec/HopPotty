import SwiftUI

/// The only way into the Potty Pause Lab.
///
/// ## Why the gate is structural and not a flag
///
/// The Lab can raise a shield over a child's apps, cancel every scheduled
/// monitor, and wipe the App Group. A build setting, a launch argument, a
/// `UserDefaults` key or a hidden gesture would all be one mistake away from
/// shipping that to a family — and the mistake would be invisible, because a
/// release build with a hidden developer menu looks exactly like one without.
///
/// So the gate is the compiler. In a release build:
///
/// - `PottyPauseLab` does not exist. The type is inside `#if DEBUG`.
/// - `developerSurface()` below compiles to `self`. Not "returns early", not
///   "renders nothing" — the modifier body has no reference to the Lab in it at
///   all, so there is no symbol to reach and nothing to strip.
/// - There is no string, no key, and no gesture that could turn it on, because
///   there is no `if` anywhere to be turned.
///
/// Call sites are written once and compile in both configurations:
///
/// ```swift
/// ParentHomeView()
///     .developerSurface()
/// ```
public extension View {

    #if DEBUG
    /// Attaches a long-press on the parent home screen that opens the Lab.
    ///
    /// A long press rather than a visible button: the Lab is for the people
    /// building HopPotty, and a TestFlight build goes to caregivers who should not
    /// meet it by accident. That is convenience, not security — the security is
    /// that this whole method does not exist in a release build.
    func developerSurface() -> some View {
        modifier(DeveloperSurfaceModifier())
    }
    #else
    /// Release build: does nothing, and contains nothing.
    @inlinable
    func developerSurface() -> some View { self }
    #endif
}

#if DEBUG
struct DeveloperSurfaceModifier: ViewModifier {
    @State private var isPresented = false
    @Environment(\.screenTimeEnvironment) private var screenTime

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 2) { isPresented = true }
            .sheet(isPresented: $isPresented) {
                if let screenTime {
                    PottyPauseLab(environment: screenTime)
                } else {
                    // A Lab with no environment would have to construct one, and
                    // the only thing it could construct is a live service —
                    // which is the one thing a diagnostic screen must not do
                    // behind the app's back.
                    Text("No ScreenTimeEnvironment injected.")
                        .font(.footnote.monospaced())
                        .padding()
                }
            }
    }
}
#endif
