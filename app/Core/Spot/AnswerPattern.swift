import Foundation

public struct AnswerPattern: Equatable, @unchecked Sendable {
    public let text: String
    private let expression: NSRegularExpression

    public init?(_ text: String) {
        guard let expression = try? NSRegularExpression(pattern: text) else { return nil }
        self.text = text
        self.expression = expression
    }

    public func matches(_ query: String) -> Bool {
        expression.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)) != nil
    }

    public static func == (one: AnswerPattern, two: AnswerPattern) -> Bool {
        one.text == two.text
    }
}
