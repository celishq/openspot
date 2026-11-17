import XCTest
@testable import OpenspotCore

final class ThemeReloadTests: PanelCase {
    private let roomy = Theme(text: "[space]\npadding = 20\ncell = 70\n")

    override func tearDown() async throws {
        SpotTokens.take(Theme())
        MotionTokens.take(Theme().motion)
        try await super.tearDown()
    }

    func testAReloadWhileHiddenLaysTheGridAndTheSheetsOutAgain() async throws {
        try await openList()
        let sheet = try XCTUnwrap(model.sheets["list"]?.sheetRect)
        let grid = model.gridHeight
        host.dismiss()

        model.take(roomy)

        XCTAssertEqual(host.layOuts, 1)
        XCTAssertEqual(model.sheets["list"]?.sheetRect.height, sheet.height + 14)
        XCTAssertGreaterThan(model.gridHeight, grid)
        XCTAssertEqual(model.gridHeight, SpotTokens.contentHeight(gridHeight: SpotGrid.height(of: model.placements)))
    }

    func testAReloadWhileShownWaitsForTheHide() async throws {
        try await openList()

        model.take(roomy)

        XCTAssertEqual(host.layOuts, 0)
        XCTAssertEqual(SpotTokens.padding, 13)
        host.dismiss()
        XCTAssertEqual(host.layOuts, 1)
        XCTAssertEqual(SpotTokens.padding, 20)
    }

    func testAReloadThatKeepsTheSizesLaysNothingOut() async throws {
        try await openList()
        host.dismiss()

        model.take(Theme(text: "[shared]\nhover = 0.2\n"))

        XCTAssertEqual(host.layOuts, 0)
    }
}
