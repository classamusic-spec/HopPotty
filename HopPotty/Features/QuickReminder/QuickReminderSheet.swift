import SwiftUI
import HopPottyCore

/// Setting a one-off reminder.
///
/// Six chips, a time picker behind a seventh, and one big button. That is the
/// whole screen, and the shape is the point: the caregiver reaching for this is
/// standing in a kitchen holding a cup, and the interaction that fits is one
/// tap and one more.
///
/// What the sheet deliberately does **not** offer:
///
/// - **A repeat.** A recurring reminder is the Potty Pause schedule, which has
///   its own screen, its own quiet hours and its own active window. Two ways to
///   express the same thing is how a family ends up interrupted twice.
/// - **A child picker, front and centre.** The reminder defaults to "anyone",
///   because a caregiver with two children in the bath sets one timer for the
///   bathroom. Naming a child is scoping, not decoration, and the sheet only
///   does it when the caller asked for it.
/// - **A reason, required.** `QuickReminderLabel` exists and nothing here makes
///   anyone pick one. A caregiver does not owe the app a reason for a timer.
struct QuickReminderSheet: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(ParentEnvironment.self) private var parent

    let service: any QuickReminderProviding
    /// The child this is about, or `nil` for "anyone".
    var childID: UUID?
    /// The next projected Potty Pause, when the caller has one. Used only for
    /// the advisory note; it never blocks anything and never moves anything.
    var projection: PauseProjection?

    /// What the caregiver has chosen. A duration, or the picker.
    private enum Choice: Hashable {
        case after(QuickReminderDuration)
        case pickATime
    }

    @State private var choice: Choice = .after(.minutes20)
    @State private var pickedTime = Date()
    @State private var refusal: QuickReminderRejection?
    @State private var notificationsUnavailable = false
    @State private var didFail = false
    @State private var isSaving = false

    // MARK: Derived

    private var now: Date { parent.clock.now }
    private var calendar: Calendar { parent.clock.calendar }

    /// The request the button would send. One place, so the picker's bounds,
    /// the button's enabled state and what is actually scheduled cannot drift.
    private var request: QuickReminderRequest {
        switch choice {
        case .after(let duration): .after(duration, childID: childID)
        case .pickATime: .at(pickedTime, childID: childID)
        }
    }

    private var fireAt: Date { request.fireDate(setAt: now) }

    /// The same rule the planner will apply, run while the wheel is still
    /// turning, so the button is never offered for something that would be
    /// refused.
    private var liveRefusal: QuickReminderRejection? {
        QuickReminderPlanner.validate(request, at: now)
    }

    /// The pending reminder this one would take the place of.
    private var wouldReplace: QuickReminder? {
        guard case .replaces(let existing) = QuickReminderPlanner.admit(
            childID: childID,
            existing: service.state.reminders,
            at: now
        ) else { return nil }
        return existing
    }

    private var pauseNearby: QuickReminderCollision? {
        QuickReminderPlanner.collision(reminderAt: fireAt, projection: projection)
    }

    private func clockText(_ date: Date) -> String {
        ParentFormat.clock(date, timeZone: calendar.timeZone)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    Text(hop: HopCopy.quickReminder.subtitle)
                        .hopTextStyle(.parentCallout)
                        .foregroundStyle(theme.color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    chips

                    if case .pickATime = choice { timePicker }

                    notes
                }
                .hopPageMargins()
                .padding(.vertical, theme.spacing.l)
            }
            .navigationTitle(Text(hop: HopCopy.quickReminder.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(HopCopy.common.cancel.localized) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { primaryButton }
            .hopBackground(.primary)
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            // The picker opens at a time that is already valid, so the first
            // thing a caregiver sees is never a refusal.
            pickedTime = now.addingTimeInterval(QuickReminderDuration.minutes20.duration)
        }
    }

    // MARK: Chips

    private var chips: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 132), spacing: theme.spacing.s)],
            spacing: theme.spacing.s
        ) {
            ForEach(QuickReminderDuration.presets, id: \.self) { duration in
                chip(
                    title: QuickReminderText.presetLabel(duration, resolve: QuickReminderText.localised),
                    isSelected: choice == .after(duration)
                ) {
                    choice = .after(duration)
                    clearRefusals()
                }
            }
            chip(
                title: HopCopy.quickReminder.pickATime.localized,
                isSelected: choice == .pickATime
            ) {
                choice = .pickATime
                clearRefusals()
            }
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .hopTextStyle(.parentHeadline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .frame(minHeight: theme.hitTarget.parent)
                .padding(.horizontal, theme.spacing.s)
                .padding(.vertical, theme.spacing.s)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? theme.color.textOnBrand : theme.color.textPrimary)
        .background {
            RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                .fill(isSelected ? theme.color.brandAction : theme.color.surface)
        }
        .overlay {
            // Selection is a fill *and* a heavier border, never colour alone —
            // the same reason every status token in HopPotty carries a glyph.
            RoundedRectangle(cornerRadius: theme.radius.l, style: .continuous)
                .strokeBorder(
                    isSelected ? theme.color.brandAction : theme.color.divider,
                    lineWidth: isSelected ? 2 : (theme.isHighContrast ? 1.5 : 0.75)
                )
        }
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Time picker

    private var timePicker: some View {
        HopCard {
            DatePicker(
                HopCopy.quickReminder.timeLabel.localized,
                selection: $pickedTime,
                // The bounds are the planner's own limits, so the wheel cannot
                // reach a time the button would then refuse.
                in: now.addingTimeInterval(QuickReminderPlanner.minimumLead)
                    ... now.addingTimeInterval(QuickReminderPlanner.maximumHorizon),
                displayedComponents: [.date, .hourAndMinute]
            )
            .onChange(of: pickedTime) { _, _ in clearRefusals() }
        }
    }

    // MARK: Notes

    @ViewBuilder
    private var notes: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            if notificationsUnavailable {
                note(HopCopy.quickReminder.permissionNeeded.localized, tint: theme.color.warning)
            }

            if didFail {
                // The catalog's general "that did not finish" sentence. A
                // reminder does not get its own wording for a failure that is
                // not about reminders — see `HopCopy.errors`.
                note(HopCopy.errors.genericBody.localized, tint: theme.color.warning)
            }

            if let refusal = refusal ?? liveRefusal {
                note(
                    QuickReminderText.rejection(refusal, resolve: QuickReminderText.localised),
                    tint: theme.color.warning
                )
            }

            if let existing = wouldReplace {
                note(
                    QuickReminderText.replacesExisting(
                        clockText: clockText(existing.fireAt),
                        resolve: QuickReminderText.localised
                    ),
                    tint: theme.color.textSecondary
                )
            }

            if let pauseNearby {
                note(
                    QuickReminderText.pauseNearby(
                        clockText: clockText(pauseNearby.pauseAt),
                        resolve: QuickReminderText.localised
                    ),
                    tint: theme.color.textSecondary
                )
            }
        }
    }

    private func note(_ text: String, tint: Color) -> some View {
        Text(verbatim: text)
            .hopTextStyle(.parentCallout)
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: The one button

    private var primaryButton: some View {
        VStack(spacing: theme.spacing.xs) {
            HopPrimaryButton(
                HopCopy.quickReminder.setButton.localized,
                icon: "bell.badge"
            ) {
                Task { await set() }
            }
            .disabled(isSaving || liveRefusal != nil)

            // The confirmation is shown before the tap, not after: a caregiver
            // deciding between 3:40 and 4:00 wants to read the time, and a
            // sheet that dismisses to a toast has already taken it away.
            Text(
                verbatim: QuickReminderText.confirmation(
                    clockText: clockText(fireAt),
                    resolve: QuickReminderText.localised
                )
            )
            .hopTextStyle(.parentCaption)
            .foregroundStyle(theme.color.textSecondary)
            .opacity(liveRefusal == nil ? 1 : 0)
            .accessibilityHidden(liveRefusal != nil)

            // Offered only when there is something to take back. Opening this
            // sheet from the chip is how a caregiver changes their mind, and
            // "cancel it" and "move it" are different intentions — making the
            // second the only way to reach the first would mean setting a
            // reminder in order to be rid of one.
            if let existing = wouldReplace {
                HopSecondaryButton(HopCopy.quickReminder.cancelButton.localized) {
                    Task {
                        isSaving = true
                        await service.cancel(existing.id)
                        isSaving = false
                        dismiss()
                    }
                }
                .disabled(isSaving)
            }
        }
        .hopPageMargins()
        .padding(.vertical, theme.spacing.m)
        .background(.regularMaterial)
    }

    // MARK: Actions

    private func set() async {
        isSaving = true
        defer { isSaving = false }
        switch await service.schedule(request) {
        case .scheduled:
            dismiss()
        case .refused(let rejection):
            refusal = rejection
        case .notificationsUnavailable:
            notificationsUnavailable = true
        case .failed:
            didFail = true
        }
    }

    private func clearRefusals() {
        refusal = nil
        notificationsUnavailable = false
        didFail = false
    }
}

