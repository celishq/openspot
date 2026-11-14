import Foundation

/// The rows of the actions menu for one command and its selected item, with the selected row.
public struct ActionMenu: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public let title: String
        public let keyLabel: String
        public let action: CommandAction?
        /// Whether the hint leaves it out, as a row that each spot has.
        var isQuiet = false

        /// Whether it takes the spot or its file away, which the menu draws last and in red.
        public var isDestructive: Bool {
            action?.id == CommandAction.removeID
        }
    }

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

    /// Lists what Enter does, the actions that fit, then the rows that the app adds, each of them on this spot or item.
    /// Returns nil when there is nothing to list.
    public init?(spot: Spot, item: SpotItem?, showsOpen: Bool = true, extras: [CommandAction] = []) {
        var rows: [Row] = []
        let keyTitle = item.flatMap { $0.records ? ($0.shortcut == SpotSettings.unset ? Self.setTitle : Self.changeTitle) : nil }
        if showsOpen, let title = item?.openTitle ?? keyTitle ?? spot.openTitle(hasItem: item != nil) {
            rows.append(Row(title: title, keyLabel: "⏎", action: nil))
        }
        rows += spot.actions(for: item).map { Row(title: $0.title, keyLabel: $0.key?.label ?? "", action: $0) }
        rows += extras.map { Row(title: $0.title, keyLabel: $0.key?.label ?? "", action: $0, isQuiet: true) }
        guard !rows.isEmpty else { return nil }
        self.rows = rows
        shown = rows
    }

    public var isSearchable: Bool {
        rows.count >= Self.searchFrom
    }

    /// How many lines it draws: one for each row that it shows, and one for the field of a menu that searches.
    public var lines: Int {
        isSearchable ? shown.count + 1 : rows.count
    }

    /// How many lines it draws with no search, which sets its place.
    public var fullLines: Int {
        isSearchable ? rows.count + 1 : rows.count
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
    /// says that it stops the call. The next keys of the item, such as ⌘⏎ Settings and ⌘E Edit, follow the first.
    public func hint(stopping isRunning: (Row) -> Bool, second: [String] = []) -> String {
        var keys = footerRows.map { "\($0.keyLabel) \(isRunning($0) ? Self.stopTitle(of: $0) : $0.title)" }
        keys.insert(contentsOf: second, at: min(1, keys.count))
        return (keys + (holdsMore ? ["\(Self.key) Actions"] : [])).joined(separator: "   ")
    }

    /// Whether it holds a row that the footer does not show, so that ⌘K has something to open.
    public var holdsMore: Bool {
        rows.count > footerRows.count
    }

    /// The rows that the footer names with their keys: the first two, and the one on Escape.
    private var footerRows: [Row] {
        let keyed = rows.filter { !$0.keyLabel.isEmpty && !$0.isQuiet }
        let isEscape = { (row: Row) in row.action?.key == ActionKey(name: "escape") }
        return Array(keyed.filter { !isEscape($0) }.prefix(2)) + keyed.filter(isEscape)
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
