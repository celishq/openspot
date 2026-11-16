import Foundation

public struct HeaderField: Equatable, Sendable {
    public static let secret = "secret"

    public let id: String
    public let title: String
    public let icon: String?
    public let isSecret: Bool

    public init?(setting block: TextBlock) {
        guard let key = block.value(HeaderBlock.field), let named = HeaderField(setting: key) else { return nil }
        self.init(id: key, title: block.value("title") ?? named.title, icon: block.value("icon"), isSecret: block.value("type") == Self.secret)
    }

    public init?(setting key: String) {
        guard !key.isEmpty, !key.contains(where: \.isWhitespace) else { return nil }
        self.init(id: key, title: key.prefix(1).uppercased() + key.dropFirst(), icon: nil)
    }

    private init(id: String, title: String, icon: String?, isSecret: Bool = false) {
        self.id = id
        self.title = title
        self.icon = icon
        self.isSecret = isSecret
    }
}
