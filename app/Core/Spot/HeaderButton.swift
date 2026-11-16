import Foundation

public struct HeaderButton: Equatable, Sendable {
    public let id: String
    public let title: String
    public let icon: String?
    public let confirm: String?
    public let closes: Bool
    public let placeholder: String?

    public init?(block: TextBlock) {
        guard let id = block.value(HeaderBlock.button), let title = block.value("title"), id != "read", !id.contains(where: \.isWhitespace) else {
            return nil
        }
        self.id = id
        self.title = title
        icon = block.value("icon")
        confirm = block.value("confirm")
        closes = block.flag("close") != false
        placeholder = block.value("placeholder")
    }
}
