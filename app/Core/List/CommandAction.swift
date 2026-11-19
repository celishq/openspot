public struct CommandAction: Equatable, Sendable {
    public enum Scope: String, Sendable {
        case item
        case spot
    }

    public enum After: String, Sendable {
        case close
        case stay
    }

    public static let history = CommandAction(id: "openspot.history", title: "History", key: ActionKey(text: "cmd+y"), scope: .spot, after: .stay)

    public static let open = CommandAction(id: "openspot.open", title: "Open", scope: .spot, after: .stay)

    private static let commandPrefix = "openspot.command."

    public static func command(_ offer: Manifest.Command) -> CommandAction {
        CommandAction(id: commandPrefix + offer.id, title: offer.title, scope: .spot, after: offer.closes ? .close : .stay, confirm: offer.confirm, placeholder: offer.placeholder)
    }

    public static func command(of action: CommandAction) -> String? {
        action.id.hasPrefix(commandPrefix) ? String(action.id.dropFirst(commandPrefix.count)) : nil
    }

    public let id: String
    public let title: String
    public let key: ActionKey?
    public let scope: Scope
    public let after: After
    public let isForm: Bool
    public let confirm: String?
    public let placeholder: String?

    public init(
        id: String,
        title: String,
        key: ActionKey? = nil,
        scope: Scope = .item,
        after: After = .stay,
        isForm: Bool = false,
        confirm: String? = nil,
        placeholder: String? = nil
    ) {
        self.id = id
        self.title = title
        self.key = key
        self.scope = scope
        self.after = after
        self.isForm = isForm
        self.confirm = confirm
        self.placeholder = placeholder
    }

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
            after: block.flag("close") == false ? .stay : .close,
            isForm: block.flag("form") ?? false,
            confirm: block.value("confirm"),
            placeholder: block.value("placeholder")
        )
    }
}
