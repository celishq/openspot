import Foundation

public struct CalendarEntry: Equatable, Sendable {
    private static let ties: Set<String> = ["at", "on", "by", "in", "for", "from", "until", "в", "во", "на", "к", "до"]
    private static let noon = 12 * 3600

    public let title: String
    public let date: Date?
    public let hasTime: Bool
    public let length: TimeInterval?

    public init(words: String) {
        let found = Self.date(in: words)
        var rest = words
        if let found, let range = Range(found.range, in: words) { rest.replaceSubrange(range, with: " ") }
        var parts = rest.split(whereSeparator: \.isWhitespace).map(String.init)
        if found != nil, let last = parts.last, Self.ties.contains(last.lowercased()) { parts.removeLast() }
        let all = words.split(whereSeparator: \.isWhitespace)
        if parts.isEmpty, all.count > 1, let first = all.first, Self.date(in: all.dropFirst().joined(separator: " "))?.date == found?.date {
            parts = [String(first)]
        }
        title = parts.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ",;:-–— "))
        date = found?.date
        hasTime = found.map(Self.hasTime) ?? false
        length = found.flatMap { $0.duration > 0 ? $0.duration : nil }
    }

    init(titled words: String) throws {
        let trimmed = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SpotError.failed(1, "Openspot needs words, such as `Lunch tomorrow 13:00`.") }
        self.init(words: words)
        guard !title.isEmpty else {
            throw SpotError.failed(1, "Openspot found only a date in `\(trimmed)`. Add a title, such as `Lunch tomorrow 13:00`.")
        }
    }

    private static func date(in words: String) -> NSTextCheckingResult? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        return detector?.firstMatch(in: words, range: NSRange(words.startIndex..., in: words))
    }

    static func hasTime(_ found: NSTextCheckingResult) -> Bool {
        let key = "timeIsSignificant"
        if found.responds(to: NSSelectorFromString(key)), let isSignificant = found.value(forKey: key) as? Bool { return isSignificant }
        guard let date = found.date else { return false }
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return (parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60 + (parts.second ?? 0) != noon
    }
}
