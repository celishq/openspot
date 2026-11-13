import Foundation

/// A typed sum of dates and times: a date moved by lengths, such as `today + 3 weeks`; a count to or from a date, such as
/// `days until 25 dec`; the days between two dates; a time in another zone, such as `3pm tokyo in kyiv`; or a date alone,
/// such as `next friday`. `now`, `today`, `tomorrow` and `yesterday` read from the clock, and other dates from the date
/// finder of macOS. A count since a date with no year counts from its last time, not its next.
struct CalcDate {
    let value: String
    let title: String
    let detail: String

    private static let units: [String: Calendar.Component] = [
        "d": .day, "day": .day, "days": .day, "w": .weekOfYear, "wk": .weekOfYear, "week": .weekOfYear, "weeks": .weekOfYear,
        "mo": .month, "month": .month, "months": .month, "y": .year, "yr": .year, "year": .year, "years": .year,
        "h": .hour, "hr": .hour, "hour": .hour, "hours": .hour, "min": .minute, "mins": .minute, "minute": .minute, "minutes": .minute,
    ]
    private static let relative = ["today", "tomorrow", "yesterday", "now", "next", "last", "in", "ago"]

    init?(text: String, locale: Locale, clock: Calendar, now: Date) {
        let text = text.lowercased().trimmingCharacters(in: .whitespaces)
        let format = Format(locale: locale, clock: clock)
        if let moved = Self.moved(text, format, now) {
            self = moved
        } else if let count = Self.count(text, format, now) {
            self = count
        } else if let zoned = Self.zoned(text, format, now) {
            self = zoned
        } else if let alone = Self.alone(text, format, now) {
            self = alone
        } else {
            return nil
        }
    }

    private init(value: String, title: String, detail: String) {
        self.value = value
        self.title = title
        self.detail = detail
    }

    /// `<date> + <n> <unit>`, with as many lengths as it has.
    private static func moved(_ text: String, _ format: Format, _ now: Date) -> CalcDate? {
        guard let match = text.firstMatch(of: /^(.+?)\s*((?:[+-]\s*\d+\s*[a-z]+\s*)+)$/),
              let start = moment(String(match.1), format.clock, now) else { return nil }
        var date = start.date
        var hasTime = start.hasTime
        for length in match.2.matches(of: /([+-])\s*(\d+)\s*([a-z]+)/) {
            guard let unit = units[String(length.3)], let count = Int(length.2),
                  let next = format.clock.date(byAdding: unit, value: length.1 == "-" ? -count : count, to: date) else { return nil }
            date = next
            hasTime = hasTime || unit == .hour || unit == .minute
        }
        let lengths = match.2.trimmingCharacters(in: .whitespaces).replacing(/([+-])\s*/) { "\($0.1) " }
        return CalcDate(value: format.value(date, hasTime: hasTime), title: format.day(date, hasTime: hasTime), detail: "\(format.day(start.date, hasTime: start.hasTime)) \(lengths)")
    }

    /// `<unit> until <date>` or `<unit> since <date>`, and `<date> - <date>` in days.
    private static func count(_ text: String, _ format: Format, _ now: Date) -> CalcDate? {
        let unit: Calendar.Component
        var from: (date: Date, hasTime: Bool)
        var to: (date: Date, hasTime: Bool)
        if let match = text.firstMatch(of: /^(days|weeks|months|years|hours|minutes)\s+(until|till|to|before|since|from|after)\s+(.+)$/) {
            guard let named = units[String(match.1)], var date = moment(String(match.3), format.clock, now) else { return nil }
            unit = named
            let start = (date: now, hasTime: true)
            let isSince = ["since", "from", "after"].contains(String(match.2))
            if isSince, match.3.firstMatch(of: /\d{4}/) == nil {
                let step: Calendar.Component = format.clock.isDate(date.date, inSameDayAs: now) ? .day : .year
                while date.date > now, let earlier = format.clock.date(byAdding: step, value: -1, to: date.date) { date.date = earlier }
            }
            (from, to) = isSince ? (date, start) : (start, date)
        } else if let match = text.firstMatch(of: /^(.+?)\s+-\s+(.+)$/),
                  let later = moment(String(match.1), format.clock, now), let earlier = moment(String(match.2), format.clock, now) {
            unit = .day
            (from, to) = (earlier, later)
        } else {
            return nil
        }
        if ![.hour, .minute].contains(unit) {
            from.date = format.clock.startOfDay(for: from.date)
            to.date = format.clock.startOfDay(for: to.date)
        }
        guard let count = format.clock.dateComponents([unit], from: from.date, to: to.date).value(for: unit) else { return nil }
        let detail = "\(format.day(from.date, hasTime: from.hasTime && [.hour, .minute].contains(unit))) to \(format.day(to.date, hasTime: to.hasTime && [.hour, .minute].contains(unit)))"
        return CalcDate(value: String(count), title: format.length(count, unit), detail: detail)
    }

