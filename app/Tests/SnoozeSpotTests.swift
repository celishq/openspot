import JavaScriptCore
import XCTest

final class SnoozeSpotTests: XCTestCase {
    private let defaults = "{ morning: [8, 0], evening: [19, 0], later: 3, weekend: 6 }"

    private func times(at now: String, choices: String? = nil) throws -> [String: String] {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots/openspot.spot/snooze.js")
        let context = try XCTUnwrap(JSContext())
        context.evaluateScript(try String(contentsOf: file, encoding: .utf8))
        let script = """
        (() => {
          const moments = times(new Date(\(now)), \(choices ?? defaults))
          const out = {}
          for (const id in moments) out[id] = iso(moments[id]).slice(0, 16)
          return JSON.stringify(out)
        })()
        """
        let text = try XCTUnwrap(context.evaluateScript(script)?.toString())
        XCTAssertNil(context.exception)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: String])
    }

    func testEachTileOfAWednesdayAfternoon() throws {
        let moments = try times(at: "2026, 10, 18, 14, 20")

        XCTAssertEqual(moments, [
            "hour": "2026-11-18T15:20",
            "later": "2026-11-18T17:20",
            "evening": "2026-11-18T19:00",
            "tomorrow": "2026-11-19T08:00",
            "weekend": "2026-11-21T08:00",
            "week": "2026-11-23T08:00",
            "month": "2026-12-18T08:00",
        ])
    }

    func testLateInTheEveningLaterAndThisEveningMoveToTomorrow() throws {
        let moments = try times(at: "2026, 10, 18, 22, 5")

        XCTAssertEqual(moments["later"], "2026-11-19T08:00")
        XCTAssertEqual(moments["evening"], "2026-11-19T19:00")
    }

    func testAfterMidnightLaterIsThisMorning() throws {
        let moments = try times(at: "2026, 10, 20, 1, 5")

        XCTAssertEqual(moments["later"], "2026-11-20T08:00")
        XCTAssertEqual(moments["evening"], "2026-11-20T19:00")
    }

    func testOnAWeekendThisWeekendIsTheNextOne() throws {
        XCTAssertEqual(try times(at: "2026, 10, 21, 10, 0")["weekend"], "2026-11-28T08:00")
        XCTAssertEqual(try times(at: "2026, 10, 22, 10, 0")["weekend"], "2026-11-28T08:00")
    }

    func testOnAMondayNextWeekIsTheMondayAfter() throws {
        XCTAssertEqual(try times(at: "2026, 10, 23, 9, 0")["week"], "2026-11-30T08:00")
    }

    func testInAMonthKeepsToTheLastDayOfAShortMonth() throws {
        XCTAssertEqual(try times(at: "2027, 0, 31, 9, 0")["month"], "2027-02-28T08:00")
    }

    func testTheChoicesOfThePersonMoveTheHours() throws {
        let moments = try times(at: "2026, 10, 18, 14, 20", choices: "{ morning: [7, 30], evening: [18, 0], later: 2, weekend: 0 }")

        XCTAssertEqual(moments["later"], "2026-11-18T16:20")
        XCTAssertEqual(moments["evening"], "2026-11-18T18:00")
        XCTAssertEqual(moments["tomorrow"], "2026-11-19T07:30")
        XCTAssertEqual(moments["weekend"], "2026-11-22T07:30")
    }
}
