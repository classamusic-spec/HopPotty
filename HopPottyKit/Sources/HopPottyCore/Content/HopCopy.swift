import Foundation

// MARK: - Brand

public struct BrandCopy: HopCopySection {
    public static let surface: HopCopySurface = .brand

    public let name = HopCopyEntry.parent(
        "brand.name",
        "HopPotty",
        comment: "Product name. Never translated."
    )
    public let tagline = HopCopyEntry.parent(
        "brand.tagline",
        "Pause. Potty. Play.",
        comment: "Three beats describing the whole loop: the game pauses, the child goes, the game returns. Keep the rhythm of three short words; a literal translation matters less than the cadence."
    )
    public let characterName = HopCopyEntry.child(
        "brand.character.name",
        "Hop",
        comment: "The frog guide's name. A short, friendly sound a two-year-old can say; adapt if the sound is awkward in the target language."
    )
}

// MARK: - Common

/// Words that appear on more than one surface. One key each, so a change lands
/// everywhere and a translator sees them together.
public struct CommonCopy: HopCopySection {
    public static let surface: HopCopySurface = .common

    public let done = HopCopyEntry.parent("common.done", "Done", comment: "Button that closes a sheet. Verbless in English.")
    public let cancel = HopCopyEntry.parent("common.cancel", "Cancel")
    public let save = HopCopyEntry.parent("common.save", "Save")
    public let delete = HopCopyEntry.parent("common.delete", "Delete", comment: "Destructive button. Always behind the parent gate.")
    public let back = HopCopyEntry.parent("common.back", "Back")
    public let next = HopCopyEntry.parent("common.next", "Next", comment: "Advances to the next step of a parent flow.")
    public let notNow = HopCopyEntry.parent("common.notNow", "Not now", comment: "Declines without closing the door on the offer.")
    public let openSettings = HopCopyEntry.parent("common.openSettings", "Open Settings", comment: "Opens the iOS Settings app, not HopPotty's own settings.")
    public let childYes = HopCopyEntry.child("common.child.yes", "Yes!")
    public let childOkay = HopCopyEntry.child("common.child.okay", "Okay!")
    public let childAllDone = HopCopyEntry.child("common.child.allDone", "All done!")
    public let childAgain = HopCopyEntry.child("common.child.again", "Again!", comment: "Child taps this to replay a game or hear a line again.")
}

// MARK: - Onboarding

public struct OnboardingCopy: HopCopySection {
    public static let surface: HopCopySurface = .onboarding

    public let welcomeTitle = HopCopyEntry.parent("onboarding.welcome.title", "Welcome to HopPotty")
    public let welcomeTagline = HopCopyEntry.parent("onboarding.welcome.tagline", "Pause. Potty. Play.")
    public let welcomeBody = HopCopyEntry.parent(
        "onboarding.welcome.body",
        "HopPotty pauses the games your child is playing, invites them to the potty, and hands the game straight back."
    )
    public let welcomeContinue = HopCopyEntry.parent("onboarding.welcome.continue", "Get started")

    public let privacyTitle = HopCopyEntry.parent("onboarding.privacy.title", "Everything stays on this device")
    public let privacyBody = HopCopyEntry.parent(
        "onboarding.privacy.body",
        "Every event, star and note lives on your device. There is no account, no analytics, and nothing is uploaded."
    )
    public let privacyDetail = HopCopyEntry.parent("onboarding.privacy.detail", "Read the privacy details")

    public let nameTitle = HopCopyEntry.parent("onboarding.name.title", "What can Hop call your child?")
    public let namePlaceholder = HopCopyEntry.parent("onboarding.name.placeholder", "Nickname", comment: "Text field placeholder. A first name or whatever the family uses at home.")
    public let nameFooter = HopCopyEntry.parent(
        "onboarding.name.footer",
        "Optional. HopPotty asks for nothing else: no last name, no birthday, no photo."
    )
    public let nameSkip = HopCopyEntry.parent("onboarding.name.skip", "Skip for now")

    public let greeting = HopNameVariants(
        named: .child(
            "onboarding.greeting.named",
            "Hi, %1$@! I'm Hop.",
            comment: "Hop introduces himself to the child, using their nickname.",
            placeholders: [.nickname()]
        ),
        unnamed: .child(
            "onboarding.greeting.unnamed",
            "Hi! I'm Hop.",
            comment: "Same greeting when no nickname was entered."
        )
    )

    public let avatarTitle = HopCopyEntry.parent("onboarding.avatar.title", "Pick a friend")
    public let avatarBody = HopCopyEntry.parent("onboarding.avatar.body", "Your child sees this character on every screen.")

    public let rhythmTitle = HopCopyEntry.parent("onboarding.rhythm.title", "How often is a good rhythm?")
    public let rhythmBody = HopCopyEntry.parent(
        "onboarding.rhythm.body",
        "Many families start near 45 minutes and adjust after a few days. You can change it any time.",
        comment: "Descriptive, not a recommendation. Avoid wording that implies a correct interval."
    )

    public let modeTitle = HopCopyEntry.parent("onboarding.mode.title", "How would you like HopPotty to interrupt?")
    public let modeGentleTitle = HopCopyEntry.parent("onboarding.mode.gentle.title", "Gentle")
    public let modeGentleBody = HopCopyEntry.parent("onboarding.mode.gentle.body", "A reminder appears. Nothing is ever blocked.")
    public let modePauseTitle = HopCopyEntry.parent("onboarding.mode.pause.title", "Potty Pause")
    public let modePauseBody = HopCopyEntry.parent(
        "onboarding.mode.pause.body",
        "The apps you pick go quiet and a friendly screen invites your child to the potty. The pause ends on its own timer."
    )
    public let modeRoutineTitle = HopCopyEntry.parent("onboarding.mode.routine.title", "Guided routine")
    public let modeRoutineBody = HopCopyEntry.parent(
        "onboarding.mode.routine.body",
        "Hop walks your child through trying, wiping, flushing and washing, then hands the game back."
    )

    public let screenTimeTitle = HopCopyEntry.parent("onboarding.screenTime.title", "HopPotty uses Screen Time")
    public let screenTimeBody = HopCopyEntry.parent(
        "onboarding.screenTime.body",
        "iOS does the pausing. HopPotty asks permission to pause only the apps you pick, and never sees what happens inside them."
    )
    public let screenTimeGrant = HopCopyEntry.parent("onboarding.screenTime.grant", "Allow Screen Time")

