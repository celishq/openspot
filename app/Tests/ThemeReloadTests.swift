import XCTest
@testable import OpenspotCore

final class ThemeReloadTests: PanelCase {
    private let roomy = Theme(text: "[advanced]\npadding = 20\ncell = 70\n")

    override func tearDown() async throws {
        SpotTokens.take(Theme().layout)
        try await super.tearDown()
    }

    func testAReloadWhileHiddenLaysTheGridAndTheSheetsOutAgain() async throws {
        try await openList()
        let sheet = try XCTUnwrap(model.sheets["list"]?.sheetRect)
        let grid = model.gridHeight
        host.dismiss()

        model.take(roomy)

        XCTAssertEqual(host.layOuts, [roomy.layout])
        XCTAssertEqual(model.sheets["list"]?.sheetRect.height, sheet.height + 14)
        XCTAssertGreaterThan(model.gridHeight, grid)
        XCTAssertEqual(model.gridHeight, SpotTokens.contentHeight(gridHeight: SpotGrid.height(of: model.placements)))
    }

    func testAReloadOfTheSizesScrollsTheGridToTheTop() async throws {
        try await openList()
        host.dismiss()
        model.gridScrolled(to: 120)
        model.cardScroll = 120

        model.take(roomy)

        XCTAssertEqual(model.gridScroll, 0)
        XCTAssertEqual(model.cardScroll, 0)
    }

    func testAReloadWhileShownWaitsForTheHide() async throws {
        try await openList()

        model.take(roomy)

        XCTAssertEqual(host.layOuts, [])
        XCTAssertEqual(SpotTokens.padding, 13)
        host.dismiss()
        XCTAssertEqual(host.layOuts, [roomy.layout])
        XCTAssertEqual(SpotTokens.padding, 20)
    }

    func testAReloadThatKeepsTheSizesLaysNothingOut() async throws {
        try await openList()
        host.dismiss()

        model.take(Theme(text: "[dark]\nfill = 0.2\n"))

        XCTAssertEqual(host.layOuts, [])
    }

    func testALookChangePaintsAndTellsNoReaderOfTheLayout() async throws {
        try await openList()
        host.dismiss()
        let hover = Theme(text: "[dark]\nfill = 0.2\n")
        nonisolated(unsafe) var told = false
        withObservationTracking { _ = (model.gridHeight, model.placements, model.groupBands, model.sheets["list"]?.sheetRect) } onChange: { told = true }

        model.take(hover)

        XCTAssertEqual(host.paints.last, hover.look)
        XCTAssertEqual(host.layOuts, [])
        XCTAssertFalse(told)
    }

    func testALookChangeWhileShownPaintsAtOnce() async throws {
        try await openList()
        let hover = Theme(text: "[dark]\nfill = 0.2\n")

        model.take(hover)

        XCTAssertEqual(host.paints.last, hover.look)
    }

    func testARadiusChangeTellsTheHostToDrawTheEdgeAgain() async throws {
        try await openList()
        host.dismiss()
        let round = Theme(text: "[look]\ncorner = 30\n")

        model.take(round)

        XCTAssertEqual(host.layOuts.map(\.radius.card), [30])
        XCTAssertEqual(BackdropEdge.blurs.map(\.corner), BackdropEdge.blurs.map { 30 + SpotTokens.halo - $0.inset })
    }

    func testABackdropSizeAndPaddingMoveTheEdgesOfTheBlur() async throws {
        try await openList()
        host.dismiss()
        let wide = Theme(text: "[look]\nbackdrop = \"tint\"\nreach = \"screen\"\n\n[advanced]\nbackdrop-blur = 6\nhalo-size = 84\nhalo-padding = 20\n")

        model.take(wide)

        let reach = { (edge: BackdropEdge) in SpotTokens.halo - edge.inset + SpotTokens.backdropReach * edge.softness }
        XCTAssertEqual(host.layOuts.map(\.backdrop.size), [84])
        XCTAssertEqual(SpotTokens.backdrop, wide.layout.backdrop)
        XCTAssertEqual(BackdropEdge.blurs.map(\.softness), [8, 8, 8])
        XCTAssertEqual(reach(BackdropEdge.blurs[0]), 84, accuracy: 0.001)
        for (edge, reach) in zip(BackdropEdge.blurs, [60.0, 48, 36]) { XCTAssertEqual(SpotTokens.halo - edge.inset, reach, accuracy: 0.001) }
    }

    func testAPaddingTooCloseToTheSizeKeepsTheLeastFade() async throws {
        try await openList()
        host.dismiss()

        model.take(Theme(text: "[advanced]\nhalo-size = 30\nhalo-padding = 74\n"))

        let reach = { (edge: BackdropEdge) in SpotTokens.halo - edge.inset + SpotTokens.backdropReach * edge.softness }
        XCTAssertEqual(reach(BackdropEdge.blurs[0]), 30, accuracy: 0.001)
        XCTAssertEqual(BackdropEdge.blurs[0].softness, SpotTokens.backdropLeastFade / (SpotTokens.backdropSteps[0] + SpotTokens.backdropReach))
    }

    func testAChangedBackgroundReachesEachColourThatFollowsIt() async throws {
        try await openList()
        host.dismiss()
        let night = Theme(text: "[dark]\nbackground = \"#282A36\"\nink = \"#F8F8F2\"\n")

        model.take(night)

        let dark = try XCTUnwrap(host.paints.last?.dark)
        XCTAssertEqual(dark.glassTint, ThemeColor(text: "#282A364D"))
        XCTAssertEqual(dark.onSolid, ThemeColor(text: "#282A36"))
        XCTAssertEqual(dark.window, ThemeColor(text: "#494B54"))
        XCTAssertNotEqual(dark.fill, Theme().look.dark.fill)
    }

    func testAChangedDensityReachesEachGapAndPadding() async throws {
        try await openList()
        host.dismiss()

        model.take(Theme(text: "[look]\ndensity = 2\n"))

        XCTAssertEqual([SpotTokens.padding, SpotTokens.columnGap, SpotTokens.rowGap, SpotTokens.listRowGap, SpotTokens.menuPadding], [26, 22, 24, 12, 16])
        XCTAssertEqual(SpotTokens.cell, 64)
    }

    func testALayoutHeldUntilTheHideIsTheLastOneTaken() async throws {
        try await openList()
        let round = Theme(text: "[look]\ncorner = 30\n")

        model.take(roomy)
        model.take(round)
        host.dismiss()

        XCTAssertEqual(host.layOuts, [round.layout])
    }
}
