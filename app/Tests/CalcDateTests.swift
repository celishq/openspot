import XCTest
@testable import OpenspotCore

final class CalcDateTests: XCTestCase {
    private let english = Locale(identifier: "en_US")
    private let berlin: Calendar = {
        var clock = Calendar(identifier: .gregorian)
        clock.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return clock
    }()
    private let now = Date(timeIntervalSince1970: 1_794_402_300)

    private func answer(_ text: String) -> CalcAnswer? {
        try? CalcAnswer(text: text, locale: english, clock: berlin, now: now)
    }

    private func spaced(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private func check(_ cases: [(String, String, String)], file: StaticString = #filePath, line: UInt = #line) {
        for (text, value, title) in cases {
            XCTAssertEqual(answer(text)?.value, value, text, file: file, line: line)
            XCTAssertEqual(spaced(answer(text)?.title), title, text, file: file, line: line)
        }
    }

    func testALengthMovesADate() {
        XCTAssertEqual(answer("today + 3 weeks")?.text, "row=2026-12-02\ntitle=Wed, Dec 2, 2026\ndetail=Wed, Nov 11, 2026 + 3 weeks\n")
        check([
            ("today - 10 days", "2026-11-01", "Sun, Nov 1, 2026"),
            ("tomorrow + 1 month", "2026-12-12", "Sat, Dec 12, 2026"),
            ("today + 1 year - 1 day", "2027-11-10", "Wed, Nov 10, 2027"),
            ("today+2d", "2026-11-13", "Fri, Nov 13, 2026"),
            ("now + 90 min", "2026-11-11 15:35", "Wed, Nov 11, 2026 at 3:35 PM"),
            ("now - 2 hours", "2026-11-11 12:05", "Wed, Nov 11, 2026 at 12:05 PM"),
            ("25.12.2026 + 1 week", "2027-01-01", "Fri, Jan 1, 2027"),
        ])
    }

    func testACountRunsToOrFromADate() {
        XCTAssertEqual(answer("days until 25 dec 2026")?.text, "row=44\ntitle=44 days\ndetail=Wed, Nov 11, 2026 to Fri, Dec 25, 2026\nunit=days\n")
        check([
            ("weeks until 25 dec 2026", "6", "6 weeks"),
            ("days since 1 jan 2026", "314", "314 days"),
            ("25 dec 2026 - today", "44", "44 days"),
            ("hours until tomorrow", "9", "9 hours"),
            ("days since 1 jan", "314", "314 days"),
        ])
    }

    func testATimeShowsInAnotherZone() {
        XCTAssertEqual(spaced(answer("3pm tokyo in berlin")?.text), "row=2026-11-11 07:00\ntitle=Wed 7:00 AM\ndetail=Wed 3:00 PM · Tokyo\nunit=AM\n")
        check([
            ("now in tokyo", "2026-11-11 22:05", "Wed 10:05 PM"),
            ("time in new york", "2026-11-11 08:05", "Wed 8:05 AM"),
            ("15:00 in kyiv", "2026-11-11 16:00", "Wed 4:00 PM"),
            ("noon utc in kyiv", "2026-11-11 14:00", "Wed 2:00 PM"),
            ("9:30 am pst in london", "2026-11-11 17:30", "Wed 5:30 PM"),
        ])
    }

    func testADateAloneSaysItsDay() {
        check([
            ("25.12.2026", "2026-12-25", "Fri, Dec 25, 2026"),
            ("2026-12-25", "2026-12-25", "Fri, Dec 25, 2026"),
            ("2026-12-25 + 1 week", "2027-01-01", "Fri, Jan 1, 2027"),
            ("dec 25 2026 3pm", "2026-12-25 15:00", "Fri, Dec 25, 2026 at 3:00 PM"),
            ("yesterday", "2026-11-10", "Tue, Nov 10, 2026"),
        ])
    }

    func testWordsThatAreNoDateHaveNoAnswer() {
        for text in ["friday", "may", "today is", "3pm", "now in narnia", "days until", "today + 3 apples", "tomorrow never dies", "in 5"] {
            XCTAssertNil(answer(text), text)
        }
    }
}
