import XCTest
@testable import OpenspotCore

/// Proves `openspot calendar events` and `calendars` through `Events`, with a fake store in place of EventKit.
final class EventsTests: XCTestCase {
    private let berlin = TimeZone(identifier: "Europe/Berlin")!
    private let work = CalendarList(id: "A8E2", title: "Work", account: "iCloud", color: "#1BADF8")

    private var clock: Calendar {
        var clock = Calendar(identifier: .gregorian)
        clock.timeZone = berlin
        return clock
    }

    /// Tuesday 10 November 2026 at the hour and minute in Berlin, or on a later day.
    private func at(_ hour: Int, _ minute: Int = 0, day: Int = 10) -> Date {
        clock.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func event(_ id: String, _ title: String, _ start: Date, _ end: Date, allDay: Bool = false, url: String? = nil, notes: String? = nil) -> Event {
        Event(id: id, title: title, start: start, end: end, isAllDay: allDay, calendar: work, location: nil, url: url, notes: notes)
    }

    private func calendar(_ store: FakeEventStore, isRead: Bool = true) -> Events {
        Events(store: store, now: at(9, 40), clock: clock, locale: Locale(identifier: "en_GB"), isRead: isRead)
    }

    private func rows(_ text: String) -> [TextBlock] {
        TextBlock.blocks(in: text)
    }

    func testTodayHoldsEachEventThatHasNotEndedInTheOrderOfItsStart() async throws {
        let store = FakeEventStore(events: [
            event("lunch", "Lunch", at(13), at(14, 30)),
            event("early", "Early call", at(8), at(9)),
            event("standup", "Standup", at(9, 30), at(9, 45)),
            event("tomorrow", "Review", at(10, day: 11), at(11, day: 11))
        ])

        let rows = rows(try await calendar(store).events(days: 1, hiding: []))

        XCTAssertEqual(rows.map { $0.value("title") }, ["Standup", "Lunch"])
        XCTAssertEqual(rows[0].value("detail"), "09:30–09:45 · Work")
        XCTAssertEqual(rows[0].value("value"), "true")
        XCTAssertNil(rows[1].value("value"))
        XCTAssertEqual(rows[1].value("start"), "2026-11-10T13:00:00+01:00")
        XCTAssertEqual(rows[1].value("end"), "2026-11-10T14:30:00+01:00")
        XCTAssertEqual(rows[1].value("calendar"), "A8E2")
        XCTAssertEqual(rows[1].value("color"), "#1BADF8")
        XCTAssertEqual(rows[1].value("icon"), "calendar")
    }

    func testTwoDaysAddTomorrowAndNameItsDay() async throws {
        let store = FakeEventStore(events: [
            event("tomorrow", "Review", at(10, day: 11), at(11, day: 11)),
            event("later", "Trip", at(10, day: 12), at(11, day: 12))
        ])

        let rows = rows(try await calendar(store).events(days: 2, hiding: []))

        XCTAssertEqual(rows.map { $0.value("title") }, ["Review"])
        XCTAssertEqual(rows[0].value("detail"), "Tomorrow 10:00–11:00 · Work")
        XCTAssertEqual(store.ranges.last?.end, at(0, day: 12))
    }

    func testAnEventOfWholeDaysSaysSo() async throws {
        let store = FakeEventStore(events: [event("holiday", "Holiday", at(0), at(0, day: 11), allDay: true)])

        let text = try await calendar(store).events(days: 1, hiding: [])
        let row = try XCTUnwrap(rows(text).first)

        XCTAssertEqual(row.value("detail"), "All day · Work")
        XCTAssertEqual(row.value("allday"), "true")
        XCTAssertNil(row.value("tone"))
    }

    func testTheMeetingComesFromTheNotesAndNotFromAnotherAddress() async throws {
        let store = FakeEventStore(events: [
            event("call", "Design review", at(10), at(11), url: "https://example.com/doc", notes: "Agenda\nJoin: https://us02web.zoom.us/j/123?pwd=x\nThanks"),
            event("doc", "Read the doc", at(12), at(13), url: "https://example.com/doc")
        ])

        let rows = rows(try await calendar(store).events(days: 1, hiding: []))

        XCTAssertEqual(rows[0].value("meeting"), "https://us02web.zoom.us/j/123?pwd=x")
        XCTAssertEqual(rows[0].value("icon"), "video")
        XCTAssertNil(rows[1].value("meeting"))
    }

    func testATitleWithALineBreakStaysOneValue() async throws {
        let store = FakeEventStore(events: [event("plan", "Plan\nreview", at(10), at(11))])

        let text = try await calendar(store).events(days: 1, hiding: [])

        XCTAssertTrue(text.contains("title=Plan\\nreview\n"), text)
        XCTAssertEqual(rows(text).count, 1)
    }

    func testEachTimeOfARepeatingEventHasItsOwnId() async throws {
        let store = FakeEventStore(events: [
            event("daily", "Standup", at(10), at(10, 15)),
            event("daily", "Standup", at(10, day: 11), at(10, 15, day: 11))
        ])

        let ids = rows(try await calendar(store).events(days: 2, hiding: [])).compactMap { $0.value("row") }

        XCTAssertEqual(ids.count, 2)
        XCTAssertEqual(Set(ids).count, 2)
        XCTAssertTrue(ids.allSatisfy { $0.hasPrefix("event:daily") }, "\(ids)")
    }

    func testTheHiddenCalendarsGoToTheStore() async throws {
        let store = FakeEventStore(events: [])

        _ = try await calendar(store).events(days: 1, hiding: ["A8E2", "B1"])

        XCTAssertEqual(store.ranges.last?.hidden, ["A8E2", "B1"])
        XCTAssertEqual(store.ranges.last?.start, at(9, 40))
    }

    func testAReadThatHasNotAskedSaysUnaskedAndDoesNotAsk() async throws {
        let store = FakeEventStore(events: [event("standup", "Standup", at(10), at(11))], access: .unasked)

        let text = try await calendar(store, isRead: true).events(days: 1, hiding: [])

        XCTAssertEqual(text, "status=unasked\n")
        XCTAssertEqual(store.asks, 0)
    }

    func testACallOutsideAReadAsksFirstAndThenAnswers() async throws {
        let store = FakeEventStore(events: [event("standup", "Standup", at(10), at(11))], access: .unasked, answer: .allowed)

        let rows = rows(try await calendar(store, isRead: false).events(days: 1, hiding: []))

        XCTAssertEqual(store.asks, 1)
        XCTAssertEqual(rows.map { $0.value("title") }, ["Standup"])
    }

    func testARefusalFailsWithThePaneOfCalendars() async throws {
        for (access, answer) in [(CalendarAccess.denied, CalendarAccess.denied), (.unasked, .denied)] {
            let store = FakeEventStore(events: [event("standup", "Standup", at(10), at(11))], access: access, answer: answer)

            do {
                _ = try await calendar(store, isRead: false).events(days: 1, hiding: [])
                XCTFail("a refusal printed a list")
            } catch SpotError.failedWithFix(1, let message, let link) {
                XCTAssertEqual(message, "Openspot has no access to your calendars. Allow Openspot in Privacy & Security › Calendars, then try again.")
                XCTAssertEqual(link.absoluteString, "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
            }
        }
    }

    func testTheCalendarsAreRowsWhoseIdNarrowsTheEvents() async throws {
        let store = FakeEventStore(events: [], calendars: [work, CalendarList(id: "B1", title: "Home", account: "On My Mac", color: nil)])

        let rows = rows(try await calendar(store).calendars())

        XCTAssertEqual(rows.map { $0.value("row") }, ["A8E2", "B1"])
        XCTAssertEqual(rows[0].value("title"), "Work")
        XCTAssertEqual(rows[0].value("detail"), "iCloud")
        XCTAssertEqual(rows[0].value("color"), "#1BADF8")
        XCTAssertNil(rows[1].value("color"))
    }
}
