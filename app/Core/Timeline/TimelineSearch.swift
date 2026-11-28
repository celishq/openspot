import Foundation

struct TimelineSearch: Sendable {
    struct Fault: Error {
        let message: String
    }

    let text: String

    func query(from base: Timeline.Query, at now: Date) throws(Fault) -> Timeline.Query {
        var query = base
        var words: [Substring] = []
        for word in text.split(whereSeparator: \.isWhitespace) {
            guard let colon = word.firstIndex(of: ":"), colon > word.startIndex else {
                words.append(word)
                continue
            }
            let value = String(word[word.index(after: colon)...])
            switch word[..<colon].lowercased() {
            case "spot": if !value.isEmpty { query.about = value }
            case "since": if !value.isEmpty { query.within = try Self.age(value, at: now) }
            case "sort": if !value.isEmpty { query.order = try Self.order(value) }
            default: words.append(word)
            }
        }
        query.text = words.isEmpty ? nil : words.joined(separator: " ")
        return query
    }

    private static func age(_ value: String, at now: Date) throws(Fault) -> TimeInterval {
        if value.lowercased() == "today" { return max(1, now.timeIntervalSince(Calendar.current.startOfDay(for: now))) }
        guard let age = Manifest.Triggers.age(orSeconds: value), age > 0 else {
            throw Fault(message: "since: takes an age, such as 30m, 2h or 7d, or today.")
        }
        return age
    }

    private static func order(_ value: String) throws(Fault) -> Timeline.Order {
        guard let order = Timeline.Order(rawValue: value) else { throw Fault(message: "sort: takes newest or oldest.") }
        return order
    }
}
