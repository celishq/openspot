import Foundation

/// The rows of the actions menu for one command and its selected item, with the selected row. Its rows come in groups:
/// the spot's own, then Openspot's, then those that each other spot offers, A to Z by its name. Each group after the first
/// has a header line, unless a search shows the rows.
public struct ActionMenu: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public let title: String
        public let keyLabel: String
        public let action: CommandAction?
        /// Whether the hint leaves it out, as a row that each spot has.
        var isQuiet = false
        /// The ID of the spot that offers the action, which a press runs. Nil for an action of the menu's own spot or of the app.
        public var owner: String?
        /// The title of its group, which its header shows. Nil for the group of the menu's own spot.
        var group: String?
    }

    /// An action that a spot offers to the menu of the card, with the name of its group: Openspot for a spot of the app.
    public struct Offer: Equatable, Sendable {
        public let owner: String
        public let name: String
        public let action: CommandAction
        public let isApp: Bool

        public init(owner: String, name: String, action: CommandAction, isApp: Bool = false) {
            self.owner = owner
            self.name = isApp ? ActionMenu.appGroup : name
            self.action = action
            self.isApp = isApp
        }
    }

    /// The title of a group, and the line it takes among the lines of the rows.
    public struct Header: Equatable, Sendable {
        public let title: String
        public let line: Int
    }

    /// The title of the group of the app's own rows.
    static let appGroup = "Openspot"

    /// What Enter does on a row that shows a key: it records a new one.
    static let changeTitle = "Change"
    /// What Enter does on a row that has no key yet.
    static let setTitle = "Set"

    /// The key that opens and closes the menu, as the footer shows it.
    public static let key = "⌘K"

    /// How many rows a menu needs to show a field to search them.
    private static let searchFrom = 3

    public let rows: [Row]
    /// The rows that the search finds, best first. With no search, each row.
    public private(set) var shown: [Row]
    public private(set) var query = ""
    public private(set) var selected = 0
    public private(set) var confirming: String?

    /// Lists what Enter does, the actions that fit, then the actions that spots offer: the app's first, then each other
    /// spot's, A to Z. Returns nil when there is nothing to list.
    public init?(spot: Spot, item: SpotItem?, showsOpen: Bool = true, offered: [Offer] = []) {
        var rows: [Row] = []
        let keyTitle = item.flatMap { $0.records ? ($0.shortcut == KeyList.unset ? Self.setTitle : Self.changeTitle) : nil }
        if showsOpen, let title = item?.openTitle ?? keyTitle ?? spot.openTitle(hasItem: item != nil) {
            rows.append(Row(title: title, keyLabel: "⏎", action: nil))
        }
        rows += spot.actions(for: item).map { Row(title: $0.title, keyLabel: $0.key?.label ?? "", action: $0) }
        let sorted = offered.enumerated().sorted {
            ($0.element.isApp ? 0 : 1, $0.element.name, $0.offset) < ($1.element.isApp ? 0 : 1, $1.element.name, $1.offset)
        }.map(\.element)
        rows += sorted.map { Row(title: $0.action.title, keyLabel: $0.action.key?.label ?? "", action: $0.action, isQuiet: true, owner: $0.owner, group: $0.name) }
        guard !rows.isEmpty else { return nil }
        self.rows = rows
        shown = rows
    }

    public var isSearchable: Bool {
        rows.count >= Self.searchFrom
    }

    /// How many lines it draws: one for each row that it shows, one for each header, and one for the field of a menu that
    /// searches.
    public var lines: Int {
        shown.count + headers.count + (isSearchable ? 1 : 0)
    }

    /// How many lines it draws with no search, which sets its place.
    public var fullLines: Int {
        rows.count + Self.headers(of: rows).count + (isSearchable ? 1 : 0)
    }

    /// The header of each group after the first, with no search. A menu of one group has none.
    public var headers: [Header] {
        query.isEmpty ? Self.headers(of: shown) : []
    }

    /// The line of the shown row at this index among the lines of the rows and the headers.
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
        shown.indices.contains(selected) ? shown[selected] : nil
    }

    /// Shows the rows whose words match the text, as the lists match them, and selects the first.
    public mutating func search(_ text: String) {
        guard text != query else { return }
        query = text
        let items = rows.indices.map { SpotItem(title: rows[$0].title, run: String($0)) }
        shown = text.isEmpty ? rows : SearchQuery(text: text).matching(items).compactMap { Int($0.run).map { rows[$0] } }
        selected = 0
        confirming = nil
    }

    /// The first keys and the key of this menu, in words for a footer.
    public var hint: String {
        hint(stopping: { _ in false })
    }

    /// The first two keys, an action that holds Esc, and the key of this menu, in words for a footer. The key of a running row
    /// says that it stops the call. A second key of the item, such as ⌘⏎ Settings, follows the first.
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
        selected = min(max(selected + step, 0), max(shown.count - 1, 0))
        confirming = nil
    }

    /// Selects the row of this action. A search that hides it ends first.
    public mutating func select(_ action: CommandAction) {
        if !shown.contains(where: { $0.action == action }) { search("") }
        selected = shown.firstIndex { $0.action == action } ?? selected
    }

    /// Takes a press of the selected row. A row that asks to confirm needs a second press, and returns nil on the first. A
    /// running row stops its call, which needs no question.
    public mutating func press(isRunning: Bool = false) -> Row? {
        guard let row = selectedRow else { return nil }
        guard !isRunning, let action = row.action, action.confirm != nil, confirming != action.id else { return row }
        confirming = action.id
        return nil
    }

    /// What a row says now. A running row says that it stops the call, and a row shows its question while it waits for the
    /// second press.
    public func title(of row: Row, isRunning: Bool = false) -> String {
        if isRunning { return Self.stopTitle(of: row) }
        if let action = row.action, action.id == confirming, let confirm = action.confirm { return confirm }
        return row.title
    }

    private static func stopTitle(of row: Row) -> String {
        row.action == nil ? "Stop" : "Stop \(row.title)"
    }
}
