import Foundation

/// Which set of dependencies this build gets.
///
/// Chosen by **compile-time configuration**, not a runtime flag or a launch
/// argument. A runtime switch that can select mock services is a switch that can
/// be flipped in a shipping build — by a debug menu someone forgot to remove, by
/// a URL scheme, or by a bug. In a product that shields a child's apps and takes
/// a payment, "the release binary physically does not contain the mock store" is
/// worth more than the convenience of toggling it at runtime.
///
/// Set `HOPPOTTY_MOCKS` in *Other Swift Flags* (`-DHOPPOTTY_MOCKS`) on the Debug
/// and Preview build configurations only.
enum AppBuildConfiguration: String, Sendable {
    /// Real SwiftData store, real notifications, real StoreKit.
    case live
    /// Everything in memory, seeded with fixtures. Previews and unit tests.
    case mock

    static let current: AppBuildConfiguration = {
        #if HOPPOTTY_MOCKS
        return .mock
        #else
        return .live
        #endif
    }()

    /// True inside an Xcode Preview process, which needs in-memory services even
    /// in a build configuration that would otherwise be `.live`.
    ///
    /// This is the one runtime check that is justified: the preview process sets
    /// this variable itself, no shipping process ever has it, and previews must
    /// never touch the real store or the sandbox StoreKit account.
    static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// True in a unit or UI test host.
    static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    /// The configuration to actually build the environment with.
    static var resolved: AppBuildConfiguration {
        if isRunningInPreview || isRunningTests { return .mock }
        return current
    }
}

// MARK: - Clock

/// The single source of "what time is it".
///
/// Every date-sensitive decision in HopPotty — quiet windows, cooldowns, the
/// daily summary, reward idempotency keys — is a pure function of an explicit
/// `now` in `HopPottyCore`. This protocol is how the *app layer* supplies that
/// `now` without any service calling `Date()` behind a test's back.
protocol HopClock: Sendable {
    var now: Date { get }
    /// The calendar all wall-clock reasoning uses. Injectable because a test that
    /// depends on the machine's time zone is a test that fails in November.
    var calendar: Calendar { get }
}

struct SystemClock: HopClock {
    var now: Date { Date() }
    var calendar: Calendar { Calendar.current }
}

/// A clock a test or preview can pin.
final class FixedClock: HopClock, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date
    let calendar: Calendar

    init(now: Date, calendar: Calendar = Calendar(identifier: .gregorian)) {
        self._now = now
        self.calendar = calendar
    }

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return _now
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        _now += interval
        lock.unlock()
    }

    func set(_ date: Date) {
        lock.lock()
        _now = date
        lock.unlock()
    }
}

// MARK: - Parent authorization

/// Proof that a parent gate challenge was passed.
///
/// Destructive actions, the purchase surface and the export sheet all take one
/// of these rather than a `Bool`. A `Bool` parameter named `parentApproved` can
/// be passed `true` by any caller that finds it convenient; a value that has to
/// be *obtained* makes the omission visible at the call site instead.
///
/// **Honest limitation.** HopPotty is one module, so `private init` is a speed
/// bump rather than a wall — any file in the target can call `mint`. What it
/// buys is: a single grep-able mint point, a log line for every mint, and a
/// signature that documents the requirement. The real enforcement is the parent
/// gate UI and the contract test that asserts destructive repository methods
/// take a `ParentAuthorization`.
struct ParentAuthorization: Sendable {
    /// Why the gate was raised. Logged; never contains user text.
    let reason: Reason
    let grantedAt: Date

    enum Reason: String, Sendable, CaseIterable {
        case openParentArea
        case changeSchedule
        case deleteData
        case exportData
        case purchase
        case restorePurchase
    }

    private init(reason: Reason, grantedAt: Date) {
        self.reason = reason
        self.grantedAt = grantedAt
    }

    /// Call **only** from the parent gate, after the challenge succeeded.
    static func mint(reason: Reason, at date: Date = Date()) -> ParentAuthorization {
        HopLog.authorization.info("parent gate passed reason=\(reason.rawValue, privacy: .public)")
        return ParentAuthorization(reason: reason, grantedAt: date)
    }

    /// Authorization goes stale so a gate passed at breakfast cannot be used to
    /// wipe the app at dinner.
    static let validity: TimeInterval = 15 * 60

    func isValid(at now: Date) -> Bool {
        now >= grantedAt && now.timeIntervalSince(grantedAt) <= Self.validity
    }
}
