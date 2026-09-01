import SwiftUI
import HopPottyCore

/// The quiet-times list.
///
/// A quiet window is a *wall-clock* range, so everything here edits
/// `LocalTimeOfDay` and never a `Date`. A window whose end is at or before its
/// start wraps midnight, which is how bedtime is expressed — the editor says so
/// rather than rejecting it as invalid input.
struct QuietHoursEditor: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let windows: [QuietWindow]
    var calendar: Calendar = .current
    let onChange: ([QuietWindow]) -> Void

    @State private var draft: [QuietWindow] = []
    @State private var editing: QuietWindow?
    @State private var pendingRemoval: QuietWindow?

    var body: some View {
        List {
            Section {
                if draft.isEmpty {
                    Text(hop: HopCopy.timerSettings.quietEmpty)
                        .foregroundStyle(theme.color.textSecondary)
                } else {
                    ForEach(draft) { window in
                        Button {
                            editing = window
                        } label: {
                            QuietWindowRow(window: window, calendar: calendar)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        // Removing a quiet window makes HopPotty *more* likely to
                        // interrupt, so it is confirmed rather than swiped away
                        // silently. It is not a parent-gated action: nothing is
                        // destroyed and nothing about the child is lost.
                        if let index = offsets.first { pendingRemoval = draft[index] }
                    }
                }
            } footer: {
                Text(hop: HopCopy.timerSettings.quietFooter)
            }

            Section {
                Button {
                    editing = QuietWindow(
                        start: LocalTimeOfDay(hour: 12, minute: 30),
                        end: LocalTimeOfDay(hour: 14, minute: 30),
                        label: .nap
                    )
                } label: {
                    Label(hop: HopCopy.timerSettings.quietAdd, systemImage: "plus")
                }
            }
        }
        .navigationTitle(Text(hop: HopCopy.timerSettings.quietTitle))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if draft.isEmpty { draft = windows } }
        .sheet(item: $editing) { window in
            QuietWindowSheet(window: window, calendar: calendar) { updated in
                if let index = draft.firstIndex(where: { $0.id == updated.id }) {
                    draft[index] = updated
                } else {
                    draft.append(updated)
                }
                onChange(draft)
            }
        }
        .alert(
            pendingRemoval.map {
                HopCopy.timerSettings.quietRemove.localized(.text($0.label.parentTitle))
            } ?? "",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            )
        ) {
            Button(HopCopy.common.cancel.localized, role: .cancel) { pendingRemoval = nil }
            Button(HopCopy.common.delete.localized, role: .destructive) {
                if let pendingRemoval {
                    draft.removeAll { $0.id == pendingRemoval.id }
                    onChange(draft)
                }
                pendingRemoval = nil
            }
        }
    }
}

struct QuietWindowRow: View {
    @Environment(\.hopTheme) private var theme
    let window: QuietWindow
    var calendar: Calendar = .current

    var body: some View {
        HStack(spacing: theme.spacing.m) {
            Image(systemName: window.label.systemImage)
                .foregroundStyle(theme.color.brandPrimary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: window.label.parentTitle)
                    .font(theme.font(.parentBody))
                    .foregroundStyle(theme.color.textPrimary)
                Text(verbatim: ParentFormat.timeSpan(window.start, window.end, calendar: calendar))
                    .font(theme.font(.parentFootnote))
                    .foregroundStyle(theme.color.textSecondary)
                    .monospacedDigit()
            }
            Spacer()
            if !window.isEnabled {
                HopPill(HopCopy.parentHome.heroDisabled.localized, tint: theme.color.neutral, glyph: .pause)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Editing one window.
struct QuietWindowSheet: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var window: QuietWindow
    private let calendar: Calendar
    private let onSave: (QuietWindow) -> Void

    init(window: QuietWindow, calendar: Calendar = .current, onSave: @escaping (QuietWindow) -> Void) {
        _window = State(initialValue: window)
        self.calendar = calendar
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(HopCopy.timerSettings.quietLabelCustom.localized, selection: $window.label) {
                        ForEach(QuietWindowLabel.allCases) { label in
                            Text(verbatim: label.parentTitle).tag(label)
                        }
                    }
                }

                Section {
                    LocalTimePicker(
                        time: $window.start,
                        label: HopFeatureStrings.activeHoursStart,
                        calendar: calendar
                    )
                    LocalTimePicker(
                        time: $window.end,
                        label: HopFeatureStrings.activeHoursEnd,
                        calendar: calendar
                    )
                } footer: {
                    if window.wrapsMidnight {
                        // Stated rather than corrected: an overnight window is
                        // the normal way to express bedtime.
                        Text(hop: HopCopy.timerSettings.quietLabelBedtime)
                    }
                }

                Section {
                    Toggle(isOn: $window.isEnabled) {
                        Text(hop: HopCopy.timerSettings.enableButton)
                    }
                }
            }
            .navigationTitle(Text(verbatim: window.label.parentTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(HopCopy.common.cancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(HopCopy.common.save.localized) {
                        onSave(window)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#if DEBUG
#Preview("Quiet hours, populated") {
    NavigationStack {
        QuietHoursEditor(
            windows: QuietWindow.onboardingSuggestions,
            calendar: ParentEnvironment.previewCalendar
        ) { _ in }
    }
    .hopThemedRoot()
}

#Preview("Quiet hours, empty AX3") {
    NavigationStack {
        QuietHoursEditor(windows: [], calendar: ParentEnvironment.previewCalendar) { _ in }
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .hopThemedRoot()
}
#endif
