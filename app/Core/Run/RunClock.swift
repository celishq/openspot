import Foundation

public struct RunClock: Sendable {
    public let now: @Sendable () -> Date
    public let sleep: @MainActor @Sendable (Duration, Duration?) async throws -> Void
    public let after: @Sendable (TimeInterval, @escaping @Sendable () -> Void) -> Void

    public init(
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @MainActor @Sendable (Duration, Duration?) async throws -> Void = { try await Task.sleep(for: $0, tolerance: $1) },
        after: @escaping @Sendable (TimeInterval, @escaping @Sendable () -> Void) -> Void = { DispatchQueue.global().asyncAfter(deadline: .now() + max(0, $0), execute: $1) }
    ) {
        self.now = now
        self.sleep = sleep
        self.after = after
    }
}
