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
        case peek
        case act(PeekAct, name: String)
        case group(String)
        case playback
        case open
        case secret(String)
        case option(String)
    }

    public static let history = CommandAction(kind: .history, title: "History", key: ActionKey(text: "cmd+y"), scope: .spot, after: .stay)

    public static let peek = CommandAction(kind: .peek, title: "Peek", key: ActionKey(text: "cmd+p"), scope: .item, after: .stay)

    public static let playback = CommandAction(kind: .playback, title: "Pause", scope: .item, after: .stay)

    static func playback(isPlaying: Bool) -> CommandAction {
        CommandAction(kind: .playback, title: isPlaying ? "Pause" : "Play", scope: .item, after: .stay)
    }

    static func act(_ act: PeekAct, name: String, title: String) -> CommandAction {
        CommandAction(kind: .act(act, name: name), title: title, scope: .item, after: .close)
    }

    static func group(_ name: String, title: String) -> CommandAction {
        CommandAction(kind: .group(name), title: title, scope: .item, after: .stay)
    }

    public static let open = CommandAction(kind: .open, title: "Open", scope: .spot, after: .stay)

    public static func command(_ offer: Manifest.Action) -> CommandAction {
        CommandAction(kind: .command(offer.id), title: offer.title ?? "", scope: .spot, after: offer.closes ? .close : .stay, confirm: offer.confirm)
    }

    public static func word(_ name: String, shown word: String? = nil) -> CommandAction {
        CommandAction(kind: .word(name), title: word ?? name, scope: .spot, after: .close)
    }

    static func secret(_ key: String, title: String) -> CommandAction {
        CommandAction(kind: .secret(key), title: "Change \(title)", scope: .spot, after: .stay)
    }

    static func option(_ key: String, title: String) -> CommandAction {
        CommandAction(kind: .option(key), title: "Change \(title)", scope: .spot, after: .stay)
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
        case .peek: "openspot.peek"
        case .act(_, let name), .group(let name): "openspot.act." + name
        case .playback: "openspot.playback"
        case .open: "openspot.open"
        case .secret(let key): "openspot.secret." + key
        case .option(let key): "openspot.option." + key
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
