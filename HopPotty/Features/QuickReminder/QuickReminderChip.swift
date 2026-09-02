import SwiftUI
import HopPottyCore

// MARK: - Localisation seam

extension QuickReminderText {
    /// Resolves a Quick Reminder string through the app's string table, falling
    /// back to the English authored in `HopCopy`.
    ///
    /// `QuickReminderText` decides *which* entry a sentence uses and in what
    /// order its slots go; this decides what language it comes out in. Passing
    /// it at every call site is what keeps the two decisions in one place each
    /// — see `HopText.swift` for why `NSLocalizedString(_:value:)` rather than
    /// `LocalizedStringResource`.
    static let localised: Resolver = { entry, values in entry.localized(filling: values) }
}

// MARK: - The chip

/// The compact pill that says a reminder is waiting.
///
/// "Reminder · 3:40 PM", with an X. It is deliberately the smallest possible
/// piece of dashboard furniture: a Quick Reminder is a timer a caregiver set
/// thirty seconds ago and will act on within the hour, and it does not deserve
/// a card, a countdown ring or a section of its own.
///
/// It shows a **wall-clock time, not a countdown**. A live countdown would tick
/// while the caregiver is reading something else, would need a timer to redraw,
/// and would turn a calm "3:40" into something that looks like it is running
/// out. The remaining time is still there for VoiceOver, where it is the more
/// useful of the two.
struct QuickReminderChip: View {
    @Environment(\.hopTheme) private var theme

    let reminder: QuickReminder
    /// The instant the surrounding screen is drawing for. Passed in rather than
    /// read from a clock here, so a preview pinned to a fixed date renders the
    /// same pill every time.
    let now: Date
    var calendar: Calendar = .current
    let onCancel: () -> Void

    private var clockText: String {
        ParentFormat.clock(reminder.fireAt, timeZone: calendar.timeZone)
    }

    private var remainingText: String {
        ParentFormat.shortDuration(QuickReminderPlanner.remaining(reminder, at: now))
    }

    private var tint: Color { theme.color.brandAction }

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            HopGlyphView(.timer, size: 12)
                .accessibilityHidden(true)

            Text(verbatim: QuickReminderText.chip(clockText: clockText, resolve: QuickReminderText.localised))
                .hopTextStyle(.parentFootnote)
                // One line, but it may still wrap at accessibility sizes rather
                // than truncate: a clipped time is worse than a taller pill.
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(HopBareButtonStyle(minimumTarget: theme.hitTarget.parent, tint: tint))
            // The X alone says nothing to VoiceOver, so the label says what
            // will be cancelled and when.
            .accessibilityLabel(
                Text(verbatim: QuickReminderText.cancelLabel(clockText: clockText, resolve: QuickReminderText.localised))
            )
        }
        .foregroundStyle(tint)
        .padding(.leading, theme.spacing.s)
        .padding(.trailing, theme.spacing.xs)
        .padding(.vertical, theme.spacing.xs)
        .background { Capsule().fill(HopColors.wash(tint, isDark: theme.isDark)) }
        .overlay { Capsule().strokeBorder(tint.opacity(theme.isHighContrast ? 0.8 : 0.18), lineWidth: 1) }
        // The pill and its cancel button stay two elements: merging them would
        // leave no way to cancel with VoiceOver.
        .accessibilityElement(children: .contain)
        .accessibilityValue(
            Text(verbatim: QuickReminderText.remaining(durationText: remainingText, resolve: QuickReminderText.localised))
        )
    }
}

// MARK: - The mount

/// Everything the dashboard needs in one view: the chip when a reminder is
/// waiting, the way to set one when none is, and the sheet behind both.
///
/// A container rather than a bare chip, because "is there one waiting?" is a
/// question with three answers — one waiting, none waiting, notifications off
/// — and answering it at the call site would put that logic in whichever screen
/// mounted it first.
///
/// It draws nothing at all when there is nothing waiting *and* `showsSetButton`
/// is false, so it can be dropped into a layout that has its own entry point.
struct QuickReminderBar: View {
    @Environment(\.hopTheme) private var theme
    @Environment(\.quickReminders) private var service
    @Environment(ParentEnvironment.self) private var parent

    /// The child the reminder is about, or `nil` for "anyone" — which is the
    /// commoner case, and the default.
    var childID: UUID?
    /// Whether to offer "Set reminder" when nothing is waiting.
    var showsSetButton = true

