import Foundation

public struct Events {
    private static let pane = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
    private static let refusal = "Openspot has no access to your calendars. Allow Openspot in Privacy & Security › Calendars, then try again."

    private let store: any EventStore
    private let clock: CalendarClock
    private let isRead: Bool

    public init(store: any EventStore, now: Date = Date(), clock: Calendar = .current, locale: Locale = .current, isRead: Bool) {
        self.store = store
        self.clock = CalendarClock(now: now, calendar: clock, locale: locale)
        self.isRead = isRead
    }

    public func events(days: Int, hiding hidden: [String]) async throws -> String {
        guard try await isAllowed() else { return CalendarAccess.unaskedText }
        let events = store.events(from: clock.now, to: clock.end(ofDay: days), hiding: hidden)
            .filter { $0.end > clock.now }
            .sorted { first, second in
                if first.start != second.start { return first.start < second.start }
                if first.isAllDay != second.isAllDay { return first.isAllDay }
                return first.title < second.title
            }
        return Self.text(events.map { $0.row(clock) })
    }

    public func calendars() async throws -> String {
        guard try await isAllowed() else { return CalendarAccess.unaskedText }
        return Self.text(store.calendars().map(\.row))
    }

    public func day(of id: String) async throws -> Date {
        switch CalendarItemID(id) {
        case .event(_, let start)?: return start
        case .reminder?: throw SpotError.failed(1, "\(id) is a reminder. Run `openspot reminders show \(id)` to open it in Reminders.")
        case nil: throw CalendarItemID.missing(id)
        }
    }

    public func add(_ words: String, isDry: Bool) async throws -> String {
        let entry = try CalendarEntry(titled: words)
        guard let date = entry.date else {
            let trimmed = words.trimmingCharacters(in: .whitespacesAndNewlines)
            throw SpotError.failed(1, "Openspot found no date in `\(trimmed)`. Add one, such as `tomorrow 9am`.")
        }
        guard try await isAllowed() else { return CalendarAccess.unaskedText }
        guard let calendar = store.defaultCalendar() else {
            throw SpotError.failed(1, "Openspot found no calendar for new events. Choose a default calendar in Calendar › Settings › General, then try again.")
        }
        let start = entry.hasTime ? date : clock.calendar.startOfDay(for: date)
        let end = entry.hasTime ? start.addingTimeInterval(entry.length ?? 3600) : clock.calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let event = Event(id: "new", title: entry.title, start: start, end: end, isAllDay: !entry.hasTime, calendar: calendar, location: nil, url: nil, notes: nil)
        guard !isDry else { return Self.text([TextBlock(fields: [.init(key: "row", value: "event:new")] + event.row(clock).fields.dropFirst())]) }
        return Self.text([try store.add(event).row(clock)])
    }

    private func isAllowed() async throws -> Bool {
        try await store.isAllowed(isRead: isRead, refusal: Self.refusal, pane: Self.pane)
    }

    private static func text(_ rows: [TextBlock]) -> String {
        rows.map { $0.text + "\n" }.joined()
    }
}
