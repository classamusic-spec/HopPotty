import SwiftUI
import HopPottyCore

/// The gate itself.
///
/// Presented as a sheet by `.hopParentGated(isPresented:onPass:)`; features do
/// not construct this directly.
struct ParentGateView: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled

    let style: ParentGateStyle
    let reason: ParentAuthorization.Reason
    let onPass: (ParentAuthorization) -> Void
    let onCancel: () -> Void

    @State private var phase: ParentGatePhase = .holding
    @State private var challenge = ParentGateChallenge.random()
    @State private var typedAnswer = ""
    @State private var holdProgress: Double = 0
    @State private var holdTask: Task<Void, Never>?
    @State private var attemptsLeft = ParentGateChallenge.attemptsPerChallenge
    @FocusState private var answerFocused: Bool

    private let authenticator = DeviceOwnerAuthenticator()

    /// A hold is a gesture some people cannot perform and VoiceOver cannot
    /// describe. When either assistive technology is on, the challenge starts at
    /// the sum — which is still an adult-only step, and is the part that
    /// actually does the work.
    private var skipsHold: Bool { voiceOverEnabled || switchControlEnabled }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                header
                // The gate is a modal, and its steps replace each other inside
                // it: the hold gives way to the sum, the sum to the device
                // check. Each one belongs *here*, over what was already on
                // screen, so each arrives in place rather than sliding in from
                // somewhere it was never coming from.
                Group {
                    switch phase {
                    case .holding:
                        holdStep
                            .hopScreenTransition(.modal)
                    case .answering, .retrying, .fellBackToArithmetic:
                        arithmeticStep
                            .hopScreenTransition(.modal)
                    case .authenticating:
                        HopLoadingState(message: HopCopy.parentGate.deviceOwnerReason.localized)
                            .hopScreenTransition(.modal)
                    case .passed:
                        EmptyView()
                    }
                }
                .hopScreenChange(.modal, value: phase)
                Spacer(minLength: 0)
            }
            .padding(theme.spacing.l)
            .hopReadableWidth()
            .frame(maxWidth: .infinity, alignment: .leading)
            .hopBackground(.primary)
            .navigationTitle(Text(hop: HopCopy.parentGate.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(HopCopy.common.cancel.localized, action: cancel)
                }
            }
        }
        .task { await start() }
        .onDisappear { holdTask?.cancel() }
    }

    // MARK: Steps

    private var header: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(hop: HopCopy.parentGate.body)
                .font(theme.font(.parentBody))
                .foregroundStyle(theme.color.textSecondary)
            if phase == .fellBackToArithmetic {
                Text(verbatim: HopStrings.gateBiometricUnavailable)
                    .font(theme.font(.parentFootnote))
                    .foregroundStyle(theme.color.textSecondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var holdStep: some View {
        VStack(spacing: theme.spacing.m) {
            ZStack {
                Circle()
                    .strokeBorder(theme.color.divider, lineWidth: 10)
                HopProgressRing(progress: holdProgress, lineWidth: 10, tint: theme.color.brandAction)
                Text(hop: HopCopy.parentGate.holdInstruction)
                    .font(theme.font(.parentHeadline))
                    .foregroundStyle(theme.color.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(theme.spacing.m)
            }
            .frame(width: 180, height: 180)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in beginHold() }
                    .onEnded { _ in cancelHold() }
            )
            .accessibilityElement()
            .hopAccessibilityLabel(HopCopy.parentGate.holdInstruction)
            .accessibilityHint(Text(verbatim: HopStrings.gateHoldHint))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { advanceToArithmetic() }
        }
        .frame(maxWidth: .infinity)
    }

    private var arithmeticStep: some View {
        VStack(alignment: .leading, spacing: theme.spacing.m) {
            Text(verbatim: challenge.question)
                .font(theme.font(.parentTitle))
                .foregroundStyle(theme.color.textPrimary)

            TextField(HopStrings.gateSumPrompt, text: $typedAnswer)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(theme.font(.metric))
                .focused($answerFocused)
                .padding(theme.spacing.s)
                .background(
                    RoundedRectangle(cornerRadius: theme.radius.m, style: .continuous)
                        .fill(theme.color.surfaceSunken)
                )
                .accessibilityLabel(Text(verbatim: challenge.question))
                .accessibilityHint(Text(verbatim: HopStrings.gateSumHint))
                .onChange(of: typedAnswer) { _, newValue in
                    typedAnswer = String(newValue.filter(\.isNumber).prefix(3))
                }

            if phase == .retrying {
                Text(hop: HopCopy.parentGate.retry)
                    .font(theme.font(.parentFootnote))
                    .foregroundStyle(theme.color.warning)
                    .accessibilityAddTraits(.isStaticText)
            }

            HopPrimaryButton(HopCopy.common.done.localized, action: submit)
                .disabled(typedAnswer.isEmpty)
        }
        .onAppear { answerFocused = true }
    }

    // MARK: Behaviour

    private func start() async {
        switch style {
        case .deviceOwner:
            phase = .authenticating
            let result = await authenticator.authenticate(
                reason: HopCopy.parentGate.deviceOwnerReason.localized
            )
            switch result {
            case .passed:
                pass()
            case .cancelled:
                cancel()
            case .unavailable, .failed:
                // Never a dead end: the caregiver still gets in through the sum.
                phase = .fellBackToArithmetic
            }
        case .holdAndArithmetic:
            phase = skipsHold ? .answering : .holding
        }
    }

    private func beginHold() {
        guard phase == .holding, holdTask == nil else { return }
        holdTask = Task { @MainActor in
            let steps = 30
            let step = ParentGateChallenge.holdDuration / Double(steps)
            for index in 1...steps {
                try? await Task.sleep(for: .seconds(step))
                if Task.isCancelled { return }
                holdProgress = Double(index) / Double(steps)
            }
            advanceToArithmetic()
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        guard phase == .holding else { return }
        withAnimation(theme.animation(.parentTap)) { holdProgress = 0 }
    }

    private func advanceToArithmetic() {
        holdTask = nil
        holdProgress = 1
        withAnimation(theme.animation(.parentTransition)) { phase = .answering }
    }

    private func submit() {
        guard challenge.accepts(typedAnswer) else {
            attemptsLeft -= 1
            typedAnswer = ""
            if attemptsLeft <= 0 {
                // A fresh sum rather than a lockout. See `attemptsPerChallenge`.
                challenge = .random()
                attemptsLeft = ParentGateChallenge.attemptsPerChallenge
            }
            withAnimation(theme.animation(.parentTap)) { phase = .retrying }
            return
        }
        pass()
    }

    private func pass() {
        phase = .passed
        onPass(ParentAuthorization.mint(reason: reason))
    }

    private func cancel() {
        holdTask?.cancel()
        onCancel()
    }
}

#if DEBUG
#Preview("Hold and sum") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ParentGateView(style: .holdAndArithmetic, reason: .openParentArea, onPass: { _ in }, onCancel: {})
        }
        .hopThemedRoot()
}

#Preview("Sum step, AX3") {
    ParentGateView(style: .holdAndArithmetic, reason: .deleteData, onPass: { _ in }, onCancel: {})
        .environment(\.dynamicTypeSize, .accessibility3)
        .hopThemedRoot()
}

#Preview("Device owner, dark") {
    ParentGateView(style: .deviceOwner, reason: .purchase, onPass: { _ in }, onCancel: {})
        .preferredColorScheme(.dark)
        .hopThemedRoot()
}
#endif