    public let appsTitle = HopCopyEntry.parent("onboarding.apps.title", "Pick the apps that pause")
    public let appsBody = HopCopyEntry.parent(
        "onboarding.apps.body",
        "Usually the games and video apps your child uses most. Everything else keeps working as it does now."
    )
    public let appsPickButton = HopCopyEntry.parent("onboarding.apps.pick", "Choose apps")

    public let doneTitle = HopCopyEntry.parent("onboarding.done.title", "You are all set")
    public let doneBody = HopCopyEntry.parent("onboarding.done.body", "HopPotty is watching the clock now. Everything is editable in Settings.")
    public let doneButton = HopCopyEntry.parent("onboarding.done.button", "Go to HopPotty")
}

// MARK: - Parent home

public struct ParentHomeCopy: HopCopySection {
    public static let surface: HopCopySurface = .parentHome

    public let title = HopCopyEntry.parent("parentHome.title", "Today")

    /// The hero card. Canonical wording — the whole product is named by this
    /// card and it appears in App Store screenshots.
    public let heroTitle = HopCopyEntry.parent("parentHome.hero.title", "Next Potty Pause")
    public let heroCountdown = HopCopyEntry.parent(
        "parentHome.hero.countdown",
        "In %1$@",
        comment: "Sits under the hero title. The value is a formatted duration produced by the caller.",
        placeholders: [.text(1, "timeRemaining", "Formatted time until the next pause.", example: "12 minutes")]
    )
    public let heroWaitingForActivity = HopCopyEntry.parent(
        "parentHome.hero.waitingForActivity",
        "When app use starts again",
        comment: "Shown when pauses are driven by app use rather than the clock, and the child is not using the selected apps."
    )
    public let heroQuietWindow = HopCopyEntry.parent(
        "parentHome.hero.quietWindow",
        "Quiet until %1$@",
        placeholders: [.text(1, "endTime", "Wall-clock time the quiet window ends.", example: "2:30 PM")]
    )
    public let heroSkippingNext = HopCopyEntry.parent("parentHome.hero.skippingNext", "Skipping the next one")
    public let heroPausedUntilTomorrow = HopCopyEntry.parent("parentHome.hero.pausedUntilTomorrow", "Paused until tomorrow")
    public let heroDisabled = HopCopyEntry.parent("parentHome.hero.disabled", "Potty Pause is off")
    public let heroOutsideActiveHours = HopCopyEntry.parent("parentHome.hero.outsideActiveHours", "Outside today's active hours")

    public let summaryTitle = HopCopyEntry.parent("parentHome.summary.title", "Today so far")
    public let summaryVisits = HopPluralVariants(
        zero: .parent("parentHome.summary.visits.zero", "No potty visits logged yet"),
        one: .parent(
            "parentHome.summary.visits.one",
            "%1$lld potty visit logged",
            placeholders: [.count(1, "visits", "Number of potty events logged today.", example: "1")]
        ),
        other: .parent(
            "parentHome.summary.visits.other",
            "%1$lld potty visits logged",
            placeholders: [.count(1, "visits", "Number of potty events logged today.", example: "4")]
        )
    )
    public let summaryStars = HopPluralVariants(
        zero: .parent("parentHome.summary.stars.zero", "None yet today"),
        one: .parent(
            "parentHome.summary.stars.one",
            "%1$lld star earned today",
            placeholders: [.count(1, "stars", "Stars earned today.", example: "1")]
        ),
        other: .parent(
            "parentHome.summary.stars.other",
            "%1$lld stars earned today",
            placeholders: [.count(1, "stars", "Stars earned today.", example: "6")]
        )
    )
    public let summaryTriesLabel = HopCopyEntry.parent("parentHome.summary.triesLabel", "Tries")
    public let summaryStarsLabel = HopCopyEntry.parent("parentHome.summary.starsLabel", "Stars")

    public let timelineTitle = HopCopyEntry.parent("parentHome.timeline.title", "Timeline")
    public let timelineEmpty = HopCopyEntry.parent("parentHome.timeline.empty", "Nothing logged yet today.")
    public let timelineAddButton = HopCopyEntry.parent("parentHome.timeline.add", "Log a visit")

    public let eventTried = HopCopyEntry.parent("parentHome.event.tried", "Tried", comment: "A potty visit with no result. The primary event in HopPotty and never a lesser one.")
    public let eventPee = HopCopyEntry.parent("parentHome.event.pee", "Pee")
    public let eventPoop = HopCopyEntry.parent("parentHome.event.poop", "Poop")
    public let eventAccident = HopCopyEntry.parent("parentHome.event.accident", "Accident")
    public let eventAccidentFooter = HopCopyEntry.parent(
        "parentHome.event.accidentFooter",
        "Recorded as a neutral fact. Accidents never touch your child's stars, and your child never sees this entry."
    )
    public let eventSourceChild = HopCopyEntry.parent("parentHome.event.source.child", "Logged by your child")
    public let eventSourceParent = HopCopyEntry.parent("parentHome.event.source.parent", "Logged by you")
    public let eventSourcePause = HopCopyEntry.parent("parentHome.event.source.pause", "Recorded at the end of a pause")
    public let eventNotePlaceholder = HopCopyEntry.parent("parentHome.event.notePlaceholder", "Note for yourself", comment: "Private to the caregiver. Never shown to the child.")

    public let actionSkipNext = HopCopyEntry.parent("parentHome.action.skipNext", "Skip the next pause")
    public let actionPauseUntilTomorrow = HopCopyEntry.parent("parentHome.action.pauseUntilTomorrow", "Pause until tomorrow")
    public let actionResume = HopCopyEntry.parent("parentHome.action.resume", "Resume Potty Pause")
    public let actionStartNow = HopCopyEntry.parent("parentHome.action.startNow", "Start a pause now")

    public let insightsTitle = HopCopyEntry.parent("parentHome.insights.title", "Patterns")
    public let insightsDisclaimer = HopCopyEntry.parent(
        "parentHome.insights.disclaimer",
        "These are patterns in what you logged. They describe your child's week and nothing else.",
        comment: "Framing line under the insights. It exists to keep observations from reading as advice; keep the hedge in translation."
    )
    public let insightsNotEnoughData = HopCopyEntry.parent(
        "parentHome.insights.notEnoughData",
        "A few more days of logging will fill this in."
    )
    public let insightsBusiestWindow = HopCopyEntry.parent(
        "parentHome.insights.busiestWindow",
        "Most visits happened between %1$@ and %2$@.",
        placeholders: [
            .text(1, "windowStart", "Start of the busiest observed window.", example: "9:00 AM"),
            .text(2, "windowEnd", "End of the busiest observed window.", example: "11:00 AM"),
        ]
    )
    public let insightsAverageGap = HopCopyEntry.parent(
        "parentHome.insights.averageGap",
        "The average gap between logged visits was %1$@.",
        placeholders: [.text(1, "duration", "Formatted average interval.", example: "1 hour 10 minutes")]
    )

