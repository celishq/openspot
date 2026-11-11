/// The rows of the actions menu for one command and its selected item, with the selected row.
public struct ActionMenu: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public let title: String
        public let keyLabel: String
        public let action: CommandAction?
        /// Whether the hint leaves it out, as a row that each spot has.
        var isQuiet = false
    }

    /// What Enter does on a row that shows a key: it records a new one.
    static let changeTitle = "Change"
    /// What Enter does on a row that has no key yet.
    static let setTitle = "Set"

    /// The key that opens and closes the menu, as the footer shows it.
    public static let key = "⌘K"

    /// How many rows a person takes in at a glance. A menu with more shows a field to search them.
    private static let glance = 5

    public let rows: [Row]
    /// The rows that the search finds, best first. With no search, each row.
    public private(set) var shown: [Row]
    public private(set) var query = ""
    public private(set) var selected = 0
    public private(set) var confirming: String?

    /// Lists what Enter does, the actions that fit, then the rows that the app adds, each of them on this command or item.
    /// Returns nil when there is nothing to list.
    public init?(command: Spot, item: SpotItem?, showsPrimary: Bool = true, extras: [CommandAction] = []) {
        var rows: [Row] = []
        if showsPrimary, let title = item?.openTitle ?? item?.shortcut.map { $0 == SettingsSpot.unset ? Self.setTitle : Self.changeTitle } ?? command.primaryTitle(hasItem: item != nil) {
            rows.append(Row(title: title, keyLabel: "⏎", action: nil))
        }
        rows += command.actions(for: item).map { Row(title: $0.title, keyLabel: $0.key?.label ?? "", action: $0) }
        rows += extras.map { Row(title: $0.title, keyLabel: $0.key?.label ?? "", action: $0, isQuiet: true) }
        guard !rows.isEmpty else { return nil }
        self.rows = rows
        shown = rows
    }

    public var isSearchable: Bool {
        rows.count > Self.glance
    }

    /// How many lines it draws: one for each row that it shows, and one for the field of a menu that searches.
    public var lines: Int {
        isSearchable ? shown.count + 1 : rows.count
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
