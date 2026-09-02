import Foundation
import Testing
@testable import HopPottyCore

/// The words a Quick Reminder says.
///
/// The catalog-wide safety suites already scan these strings for shame,
/// medical and prescriptive language along with every other entry. What is
/// checked here is what only this feature can get wrong: a reminder is a
/// caregiver's own tool, so nothing it says may be about the child, and the
/// refusals must each have a sentence — a limit with no wording ships as a
/// button that quietly does nothing.
@Suite("Quick Reminder: copy")
struct QuickReminderCopyTests {

    // MARK: - Audience

    /// The child never sees a Quick Reminder and is never its subject.
    @Test("Every Quick Reminder string is written for the caregiver")
    func everyStringIsParentFacing() {
        let entries = HopCopy.entries(on: .quickReminder)
        #expect(!entries.isEmpty, "the quickReminder surface reflected to nothing")
        for entry in entries {
            #expect(entry.audience == .parent, "\(entry.key) is addressed to the child")
        }
    }

    /// A Quick Reminder has no outcome, so no string may describe one. This
    /// catches the sentence nobody means to write — "Maya has not gone yet" —
    /// before it exists, by refusing the nickname slot the sentence would need.
    @Test("No Quick Reminder string takes a nickname")
    func noStringNamesTheChild() {
        for entry in HopCopy.entries(on: .quickReminder) {
            #expect(
                !entry.placeholders.contains { $0.name == "nickname" },
                "\(entry.key) interpolates a child's name into a caregiver's own timer"
            )
        }
        for pair in HopCopy.allNameVariants {
            #expect(
                !pair.baseKey.hasPrefix(HopCopySurface.quickReminder.keyPrefix),
                "\(pair.baseKey) is a nickname pair on a surface the child never sees"
            )
        }
    }

    @Test("The notification a Quick Reminder sends is addressed to the caregiver")
    func theNotificationIsParentFacing() {
        #expect(HopCopy.notification.quickReminderTitle.audience == .parent)
        #expect(HopCopy.notification.quickReminderBody.audience == .parent)
        #expect(HopCopy.notification.quickReminderTitle.value == "Hop says: potty time?")
        #expect(HopCopy.notification.quickReminderBody.value == "A gentle nudge you set earlier.")
    }

    // MARK: - Coverage

    @Test("Every preset chip has an authored sentence")
    func everyPresetHasAChip() {
        for duration in QuickReminderDuration.presets {
            let entry = QuickReminderText.presetEntry(duration)
            #expect(entry != nil, "the \(duration.minutes)-minute chip has no copy")
            #expect(entry?.placeholders.isEmpty == true, "a preset chip should not need a slot filled")
        }
        // A custom duration has no authored sentence and falls back to the
        // format, which is why the format exists.
        #expect(QuickReminderText.presetEntry(.custom(minutes: 25)) == nil)
        #expect(QuickReminderText.presetLabel(.custom(minutes: 25), durationText: "25 minutes") == "In 25 minutes")
        #expect(QuickReminderText.presetLabel(.minutes60) == "In 1 hour")
    }

    /// A refusal with no wording is a disabled button with no explanation.
    @Test("Every refusal has a sentence, and no two share one")
    func everyRejectionHasItsOwnSentence() {
        let rejections: [QuickReminderRejection] = [.inThePast, .tooSoon, .beyondHorizon, .tooManyPending]
        var seen: Set<String> = []
        for rejection in rejections {
            let sentence = QuickReminderText.rejection(rejection)
            #expect(!sentence.isEmpty)
            #expect(!sentence.contains("%"), "\(rejection) left a format token in \"\(sentence)\"")
            #expect(seen.insert(sentence).inserted, "\(rejection) reuses another refusal's sentence")
        }
    }

    // MARK: - Rendering

    @Test("The chip and its confirmation read as specified")
    func rendering() {
        #expect(QuickReminderText.chip(clockText: "3:40 PM") == "Reminder · 3:40 PM")
        #expect(QuickReminderText.confirmation(clockText: "3:40 PM") == "Reminder set for 3:40 PM")
        #expect(QuickReminderText.cancelLabel(clockText: "3:40 PM") == "Cancel the reminder set for 3:40 PM")
        #expect(QuickReminderText.remaining(durationText: "12 minutes") == "12 minutes from now")
        #expect(QuickReminderText.pauseNearby(clockText: "3:35 PM") == "A Potty Pause is already coming at 3:35 PM.")
        #expect(
            QuickReminderText.replacesExisting(clockText: "2:15 PM")
                == "This takes the place of your reminder at 2:15 PM."
        )
    }

    /// Every slot is filled. A stray `%1$@` on a chip is the defect this catches.
    @Test("Nothing rendered leaves a format token behind")
    func nothingRenderedLeavesAToken() {
        let rendered = [
            QuickReminderText.chip(clockText: "3:40 PM"),
            QuickReminderText.confirmation(clockText: "3:40 PM"),
            QuickReminderText.cancelLabel(clockText: "3:40 PM"),
            QuickReminderText.remaining(durationText: "12 minutes"),
            QuickReminderText.replacesExisting(clockText: "2:15 PM"),
            QuickReminderText.pauseNearby(clockText: "3:35 PM"),
            QuickReminderText.presetLabel(.minutes15),
            QuickReminderText.presetLabel(.custom(minutes: 25), durationText: "25 minutes"),
        ]
        for text in rendered {
            #expect(!text.contains("%"), "\"\(text)\" still carries a format token")
        }
    }

    /// The resolver is the localisation seam: the app hands in a closure that
    /// looks the key up first. This proves the sentence is assembled from the
    /// resolved string rather than from the catalog's English.
    @Test("A custom resolver is what gets rendered")
    func resolverIsHonoured() {
        let shouty: QuickReminderText.Resolver = { entry, values in
            HopCopyFormat.filling(entry.value.uppercased(), with: values.mapValues(\.stringValue))
        }
        #expect(QuickReminderText.chip(clockText: "3:40 PM", resolve: shouty) == "REMINDER · 3:40 PM")
        #expect(
            QuickReminderText.rejection(.beyondHorizon, resolve: shouty)
                == "QUICK REMINDERS REACH UP TO 24 HOURS AHEAD."
        )
    }
}
