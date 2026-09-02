import Foundation
import Observation
import HopPottyCore

/// Everything Hop's screen knows, and the only thing in Child Space that writes.
///
/// ## Why the child's home has a model at all
///
/// The four child surfaces are deliberately dumb: `PottyRoutineView`,
/// `PondScreen`, `GamesScreen` and `QuizRoundView` each report what happened and
/// touch no store. Somebody has to be the caller they report *to* — write the
/// visit, offer the star, and read the new total back so the pond behind Hop
/// grows. That is this type, and it is the only object a child's tap can reach
/// that has a repository in it.
///
/// ## What it deliberately cannot do
///
/// There is no method here that shortens, extends, cancels or inspects a Potty
/// Pause. The routine and the pause are two different things that happen to
/// overlap: `Docs/ChildSafety.md` §8 and Contract §4.1 make the pause end on its
/// own timer, on completion, or on a caregiver override, and nothing a child does
/// on this screen is allowed to be a fourth path. `HopHubView` only ever *reads*
/// the pause record, once, to decide whether to open on the routine.
///
/// There is also no method that removes a star, resets a total, or writes an
/// `.accident`. `RewardCoordinator` has no removal API to call, and
/// `PottyEventKind.isChildLoggable` is checked before an event is written, so
/// the one kind a child must never self-report cannot be written from here even
/// by mistake.
@MainActor
@Observable
final class HopHubModel {

    /// Who is playing, what they have, and what they are allowed to be offered.
    /// Handed to every child surface through `\.childContext`.
    private(set) var context: ChildContext

    /// Nil until the first read finishes. The hub draws with an empty pond and a
    /// zero star count in the meantime rather than a spinner: a child looking at
    /// Hop's screen should never be looking at loading chrome.
    private(set) var child: ChildProfile?

    private let environment: ParentEnvironment
    private let rewards: RewardCoordinator

    init(environment: ParentEnvironment) {
        self.environment = environment
        self.context = ChildContext(settings: environment.settings)
        // Built here rather than injected because `ParentEnvironment` carries
        // the repositories and not the coordinators. Two instances of
        // `RewardCoordinator` over the same repositories are safe: it holds no
        // state of its own, and the ledger's idempotency key — not any in-memory
        // bookkeeping — is what collapses a repeated award.
        self.rewards = RewardCoordinator(
            rewards: environment.repositories.rewards,
            pond: environment.repositories.pond,
            clock: environment.clock
        )
    }

    // MARK: - Reading

    /// Reads the child, their settings, their star total and their pond.
    ///
    /// Safe to call as often as the hub reappears. A failed read leaves the last
    /// good context in place — the child's screen is not the place to explain a
    /// storage error, and a pond that is briefly one star behind is better than a
    /// pond that vanishes.
    func load() async {
        guard let child = environment.resolvedChild(nil) else { return }
        self.child = child

        let stars = (try? await rewards.totalStars(for: child.id)) ?? context.totalStars
        let pond = (try? await rewards.pond(for: child.id)) ?? context.pond

        context = ChildContext(
            child: child,
            settings: environment.settings,
            totalStars: stars,
            pond: pond
        )
    }

    // MARK: - What the surfaces report back

    /// Writes the visit and offers the stars the run earned.
    ///
    /// Every star is keyed to `session`, which the hub mints when it *opens* the
    /// routine — before anything could have gone wrong — rather than to the
    /// event row. That is the difference between a key derived from durable data
    /// and one derived from this attempt: an event id minted here would be new on
    /// every retry, so it would make a repeated finish look like a second visit
    /// and pay for it twice. With the session as the scope, one run earns one
    /// star per reason however many times this method is called.
    ///
    /// The star not carrying a `sourceEventID` costs the child nothing: deleting
    /// an event never removes its star anyway (`RewardService.reconcile` breaks
    /// the link and keeps the row), so the only difference is which line of the
    /// deletion receipt the star appears on.
    func finishRoutine(_ result: PottyRoutineResult, session: UUID) async {
        guard let child else { return }

        // `isChildLoggable` is false only for `.accident`, which the routine has
        // no way to produce. Checked anyway: the one rule this app cannot get
        // wrong is that a child is never asked to record a failure state, and a
        // guard is cheaper than the argument about whether it can happen.
        if let kind = result.outcome, kind.isChildLoggable {
            let event = PottyEvent(
                childID: child.id,
                timestamp: environment.clock.now,
                kind: kind,
                source: .childRoutine
            )
            // A failed write loses the timeline row, not the stars. The child
            // did the thing; a full disk is not their problem and must not be
            // their loss.
            try? await environment.repositories.events.save(event)
        }

        for reason in result.earnedReasons {
            _ = try? await rewards.award(reason: reason, childID: child.id, scope: .session(session))
        }

        await load()
    }

    /// Offers the star a finished game round earns.
    ///
    /// Scoped to the calendar day, which is what `RewardScope.day` documents
    /// itself as being for: a game round has no row of its own, so "once today"
    /// is the only collapse window derivable from durable data. It is also the
    /// answer that keeps `Docs/ChildSafety.md` §7 true — a star per replay would
    /// make the game the reason to go to the bathroom. Nothing tells the child
    /// this, and nothing asks them to come back tomorrow: the star simply lands
    /// the first time and the game stays exactly as playable afterwards.
    func finishGame(_ result: MiniGameRoundResult) async {
        await awardOncePerDay(result.rewardReason)
    }

    /// Offers the star a finished round of questions earns. Leaving early earns
    /// the same star — see `QuizRoundResult`.
    func finishQuiz(_ result: QuizRoundResult) async {
        await awardOncePerDay(result.rewardReason)
    }

    private func awardOncePerDay(_ reason: RewardReason) async {
        guard let child else { return }
        _ = try? await rewards.award(
            reason: reason,
            childID: child.id,
            scope: .day(environment.clock.now)
        )
        await load()
    }
}
