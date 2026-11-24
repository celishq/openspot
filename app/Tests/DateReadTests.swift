import XCTest
@testable import OpenspotCore

final class DateReadTests: XCTestCase {
    private let berlin = TimeZone(identifier: "Europe/Berlin")!
    private let now = Date(timeIntervalSince1970: 1_794_402_300)

    private func read(_ words: String) -> String {
        DateCall.block(of: words, now: now, zone: berlin)
    }

    func testWordsThatNameADayPrintItsDayWithNoTime() {
        XCTAssertEqual(read("25 dec"), "item=2026-12-25\ntime=false\n")
        XCTAssertEqual(read("next friday"), "item=2026-11-20\ntime=false\n")
        XCTAssertEqual(read("in 3 weeks"), "item=2026-12-02\ntime=false\n")
    }

    func testWordsThatNameATimePrintItInTheZoneOfTheClock() {
        XCTAssertEqual(read("tomorrow 3pm"), "item=2026-11-12 15:00\ntime=true\n")
        XCTAssertEqual(DateCall.block(of: "tomorrow 3pm", now: now, zone: TimeZone(identifier: "Asia/Tokyo")!), "item=2026-11-12 15:00\ntime=true\n")
        XCTAssertEqual(read(" dec 25 2026 3pm "), "item=2026-12-25 15:00\ntime=true\n")
    }

    func testWordsThatAreMoreThanADatePrintNothing() {
        for words in ["tomorrow never dies", "call mom tomorrow", "today show", "safari", ""] {
            XCTAssertEqual(read(words), "", words)
        }
    }

    func testTheCommandTakesTheWordsOfTheDate() {
        XCTAssertEqual(CommandLineCall(arguments: ["date", "read", "25", "dec"], spot: "own")?.value as? DateCall, .read("25 dec"))
        XCTAssertNil(CommandLineCall(arguments: ["date", "read"], spot: "own")?.value as? DateCall)
    }
}
