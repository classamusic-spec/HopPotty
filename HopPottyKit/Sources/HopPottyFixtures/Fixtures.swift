import Foundation
import HopPottyCore

/// Deterministic sample data for previews, tests and the debug lab.
///
/// Everything here is seeded from fixed values so a preview looks the same on
/// every run and a failing test is reproducible. Fixtures live in a separate
/// module that the shipping app target does not link, so sample children can
/// never appear in a real family's data.
public enum HopFixtures {
    /// A fixed instant used as "now" throughout the fixtures:
    /// 2026-03-10 09:00:00 UTC, a Tuesday.
    public static let referenceDate = Date(timeIntervalSince1970: 1_773_133_200)

    /// Stable IDs so fixtures across files refer to the same child.
    public static let samChildID = UUID(uuidString: "5A11D000-0000-4000-8000-000000000001")!
    public static let mayaChildID = UUID(uuidString: "5A11D000-0000-4000-8000-000000000002")!

    public static var sam: ChildProfile {
        ChildProfile(
            id: samChildID,
            nickname: "Sam",
            avatar: .frogGreen,
            pondTheme: .meadowPond,
            createdAt: referenceDate.addingTimeInterval(-14 * 86_400),
            modifiedAt: referenceDate
        )
    }

    public static var maya: ChildProfile {
        ChildProfile(
            id: mayaChildID,
            nickname: "Maya",
            avatar: .frogLavender,
            pondTheme: .meadowPond,
            createdAt: referenceDate.addingTimeInterval(-40 * 86_400),
            modifiedAt: referenceDate
        )
    }

    /// A child with no nickname, to exercise the neutral-phrasing paths.
    public static var unnamedChild: ChildProfile {
        ChildProfile(id: UUID(uuidString: "5A11D000-0000-4000-8000-000000000003")!)
    }
}