    public let childSwitcher = HopCopyEntry.parent("parentHome.childSwitcher", "Switch child")
    public let openChildMode = HopCopyEntry.parent("parentHome.openChildMode", "Hand it to your child")
}

// MARK: - Timer settings

public struct TimerSettingsCopy: HopCopySection {
    public static let surface: HopCopySurface = .timerSettings

    public let title = HopCopyEntry.parent("timerSettings.title", "Potty Pause")

    public let modeLabel = HopCopyEntry.parent("timerSettings.mode.label", "Mode")
    public let modeGentle = HopCopyEntry.parent("timerSettings.mode.gentle", "Gentle")
    public let modePause = HopCopyEntry.parent("timerSettings.mode.pause", "Potty Pause")
    public let modeRoutine = HopCopyEntry.parent("timerSettings.mode.routine", "Guided routine")

    public let basisLabel = HopCopyEntry.parent("timerSettings.basis.label", "What starts the countdown")
    public let basisScreenActivity = HopCopyEntry.parent("timerSettings.basis.screenActivity", "App use")
    public let basisScreenActivityFooter = HopCopyEntry.parent(
        "timerSettings.basis.screenActivityFooter",
        "The countdown runs only while your child is using the apps you picked."
    )
    public let basisClockTime = HopCopyEntry.parent("timerSettings.basis.clockTime", "Clock time")
    public let basisClockTimeFooter = HopCopyEntry.parent(
        "timerSettings.basis.clockTimeFooter",
        "The countdown runs on the wall clock during your active hours, whatever the device is doing."
    )

    public let intervalLabel = HopCopyEntry.parent("timerSettings.interval.label", "Every")
    public let intervalValue = HopPluralVariants(
        one: .parent(
            "timerSettings.interval.value.one",
            "%1$lld minute",
            placeholders: [.count(1, "minutes", "Interval length in minutes.", example: "1")]
        ),
        other: .parent(
            "timerSettings.interval.value.other",
            "%1$lld minutes",
            placeholders: [.count(1, "minutes", "Interval length in minutes.", example: "45")]
        )
    )
    public let intervalCustom = HopCopyEntry.parent("timerSettings.interval.custom", "Custom")
    public let intervalCustomRange = HopCopyEntry.parent(
        "timerSettings.interval.customRange",
        "Anything from %1$lld to %2$lld minutes.",
        placeholders: [
            .count(1, "minimum", "Shortest interval HopPotty allows.", example: "10"),
            .count(2, "maximum", "Longest interval HopPotty allows.", example: "240"),
        ]
    )

    public let warningLabel = HopCopyEntry.parent("timerSettings.warning.label", "Warning before a pause")
    public let warningFooter = HopCopyEntry.parent(
        "timerSettings.warning.footer",
        "A heads-up gives your child a moment to finish what they are doing."
    )
    public let warningOff = HopCopyEntry.parent("timerSettings.warning.off", "No warning")

    public let durationLabel = HopCopyEntry.parent("timerSettings.duration.label", "Pause length")
    public let durationFooter = HopCopyEntry.parent(
        "timerSettings.duration.footer",
        "The pause ends when this time is up, whatever happened in the bathroom. Screen access is never held back for a result.",
        comment: "This sentence states a product guarantee. Translate the guarantee exactly; it is the promise the whole app rests on."
    )

    public let cooldownLabel = HopCopyEntry.parent("timerSettings.cooldown.label", "Rest between pauses")
    public let cooldownFooter = HopCopyEntry.parent(
        "timerSettings.cooldown.footer",
        "After a pause ends, HopPotty waits at least this long before the next one."
    )

    public let activeHoursLabel = HopCopyEntry.parent("timerSettings.activeHours.label", "Active hours")
    public let activeHoursValue = HopCopyEntry.parent(
        "timerSettings.activeHours.value",
        "%1$@ to %2$@",
        placeholders: [
            .text(1, "start", "Start of the active window.", example: "7:00 AM"),
            .text(2, "end", "End of the active window.", example: "7:30 PM"),
        ]
    )
    public let activeDaysLabel = HopCopyEntry.parent("timerSettings.activeDays.label", "Active days")
    public let activeDaysEveryDay = HopCopyEntry.parent("timerSettings.activeDays.everyDay", "Every day")

    public let quietTitle = HopCopyEntry.parent("timerSettings.quiet.title", "Quiet times")
    public let quietFooter = HopCopyEntry.parent(
        "timerSettings.quiet.footer",
        "HopPotty stays silent during these. Naps, meals and bedtime are the usual ones."
    )
    public let quietAdd = HopCopyEntry.parent("timerSettings.quiet.add", "Add a quiet time")
    public let quietEmpty = HopCopyEntry.parent("timerSettings.quiet.empty", "No quiet times yet.")
    public let quietLabelNap = HopCopyEntry.parent("timerSettings.quiet.label.nap", "Nap")
    public let quietLabelBedtime = HopCopyEntry.parent("timerSettings.quiet.label.bedtime", "Bedtime")
    public let quietLabelSchool = HopCopyEntry.parent("timerSettings.quiet.label.school", "School")
    public let quietLabelMealtime = HopCopyEntry.parent("timerSettings.quiet.label.mealtime", "Mealtime")
    public let quietLabelCustom = HopCopyEntry.parent("timerSettings.quiet.label.custom", "Quiet time")
    public let quietRemove = HopCopyEntry.parent(
        "timerSettings.quiet.remove",
        "Remove the %1$@ quiet time?",
        placeholders: [.text(1, "label", "The quiet window's label, already localised.", example: "Nap")]
    )

    public let disableButton = HopCopyEntry.parent("timerSettings.disable.button", "Disable Potty Pause")
    public let disableFooter = HopCopyEntry.parent(
        "timerSettings.disable.footer",
        "Reminders and pauses will not run until you turn this back on. Stars and pond decorations stay exactly as they are."
    )
    public let enableButton = HopCopyEntry.parent("timerSettings.enable.button", "Enable Potty Pause")
}

// MARK: - Shield

/// The Screen Time shield. Rendered by an app extension with no access to the
/// app's state, so every string here has to make sense cold, on its own.
public struct ShieldCopy: HopCopySection {
    public static let surface: HopCopySurface = .shield

