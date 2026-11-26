import XCTest
@testable import OpenspotCore

final class ColorsSpotTests: BuiltInCase {
    private var colors: Spot {
        get throws {
            try XCTUnwrap(try SpotsFolder(url: root.appendingPathComponent("none"), core: repoSpots).scan().scripts.first { $0.id == "colors" })
        }
    }

    private func preview(of text: String) async throws -> [String] {
        let answer = try await runs.answer(of: try colors, EventName.itemPreview, input: "input.item=a\ninput.item.text=\(text)\n", limit: 60)
        return TextBlock.blocks(in: answer).compactMap { $0.value("text") != nil ? $0.value("title") : nil }
    }

    func testThePreviewShowsTheColourAsHexRGBAAndHSL() async throws {
        let red = try await preview(of: "#ff3b30")
        let blue = try await preview(of: "rgb(0 122 255 / 50%)")
        let green = try await preview(of: "hsl(120, 100%, 25%)")

        XCTAssertEqual(red, ["#ff3b30", "rgba(255, 59, 48, 1)", "hsl(3, 100%, 59%)"])
        XCTAssertEqual(blue, ["#007aff80", "rgba(0, 122, 255, 0.5)", "hsla(211, 100%, 50%, 0.5)"])
        XCTAssertEqual(green.first, "#008000")
    }

    func testAColourIsOfItsTypeAndAWordIsNot() throws {
        let type = try XCTUnwrap(try colors.types.first)

        XCTAssertEqual(["#fff", "#ff3b30", "#ff3b3080", "rgba(0, 0, 0, 0.5)", "hsl(3 100% 59%)"].map(type.holds), [true, true, true, true, true])
        XCTAssertEqual(["fff", "#ff3b3", "red", "rgb(0, 0, 0) and more"].map(type.holds), [false, false, false, false])
    }

    func testItStaysOffTheGridAndOutOfTheSearchAndItsActionsAreNoCommands() throws {
        let spot = try colors

        XCTAssertFalse(spot.isFound)
        XCTAssertEqual(spot.commands.map(\.id), [])
        XCTAssertEqual(spot.actions.compactMap(\.type), ["color", "color", "color"])
    }
}
