import SwiftUI
import HopPottyCore

/// Something in Settings that may only happen after the grown-up gate.
///
/// The four gated actions are gathered here rather than scattered across the
/// form, so the list of what is protected is readable in one place: the
/// purchase, the data export, and the two deletions. External links are gated
/// at their own row (`ExternalLinkRow`), and the Screen Time rows gate
/// themselves where they sit.
struct SettingsGateRequest: Identifiable, Equatable {
    enum Kind: Equatable {
        case purchase
        case export
        case deleteChild(UUID)
        case deleteEverything
    }

    let kind: Kind

    var id: String {
        switch kind {
        case .purchase: "purchase"
        case .export: "export"
        case .deleteChild(let childID): "delete-\(childID.uuidString)"
        case .deleteEverything: "delete-everything"
        }
    }

    var reason: ParentAuthorization.Reason {
        switch kind {
        case .purchase: .purchase
        case .export: .exportData
        case .deleteChild, .deleteEverything: .deleteData
        }
    }
}

/// Raises the gate for a request, then runs what the request asked for.
///
/// A deletion takes two steps on purpose: the gate proves an adult is present,
/// and the confirmation sheet tells that adult exactly what is about to go.
/// Neither replaces the other — a gate with no receipt is a wall with no sign,
/// and a receipt with no gate is a sign a four-year-old can walk past.
struct SettingsGateHost: ViewModifier {
    @Environment(ParentEnvironment.self) private var parent

    @Binding var request: SettingsGateRequest?
    let model: SettingsModel?

    @State private var authorization: ParentAuthorization?
    @State private var isGatePresented = false
    @State private var isPaywallPresented = false
    @State private var isConfirmationPresented = false
    @State private var isExportPresented = false

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _, newValue in
                isGatePresented = newValue != nil
            }
            .hopParentGated(
                isPresented: $isGatePresented,
                reason: request?.reason ?? .openParentArea
            ) { granted in
                authorization = granted
                Task { await run(granted) }
            }
            .sheet(isPresented: $isPaywallPresented, onDismiss: clear) {
                if let authorization {
                    PaywallView(authorization: authorization)
                }
            }
            .sheet(isPresented: $isConfirmationPresented, onDismiss: clear) {
                confirmationSheet
            }
            .sheet(isPresented: $isExportPresented, onDismiss: clear) {
                if let url = model?.exportURL {
                    ExportShareSheet(url: url)
                }
            }
    }

    @ViewBuilder
    private var confirmationSheet: some View {
        if let model, let receipt = model.receipt, let action = model.pendingAction {
            DestructiveConfirmationSheet(
                title: title(for: action),
                receipt: receipt,
                isWorking: model.isWorking,
                onConfirm: {
                    guard let authorization else { return }
                    Task {
                        await model.confirm(action, authorization: authorization)
                        isConfirmationPresented = false
                    }
                }
            )
        }
    }

    private func title(for action: SettingsModel.DestructiveAction) -> String {
        switch action {
        case .deleteChild(let childID):
            let nickname = parent.children.first { $0.id == childID }?.nickname
            return HopCopy.parentGate.deleteChildTitle.localized(forNickname: nickname)
        case .deleteEverything:
            return HopCopy.parentGate.deleteEverythingTitle.localized
        }
    }

    private func run(_ granted: ParentAuthorization) async {
        guard let request, let model else { return }
        switch request.kind {
        case .purchase:
            isPaywallPresented = true
        case .export:
            await model.export(childID: parent.activeChildID, authorization: granted)
            isExportPresented = model.exportURL != nil
        case .deleteChild(let childID):
            await model.prepare(.deleteChild(childID))
            isConfirmationPresented = model.pendingAction != nil
        case .deleteEverything:
            await model.prepare(.deleteEverything)
            isConfirmationPresented = model.pendingAction != nil
        }
    }

    private func clear() {
        request = nil
        model?.cancelPendingAction()
        model?.clearExport()
        // The authorization is dropped as soon as the action it was minted for
        // finishes, rather than being kept alive for the next tap.
        authorization = nil
    }
}

/// A link that leaves HopPotty.
///
/// Gated, because "opens the web" is exactly the door a four-year-old should
/// not find, and because the App Store review guidelines expect a parental gate
/// in front of one in a kids-category app.
struct ExternalLinkRow: View {
    @Environment(\.openURL) private var openURL

    let title: String
    let url: URL?

    @State private var isGatePresented = false

    var body: some View {
        Button {
            isGatePresented = true
        } label: {
            HStack {
                Text(verbatim: title)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .accessibilityHidden(true)
            }
        }
        .disabled(url == nil)
        .hopParentGated(isPresented: $isGatePresented, reason: .openParentArea) { _ in
            if let url { openURL(url) }
        }
    }
}

/// The destinations HopPotty links out to.
///
/// Placeholders until the real URLs exist. `nil` disables the row rather than
/// opening something wrong — a broken legal link is worse than a greyed one.
enum HopLegalLinks {
    static let privacyPolicy = URL(string: "https://hoppotty.app/privacy")
    static let terms = URL(string: "https://hoppotty.app/terms")
    static let support = URL(string: "https://hoppotty.app/support")
}
