import SwiftUI
import HopPottyCore

// The gate as a modifier, which is the form features use.
//
// INTEGRATION NOTE. `Docs/DesignSystemAPI.md` lists `HopParentGate` and
// `.hopParentGated(isPresented:onPass:)` under the design system. This file is
// the feature-layer implementation of that contract, written here because every
// gated call site lives in `Features/`. If the design system ships its own
// `hopParentGated`, delete this file and `ParentGateView.swift` — no call site
// changes, because the signature below is the documented one.

/// The gate style the app is configured for.
///
/// An environment value rather than a lookup inside the modifier, so the gate
/// works identically in a preview with no `ParentEnvironment` installed, and so
/// a caregiver's choice in Settings reaches every gate in one place.
private struct ParentGateStyleKey: EnvironmentKey {
    static let defaultValue: ParentGateStyle = .holdAndArithmetic
}

extension EnvironmentValues {
    var parentGateStyle: ParentGateStyle {
        get { self[ParentGateStyleKey.self] }
        set { self[ParentGateStyleKey.self] = newValue }
    }
}

struct ParentGateModifier: ViewModifier {
    @Environment(\.parentGateStyle) private var style

    @Binding var isPresented: Bool
    let reason: ParentAuthorization.Reason
    let onPass: (ParentAuthorization) -> Void

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            ParentGateView(
                style: style,
                reason: reason,
                onPass: { authorization in
                    isPresented = false
                    onPass(authorization)
                },
                onCancel: { isPresented = false }
            )
            // Medium is enough for a question and a field, and leaving the app
            // partly visible behind the sheet makes it obvious the gate is a
            // step rather than a new place.
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
        }
    }
}

extension View {
    /// Raises the grown-up gate, and runs `onPass` only if it is passed.
    ///
    /// The documented form from `Docs/DesignSystemAPI.md`. Use the `reason:`
    /// overload where the caller needs the minted `ParentAuthorization` to hand
    /// to a repository — every destructive method takes one.
    func hopParentGated(isPresented: Binding<Bool>, onPass: @escaping () -> Void) -> some View {
        modifier(
            ParentGateModifier(
                isPresented: isPresented,
                reason: .openParentArea,
                onPass: { _ in onPass() }
            )
        )
    }

    /// The form that yields proof the gate was passed.
    func hopParentGated(
        isPresented: Binding<Bool>,
        reason: ParentAuthorization.Reason,
        onPass: @escaping (ParentAuthorization) -> Void
    ) -> some View {
        modifier(ParentGateModifier(isPresented: isPresented, reason: reason, onPass: onPass))
    }
}

#if DEBUG
private struct ParentGateModifierPreview: View {
    @State private var showing = false
    @State private var passed = false

    var body: some View {
        VStack(spacing: 24) {
            Button("Open a grown-up area") { showing = true }
            if passed { Text(verbatim: "Passed") }
        }
        .hopParentGated(isPresented: $showing, reason: .openParentArea) { _ in passed = true }
    }
}

#Preview("Gate modifier") {
    ParentGateModifierPreview().hopThemedRoot()
}
#endif
