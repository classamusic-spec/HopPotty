import SwiftUI
import WidgetKit
import HopPottyCore
import HopPottyDesignTokens

// MARK: - The entry

/// One frame of the widget's timeline.
///
/// The snapshot is the same object at every entry; only `date` moves. That is
/// the whole trick behind the refresh budget: WidgetKit archives one view per
/// entry, and the view reads `date` to decide whether the appointment is still
/// ahead. Nothing has to be recomputed and nobody has to be woken.
struct NextPauseEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

// MARK: - The provider

/// Reads the App Group and plans the timeline. It computes nothing else.
///
/// `TimelineProvider` rather than `AppIntentTimelineProvider`: an intent-driven
/// provider buys per-widget configuration, and this widget has nothing to
/// configure. Offering a child picker would mean rendering a list of the family's
/// children in the system's widget-editing sheet, which is a place HopPotty has
/// no business putting a child's name. The widget follows the app's active child,
/// silently, and a caregiver changes it in the app.
struct NextPauseProvider: TimelineProvider {

    private let store: WidgetSnapshotStore

    init(store: WidgetSnapshotStore = .shared) {
        self.store = store
    }

    /// The greyed-out frame the system draws while it waits for a real one, and
    /// the frame shown in the widget gallery.
    ///
    /// Deliberately synthetic — `WidgetSnapshot.placeholder` — rather than the
    /// family's real state. The gallery is browsed with the phone unlocked in
    /// front of whoever is holding it, and it is not the place a caregiver chose
    /// to publish their afternoon.
    func placeholder(in context: Context) -> NextPauseEntry {
        NextPauseEntry(date: Date(), snapshot: .placeholder(at: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (NextPauseEntry) -> Void) {
        let now = Date()
        // `isPreview` is the gallery. Everywhere else this is the real widget
        // about to appear on a home screen, so it gets the real answer.
        let snapshot = context.isPreview ? WidgetSnapshot.placeholder(at: now) : store.loadForDisplay(at: now)
        completion(NextPauseEntry(date: now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextPauseEntry>) -> Void) {
        let now = Date()
        let snapshot = store.loadForDisplay(at: now)
        let entries = WidgetTimelinePlan.entryDates(for: snapshot, from: now)
            .map { NextPauseEntry(date: $0, snapshot: snapshot) }

        // `.after` rather than `.atEnd`: the two are usually the same instant,
        // but `.after` states the intent, and if the plan ever ends earlier than
        // its last entry the policy is the thing that has to be right.
        completion(
            Timeline(
                entries: entries,
                policy: .after(WidgetTimelinePlan.refreshDate(for: snapshot, from: now))
            )
        )
    }
}

// MARK: - The widget

struct NextPauseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshotStore.widgetKind, provider: NextPauseProvider()) { entry in
            NextPauseWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(verbatim: HopCopy.parentHome.heroTitle.value))
        .description(Text(verbatim: HopCopy.brand.tagline.value))
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
        // No `.widgetURL`. HopPotty declares no URL scheme on purpose
        // (`HopPotty/App/Info.plist`): a parental-controls app that can be driven
        // from a link is one a child can drive. Tapping the widget opens the app
        // at whatever screen it was on, which is the system default and is
        // exactly enough.
    }
}

// MARK: - The view

struct NextPauseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextPauseEntry

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .systemMedium: medium
        default: small
        }
    }

    // MARK: Home screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                // `size` is the width of Hop's head, and a frog's head is wider
                // than it is tall — so these numbers are larger than the square
                // face they replaced while covering about the same area.
                HopWidgetFace(mood: state.mood, size: 48)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            Text(verbatim: state.headline)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            countdown
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Color(HopPalette.hopGreenInk))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let subtitle = state.subtitle {
                Text(verbatim: subtitle)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { homeBackground }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: state.accessibilityLabel))
    }

    private var medium: some View {
        HStack(spacing: 16) {
            HopWidgetFace(mood: state.mood, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: state.headline)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                countdown
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(HopPalette.hopGreenInk))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let subtitle = state.subtitle {
                    Text(verbatim: subtitle)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) { homeBackground }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: state.accessibilityLabel))
    }

    /// A soft wash rather than a flat fill, so the widget sits on a busy home
    /// screen the way the app's cards sit on its own background.
    private var homeBackground: some View {
        LinearGradient(
            colors: [Color(HopPalette.hopGreenSoft), Color(HopPalette.cloud)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: Lock screen

    /// Accessory widgets are rendered into a vibrant, effectively single-colour
    /// layer, so everything here is shape and text — no palette, no gradient.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                HopWidgetFace(mood: state.mood, size: 26, isMonochrome: true)
                countdown
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .widgetAccentable()
        .containerBackground(for: .widget) { Color.clear }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: state.accessibilityLabel))
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            HopWidgetFace(mood: state.mood, size: 30, isMonochrome: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: state.headline)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                countdown
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
        }
        .widgetAccentable()
        .containerBackground(for: .widget) { Color.clear }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: state.accessibilityLabel))
    }

    /// One line, no glyph of our own: the system already puts the app's icon
    /// beside it, and a second frog would be a frog too many.
    ///
    /// Built by concatenating `Text` rather than by stacking views. The inline
    /// accessory family renders a single line of text with an optional image and
    /// flattens anything else, so `Text(…) + Text(date, style:)` is the only
    /// shape that reliably keeps a live countdown up there.
    private var inline: some View {
        inlineText
            .containerBackground(for: .widget) { Color.clear }
    }

    private var inlineText: Text {
        switch state.kind {
        case .counting(let target):
            // `.relative` rather than `.timer` here: one line of status text
            // beside the app icon reads better as "12 minutes" than as a running
            // clock, and inline widgets are truncated hard.
            Text(verbatim: state.headline) + Text(verbatim: " ") + Text(target, style: .relative)
        case .word(let word):
            Text(verbatim: word)
        }
    }

    // MARK: The countdown itself
    //
    // `Text(_:style:)` is rendered by the system from a date. It keeps ticking
    // with no timeline entry, no reload, and nothing charged against the refresh
    // budget — which is why the plan in `WidgetTimelinePlan` can afford to be as
    // sparse as it is. Entries exist for the things a date cannot animate: which
    // face Hop is wearing, and the moment the words have to change.

    /// The countdown, at whatever size the caller's font says.
    ///
    /// One property for all four stacked layouts: they differ in font and in
    /// nothing else, and two copies of this would be two places for the styles
    /// to drift apart. The inline family is the exception and has `inlineText`,
    /// because it cannot contain a stack at all.
    private var countdown: Text {
        switch state.kind {
        case .counting(let target): Text(target, style: .timer)
        case .word(let word): Text(verbatim: word)
        }
    }

    private var state: NextPauseDisplayState {
        NextPauseDisplayState(snapshot: entry.snapshot, now: entry.date)
    }
}

