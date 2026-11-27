import XCTest
@testable import OpenspotCore

final class ColorPeekTests: XCTestCase {
    func testAColourTextOfEachFormReadsAsItsColour() {
        let texts = ["#f00", "#FF3B30", "#ff3b3080", "rgb(255, 59, 48)", "rgba(0 122 255 / 50%)", "hsl(120, 100%, 25%)", "red", "#ff3b3", "  #FF3B30\n"]

        XCTAssertEqual(texts.map { HexColor(css: $0)?.text }, ["#FF0000", "#FF3B30", "#FF3B3080", "#FF3B30", "#007AFF80", "#008000", nil, nil, "#FF3B30"])
    }

    func testAColourCopiesAsEachFormat() throws {
        let color = try XCTUnwrap(HexColor(css: "#FF3B30"))

        XCTAssertEqual(color.formats.map(\.title), ["HEX", "RGB", "RGBA", "HSL", "SwiftUI"])
        XCTAssertEqual(color.formats.map(\.text), [
            "#FF3B30",
            "rgb(255 59 48)",
            "rgba(255, 59, 48, 1)",
            "hsl(3 100% 59%)",
            "Color(red: 1.000, green: 0.231, blue: 0.188)",
        ])
    }

    func testTheBlocksOfAColourAreAPeekWithASwatchAndCopyAs() throws {
        let blocks = try XCTUnwrap(HexColor(css: "#ff3b30")).peek
        let kept = [TextBlock(fields: blocks[0].fields + [.init(key: "parent", value: "a")])] + blocks.dropFirst()

        let row = Frame(text: "item=a\ntitle=Red\ntext=#ff3b30\n\n" + kept.map(\.text).joined(separator: "\n")).items.first
        let item = try XCTUnwrap(row)

        guard case .blocks(let tree) = Peek(item: item)?.look else { return XCTFail("no blocks") }
        XCTAssertEqual(tree.node("swatch")?.block.value("value"), "#ff3b30")
        let actions = PeekAct.actions(of: item.peek)
        XCTAssertEqual(actions.map(\.title), ["Copy as", "HEX", "RGB", "RGBA", "HSL", "SwiftUI"])
        XCTAssertEqual(actions.map(\.id).first, "openspot.act.copy-as")
    }
}
