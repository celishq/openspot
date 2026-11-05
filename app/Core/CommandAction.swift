/// One more thing a command can do, listed in its actions menu and declared in its manifest.
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
}