// MARK: - What the widget says

/// The words and the shape of one frame, resolved from a snapshot and the
/// entry's own instant.
///
/// A separate value rather than a pile of computed properties on the view so the
/// same decision serves five layouts. Every string comes from `HopCopy`, which
/// `HopPottyCore` brings into the widget process — the widget invents no copy of
/// its own beyond the two separators noted below.
struct NextPauseDisplayState {

    enum Kind {
        /// Hand this date to `Text(_:style:)` and let the system tick it.
        case counting(Date)
        /// Nothing to count. Say this instead.
        case word(String)
    }

    let mood: HopWidgetMood
    let headline: String
    let kind: Kind
    let subtitle: String?
    let accessibilityLabel: String

    init(snapshot: WidgetSnapshot, now: Date) {
        self.mood = snapshot.mood

        // Ordered by what a caregiver most needs to know, which is also the
        // order in which each fact overrides the one below it.

        if let endsAt = snapshot.pauseEndsAt, now < endsAt {
            // A pause is running right now. The child is looking at the shield.
            headline = HopCopy.shield.title.value
            kind = .counting(endsAt)
            subtitle = HopCopy.shield.returning.value
            accessibilityLabel = HopCopy.shield.title.value
            return
        }

        let reminder = snapshot.quickReminderAt.flatMap { $0 > now ? $0 : nil }
        let pause = snapshot.nextPauseAt.flatMap { $0 > now ? $0 : nil }

        // "The reminder is first" means either there is no pause to compare it
        // with, or it lands before the one there is.
        if let reminder, pause.map({ reminder < $0 }) ?? true {
            headline = HopCopy.quickReminder.title.value
            kind = .counting(reminder)
            // When both are coming and the reminder is first, the pause becomes
            // the second sentence rather than a competing headline.
            subtitle = pause == nil ? nil : HopCopy.parentHome.heroTitle.value
            accessibilityLabel = HopCopy.quickReminder.title.value
        } else if let pause {
            headline = HopCopy.parentHome.heroTitle.value
            kind = .counting(pause)
            subtitle = nil
            accessibilityLabel = HopCopy.parentHome.heroTitle.value
        } else {
            // Nothing ahead. Two different silences, and they mean different
            // things to a caregiver: the schedule is switched off, or it is on
            // and simply has nothing to project today.
            //
            // "Nothing waiting right now." is true whatever the second reason
            // turns out to be — a skipped pause, a closed active window, a quiet
            // hour — and the snapshot deliberately does not carry which, because
            // that is a fact about a family's day and this is a lock screen.
            let word = snapshot.isScheduleEnabled
                ? HopCopy.parentHome.heroNothingScheduled.value
                : HopCopy.parentHome.heroDisabled.value
            headline = HopCopy.parentHome.heroTitle.value
            kind = .word(word)
            subtitle = nil
            accessibilityLabel = word
        }
    }
}

#if DEBUG
// The plain view preview rather than `#Preview(as:widget:timeline:)`. The widget
// form renders the real timeline, which is worth having — but it is also the one
// preview API in this file that nothing in this repository can compile-check, and
// a preview that does not build fails the whole target. Add it back the first
// time someone opens this project in Xcode and can watch it succeed.
#Preview("Next pause — home screen") {
    VStack(spacing: 16) {
        NextPauseWidgetView(entry: NextPauseEntry(date: .now, snapshot: .placeholder(at: .now)))
            .frame(width: 158, height: 158)
        NextPauseWidgetView(entry: NextPauseEntry(date: .now, snapshot: .empty(at: .now)))
            .frame(width: 158, height: 158)
    }
    .padding()
}
#endif
