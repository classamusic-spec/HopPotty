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
}
