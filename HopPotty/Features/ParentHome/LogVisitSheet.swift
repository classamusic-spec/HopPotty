import SwiftUI
import HopPottyCore

/// Logging a visit by hand.
///
/// Four kinds, drawn the same size and in the same style. `tried` comes first
/// because it is the primary event; `accident` sits with the others and carries
/// one line of plain explanation rather than a warning colour — a caregiver
/// recording an accident is doing exactly what the app asked them to do.
///
/// The timestamp is editable and defaults to now. A parent who noticed twenty
/// minutes late should be able to say so, which is why `PottyEvent.timestamp`
/// is "when it happened", not "when it was recorded".
struct LogVisitSheet: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(ParentEnvironment.self) private var parent

    let onSave: (PottyEventKind, Date, String?) async -> Void

    @State private var kind: PottyEventKind = .tried
    @State private var timestamp = Date()
    @State private var note = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(HopCopy.parentHome.timelineAddButton.localized, selection: $kind) {
                        ForEach(PottyEventKind.parentDisplayOrder) { candidate in
                            Text(verbatim: candidate.parentLabel).tag(candidate)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } footer: {
                    if kind == .accident {
                        Text(hop: HopCopy.parentHome.eventAccidentFooter)
                    }
                }

                Section {
                    DatePicker(
                        HopCopy.timerSettings.activeHoursLabel.localized,
                        selection: $timestamp,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section {
                    TextField(HopCopy.parentHome.eventNotePlaceholder.localized, text: $note, axis: .vertical)
                        .lineLimit(1...4)
                } footer: {
                    Text(hop: HopCopy.parentHome.eventNotePlaceholder)
                }
            }
            .navigationTitle(Text(hop: HopCopy.parentHome.timelineAddButton))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(HopCopy.common.cancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(HopCopy.common.save.localized) {
                        Task {
                            isSaving = true
                            await onSave(
                                kind,
                                timestamp,
                                note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
                            )
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear { timestamp = parent.clock.now }
        }
        .presentationDetents([.medium, .large])
    }
}

#if DEBUG
#Preview("Log a visit") {
    LogVisitSheet { _, _, _ in }
        .environment(ParentEnvironment.preview())
        .hopThemedRoot()
}

#Preview("Log a visit, AX3 dark") {
    LogVisitSheet { _, _, _ in }
        .environment(ParentEnvironment.preview())
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
        .hopThemedRoot()
}
#endif
