import Foundation

public struct KeyMap: Equatable, Sendable {
    public private(set) var set: [SettingRows.Group] = []
    public private(set) var unset: [SettingRows.Group] = []
    private var clashes: [[SettingRow]] = []
    public private(set) var clashing: Set<String> = []

    public init() {}

    init(_ rows: [SettingRow]) {
        let keys = rows.filter { $0.kind == .key }
        let keyed = keys.filter { !($0.value ?? "").isEmpty }
        let found = Dictionary(grouping: keyed) { Self.normal($0.value ?? "") }.values.filter { $0.count > 1 }.sorted { ($0[0].value ?? "") < ($1[0].value ?? "") }
        clashes = found
        clashing = Set(found.flatMap { $0.map(\.item) })
        set = Self.byName(keyed)
        unset = Self.byName(keys.filter { ($0.value ?? "").isEmpty })
    }

    public func clash(of item: String) -> String? {
        let others = clashes.first { $0.contains { $0.item == item } }?.filter { $0.item != item } ?? []
        return others.isEmpty ? nil : "Also " + others.map { "\($0.name) · \($0.title)" }.joined(separator: ", ")
    }

    private static func byName(_ rows: [SettingRow]) -> [SettingRows.Group] {
        rows.map(\.name).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.map { name in SettingRows.Group(id: name, rows: rows.filter { $0.name == name }) }
    }

    private static func normal(_ key: String) -> String {
        let words = key.lowercased().split(separator: "+").map(String.init)
        return (words.dropLast().sorted() + words.suffix(1)).joined(separator: "+")
    }
}
