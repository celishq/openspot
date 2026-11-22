import XCTest
@testable import OpenspotCore

final class OnTableTests: XCTestCase {
    private func load(_ toml: String) throws -> (spot: Spot?, refused: [String]) {
        let spots = try temporaryFolder()
        try "#!/bin/sh\necho\n".writeScript(to: spots.appendingPathComponent("snooze.spot/snooze.sh"), toml: toml)
        let scan = try SpotsFolder(url: spots).scan()
        return (scan.spots.first, scan.refused.map(\.reason))
    }

    private func refusal(_ toml: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let loaded = try load(toml)
        XCTAssertNil(loaded.spot, file: file, line: line)
        return loaded.refused.joined(separator: "\n")
    }

    func testTheTriggersOfOnAreReadIntoTheSpot() throws {
        let loaded = try load("""
        [on]
        command = ["snooze", "later"]
        search = "^https?://"
        schedule = ["0 9 * * 1-5", "*/15 * * * *"]
        every = 60
        drop = ["png", "folder"]
        "picker.picked" = true
        """)

        let spot = try XCTUnwrap(loaded.spot, loaded.refused.joined())
        let triggers = try XCTUnwrap(spot.triggers)
        XCTAssertEqual(triggers.commands, ["snooze", "later"])
        XCTAssertEqual(spot.answers?.text, "^https?://")
        XCTAssertEqual(triggers.schedule.map(\.text), ["0 9 * * 1-5", "*/15 * * * *"])
        XCTAssertEqual(spot.on?.seconds, 60)
        XCTAssertEqual(spot.drop, ["png", "folder"])
        XCTAssertEqual(triggers.bindings, ["picker.picked"])
    }

    func testEachEventOfTheEventsTableIsAKeyOfItsOwn() throws {
        for event in SpotEvent.known where event != SpotEvent.searchText {
            let loaded = try load("[on]\n\"\(event)\" = true")

            let spot = try XCTUnwrap(loaded.spot, "\(event): \(loaded.refused.joined())")
            XCTAssertEqual(spot.triggers?.events, [event])
            let moment: ShowEvents.Moment = switch event {
            case SpotEvent.sheetOpen, SpotEvent.sheetText: .sheet
            case SpotEvent.panelOpen: .panel
            default: .event(event)
            }
            XCTAssertEqual(spot.on?.has(moment), true, event)
        }
    }

    func testAnEventWithAValueTakesARegularExpressionOfIt() throws {
        let spot = try XCTUnwrap(try load("[on]\n\"power.change\" = \"^ac$\"").spot)

        XCTAssertEqual(spot.on?.admits(SpotEvent.powerChange, value: "ac"), true)
        XCTAssertEqual(spot.on?.admits(SpotEvent.powerChange, value: "battery"), false)
    }

    func testEachWrongTriggerFailsTheLoadWithALineThatNamesItsKey() throws {
        let cases = [
            ("\"power.chnage\" = true", "power.chnage"),
            ("search = \"([\"", "search"),
            ("\"app.front\" = \"([\"", "app.front"),
            ("schedule = [\"61 * * * *\"]", "schedule"),
            ("schedule = [\"0 9 * *\"]", "schedule"),
            ("every = 0", "every"),
            ("command = [\"/snooze\"]", "command"),
            ("drop = \"png\"", "drop"),
            ("\"clipboard.change\" = \"^http\"", "clipboard.change"),
            ("\"picker.picked\" = 1", "picker.picked"),
            ("later = true", "later")
        ]
        for (line, key) in cases {
            let reason = try refusal("[on]\n\(line)")

            XCTAssertTrue(reason.contains(key), "\(line): \(reason)")
        }
    }

    func testAnActionThatTakesTheNameOfAHandlerFailsTheLoad() throws {
        let reason = try refusal("[on]\ncommand = [\"go\"]\n\n[actions.command]\ntitle = \"Go\"")

        XCTAssertTrue(reason.contains("[actions.command]"), reason)
    }

    func testOnCannotSitBesideAnOldTrigger() throws {
        let reason = try refusal("drop = \"png\"\n\n[on]\nevery = 60")

        XCTAssertTrue(reason.contains("drop"), reason)
    }

    func testACronLineFindsItsNextTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let friday = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-20T09:00:00Z"))
        let line = try XCTUnwrap(CronLine("0 9 * * 1-5"))

        let next = line.next(after: friday, calendar: calendar)

        XCTAssertEqual(next.map { ISO8601DateFormatter().string(from: $0) }, "2026-11-23T09:00:00Z")
    }
}
