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

        [bindings]
        picker = { spot = "time-picker" }
        """)

        let spot = try XCTUnwrap(loaded.spot, loaded.refused.joined())
        let triggers = spot.triggers
        XCTAssertEqual(triggers.commands, ["snooze", "later"])
        XCTAssertEqual(spot.triggers.search?.text, "^https?://")
        XCTAssertEqual(triggers.schedule.map(\.text), ["0 9 * * 1-5", "*/15 * * * *"])
        XCTAssertEqual(spot.triggers.every, 60)
        XCTAssertEqual(spot.triggers.drop, DropKinds(["png", "folder"]))
        XCTAssertEqual(triggers.bindings.map(\.key), ["picker.picked"])
    }

    func testEachEventOfTheEventsTableIsAKeyOfItsOwn() throws {
        for event in EventName.declarable {
            let loaded = try load("[on]\n\"\(event)\" = true")

            let spot = try XCTUnwrap(loaded.spot, "\(event): \(loaded.refused.joined())")
            XCTAssertEqual(spot.triggers.events, [event])
        }
    }

    func testAnEventWithAValueTakesARegularExpressionOfIt() throws {
        let spot = try XCTUnwrap(try load("[on]\n\"power.change\" = \"^ac$\"").spot)

        XCTAssertEqual(spot.triggers.admits(EventName.powerChange, value: "ac"), true)
        XCTAssertEqual(spot.triggers.admits(EventName.powerChange, value: "battery"), false)
        for event in ["system.load", "disk.mount", "device.connect"] {
            let other = try XCTUnwrap(try load("[on]\n\"\(event)\" = \"^a$\"").spot, event)
            XCTAssertEqual(other.triggers.admits(event, value: "a"), true, event)
            XCTAssertEqual(other.triggers.admits(event, value: "b"), false, event)
        }
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
            ("\"panel.open\" = \"([\"", "panel.open"),
            ("\"sheet.open\" = \"^x\"", "sheet.open"),
            ("\"screen.wake\" = \"^x\"", "screen.wake"),
            ("every = 1.5", "every"),
            ("\"picker.picked\" = 1", "picker.picked"),
            ("later = true", "later")
        ]
        for (line, key) in cases {
            let reason = try refusal("[on]\n\(line)")

            XCTAssertTrue(reason.contains(key), "\(line): \(reason)")
        }
    }

    func testAnEventOfABindingThatTheSpotDoesNotDeclareFailsTheLoad() throws {
        let reason = try refusal("[on]\n\"picker.picked\" = true")

        XCTAssertEqual(reason, "Snooze has [on] picker.picked, which names no binding picker. Add it to [bindings], such as picker = { spot = \"<id>\" }")
    }

    func testAnEventThatAnInstalledBoundSpotDoesNotDeclareFailsTheLoadOfItsListener() throws {
        let spots = try temporaryFolder()
        try "#!/bin/sh\n".writeScript(to: spots.appendingPathComponent("picker.spot/picker.sh"), toml: "[events.picked]\nuntil = \"date\"")
        try "#!/bin/sh\n".writeScript(to: spots.appendingPathComponent("snooze.spot/snooze.sh"), toml: "[bindings]\npicker = { spot = \"picker\" }\n[on]\n\"picker.chosen\" = true")
        try "#!/bin/sh\n".writeScript(to: spots.appendingPathComponent("later.spot/later.sh"), toml: "[bindings]\npicker = { spot = \"picker\" }\n[on]\n\"picker.picked\" = true")

        let scan = try SpotsFolder(url: spots).scan()

        XCTAssertEqual(Set(scan.spots.map(\.id)), ["picker", "later"])
        XCTAssertEqual(scan.refused.map(\.reason), ["Snooze has [on] picker.chosen, but picker declares no event chosen. Name one of its [events]: picked"])
    }

    func testAnEventThatACoreSpotDoesNotDeclareFailsTheLoadOfItsListener() throws {
        let spots = try temporaryFolder()
        let core = try temporaryFolder()
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("picker.spot/picker.sh"), toml: "[events.picked]\nuntil = \"date\"")
        try "#!/bin/sh\n".writeScript(to: spots.appendingPathComponent("snooze.spot/snooze.sh"), toml: "[bindings]\npicker = { spot = \"picker\" }\n[on]\n\"picker.chosen\" = true")

        let scan = try SpotsFolder(url: spots, core: core).scan()

        XCTAssertEqual(scan.spots.map(\.id), ["picker"])
        XCTAssertEqual(scan.refused.map(\.reason), ["Snooze has [on] picker.chosen, but picker declares no event chosen. Name one of its [events]: picked"])
    }

    func testAnEventIsDeclaredWithTypedValuesAndAWrongTypeFailsTheLoad() throws {
        let spot = try XCTUnwrap(try load("[events.snoozed]\nurl = \"url\"\nuntil = { type = \"date\", required = true }").spot)

        XCTAssertEqual(spot.events.map(\.name), ["snoozed"])
        XCTAssertEqual(spot.events.first?.values.map(\.name), ["url", "until"])
        XCTAssertTrue(try refusal("[events.snoozed]\nurl = \"link\"").contains("[events.snoozed] url"))
    }

    func testAnActionThatTakesTheNameOfAHandlerFailsTheLoad() throws {
        let reason = try refusal("[on]\ncommand = [\"go\"]\n\n[actions.command]\ntitle = \"Go\"")

        XCTAssertTrue(reason.contains("[actions.command]"), reason)
    }

    func testOnCannotSitBesideAnOldTrigger() throws {
        let reason = try refusal("drop = \"png\"\n\n[on]\nevery = 60")

        XCTAssertTrue(reason.contains("drop"), reason)
    }

    func testAnswersSitsBesideTheSearchOfOn() throws {
        let loaded = try load("answers = \"card\"\n\n[on]\nsearch = \"^[0-9]\"")

        let spot = try XCTUnwrap(loaded.spot, loaded.refused.joined())
        XCTAssertEqual(spot.triggers.search?.text, "^[0-9]")
        XCTAssertEqual(spot.triggers.search?.isCard, true)
    }

    func testSearchTrueListsTheItemsOfTheSpotInThePanelSearch() throws {
        let loaded = try load("[on]\nsearch = true")

        let spot = try XCTUnwrap(loaded.spot, loaded.refused.joined())
        XCTAssertTrue(spot.triggers.lists)
        XCTAssertNil(spot.triggers.search)
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
