import XCTest
@testable import OpenspotCore

/// Proves the Spots spot of the app: a small card on the grid that a search for "edit spots" finds, whose press opens the
/// grid of Edit Spots through the API.
final class CatalogSpotTests: BuiltInCase {
    override func setUp() async throws {
        try await super.setUp()
        try "#!/bin/sh\n# detail=Open app\n# icon=star\n".writeScript(to: core.appendingPathComponent("zebra.spot/zebra.sh"))
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("apps.spot/apps.sh"))
        try "#!/bin/sh\n# on=clock.5\n".writeScript(to: core.appendingPathComponent("cpu.spot/cpu.sh"))
    }

    private var catalog: Spot {
        get throws {
            try spot("spots")
        }
    }

    func testItIsASmallCardOnTheGridWithItsLetterThatAKeywordFinds() throws {
        let spot = try catalog
        let defaults = Config(text: try String(contentsOf: repoSpots.deletingLastPathComponent().appendingPathComponent("app/defaults.toml"), encoding: .utf8))

        XCTAssertEqual(spot.name, "Spots")
        XCTAssertEqual(spot.subtitle, "Edit Spots")
        XCTAssertNil(spot.read)
        XCTAssertEqual(defaults.arrangement.size(of: spot.id), .small)
        XCTAssertTrue(spot.isOnGrid)
        XCTAssertEqual(spot.keywords, ["edit spots"])
        XCTAssertEqual(defaults.arrangement.choices.first { $0.id == spot.id }?.letter, "p")
    }

    func testAPressOpensEditSpotsInTheApp() async throws {
        _ = try await catalog.perform(SpotAction(arguments: ["open"]), timeout: 5)

        let opened = await app.opened
        XCTAssertEqual(opened, ["grid"])
    }

    func testTurningOnACoreWidgetLoadsItInAScan() throws {
        try "#!/bin/sh\n# title=Overview\n# grid.square=cpu\n".writeScript(to: core.appendingPathComponent("overview.spot/overview.sh"))

        try file.turn("overview", on: true)

        let scan = try SpotsFolder(url: spots, core: core, enabled: file.read().arrangement.enabled).scan()
        XCTAssertEqual(scan.spots.filter(\.headerState.isOnGrid).map(\.name), ["Overview"])
    }

    func testTheSpotsSpotShowsWithAnEmptyFolder() throws {
        let scan = try SpotsFolder(url: spots, core: repoSpots).scan()

        XCTAssertTrue(scan.spots.contains { $0.id == "openspot/spots" })
        XCTAssertEqual(scan.refused, [])
    }

    func testAListWithRowsNeverWaitsForAFirstAnswerOnASlowRead() {
        var list = ItemList()
        XCTAssertFalse(list.holdsItems)
        list.replace([SpotItem(title: "Apps", run: "apps")])
        XCTAssertTrue(list.holdsItems)
        list.beginLoading()
        XCTAssertTrue(list.holdsItems)
    }

    func testAReviewThatCannotAddShowsTheTextWithNoAddPart() throws {
        let scan = try SpotsFolder(url: spots, core: core, enabled: ["apps"]).scan()
        let shared = try SpotPackage(sharing: XCTUnwrap(scan.spots.first { $0.id == "apps" }), from: scan)

        let review = try ReviewSpot(spot: shared, folder: spots, canAdd: false)
        let sheet = try review.answer(["read"])

        XCTAssertFalse(sheet.contains("text=install"))
        XCTAssertTrue(sheet.contains("apps.sh"))
    }

    func testARowIsOnByItsValue() throws {
        let on = try XCTUnwrap(TextBlock.blocks(in: "row=apps\ntitle=Apps\nvalue=true\n").first)
        let old = try XCTUnwrap(TextBlock.blocks(in: "row=apps\ntitle=Apps\non=true\n").first)

        XCTAssertEqual(SpotItem(block: on)?.isOn, true)
        XCTAssertEqual(SpotItem(block: old)?.isOn, false)
    }
}
