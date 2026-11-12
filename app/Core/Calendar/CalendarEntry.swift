import Foundation

/// What a person typed to add an event or a reminder: the first date in the words, found by the date finder of macOS, and
/// the rest of the words as the title (E4).
public struct CalendarEntry: Equatable, Sendable {
    /// Short words that tie a date to the title, such as `on` in `Pay rent on Nov 15`, which go with the date.
    private static let ties: Set<String> = ["at", "on", "by", "in", "for", "from", "until", "в", "во", "на", "к", "до"]
    private static let noon = 12 * 3600

    public let title: String
    public let date: Date?
    public let hasTime: Bool
    /// The seconds of a range, such as `13:00-14:30`.
    public let length: TimeInterval?

    /// Reads the words. The finder can take a first word that names a time of day, such as `Lunch` in `Lunch tomorrow 13:00`,
    /// and when it takes all the words, the first word is the title while the rest gives the same date.
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

    /// Reads the words of an add, or fails with what they lack: any words, or a title beside the date.
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

    /// Whether the words gave a time and not only a day. The date finder says so in a key of its own, and with no such key
    /// a date at noon counts as a day, as the finder gives a day.
    static func hasTime(_ found: NSTextCheckingResult) -> Bool {
        let key = "timeIsSignificant"
        if found.responds(to: NSSelectorFromString(key)), let isSignificant = found.value(forKey: key) as? Bool { return isSignificant }
        guard let date = found.date else { return false }
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return (parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60 + (parts.second ?? 0) != noon
    }
}
