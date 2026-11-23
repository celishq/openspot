import Foundation

enum DateCall: NounCall {
    case read(String)

    static let noun = CommandNoun("date", group: .mac, verbs: [
        CommandVerb(
            "read", "<words>...",
            "Prints the date that the words name, such as tomorrow 3pm, 25 dec or next friday, as item=yyyy-MM-dd, with HH:mm in the zone of the Mac when they name a time, and time=true or false. It prints nothing when the words are more than a date.",
            rule: CallRule(flags: .pure)
        ) { words in
            words.none ? nil : Self.read(words.rest.joined(separator: " "))
        }
    ])

    static func block(of words: String, now: Date? = nil, zone: TimeZone = .current) -> String {
        let text = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let found = TextFinds(text).date(now: now, zone: zone), found.range == text.startIndex..<text.endIndex else { return "" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: found.date)
        let two = { (number: Int?) in String(format: "%02d", number ?? 0) }
        let day = String(format: "%04d", parts.year ?? 0) + "-\(two(parts.month))-\(two(parts.day))"
        let item = found.hasTime ? "\(day) \(two(parts.hour)):\(two(parts.minute))" : day
        return TextBlock(fields: [.init(key: "item", value: item), .init(key: "time", value: found.hasTime ? "true" : "false")]).text
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard case .read(let words) = self else { return nil }
        return CommandAnswer.work { Self.block(of: words) }
    }
}
