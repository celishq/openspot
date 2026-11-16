import Foundation

public struct CommandOffer: Equatable, Sendable {
    public static let secret = "secret"

    public let id: String
    public let title: String
    public let icon: String?
    public let confirm: String?
    public let isSecret: Bool
    public let closes: Bool

    public init?(block: TextBlock) {
        guard let id = block.value(HeaderBlock.button), let title = block.value("title"), id != "read", !id.contains(where: \.isWhitespace) else {
            return nil
        }
        self.init(id: id, title: title, icon: block.value("icon"), confirm: block.value("confirm"), closes: block.flag("close") != false)
    }

    public init?(setting block: TextBlock) {
        guard let key = block.value(HeaderBlock.field), let named = CommandOffer(setting: key) else { return nil }
        self.init(id: key, title: block.value("title") ?? named.title, icon: block.value("icon"), isSecret: block.value("type") == Self.secret)
    }

    public init?(setting key: String) {
        guard !key.isEmpty, !key.contains(where: \.isWhitespace) else { return nil }
        self.init(id: key, title: key.prefix(1).uppercased() + key.dropFirst(), icon: nil)
    }

    private init(id: String, title: String, icon: String?, confirm: String? = nil, isSecret: Bool = false, closes: Bool = true) {
        self.id = id
        self.title = title
        self.icon = icon
        self.confirm = confirm
        self.isSecret = isSecret
        self.closes = closes
    }
}
