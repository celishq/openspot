/// One more thing a command can do, which its script prints and its actions menu lists.
public struct CommandAction: Equatable, Sendable {
    /// What an action acts on: the selected item, the default, or the whole spot (protocol: Buttons and actions).
    public enum Scope: String, Sendable {
        case item
        case spot
    }

    /// What the panel does after the action runs.
    public enum After: String, Sendable {
        case close
        case stay
    }

    /// The row that the app adds to the menu of a spot, which no script prints or answers.
    public static let share = CommandAction(id: "openspot.share", title: "Share", key: ActionKey(text: "cmd+shift+c"), scope: .spot, after: .close)

    /// The row that takes a spot out of the spots folder, which `⌘Z` puts back. A widget file takes each widget that it
    /// holds.
    public static func remove(widgets count: Int = 1) -> CommandAction {
        CommandAction(id: removeID, title: count > 1 ? "Delete \(count) widgets" : "Delete", key: ActionKey(text: "cmd+backspace"), scope: .spot, after: .stay)
    }

    /// The row that opens the file of a spot in the text editor.
    public static let edit = CommandAction(id: "openspot.edit", title: "Edit", key: ActionKey(text: "cmd+e"), scope: .spot, after: .close)

    /// The row that copies a prompt that asks a coding agent to change a spot.
    public static let copyPrompt = CommandAction(id: "openspot.copy-prompt", title: "Copy prompt for AI", scope: .spot, after: .close)

    public static let removeID = "openspot.remove"

    /// The row that turns a core spot off. Its file stays in the app, and its data stays.
    public static let turnOff = CommandAction(id: "openspot.turn-off", title: "Turn off", key: ActionKey(text: "cmd+backspace"), scope: .spot, after: .close)

    public let id: String
    public let title: String
    public let key: ActionKey?
    public let scope: Scope
    public let after: After
    public let isForm: Bool
    public let confirm: String?

    public init(
        id: String,
        title: String,
        key: ActionKey? = nil,
        scope: Scope = .item,
        after: After = .stay,
        isForm: Bool = false,
        confirm: String? = nil
    ) {
        self.id = id
        self.title = title
        self.key = key
        self.scope = scope
        self.after = after
        self.isForm = isForm
        self.confirm = confirm
    }

    /// Reads the block of one action. It needs a title, and a key or a scope it gives must be known.
    public init?(id: String, block: TextBlock) {
        guard let title = block.value("title") else { return nil }
        var key: ActionKey?
        if let name = block.value("shortcut") {
            guard let parsed = ActionKey(text: name) else { return nil }
            key = parsed
        }
        guard let scope = Scope(rawValue: block.value("scope") ?? Scope.item.rawValue) else { return nil }
        self.init(
            id: id,
            title: title,
            key: key,
            scope: scope,
            after: block.flag("close") == true ? .close : .stay,
            isForm: block.flag("form") ?? false,
            confirm: block.value("confirm")
        )
    }
}
