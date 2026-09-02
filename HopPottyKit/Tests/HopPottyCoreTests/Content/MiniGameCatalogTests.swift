import Foundation
import Testing
@testable import HopPottyCore

/// The mini-games.
///
/// `Docs/CONTRACTS.md` §4.7 rules out engagement mechanics. For a game handed to
/// a three-year-old that means something specific: no way to lose, no clock
/// running down, and a round short enough that the game stays a thank-you for
/// going to the bathroom rather than becoming the reason to go.
@Suite("Mini-game catalog")
struct MiniGameCatalogTests {

    @Test("Every game id has exactly one entry")
    func catalogIsComplete() {
        #expect(MiniGameCatalog.all.count == MiniGameID.allCases.count)
        for id in MiniGameID.allCases {
            #expect(MiniGameCatalog.game(id).id == id, "game(\(id.rawValue)) returned the wrong game")
        }
        let ids = MiniGameCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Rounds are between thirty and ninety seconds")
    func durationsAreInRange() {
        for game in MiniGameCatalog.all {
            let duration: TimeInterval = game.targetDuration
            #expect(
                MiniGameCatalog.targetDurationRange.contains(duration),
                "\(game.id.rawValue) targets \(duration)s, outside \(MiniGameCatalog.targetDurationRange)"
            )
        }
    }

