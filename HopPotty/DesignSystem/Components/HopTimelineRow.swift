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
/// that is one fact. The rail and the node are decorative and hidden.
///
/// ## Arrival
///
/// `arrivalIndex:` gives a day's worth of entries a staggered arrival: each row
/// fades and slides a few points toward its rail, and its connector *draws*
/// downward a beat behind the node, so a timeline reads as being written down
/// the page rather than as a block appearing. Off by default, and off entirely
/// under Reduce Motion, where the rows simply fade in together.
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

    /// The connector follows the node rather than arriving with it. The extra
    /// beat is what makes it read as a line being drawn; under Reduce Motion
    /// there is no beat, because there is nothing to draw.
    private var railAnimation: Animation {
        theme.reduceMotion ? arrivalAnimation : arrivalAnimation.delay(0.08)
    }

    private var tint: Color { theme.color.accent(for: event.kind) }

    private var timeText: String {
        event.timestamp.formatted(date: .omitted, time: .shortened)
    }

    public var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.m) {
            Text(timeText)
                .hopTextStyle(.parentCaption)
                // Monospaced so a column of times lines up on the colon instead
                // of ragging left as the hour changes width.
                .hopNumericText()
                .foregroundStyle(theme.color.textSecondary)
                .frame(width: 64, alignment: .trailing)
                .padding(.top, 6)

            rail

            VStack(alignment: .leading, spacing: 2) {
                Text(event.kind.displayName)
                    .hopTextStyle(.parentHeadline)
                    .foregroundStyle(theme.color.textPrimary)

                Text(event.source.displayName)
                    .hopTextStyle(.parentCaption)
                    .foregroundStyle(theme.color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let note = event.note, !note.isEmpty {
                    Text(note)
                        .hopTextStyle(.parentCallout)
                        .foregroundStyle(theme.color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, theme.spacing.xs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, isLast ? 0 : theme.spacing.xl)
        }
        .opacity(isArriving ? 0 : 1)
        // Toward the rail, not down the page: a row sliding vertically would
        // cross the row above it, and the rail is the thing it belongs to.
        .offset(x: isArriving && !theme.reduceMotion ? -10 : 0)
        .animation(arrivalAnimation, value: hasArrived)
        .onAppear { hasArrived = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(timeText), \(event.kind.displayName)")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard let note = event.note, !note.isEmpty else { return event.source.displayName }
        return "\(event.source.displayName). \(HopStrings.noteLabel): \(note)"
    }

    private var rail: some View {
        VStack(spacing: 0) {
            HopGlyphBadge(HopGlyph(event.kind), tint: tint, diameter: 32)
            if !isLast {
                Rectangle()
                    .fill(theme.color.divider)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 2)
                    .scaleEffect(y: isArriving && !theme.reduceMotion ? 0 : 1, anchor: .top)
                    .animation(railAnimation, value: hasArrived)
            }
        }
        .frame(width: 32)
        .accessibilityHidden(true)
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
