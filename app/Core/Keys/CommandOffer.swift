import Foundation

/// A command that a script lists in its header, as `left:Left side`. A person can give it a key.
public struct CommandOffer: Equatable, Sendable {
    public let id: String
    public let title: String

    /// Reads an ID and a title. Returns nil for any other words, and for the reserved call `read`.
    public init?(text: String) {
        let pair = text.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard pair.count == 2, !pair[1].isEmpty, pair[0] != "read", !pair[0].contains(where: \.isWhitespace) else { return nil }
        id = pair[0]
        title = pair[1]
    }
}
