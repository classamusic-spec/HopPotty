import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

/// The grown-up check.
///
/// Two deliberate properties: it is boring, and it is not a game. A gate that
/// looks fun is a gate a three-year-old will try to beat. The hold is long
/// enough to be uninteresting and the sum is beyond a preschooler, and neither
/// is dressed up.
public struct HopParentGate: View {
    @Environment(\.hopTheme) private var theme
    @State private var model: HopParentGateModel
    @State private var holdProgress: Double = 0

    private let onPass: () -> Void
    private let onCancel: () -> Void

    public init(style: ParentGateStyle, onPass: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self._model = State(initialValue: HopParentGateModel(style: style))
        self.onPass = onPass
        self.onCancel = onCancel
    }

    /// Pins the challenge, for previews and tests.
    init(model: HopParentGateModel, onPass: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self._model = State(initialValue: model)
        self.onPass = onPass
        self.onCancel = onCancel
    }

    private let holdDuration: Double = 1.2

    public var body: some View {
        VStack(spacing: theme.spacing.xxl) {
            header

            switch model.stage {
            case .holding: holdControl
            case .answering: arithmetic
            case .authenticating: HopLoadingState(message: HopStrings.gateBiometricPrompt)
            case .unavailable: unavailable
            case .passed: EmptyView()
            }

            Spacer(minLength: 0)

            HopSecondaryButton(HopStrings.cancel, action: onCancel)
        }
        .padding(theme.spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.color.backgroundPrimary)
        .task {
            guard model.stage == .authenticating else { return }
            if await model.authenticateDeviceOwner() { onPass() }
        }
    }

