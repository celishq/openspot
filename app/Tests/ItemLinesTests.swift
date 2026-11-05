import XCTest
@testable import OpenspotCore

final class ItemLinesTests: XCTestCase {
    func testKeepsValidLinesAndReportsBadOnes() {
        let lines = ItemLines(output: """
        {"title":"Safari","subtitle":"Browser","run":"/Applications/Safari.app","file":"/Applications/Safari.app"}
        not json

        {"title":"Off","run":"off","symbol":"power"}
        """)

        XCTAssertEqual(lines.items, [
            SpotItem(title: "Safari", subtitle: "Browser", run: "/Applications/Safari.app", file: "/Applications/Safari.app"),
            SpotItem(title: "Off", run: "off", symbol: "power")
        ])
        XCTAssertEqual(lines.errors, ["not json"])
    }

    func testKeepsTheFirstItemOfEachRunValue() {
        let lines = ItemLines(output: """
        {"title":"One","run":"same"}
        {"title":"Two","run":"same"}
        """)

        XCTAssertEqual(lines.items.map(\.title), ["One"])
    }
}
