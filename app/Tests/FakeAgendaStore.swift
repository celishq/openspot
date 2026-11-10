import Foundation
@testable import OpenspotCore

/// A store of events and reminders in memory that answers as EventKit does: each event that overlaps a range, each open
/// reminder due before its end, and each reminder done since its start.
final class FakeAgendaStore: AgendaStore {
    struct Range: Equatable {
        let start: Date
        let end: Date
        let calendars: [String]
    }

    struct Mark: Equatable {
        let id: String
        let isDone: Bool
    }

    private let allEvents: [AgendaEvent]
    private var allReminders: [AgendaReminder]
    private let allLists: [AgendaList]
    private(set) var access: AgendaAccess
    private let answer: AgendaAccess
    private(set) var asked: [AgendaKind] = []
    private(set) var ranges: [Range] = []
    private(set) var listed: [AgendaKind] = []
    private(set) var marks: [Mark] = []

    init(events: [AgendaEvent] = [], reminders: [AgendaReminder] = [], lists: [AgendaList] = [], access: AgendaAccess = .allowed, answer: AgendaAccess = .allowed) {
        allEvents = events
        allReminders = reminders
        allLists = lists
        self.access = access
        self.answer = answer
    }

    func access(to kind: AgendaKind) -> AgendaAccess {
        access
    }

    func ask(for kind: AgendaKind) async -> AgendaAccess {
        asked.append(kind)
        access = answer
        return answer
    }

    func events(from start: Date, to end: Date, in calendars: [String]) -> [AgendaEvent] {
        ranges.append(Range(start: start, end: end, calendars: calendars))
        return allEvents.filter { $0.start < end && $0.end > start }
    }

    func reminders(dueBefore end: Date, doneSince start: Date, in lists: [String]) async -> [AgendaReminder] {
        ranges.append(Range(start: start, end: end, calendars: lists))
        return allReminders.filter { reminder in
            guard let done = reminder.doneAt else { return reminder.due.map { $0 < end } ?? false }
            return done >= start
        }
    }

    func mark(reminder id: String, done: Bool) throws -> Bool {
        guard allReminders.contains(where: { $0.id == id }) else { return false }
        marks.append(Mark(id: id, isDone: done))
        return true
    }

    func lists(of kind: AgendaKind) -> [AgendaList] {
        listed.append(kind)
        return allLists
    }
}
