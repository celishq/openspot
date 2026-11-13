import XCTest
@testable import OpenspotCore

/// Proves the Icon spot of the app: Change Icon in the menu of a card opens the drawer's sheet for that card's spot, each
/// stroke keeps a draft, Save keeps a picture of the squares as that spot's icon, and Reset gives the spot its own icon back.
final class IconSpotTests: BuiltInCase {
    private var icon: Spot {
        get throws {
            try spot("icon")
        }
    }

    private func call(_ arguments: [String]) async throws {
        try await icon.perform(SpotAction(arguments: arguments), timeout: 5)
    }

    private func view() async throws -> TextBlock {
        let output = try await icon.items(timeout: 5)
        return try XCTUnwrap(output.view)
    }

    private var saved: String? {
        file.read().setting("icon", of: "weather")
    }

    private let empty = String(repeating: ".", count: 144)

    func testItOffersChangeIconToEveryCardAndShowsNowhereElse() throws {
        let icon = try icon

        XCTAssertEqual(icon.offeredActions.map(\.action.title), ["Change Icon"])
        XCTAssertFalse(icon.offersFloat)
        XCTAssertFalse(icon.offersCard)
    }

    func testChangeIconOpensTheDrawerSheetOnThatCardsSpotWithItsButtons() async throws {
        try await call(["change", "weather"])

        let opened = await app.opened
        let output = try await icon.items(timeout: 5)
        let view = try await self.view()
        XCTAssertEqual(opened, ["open openspot/icon"])
        XCTAssertEqual(output.summary?.value("title"), "weather")
        XCTAssertEqual(view.value("dots"), empty)
        XCTAssertEqual(output.parts.filter { $0.kind == "button" }.map(\.id), ["reset", "save"])
    }

    func testAStrokeKeepsADraftThatSaveDrawsAsTheIconAndResetRemoves() async throws {
        let dots = "0" + String(repeating: ".", count: 142) + "2"
        try await call(["change", "weather"])

        try await call(["drawer", dots])
        let draft = try await view().value("dots")
        try await call(["save"])
        let changes = await app.changeList
        let path = try XCTUnwrap(saved)
        let picture = try String(contentsOfFile: path, encoding: .utf8)
        try await call(["change", "weather"])
        let reopened = try await view().value("dots")
        try await call(["reset"])

        XCTAssertEqual(draft, dots)
        XCTAssertEqual(changes.last, .spots(["weather"]))
        XCTAssertTrue(path.hasSuffix(".svg"), path)
        XCTAssertEqual(picture.components(separatedBy: "<rect").count - 1, 2)
        XCTAssertEqual(reopened, dots)
        XCTAssertNil(saved)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }

    func testSaveOfAnEmptyDrawingGivesTheSpotItsOwnIconBack() async throws {
        try await call(["change", "weather"])
        try await call(["drawer", "0" + String(repeating: ".", count: 143)])
        try await call(["save"])
        XCTAssertNotNil(saved)

        try await call(["change", "weather"])
        try await call(["drawer", empty])
        try await call(["save"])

        XCTAssertNil(saved)
    }
}
