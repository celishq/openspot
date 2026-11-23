public struct CommandAction: Equatable, Sendable {
    public enum Scope: String, Sendable {
        case item
        case spot
    }

    public enum After: String, Sendable {
        case close
        case stay
    }

    public enum Kind: Equatable, Sendable {
        case frame(String)
        case command(String)
        case word(String)
        case history
        case open
    }

    public static let history = CommandAction(kind: .history, title: "History", key: ActionKey(text: "cmd+y"), scope: .spot, after: .stay)

    public static let open = CommandAction(kind: .open, title: "Open", scope: .spot, after: .stay)

    public static func command(_ offer: Manifest.Action) -> CommandAction {
        CommandAction(kind: .command(offer.id), title: offer.title ?? "", scope: .spot, after: offer.closes ? .close : .stay, confirm: offer.confirm)
    }

    public static func word(_ name: String, shown word: String? = nil) -> CommandAction {
        CommandAction(kind: .word(name), title: word ?? name, scope: .spot, after: .close)
    }

    public let kind: Kind
    public let title: String
    public let key: ActionKey?
    public let scope: Scope
    public let after: After
    public let confirm: String?
    public let placeholder: String?

    public init(
        id: String,
        title: String,
        key: ActionKey? = nil,
        scope: Scope = .item,
        after: After = .stay,
        confirm: String? = nil,
        placeholder: String? = nil
    ) {
        self.init(kind: .frame(id), title: title, key: key, scope: scope, after: after, confirm: confirm, placeholder: placeholder)
    }

    private init(
        kind: Kind,
        title: String,
        key: ActionKey? = nil,
        scope: Scope = .item,
        after: After = .stay,
        confirm: String? = nil,
        placeholder: String? = nil
    ) {
        self.kind = kind
        self.title = title
        self.key = key
        self.scope = scope
        self.after = after
        self.confirm = confirm
        self.placeholder = placeholder
    }

    public var id: String {
        switch kind {
        case .frame(let id): id
        case .command(let id): "openspot.command." + id
        case .word(let name): "openspot.word." + name
        case .history: "openspot.history"
        case .open: "openspot.open"
        }
    }

    public var callName: String {
        if case .command(let id) = kind { id } else { id }
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
            confirm: block.value("confirm"),
            placeholder: block.value("placeholder")
        )
    }
}