    public let title = HopCopyEntry.child(
        "shield.title",
        "Potty time!",
        comment: "The headline on the pause screen. Canonical wording: warm, two words, an invitation rather than an instruction."
    )
    public let body = HopCopyEntry.child(
        "shield.body",
        "Let's hop to the potty. Your game will be here when you get back.",
        comment: "Canonical wording. The second sentence is the promise that makes the pause safe; never drop it in translation."
    )
    public let bodyWithApp = HopCopyEntry.child(
        "shield.bodyWithApp",
        "Let's hop to the potty. %1$@ will be right here when you get back.",
        comment: "Same promise, naming the app the child was in.",
        placeholders: [.text(1, "appName", "Name of the paused app, from the system.", example: "Bluey")]
    )
    public let greeting = HopNameVariants(
        named: .child(
            "shield.greeting.named",
            "Potty time, %1$@!",
            comment: "Headline when a nickname is set.",
            placeholders: [.nickname()]
        ),
        unnamed: .child("shield.greeting.unnamed", "Potty time!")
    )
    // Specified verbatim in the product brief. A first-person alternative
    // ("I'm going!" / "Ask a grown-up") reads better to some ears — no question
    // mark for a pre-reader, and the child speaking rather than being addressed —
    // but changing canonical copy is a product decision, not an implementation one.
    public let primaryButton = HopCopyEntry.child("shield.primary", "Let's Go!", comment: "Primary shield button. Canonical brand copy.")
    public let secondaryButton = HopCopyEntry.child("shield.secondary", "Need a grown-up?", comment: "Secondary shield button, routes to the parent gate.")
    public let returning = HopCopyEntry.child(
        "shield.returning",
        "Your game comes back soon.",
        comment: "Reassurance while the pause is up. Deliberately vague about the exact time: a visible countdown reads as pressure to a small child."
    )
    public let restoreButton = HopCopyEntry.parent(
        "shield.restore",
        "Restore Screen Access",
        comment: "Caregiver escape hatch on the pause screen. Canonical wording, and it appears in Settings with the same words."
    )
    public let restoreFooter = HopCopyEntry.parent(
        "shield.restoreFooter",
        "Lifts the pause right now and hands the apps straight back."
    )
}

// MARK: - Notifications

public struct NotificationCopy: HopCopySection {
    public static let surface: HopCopySurface = .notification

    public let warningTitle = HopCopyEntry.child(
        "notification.warning.title",
        "Potty break coming soon!",
        comment: "Canonical wording for the heads-up notification, a couple of minutes before a pause."
    )
    public let warningBody = HopNameVariants(
        named: .child(
            "notification.warning.body.named",
            "%1$@, find a good spot to pause your game.",
            placeholders: [.nickname()]
        ),
        unnamed: .child("notification.warning.body.unnamed", "Find a good spot to pause your game.")
    )
    public let pauseTitle = HopCopyEntry.child("notification.pause.title", "Potty time!")
    public let pauseBody = HopCopyEntry.child("notification.pause.body", "Hop is waiting by the pond.")

    public let summaryTitle = HopCopyEntry.parent("notification.summary.title", "Today with HopPotty")
    public let summaryBody = HopCopyEntry.parent(
        "notification.summary.body",
        "Your timeline for today is ready.",
        comment: "Daily summary. Deliberately free of numbers so the notification itself never reads as a scorecard."
    )
}

// MARK: - Routine chrome

/// Buttons and framing around the guided routine. The steps themselves live in
/// `PottyRoutineContent`.
public struct RoutineChromeCopy: HopCopySection {
    public static let surface: HopCopySurface = .routine

    public let introTitle = HopCopyEntry.child(
        "routine.intro.title",
        "Let's give it a try.",
        comment: "Canonical opening line of the routine. An invitation with no expectation attached."
    )
    public let stepProgress = HopCopyEntry.parent(
        "routine.progress",
        "Step %1$lld of %2$lld",
        comment: "Read by VoiceOver and shown to caregivers helping out. The child sees dots, not numbers.",
        placeholders: [
            .count(1, "current", "1-based index of the current step.", example: "2"),
            .count(2, "total", "Number of steps in the routine.", example: "5"),
        ]
    )
    public let nextButton = HopCopyEntry.child("routine.next", "Next")
    public let skipButton = HopCopyEntry.child("routine.skip", "Skip this")
    public let helpButton = HopCopyEntry.child("routine.help", "I need a grown-up")
    public let repeatButton = HopCopyEntry.child("routine.repeat", "Say it again")
    public let outcomeQuestion = HopCopyEntry.child("routine.outcome.question", "How did it go?")
    public let outcomePee = HopCopyEntry.child("routine.outcome.pee", "Pee!")
    public let outcomePoop = HopCopyEntry.child("routine.outcome.poop", "Poop!")
    public let outcomeNothing = HopCopyEntry.child(
        "routine.outcome.nothing",
        "Nothing yet",
        comment: "The third option, drawn exactly as large and as cheerfully as the other two."
    )
    public let sitTimerCaption = HopCopyEntry.child(
        "routine.sitTimer.caption",
        "Take all the time you need.",
        comment: "Shown beside the optional sit timer. The timer fills up rather than counting down."
    )
    public let leaveButton = HopCopyEntry.child("routine.leave", "All done!")
}

// MARK: - Celebration

public struct CelebrationCopy: HopCopySection {
    public static let surface: HopCopySurface = .celebration

    public let successTitle = HopCopyEntry.child(
        "celebration.success.title",
        "You listened to your body!",
        comment: "Canonical. Celebrates the skill the child controls, never the result."
    )
    public let triedTitle = HopCopyEntry.child(
        "celebration.tried.title",
        "Nothing happened? That's okay. Nice trying!",
        comment: "Canonical response when a visit produced nothing. Warmth first, then praise for the attempt."
    )
    public let hygieneTitle = HopCopyEntry.child(
        "celebration.hygiene.title",
        "Flush, wash, high five!",
        comment: "Canonical three-beat cheer at the end of the hygiene steps. Keep the rhythm of three."
    )
    public let resumeButton = HopCopyEntry.child(
        "celebration.resume.button",
        "Back to play!",
        comment: "Canonical. The button that returns the child to their game."
    )
    public let starsEarned = HopPluralVariants(
        one: .child(
            "celebration.stars.one",
            "You earned a star!",
            comment: "English spells out the single star rather than showing a numeral."
        ),
        other: .child(
            "celebration.stars.other",
            "You earned %1$lld stars!",
            placeholders: [.count(1, "stars", "Stars earned in this session.", example: "2")]
        )
    )
    public let starTotal = HopPluralVariants(
        one: .child(
            "celebration.total.one",
            "%1$lld star in your pond",
            placeholders: [.count(1, "stars", "Lifetime star total.", example: "1")]
        ),
        other: .child(
            "celebration.total.other",
            "%1$lld stars in your pond",
            placeholders: [.count(1, "stars", "Lifetime star total.", example: "34")]
        )
    )
    public let pondUnlock = HopCopyEntry.child(
        "celebration.pondUnlock",
        "A new pond friend is waiting!",
        comment: "Shown when the star just earned unlocks a decoration."
    )
    public let toldGrownUp = HopCopyEntry.child("celebration.toldGrownUp", "You told a grown-up. Hooray!")
    public let washedHands = HopCopyEntry.child("celebration.washedHands", "Sparkly clean hands!")
    public let seeThePond = HopCopyEntry.child("celebration.seeThePond", "See your pond")
    public let greeting = HopNameVariants(
        named: .child(
            "celebration.greeting.named",
            "Way to go, %1$@!",
            placeholders: [.nickname()]
        ),
        unnamed: .child("celebration.greeting.unnamed", "Way to go!")
    )
}

