import XCTest
@testable import OpenspotCore

final class CalendarSampleTests: XCTestCase {
    func testAnotherCountOrALaterEditRaisesItsChangeAndTheSameStampRaisesNone() {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let first = CalendarSample(edits: [day, nil])

        XCTAssertEqual(CalendarSample(edits: [day]).event(EventName.calendarChange, after: first), .named(EventName.calendarChange, value: nil))
        XCTAssertEqual(CalendarSample(edits: [day.addingTimeInterval(1), nil]).event(EventName.remindersChange, after: first), .named(EventName.remindersChange, value: nil))
        XCTAssertNil(CalendarSample(edits: [nil, day]).event(EventName.calendarChange, after: first))
    }
}
