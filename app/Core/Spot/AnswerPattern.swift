import Foundation

/// The regular expression of an `on=search.text` line, which says the text of the main search that a spot answers (A1).
public struct AnswerPattern: Equatable, @unchecked Sendable {
    public let text: String
    private let expression: NSRegularExpression

    /// Reads a pattern, or returns nil for text that is no regular expression.
    public init?(_ text: String) {
        guard let expression = try? NSRegularExpression(pattern: text) else { return nil }
        self.text = text
        self.expression = expression
    }

    /// Whether the pattern finds a match anywhere in the text, so that `^` ties it to the start.
    public func matches(_ query: String) -> Bool {
        expression.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)) != nil
    }

    public static func == (one: AnswerPattern, two: AnswerPattern) -> Bool {
        one.text == two.text
    }
}
