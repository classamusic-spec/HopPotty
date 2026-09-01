import Foundation
import HopPottyCore

// MARK: - Target membership
//
// SHARED BY THE APP AND THE DEVICE ACTIVITY MONITOR EXTENSION.
// The two shield extensions do not need it and must not link it.

/// The minimum a `DeviceActivityMonitor` extension needs in order to *decline* to
/// start a pause, and to start one correctly when it does.
///
/// ## Why this exists at all
///
/// The monitor extension is woken by the system with a `DeviceActivityName` and
/// nothing else. It has no `ModelContainer`, no `PottySchedule`, and no way to
/// ask the app anything — the app is usually not running, which is the entire
/// point of the extension. But it is the process that must raise a shield when a
/// usage threshold is crossed, and raising a shield requires knowing how long the
/// pause lasts and whether a pause is allowed right now at all.
///
/// Without this payload the extension would either shield for a hard-coded
/// duration it invented, or interrupt a child during a nap. Both are worse than
/// putting four pieces of configuration across the boundary.
///
/// ## Why this does not violate the boundary rule
///
/// It is configuration, not identity. There is no child identifier here, no
/// nickname, no age, no notes, no event history, no reward state, and no free
/// text — the same prohibitions that govern `SharedPauseTypes`. A reader of this
/// file learns that *somebody* on this device does not want to be interrupted
/// between 12:30 and 14:00. They learn nothing about who.
///
/// This does go beyond the five values a minimal boundary would carry, and that
/// is a deliberate, narrow exception, listed here so it cannot expand quietly:
/// **pause duration, active days, quiet ranges, cooldown.** Anything else that
/// wants to cross should be questioned as hard as this was.
///
/// ## Writer discipline
///
/// Written only by the app, whenever the schedule changes and on every foreground.
/// Read only by the monitor extension. Single writer, so no race.
public struct MonitoringGate: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int

    /// How long a pause the extension should open. Already clamped to the
    /// product's bounds by the app; clamped again on use, because this value
    /// becomes system state and a corrupted file must not be able to write an
    /// hour-long shield.
    public let pauseDurationSeconds: TimeInterval

    /// `Weekday.rawValue`s the schedule is active on. Empty means every day.
    public let activeDayNumbers: [Int]

    /// Minutes-since-midnight ranges during which no pause may start. Stored as
    /// wall-clock minutes rather than instants for the same reason `QuietWindow`
    /// does: "naps start at 12:30" means 12:30 in whatever zone the family is in
    /// today, and an absolute instant would shift by an hour every DST boundary.
    public let quietRanges: [QuietRange]

    /// The earliest and latest wall-clock minute at which a pause may occur.
    public let activeWindowStartMinutes: Int
    public let activeWindowEndMinutes: Int

    /// The quiet period after a pause. Enforced against `cooldown.json`.
    public let cooldownSeconds: TimeInterval

    public struct QuietRange: Codable, Equatable, Sendable {
        public let startMinutes: Int
        public let endMinutes: Int

        public init(startMinutes: Int, endMinutes: Int) {
            self.startMinutes = startMinutes
            self.endMinutes = endMinutes
        }

        /// Half-open, and midnight-wrapping, exactly like `QuietWindow.contains`.
        /// The two implementations must agree; `Docs/PhysicalDeviceQA.md` has a
        /// check that a nap window suppresses a pause on-device.
        public func contains(minutes: Int) -> Bool {
            if endMinutes <= startMinutes {
                return minutes >= startMinutes || minutes < endMinutes
            }
            return minutes >= startMinutes && minutes < endMinutes
        }
    }

    public init(
        schemaVersion: Int = MonitoringGate.currentSchemaVersion,
        pauseDurationSeconds: TimeInterval,
        activeDayNumbers: [Int],
        quietRanges: [QuietRange],
        activeWindowStartMinutes: Int,
        activeWindowEndMinutes: Int,
        cooldownSeconds: TimeInterval
    ) {
        self.schemaVersion = schemaVersion
        self.pauseDurationSeconds = pauseDurationSeconds
        self.activeDayNumbers = activeDayNumbers
        self.quietRanges = quietRanges
        self.activeWindowStartMinutes = activeWindowStartMinutes
        self.activeWindowEndMinutes = activeWindowEndMinutes
        self.cooldownSeconds = cooldownSeconds
    }

    public init(schedule: PottySchedule) {
        self.init(
            pauseDurationSeconds: min(
                max(schedule.pauseDuration, PottySchedule.minimumPauseDuration),
                PottySchedule.maximumPauseDuration
            ),
            activeDayNumbers: schedule.activeDays.map(\.rawValue).sorted(),
            quietRanges: schedule.quietWindows
                .filter(\.isEnabled)
                .map {
                    QuietRange(
                        startMinutes: $0.start.minutesSinceMidnight,
                        endMinutes: $0.end.minutesSinceMidnight
                    )
                },
            activeWindowStartMinutes: schedule.activeWindowStart.minutesSinceMidnight,
            activeWindowEndMinutes: schedule.activeWindowEnd.minutesSinceMidnight,
            cooldownSeconds: max(0, schedule.cooldown)
        )
    }

    /// The clamped duration to actually use.
    public var safePauseDuration: TimeInterval {
        min(
            max(pauseDurationSeconds, PottySchedule.minimumPauseDuration),
            PottySchedule.maximumPauseDuration
        )
    }

    /// Whether a pause may start at this instant.
    ///
    /// The extension calls this and nothing else. Note the direction it fails in:
    /// a gate that cannot be read at all means **no pause**, not a pause with
    /// invented settings. A missed pause is a reminder that did not happen; an
    /// invented pause is a shield of unknown duration on a child's device.
    public func permitsPause(at instant: Date, calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: instant)
        guard let hour = components.hour, let minute = components.minute else { return false }
        let minutes = hour * 60 + minute

        if !activeDayNumbers.isEmpty, let weekday = components.weekday,
           !activeDayNumbers.contains(weekday) {
            return false
        }

        let inWindow: Bool = activeWindowEndMinutes > activeWindowStartMinutes
            ? (minutes >= activeWindowStartMinutes && minutes < activeWindowEndMinutes)
            : (minutes >= activeWindowStartMinutes || minutes < activeWindowEndMinutes)
        guard inWindow else { return false }

        return !quietRanges.contains { $0.contains(minutes: minutes) }
    }
}

