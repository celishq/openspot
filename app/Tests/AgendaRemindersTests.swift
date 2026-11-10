import XCTest
@testable import OpenspotCore

/// Proves `openspot reminders due`, `lists` and `done` through `Agenda`, with a fake store in place of EventKit.
final class AgendaRemindersTests: XCTestCase {
    private let family = AgendaList(id: "7D10", title: "Family", account: "iCloud", color: "#FF9500")

    private var clock: Calendar {
        var clock = Calendar(identifier: .gregorian)
        clock.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return clock
    }

    /// Tuesday 10 November 2026 at the hour and minute in Berlin, or on another day.
    private func at(_ hour: Int, _ minute: Int = 0, day: Int = 10) -> Date {
        clock.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func reminder(_ id: String, _ title: String, due: Date?, allDay: Bool = false, doneAt: Date? = nil) -> AgendaReminder {
        AgendaReminder(id: id, title: title, due: due, isAllDay: allDay, list: family, doneAt: doneAt)
    }

    private func agenda(_ store: FakeAgendaStore, isRead: Bool = true) -> Agenda {
        Agenda(store: store, now: at(9, 40), clock: clock, locale: Locale(identifier: "en_GB"), isRead: isRead)
    }

    private func rows(_ text: String) -> [TextBlock] {
        TextBlock.blocks(in: text)
    }

    func testDueHoldsLateAndTodaysRemindersAndThoseDoneTodayInTheOrderOfTheirDueTime() async throws {
        let store = FakeAgendaStore(reminders: [
            reminder("evening", "Water the plants", due: at(18)),
            reminder("tomorrow", "Pay rent", due: at(9, day: 11)),
            reminder("late", "Call mom", due: at(18, day: 9)),
            reminder("ticked", "Take pills", due: at(8), doneAt: at(8, 5)),
            reminder("day", "Buy stamps", due: at(0), allDay: true),
            reminder("someday", "Read a book", due: nil)
        ])

        let rows = rows(try await agenda(store).due(days: 1, hiding: []))

        XCTAssertEqual(rows.map { $0.value("title") }, ["Call mom", "Buy stamps", "Take pills", "Water the plants"])
        XCTAssertEqual(rows.map { $0.value("detail") }, ["Late · Yesterday 18:00 · Family", "Today · Family", "Done · Family", "18:00 · Family"])
        XCTAssertEqual(rows.map { $0.value("tone") }, ["bad", nil, nil, nil])
        XCTAssertEqual(rows.map { $0.value("done") }, ["false", "false", "true", "false"])
        XCTAssertEqual(rows.map { $0.value("icon") }, ["circle", "circle", "checkmark.circle.fill", "circle"])
        XCTAssertEqual(rows[0].value("row"), "reminder:late")
        XCTAssertEqual(rows[0].value("due"), "2026-11-09T18:00:00+01:00")
        XCTAssertEqual(rows[1].value("allday"), "true")
        XCTAssertEqual(rows[0].value("list"), "7D10")
        XCTAssertEqual(rows[0].value("color"), "#FF9500")
        XCTAssertEqual(store.ranges.last, FakeAgendaStore.Range(start: at(0), end: at(0, day: 11), hidden: []))
    }

    func testTwoDaysAddTomorrowAndAReminderDoneTodayForALaterDayStaysOut() async throws {
        let store = FakeAgendaStore(reminders: [
            reminder("tomorrow", "Pay rent", due: at(9, day: 11)),
            reminder("later", "Renew passport", due: at(9, day: 13), doneAt: at(9))
        ])

        let rows = rows(try await agenda(store).due(days: 2, hiding: ["7D10"]))

        XCTAssertEqual(rows.map { $0.value("detail") }, ["Tomorrow 09:00 · Family"])
        XCTAssertEqual(store.ranges.last?.hidden, ["7D10"])
    }

    func testALateReminderOfAWholeDaySaysItsDay() async throws {
        let store = FakeAgendaStore(reminders: [reminder("late", "Buy stamps", due: at(0, day: 9), allDay: true)])

        let text = try await agenda(store).due(days: 1, hiding: [])
        let row = try XCTUnwrap(rows(text).first)

        XCTAssertEqual(row.value("detail"), "Late · Yesterday · Family")
        XCTAssertEqual(row.value("tone"), "bad")
    }

    func testDoneTicksAndOpensAgainTheReminderWhoseIdTheListPrinted() async throws {
        let store = FakeAgendaStore(reminders: [reminder("late", "Call mom", due: at(18, day: 9))])
        let text = try await agenda(store).due(days: 1, hiding: [])
        let id = try XCTUnwrap(rows(text).first?.value("row"))

        let ticked = try await agenda(store, isRead: false).done(id, true)
        let opened = try await agenda(store, isRead: false).done(id, false)

        XCTAssertEqual(ticked, "")
        XCTAssertEqual(opened, "")
        XCTAssertEqual(store.marks, [.init(id: "late", isDone: true), .init(id: "late", isDone: false)])
    }

    func testDoneOfAnIdThatNamesNoReminderFails() async throws {
        let store = FakeAgendaStore(reminders: [reminder("late", "Call mom", due: at(18, day: 9))])

        for id in ["reminder:gone", "event:late/1700000000", "late"] {
            do {
                _ = try await agenda(store, isRead: false).done(id, true)
                XCTFail("\(id) was ticked")
            } catch PluginError.failed(1, let message) {
                XCTAssertEqual(message, "Openspot cannot find \(id). Read the list again, and use the id of one of its rows.")
            }
        }
        XCTAssertEqual(store.marks, [])
    }

    func testRemindersAskForTheirOwnLeaveAndARefusalLinksToItsPane() async throws {
        let unasked = FakeAgendaStore(reminders: [], access: .unasked)
        let read = try await agenda(unasked).due(days: 1, hiding: [])
        XCTAssertEqual(read, "status=unasked\n")
        XCTAssertEqual(unasked.asked, [])

        let refused = FakeAgendaStore(reminders: [], access: .unasked, answer: .denied)
        do {
            _ = try await agenda(refused, isRead: false).due(days: 1, hiding: [])
            XCTFail("a refusal printed a list")
        } catch PluginError.failedWithFix(1, let message, let link) {
            XCTAssertEqual(refused.asked, [.reminder])
            XCTAssertEqual(message, "Openspot has no access to your reminders. Allow Openspot in Privacy & Security › Reminders, then try again.")
            XCTAssertEqual(link.absoluteString, "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")
        }
    }

    func testTheListsAreRows() async throws {
        let store = FakeAgendaStore(lists: [family])

        let rows = rows(try await agenda(store).lists())

        XCTAssertEqual(rows.map { $0.value("row") }, ["7D10"])
        XCTAssertEqual(rows.first?.value("detail"), "iCloud")
        XCTAssertEqual(store.listed, [.reminder])
    }
}
