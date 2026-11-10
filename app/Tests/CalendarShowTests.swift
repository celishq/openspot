import XCTest
@testable import OpenspotCore

/// Proves which day `openspot calendar show` opens for the id of an event, and which reminder `openspot reminders show` opens.
final class CalendarShowTests: XCTestCase {
    private let family = CalendarList(id: "7D10", title: "Family", account: "iCloud", color: nil)
    private let work = CalendarList(id: "A8E2", title: "Work", account: "iCloud", color: nil)
    private let now = Date(timeIntervalSince1970: 1_794_300_000)

    private func events(_ store: FakeEventStore) -> Events {
        Events(store: store, now: now, isRead: false)
    }

    private func reminders(_ store: FakeReminderStore) -> Reminders {
        Reminders(store: store, now: now, isRead: false)
    }

    private func id(_ text: String) throws -> String {
        try XCTUnwrap(TextBlock.blocks(in: text).first?.value("row"))
    }

    func testAnEventOpensOnTheDayOfItsTime() async throws {
        let start = now.addingTimeInterval(86_400)
        let store = FakeEventStore(events: [Event(id: "daily", title: "Standup", start: start, end: start.addingTimeInterval(900), isAllDay: false, calendar: work, location: nil, url: nil, notes: nil)])
        let id = try id(try await events(store).events(days: 3, hiding: []))

        let day = try await events(store).day(of: id)

        XCTAssertEqual(day, start)
    }

    func testAReminderSaysToShowItInReminders() async throws {
        let reminders = FakeReminderStore(reminders: [Reminder(id: "late", title: "Call mom", due: now, isAllDay: false, list: family, doneAt: nil)])
        let id = try id(try await self.reminders(reminders).due(days: 1, hiding: []))

        do {
            _ = try await events(FakeEventStore()).day(of: id)
            XCTFail("\(id) opened a day")
        } catch PluginError.failed(1, let message) {
            XCTAssertEqual(message, "\(id) is a reminder. Run `openspot reminders show \(id)` to open it in Reminders.")
        }
    }

    func testAReminderOpensInRemindersByItsOwnId() async throws {
        let store = FakeReminderStore(reminders: [Reminder(id: "9C41-B2", title: "Call mom", due: now, isAllDay: false, list: family, doneAt: nil)])
        let id = try id(try await reminders(store).due(days: 1, hiding: []))

        let link = try await reminders(store).link(of: id)

        XCTAssertEqual(link.absoluteString, "x-apple-reminderkit://REMCDReminder/9C41-B2")
    }

    func testAReminderLinkOfAnIdThatNamesNoReminderFails() async throws {
        let store = FakeReminderStore()

        for id in ["reminder:gone", "event:daily/1794300000", "Standup"] {
            do {
                _ = try await reminders(store).link(of: id)
                XCTFail("\(id) gave a link")
            } catch PluginError.failed(1, let message) {
                XCTAssertEqual(message, "Openspot cannot find \(id). Read the list again, and use the id of one of its rows.")
            }
        }
    }

    func testAnIdThatNamesNothingFails() async throws {
        let store = FakeEventStore()

        for id in ["event:new", "event:daily", "event:daily/soon", "Standup"] {
            do {
                _ = try await events(store).day(of: id)
                XCTFail("\(id) opened a day")
            } catch PluginError.failed(1, let message) {
                XCTAssertEqual(message, "Openspot cannot find \(id). Read the list again, and use the id of one of its rows.")
            }
        }
    }
}
