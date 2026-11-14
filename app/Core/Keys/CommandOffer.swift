import Foundation

/// A command or a setting that a script offers in its header, as a block: `button=left` or `field=folder`, with a
/// `title` and an `icon`. A person can give a command a key, and choose the value of a setting.
public struct CommandOffer: Equatable, Sendable {
    public let id: String
    public let title: String
    /// The `icon` of its row in Settings. Nil shows the icon of its script.
    public let icon: String?
    /// Whether a setting is a key that the spot listens for, from `type=hotkey`, which its row records.
    public let isHotkey: Bool

    /// Reads a `button` block. Returns nil with no `title`, for an ID with a space, and for the reserved call `read`.
    public init?(block: TextBlock) {
        guard let id = block.value("button"), let title = block.value("title"), id != "read", !id.contains(where: \.isWhitespace) else {
            return nil
        }
        self.id = id
        self.title = title
        icon = block.value("icon")
        isHotkey = false
    }

    /// Reads a `field` block. With no `title`, its title is its key with a capital first letter.
    public init?(setting block: TextBlock) {
        guard let key = block.value("field"), let named = CommandOffer(setting: key) else { return nil }
        self.init(id: key, title: block.value("title") ?? named.title, icon: block.value("icon"), isHotkey: block.value("type") == "hotkey")
    }

    /// A setting of this key, titled with its key with a capital first letter.
    public init?(setting key: String) {
        guard !key.isEmpty, !key.contains(where: \.isWhitespace) else { return nil }
        self.init(id: key, title: key.prefix(1).uppercased() + key.dropFirst(), icon: nil)
    }

    private init(id: String, title: String, icon: String?, isHotkey: Bool = false) {
        self.id = id
        self.title = title
        self.icon = icon
        self.isHotkey = isHotkey
    }
}