    /// There is no losing state to look for: the completion type has two cases
    /// and neither of them is a loss. This switch is what stops compiling if a
    /// `.timeUp` or `.failed` is ever added.
    @Test("No game can be lost and none runs a countdown")
    func noLosingState() {
        for game in MiniGameCatalog.all {
            switch game.completion {
            case .whenTaskComplete:
                #expect(game.endsAutomatically, "\(game.id.rawValue) completes a task but claims not to end itself")
            case .whenChildIsDone:
                #expect(!game.endsAutomatically, "\(game.id.rawValue) waits for the child but claims to end itself")
            case .handOffToRoutine:
                #expect(game.endsAutomatically, "\(game.id.rawValue) hands off to the routine but claims not to end itself")
                #expect(
                    game.completion.handOffStep != nil,
                    "\(game.id.rawValue) hands off to a routine that has no first step"
                )
            }
        }
    }

    @Test("At least one game never ends on its own")
    func oneGameIsOpenEnded() {
        // The calm one. A child who wants to keep matching is allowed to.
        #expect(MiniGameCatalog.bathroomMatch.completion == .whenChildIsDone)
        #expect(MiniGameCatalog.all.contains { !$0.endsAutomatically })
    }

    @Test("Each game says what it is for, to the right audience")
    func audiencesAreRight() {
        for game in MiniGameCatalog.all {
            #expect(game.title.audience == .child, "\(game.id.rawValue) title is not child copy")
            #expect(game.childDescription.audience == .child, "\(game.id.rawValue) description is not child copy")
            #expect(game.learningGoal.audience == .parent, "\(game.id.rawValue) learning goal is not parent copy")
            #expect(!game.learningGoal.value.isEmpty)
            #expect(game.rewardReason == .completedGame)
            #expect(game.illustration.isWellFormed)
        }
    }

    @Test("Game copy is keyed under the games surface and unique")
    func gameCopyIsWellFormed() {
        let entries = MiniGameCatalog.copyEntries
        for entry in entries {
            #expect(entry.key.hasPrefix(HopCopySurface.games.keyPrefix), "\(entry.key) is not on the games surface")
        }
        let keys = entries.map(\.key)
        #expect(Set(keys).count == keys.count, "duplicated game keys")
    }

    // MARK: - The five newer games

    /// The games added alongside the original three. Listed explicitly rather
    /// than derived, so removing one from `all` fails here instead of silently
    /// shrinking the coverage below.
    static let newGames: [MiniGame] = [
        MiniGameCatalog.flySnack,
        MiniGameCatalog.mudOff,
        MiniGameCatalog.bodySignal,
        MiniGameCatalog.flushWave,
        MiniGameCatalog.pottyOrder,
    ]

    @Test("Each of the five newer games is in the catalog exactly once")
    func newGamesAreInTheCatalog() {
        for game in Self.newGames {
            #expect(MiniGameCatalog.all.filter { $0.id == game.id }.count == 1, "\(game.id.rawValue) is not in `all` exactly once")
            #expect(MiniGameCatalog.game(game.id).id == game.id)
        }
    }

    /// Between half a minute and a minute and a half, like every other game.
    /// The bound is written out rather than read from the range so that
    /// widening the range does not quietly widen the test.
    @Test("The newer games run between thirty and ninety seconds")
    func newGameDurationsAreInRange() {
        for game in Self.newGames {
            let duration: TimeInterval = game.targetDuration
            #expect(duration >= TimeInterval(30), "\(game.id.rawValue) targets \(duration)s, under thirty")
            #expect(duration <= TimeInterval(90), "\(game.id.rawValue) targets \(duration)s, over ninety")
        }
    }

    /// None of the five waits to be dismissed: each one reaches its own ending,
    /// whether that is a finished board or the first step of the routine.
    @Test("Every newer game ends on its own")
    func newGamesEndAutomatically() {
        for game in Self.newGames {
            #expect(game.endsAutomatically, "\(game.id.rawValue) does not end on its own")
        }
    }

    /// The type has no losing case, so there is nothing to look for at runtime —
    /// this switch is the assertion. It stops compiling the day someone adds
    /// `.failed`, `.timeUp` or `.gaveUp`, which is the only moment the check
    /// could be useful.
    @Test("No completion case is a losing case")
    func completionHasNoFailureCase() {
        for completion in [MiniGameCompletion.whenTaskComplete, .whenChildIsDone, .handOffToRoutine] {
            switch completion {
            case .whenTaskComplete, .whenChildIsDone, .handOffToRoutine:
                #expect(Bool(true))
            }
        }
        // And no game claims a reward for anything other than having played.
        for game in MiniGameCatalog.all {
            #expect(game.rewardReason == .completedGame, "\(game.id.rawValue) rewards something other than playing")
        }
    }

    /// Fly Snack is the only game whose ending is part of the lesson: the tummy
    /// fills, and what follows is a trip to the potty rather than a menu.
    @Test("Fly Snack hands off to the first step of the routine")
    func flySnackHandsOffToTheRoutine() {
        let game = MiniGameCatalog.flySnack
        #expect(game.completion == .handOffToRoutine)
        #expect(game.endsAutomatically)
        #expect(game.completion.handOffStep == PottyRoutineContent.steps.first?.id)
        #expect(MiniGameCatalog.all.filter { $0.completion == .handOffToRoutine }.count == 1)
        // The fullness line is about a signal, never about how much was eaten.
        #expect(game.done?.value == "Hop's tummy says: potty time!")
    }

    @Test("Every newer game has a title, an intro and a done line, all for the child")
    func newGamesHaveTheirThreeCards() {
        for game in Self.newGames {
            #expect(!game.title.value.isEmpty, "\(game.id.rawValue) has no title")
            #expect(game.title.audience == .child)

            let intro = game.intro
            #expect(intro != nil, "\(game.id.rawValue) has no intro line")
            #expect(intro?.value.isEmpty == false, "\(game.id.rawValue) has a blank intro")
            #expect(intro?.audience == .child, "\(game.id.rawValue) intro is not child copy")
            #expect(intro?.key == "games.\(game.id.rawValue).intro", "\(game.id.rawValue) intro is keyed \(intro?.key ?? "nothing")")

            let done = game.done
            #expect(done != nil, "\(game.id.rawValue) has no done line")
            #expect(done?.value.isEmpty == false, "\(game.id.rawValue) has a blank done line")
            #expect(done?.audience == .child, "\(game.id.rawValue) done line is not child copy")
            #expect(done?.key == "games.\(game.id.rawValue).done", "\(game.id.rawValue) done line is keyed \(done?.key ?? "nothing")")

            #expect(game.learningGoal.audience == .parent)
        }
    }

    @Test("Every newer game keys its copy under its own id")
    func newGameKeysAreOwned() {
        for game in Self.newGames {
            let prefix = "games.\(game.id.rawValue)."
            for entry in game.copyEntries {
                #expect(entry.key.hasPrefix(prefix), "\(entry.key) belongs to no game named \(game.id.rawValue)")
            }
        }
    }

    // MARK: - Art keys

    @Test("Every game names a scene and its sprites, and every key is well formed")
    func illustrationKeysAreWellFormed() {
        for game in MiniGameCatalog.all {
            #expect(game.illustration.isWellFormed, "\(game.id.rawValue) scene key \(game.illustration) is malformed")
            #expect(game.illustration.rawValue == "scene.games.\(game.id.rawValue)", "\(game.id.rawValue) scene key is \(game.illustration)")
            for sprite in game.sprites {
                #expect(sprite.isWellFormed, "\(game.id.rawValue) sprite key \(sprite) is malformed")
                #expect(sprite.family == "icon", "\(sprite) is not an icon")
                #expect(sprite.rawValue.hasPrefix("icon.games."), "\(sprite) is not keyed under icon.games")
                #expect(!sprite.assetName.isEmpty, "\(sprite) exports to no file name")
            }
            #expect(game.illustrations == [game.illustration] + game.sprites)
        }
    }

    /// Two games sharing a sprite key would share a drawing, and the second one
    /// to be drawn would silently replace the first.
    @Test("No two games claim the same art key")
    func artKeysAreUnique() {
        let keys = MiniGameCatalog.illustrations
        #expect(Set(keys).count == keys.count, "duplicated art keys among the games")
    }

    /// The keys the art pipeline was given. Written out verbatim because these
    /// are a contract with `Art/` and with the views: a rename here is a missing
    /// drawing there, and this is the test that says so.
    @Test("The newer games declare exactly the art the pipeline was promised")
    func promisedArtKeysArePresent() {
        let promised: Set<HopIllustrationKey> = [
            "scene.games.flySnack", "icon.games.fly.blue", "icon.games.fly.green",
            "icon.games.fly.gold", "icon.games.tummyMeter",
            "scene.games.mudOff", "icon.games.mud.brown", "icon.games.mud.green",
            "icon.games.mud.paint", "icon.games.sparkle",
            "scene.games.bodySignal", "icon.games.ball", "icon.games.thoughtBubble",
            "scene.games.flushWave", "icon.games.flusher", "icon.games.swirl",
            "scene.games.pottyOrder", "icon.games.card.pantsDown", "icon.games.card.sit",
            "icon.games.card.wipe", "icon.games.card.wash",
        ]
        let declared = Set(Self.newGames.flatMap(\.illustrations))
        #expect(declared == promised, "missing: \(promised.subtracting(declared)); unexpected: \(declared.subtracting(promised))")
    }

    // MARK: - Voice

    @Test("Every newer game has spoken lines, and every line reaches the catalog")
    func newGamesSpeak() {
        let catalogKeys = Set(HopCopy.allEntries.map(\.key))
        let allIDs = HopVoiceCatalog.allLines.map(\.id)
        for game in Self.newGames {
            #expect(!game.voiceLines.isEmpty, "\(game.id.rawValue) says nothing")
            for line in game.voiceLines {
                #expect(
                    line.id.rawValue.hasPrefix("games.\(game.id.rawValue).spoken."),
                    "\(line.id) is not keyed under its game's spoken lines"
                )
                #expect(!line.caption.isEmpty, "\(line.id) has no caption")
                #expect(line.asset.state == .planned, "\(line.id) claims a recording that does not exist yet")
                #expect(catalogKeys.contains(line.id.rawValue + ".spoken"), "\(line.id) is not translatable")
                #expect(allIDs.filter { $0 == line.id }.count == 1, "\(line.id) appears twice in the voice catalog")
            }
        }
    }

    // MARK: - Safety

    /// The second safety net, run over the games specifically.
    ///
    /// `ChildSafetyCopyTests` already scans the whole catalog, which is what
    /// actually guards the product. This narrower pass exists so that a failure
    /// names the game — an engineer adding a sixth game finds out from the game
    /// suite, in the words of the game they just wrote.
    @Test("No game says anything a child could hear as being told off")
    func gameCopyIsKind() {
        for game in MiniGameCatalog.all {
            for entry in game.copyEntries {
                let matches = CopySafetyScanner.shameMatches(in: entry.value)
                #expect(
                    matches.isEmpty,
                    "\(entry.key) says \"\(entry.value)\" — shame language: \(matches.joined(separator: ", "))"
                )
                #expect(
                    CopySafetyScanner.medicalMatches(in: entry.value).isEmpty,
                    "\(entry.key) says \"\(entry.value)\" — medical language"
                )
            }
            for line in game.voiceLines {
                #expect(CopySafetyScanner.shameMatches(in: line.text).isEmpty, "\(line.id) says \"\(line.text)\"")
                #expect(CopySafetyScanner.shameMatches(in: line.caption).isEmpty, "\(line.id) captions \"\(line.caption)\"")
                #expect(CopySafetyScanner.medicalMatches(in: line.text).isEmpty, "\(line.id) says \"\(line.text)\"")
            }
            #expect(
                CopySafetyScanner.prescriptiveMatches(in: game.learningGoal.value).isEmpty,
                "\(game.learningGoal.key) tells a caregiver what to do"
            )
        }
    }

    /// The words named in the brief for these games, checked one by one so the
    /// failure message says which word and which game.
    @Test("The named words appear in no game copy")
    func namedWordsAreAbsent() {
        let banned = ["wrong", "fail", "failed", "lose", "lost", "hurry", "must", "should", "bad", "naughty"]
        let strings = MiniGameCatalog.all.flatMap { game in
            game.copyEntries.map(\.value) + game.voiceLines.flatMap { [$0.text, $0.caption] }
        }
        for text in strings {
            for word in banned {
                #expect(!CopySafetyScanner.containsWord(word, in: text), "\"\(text)\" contains \"\(word)\"")
            }
        }
    }

    /// Fly Snack talks about a signal, not about appetite. A line that read
    /// "Hop ate too much!" would pass every word-level scan and still teach a
    /// two-year-old the one thing this game exists to avoid teaching.
    @Test("Fly Snack never frames fullness as eating too much")
    func flySnackIsNeutralAboutEating() {
        let phrases = ["too much", "too many", "so full", "over full", "big tummy", "greedy"]
        let strings = MiniGameCatalog.flySnack.copyEntries.map(\.value)
            + MiniGameCatalog.flySnack.voiceLines.map(\.text)
        for text in strings {
            for phrase in phrases {
                #expect(!CopySafetyScanner.containsPhrase(phrase, in: text), "\"\(text)\" contains \"\(phrase)\"")
            }
        }
        // The tummy is a messenger: what it says is where to go next.
        #expect(MiniGameCatalog.flySnack.done?.value.contains("potty time") == true)
    }

    // MARK: - Child copy length

    /// The same ceiling the whole catalog is held to, asserted here as well
    /// because a game's intro card is the longest thing these screens show.
    @Test("Game copy stays short enough for a pre-reader")
    func gameCopyIsShort() {
        for game in MiniGameCatalog.all {
            for entry in game.copyEntries where entry.audience == .child {
                #expect(entry.exampleRendering.count <= 90, "\(entry.key) is \(entry.exampleRendering.count) characters")
            }
            for line in game.voiceLines {
                #expect(line.text.count <= 90, "\(line.id) is \(line.text.count) characters")
            }
        }
    }
}
