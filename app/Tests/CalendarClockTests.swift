import XCTest
@testable import OpenspotCore

final class CalendarClockTests: XCTestCase {
    private var berlin: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func at(day: Int) -> Date {
        berlin.date(from: DateComponents(year: 2020, month: 3, day: day, hour: 12))!
    }

    func testTheDaysNextToTheGivenNowHaveTheirWordOnAnyRealDate() {
        let clock = CalendarClock(now: at(day: 10), calendar: berlin, locale: Locale(identifier: "en_GB"))

        XCTAssertEqual([clock.day(at(day: 9)), clock.day(at(day: 10)), clock.day(at(day: 11))], ["Yesterday", nil, "Tomorrow"])
    }
}
