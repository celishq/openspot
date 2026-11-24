import XCTest
@testable import OpenspotCore

final class AttachmentSpotTests: BuiltInCase {
    private var attachments: Spot {
        get throws {
            try spot("attachments")
        }
    }

    private func items() async throws -> [SpotItem] {
        try await attachments.items(timeout: 60).items
    }

    private func press(_ handler: String, on item: String) async throws {
        try await attachments.perform(handler, input: "input.item=\(item)\n", timeout: 60)
    }

    override func setUp() async throws {
        try await super.setUp()
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("apps.spot/apps.sh"))
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("tab.spot/tab.sh"), toml: "title = 'Tab'\ndetail = 'Hand the front tab to a spot'\nuses = ['attachment']")
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("copy.spot/copy.sh"), toml: "title = 'Copy'\nuses = ['attachment', 'clipboard']")
    }

    func testTheSearchFindsItByTheWordsOfWhatItReads() throws {
        let spot = try attachments

        XCTAssertTrue(spot.isFound)
        XCTAssertTrue(spot.showsInSheet)
        XCTAssertTrue(["attachments", "tab", "selection", "clipboard"].allSatisfy(spot.keywords.contains))
    }

    func testTheSheetListsEachSourceOnOrOffWithWhatItReads() async throws {
        try file.turn("tab", on: true)

        let items = try await items()

        XCTAssertEqual(items.map(\.run), ["copy", "tab"])
        XCTAssertEqual(items.map(\.isOn), [false, true])
        XCTAssertEqual(items.map(\.openTitle), ["Turn on", "Turn off"])
        XCTAssertEqual(items.last?.subtitle, "Hand the front tab to a spot")
        XCTAssertEqual(items.map { $0.hides ?? [] }, [["settings"], []])
    }

    func testReturnTurnsASourceOnAndOff() async throws {
        try await press("press", on: "copy")
        XCTAssertEqual(file.read().arrangement.enabled, ["copy"])

        try await press("press", on: "copy")
        XCTAssertEqual(file.read().arrangement.enabled, [])
    }

    func testSettingsOpensTheSettingsOfTheSource() async throws {
        try file.turn("tab", on: true)

        try await press("settings", on: "tab")

        let opened = await app.opened
        XCTAssertEqual(opened, ["settings tab"])
    }
}
