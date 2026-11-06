/// The rows of the actions menu for one command and its selected item, with the selected row.
public struct ActionMenu: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public let title: String
        public let keyLabel: String
        public let action: CommandAction?
        public var opensEdit = false
    }

    public let rows: [Row]
    public private(set) var selected = 0
    public private(set) var confirming: String?

    /// Lists what Enter does, then the actions that fit. Returns nil when there is nothing to list.
    public init?(command: PluginCommand, item: SpotItem?, showsPrimary: Bool = true, showsEdit: Bool = false) {
        var rows: [Row] = []
        if showsPrimary, let title = command.primaryTitle(hasItem: item != nil) {
            rows.append(Row(title: title, keyLabel: "⏎", action: nil))
        }
        rows += command.actions(for: item).map { Row(title: $0.title, keyLabel: $0.key?.label ?? "", action: $0) }
        if showsEdit { rows.append(Row(title: "Edit Spots", keyLabel: "", action: nil, opensEdit: true)) }
        guard !rows.isEmpty else { return nil }
        self.rows = rows
    }

    /// The first keys and the key of this menu, in words for a footer.
    public var hint: String {
        hint(stopping: { _ in false })
    }

    /// The first keys and the key of this menu, in words for a footer. The key of a running row says that it stops the call.
    public func hint(stopping isRunning: (Row) -> Bool) -> String {
        let keys = rows.filter { !$0.keyLabel.isEmpty }.prefix(2).map { "\($0.keyLabel) \(isRunning($0) ? Self.stopTitle(of: $0) : $0.title)" }
        return (keys + ["⌘K Actions"]).joined(separator: "   ")
    }

    public mutating func move(by step: Int) {
        selected = min(max(selected + step, 0), rows.count - 1)
        confirming = nil
    }

    public mutating func select(_ action: CommandAction) {
        selected = rows.firstIndex { $0.action == action } ?? selected
    }

    /// Takes a press of the selected row. A row that asks to confirm needs a second press, and returns nil on the first. A
    /// running row stops its call, which needs no question.
    public mutating func press(isRunning: Bool = false) -> Row? {
        let row = rows[selected]
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
