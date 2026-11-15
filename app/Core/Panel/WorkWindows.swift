import Foundation

public struct WorkWindows: Equatable, Sendable {
    private var count = 0

    public init() {}

    public var isRegular: Bool {
        count > 0
    }

    public mutating func open() {
        count += 1
    }

    public mutating func close() {
        count = max(count - 1, 0)
    }
}
