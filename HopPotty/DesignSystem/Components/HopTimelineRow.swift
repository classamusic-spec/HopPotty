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
public struct HopTimelineRow: View {
    @Environment(\.hopTheme) private var theme

    private let event: PottyEvent
    private let isLast: Bool

    public init(event: PottyEvent, isLast: Bool) {
        self.event = event
        self.isLast = isLast
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
    var body: some View {
        ScrollView {
            HopCard {
                VStack(spacing: 0) {
                    ForEach(Array(HopTimelinePreviewData.day.enumerated()), id: \.element.id) { index, event in
                        HopTimelineRow(event: event, isLast: index == HopTimelinePreviewData.day.count - 1)
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
#endif
