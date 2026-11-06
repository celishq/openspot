import Foundation

/// A key that a script holds in every app, with the call that a press makes, as a header writes it: `ctrl+option+left left`.
public struct GlobalKey: Hashable, Sendable {
    public let spot: String
    public let shortcut: Shortcut
    public let call: String

    /// Reads a key and a call. Returns nil for any other words, and for the reserved call `read`.
    public init?(text: String, spot: String) {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard words.count == 2, let shortcut = Shortcut(text: words[0]), words[1] != "read" else { return nil }
        self.spot = spot
        self.shortcut = shortcut
        self.call = words[1]
    }
}
