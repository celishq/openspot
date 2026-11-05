import XCTest
@testable import OpenspotCore

final class ItemBlocksTests: XCTestCase {
    func testKeepsValidBlocksAndReportsBadOnes() {
        let blocks = ItemBlocks(output: """
        title=Safari
        subtitle=Browser
        run=/Applications/Safari.app
        file=/Applications/Safari.app

        not an item

        title=Off
        run=off
        symbol=power
        """)

        XCTAssertEqual(blocks.items, [
            SpotItem(title: "Safari", subtitle: "Browser", run: "/Applications/Safari.app", file: "/Applications/Safari.app"),
            SpotItem(title: "Off", run: "off", symbol: "power")
        ])
        XCTAssertEqual(blocks.errors, ["not an item"])
    }

    func testABlockWithNoRunIsReportedByItsFirstLine() {
        XCTAssertEqual(ItemBlocks(output: "title=Lost\ndetail=x\n").errors, ["title=Lost"])
    }

    func testKeepsTheFirstItemOfEachRunValue() {
        let blocks = ItemBlocks(output: "title=One\nrun=same\n\ntitle=Two\nrun=same\n")

        XCTAssertEqual(blocks.items.map(\.title), ["One"])
    }

    func testNoOutputIsNoItems() {
        XCTAssertEqual(ItemBlocks(output: ""), ItemBlocks(output: "\n\n"))
        XCTAssertEqual(ItemBlocks(output: "").items, [])
    }
}
