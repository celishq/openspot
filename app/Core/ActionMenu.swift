/// The rows of the actions menu for one command and its selected item, with the selected row.
public struct ActionMenu: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public let title: String
        public let keyLabel: String
        public let action: CommandAction?
    }

    public let rows: [Row]
    public private(set) var selected = 0
    public private(set) var confirming: String?

    /// Lists what Enter does, then the actions that fit. Returns nil when there is nothing to list.
    public init?(command: PluginCommand, item: SpotItem?) {
        var rows: [Row] = []
        if let title = command.primaryTitle(hasItem: item != nil) {
            rows.append(Row(title: title, keyLabel: "⏎", action: nil))
        }
        rows += command.actions(for: item).map { Row(title: $0.title, keyLabel: $0.key?.label ?? "", action: $0) }
        guard !rows.isEmpty else { return nil }
        self.rows = rows
    }

    public mutating func move(by step: Int) {
        selected = min(max(selected + step, 0), rows.count - 1)
        confirming = nil
    }

    public mutating func select(_ action: CommandAction) {
        selected = rows.firstIndex { $0.action == action } ?? selected
    }

    /// Takes a press of the selected row. A row that asks to confirm needs a second press, and returns nil on the first.
    public mutating func press() -> Row? {
        let row = rows[selected]
        guard let action = row.action, action.confirm != nil, confirming != action.id else { return row }
        confirming = action.id
        return nil
    }

    /// What a row says now. It shows its question while it waits for the second press.
    public func title(of row: Row) -> String {
        if let action = row.action, action.id == confirming, let confirm = action.confirm { return confirm }
        return row.title
    }
}
