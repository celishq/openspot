import Foundation

/// The time now, with the calendar, the zone and the language in which an agenda writes each time.
struct AgendaClock {
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
    func day(_ date: Date) -> String? {
        let distance = calendar.dateComponents([.day], from: startOfToday, to: calendar.startOfDay(for: date)).day ?? 0
        guard distance != 0 else { return nil }
        let format = DateFormatter()
        format.locale = locale
        format.timeZone = calendar.timeZone
        if abs(distance) == 1 {
            format.dateStyle = .medium
            format.timeStyle = .none
            format.doesRelativeDateFormatting = true
        } else {
            format.setLocalizedDateFormatFromTemplate("EEEdMMM")
        }
        return format.string(from: date)
    }
}
