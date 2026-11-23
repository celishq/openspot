import Foundation

public struct CronLine: Equatable, Sendable {
    private static let ranges = [0...59, 0...23, 1...31, 1...12, 0...7]

    public let text: String
    private let fields: [Set<Int>]
    private let isAnyDay: Bool
    private let isAnyWeekday: Bool

    public init?(_ text: String) {
        let parts = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count == Self.ranges.count else { return nil }
        var fields: [Set<Int>] = []
        for (part, range) in zip(parts, Self.ranges) {
            guard let field = Self.field(part, in: range) else { return nil }
            fields.append(field)
        }
        fields[4] = Set(fields[4].map { $0 % 7 })
        self.text = parts.joined(separator: " ")
        self.fields = fields
        isAnyDay = parts[2] == "*"
        isAnyWeekday = parts[4] == "*"
    }

    public func next(after date: Date, calendar: Calendar = .current) -> Date? {
        guard let start = calendar.date(byAdding: .minute, value: 1, to: date),
              let minute = calendar.dateInterval(of: .minute, for: start)?.start,
              var day = calendar.dateInterval(of: .day, for: minute)?.start
        else { return nil }
        for _ in 0..<(366 * 5) {
            let parts = calendar.dateComponents([.month, .day, .weekday], from: day)
            if let month = parts.month, let monthDay = parts.day, let weekday = parts.weekday, fields[3].contains(month), matches(day: monthDay, weekday: weekday - 1) {
                for hour in fields[1].sorted() {
                    for each in fields[0].sorted() {
                        guard let time = calendar.date(bySettingHour: hour, minute: each, second: 0, of: day) else { continue }
                        if time >= minute { return time }
                    }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            day = next
        }
        return nil
    }

    private func matches(day: Int, weekday: Int) -> Bool {
        let isDay = fields[2].contains(day)
        let isWeekday = fields[4].contains(weekday)
        if isAnyDay || isAnyWeekday { return isDay && isWeekday }
        return isDay || isWeekday
    }

    private static func field(_ text: String, in range: ClosedRange<Int>) -> Set<Int>? {
        var values = Set<Int>()
        for part in text.split(separator: ",", omittingEmptySubsequences: false) {
            let pieces = part.split(separator: "/", omittingEmptySubsequences: false)
            guard (1...2).contains(pieces.count) else { return nil }
            let step = pieces.count == 2 ? Int(pieces[1]) : 1
            guard let step, step > 0 else { return nil }
            let span: ClosedRange<Int>
            if pieces[0] == "*" {
                span = range
            } else {
                let ends = pieces[0].split(separator: "-", omittingEmptySubsequences: false).map { Int($0) }
                guard (1...2).contains(ends.count), let low = ends.first ?? nil, let high = ends.last ?? nil, range.contains(low), range.contains(high), low <= high else { return nil }
                span = low...(ends.count == 1 && pieces.count == 2 ? range.upperBound : high)
            }
            values.formUnion(stride(from: span.lowerBound, through: span.upperBound, by: step))
        }
        return values
    }
}
