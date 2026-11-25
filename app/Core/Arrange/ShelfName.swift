import Foundation

public struct ShelfName: Equatable, Sendable {
    public struct Break: Equatable, Sendable {
        public let first: String
        public let rest: String
    }

    public let text: String
    public let breaks: [Break]

    public init(_ text: String) {
        self.text = text
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        breaks = stride(from: words.count - 1, to: 0, by: -1).map { index in
            Break(first: words[..<index].joined(separator: " "), rest: words[index...].joined(separator: " "))
        }
    }
}
