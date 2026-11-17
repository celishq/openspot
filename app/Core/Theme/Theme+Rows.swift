import Foundation

extension Theme {
    public init(rows: [ThemeRow]) {
        let sections = Dictionary(grouping: rows.flatMap { row in row.cells.map { (section: $0.key.section, line: "\($0.key.key) = \($0.value.text)") } }, by: \.section)
        self.init(text: sections.keys.sorted().map { name in (["[\(name)]"] + sections[name, default: []].map(\.line)).joined(separator: "\n") }.joined(separator: "\n\n"))
    }
}