    private var header: some View {
        VStack(spacing: theme.spacing.s) {
            HopGlyphBadge(.shield, tint: theme.color.brandAction, diameter: 56)
            Text(HopStrings.gateTitle)
                .hopTextStyle(.parentTitle)
                .foregroundStyle(theme.color.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, theme.spacing.xxl)
    }

    // MARK: - Hold

    private var holdControl: some View {
        VStack(spacing: theme.spacing.l) {
            ZStack {
                Circle()
                    .stroke(theme.color.divider, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(theme.color.brandAction, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(HopStrings.gateHoldPrompt)
                    .hopTextStyle(.parentHeadline)
                    .foregroundStyle(theme.color.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(theme.spacing.l)
            }
            .frame(width: 176, height: 176)
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: holdDuration, maximumDistance: 40) {
                model.completeHold()
            } onPressingChanged: { isPressing in
                // A determinate fill that has to track real elapsed time, so it
                // is linear and not a motion token; Reduce Motion does not
                // remove it because it is the progress readout, not decoration.
                withAnimation(.linear(duration: isPressing ? holdDuration : 0.18)) {
                    holdProgress = isPressing ? 1 : 0
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(HopStrings.gateHoldPrompt)
            .accessibilityHint(HopStrings.gateHoldHint)
            // Switch Control and VoiceOver cannot express a press-and-hold, so
            // activating the element skips straight to the sum. The sum is the
            // part that actually gates; the hold only filters flailing.
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.completeHold() }

            Text(HopStrings.gateHoldHint)
                .hopTextStyle(.parentCallout)
                .foregroundStyle(theme.color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Arithmetic

    private var arithmetic: some View {
        VStack(spacing: theme.spacing.l) {
            Text("\(HopStrings.gateSumPrompt) \(model.challenge.question)?")
                .hopTextStyle(.parentTitle)
                .foregroundStyle(theme.color.textPrimary)
                .hopNumericText()
                .accessibilityLabel("\(HopStrings.gateSumPrompt) \(model.challenge.left) plus \(model.challenge.right)?")

            Text(model.entry.isEmpty ? " " : model.entry)
                .hopTextStyle(.metric)
                .foregroundStyle(theme.color.textPrimary)
                .frame(minWidth: 120, minHeight: 48)
                .background {
                    RoundedRectangle(cornerRadius: theme.radius.m, style: .continuous)
                        .fill(theme.color.surfaceSunken)
                }
                .accessibilityLabel(HopStrings.gateSumHint)
                .accessibilityValue(model.entry)

            if let retryMessage = model.retryMessage {
                Text(retryMessage)
                    .hopTextStyle(.parentCallout)
                    .foregroundStyle(theme.color.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isStaticText)
            }

            keypad
        }
    }

    private var keypad: some View {
        Grid(horizontalSpacing: theme.spacing.m, verticalSpacing: theme.spacing.m) {
            ForEach(0..<3) { row in
                GridRow {
                    ForEach(1..<4) { column in
                        digitKey(row * 3 + column)
                    }
                }
            }
            GridRow {
                key(label: HopStrings.gateDelete, systemImage: "delete.left") { model.deleteLast() }
                digitKey(0)
                key(label: HopStrings.gateDone, systemImage: "checkmark") {
                    if model.submit() { onPass() }
                }
            }
        }
        .frame(maxWidth: 320)
    }

    private func digitKey(_ digit: Int) -> some View {
        key(label: digit.formatted(), systemImage: nil) { model.append(digit) }
    }

    private func key(label: String, systemImage: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 20, weight: .semibold))
                } else {
                    Text(label).hopTextStyle(.parentTitle).hopNumericText()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(HopButtonStyle(size: .parent, appearance: .tonal(tint: theme.color.brandAction)))
        .accessibilityLabel(label)
    }

    private var unavailable: some View {
        VStack(spacing: theme.spacing.l) {
            Text(HopStrings.gateBiometricUnavailable)
                .hopTextStyle(.parentBody)
                .foregroundStyle(theme.color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HopPrimaryButton(HopStrings.gateDone) { model.fallBackToArithmetic() }
        }
    }
}

/// Presents the gate and runs `onPass` only after it is passed.
///
/// The form features should reach for: a destructive or purchasing action calls
/// this rather than presenting the gate itself, so no call site can forget to
/// wait for the result.
public extension View {
    func hopParentGated(
        isPresented: Binding<Bool>,
        style: ParentGateStyle = .holdAndArithmetic,
        onPass: @escaping () -> Void
    ) -> some View {
        modifier(HopParentGateModifier(isPresented: isPresented, style: style, onPass: onPass))
    }
}

public struct HopParentGateModifier: ViewModifier {
    @Binding var isPresented: Bool
    let style: ParentGateStyle
    let onPass: () -> Void

    public func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            HopParentGate(
                style: style,
                onPass: {
                    isPresented = false
                    onPass()
                },
                onCancel: { isPresented = false }
            )
            .presentationDetents([.large])
            .hopThemedRoot()
        }
    }
}

#if DEBUG
/// Preview host: builds the model, optionally advances it past the hold, and
/// keeps the `#Preview` bodies to a single expression.
private struct HopParentGatePreview: View {
    let challenge: HopArithmeticChallenge
    var skipsHold: Bool = false

    @State private var model: HopParentGateModel

    init(challenge: HopArithmeticChallenge, skipsHold: Bool = false) {
        self.challenge = challenge
        self.skipsHold = skipsHold
        let model = HopParentGateModel(style: .holdAndArithmetic, challenge: challenge)
        if skipsHold { model.completeHold() }
        self._model = State(initialValue: model)
    }

    var body: some View {
        HopParentGate(model: model, onPass: {}, onCancel: {})
    }
}

#Preview("Parent gate · hold") {
    HopParentGatePreview(challenge: HopArithmeticChallenge(left: 27, right: 46))
        .hopThemedRoot()
}

#Preview("Parent gate · sum") {
    HopParentGatePreview(challenge: HopArithmeticChallenge(left: 27, right: 46), skipsHold: true)
        .hopThemedRoot()
}

#Preview("Parent gate · sum, AX3") {
    HopParentGatePreview(challenge: HopArithmeticChallenge(left: 27, right: 46), skipsHold: true)
        .environment(\.dynamicTypeSize, .accessibility3)
        .hopThemedRoot()
}

#Preview("Parent gate · sum, dark") {
    HopParentGatePreview(challenge: HopArithmeticChallenge(left: 33, right: 19), skipsHold: true)
        .hopThemedRoot()
        .preferredColorScheme(.dark)
}

#Preview("Parent gate · high contrast") {
    HopParentGatePreview(challenge: HopArithmeticChallenge(left: 27, right: 46))
        .hopThemedRoot(appearance: .lightHighContrast)
}

#Preview("Parent gate · iPad") {
    HopParentGatePreview(challenge: HopArithmeticChallenge(left: 27, right: 46), skipsHold: true)
        .frame(width: 834, height: 900)
        .hopThemedRoot()
}
#endif
