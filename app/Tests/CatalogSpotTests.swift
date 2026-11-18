import XCTest
@testable import OpenspotCore

final class CatalogSpotTests: BuiltInCase {
    override func setUp() async throws {
        try await super.setUp()
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("zebra.spot/zebra.sh"), toml: "detail = 'Open app'\nicon = 'star'")
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("apps.spot/apps.sh"))
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("cpu.spot/cpu.sh"), toml: "on = ['clock.5']")
    }

    private var catalog: Spot {
        get throws {
            try spot("spots")
        }
    }

    func testItIsAWideCardOnTheDefaultGridThatAKeywordFinds() throws {
        let spot = try catalog
        let defaults = Config(text: try String(contentsOf: repoSpots.deletingLastPathComponent().appendingPathComponent("app/defaults.toml"), encoding: .utf8))

        XCTAssertEqual(spot.name, "Spots")
        XCTAssertEqual(spot.subtitle, "Edit Spots")
        XCTAssertNil(spot.read)
        XCTAssertEqual(defaults.arrangement.size(of: spot.id), .wide)
        XCTAssertTrue(spot.isOnGrid)
        XCTAssertEqual(spot.keywords, ["edit spots"])
    }

    func testAPressOpensEditSpotsInTheApp() async throws {
        _ = try await catalog.perform(SpotAction(arguments: ["open"]), timeout: 60)

        let opened = await app.opened
        XCTAssertEqual(opened, ["grid"])
    }

    func testTurningOnACoreWidgetLoadsItInAScan() throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("overview.spot/overview.sh"), toml: "title = 'Overview'\n'grid.square' = ['cpu']")

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
        let sheet = try review.answer(["show"])

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
