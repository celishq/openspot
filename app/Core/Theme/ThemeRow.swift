import Foundation

public struct ThemeRow: Equatable, Sendable, Identifiable {
    public struct Cell: Equatable, Sendable {
        public let key: ThemeKey
        public fileprivate(set) var value: ConfigDocument.Value
        public fileprivate(set) var isSet: Bool

        public init(key: ThemeKey, value: ConfigDocument.Value, isSet: Bool) {
            self.key = key
            self.value = value
            self.isSet = isSet
        }
    }

    public static let look = "look"

    public let group: String
    public let id: ThemeKey
    public let kind: ThemeKind
    public private(set) var cells: [Cell]

    public var name: String {
        id.key
    }

    public init(group: String, id: ThemeKey, kind: ThemeKind, cells: [Cell]) {
        self.group = group
        self.id = id
        self.kind = kind
        self.cells = cells
    }

    public static func rows(builtIn: String, own: String?) -> [ThemeRow] {
        let base = (try? ConfigDocument(text: builtIn))?.sections ?? []
        let mine = own.flatMap { try? ConfigDocument(text: $0) }?.sections ?? []
        let cell = { (key: ThemeKey) -> Cell? in
            if let value = mine.first(where: { $0.name == key.section })?[key.key], Theme.accepts(value, at: key) { return Cell(key: key, value: value, isSet: true) }
            return base.first { $0.name == key.section }?[key.key].map { Cell(key: key, value: $0, isSet: false) }
        }
        return base.filter { $0.name != "light" }.flatMap { table -> [ThemeRow] in
            let sections = table.name == "dark" ? ["dark", "light"] : [table.name]
            return table.keys.compactMap { key -> ThemeRow? in
                let id = ThemeKey(section: table.name, key: key)
                guard let kind = Theme.kind(of: id) else { return nil }
                return ThemeRow(group: table.name == "dark" ? look : table.name, id: id, kind: kind, cells: sections.compactMap { cell(ThemeKey(section: $0, key: key)) })
            }
        }
    }

    public mutating func change(_ value: ConfigDocument.Value, at key: ThemeKey) {
        guard let index = cells.firstIndex(where: { $0.key == key }) else { return }
        cells[index].value = value
        cells[index].isSet = true
    }
}
