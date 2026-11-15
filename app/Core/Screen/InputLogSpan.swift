import Foundation

public struct InputLogSpan: Sendable {
    public static let byteLimit = 64 << 20

    private let limit: Int
    private var zero: TimeInterval?
    private var written = 0

    public init(limit: Int = byteLimit) {
        self.limit = limit
    }

    public mutating func begin(at time: TimeInterval) {
        if zero == nil { zero = time }
    }

    public func seconds(at time: TimeInterval) -> TimeInterval? {
        guard let zero, time >= zero else { return nil }
        return time - zero
    }

    public mutating func admits(_ bytes: Int) -> Bool {
        guard written + bytes <= limit else { return false }
        written += bytes
        return true
    }
}
