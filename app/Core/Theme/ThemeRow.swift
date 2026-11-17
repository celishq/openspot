import Foundation

public struct ThemeRow: Equatable, Sendable, Identifiable {
    public struct Cell: Equatable, Sendable {
        public let section: String
        public fileprivate(set) var value: ConfigDocument.Value
        public fileprivate(set) var isSet: Bool

        public init(section: String, value: ConfigDocument.Value, isSet: Bool) {
            self.section = section
            self.value = value
            self.isSet = isSet
        }
    }

    public static let look = "look"

    public let group: String
    public let key: String
    public let kind: ThemeKind
    public private(set) var cells: [Cell]

    public var id: String {
        "\(group) \(key)"
    }

    public init(group: String, key: String, kind: ThemeKind, cells: [Cell]) {
        self.group = group
        self.key = key
        self.kind = kind
        self.cells = cells
    }

    public static func rows(builtIn: String, own: String?) -> [ThemeRow] {
        let base = (try? ConfigDocument(text: builtIn))?.sections ?? []
        let mine = own.flatMap { try? ConfigDocument(text: $0) }?.sections ?? []
        let cell = { (section: String, key: String) -> Cell? in
            if let value = mine.first(where: { $0.name == section })?[key] { return Cell(section: section, value: value, isSet: true) }
            return base.first { $0.name == section }?[key].map { Cell(section: section, value: $0, isSet: false) }
        }
        return base.filter { $0.name != "light" }.flatMap { table -> [ThemeRow] in
            let sections = table.name == "dark" ? ["dark", "light"] : [table.name]
            return table.keys.compactMap { key -> ThemeRow? in
                guard let kind = Theme.kind(of: "[\(table.name)] \(key)") else { return nil }
                return ThemeRow(group: table.name == "dark" ? look : table.name, key: key, kind: kind, cells: sections.compactMap { cell($0, key) })
            }
        }
    }

    public mutating func change(_ value: ConfigDocument.Value, in section: String) {
        guard let index = cells.firstIndex(where: { $0.section == section }) else { return }
        cells[index].value = value
        cells[index].isSet = true
    }
}
