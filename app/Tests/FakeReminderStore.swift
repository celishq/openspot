import Foundation
@testable import OpenspotCore

final class FakeReminderStore: ReminderStore {
    struct Range: Equatable {
        let start: Date
        let end: Date
        let hidden: [String]
    }

    struct Mark: Equatable {
        let id: String
        let isDone: Bool
    }

    private let allReminders: [Reminder]
    private let allLists: [CalendarList]
    private let list: CalendarList?
    private var state: CalendarAccess
    private let answer: CalendarAccess
    private(set) var asks = 0
    private(set) var ranges: [Range] = []
    private(set) var marks: [Mark] = []
    private(set) var added: [Reminder] = []

    init(reminders: [Reminder] = [], lists: [CalendarList] = [], defaultList: CalendarList? = nil, access: CalendarAccess = .allowed, answer: CalendarAccess = .allowed) {
        allReminders = reminders
        allLists = lists
        list = defaultList
        state = access
        self.answer = answer
    }

    func access() -> CalendarAccess {
        state
    }

    func ask() async -> CalendarAccess {
        asks += 1
        state = answer
        return answer
    }

    func reminders(dueBefore end: Date, doneSince start: Date, hiding hidden: [String]) async -> [Reminder] {
        ranges.append(Range(start: start, end: end, hidden: hidden))
        return allReminders.filter { reminder in
            guard let done = reminder.doneAt else { return reminder.due.map { $0 < end } ?? false }
            return done >= start
        }
    }

    func reminder(_ id: String) -> Reminder? {
        allReminders.first { $0.id == id }
    }

    func mark(reminder id: String, done: Bool) throws -> Bool {
        guard allReminders.contains(where: { $0.id == id }) else { return false }
        marks.append(Mark(id: id, isDone: done))
        return true
    }

    func lists() -> [CalendarList] {
        allLists
    }

    func defaultList() -> CalendarList? {
        list
    }

    func add(_ reminder: Reminder) throws -> Reminder {
        added.append(reminder)
        return Reminder(id: "saved-\(added.count)", title: reminder.title, due: reminder.due, isAllDay: reminder.isAllDay, list: list!, doneAt: nil)
    }
}
