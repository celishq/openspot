import Foundation

public struct CalendarEntry: Equatable, Sendable {
    private static let ties: Set<String> = ["at", "on", "by", "in", "for", "from", "until", "в", "во", "на", "к", "до"]

    public let title: String
    public let date: Date?
    public let hasTime: Bool
    public let length: TimeInterval?

    public init(words: String) {
        let found = TextFinds(words).date()
        var rest = words
        if let found { rest.replaceSubrange(found.range, with: " ") }
        var parts = rest.split(whereSeparator: \.isWhitespace).map(String.init)
        if found != nil, let last = parts.last, Self.ties.contains(last.lowercased()) { parts.removeLast() }
        let all = words.split(whereSeparator: \.isWhitespace)
        if parts.isEmpty, all.count > 1, let first = all.first, TextFinds(all.dropFirst().joined(separator: " ")).date()?.date == found?.date {
            parts = [String(first)]
        }
        title = parts.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ",;:-–— "))
        date = found?.date
        hasTime = found?.hasTime ?? false
        length = found?.length
    }

    init(titled words: String) throws {
        let trimmed = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SpotError.failed(1, "Openspot needs words, such as `Lunch tomorrow 13:00`.") }
        self.init(words: words)
        guard !title.isEmpty else {
            throw SpotError.failed(1, "Openspot found only a date in `\(trimmed)`. Add a title, such as `Lunch tomorrow 13:00`.")
        }
    }
}