    @State private var isSheetPresented = false

    private var soonest: QuickReminder? {
        service?.state.soonest(at: parent.clock.now)
    }

    var body: some View {
        Group {
            if let service {
                if let reminder = soonest {
                    QuickReminderChip(
                        reminder: reminder,
                        now: parent.clock.now,
                        calendar: parent.clock.calendar
                    ) {
                        Task { await service.cancel(reminder.id) }
                    }
                    // Tapping the pill itself re-opens the sheet, where setting
                    // another replaces this one.
                    .onTapGesture { isSheetPresented = true }
                } else if showsSetButton {
                    Button {
                        isSheetPresented = true
                    } label: {
                        Label {
                            Text(hop: HopCopy.quickReminder.setButton)
                                .hopTextStyle(.parentFootnote)
                        } icon: {
                            HopGlyphView(.timer, size: 12)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.color.brandAction)
                    .padding(.horizontal, theme.spacing.s)
                    .padding(.vertical, theme.spacing.xs)
                    .frame(minHeight: theme.hitTarget.parent)
                }
            }
        }
        .sheet(isPresented: $isSheetPresented) {
            if let service {
                QuickReminderSheet(service: service, childID: childID)
            }
        }
        .task(id: parent.activeChildID) { await service?.refresh() }
    }
}

// MARK: - Environment

/// The Quick Reminder service, handed down the tree.
///
/// An environment key rather than a property on `ParentEnvironment` because a
/// Quick Reminder is not part of the caregiver's data graph: it touches no
/// repository the dashboard reads, no schedule, and no child record. Screens
/// that never mention reminders should not gain a reference to one, and
/// `nil` is a legitimate value — a host that has not wired it draws nothing
/// rather than crashing.
/// Written as an explicit `EnvironmentKey` rather than with SwiftUI's `@Entry`
/// macro, which arrived in the iOS 18 SDK — HopPotty targets iOS 17
/// (`Docs/ADR/0002-deployment-target.md`). The same choice, for the same
/// reason, as `ScreenTimeEnvironmentKey`.
private struct QuickReminderServiceKey: EnvironmentKey {
    /// `nonisolated(unsafe)` because the value's *type* is a main-actor
    /// existential and the compiler cannot know the value is `nil`. Nothing is
    /// shared: this default is a constant `nil`, and every non-nil value is
    /// installed and read on the main actor by SwiftUI.
    nonisolated(unsafe) static let defaultValue: (any QuickReminderProviding)? = nil
}

extension EnvironmentValues {
    var quickReminders: (any QuickReminderProviding)? {
        get { self[QuickReminderServiceKey.self] }
        set { self[QuickReminderServiceKey.self] = newValue }
    }
}

#if DEBUG
/// Built here rather than pulled from `HopPottyFixtures`, which the app target
/// does not link.
private let previewChipNow = Date()
private let previewChipReminder = QuickReminder(
    childID: nil,
    fireAt: previewChipNow.addingTimeInterval(20 * 60),
    createdAt: previewChipNow,
    label: .afterADrink,
    state: .pending
)

// `@MainActor` because a file-scope `private func` is nonisolated by default,
// while `ParentEnvironment`, the design-system modifiers and the views
// themselves are all main-actor isolated. Every call site is a `#Preview` body,
// which is main-actor anyway, so the annotation states what was already true.
//
// Seven file-scope preview helpers across the app have this shape. One
// (`sheetPreview` in QuickReminderSheet) was already annotated. Of the six that
// were not, the compiler named four -- one in run 60, three in run 66 -- and
// stopped; `paywallPreview` and `homePreview` were found by looking for the
// shape rather than waiting to be told.
@MainActor
private func chipPreview() -> some View {
    QuickReminderChip(reminder: previewChipReminder, now: previewChipNow, calendar: .current) {}
        .padding()
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Chip") { chipPreview() }

#Preview("Chip · dark") { chipPreview().preferredColorScheme(.dark) }

#Preview("Chip · AX3") {
    chipPreview().environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Bar · nothing waiting") {
    QuickReminderBar()
        .padding()
        .environment(ParentEnvironment.preview())
        .environment(\.quickReminders, MockQuickReminderService())
        .hopBackground()
        .hopThemedRoot()
}
#endif
