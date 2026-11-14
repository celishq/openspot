import Foundation

public struct CommandOffer: Equatable, Sendable {
    public let id: String
    public let title: String
    public let icon: String?

    public init?(block: TextBlock) {
        guard let id = block.value("button"), let title = block.value("title"), id != "read", !id.contains(where: \.isWhitespace) else {
            return nil
        }
        self.id = id
        self.title = title
        icon = block.value("icon")
    }

    public init?(setting block: TextBlock) {
        guard let key = block.value("field"), let named = CommandOffer(setting: key) else { return nil }
        self.init(id: key, title: block.value("title") ?? named.title, icon: block.value("icon"))
    }

    public init?(setting key: String) {
        guard !key.isEmpty, !key.contains(where: \.isWhitespace) else { return nil }
        self.init(id: key, title: key.prefix(1).uppercased() + key.dropFirst(), icon: nil)
    }

    private init(id: String, title: String, icon: String?) {
        self.id = id
        self.title = title
        self.icon = icon
    }
}
