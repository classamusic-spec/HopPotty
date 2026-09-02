import SwiftUI
import HopPottyDesignTokens

/// The first thing HopPotty draws.
///
/// ## What this is not
///
/// It is not the launch screen. iOS renders `UILaunchScreen` — a flat
/// `LaunchBackground` fill, declared in `App/Info.plist` — before a line of
/// this app's code runs, and there is no API that animates it. Nothing here
/// changes that, and nothing here should be described as if it did.
///
/// What it does instead is make the handover invisible: the ground it paints is
/// `backgroundPrimary`, which is the same colour in both appearances as the
/// `LaunchBackground` colour set the system just painted. The system's frame
/// and this view's first frame are the same image, so the seam between them has
/// nothing to show.
///
/// ## Why it cannot make the app slower
///
/// It is an overlay on a view tree that is already there and already loading.
/// `RootView`'s `.task` — the disk read, the service graph, the first
/// reconciliation — starts on the same frame the first hop does, and finishes
/// whenever it finishes. This view waits for none of it, asks it nothing, and
/// removes itself on its own timer: if the app is ready first, the beat still
/// finishes cleanly; if it is not, the caregiver is handed the loading state
/// that would have been on screen anyway. Nothing loops, nothing polls, and the
/// whole thing is over in ``HopSplashChoreography/total`` seconds.
struct HopSplashView: View {
    @Environment(\.hopTheme) private var theme

    /// Called once, when the splash has finished and should be removed.
    let onFinished: () -> Void

    @State private var layout = HopLogoLayout.assembled
    @State private var opacity: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let plan = HopSplashChoreography(reduceMotion: theme.reduceMotion, container: proxy.size)
            ZStack {
                // The launch screen's colour, continued. Not a gradient, not a
                // pattern: the system just painted this exact fill and any
                // difference would read as a flash.
                theme.color.backgroundPrimary
                HopLogoView(width: plan.logoWidth, layout: layout)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .opacity(opacity)
            .task { await run(plan) }
        }
        .ignoresSafeArea()
        // The lockup carries the one label there is (`HopLogoView`). Nothing
        // here is focusable, nothing announces itself, and nothing is marked
        // modal — a decorative animation that captured VoiceOver for a second
        // and a half would be worse than no animation at all.
        .accessibilityAddTraits(.isImage)
    }

    /// Walks the plan. One `Task`, one pass, no loop.
    ///
    /// Cancellation is the removal path as well as the failure path: the view
    /// going away cancels this, which is why the last thing it does is check.
    private func run(_ plan: HopSplashChoreography) async {
        layout = plan.opening
        opacity = 1

        // The plan's times are absolute, so each wait is the difference from
        // wherever the last one left us. A beat that runs long shortens the next
        // gap instead of pushing the total out.
        var elapsed: Double = 0
        for step in plan.steps {
            guard await pause(step.at - elapsed) else { return }
            elapsed = step.at
            withAnimation(step.spring.animation(reduceMotion: plan.reduceMotion)) {
                layout[step.layer] = step.placement
            }
        }

        guard await pause(plan.fadeOutAt - elapsed) else { return }
        elapsed = plan.fadeOutAt
        withAnimation(.easeInOut(duration: HopMotion.reducedMotionFade)) {
            opacity = 0
        }
        guard await pause(plan.total - elapsed) else { return }
        onFinished()
    }

    /// Waits, and reports whether the splash is still wanted afterwards.
    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(max(0, seconds)))
        return !Task.isCancelled
    }
}

// MARK: - Presenting it

extension View {
    /// Plays the launch animation over this view while it comes up.
    ///
    /// Applied *inside* the themed root and *around* the content, so the
    /// content — and every `.task` on it — is live from the first frame. The
    /// splash is on top of a running app, never in front of one that has not
    /// started.
    func hopSplash() -> some View {
        modifier(HopSplashPresenter())
    }
}

private struct HopSplashPresenter: ViewModifier {
    @State private var isFinished = false

    func body(content: Content) -> some View {
        content.overlay {
            if !isFinished {
                HopSplashView { isFinished = true }
            }
        }
    }
}

#if DEBUG
#Preview("Splash") {
    HopThemedRoot {
        Color.clear.hopBackground().hopSplash()
    }
}

#Preview("Splash · Reduce Motion") {
    HopThemedRoot(reduceMotion: true) {
        Color.clear.hopBackground().hopSplash()
    }
}
#endif
