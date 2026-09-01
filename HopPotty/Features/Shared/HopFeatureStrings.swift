import Foundation

/// Parent-facing strings the copy catalog does not carry yet.
///
/// `Docs/CONTRACTS.md` §5 routes user-visible text through `HopCopy`. These are
/// the sentences the parent screens need that `HopCopy` has no key for today —
/// the Day/Week/Month labels, the test-pause screen, the schedule preview
/// heading, and the medical-language disclaimer the interval screen is required
/// to carry.
///
/// They are gathered in one file, and only one, for the same reason
/// `DesignSystem/Foundation/HopStrings.swift` exists: moving them into `HopCopy`
/// is then a mechanical change with no call sites to hunt for. Each constant
/// below is written to `HopCopy`'s rules — describes, never prescribes; states
/// what HopPotty does, never what a child should do.
enum HopFeatureStrings {

    // MARK: Interval

    /// Required wording on the interval screen.
    ///
    /// Two sentences doing two jobs: the first removes the pressure to get the
    /// number right, the second states plainly that HopPotty is not a clinical
    /// tool. `Docs/CONTRACTS.md` §4.5 bars medical claims; this is the sentence
    /// that keeps the *absence* of one from being read as an implied one.
    static let intervalDisclaimer =
        "You can change this anytime. HopPotty doesn't provide medical timing recommendations."

    // MARK: Onboarding

    static let authorizationApprovedTitle = "Screen Time is connected"
    static let authorizationApprovedBody =
        "HopPotty can pause the apps you pick. It never sees what happens inside them."
    static let authorizationRetry = "Ask again"
    static let authorizationGentleFallbackTitle = "HopPotty will send reminders instead"
    static let authorizationGentleFallbackBody =
        "Without Screen Time permission, apps are never paused. Hop still checks in on your schedule, and you can turn pausing on later in Settings."

    static let testPauseTitle = "Try a Potty Pause"
    static let testPauseBody =
        "This runs one pause right now so you can see exactly what your child sees. It ends on its own."
    static let testPauseRun = "Run a test pause"
    static let testPauseSucceeded = "That worked. The apps you picked paused and came straight back."
    static let testPauseSkip = "Skip the test"

    static let notificationsTitle = "Let Hop give a heads-up"
    static let notificationsBody =
        "A short notice before a pause gives your child a moment to finish what they are doing. HopPotty never sends anything to bring your child back to a screen."
    static let notificationsAllow = "Allow notifications"

    static let readyTitle = "Ready when you are"
    static let readyGentleNote = "Reminders are on. Apps are not paused."

    static let activeHoursStart = "Starts"
    static let activeHoursEnd = "Ends"
    static let activeChildMarker = "Currently shown"

    // MARK: Schedule preview

    /// Heading above the plain-language rendering of the schedule.
    static let schedulePreviewTitle = "What this means"
    static let schedulePreviewHint =
        "This sentence is built from the settings above. If it does not describe your day, change a setting until it does."

    // MARK: Progress

    static let progressTitle = "Progress"
    static let progressRangeDay = "Day"
    static let progressRangeWeek = "Week"
    static let progressRangeMonth = "Month"
    static let progressTotalsTitle = "What was logged"
    static let progressPatternsTitle = "Patterns"
    static let progressEmptyTitle = "Nothing logged in this period"
    static let progressEmptyMessage =
        "Entries appear here as you and your child log them. Nothing is missing — the period simply has no entries."

    // MARK: Parent home

    static let homeGreetingMorning = "Good morning"
    static let homeGreetingAfternoon = "Good afternoon"
    static let homeGreetingEvening = "Good evening"
    static let homeNoChildTitle = "No child set up yet"
    static let homeNoChildMessage = "Add a child to start using HopPotty."
    static let homeAddChild = "Add a child"
    static let homeOpenTimer = "Potty Pause settings"

    // MARK: Settings

    static let settingsSectionChildren = "Children"
    static let settingsSectionPurchase = "HopPotty Family"
    static let settingsDebugLab = "Debug lab"
    static let settingsDebugLabFooter = "Development build only."
    static let settingsTerms = "Terms of use"
    static let settingsStoreUnavailable =
        "HopPotty could not open its storage, so nothing logged in this session will be kept. Restarting the app usually fixes it."
    static let settingsPurchasedBadge = "Unlocked"

    // MARK: Screen access

    static let restoreInProgress = "Lifting the pause"
    static let restoreConfirmed = "Screen access is back."

    // MARK: Data

    static let exportInProgress = "Preparing your file"
    static let exportReady = "Your file is ready to move wherever you like."
    static let deleteChildAction = "Delete this child's data"
    static let deleteEverythingAction = "Delete everything"
}
