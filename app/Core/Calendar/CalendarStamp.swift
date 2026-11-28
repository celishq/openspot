import Foundation

public struct CalendarStamp: Equatable, Sendable {
    public let count: Int
    public let latest: Date?

    public init(edits: [Date?]) {
        count = edits.count
        latest = edits.compactMap { $0 }.max()
    }

    public func event(_ name: String, after earlier: CalendarStamp?) -> AppSignal? {
        self == earlier ? nil : .named(name, value: nil)
    }
}
