import XCTest
@testable import OpenspotCore

final class KeysSpotTests: BuiltInCase {
    private let page = "spot:shelf"

    private var keys: Spot {
        get throws {
            try spot("keys")
        }
    }

    private func call(_ arguments: [String], page: String? = nil) async throws {
        try await keys.perform(SpotAction(arguments: arguments), page: page ?? self.page, timeout: 60)
    }

    private func items(page: String? = nil) async throws -> SpotOutput {
        try await keys.items(page: page ?? self.page, timeout: 60)
    }

    func testItShowsNowhereAndTakesThePageOfASpot() throws {
        let keys = try keys

        XCTAssertEqual(keys.offeredActions, [])
        XCTAssertFalse(keys.offersCard)
        XCTAssertTrue(keys.takes(page: page))
    }

    func testTheSheetHasARowToOpenTheSpotOnePerCommandAndOneForItsFloat() async throws {
        try script("shelf.sh", "title=Shelf\nicon=tray.full\non=sheet.open\noffers=card\noffers=float\n\nbutton=add\ntitle=Add\nicon=plus")

        let output = try await items()

        XCTAssertEqual(output.summary?.value("title"), "Shelf")
        XCTAssertEqual(output.items.map(\.run), ["spot", "key.add", "float"])
        XCTAssertEqual(output.items.map(\.title), ["Open", "Add", "Float"])
        XCTAssertEqual(output.items.map(\.symbol), ["tray.full", "plus", "tray.full"])
        XCTAssertEqual(output.items.map(\.shortcut), ["Record", "Record", "Record"])
        XCTAssertEqual(output.items.map(\.records), [true, true, true])
        XCTAssertEqual(output.items.map(\.takesShake), [true, true, true])
        XCTAssertEqual(output.items.map(\.staysOnPick), [true, true, true])
    }

    func testEachRowRecordsShowsAndRemovesItsKey() async throws {
        try script("shelf.sh", "title=Shelf\non=sheet.open\noffers=card\noffers=float\n\nbutton=add\ntitle=Add")

        try await call(["spot", "ctrl+option+s"])
        try await call(["key.add", "ctrl+option+a"])
        try await call(["float", "shake"])
        let set = try await items().items
        try await call(["clear", "spot"])
        try await call(["clear", "key.add"])
        try await call(["clear", "float"])
        let cleared = try await items().items

        XCTAssertEqual(set.map(\.shortcut), ["ctrl+option+s", "ctrl+option+a", "shake"])
        XCTAssertEqual(set.map(\.hides), [nil, nil, nil])
        XCTAssertEqual(file.read().keys, [])
        XCTAssertEqual(cleared.map(\.hides), [["clear"], ["clear"], ["clear"]])
    }

    func testASpotWithNoCommandsAndNoFloatHasOnlyItsOpenRow() async throws {
        try script("notes.sh", "title=Notes")

        let rows = try await items(page: "spot:notes").items

        XCTAssertEqual(rows.map(\.run), ["spot"])
    }

    func testWithNoSpotItHasNoRowsAndChangesNoKey() async throws {
        let output = try await keys.items(timeout: 60)
        try await keys.perform(SpotAction(arguments: ["spot", "ctrl+option+s"]), timeout: 60)

        XCTAssertEqual(output.items, [])
        XCTAssertEqual(file.read().keys, [])
    }

    func testAShakeOnARowTakesTheShakeFromTheSpotThatHadIt() async throws {
        try script("shelf.sh", "title=Shelf\non=sheet.open\noffers=card\noffers=float")
        try script("notes.sh", "title=Notes\non=sheet.open\noffers=card\noffers=float")

        try await call(["float", "shake"], page: "spot:shelf")
        try await call(["float", "shake"], page: "spot:notes")

        XCTAssertEqual(file.read().keys, [GlobalKey(spot: "notes", act: .float, trigger: .shake)])
        let rows = try await items(page: "spot:notes").items
        XCTAssertEqual(rows.first { $0.run == "float" }?.shortcut, "shake")
    }
}
