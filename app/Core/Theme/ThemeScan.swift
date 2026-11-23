import Foundation

public struct ThemeScan: Sendable {
    public struct Item: Sendable {
        public let name: String
        public let file: URL?
        public let isBuiltIn: Bool
    }

    public let items: [Item]
    let clashes: [(own: String, builtIn: String)]

    init(builtIns: [(name: String, file: URL?)], own: [(name: String, file: URL)]) {
        var builtIn: [Item] = []
        for theme in builtIns where !Self.isTaken(theme.name, in: builtIn.map(\.name)) {
            builtIn.append(Item(name: theme.name, file: theme.file, isBuiltIn: true))
        }
        let sorted = own.sorted { Self.order($0.name, $1.name) }
        let names = builtIn.map(\.name)
        clashes = sorted.compactMap { theme in
            names.first { Self.isTaken(theme.name, in: [$0]) }.map { (theme.name, $0) }
        }
        let first = builtIn[0].name
        items = [builtIn[0]] + builtIn.dropFirst().sorted { Self.order($0.name, $1.name, after: first) }
            + sorted.filter { !Self.isTaken($0.name, in: names) }.map { Item(name: $0.name, file: $0.file, isBuiltIn: false) }
    }

    public var names: [String] {
        items.map(\.name)
    }

    public func find(_ name: String) -> Item? {
        items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private static func isTaken(_ name: String, in names: [String]) -> Bool {
        names.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    private static func order(_ one: String, _ other: String, after first: String) -> Bool {
        let (isOne, isOther) = (one.hasPrefix(first), other.hasPrefix(first))
        return isOne == isOther ? order(one, other) : isOne
    }

    private static func order(_ one: String, _ other: String) -> Bool {
        one.localizedStandardCompare(other) == .orderedAscending
    }
}
