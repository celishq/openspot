import Foundation

public struct WorkFill: Equatable, Sendable {
    public static let full = WorkFill(base: 1, since: .distantPast)

    public let base: Double
    public let since: Date

    public init(base: Double, since: Date) {
        self.base = min(max(base, 0), 1)
        self.since = since
    }

    public func value(at now: Date) -> Double {
        let ceiling = base + (1 - base) * MotionTokens.workCeiling
        let time = max(now.timeIntervalSince(since), 0)
        return base + (ceiling - base) * (1 - exp(-time / MotionTokens.workCreep))
    }

    public func taking(_ reported: Double, at now: Date) -> WorkFill {
        WorkFill(base: max(reported, value(at: now)), since: now)
    }
}