#if DEBUG
/// A reminder waiting twenty minutes out. Built here rather than pulled from
/// `HopPottyFixtures`, which the app target does not link.
private let previewWaitingReminder = QuickReminder(
    childID: nil,
    fireAt: Date().addingTimeInterval(20 * 60),
    createdAt: Date(),
    label: .afterADrink,
    state: .pending
)

@MainActor
// `@MainActor` because a file-scope `private func` is nonisolated by default,
// while `ParentEnvironment`, the design-system modifiers and the views
// themselves are all main-actor isolated. Every call site is a `#Preview` body,
// which is main-actor anyway, so the annotation states what was already true.
//
// Six file-scope preview helpers across the app have this exact shape. The
// compiler named four of them (one in run 60, three in run 66) and stopped;
// the other two were found by looking for the shape rather than waiting to be
// told. All six are annotated.
@MainActor
private func sheetPreview(_ service: MockQuickReminderService) -> some View {
    QuickReminderSheet(service: service)
        .environment(ParentEnvironment.preview())
        .hopThemedRoot()
}

#Preview("Set a reminder") { sheetPreview(MockQuickReminderService()) }

#Preview("Replacing one already waiting") {
    sheetPreview(MockQuickReminderService(reminders: [previewWaitingReminder]))
}

#Preview("Notifications off") {
    sheetPreview(MockQuickReminderService(canDeliver: false))
}

#Preview("AX3, dark") {
    sheetPreview(MockQuickReminderService())
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}
#endif