// MARK: - Container access

public extension AppGroupStore {

    private static var gateFile: String { "gate.json" }
    private static var cooldownFile: String { "cooldown.json" }

    /// One `Date` in a file. Written by whichever process ends a pause; read by
    /// the monitor before starting one.
    ///
    /// Multi-writer and last-write-wins, which is safe because the value is
    /// advisory: a stale cooldown at worst allows one pause that should have been
    /// suppressed, or suppresses one that could have run. Neither can strand a
    /// shield, which is the only class of error this layer treats as serious.
    struct CooldownRecord: Codable, Equatable, Sendable {
        public let until: Date
        public init(until: Date) { self.until = until }
    }

    func loadGate() -> MonitoringGate? {
        guard let root, let data = try? Data(contentsOf: root.appendingPathComponent(Self.gateFile)) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let gate = try? decoder.decode(MonitoringGate.self, from: data) else { return nil }
        return gate.schemaVersion == MonitoringGate.currentSchemaVersion ? gate : nil
    }

    @discardableResult
    func saveGate(_ gate: MonitoringGate) -> Bool {
        guard let root else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(gate) else { return false }
        return (try? data.write(to: root.appendingPathComponent(Self.gateFile), options: .atomic)) != nil
    }

    func clearGate() {
        guard let root else { return }
        try? FileManager.default.removeItem(at: root.appendingPathComponent(Self.gateFile))
    }

    func cooldownUntil() -> Date? {
        guard let root, let data = try? Data(contentsOf: root.appendingPathComponent(Self.cooldownFile)) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(CooldownRecord.self, from: data))?.until
    }

    func setCooldown(until instant: Date) {
        guard let root else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(CooldownRecord(until: instant)) else { return }
        try? data.write(to: root.appendingPathComponent(Self.cooldownFile), options: .atomic)
    }

    func clearCooldown() {
        guard let root else { return }
        try? FileManager.default.removeItem(at: root.appendingPathComponent(Self.cooldownFile))
    }

    /// Whether the post-pause quiet period has elapsed.
    ///
    /// A cooldown recorded in the future by more than the longest cooldown the
    /// product allows is treated as expired, because that can only come from a
    /// clock that moved. Erring toward "allowed" here is the safe direction: the
    /// cost is one extra reminder, and reminders do not shield.
    func isCooldownElapsed(at instant: Date, limit: TimeInterval) -> Bool {
        guard let until = cooldownUntil() else { return true }
        if until.timeIntervalSince(instant) > max(limit, 60) { return true }
        return instant >= until
    }
}
