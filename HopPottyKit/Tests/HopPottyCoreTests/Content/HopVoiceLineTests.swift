import Foundation
import Testing
@testable import HopPottyCore

/// Hop's voice.
///
/// No production audio exists yet, which is the interesting case: every line in
/// the app is currently delivered as a caption. That has to be a designed state
/// with a reason attached, not an empty `if let` that renders nothing and tells
/// nobody.
@Suite("Hop voice lines")
struct HopVoiceLineTests {

    @Test("Every line has a caption and a spoken form")
    func linesAreComplete() {
        let lines = HopVoiceCatalog.allLines
        #expect(!lines.isEmpty)
        for line in lines {
            #expect(!line.text.isEmpty, "\(line.id) has no spoken text")
            #expect(!line.caption.isEmpty, "\(line.id) has no caption")
            #expect(!line.asset.key.rawValue.isEmpty, "\(line.id) has no asset key")
        }
    }

    @Test("Line ids and asset keys are unique")
    func identifiersAreUnique() {
        let ids = HopVoiceCatalog.allLines.map(\.id)
        #expect(Set(ids).count == ids.count, "two voice lines share an id")
        let assets = HopVoiceCatalog.allLines.map(\.asset.key)
        #expect(Set(assets).count == assets.count, "two voice lines share an asset key")
    }

    /// The degradation is explicit: caption, plus the reason it is a caption.
    @Test("A line with no recording degrades to a caption with a reason")
    func plannedLinesDegradeExplicitly() {
        let line = HopVoiceLine(id: "routine.step.test.voice", text: "Soap, scrub, rinse.")
        #expect(line.asset.state == .planned)
        let playback = HopVoiceResolver.captionsOnly.playback(for: line)
        #expect(playback == .captionOnly(caption: "Soap, scrub, rinse.", because: .assetNotYetRecorded))
        #expect(!playback.isAudible)
        #expect(playback.caption == line.caption)
    }

    @Test("A recording that is missing from the bundle says so, rather than going quiet")
    func missingAssetsAreReported() {
        let line = HopVoiceLine(
            id: "routine.step.test.voice",
            text: "Flush it away.",
            asset: .recorded("vo.routine.step.test.voice")
        )
        let emptyBundle = HopVoiceResolver(isVoiceEnabled: true, availableAssets: [])
        #expect(emptyBundle.playback(for: line) == .captionOnly(caption: "Flush it away.", because: .assetMissingFromBundle))

        let fullBundle = HopVoiceResolver(isVoiceEnabled: true, availableAssets: ["vo.routine.step.test.voice"])
        #expect(fullBundle.playback(for: line) == .play("vo.routine.step.test.voice", caption: "Flush it away."))
    }

    /// Turning Hop's voice off is a caregiver's choice, and a different reason
    /// from a missing file. The player treats them differently: one is worth a
    /// diagnostic, the other is not.
    @Test("Voice turned off is its own reason, and takes precedence")
    func voiceOffIsDistinct() {
        let line = HopVoiceLine(
            id: "celebration.test.voice",
            text: "Back to play!",
            asset: .recorded("vo.celebration.test.voice")
        )
        let resolver = HopVoiceResolver(isVoiceEnabled: false, availableAssets: ["vo.celebration.test.voice"])
        #expect(resolver.playback(for: line) == .captionOnly(caption: "Back to play!", because: .voiceTurnedOff))
    }

    /// Whatever happens, the child gets the words.
    @Test("Every line in the app has visible words in every resolver state")
    func captionsSurviveEveryState() {
        let resolvers = [
            HopVoiceResolver.captionsOnly,
            HopVoiceResolver(isVoiceEnabled: false),
            HopVoiceResolver(isVoiceEnabled: true, availableAssets: Set(HopVoiceCatalog.allLines.map(\.asset.key))),
        ]
        for resolver in resolvers {
            for line in HopVoiceCatalog.allLines {
                #expect(!resolver.playback(for: line).caption.isEmpty, "\(line.id) rendered nothing")
            }
        }
    }

    @Test("Unrecorded lines are reported rather than assumed")
    func unrecordedLinesAreVisible() {
        let planned = HopVoiceCatalog.allLines.filter { $0.asset.state == .planned }
        #expect(HopVoiceCatalog.unrecordedLines.count == planned.count)
        let fraction: Double = HopVoiceCatalog.recordedFraction
        #expect(fraction >= 0.0)
        #expect(fraction <= 1.0)
    }

    @Test("The recording script covers every line")
    func recordingScriptIsComplete() {
        let script = HopVoiceCatalog.recordingScript()
        #expect(!script.isEmpty)
        for line in HopVoiceCatalog.allLines {
            #expect(script.contains(line.asset.key.rawValue), "\(line.id) is missing from the recording script")
            #expect(script.contains(line.text), "\(line.id) text is missing from the recording script")
        }
    }

    /// A line contributes its spoken text to the catalog, and a caption entry
    /// only when the written form actually differs — a second key holding a
    /// byte-identical string is one more thing to keep in sync for no gain.
    @Test("Lines contribute translatable entries")
    func linesContributeCopy() {
        let same = HopVoiceLine(id: "routine.step.test.voice", text: "Flush it away.")
        #expect(same.copyEntries().map(\.key) == ["routine.step.test.voice.spoken"])

        let different = HopVoiceLine(id: "quizzes.q.test.prompt", text: "Hop feels a squeeze in his tummy.", caption: "Hop feels a squeeze.")
        #expect(different.hasDistinctCaption)
        #expect(different.copyEntries().map(\.key) == ["quizzes.q.test.prompt.spoken", "quizzes.q.test.prompt.caption"])
    }

    @Test("Every line in the catalog is reachable from the copy catalog")
    func linesAreInTheCatalog() {
        let keys = Set(HopCopy.allEntries.map(\.key))
        for line in HopVoiceCatalog.allLines {
            #expect(keys.contains(line.id.rawValue + ".spoken"), "\(line.id) is not in the copy catalog")
        }
    }
}