// MARK: - Pond

public struct PondCopy: HopCopySection {
    public static let surface: HopCopySurface = .pond

    public let title = HopNameVariants(
        named: .child(
            "pond.title.named",
            "%1$@'s pond",
            comment: "Screen title when the child has a nickname. Possessive; some languages will need a different construction.",
            placeholders: [.nickname()]
        ),
        unnamed: .child(
            "pond.title.unnamed",
            "Your pond",
            comment: "Screen title when no nickname is set. Second person, not a name-shaped gap."
        )
    )
    public let starCount = HopPluralVariants(
        // Never "no stars": the ledger only ever grows, and the empty state
        // should read as a beginning rather than an absence.
        zero: .child("pond.starCount.zero", "Ready for your first star!"),
        one: .child(
            "pond.starCount.one",
            "%1$lld star",
            placeholders: [.count(1, "stars", "Stars available to spend.", example: "1")]
        ),
        other: .child(
            "pond.starCount.other",
            "%1$lld stars",
            placeholders: [.count(1, "stars", "Stars available to spend.", example: "12")]
        )
    )
    public let emptyTitle = HopCopyEntry.child("pond.empty.title", "Your pond is ready")
    public let emptyBody = HopCopyEntry.child("pond.empty.body", "Every star adds something new.")
    public let nextUnlock = HopPluralVariants(
        one: .child(
            "pond.nextUnlock.one",
            "%1$lld more star and %2$@ hops in!",
            comment: "The item name stays at position 2 in every plural form, so the caller passes the same arguments whichever form is chosen.",
            placeholders: [
                .count(1, "stars", "Stars still needed.", example: "1"),
                .text(2, "itemName", "Name of the next pond decoration.", example: "a dragonfly"),
            ]
        ),
        other: .child(
            "pond.nextUnlock.other",
            "%1$lld more stars and %2$@ hops in!",
            placeholders: [
                .count(1, "stars", "Stars still needed.", example: "3"),
                .text(2, "itemName", "Name of the next pond decoration.", example: "a dragonfly"),
            ]
        )
    )
    public let itemLocked = HopPluralVariants(
        one: .child(
            "pond.item.locked.one",
            "%1$lld star",
            placeholders: [.count(1, "stars", "Star cost of the decoration.", example: "1")]
        ),
        other: .child(
            "pond.item.locked.other",
            "%1$lld stars",
            placeholders: [.count(1, "stars", "Star cost of the decoration.", example: "5")]
        )
    )
    public let itemUnlocked = HopCopyEntry.child("pond.item.unlocked", "Yours!")
    public let collectionTitle = HopCopyEntry.child("pond.collection.title", "Pond friends")
    public let tapHint = HopCopyEntry.child("pond.tapHint", "Tap a friend to say hi")
    public let placeItem = HopCopyEntry.child("pond.placeItem", "Put it in the pond")
}

// MARK: - Games chrome

/// Framing around the mini-games. Per-game strings live in `MiniGameCatalog`.
public struct GamesChromeCopy: HopCopySection {
    public static let surface: HopCopySurface = .games

    public let title = HopCopyEntry.child("games.title", "Play")
    public let startButton = HopCopyEntry.child("games.start", "Play")
    public let againButton = HopCopyEntry.child("games.again", "Play again")
    public let doneButton = HopCopyEntry.child("games.done", "All done")
    public let finished = HopCopyEntry.child("games.finished", "Great playing!")
    public let disabledFooter = HopCopyEntry.parent(
        "games.disabledFooter",
        "Mini-games are off for this child. You can turn them on in Settings."
    )
    public let goalLabel = HopCopyEntry.parent(
        "games.goalLabel",
        "What it practises",
        comment: "Heading above the learning goal on the caregiver's game list."
    )
    public let durationLabel = HopCopyEntry.parent(
        "games.durationLabel",
        "About %1$@",
        comment: "Typical length of one round, on the caregiver's game list.",
        placeholders: [.text(1, "duration", "Formatted target duration.", example: "45 seconds")]
    )
    public let endsOnItsOwn = HopCopyEntry.parent("games.endsOnItsOwn", "Ends on its own")
    public let endsWhenChildIsDone = HopCopyEntry.parent("games.endsWhenChildIsDone", "Ends when your child taps Done")
}

// MARK: - Quiz chrome

/// Framing around the questions. The questions live in `QuizContent`.
public struct QuizzesChromeCopy: HopCopySection {
    public static let surface: HopCopySurface = .quizzes

    public let title = HopCopyEntry.child("quizzes.title", "Hop's questions")
    public let startButton = HopCopyEntry.child("quizzes.start", "Let's try one!")
    public let replayPrompt = HopCopyEntry.child("quizzes.replay", "Hear it again")
    public let nextButton = HopCopyEntry.child("quizzes.next", "Another one")
    public let doneButton = HopCopyEntry.child("quizzes.done", "All done")
    public let finishedTitle = HopCopyEntry.child("quizzes.finished.title", "You answered them all!")
    public let finishedBody = HopCopyEntry.child("quizzes.finished.body", "Want to hear them again?")
    public let disabledFooter = HopCopyEntry.parent(
        "quizzes.disabledFooter",
        "Questions are off for this child. You can turn them on in Settings."
    )
    public let parentNote = HopCopyEntry.parent(
        "quizzes.parentNote",
        "There is no score and no timer. A pick that is not the one being taught simply gets a warm invitation to try another.",
        comment: "Explains the quiz design to a caregiver who wonders where the score went."
    )
}

// MARK: - Settings

public struct SettingsCopy: HopCopySection {
    public static let surface: HopCopySurface = .settings

