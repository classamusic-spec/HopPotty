import Foundation
import HopPottyCore
import SwiftData

// The `@Model` classes are a *persistence detail*. Nothing outside this folder
// ever sees one: every repository takes and returns the `HopPottyCore` value
// type, and the mapping lives on the model itself so there is exactly one place
// per record where the two shapes have to agree.
//
// The naming is deliberate. `StoredChildProfile` reads as "the stored form of a
// ChildProfile", which makes an accidental `import SwiftData` in a feature file
// obvious in review: a view that mentions `Stored…` is a view reaching past its
// layer.

// MARK: - Child profile

@Model
final class StoredChildProfile {
    @Attribute(.unique) var id: UUID
    /// The child's name, and the only piece of identity HopPotty holds. Never
    /// logged, never in an unsanitised export, never sent anywhere.
    var nickname: String?
    var avatarRaw: String
    var pondThemeRaw: String
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID,
        nickname: String?,
        avatarRaw: String,
        pondThemeRaw: String,
        createdAt: Date,
        modifiedAt: Date
    ) {
        self.id = id
        self.nickname = nickname
        self.avatarRaw = avatarRaw
        self.pondThemeRaw = pondThemeRaw
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    convenience init(_ profile: ChildProfile) {
        self.init(
            id: profile.id,
            nickname: profile.nickname,
            avatarRaw: profile.avatar.rawValue,
            pondThemeRaw: profile.pondTheme.rawValue,
            createdAt: profile.createdAt,
            modifiedAt: profile.modifiedAt
        )
    }

    /// Updates in place. `id` and `createdAt` are never rewritten — a save that
    /// changed a row's identity would orphan every event pointing at it.
    func apply(_ profile: ChildProfile) {
        nickname = ChildProfile.sanitize(profile.nickname)
        avatarRaw = profile.avatar.rawValue
        pondThemeRaw = profile.pondTheme.rawValue
        modifiedAt = profile.modifiedAt
    }

    var domainValue: ChildProfile {
        ChildProfile(
            id: id,
            nickname: nickname,
            avatar: HopStoredCoding.decodeEnum(
                HopAvatarStyle.self, raw: avatarRaw, fallback: .frogGreen, label: "avatar"
            ),
            pondTheme: HopStoredCoding.decodeEnum(
                PondTheme.self, raw: pondThemeRaw, fallback: .meadowPond, label: "pondTheme"
            ),
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }
}

// MARK: - App settings

/// Device-wide settings, stored as a single row.
///
/// A singleton table rather than `UserDefaults` because settings and family data
/// must be deleted together by "Reset app" and exported together by the export,
/// and a two-store split guarantees that one day only one of them gets wiped.
@Model
final class StoredAppSettings {
    /// Fixed primary key. There is exactly one settings row; `.unique` makes a
    /// second one impossible rather than merely unlikely.
    @Attribute(.unique) var id: String
    var hopVoiceEnabled: Bool
    var soundEffectsEnabled: Bool
    var ambientAudioEnabled: Bool
    var hapticsEnabled: Bool
    var spokenTextCaptionsEnabled: Bool
    var warningNotificationsEnabled: Bool
    var dailySummaryEnabled: Bool
    /// Minutes since midnight. A wall-clock time, never an absolute date — see
    /// `LocalTimeOfDay` for why that distinction matters across a DST boundary.
    var dailySummaryMinutes: Int
    var miniGamesEnabled: Bool
    var quizzesEnabled: Bool
    var routineSitTimerEnabled: Bool
    var routineSitTimerDuration: Double
    var parentGateStyleRaw: String
    var activeChildID: UUID?
    var hasCompletedOnboarding: Bool
    var lastSeenReleaseVersion: String?

    static let singletonID = "hop.settings"

    init(
        id: String = StoredAppSettings.singletonID,
        hopVoiceEnabled: Bool,
        soundEffectsEnabled: Bool,
        ambientAudioEnabled: Bool,
        hapticsEnabled: Bool,
        spokenTextCaptionsEnabled: Bool,
        warningNotificationsEnabled: Bool,
        dailySummaryEnabled: Bool,
        dailySummaryMinutes: Int,
        miniGamesEnabled: Bool,
        quizzesEnabled: Bool,
        routineSitTimerEnabled: Bool,
        routineSitTimerDuration: Double,
        parentGateStyleRaw: String,
        activeChildID: UUID?,
        hasCompletedOnboarding: Bool,
        lastSeenReleaseVersion: String?
    ) {
        self.id = id
        self.hopVoiceEnabled = hopVoiceEnabled
        self.soundEffectsEnabled = soundEffectsEnabled
        self.ambientAudioEnabled = ambientAudioEnabled
        self.hapticsEnabled = hapticsEnabled
        self.spokenTextCaptionsEnabled = spokenTextCaptionsEnabled
        self.warningNotificationsEnabled = warningNotificationsEnabled
        self.dailySummaryEnabled = dailySummaryEnabled
        self.dailySummaryMinutes = dailySummaryMinutes
        self.miniGamesEnabled = miniGamesEnabled
        self.quizzesEnabled = quizzesEnabled
        self.routineSitTimerEnabled = routineSitTimerEnabled
        self.routineSitTimerDuration = routineSitTimerDuration
        self.parentGateStyleRaw = parentGateStyleRaw
        self.activeChildID = activeChildID
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.lastSeenReleaseVersion = lastSeenReleaseVersion
    }

    convenience init(_ settings: AppSettings) {
        self.init(
            hopVoiceEnabled: settings.hopVoiceEnabled,
            soundEffectsEnabled: settings.soundEffectsEnabled,
            ambientAudioEnabled: settings.ambientAudioEnabled,
            hapticsEnabled: settings.hapticsEnabled,
            spokenTextCaptionsEnabled: settings.spokenTextCaptionsEnabled,
            warningNotificationsEnabled: settings.warningNotificationsEnabled,
            dailySummaryEnabled: settings.dailySummaryEnabled,
            dailySummaryMinutes: settings.dailySummaryTime.minutesSinceMidnight,
            miniGamesEnabled: settings.miniGamesEnabled,
            quizzesEnabled: settings.quizzesEnabled,
            routineSitTimerEnabled: settings.routineSitTimerEnabled,
            routineSitTimerDuration: settings.routineSitTimerDuration,
            parentGateStyleRaw: settings.parentGateStyle.rawValue,
            activeChildID: settings.activeChildID,
            hasCompletedOnboarding: settings.hasCompletedOnboarding,
            lastSeenReleaseVersion: settings.lastSeenReleaseVersion
        )
    }

    func apply(_ settings: AppSettings) {
        hopVoiceEnabled = settings.hopVoiceEnabled
        soundEffectsEnabled = settings.soundEffectsEnabled
        ambientAudioEnabled = settings.ambientAudioEnabled
        hapticsEnabled = settings.hapticsEnabled
        spokenTextCaptionsEnabled = settings.spokenTextCaptionsEnabled
        warningNotificationsEnabled = settings.warningNotificationsEnabled
        dailySummaryEnabled = settings.dailySummaryEnabled
        dailySummaryMinutes = settings.dailySummaryTime.minutesSinceMidnight
        miniGamesEnabled = settings.miniGamesEnabled
        quizzesEnabled = settings.quizzesEnabled
        routineSitTimerEnabled = settings.routineSitTimerEnabled
        routineSitTimerDuration = settings.routineSitTimerDuration
        parentGateStyleRaw = settings.parentGateStyle.rawValue
        activeChildID = settings.activeChildID
        hasCompletedOnboarding = settings.hasCompletedOnboarding
        lastSeenReleaseVersion = settings.lastSeenReleaseVersion
    }

    var domainValue: AppSettings {
        AppSettings(
            hopVoiceEnabled: hopVoiceEnabled,
            soundEffectsEnabled: soundEffectsEnabled,
            ambientAudioEnabled: ambientAudioEnabled,
            hapticsEnabled: hapticsEnabled,
            spokenTextCaptionsEnabled: spokenTextCaptionsEnabled,
            warningNotificationsEnabled: warningNotificationsEnabled,
            dailySummaryEnabled: dailySummaryEnabled,
            dailySummaryTime: LocalTimeOfDay(minutesSinceMidnight: dailySummaryMinutes),
            miniGamesEnabled: miniGamesEnabled,
            quizzesEnabled: quizzesEnabled,
            routineSitTimerEnabled: routineSitTimerEnabled,
            routineSitTimerDuration: routineSitTimerDuration,
            parentGateStyle: HopStoredCoding.decodeEnum(
                ParentGateStyle.self,
                raw: parentGateStyleRaw,
                fallback: .holdAndArithmetic,
                label: "parentGateStyle"
            ),
            activeChildID: activeChildID,
            hasCompletedOnboarding: hasCompletedOnboarding,
            lastSeenReleaseVersion: lastSeenReleaseVersion
        )
    }
}

// MARK: - Schedule

@Model
final class StoredPottySchedule {
    @Attribute(.unique) var id: UUID
    /// Foreign key, not a relationship. See `HopMigrationPlan` rule 5.
    var childID: UUID
    var modeRaw: String
    var triggerBasisRaw: String
    /// Minutes rather than the `PottyInterval` enum: `PottyInterval(minutes:)`
    /// round-trips presets and custom values through the same integer, so a new
    /// preset is never a schema change.
    var intervalMinutes: Int
    var warningOffset: Double
    var pauseDuration: Double
    var cooldown: Double
    /// `[QuietWindow]` as JSON. A separate table would buy a query nobody makes
    /// — quiet windows are always read as a whole set for one schedule.
    var quietWindowsData: Data
    /// `Weekday` raw values. Stored sorted so the column is stable for equal sets.
    var activeDayValues: [Int]
    var activeWindowStartMinutes: Int
    var activeWindowEndMinutes: Int
    var isEnabled: Bool
    /// `ScheduleSuspension` as JSON — it is an enum with associated values, so
    /// there is no faithful column form.
    var suspensionData: Data
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID,
        childID: UUID,
        modeRaw: String,
        triggerBasisRaw: String,
        intervalMinutes: Int,
        warningOffset: Double,
        pauseDuration: Double,
        cooldown: Double,
        quietWindowsData: Data,
        activeDayValues: [Int],
        activeWindowStartMinutes: Int,
        activeWindowEndMinutes: Int,
        isEnabled: Bool,
        suspensionData: Data,
        createdAt: Date,
        modifiedAt: Date
    ) {
        self.id = id
        self.childID = childID
        self.modeRaw = modeRaw
        self.triggerBasisRaw = triggerBasisRaw
        self.intervalMinutes = intervalMinutes
        self.warningOffset = warningOffset
        self.pauseDuration = pauseDuration
        self.cooldown = cooldown
        self.quietWindowsData = quietWindowsData
        self.activeDayValues = activeDayValues
        self.activeWindowStartMinutes = activeWindowStartMinutes
        self.activeWindowEndMinutes = activeWindowEndMinutes
        self.isEnabled = isEnabled
        self.suspensionData = suspensionData
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    convenience init(_ schedule: PottySchedule) {
        self.init(
            id: schedule.id,
            childID: schedule.childID,
            modeRaw: schedule.mode.rawValue,
            triggerBasisRaw: schedule.triggerBasis.rawValue,
            intervalMinutes: schedule.interval.minutes,
            warningOffset: schedule.warningOffset,
            pauseDuration: schedule.pauseDuration,
            cooldown: schedule.cooldown,
            quietWindowsData: HopStoredCoding.encode(schedule.quietWindows, label: "quietWindows"),
            activeDayValues: schedule.activeDays.map(\.rawValue).sorted(),
            activeWindowStartMinutes: schedule.activeWindowStart.minutesSinceMidnight,
            activeWindowEndMinutes: schedule.activeWindowEnd.minutesSinceMidnight,
            isEnabled: schedule.isEnabled,
            suspensionData: HopStoredCoding.encode(schedule.suspension, label: "suspension"),
            createdAt: schedule.createdAt,
            modifiedAt: schedule.modifiedAt
        )
    }

    func apply(_ schedule: PottySchedule) {
        modeRaw = schedule.mode.rawValue
        triggerBasisRaw = schedule.triggerBasis.rawValue
        intervalMinutes = schedule.interval.minutes
        warningOffset = schedule.warningOffset
        pauseDuration = schedule.pauseDuration
        cooldown = schedule.cooldown
        quietWindowsData = HopStoredCoding.encode(schedule.quietWindows, label: "quietWindows")
        activeDayValues = schedule.activeDays.map(\.rawValue).sorted()
        activeWindowStartMinutes = schedule.activeWindowStart.minutesSinceMidnight
        activeWindowEndMinutes = schedule.activeWindowEnd.minutesSinceMidnight
        isEnabled = schedule.isEnabled
        suspensionData = HopStoredCoding.encode(schedule.suspension, label: "suspension")
        modifiedAt = schedule.modifiedAt
    }

    var domainValue: PottySchedule {
        PottySchedule(
            id: id,
            childID: childID,
            // `.gentle` is the fallback for an unreadable mode on purpose: it is
            // the only mode that never shields anything. If HopPotty cannot tell
            // what a caregiver configured, it must not guess in the direction of
            // taking a child's apps away.
            mode: HopStoredCoding.decodeEnum(
                PottyPauseMode.self, raw: modeRaw, fallback: .gentle, label: "mode"
            ),
            triggerBasis: HopStoredCoding.decodeEnum(
                PottyTriggerBasis.self, raw: triggerBasisRaw, fallback: .clockTime, label: "triggerBasis"
            ),
            interval: PottyInterval(minutes: intervalMinutes),
            warningOffset: warningOffset,
            pauseDuration: pauseDuration,
            cooldown: cooldown,
            quietWindows: HopStoredCoding.decode(
                [QuietWindow].self, from: quietWindowsData, fallback: [], label: "quietWindows"
            ),
            activeDays: Set(activeDayValues.compactMap(Weekday.init(rawValue:))),
            activeWindowStart: LocalTimeOfDay(minutesSinceMidnight: activeWindowStartMinutes),
            activeWindowEnd: LocalTimeOfDay(minutesSinceMidnight: activeWindowEndMinutes),
            isEnabled: isEnabled,
            suspension: HopStoredCoding.decode(
                ScheduleSuspension.self, from: suspensionData, fallback: .none, label: "suspension"
            ),
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }
}

// MARK: - Screen Time configuration

@Model
final class StoredScreenTimeConfiguration {
    /// One configuration per child, so the child id *is* the key.
    @Attribute(.unique) var childID: UUID
    var selectedApplicationCount: Int
    var selectedCategoryCount: Int
    var selectedWebDomainCount: Int
    var authorizationStatusRaw: String
    var lastMonitoringRegistration: Date?
    var lastRegistrationFailureRaw: String?

    init(
        childID: UUID,
        selectedApplicationCount: Int,
        selectedCategoryCount: Int,
        selectedWebDomainCount: Int,
        authorizationStatusRaw: String,
        lastMonitoringRegistration: Date?,
        lastRegistrationFailureRaw: String?
    ) {
        self.childID = childID
        self.selectedApplicationCount = selectedApplicationCount
        self.selectedCategoryCount = selectedCategoryCount
        self.selectedWebDomainCount = selectedWebDomainCount
        self.authorizationStatusRaw = authorizationStatusRaw
        self.lastMonitoringRegistration = lastMonitoringRegistration
        self.lastRegistrationFailureRaw = lastRegistrationFailureRaw
    }

    convenience init(_ configuration: ScreenTimeConfiguration) {
        self.init(
            childID: configuration.childID,
            selectedApplicationCount: configuration.selectedApplicationCount,
            selectedCategoryCount: configuration.selectedCategoryCount,
            selectedWebDomainCount: configuration.selectedWebDomainCount,
            authorizationStatusRaw: configuration.authorizationStatus.rawValue,
            lastMonitoringRegistration: configuration.lastMonitoringRegistration,
            lastRegistrationFailureRaw: configuration.lastRegistrationFailure?.rawValue
        )
    }

    func apply(_ configuration: ScreenTimeConfiguration) {
        selectedApplicationCount = configuration.selectedApplicationCount
        selectedCategoryCount = configuration.selectedCategoryCount
        selectedWebDomainCount = configuration.selectedWebDomainCount
        authorizationStatusRaw = configuration.authorizationStatus.rawValue
        lastMonitoringRegistration = configuration.lastMonitoringRegistration
        lastRegistrationFailureRaw = configuration.lastRegistrationFailure?.rawValue
    }

    var domainValue: ScreenTimeConfiguration {
        ScreenTimeConfiguration(
            childID: childID,
            selectedApplicationCount: selectedApplicationCount,
            selectedCategoryCount: selectedCategoryCount,
            selectedWebDomainCount: selectedWebDomainCount,
            // `.notDetermined` is the safe fallback: it makes the app ask again
            // rather than assume it may shield.
            authorizationStatus: HopStoredCoding.decodeEnum(
                ScreenTimeAuthorizationStatus.self,
                raw: authorizationStatusRaw,
                fallback: .notDetermined,
                label: "authorizationStatus"
            ),
            lastMonitoringRegistration: lastMonitoringRegistration,
            lastRegistrationFailure: lastRegistrationFailureRaw.map {
                HopStoredCoding.decodeEnum(
                    ScreenTimeFailure.self, raw: $0, fallback: .unknown, label: "registrationFailure"
                )
            }
        )
    }
}

// MARK: - Deliberately absent: the pause session
//
// `PersistedPauseSession` has no `@Model` here, and must not get one.
//
// A running pause is cross-process state: the app, the DeviceActivity monitor
// extension and the shield-action extension all need to read and write it, and
// two of those three cannot open a SwiftData store at all. It therefore lives
// in the App Group record (`Services/ScreenTime/AppGroupStore.swift`), which is
// the single source of truth for "is a shield up right now".
//
// Mirroring it into SwiftData would create a second answer to that question,
// held by the one process that is *least* likely to be running when it matters.
// The failure mode is not a stale row — it is a child locked out of their apps
// because two stores disagreed about whether a pause had ended.
