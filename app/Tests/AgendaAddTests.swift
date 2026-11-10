import XCTest
@testable import OpenspotCore

/// Proves `openspot calendar add` and `openspot reminders add` through `Agenda`, with a fake store and the real time now.
final class AgendaAddTests: XCTestCase {
    private let work = AgendaList(id: "A8E2", title: "Work", account: "iCloud", color: "#1BADF8")
    private let family = AgendaList(id: "7D10", title: "Family", account: "iCloud", color: nil)
    private let clock = Calendar.current

    private func tomorrow(_ hour: Int, _ minute: Int = 0) -> Date {
        let day = clock.date(byAdding: .day, value: 1, to: clock.startOfDay(for: Date()))!
        return clock.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private func store(access: AgendaAccess = .allowed) -> FakeAgendaStore {
        FakeAgendaStore(lists: [work], defaults: [.event: work, .reminder: family], access: access)
    }

    private func agenda(_ store: FakeAgendaStore, isRead: Bool = false) -> Agenda {
        Agenda(store: store, isRead: isRead)
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
        let store = store()

        let text = try await agenda(store).addEvent("Standup tomorrow 10am", isDry: false)
        let row = try row(text)

        XCTAssertEqual(store.addedEvents.map(\.title), ["Standup"])
        XCTAssertEqual(store.addedEvents.first?.start, tomorrow(10))
        XCTAssertEqual(store.addedEvents.first?.end, tomorrow(11))
        XCTAssertEqual(store.addedEvents.first?.isAllDay, false)
        XCTAssertEqual(row.value("row"), "event:saved-1/\(Int(tomorrow(10).timeIntervalSince1970))")
        XCTAssertEqual(row.value("start"), iso(tomorrow(10)))
        XCTAssertEqual(row.value("calendar"), "A8E2")
    }

    func testARangeSetsTheEndAndADayWithNoTimeMakesAnEventOfTheWholeDay() async throws {
        let store = store()

        _ = try await agenda(store).addEvent("Lunch tomorrow 13:00-14:30", isDry: false)
        _ = try await agenda(store).addEvent("Offsite tomorrow", isDry: false)

        XCTAssertEqual(store.addedEvents.first?.end, tomorrow(14, 30))
        XCTAssertEqual(store.addedEvents.last?.title, "Offsite")
        XCTAssertEqual(store.addedEvents.last?.isAllDay, true)
        XCTAssertEqual(store.addedEvents.last?.start, tomorrow(0))
        XCTAssertEqual(store.addedEvents.last?.end, clock.date(byAdding: .day, value: 1, to: tomorrow(0)))
    }

    func testAnEventNeedsADateAndATitle() async throws {
        let cases = [
            ("Buy milk", "Openspot found no date in `Buy milk`. Add one, such as `tomorrow 9am`."),
            ("tomorrow 9am", "Openspot found only a date in `tomorrow 9am`. Add a title, such as `Lunch tomorrow 13:00`."),
            ("  ", "Openspot needs words, such as `Lunch tomorrow 13:00`.")
        ]
        for (words, message) in cases {
            do {
                _ = try await agenda(store()).addEvent(words, isDry: false)
                XCTFail("\(words) was added")
            } catch PluginError.failed(1, let said) {
                XCTAssertEqual(said, message)
            }
        }
    }

    func testAReminderTakesItsTimeOrItsDayOrNoDate() async throws {
        let store = store()

        let timed = try row(try await agenda(store).addReminder("Call mom tomorrow 9am", isDry: false))
        let undated = try row(try await agenda(store).addReminder("Buy milk", isDry: false))
        _ = try await agenda(store).addReminder("Pay rent tomorrow", isDry: false)

        XCTAssertEqual(store.addedReminders.map(\.title), ["Call mom", "Buy milk", "Pay rent"])
        XCTAssertEqual(store.addedReminders.map(\.due), [tomorrow(9), nil, tomorrow(0)])
        XCTAssertEqual(store.addedReminders.map(\.isAllDay), [false, false, true])
        XCTAssertEqual(timed.value("row"), "reminder:saved-1")
        XCTAssertEqual(timed.value("due"), iso(tomorrow(9)))
        XCTAssertEqual(undated.value("detail"), "No date · Family")
    }

    func testADryRunPrintsTheRowItWouldAddAndSavesNothingAlsoInARead() async throws {
        let store = store()

        let event = try row(try await agenda(store, isRead: true).addEvent("Standup tomorrow 10am", isDry: true))
        let reminder = try row(try await agenda(store, isRead: true).addReminder("Call mom tomorrow 9am", isDry: true))

        XCTAssertEqual(event.value("row"), "event:new")
        XCTAssertEqual(event.value("title"), "Standup")
        XCTAssertEqual(event.value("calendar"), "A8E2")
        XCTAssertEqual(reminder.value("row"), "reminder:new")
        XCTAssertEqual(reminder.value("list"), "7D10")
        XCTAssertEqual(store.addedEvents, [])
        XCTAssertEqual(store.addedReminders, [])
    }

    func testAnAddWithNoDefaultCalendarSaysWhereToChooseOne() async throws {
        let store = FakeAgendaStore(lists: [], defaults: [:])

        do {
            _ = try await agenda(store).addEvent("Standup tomorrow 10am", isDry: false)
            XCTFail("an event was added with no calendar")
        } catch PluginError.failed(1, let said) {
            XCTAssertEqual(said, "Openspot found no calendar for new events. Choose a default calendar in Calendar › Settings › General, then try again.")
        }
    }

    func testAnAddOutsideAReadAsksForLeaveFirst() async throws {
        let store = FakeAgendaStore(lists: [], defaults: [.reminder: family], access: .unasked, answer: .allowed)

        _ = try await agenda(store).addReminder("Call mom", isDry: false)

        XCTAssertEqual(store.asked, [.reminder])
        XCTAssertEqual(store.addedReminders.count, 1)
    }
}