    public let title = HopCopyEntry.parent("settings.title", "Settings")

    public let sectionChild = HopCopyEntry.parent("settings.section.child", "Child")
    public let childNickname = HopCopyEntry.parent("settings.child.nickname", "Nickname")
    public let childNicknameFooter = HopCopyEntry.parent(
        "settings.child.nicknameFooter",
        "Optional. Without one, Hop says your pond instead of a name."
    )
    public let childAvatar = HopCopyEntry.parent("settings.child.avatar", "Character")
    public let childPondTheme = HopCopyEntry.parent("settings.child.pondTheme", "Pond")
    public let childAdd = HopCopyEntry.parent("settings.child.add", "Add a child")
    public let childRemove = HopCopyEntry.parent("settings.child.remove", "Remove this child")

    public let sectionSound = HopCopyEntry.parent("settings.section.sound", "Sound and voice")
    public let soundVoice = HopCopyEntry.parent("settings.sound.voice", "Hop's voice")
    public let soundVoiceFooter = HopCopyEntry.parent(
        "settings.sound.voiceFooter",
        "Hop reads each step aloud. Captions stay on screen either way."
    )
    public let soundEffects = HopCopyEntry.parent("settings.sound.effects", "Sound effects")
    public let soundAmbient = HopCopyEntry.parent("settings.sound.ambient", "Pond sounds")
    public let soundHaptics = HopCopyEntry.parent("settings.sound.haptics", "Haptics")
    public let soundCaptions = HopCopyEntry.parent("settings.sound.captions", "Show captions")
    public let soundCaptionsFooter = HopCopyEntry.parent(
        "settings.sound.captionsFooter",
        "Shows the written form of every line Hop speaks."
    )

    public let sectionExperience = HopCopyEntry.parent("settings.section.experience", "What your child sees")
    public let experienceGames = HopCopyEntry.parent("settings.experience.games", "Mini-games")
    public let experienceQuizzes = HopCopyEntry.parent("settings.experience.quizzes", "Questions")
    public let experienceSitTimer = HopCopyEntry.parent("settings.experience.sitTimer", "Show a sit timer")
    public let experienceSitTimerFooter = HopCopyEntry.parent(
        "settings.experience.sitTimerFooter",
        "A calm filling circle during the try step. Off by default, because a visible timer makes some children tense."
    )
    public let experienceSitTimerLength = HopCopyEntry.parent("settings.experience.sitTimerLength", "Sit timer length")

    public let sectionNotifications = HopCopyEntry.parent("settings.section.notifications", "Notifications")
    public let notificationsWarning = HopCopyEntry.parent("settings.notifications.warning", "Warning before a pause")
    public let notificationsSummary = HopCopyEntry.parent("settings.notifications.summary", "Daily summary")
    public let notificationsSummaryTime = HopCopyEntry.parent("settings.notifications.summaryTime", "Summary time")

    public let sectionPrivacy = HopCopyEntry.parent("settings.section.privacy", "Privacy and data")
    public let privacyExport = HopCopyEntry.parent("settings.privacy.export", "Export my data")
    public let privacyExportFooter = HopCopyEntry.parent(
        "settings.privacy.exportFooter",
        "Writes a file you keep. HopPotty sends it nowhere."
    )
    public let privacyDeleteChild = HopCopyEntry.parent("settings.privacy.deleteChild", "Delete this child's data")
    public let privacyDeleteAll = HopCopyEntry.parent("settings.privacy.deleteAll", "Delete everything")

    public let sectionGate = HopCopyEntry.parent("settings.section.gate", "Grown-up gate")
    public let gateStyleArithmetic = HopCopyEntry.parent("settings.gate.arithmetic", "Hold and answer a sum")
    public let gateStyleDeviceOwner = HopCopyEntry.parent("settings.gate.deviceOwner", "Face ID or passcode")

    public let emergencyTitle = HopCopyEntry.parent("settings.emergency.title", "Restore Screen Access")
    public let emergencyFooter = HopCopyEntry.parent(
        "settings.emergency.footer",
        "Lifts any pause that is up right now. Use it whenever you need to; nothing about it counts against your child."
    )
    public let emergencyConfirm = HopCopyEntry.parent("settings.emergency.confirm", "Restore access now")

    public let sectionAbout = HopCopyEntry.parent("settings.section.about", "About")
    public let aboutVersion = HopCopyEntry.parent(
        "settings.about.version",
        "Version %1$@",
        placeholders: [.text(1, "version", "Marketing version and build.", example: "1.0 (12)")]
    )
    public let aboutPrivacyPolicy = HopCopyEntry.parent("settings.about.privacyPolicy", "Privacy policy")
    public let aboutSupport = HopCopyEntry.parent("settings.about.support", "Contact support")
    public let aboutAcknowledgements = HopCopyEntry.parent("settings.about.acknowledgements", "Acknowledgements")
}

// MARK: - Errors

/// Every failure a caregiver can see, with the recovery in the body.
public struct ErrorsCopy: HopCopySection {
    public static let surface: HopCopySurface = .errors

    public let screenTimeDeniedTitle = HopCopyEntry.parent("errors.screenTime.denied.title", "Screen Time permission is off")
    public let screenTimeDeniedBody = HopCopyEntry.parent(
        "errors.screenTime.denied.body",
        "Potty Pause needs Screen Time permission to pause apps. Reminders keep working without it."
    )
    public let screenTimeRestrictedTitle = HopCopyEntry.parent("errors.screenTime.restricted.title", "Screen Time is unavailable here")
    public let screenTimeRestrictedBody = HopCopyEntry.parent(
        "errors.screenTime.restricted.body",
        "This device is managed by someone else, so HopPotty is unable to pause apps on it. Gentle reminders still work."
    )
    public let screenTimeNoSelectionTitle = HopCopyEntry.parent("errors.screenTime.noSelection.title", "No apps picked yet")
    public let screenTimeNoSelectionBody = HopCopyEntry.parent(
        "errors.screenTime.noSelection.body",
        "Pick at least one app for HopPotty to pause."
    )
    public let screenTimeRegistrationTitle = HopCopyEntry.parent("errors.screenTime.registration.title", "Scheduling did not go through")
    public let screenTimeRegistrationBody = HopCopyEntry.parent(
        "errors.screenTime.registration.body",
        "HopPotty will try again shortly. Your settings are saved."
    )
    public let shieldApplyTitle = HopCopyEntry.parent("errors.shield.apply.title", "That pause did not start")
    public let shieldApplyBody = HopCopyEntry.parent(
        "errors.shield.apply.body",
        "Your child was not interrupted. The next pause will try again."
    )
    public let shieldClearTitle = HopCopyEntry.parent("errors.shield.clear.title", "Apps are still paused")
    public let shieldClearBody = HopCopyEntry.parent(
        "errors.shield.clear.body",
        "Restore Screen Access lifts it right away.",
        comment: "Names the button in Settings, so keep the two strings identical."
    )
    public let notificationsDeniedTitle = HopCopyEntry.parent("errors.notifications.denied.title", "Notifications are off")
    public let notificationsDeniedBody = HopCopyEntry.parent(
        "errors.notifications.denied.body",
        "The heads-up before a pause needs notification permission."
    )
    public let storageTitle = HopCopyEntry.parent("errors.storage.title", "HopPotty could not save that")
    public let storageBody = HopCopyEntry.parent(
        "errors.storage.body",
        "Your device may be out of space. Free some room and try again."
    )
    public let genericTitle = HopCopyEntry.parent("errors.generic.title", "Something went sideways")
    public let genericBody = HopCopyEntry.parent(
        "errors.generic.body",
        "Your data is safe. Try again in a moment."
    )
    public let retryButton = HopCopyEntry.parent("errors.retry", "Try again")
    public let dismissButton = HopCopyEntry.parent("errors.dismiss", "Dismiss")
    public let childFallback = HopCopyEntry.child(
        "errors.child.fallback",
        "Let's find a grown-up.",
        comment: "The only failure a child ever sees. No detail, no apology, just the next step."
    )
}