    /// `<time> [zone] in <zone>`, such as `3pm tokyo in kyiv`, or `now in <zone>`.
    private static func zoned(_ text: String, _ format: Format, _ now: Date) -> CalcDate? {
        for match in text.matches(of: /\s+in\s+/).reversed() {
            guard let target = zone(String(text[match.range.upperBound...])) else { continue }
            let source = String(text[..<match.range.lowerBound])
            let moment: (date: Date, zone: TimeZone)
            if ["now", "time", "the time"].contains(source) {
                moment = (now, format.clock.timeZone)
            } else if let time = source.firstMatch(of: /^(?:(\d{1,2})(?::(\d{2}))?\s*(am|pm)?|(noon)|(midnight))\s*(.*)$/) {
                var hour = time.1.flatMap { Int($0) } ?? (time.4 != nil ? 12 : 0)
                let minute = time.2.flatMap { Int($0) } ?? 0
                if time.3 == "pm", hour < 12 { hour += 12 }
                if time.3 == "am", hour == 12 { hour = 0 }
                let rest = String(time.6)
                guard hour < 24, minute < 60, let from = rest.isEmpty ? format.clock.timeZone : zone(rest) else { continue }
                var clock = format.clock
                clock.timeZone = from
                guard let date = clock.date(bySettingHour: hour, minute: minute, second: 0, of: now) else { continue }
                moment = (date, from)
            } else {
                continue
            }
            return CalcDate(
                value: format.value(moment.date, hasTime: true, in: target),
                title: format.time(moment.date, in: target),
                detail: "\(format.time(moment.date, in: moment.zone)) · \(name(of: moment.zone))"
            )
        }
        return nil
    }

    /// A date with nothing else, when it holds a digit or a word such as `next`, so that a word such as `may` is no date.
    private static func alone(_ text: String, _ format: Format, _ now: Date) -> CalcDate? {
        let words = text.split(separator: " ").map(String.init)
        guard text.contains(where: \.isNumber) || words.contains(where: relative.contains),
              text.firstMatch(of: /^\d{1,2}(:\d{2})?\s*(am|pm)?$/) == nil,
              let date = moment(text, format.clock, now) else { return nil }
        return CalcDate(value: format.value(date.date, hasTime: date.hasTime), title: format.day(date.date, hasTime: date.hasTime), detail: text)
    }

    /// The moment of a whole text: a word of the clock, or a date that the finder reads from all of it.
    private static func moment(_ text: String, _ clock: Calendar, _ now: Date) -> (date: Date, hasTime: Bool)? {
        let today = clock.startOfDay(for: now)
        switch text.trimmingCharacters(in: .whitespaces) {
        case "now": return (now, true)
        case "today": return (today, false)
        case "tomorrow": return clock.date(byAdding: .day, value: 1, to: today).map { ($0, false) }
        case "yesterday": return clock.date(byAdding: .day, value: -1, to: today).map { ($0, false) }
        default:
            guard let found = CalcFormats.dates?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  found.range == NSRange(text.startIndex..., in: text), let date = found.date else { return nil }
            return (date, CalendarEntry.hasTime(found))
        }
    }

    /// The zone of a city, such as `tokyo` or `new york`, or of an abbreviation, such as `utc` or `pst`.
    private static func zone(_ name: String) -> TimeZone? {
        let name = name.trimmingCharacters(in: .whitespaces)
        if let abbreviation = TimeZone.abbreviationDictionary[name.uppercased()] { return TimeZone(identifier: abbreviation) }
        let identifier = TimeZone.knownTimeZoneIdentifiers.first { identifier in
            identifier.split(separator: "/").last?.replacingOccurrences(of: "_", with: " ").lowercased() == name
        }
        return identifier.flatMap(TimeZone.init(identifier:))
    }

    private static func name(of zone: TimeZone) -> String {
        zone.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? zone.identifier
    }

    /// The ways of the Mac to write a date, a time, a value and a length.
    private struct Format {
        let locale: Locale
        let clock: Calendar

        func day(_ date: Date, hasTime: Bool) -> String {
            written(date, hasTime ? "EEEdMMMyyyyjmm" : "EEEdMMMyyyy", in: clock.timeZone)
        }

        func time(_ date: Date, in zone: TimeZone) -> String {
            written(date, "EEEjmm", in: zone)
        }

        /// A date as `2026-12-02`, or `2026-12-02 15:00` with its time.
        func value(_ date: Date, hasTime: Bool, in zone: TimeZone? = nil) -> String {
            let zone = zone ?? clock.timeZone
            let pattern = hasTime ? "yyyy-MM-dd HH:mm" : "yyyy-MM-dd"
            let formatter = CalcFormats.formatter(DateFormatter.self, "value|\(pattern)|\(zone.identifier)") {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = zone
                formatter.dateFormat = pattern
                return formatter
            }
            return formatter.string(from: date)
        }

        func length(_ count: Int, _ unit: Calendar.Component) -> String {
            let allowed: NSCalendar.Unit = unit == .weekOfYear ? .weekOfMonth : Self.unit(unit)
            let formatter = CalcFormats.formatter(DateComponentsFormatter.self, "length|\(allowed.rawValue)|\(CalcFormats.key(locale, clock))") {
                let formatter = DateComponentsFormatter()
                formatter.unitsStyle = .full
                var calendar = clock
                calendar.locale = locale
                formatter.calendar = calendar
                formatter.allowedUnits = allowed
                return formatter
            }
            var parts = DateComponents()
            switch unit {
            case .weekOfYear: parts.weekOfMonth = count
            default: parts.setValue(count, for: unit)
            }
            return formatter.string(from: parts) ?? String(count)
        }

        private static func unit(_ component: Calendar.Component) -> NSCalendar.Unit {
            switch component {
            case .year: .year
            case .month: .month
            case .hour: .hour
            case .minute: .minute
            default: .day
            }
        }

        private func written(_ date: Date, _ template: String, in zone: TimeZone) -> String {
            let formatter = CalcFormats.formatter(DateFormatter.self, "written|\(template)|\(CalcFormats.key(locale, clock, zone))") {
                let formatter = DateFormatter()
                formatter.locale = locale
                formatter.calendar = clock
                formatter.timeZone = zone
                formatter.setLocalizedDateFormatFromTemplate(template)
                return formatter
            }
            return formatter.string(from: date)
        }
    }
}
