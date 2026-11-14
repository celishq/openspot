import Foundation

public struct ActionMenu: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public let title: String
        public let keyLabel: String
        public let action: CommandAction?
        var isQuiet = false
        public var owner: String?
        var group: String?
        public var children: [Row] = []
    }

    public struct Header: Equatable, Sendable {
        public let title: String
        public let line: Int
    }

    static let changeTitle = "Change"
    static let setTitle = "Set"

    public static let key = "⌘K"

    private static let searchFrom = 3

    public let rows: [Row]
    public private(set) var submenu: Submenu?

    public struct Submenu: Equatable, Sendable {
        public let parent: Int
        public let rows: [Row]
        public fileprivate(set) var selected = 0
    }
    public private(set) var shown: [Row]
    public private(set) var query = ""
    public private(set) var selected = 0
    public private(set) var confirming: String?

    public init?(spot: Spot, item: SpotItem?, showsOpen: Bool = true, offered: [OfferedAction] = []) {
        var rows: [Row] = []
        let keyTitle = item.flatMap { $0.records ? ($0.shortcut == KeyList.unset ? Self.setTitle : Self.changeTitle) : nil }
        if showsOpen, let title = item?.openTitle ?? keyTitle ?? spot.openTitle(hasItem: item != nil) {
            rows.append(Row(title: title, keyLabel: "⏎", action: nil))
        }
        rows += spot.actions(for: item).map { Row(title: $0.title, keyLabel: $0.key?.label ?? "", action: $0) }
        let sorted = offered.enumerated().sorted {
            ($0.element.group == nil ? 0 : 1, $0.element.group ?? "", $0.offset) < ($1.element.group == nil ? 0 : 1, $1.element.group ?? "", $1.offset)
        }.map(\.element)
        rows += Self.nested(sorted.map { Row(title: $0.action.title, keyLabel: $0.action.key?.label ?? "", action: $0.action, isQuiet: true, owner: $0.owner, group: $0.group) })
        guard !rows.isEmpty else { return nil }
        self.rows = rows
        shown = rows
    }

    private static func nested(_ rows: [Row]) -> [Row] {
        var top: [Row] = []
        for row in rows {
            let id = row.action?.id ?? ""
            if let dot = id.lastIndex(of: "."), let index = top.firstIndex(where: { $0.owner == row.owner && $0.action?.id == String(id[..<dot]) }) {
                top[index].children.append(row)
                top[index] = Row(title: top[index].title, keyLabel: "›", action: top[index].action, isQuiet: true, owner: top[index].owner, group: top[index].group, children: top[index].children)
            } else {
                top.append(row)
            }
        }
        return top
    }

    public var parent: Row? {
        submenu.map { shown[$0.parent] }
    }

    public mutating func enterSelected() -> Bool {
        guard submenu == nil, shown.indices.contains(selected), !shown[selected].children.isEmpty else { return false }
        submenu = Submenu(parent: selected, rows: shown[selected].children)
        confirming = nil
        return true
    }

    public mutating func back() -> Bool {
        guard submenu != nil else { return false }
        submenu = nil
        confirming = nil
        return true
    }

    public mutating func point(at index: Int) {
        guard shown.indices.contains(index) else { return }
        if submenu?.parent == index { return }
        selected = index
        submenu = nil
        confirming = nil
        _ = enterSelected()
    }

    public mutating func pointSubmenu(at index: Int) {
        guard let rows = submenu?.rows, rows.indices.contains(index), submenu?.selected != index else { return }
        submenu?.selected = index
        confirming = nil
    }

    public var isSearchable: Bool {
        rows.count >= Self.searchFrom
    }

    public var lines: Int {
        shown.count + headers.count + (isSearchable ? 1 : 0)
    }

    public var fullLines: Int {
        rows.count + Self.headers(of: rows).count + (isSearchable ? 1 : 0)
    }

    public var headers: [Header] {
        query.isEmpty ? Self.headers(of: shown) : []
    }

    public func line(ofShown index: Int) -> Int {
        index + headers.enumerated().filter { $0.element.line - $0.offset <= index }.count
    }

    private static func headers(of rows: [Row]) -> [Header] {
        guard Set(rows.map(\.group)).count > 1 else { return [] }
        var headers: [Header] = []
        for (index, row) in rows.enumerated() where index > 0 && row.group != rows[index - 1].group {
            headers.append(Header(title: row.group ?? "", line: index + headers.count))
        }
        return headers
    }

    public var selectedRow: Row? {
        if let submenu { return submenu.rows.indices.contains(submenu.selected) ? submenu.rows[submenu.selected] : nil }
        return shown.indices.contains(selected) ? shown[selected] : nil
    }

    public mutating func search(_ text: String) {
        guard text != query else { return }
        query = text
        let all = rows.flatMap { row in [row] + row.children.map { Row(title: "\(row.title) › \($0.title)", keyLabel: $0.keyLabel, action: $0.action, isQuiet: $0.isQuiet, owner: $0.owner, group: $0.group) } }
        let items = all.indices.map { SpotItem(title: all[$0].title, run: String($0)) }
        shown = text.isEmpty ? rows : SearchQuery(text: text).matching(items).compactMap { Int($0.run).map { all[$0] } }.filter { $0.children.isEmpty }
        submenu = nil
        selected = 0
        confirming = nil
    }

    public var hint: String {
        hint(stopping: { _ in false })
    }

    public func hint(stopping isRunning: (Row) -> Bool, second: String? = nil) -> String {
        let keyed = rows.filter { !$0.keyLabel.isEmpty && !$0.isQuiet }
        let isEscape = { (row: Row) in row.action?.key == ActionKey(name: "escape") }
        let shown = Array(keyed.filter { !isEscape($0) }.prefix(2)) + keyed.filter(isEscape)
        var keys = shown.map { "\($0.keyLabel) \(isRunning($0) ? Self.stopTitle(of: $0) : $0.title)" }
        if let second { keys.insert(second, at: min(1, keys.count)) }
        return (keys + ["\(Self.key) Actions"]).joined(separator: "   ")
    }

    public mutating func move(by step: Int) {
        guard step != 0 else { return }
        if let submenu {
            self.submenu?.selected = min(max(submenu.selected + step, 0), max(submenu.rows.count - 1, 0))
        } else {
            selected = min(max(selected + step, 0), max(shown.count - 1, 0))
        }
        confirming = nil
    }

    public mutating func select(_ action: CommandAction) {
        submenu = nil
        if !shown.contains(where: { $0.action == action }) { search("") }
        selected = shown.firstIndex { $0.action == action } ?? selected
    }

    public mutating func press(isRunning: Bool = false) -> Row? {
        guard let row = selectedRow else { return nil }
        if !row.children.isEmpty {
            _ = enterSelected()
            return nil
        }
        guard !isRunning, let action = row.action, action.confirm != nil, confirming != action.id else { return row }
        confirming = action.id
        return nil
    }

    public func title(of row: Row, isRunning: Bool = false) -> String {
        if isRunning { return Self.stopTitle(of: row) }
        if let action = row.action, action.id == confirming, let confirm = action.confirm { return confirm }
        return row.title
    }

    private static func stopTitle(of row: Row) -> String {
        row.action == nil ? "Stop" : "Stop \(row.title)"
    }
}
