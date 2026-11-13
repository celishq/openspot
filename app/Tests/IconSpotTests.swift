import XCTest
@testable import OpenspotCore

/// Proves the Icon spot of the app: Change Icon in the menu of a card floats the drawer for that card's spot, a save keeps a
/// picture of the dots as that spot's icon, and Reset gives the spot its own icon back.
final class IconSpotTests: BuiltInCase {
    private var icon: Spot {
        get throws {
            try spot("icon")
        }
    }

    private func call(_ arguments: [String]) async throws {
        try await icon.perform(SpotAction(arguments: arguments), timeout: 5)
    }

    private var saved: String? {
        file.read().setting("icon", of: "weather")
    }

    func testItOffersChangeIconToEveryCardAndFloatsWithNoCard() throws {
        let icon = try icon

        XCTAssertEqual(icon.offeredActions.map(\.action.title), ["Change Icon"])
        XCTAssertTrue(icon.offersFloat)
        XCTAssertFalse(icon.offersCard)
    }

    func testChangeIconFloatsTheDrawerOnThatCardsSpot() async throws {
        try await call(["change", "weather"])

        let opened = await app.opened
        XCTAssertEqual(opened, ["float openspot/icon"])
        let output = try await icon.items(timeout: 5)
        let view = try XCTUnwrap(output.view)
        XCTAssertEqual(view.value("view"), "drawer")
        XCTAssertEqual(view.value("target"), "weather")
        XCTAssertEqual(view.value("dots"), String(repeating: ".", count: 256))
    }

    func testASaveKeepsAPictureOfTheDotsAsTheIconAndResetRemovesIt() async throws {
        let dots = "0" + String(repeating: ".", count: 254) + "2"
        try await call(["change", "weather"])

        try await call(["drawer", "save \(dots)"])
        let changes = await app.changeList
        let path = try XCTUnwrap(saved)
        let picture = try String(contentsOfFile: path, encoding: .utf8)
        let output = try await icon.items(timeout: 5)
        let view = try XCTUnwrap(output.view)
        try await call(["drawer", "reset"])

        XCTAssertEqual(changes.last, .spots(["weather"]))
        XCTAssertTrue(path.hasSuffix(".svg"), path)
        XCTAssertEqual(picture.components(separatedBy: "<circle").count - 1, 2)
        XCTAssertEqual(view.value("dots"), dots)
        XCTAssertNil(saved)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }
}
