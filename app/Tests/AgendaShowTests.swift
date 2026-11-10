import XCTest
@testable import OpenspotCore

/// Proves which day `openspot calendar show` opens for the id of a row, and which reminder `openspot reminders show` opens.
final class AgendaShowTests: XCTestCase {
    private let family = AgendaList(id: "7D10", title: "Family", account: "iCloud", color: nil)
    private let work = AgendaList(id: "A8E2", title: "Work", account: "iCloud", color: nil)
    private let now = Date(timeIntervalSince1970: 1_794_300_000)

    private func agenda(_ store: FakeAgendaStore) -> Agenda {
        Agenda(store: store, now: now, isRead: false)
    }

    private func id(_ text: String) throws -> String {
        try XCTUnwrap(TextBlock.blocks(in: text).first?.value("row"))
    }

    func testAnEventOpensOnTheDayOfItsTime() async throws {
        let start = now.addingTimeInterval(86_400)
        let store = FakeAgendaStore(events: [AgendaEvent(id: "daily", title: "Standup", start: start, end: start.addingTimeInterval(900), isAllDay: false, calendar: work, location: nil, url: nil, notes: nil)])
        let id = try id(try await agenda(store).events(days: 3, calendars: []))

        let day = try await agenda(store).day(of: id)

        XCTAssertEqual(day, start)
    }

    func testAReminderOpensOnItsDueDayOrTodayWithNone() async throws {
        let due = now.addingTimeInterval(-86_400)
        let store = FakeAgendaStore(reminders: [
            AgendaReminder(id: "late", title: "Call mom", due: due, isAllDay: false, list: family, doneAt: nil),
            AgendaReminder(id: "loose", title: "Buy milk", due: nil, isAllDay: false, list: family, doneAt: nil)
        ])
        let id = try id(try await agenda(store).due(days: 1, lists: []))

        let late = try await agenda(store).day(of: id)
        let loose = try await agenda(store).day(of: "reminder:loose")

        XCTAssertEqual(late, due)
        XCTAssertEqual(loose, now)
    }

    func testAReminderOpensInRemindersByItsOwnId() async throws {
        let store = FakeAgendaStore(reminders: [AgendaReminder(id: "9C41-B2", title: "Call mom", due: now, isAllDay: false, list: family, doneAt: nil)])
        let id = try id(try await agenda(store).due(days: 1, lists: []))

        let link = try await agenda(store).link(of: id)

        XCTAssertEqual(link.absoluteString, "x-apple-reminderkit://REMCDReminder/9C41-B2")
    }

    func testAReminderLinkOfAnIdThatNamesNoReminderFails() async throws {
        let store = FakeAgendaStore(events: [AgendaEvent(id: "daily", title: "Standup", start: now, end: now, isAllDay: false, calendar: work, location: nil, url: nil, notes: nil)])

        for id in ["reminder:gone", "event:daily/1794300000", "Standup"] {
            do {
                _ = try await agenda(store).link(of: id)
                XCTFail("\(id) gave a link")
            } catch PluginError.failed(1, let message) {
                XCTAssertEqual(message, "Openspot cannot find the reminder \(id). Read the list again, and use the id of one of its rows.")
            }
        }
    }

    func testAnIdThatNamesNothingFails() async throws {
        let store = FakeAgendaStore()

        for id in ["reminder:gone", "event:new", "event:daily", "event:daily/soon", "Standup"] {
            do {
                _ = try await agenda(store).day(of: id)
                XCTFail("\(id) opened a day")
            } catch PluginError.failed(1, let message) {
                XCTAssertEqual(message, "Openspot cannot find \(id). Read the list again, and use the id of one of its rows.")
            }
        }
    }
}
