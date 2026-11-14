import XCTest
@testable import OpenspotCore

final class CalendarEntryTests: XCTestCase {
    private let clock = Calendar.current

    private func tomorrow(_ hour: Int, _ minute: Int = 0) -> Date {
        let day = clock.date(byAdding: .day, value: 1, to: clock.startOfDay(for: Date()))!
        return clock.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    func testATimeIsTakenOutOfTheTitle() {
        let entry = CalendarEntry(words: "Call mom tomorrow 9am")

        XCTAssertEqual(entry.title, "Call mom")
        XCTAssertEqual(entry.date, tomorrow(9))
        XCTAssertTrue(entry.hasTime)
        XCTAssertNil(entry.length)
    }

    func testARangeGivesItsLength() {
        let entry = CalendarEntry(words: "Lunch with Ana tomorrow 13:00-14:30")

        XCTAssertEqual(entry.title, "Lunch with Ana")
        XCTAssertEqual(entry.date, tomorrow(13))
        XCTAssertEqual(entry.length, 5400)
    }

    func testAFirstWordThatTheFinderTakesAsATimeOfDayStaysTheTitle() {
        let lunch = CalendarEntry(words: "Lunch tomorrow 13:00-14:30")
        let dinner = CalendarEntry(words: "Dinner tomorrow 7pm")
        let bare = CalendarEntry(words: "tomorrow 9am")

        XCTAssertEqual(lunch.title, "Lunch")
        XCTAssertEqual(lunch.date, tomorrow(13))
        XCTAssertEqual(lunch.length, 5400)
        XCTAssertEqual(dinner.title, "Dinner")
        XCTAssertEqual(dinner.date, tomorrow(19))
        XCTAssertEqual(bare.title, "")
    }

    func testADayWithNoTimeHasNoTimeAndLosesItsWordBefore() {
        let entry = CalendarEntry(words: "Pay rent on Nov 15")

        XCTAssertEqual(entry.title, "Pay rent")
        XCTAssertFalse(entry.hasTime)
        XCTAssertEqual(entry.date.map { clock.component(.day, from: $0) }, 15)
        XCTAssertEqual(entry.date.map { clock.component(.month, from: $0) }, 11)
    }

    func testWordsWithNoDateAreAllTitle() {
        let entry = CalendarEntry(words: "  Buy   2 apples ")

        XCTAssertEqual(entry.title, "Buy 2 apples")
        XCTAssertNil(entry.date)
    }

    func testWordsInRussianFindTheirDate() {
        let entry = CalendarEntry(words: "Позвонить маме завтра в 9")

        XCTAssertEqual(entry.title, "Позвонить маме")
        XCTAssertEqual(entry.date, tomorrow(9))
        XCTAssertTrue(entry.hasTime)
    }
}
