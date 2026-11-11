import Foundation

/// The time now, with the calendar, the zone and the language in which a row writes each time.
struct CalendarClock {
    let now: Date
    let calendar: Calendar
    let locale: Locale

    var startOfToday: Date {
        calendar.startOfDay(for: now)
    }

    /// The end of a day, where day 1 is today.
    func end(ofDay day: Int) -> Date {
        calendar.date(byAdding: .day, value: day, to: startOfToday) ?? now
    }

    /// The time in ISO 8601, with the offset of the zone.
    func iso(_ date: Date) -> String {
        let format = ISO8601DateFormatter()
        format.timeZone = calendar.timeZone
        format.formatOptions = [.withInternetDateTime]
        return format.string(from: date)
    }

    /// The time of day, such as 09:30, as the language of the Mac writes it.
    func time(_ date: Date) -> String {
        let format = DateFormatter()
        format.locale = locale
        format.timeZone = calendar.timeZone
        format.dateStyle = .none
        format.timeStyle = .short
        return format.string(from: date)
    }

    /// The name of the day of a time: nil for today, the word for the day before or after, and else its weekday and date.
    /// The day before or after counts from `now`, while the formatter's words count from the system date.
    func day(_ date: Date) -> String? {
        let distance = calendar.dateComponents([.day], from: startOfToday, to: calendar.startOfDay(for: date)).day ?? 0
        guard distance != 0 else { return nil }
        let format = DateFormatter()
        format.locale = locale
        format.timeZone = calendar.timeZone
        guard abs(distance) == 1 else {
            format.setLocalizedDateFormatFromTemplate("EEEdMMM")
            return format.string(from: date)
        }
        format.dateStyle = .medium
        format.timeStyle = .none
        format.doesRelativeDateFormatting = true
        let today = calendar.startOfDay(for: Date())
        return format.string(from: calendar.date(byAdding: .day, value: distance, to: today) ?? date)
    }
}
