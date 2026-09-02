import SwiftUI
import HopPottyCore
import HopPottyDesignTokens

public extension PottyEventSource {
    /// Who wrote the entry down. Never a judgement about the entry.
    var displayName: String {
        switch self {
        case .childRoutine: HopStrings.sourceChildRoutine
        case .parentManual: HopStrings.sourceParentManual
        case .pauseCompletion: HopStrings.sourcePauseCompletion
        case .restored: HopStrings.sourceRestored
        }
    }
}

/// One entry in the day's timeline.
///
/// Reads as a single line to VoiceOver — time, kind, who recorded it — because
/// that is one fact. The mark is decorative and hidden.
///
/// ## Health, not a journal
///
/// This row used to be a vertical rail: a 32pt tinted disc with the event glyph
/// inside it, a 2pt connector drawn down to the next row, and the source of the
/// entry spelled out under every single line. Four of those is four coloured
/// circles and three lengths of pipe on a screen that already has a painted pond
/// above it. Apple Health draws an entry as a time, a small tinted symbol and a
/// word, separated by a hairline, and that is what this is now.
///
/// Two things went with the rail:
///
/// - **The disc.** The tint moved onto the glyph itself. Meaning still rides on
///   the silhouette as well as the colour (`Docs/CONTRACTS.md` §6), so nothing
///   is carried by hue alone; there is simply one fewer object per row.
/// - **The source, on the ordinary rows.** "Logged by Hop's routine" under every
///   entry is the default case announcing itself once per line. It is shown when
///   it is actually informative — a grown-up added the entry by hand, or it came
///   back from a backup — and VoiceOver reads it on every row regardless, so
///   nothing is lost to a screen-reader user.
///
/// An accident is drawn exactly like every other entry: `eventAccident` is the
/// palette's neutral grey, and there is no warning mark, no red and no emphasis
/// anywhere in this row (§7, `Docs/CONTRACTS.md` §4.3).
///
/// ## Arrival
///
/// `arrivalIndex:` gives a day's worth of entries a staggered arrival: each row
/// fades and slides a few points toward its leading edge, so a timeline reads as
/// being written down the page rather than as a block appearing. Off by default,
/// and off entirely under Reduce Motion, where the rows simply fade in together.
public struct HopTimelineRow: View {
    @Environment(\.hopTheme) private var theme
    @State private var hasArrived = false

    private let event: PottyEvent
    private let isLast: Bool
    private let arrivalIndex: Int?

    public init(event: PottyEvent, isLast: Bool, arrivalIndex: Int? = nil) {
        self.event = event
        self.isLast = isLast
        self.arrivalIndex = arrivalIndex
    }

    /// True only between the first render and the arrival landing.
    private var isArriving: Bool { arrivalIndex != nil && !hasArrived }

    private var arrivalAnimation: Animation {
        HopAnimationToken.parentTransition.animation(
            reduceMotion: theme.reduceMotion,
            index: arrivalIndex ?? 0
        )
    }

    private var tint: Color { theme.color.accent(for: event.kind) }

    private var timeText: String {
        event.timestamp.formatted(date: .omitted, time: .shortened)
    }

    /// The provenance worth printing. `childRoutine` and `pauseCompletion` are
    /// the two ordinary paths — an entry with no caption came from the routine,
    /// which is what a caregiver already assumes.
    private var printedSource: String? {
        switch event.source {
        case .parentManual, .restored: event.source.displayName
        case .childRoutine, .pauseCompletion: nil
        }
    }

