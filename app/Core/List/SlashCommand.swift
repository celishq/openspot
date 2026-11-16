import Foundation

public struct SlashCommand: Equatable, Sendable {
    public let word: String
    public let text: String
    public let lead: String

    public init?(_ query: String) {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard let found = words.first(where: Self.isCommand) else { return nil }
        word = String(found.dropFirst())
        lead = String(query[..<found.startIndex])
        let before = query[..<found.startIndex].trimmingCharacters(in: .whitespaces)
        let after = query[found.endIndex...].trimmingCharacters(in: .whitespaces)
        text = [before, after].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func isCommand(_ word: Substring) -> Bool {
        guard word.first == "/", let first = word.dropFirst().first, first.isLetter else { return false }
        return word.dropFirst().allSatisfy { $0.isLetter || $0.isNumber || "-_.".contains($0) }
    }
}
