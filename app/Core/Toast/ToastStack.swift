import Foundation

public struct ToastStack: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public let number: Int
        public let spot: String
        public let kind: ToastKind
    }

    public static let limit = 3

    public private(set) var entries: [Entry] = []
    private var count = 0

    public init() {}

    @discardableResult
    public mutating func add(spot: String, kind: ToastKind) -> (number: Int, dropped: [Int]) {
        count += 1
        var dropped = entries.filter { $0.spot == spot && $0.kind == .work }.map(\.number)
        entries.removeAll { dropped.contains($0.number) }
        entries.insert(Entry(number: count, spot: spot, kind: kind), at: 0)
        while entries.count > Self.limit {
            dropped.append(entries.removeLast().number)
        }
        return (count, dropped)
    }

    @discardableResult
    public mutating func remove(_ number: Int) -> Bool {
        guard let index = entries.firstIndex(where: { $0.number == number }) else { return false }
        entries.remove(at: index)
        return true
    }
}