// MARK: - Parent gate

public struct ParentGateCopy: HopCopySection {
    public static let surface: HopCopySurface = .parentGate

    public let title = HopCopyEntry.parent("parentGate.title", "Grown-ups only")
    public let body = HopCopyEntry.parent("parentGate.body", "Hold the button, then answer the question.")
    public let holdInstruction = HopCopyEntry.parent("parentGate.hold", "Press and hold")
    public let question = HopCopyEntry.parent(
        "parentGate.question",
        "What is %1$lld plus %2$lld?",
        comment: "Spelled out rather than shown as a plus sign, so a pre-reader cannot guess it from the shape.",
        placeholders: [
            .count(1, "firstNumber", "First addend.", example: "13"),
            .count(2, "secondNumber", "Second addend.", example: "24"),
        ]
    )
    public let retry = HopCopyEntry.parent("parentGate.retry", "Not quite. Here is another one.")
    public let deviceOwnerReason = HopCopyEntry.parent(
        "parentGate.deviceOwnerReason",
        "Confirm it is a grown-up",
        comment: "Reason string shown by Face ID or Touch ID."
    )

    public let deleteChildTitle = HopNameVariants(
        named: .parent(
            "parentGate.delete.child.title.named",
            "Delete %1$@'s data?",
            placeholders: [.nickname()]
        ),
        unnamed: .parent("parentGate.delete.child.title.unnamed", "Delete this child's data?")
    )
    public let deleteEvents = HopPluralVariants(
        zero: .parent("parentGate.delete.events.zero", "No logged events to remove."),
        one: .parent(
            "parentGate.delete.events.one",
            "%1$lld logged potty event will be removed.",
            placeholders: [.count(1, "events", "Events that will be deleted.", example: "1")]
        ),
        other: .parent(
            "parentGate.delete.events.other",
            "%1$lld logged potty events will be removed.",
            placeholders: [.count(1, "events", "Events that will be deleted.", example: "128")]
        )
    )
    public let deleteStars = HopPluralVariants(
        // Matches the "earned star" wording of the other forms, and keeps the
        // banned "no stars" phrasing out of a dialog a caregiver reads aloud.
        zero: .parent("parentGate.delete.stars.zero", "No earned stars to remove."),
        one: .parent(
            "parentGate.delete.stars.one",
            "%1$lld earned star will be removed.",
            placeholders: [.count(1, "stars", "Stars that will be deleted.", example: "1")]
        ),
        other: .parent(
            "parentGate.delete.stars.other",
            "%1$lld earned stars will be removed.",
            placeholders: [.count(1, "stars", "Stars that will be deleted.", example: "64")]
        )
    )
    public let deleteDecorations = HopPluralVariants(
        zero: .parent("parentGate.delete.decorations.zero", "No pond decorations to remove."),
        one: .parent(
            "parentGate.delete.decorations.one",
            "%1$lld pond decoration will be removed.",
            placeholders: [.count(1, "decorations", "Pond items that will be deleted.", example: "1")]
        ),
        other: .parent(
            "parentGate.delete.decorations.other",
            "%1$lld pond decorations will be removed.",
            placeholders: [.count(1, "decorations", "Pond items that will be deleted.", example: "9")]
        )
    )
    public let deleteIrreversible = HopCopyEntry.parent(
        "parentGate.delete.irreversible",
        "This cannot be undone.",
        comment: "Required on every destructive confirmation, alongside the exact counts above."
    )
    public let deleteConfirm = HopCopyEntry.parent("parentGate.delete.confirm", "Delete")
    public let deleteEverythingTitle = HopCopyEntry.parent("parentGate.delete.everything.title", "Delete everything?")
    public let deleteEverythingChildren = HopPluralVariants(
        one: .parent(
            "parentGate.delete.everything.children.one",
            "%1$lld child profile will be removed.",
            placeholders: [.count(1, "children", "Profiles that will be deleted.", example: "1")]
        ),
        other: .parent(
            "parentGate.delete.everything.children.other",
            "%1$lld child profiles will be removed.",
            placeholders: [.count(1, "children", "Profiles that will be deleted.", example: "2")]
        )
    )
}

// MARK: - Purchase

/// One purchase, no subscription, no countdown, no discount that expires.
public struct PurchaseCopy: HopCopySection {
    public static let surface: HopCopySurface = .purchase

