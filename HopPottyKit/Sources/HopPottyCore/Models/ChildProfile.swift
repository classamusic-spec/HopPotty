import Foundation

/// A child using HopPotty.
///
/// Deliberately thin. HopPotty asks for a nickname and nothing else: no legal
/// name, no birthday, no photo. Age-appropriate defaults come from the chosen
/// routine, not from personal data. See `Docs/PrivacyArchitecture.md`.
public struct ChildProfile: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    /// What Hop calls this child. Optional — a family can use HopPotty without
    /// naming anyone, and the UI falls back to a neutral phrasing.
    public var nickname: String?
    /// Index into the built-in avatar set. No uploaded photographs.
    public var avatar: HopAvatarStyle
    /// Pond theme this child is exploring.
    public var pondTheme: PondTheme
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        nickname: String? = nil,
        avatar: HopAvatarStyle = .frogGreen,
        pondTheme: PondTheme = .meadowPond,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.nickname = ChildProfile.sanitize(nickname)
        self.avatar = avatar
        self.pondTheme = pondTheme
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// The longest nickname the layouts are designed to hold without truncating.
    public static let maxNicknameLength = 24

    /// Trims whitespace, collapses empty strings to `nil`, and caps length.
    ///
    /// Capping here rather than in the text field means every entry point —
    /// onboarding, settings, an import — gets the same guarantee.
    public static func sanitize(_ nickname: String?) -> String? {
        guard let nickname else { return nil }
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxNicknameLength))
    }

    /// Whether this profile carries a nickname, used to pick between
    /// "Maya's pond" and "Your pond" phrasings.
    public var hasNickname: Bool { nickname != nil }
}

/// The built-in avatar set. Illustrated, never photographic.
public enum HopAvatarStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case frogGreen, frogBlue, frogSunshine, frogPeach, frogLavender
    case tadpole, turtle, duckling

    public var id: String { rawValue }
}

/// Visual worlds a child's pond can use. One ships at launch; the enum exists so
/// added worlds do not require a data migration.
public enum PondTheme: String, Codable, CaseIterable, Sendable, Identifiable {
    case meadowPond, sunsetPond, snowyPond

    public var id: String { rawValue }

    /// Whether this theme is available in the shipping build.
    public var isAvailableAtLaunch: Bool { self == .meadowPond }
}
