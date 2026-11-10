import Foundation

/// The events and the reminders of the person as the rows that `openspot calendar` and `openspot reminders` print (E1).
/// A read never asks for leave: it says `status=unasked`, and a call outside a read asks (E6, E7).
public struct Agenda {
    static let unasked = "status=unasked\n"

    private let store: any AgendaStore
    private let clock: AgendaClock
    private let isRead: Bool

    public init(store: any AgendaStore, now: Date = Date(), clock: Calendar = .current, locale: Locale = .current, isRead: Bool) {
        self.store = store
        self.clock = AgendaClock(now: now, calendar: clock, locale: locale)
        self.isRead = isRead
    }

    /// Each event that has not ended, through the end of a day, in the order of its start.
    public func events(days: Int, calendars: [String]) async throws -> String {
        guard try await isAllowed(.event) else { return Self.unasked }
        let events = store.events(from: clock.now, to: clock.end(ofDay: days), in: calendars)
            .filter { $0.end > clock.now }
            .sorted { first, second in
                if first.start != second.start { return first.start < second.start }
                if first.isAllDay != second.isAllDay { return first.isAllDay }
                return first.title < second.title
            }
        return Self.text(events.map { $0.row(clock) })
    }

    public func calendars() async throws -> String {
        guard try await isAllowed(.event) else { return Self.unasked }
        return Self.text(store.lists(of: .event).map(\.row))
    }

    /// Whether the store may be read. A read that has not asked returns false, a call outside a read asks first, and a
    /// refusal fails with the pane that fixes it (E8).
    private func isAllowed(_ kind: AgendaKind) async throws -> Bool {
        var access = store.access(to: kind)
        if access == .unasked {
            guard !isRead else { return false }
            access = await store.ask(for: kind)
        }
        guard access == .allowed else { throw PluginError.failedWithFix(1, kind.refusal, kind.pane) }
        return true
    }

    private static func text(_ rows: [TextBlock]) -> String {
        rows.map { $0.text + "\n" }.joined()
    }
}