    public let title = HopCopyEntry.parent("purchase.title", "HopPotty Family")
    public let subtitle = HopCopyEntry.parent("purchase.subtitle", "One purchase. Every feature, for good.")
    public let featureChildren = HopCopyEntry.parent("purchase.feature.children", "Every child in the family")
    public let featurePond = HopCopyEntry.parent("purchase.feature.pond", "The whole pond collection")
    public let featureGames = HopCopyEntry.parent("purchase.feature.games", "All three mini-games")
    public let featureInsights = HopCopyEntry.parent("purchase.feature.insights", "Weekly pattern summaries")
    public let price = HopCopyEntry.parent(
        "purchase.price",
        "%1$@ once",
        comment: "The word after the price makes clear it is not a subscription.",
        placeholders: [.text(1, "price", "Localised price from the App Store.", example: "$14.99")]
    )
    public let buyButton = HopCopyEntry.parent("purchase.buy", "Unlock HopPotty")
    public let restoreButton = HopCopyEntry.parent("purchase.restore", "Restore purchase")
    public let freeFooter = HopCopyEntry.parent(
        "purchase.freeFooter",
        "The free version keeps one child, the full routine and every reminder. Nothing your child earned is ever behind the purchase.",
        comment: "The second sentence is a product commitment, not marketing. Keep it."
    )
    public let thanksTitle = HopCopyEntry.parent("purchase.thanks.title", "Thank you")
    public let thanksBody = HopCopyEntry.parent(
        "purchase.thanks.body",
        "Everything is unlocked on every device signed in to your Apple Account."
    )
    public let restored = HopCopyEntry.parent("purchase.restored", "Your purchase is restored.")
    public let failedTitle = HopCopyEntry.parent("purchase.failed.title", "The purchase did not complete")
    public let failedBody = HopCopyEntry.parent("purchase.failed.body", "You were not charged. You can try again any time.")
    public let pendingTitle = HopCopyEntry.parent("purchase.pending.title", "Waiting for approval")
    public let pendingBody = HopCopyEntry.parent("purchase.pending.body", "Ask to Buy sent this to your family organiser.")
}

// MARK: - Accessibility

/// VoiceOver labels for surfaces that are mostly illustration.
///
/// These are read aloud, so the child-facing ones are held to the same warmth
/// and length rules as anything a child hears from Hop.
public struct AccessibilityCopy: HopCopySection {
    public static let surface: HopCopySurface = .a11y

    public let hopCharacter = HopCopyEntry.child("a11y.hop", "Hop the frog")
    public let starGlyph = HopCopyEntry.child("a11y.star", "A star")
    public let pondScene = HopNameVariants(
        named: .child(
            "a11y.pond.scene.named",
            "%1$@'s pond, with everything you have collected.",
            placeholders: [.nickname()]
        ),
        unnamed: .child("a11y.pond.scene.unnamed", "Your pond, with everything you have collected.")
    )
    public let routineIllustration = HopCopyEntry.child(
        "a11y.routine.illustration",
        "A picture of this step",
        comment: "Fallback label. Each routine step supplies its own richer label."
    )
    public let quizOptionHint = HopCopyEntry.child("a11y.quiz.optionHint", "Tap a picture to answer")
    public let progressDots = HopCopyEntry.parent(
        "a11y.routine.progressDots",
        "Step %1$lld of %2$lld",
        placeholders: [
            .count(1, "current", "1-based index of the current step.", example: "3"),
            .count(2, "total", "Number of steps.", example: "5"),
        ]
    )
    public let eventGlyphTried = HopCopyEntry.parent("a11y.event.tried", "Tried")
    public let eventGlyphPee = HopCopyEntry.parent("a11y.event.pee", "Pee")
    public let eventGlyphPoop = HopCopyEntry.parent("a11y.event.poop", "Poop")
    public let eventGlyphAccident = HopCopyEntry.parent("a11y.event.accident", "Accident")
}

// MARK: - The catalog

/// Every user-visible string in HopPotty.
///
/// Views hold no string literals (`Docs/CONTRACTS.md` §5). Everything a person
/// can read or hear is declared here or in the content types that feed
/// `allEntries`, which is what makes the child-safety tests exhaustive rather
/// than a spot check.
public enum HopCopy {
    public static let brand = BrandCopy()
    public static let common = CommonCopy()
    public static let onboarding = OnboardingCopy()
    public static let parentHome = ParentHomeCopy()
    public static let timerSettings = TimerSettingsCopy()
    public static let shield = ShieldCopy()
    public static let notification = NotificationCopy()
    public static let routine = RoutineChromeCopy()
    public static let celebration = CelebrationCopy()
    public static let pond = PondCopy()
    public static let games = GamesChromeCopy()
    public static let quizzes = QuizzesChromeCopy()
    public static let settings = SettingsCopy()
    public static let errors = ErrorsCopy()
    public static let parentGate = ParentGateCopy()
    public static let purchase = PurchaseCopy()
    public static let a11y = AccessibilityCopy()

    /// The declared sections, each of which knows its surface. Content types
    /// contribute separately because their strings are generated from structured
    /// content rather than declared one by one.
    public static let sections: [any HopCopySection] = [
        brand, common, onboarding, parentHome, timerSettings, shield, notification,
        routine, celebration, pond, games, quizzes, settings, errors, parentGate,
        purchase, a11y,
    ]

    /// Strings that come from structured content: routine steps, quiz questions,
    /// game descriptions and Hop's shared voice lines.
    public static var contentEntries: [HopCopyEntry] {
        PottyRoutineContent.copyEntries
            + QuizContent.copyEntries
            + MiniGameCatalog.copyEntries
            + HopVoice.shared.entries
    }

    /// The whole catalog. Derived, never hand-listed.
    public static var allEntries: [HopCopyEntry] {
        sections.flatMap(\.entries) + contentEntries
    }

    /// Keyed lookup. Built fresh rather than cached because the catalog is
    /// static data and this is called by tooling, not in a render loop.
    public static func lookup(_ key: String) -> HopCopyEntry? {
        allEntries.first { $0.key == key }
    }

    /// Keys that appear more than once. A duplicate key means one string is
    /// silently shadowing another in the string catalog — the kind of bug that
    /// surfaces as "the translation is right in one screen and wrong in the
    /// other".
    public static var duplicateKeys: [String] {
        var seen: Set<String> = []
        var duplicates: Set<String> = []
        for entry in allEntries {
            if !seen.insert(entry.key).inserted { duplicates.insert(entry.key) }
        }
        return duplicates.sorted()
    }

    public static func entries(for audience: HopCopyAudience) -> [HopCopyEntry] {
        allEntries.filter { $0.audience == audience }
    }

    public static func entries(on surface: HopCopySurface) -> [HopCopyEntry] {
        allEntries.filter { $0.surface == surface }
    }

    /// Sorted by key, which is the order an exported String Catalog uses.
    public static var allEntriesSortedByKey: [HopCopyEntry] {
        allEntries.sorted { $0.key < $1.key }
    }

    /// Every nickname-optional pair in the catalog.
    public static var allNameVariants: [HopNameVariants] {
        sections.flatMap { HopCopyReflection.nameVariants(in: $0) }
    }

    /// Every plural group in the catalog.
    public static var allPluralVariants: [HopPluralVariants] {
        sections.flatMap { HopCopyReflection.pluralVariants(in: $0) }
    }
}
