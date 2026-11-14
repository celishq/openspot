import XCTest
@testable import OpenspotCore

final class CalendarAddTests: XCTestCase {
    private let work = CalendarList(id: "A8E2", title: "Work", account: "iCloud", color: "#1BADF8")
    private let family = CalendarList(id: "7D10", title: "Family", account: "iCloud", color: nil)
    private let clock = Calendar.current

    private func tomorrow(_ hour: Int, _ minute: Int = 0) -> Date {
        let day = clock.date(byAdding: .day, value: 1, to: clock.startOfDay(for: Date()))!
        return clock.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private func eventStore() -> FakeEventStore {
        FakeEventStore(calendars: [work], defaultCalendar: work)
    }

    private func reminderStore() -> FakeReminderStore {
        FakeReminderStore(defaultList: family)
    }

    private func events(_ store: FakeEventStore, isRead: Bool = false) -> Events {
        Events(store: store, isRead: isRead)
    }

    private func reminders(_ store: FakeReminderStore, isRead: Bool = false) -> Reminders {
        Reminders(store: store, isRead: isRead)
    }

    private func row(_ text: String) throws -> TextBlock {
        try XCTUnwrap(TextBlock.blocks(in: text).first)
    }

    private func iso(_ date: Date) -> String {
        let format = ISO8601DateFormatter()
        format.timeZone = clock.timeZone
        return format.string(from: date)
    }

    func testAnEventWithATimeLastsOneHourAndPrintsTheRowOfTheSavedEvent() async throws {
        let store = eventStore()

        let text = try await events(store).add("Standup tomorrow 10am", isDry: false)
        let row = try row(text)

        XCTAssertEqual(store.added.map(\.title), ["Standup"])
        XCTAssertEqual(store.added.first?.start, tomorrow(10))
        XCTAssertEqual(store.added.first?.end, tomorrow(11))
        XCTAssertEqual(store.added.first?.isAllDay, false)
        XCTAssertEqual(row.value("row"), "event:saved-1/\(Int(tomorrow(10).timeIntervalSince1970))")
        XCTAssertEqual(row.value("start"), iso(tomorrow(10)))
        XCTAssertEqual(row.value("calendar"), "A8E2")
    }

    func testARangeSetsTheEndAndADayWithNoTimeMakesAnEventOfTheWholeDay() async throws {
        let store = eventStore()

        _ = try await events(store).add("Lunch tomorrow 13:00-14:30", isDry: false)
        _ = try await events(store).add("Offsite tomorrow", isDry: false)

        XCTAssertEqual(store.added.first?.end, tomorrow(14, 30))
        XCTAssertEqual(store.added.last?.title, "Offsite")
        XCTAssertEqual(store.added.last?.isAllDay, true)
        XCTAssertEqual(store.added.last?.start, tomorrow(0))
        XCTAssertEqual(store.added.last?.end, clock.date(byAdding: .day, value: 1, to: tomorrow(0)))
    }

    func testAnEventNeedsADateAndATitle() async throws {
        let cases = [
            ("Buy milk", "Openspot found no date in `Buy milk`. Add one, such as `tomorrow 9am`."),
            ("tomorrow 9am", "Openspot found only a date in `tomorrow 9am`. Add a title, such as `Lunch tomorrow 13:00`."),
            ("  ", "Openspot needs words, such as `Lunch tomorrow 13:00`.")
        ]
        for (words, message) in cases {
            do {
                _ = try await events(eventStore()).add(words, isDry: false)
                XCTFail("\(words) was added")
            } catch SpotError.failed(1, let said) {
                XCTAssertEqual(said, message)
            }
        }
    }

    func testAReminderTakesItsTimeOrItsDayOrNoDate() async throws {
        let store = reminderStore()

        let timed = try row(try await reminders(store).add("Call mom tomorrow 9am", isDry: false))
        let undated = try row(try await reminders(store).add("Buy milk", isDry: false))
        _ = try await reminders(store).add("Pay rent tomorrow", isDry: false)

        XCTAssertEqual(store.added.map(\.title), ["Call mom", "Buy milk", "Pay rent"])
        XCTAssertEqual(store.added.map(\.due), [tomorrow(9), nil, tomorrow(0)])
        XCTAssertEqual(store.added.map(\.isAllDay), [false, false, true])
        XCTAssertEqual(timed.value("row"), "reminder:saved-1")
        XCTAssertEqual(timed.value("due"), iso(tomorrow(9)))
        XCTAssertEqual(undated.value("detail"), "No date · Family")
    }

    func testADryRunPrintsTheRowItWouldAddAndSavesNothingAlsoInARead() async throws {
        let eventStore = eventStore()
        let reminderStore = reminderStore()

        let event = try row(try await events(eventStore, isRead: true).add("Standup tomorrow 10am", isDry: true))
        let reminder = try row(try await reminders(reminderStore, isRead: true).add("Call mom tomorrow 9am", isDry: true))

        XCTAssertEqual(event.value("row"), "event:new")
        XCTAssertEqual(event.value("title"), "Standup")
        XCTAssertEqual(event.value("calendar"), "A8E2")
        XCTAssertEqual(reminder.value("row"), "reminder:new")
        XCTAssertEqual(reminder.value("list"), "7D10")
        XCTAssertEqual(eventStore.added, [])
        XCTAssertEqual(reminderStore.added, [])
    }

    func testAnAddWithNoDefaultCalendarSaysWhereToChooseOne() async throws {
        let store = FakeEventStore()

        do {
            _ = try await events(store).add("Standup tomorrow 10am", isDry: false)
            XCTFail("an event was added with no calendar")
        } catch SpotError.failed(1, let said) {
            XCTAssertEqual(said, "Openspot found no calendar for new events. Choose a default calendar in Calendar › Settings › General, then try again.")
        }
    }

    func testAnAddOutsideAReadAsksForLeaveFirst() async throws {
        let store = FakeReminderStore(defaultList: family, access: .unasked, answer: .allowed)

        _ = try await reminders(store).add("Call mom", isDry: false)

        XCTAssertEqual(store.asks, 1)
        XCTAssertEqual(store.added.count, 1)
    }
}
