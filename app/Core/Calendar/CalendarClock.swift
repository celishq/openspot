import Foundation

struct CalendarClock {
    let now: Date
    let calendar: Calendar
    let locale: Locale

    var startOfToday: Date {
        calendar.startOfDay(for: now)
    }

    func end(ofDay day: Int) -> Date {
        calendar.date(byAdding: .day, value: day, to: startOfToday) ?? now
    }

    func iso(_ date: Date) -> String {
        let format = ISO8601DateFormatter()
        format.timeZone = calendar.timeZone
        format.formatOptions = [.withInternetDateTime]
        return format.string(from: date)
    }

    func time(_ date: Date) -> String {
        let format = DateFormatter()
        format.locale = locale
        format.timeZone = calendar.timeZone
        format.dateStyle = .none
        format.timeStyle = .short
        return format.string(from: date)
    }

    func day(_ date: Date) -> String? {
        let distance = calendar.dateComponents([.day], from: startOfToday, to: calendar.startOfDay(for: date)).day ?? 0
        guard distance != 0 else { return nil }
        if abs(distance) == 1 {
            let word = RelativeDateTimeFormatter()
            word.locale = locale
            word.dateTimeStyle = .named
            word.formattingContext = .beginningOfSentence
            return word.localizedString(from: DateComponents(day: distance))
        }
        let format = DateFormatter()
        format.locale = locale
        format.timeZone = calendar.timeZone
        format.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return format.string(from: date)
    }
}
