import XCTest
@testable import OpenspotCore

@MainActor
final class SpotCatalogTests: XCTestCase {
    private var root: URL!
    private var folder: URL!
    private var core: URL!
    private var file: ConfigFile!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-catalog-\(UUID().uuidString)")
        folder = root.appendingPathComponent("plugins")
        core = root.appendingPathComponent("core")
        file = ConfigFile(url: root.appendingPathComponent("config.toml"))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
        try "#!/bin/sh\n# subtitle=Open app\n# symbol=star\n".writeScript(to: core.appendingPathComponent("zebra.sh"))
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("apps.sh"))
        try "#!/bin/sh\n# read=5\n".writeScript(to: core.appendingPathComponent("cpu.sh"))
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private var spot: PluginCommand {
        get throws {
            try XCTUnwrap(ShippedSpot.commands(folder: folder, guide: folder, app: "", config: file, core: core).first { $0.name == "Spots" })
        }
    }

    func testItListsTheCoreSpotsByNameThenTheRowForAuthors() async throws {
        let items = try await spot.items(timeout: 1).items

        XCTAssertEqual(items.map(\.title), ["Apps", "Zebra", "Build your own"])
        XCTAssertEqual(items[1].subtitle, "Open app")
        XCTAssertEqual(items[1].symbol, "star")
        XCTAssertEqual(items.map(\.isOn), [false, false, false])
    }

    func testAPickTurnsASpotOnAndThenOff() async throws {
        let spot = try spot

        try await spot.perform(.item(SpotItem(title: "Apps", run: "apps")), timeout: 1)
        XCTAssertEqual(file.read().arrangement.enabled, ["apps"])
        let on = try await spot.items(timeout: 1).items
        XCTAssertEqual(on.first?.isOn, true)

        try await spot.perform(.item(SpotItem(title: "Apps", run: "apps")), timeout: 1)
        XCTAssertEqual(file.read().arrangement.enabled, [])
    }

    func testAPickKeepsThePanelOpen() async throws {
        let output = try await spot.items(timeout: 1)

        XCTAssertEqual(output.pick, .stay)
        XCTAssertFalse(output.keepsRecent)
    }

    func testASheetRereadsAfterAPick() async throws {
        let runs = SpotRuns()
        let sheet = runs.sheet(for: try spot)
        sheet.open {}
        for _ in 0..<200 where sheet.list.shown.isEmpty { try await Task.sleep(for: .milliseconds(5)) }

        sheet.pick(SpotItem(title: "Apps", run: "apps"))

        for _ in 0..<200 where sheet.list.shown.first?.isOn != true { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(sheet.list.shown.first?.isOn, true)
        XCTAssertEqual(file.read().arrangement.enabled, ["apps"])
    }

    func testAFileInThePluginsFolderShowsAsOnAndAPickChangesNothing() async throws {
        try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("apps.sh"))
        let spot = try spot

        let items = try await spot.items(timeout: 1).items
        XCTAssertEqual(items.first?.isOn, true)
        XCTAssertEqual(items.first?.subtitle, "In your plugins folder")

        try await spot.perform(.item(SpotItem(title: "Apps", run: "apps")), timeout: 1)
        XCTAssertEqual(file.read().arrangement.enabled, [])
    }

    func testTurningOnACoreWidgetLoadsItInAScan() async throws {
        try "[[widgets]]\nname = \"Overview\"\nlayout = \"single\"\nplaces = [\"cpu\"]\n".write(to: core.appendingPathComponent("overview.toml"), atomically: true, encoding: .utf8)
        let spot = try spot
        let items = try await spot.items(timeout: 1).items
        let row = try XCTUnwrap(items.first { $0.title == "Overview" })

        try await spot.perform(.item(row), timeout: 1)

        let scan = try PluginFolder(url: folder, core: core, enabled: file.read().arrangement.enabled).scan()
        XCTAssertEqual(scan.commands.map(\.name), ["Overview"])
    }

    func testAReadAfterAPickIsNotAFirstAnswer() async throws {
        let runs = SpotRuns()
        let sheet = runs.sheet(for: try spot)
        sheet.open {}
        for _ in 0..<200 where sheet.list.shown.isEmpty { try await Task.sleep(for: .milliseconds(5)) }

        sheet.pick(SpotItem(title: "Apps", run: "apps"))

        var waited = false
        for _ in 0..<200 where sheet.list.shown.first?.isOn != true {
            waited = waited || sheet.awaitsFirstAnswer
            await Task.yield()
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertFalse(waited || sheet.awaitsFirstAnswer)
    }

    func testAListWithRowsNeverWaitsForAFirstAnswerOnASlowRead() {
        var list = ItemList()
        XCTAssertFalse(list.holdsItems)
        list.replace([SpotItem(title: "Apps", run: "apps")])
        XCTAssertTrue(list.holdsItems)
        list.beginLoading()
        XCTAssertTrue(list.holdsItems)
    }

    func testSelectAllTurnsEachCoreSpotOnAndSkipsAFolderFile() async throws {
        try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("apps.sh"))
        let catalog = SpotCatalog(folder: folder, core: core, config: file)

        XCTAssertEqual(try catalog.answer([SpotCatalog.selectAllID]), "")

        XCTAssertEqual(file.read().arrangement.enabled, ["zebra"])
    }

    func testSelectAllIsACommandActionWithAKey() async throws {
        let actions = try await spot.items(timeout: 1).actions
        let action = try XCTUnwrap(actions.first { $0.id == SpotCatalog.selectAllID })

        XCTAssertEqual(action.title, "Select all")
        XCTAssertEqual(action.scope, .command)
        XCTAssertEqual(action.after, .stay)
        XCTAssertNotNil(action.key)
    }

    func testAnUnknownSpotIsAFault() async throws {
        let catalog = SpotCatalog(folder: folder, core: core, config: file)

        do {
            _ = try catalog.answer(["open", "gone"])
            XCTFail("It took a spot that does not exist.")
        } catch {}
    }

    func testTheRowForAuthorsHidesTheReview() async throws {
        let items = try await spot.items(timeout: 1).items

        XCTAssertEqual(items.last?.run, SpotCatalog.buildRun)
        XCTAssertEqual(items.last?.hides, [SpotCatalog.reviewID])
        XCTAssertNil(items.first?.hides)
    }

    func testItOffersAReviewOfACoreSpot() async throws {
        let actions = try await spot.items(timeout: 1).actions

        XCTAssertTrue(actions.map(\.id).contains(SpotCatalog.reviewID))
    }

    func testAReviewThatCannotAddShowsTheTextWithNoAddPart() throws {
        let scan = try PluginFolder(url: folder, core: core, enabled: ["apps"]).scan()
        let shared = try SharedSpot(sharing: XCTUnwrap(scan.commands.first), from: scan)

        let review = try SpotReview(spot: shared, folder: folder, canAdd: false)
        let sheet = try review.answer(["read"])

        XCTAssertFalse(sheet.contains("part=install"))
        XCTAssertTrue(sheet.contains("apps.sh"))
    }

    func testBuildIsOffTheGridAndHoldsTheToolsForAuthors() async throws {
        let commands = ShippedSpot.commands(folder: folder, guide: folder, app: "", config: file)
        let build = try XCTUnwrap(commands.first { $0.name == "Build" })

        XCTAssertFalse(build.isOnGrid)
        XCTAssertEqual(commands.map(\.name), ["Spots", "Settings", "Build"])
        let items = try await build.items(timeout: 1).items
        XCTAssertEqual(items.map(\.run), ["prompt", "sandbox", "guide", "folder"])
    }

    func testTheRowOfACoreSpotReadsOnFromItsBlock() throws {
        let block = try XCTUnwrap(TextBlock.blocks(in: "row=Apps\nrun=apps\non=true\n").first)

        XCTAssertEqual(SpotItem(block: block)?.isOn, true)
    }
}
