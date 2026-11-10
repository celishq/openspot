import Foundation

/// A reminder in a list, open or done.
public struct Reminder: Equatable, Sendable {
    public let id: String
    public let title: String
    public let due: Date?
    /// Whether it is due on a day, with no time.
    public let isAllDay: Bool
    public let list: CalendarList
    public let doneAt: Date?

    public init(id: String, title: String, due: Date?, isAllDay: Bool, list: CalendarList, doneAt: Date?) {
        self.id = id
        self.title = title
        self.due = due
        self.isAllDay = isAllDay
        self.list = list
        self.doneAt = doneAt
    }

    /// Whether it is open and its time, or its day, has passed.
    func isLate(_ clock: CalendarClock) -> Bool {
        guard doneAt == nil, let due else { return false }
        return isAllDay ? due < clock.startOfToday : due < clock.now
    }

    /// Its row (E2). `done` holds whether it is ticked, so that a template can draw a tick.
    func row(_ clock: CalendarClock) -> TextBlock {
        let isLate = isLate(clock)
        var fields: [TextBlock.Field] = [
            .init(key: "row", value: CalendarItemID.reminder(id).text),
            .init(key: "title", value: title),
            .init(key: "detail", value: "\(when(clock, isLate: isLate)) · \(list.title)"),
            .init(key: "icon", value: doneAt == nil ? "circle" : "checkmark.circle.fill"),
            .init(key: "tone", value: isLate ? "bad" : ""),
            .init(key: "due", value: due.map(clock.iso) ?? ""),
            .init(key: "allday", value: isAllDay ? "true" : ""),
            .init(key: "list", value: list.id),
            .init(key: "color", value: list.color ?? ""),
            .init(key: "done", value: doneAt == nil ? "false" : "true")
        ]
        fields.removeAll { $0.value.isEmpty }
        return TextBlock(fields: fields)
    }

    /// When it is due, in words: `Done`, or `Late` and its time, or its day and time with no day for today.
    private func when(_ clock: CalendarClock, isLate: Bool) -> String {
        guard doneAt == nil else { return "Done" }
        guard let due else { return "No date" }
        let time = isAllDay ? nil : clock.time(due)
        let day = clock.day(due) ?? (time == nil ? "Today" : nil)
        let words = [day, time].compactMap(\.self).joined(separator: " ")
        return isLate ? "Late · \(words)" : words
    }
}
