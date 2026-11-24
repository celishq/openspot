import XCTest
@testable import OpenspotCore

final class TextFindsTests: XCTestCase {
    private let berlin = TimeZone(identifier: "Europe/Berlin")!
    private let now = Date(timeIntervalSince1970: 1_794_402_300)

    private func wall(_ date: Date?) -> String? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = berlin
        return date.map { date in
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            return String(format: "%04d-%02d-%02d %02d:%02d", parts.year!, parts.month!, parts.day!, parts.hour!, parts.minute!)
        }
    }

    func testADateInWordsTakesTheClockItIsGiven() {
        let found = TextFinds("Call mom tomorrow 9am").date(now: now, zone: berlin)

        XCTAssertEqual(wall(found?.date), "2026-11-12 09:00")
        XCTAssertEqual(found?.hasTime, true)
        XCTAssertEqual(found.map { String("Call mom tomorrow 9am"[$0.range]) }, "tomorrow 9am")
    }

    func testADayWithNoTimeHasNoTime() {
        let found = TextFinds("next friday").date(now: now, zone: berlin)

        XCTAssertEqual(wall(found?.date).map { String($0.prefix(10)) }, "2026-11-20")
        XCTAssertEqual(found?.hasTime, false)
    }

    func testARangeGivesItsLength() {
        XCTAssertEqual(TextFinds("tomorrow 13:00-14:30").date(now: now, zone: berlin)?.length, 5400)
        XCTAssertNil(TextFinds("tomorrow 13:00").date(now: now, zone: berlin)?.length)
    }

    func testWordsWithNoDateHaveNone() {
        XCTAssertNil(TextFinds("Buy 2 apples").date(now: now, zone: berlin))
    }

    func testTheLinksOfATextAreFound() {
        let links = TextFinds("Join https://zoom.us/j/1 tomorrow, notes at https://example.com/a").links

        XCTAssertEqual(links.map(\.absoluteString), ["https://zoom.us/j/1", "https://example.com/a"])
    }
}