    public var body: some View {
        HStack(alignment: .center, spacing: theme.spacing.m) {
            Text(timeText)
                .hopTextStyle(.parentCallout)
                // Monospaced so a column of times lines up on the colon instead
                // of ragging left as the hour changes width.
                .hopNumericText()
                .foregroundStyle(theme.color.textSecondary)
                .frame(width: 76, alignment: .leading)

            HopGlyphView(HopGlyph(event.kind), size: 17)
                .foregroundStyle(tint)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.kind.displayName)
                    .hopTextStyle(.parentBody)
                    .foregroundStyle(theme.color.textPrimary)

                if let printedSource {
                    Text(printedSource)
                        .hopTextStyle(.parentCaption)
                        .foregroundStyle(theme.color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let note = event.note, !note.isEmpty {
                    Text(note)
                        .hopTextStyle(.parentCaption)
                        .foregroundStyle(theme.color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, theme.spacing.s)
        .frame(minHeight: theme.hitTarget.parent)
        // The hairline is inset to the time column the way a system list insets
        // to its label, and the last row has none — the card's own edge is there.
        .overlay(alignment: .bottom) {
            if !isLast { HopRowDivider(leadingInset: 0) }
        }
        .opacity(isArriving ? 0 : 1)
        .offset(x: isArriving && !theme.reduceMotion ? -10 : 0)
        .animation(arrivalAnimation, value: hasArrived)
        .onAppear { hasArrived = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(timeText), \(event.kind.displayName)")
        .accessibilityValue(accessibilityValue)
    }

    /// VoiceOver always hears the source, whether or not the row prints it.
    private var accessibilityValue: String {
        guard let note = event.note, !note.isEmpty else { return event.source.displayName }
        return "\(event.source.displayName). \(HopStrings.noteLabel): \(note)"
    }
}

#if DEBUG
/// Deterministic timeline fixtures. Fixed IDs and a fixed reference instant so a
/// preview renders identically on every run.
enum HopTimelinePreviewData {
    static let childID = UUID(uuidString: "5A11D000-0000-4000-8000-000000000001")!
    /// 2026-03-10 09:00:00 UTC, matching `HopFixtures.referenceDate`.
    static let reference = Date(timeIntervalSince1970: 1_773_133_200)

    static func event(
        _ index: Int,
        kind: PottyEventKind,
        source: PottyEventSource,
        minutesAgo: Int,
        note: String? = nil
    ) -> PottyEvent {
        PottyEvent(
            id: UUID(uuidString: String(format: "E0E0E0E0-0000-4000-8000-%012d", index))!,
            childID: childID,
            timestamp: reference.addingTimeInterval(TimeInterval(-minutesAgo * 60)),
            kind: kind,
            source: source,
            note: note,
            createdAt: reference,
            modifiedAt: reference
        )
    }

    static let day: [PottyEvent] = [
        event(1, kind: .tried, source: .childRoutine, minutesAgo: 20),
        event(2, kind: .pee, source: .childRoutine, minutesAgo: 95),
        event(3, kind: .accident, source: .parentManual, minutesAgo: 180, note: "On the way back from the park."),
        event(4, kind: .poop, source: .pauseCompletion, minutesAgo: 260),
    ]
}

private struct HopTimelinePreview: View {
    /// Staggered when set, which is what a real day's timeline passes.
    var staggers = false

    var body: some View {
        ScrollView {
            HopCard {
                VStack(spacing: 0) {
                    ForEach(Array(HopTimelinePreviewData.day.enumerated()), id: \.element.id) { index, event in
                        HopTimelineRow(
                            event: event,
                            isLast: index == HopTimelinePreviewData.day.count - 1,
                            arrivalIndex: staggers ? index : nil
                        )
                    }
                }
            }
            .padding()
        }
    }
}

#Preview("Timeline") {
    HopTimelinePreview()
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Timeline · AX3") {
    HopTimelinePreview()
        .environment(\.dynamicTypeSize, .accessibility3)
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Timeline · dark") {
    HopTimelinePreview()
        .hopBackground()
        .hopThemedRoot()
        .preferredColorScheme(.dark)
}

#Preview("Timeline · high contrast") {
    HopTimelinePreview()
        .hopBackground()
        .hopThemedRoot(appearance: .lightHighContrast)
}

#Preview("Timeline · staggered arrival") {
    HopTimelinePreview(staggers: true)
        .hopBackground()
        .hopThemedRoot()
}

#Preview("Timeline · staggered arrival, Reduce Motion") {
    HopTimelinePreview(staggers: true)
        .hopBackground()
        .hopThemedRoot(reduceMotion: true)
}
#endif
