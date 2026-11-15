import Foundation

public struct RunClock {
    public let now: () -> Date
    public let sleep: @MainActor (Duration, Duration?) async throws -> Void

    public init(
        now: @escaping () -> Date = { Date() },
        sleep: @escaping @MainActor (Duration, Duration?) async throws -> Void = { try await Task.sleep(for: $0, tolerance: $1) }
    ) {
        self.now = now
        self.sleep = sleep
    }
}
