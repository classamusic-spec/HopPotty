import SwiftUI
import HopPottyCore

// Cross-cutting support for every child-facing surface (routine, pond, games,
// quizzes).
//
// It lives under `PottyRoutine/Support/` only because the four feature folders
// are this workstream's agreed write scope; the whole app is one module, so
// placement here is organisational, not architectural. At integration these
// three files move to `Features/ChildSurfaces/` unchanged.

/// Everything a child surface needs to know about who is playing.
///
/// One value, passed through the environment, so no child view reaches for a
/// store, a service or a database. Views read it; the flow models mutate their
/// own state and hand results back to the caller.
struct ChildContext: Equatable, Sendable {
    var child: ChildProfile
    var settings: AppSettings
    /// Lifetime stars, derived from the reward ledger by the caller. Never
    /// stored here as a mutable running total — see `RewardService`.
    var totalStars: Int
    var pond: PondProgress

    init(
        child: ChildProfile = ChildProfile(),
        settings: AppSettings = AppSettings(),
        totalStars: Int = 0,
        pond: PondProgress? = nil
    ) {
        self.child = child
        self.settings = settings
        self.totalStars = totalStars
        self.pond = pond ?? PondProgress(childID: child.id)
    }

    var nickname: String? { child.nickname }

    /// Whether captions are drawn under a spoken line. Contract §6 makes this a
    /// caregiver preference over *presentation*, never over *availability*:
    /// VoiceOver still reads the caption text when this is off.
    var showsCaptions: Bool { settings.spokenTextCaptionsEnabled }

    /// The resolver that decides whether a line plays or falls back to its
    /// caption. Today no voice asset ships, so every line is caption-only —
    /// that path is the normal one, not an error state.
    var voiceResolver: HopVoiceResolver {
        HopVoiceResolver(isVoiceEnabled: settings.hopVoiceEnabled, availableAssets: [])
    }
}

private struct ChildContextKey: EnvironmentKey {
    // A child view rendered without a context still draws: an unnamed child
    // with default settings and an empty pond.
    static let defaultValue = ChildContext()
}

extension EnvironmentValues {
    var childContext: ChildContext {
        get { self[ChildContextKey.self] }
        set { self[ChildContextKey.self] = newValue }
    }
}

extension View {
    /// Installs the child context. Call once, at the root of a child flow.
    func childContext(_ context: ChildContext) -> some View {
        environment(\.childContext, context)
    }
}

// MARK: - Stage sizing

/// How large the illustrated stage at the centre of a child screen should be.
///
/// iPad does not scale the phone layout up: it keeps the stage at a size a
/// child can still take in at arm's length and lets the surrounding scene
/// breathe instead. A 600pt frog is not a better frog.
enum ChildStage {
    static func height(for sizeClass: UserInterfaceSizeClass?, in containerHeight: CGFloat) -> CGFloat {
        let ceiling: CGFloat = sizeClass == .regular ? 420 : 300
        return min(ceiling, max(180, containerHeight * 0.38))
    }

    static func characterSize(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 260 : 190
    }

    /// The widest a child's stage and controls are allowed to get.
    static let contentWidth = HopLayout.childContentWidth
}
