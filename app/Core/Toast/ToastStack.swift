import Foundation

public struct ToastStack: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public let number: Int
        public let spot: String
        public let kind: ToastKind
        public let id: String?
    }

    public static let limit = 3

    public private(set) var entries: [Entry] = []
    private var count = 0

    public init() {}

    @discardableResult
    public mutating func add(spot: String, kind: ToastKind, id: String? = nil) -> (number: Int, dropped: [Int], isNew: Bool) {
        if let id, let number = number(of: id, spot: spot) { return (number, [], false) }
        count += 1
        var dropped = entries.filter { $0.spot == spot && $0.kind == .work }.map(\.number)
        entries.removeAll { dropped.contains($0.number) }
        entries.insert(Entry(number: count, spot: spot, kind: kind, id: id), at: 0)
        while entries.count > Self.limit {
            dropped.append(entries.removeLast().number)
        }
        return (count, dropped, true)
    }

    public func number(of id: String, spot: String) -> Int? {
        entries.first { $0.id == id && $0.spot == spot }?.number
    }

    @discardableResult
    public mutating func remove(_ number: Int) -> Bool {
        guard let index = entries.firstIndex(where: { $0.number == number }) else { return false }
        entries.remove(at: index)
        return true
    }
}
