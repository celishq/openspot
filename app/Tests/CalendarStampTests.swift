import XCTest
@testable import OpenspotCore

final class CalendarStampTests: XCTestCase {
    func testAnotherCountOrALaterEditRaisesItsChangeAndTheSameStampRaisesNone() {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let first = CalendarStamp(edits: [day, nil])

        XCTAssertEqual(CalendarStamp(edits: [day]).event(EventName.calendarChange, after: first), .named(EventName.calendarChange, value: nil))
        XCTAssertEqual(CalendarStamp(edits: [day.addingTimeInterval(1), nil]).event(EventName.remindersChange, after: first), .named(EventName.remindersChange, value: nil))
        XCTAssertNil(CalendarStamp(edits: [nil, day]).event(EventName.calendarChange, after: first))
    }
}
