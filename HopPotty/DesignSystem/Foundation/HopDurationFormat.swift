import Foundation

/// Duration formatting for the two places HopPotty shows time passing.
///
/// Split in two on purpose. The glanceable form is what a caregiver reads
/// across a room; the spoken form is what VoiceOver says. `04:05` is correct on
/// screen and useless read aloud — "four zero five" — so the two never share a
/// string.
public enum HopDurationFormat {
    /// `MM:SS` under an hour, `H:MM:SS` above it. Always zero-padded so the
    /// field width never changes as the number ticks down.
    public static func glanceable(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// A coarser form for a card that is not counting seconds: "45 min", "1 hr
    /// 20 min".
    public static func approximate(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval.rounded()))
        let hours = total / 3600
        let minutes = max(total < 60 ? 0 : 1, (total % 3600) / 60)
        if hours > 0 && minutes > 0 { return "\(hours) hr \(minutes) min" }
        if hours > 0 { return "\(hours) hr" }
        if minutes > 0 { return "\(minutes) min" }
        return "under a minute"
    }

    /// The spoken form, for `accessibilityValue`.
    public static func spoken(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) \(hours == 1 ? "hour" : "hours")") }
        if minutes > 0 { parts.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")") }
        // Seconds are dropped once there are hours: nobody needs "2 hours,
        // 14 minutes and 3 seconds" read to them.
        if seconds > 0 && hours == 0 { parts.append("\(seconds) \(seconds == 1 ? "second" : "seconds")") }
        guard !parts.isEmpty else { return "no time left" }
        return parts.joined(separator: " ")
    }
}
