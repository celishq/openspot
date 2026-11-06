/// One more thing a command can do, which its script prints and its actions menu lists.
public struct CommandAction: Equatable, Sendable {
    /// What an action needs: a selected item, or only its command.
    public enum Scope: String, Sendable {
        case item
        case command
    }

    /// What the panel does after the action runs.
    public enum After: String, Sendable {
        case close
        case stay
    }

    /// The row that the app adds to the menu of a spot, which no script prints or answers.
    public static let share = CommandAction(id: "openspot.share", title: "Copy to share", scope: .command, after: .close)

    /// The row that takes a spot out of the plugins folder. A widget file takes each widget that it holds.
    public static func remove(widgets count: Int = 1) -> CommandAction {
        let what = count > 1 ? " \(count) widgets" : ""
        return CommandAction(id: removeID, title: "Remove", scope: .command, after: .close, confirm: "Press again to remove\(what)")
    }

    public static let removeID = "openspot.remove"

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
        if let name = block.value("key") {
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
