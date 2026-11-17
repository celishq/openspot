import XCTest
@testable import OpenspotCore

final class ThemeLayoutTests: XCTestCase {
    private let builtInURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Themes/openspot.theme/theme.toml")

    override func tearDown() {
        SpotTokens.take(Theme().layout)
    }

    private func read(copy text: String) throws -> Theme {
        let folder = try temporaryFolder()
        let copy = folder.appendingPathComponent("themes/openspot.theme/theme.toml")
        try FileManager.default.createDirectory(at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: copy, atomically: true, encoding: .utf8)
        return ThemeFolder.read(builtIn: builtInURL, copy: copy)
    }

    func testTheBuiltInThemeKeepsTodaysLayout() {
        SpotTokens.take(ThemeFolder.read(builtIn: builtInURL).layout)

        XCTAssertEqual(SpotTokens.cell, 64)
        XCTAssertEqual(SpotTokens.gridWidth, 289)
        XCTAssertEqual(SpotTokens.panelWidth, 469)
        XCTAssertEqual(SpotTokens.panelHeight, 734)
        XCTAssertEqual(SpotTokens.sheetRect(rows: 1), CGRect(x: 90, y: 90, width: 289, height: 166))
        XCTAssertEqual(SpotTokens.partsWidth, 263)
    }

    func testACopyWithNewSizesMovesTheGridAndTheSheet() throws {
        let before = SpotTokens.sheetRect(rows: 1)

        SpotTokens.take(try read(copy: "[look]\ncorner = 30\n\n[advanced]\npadding = 20\ncell = 70\ncolumn-gap = 15\n").layout)

        XCTAssertEqual(SpotTokens.padding, 20)
        XCTAssertEqual(SpotTokens.cardRadius, 30)
        XCTAssertEqual(SpotTokens.width(columns: 2), 155)
        XCTAssertEqual(SpotTokens.gridWidth, 325)
        XCTAssertEqual(SpotTokens.gridOrigin(scrollOffset: 0, left: 0), CGPoint(x: 90, y: 172))
        XCTAssertEqual(SpotTokens.sheetRect(rows: 1).height, before.height + 14)
        XCTAssertEqual(SpotTokens.sheetRect(rows: 1).width, 325)
        XCTAssertEqual(SurfaceEdge.sheet.radius, 30)
        XCTAssertEqual(SpotTokens.partsWidth, 325 - 40)
    }

    func testACardCornerOfTheThemeRoundsEveryCardSoAOneRowCardIsACapsuleOnlyAtTheBuiltInCorner() throws {
        let strip = CGRect(x: 0, y: 0, width: SpotTokens.width(columns: 2), height: SpotTokens.cell)

        SpotTokens.take(try read(copy: "[look]\ncorner = 10\n").layout)

        XCTAssertEqual(SurfaceEdge(card: .wide).corner(in: strip), SpotTokens.cell / 2 * 10 / 26, accuracy: 0.001)
        XCTAssertFalse(SurfaceEdge(card: .small).isCircular(in: CGRect(x: 0, y: 0, width: SpotTokens.cell, height: SpotTokens.cell)))
        XCTAssertEqual(SurfaceEdge(card: .square).radius, 10)

        SpotTokens.take(try read(copy: "[look]\ncorner = 0\n").layout)

        XCTAssertEqual(SurfaceEdge(card: .wide).radius, 0)
    }

    func testACopyWithANewDurationChangesTheMotion() throws {
        MotionTokens.take(try read(copy: "[advanced]\ngrow = 0.3\nlifted-scale = 1.1\n").layout.motion)

        XCTAssertEqual(MotionTokens.grow, 0.3 * MotionTokens.slow)
        XCTAssertEqual(MotionTokens.liftedScale, 1.1)
        XCTAssertEqual(MotionTokens.move, 0.25 * MotionTokens.slow)
    }
}
