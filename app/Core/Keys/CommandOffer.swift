import Foundation

/// A command that a script lists in its header, as `left:Left side`, with an optional icon, as
/// `left:Left side:rectangle.lefthalf.filled`. A person can give it a key. A setting in the header takes the same words.
public struct CommandOffer: Equatable, Sendable {
    public let id: String
    public let title: String
    /// The `icon` of its row in Settings. Nil shows the icon of its script.
    public let icon: String?

    /// Reads an ID, a title and an icon. Returns nil for any other words, and for the reserved call `read`.
    public init?(text: String) {
        let parts = text.split(separator: ":", maxSplits: 2).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2, !parts[1].isEmpty, parts[0] != "read", !parts[0].contains(where: \.isWhitespace) else { return nil }
        id = parts[0]
        title = parts[1]
        icon = parts.count == 3 && !parts[2].isEmpty ? parts[2] : nil
    }

    /// Reads a setting, as `folder` or `editor:Default app`. With no title, its title is its key with a capital first letter.
    public init?(setting text: String) {
        let key = text.split(separator: ":", maxSplits: 1).first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        guard !key.isEmpty else { return nil }
        if text.contains(":") {
            guard let offer = CommandOffer(text: text) else { return nil }
            self = offer
        } else {
            id = key
            title = key.prefix(1).uppercased() + key.dropFirst()
            icon = nil
        }
    }
}
