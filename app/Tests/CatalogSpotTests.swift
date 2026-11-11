import XCTest
@testable import OpenspotCore

/// Proves the Spots spot of the app: it links to New spot first, then lists the core spots, and a pick turns one on or
/// off through the API.
final class CatalogSpotTests: BuiltInCase {
    override func setUp() async throws {
        try await super.setUp()
        try "#!/bin/sh\n# detail=Open app\n# icon=star\n".writeScript(to: core.appendingPathComponent("zebra.sh"))
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("apps.sh"))
        try "#!/bin/sh\n# read=5\n".writeScript(to: core.appendingPathComponent("cpu.sh"))
    }

    private var catalog: Spot {
        get throws {
            try spot("spots")
        }
    }

    func testItIsASmallListOnTheGridWithItsLetter() throws {
        let spot = try catalog
        let defaults = Config(text: try String(contentsOf: repoPlugins.deletingLastPathComponent().appendingPathComponent("app/defaults.toml"), encoding: .utf8))

        XCTAssertEqual(spot.name, "Spots")
        XCTAssertEqual(spot.subtitle, "Turn on")
        XCTAssertEqual(spot.kind, .list)
        XCTAssertEqual(spot.size, .small)
        XCTAssertTrue(spot.isOnGrid)
        XCTAssertEqual(defaults.arrangement.choices.first { $0.id == spot.id }?.letter, "p")
    }

    func testTheSpotsSpotShowsWithAnEmptyFolder() throws {
        let scan = try SpotFolder(url: plugins, core: repoPlugins).scan()

        XCTAssertTrue(scan.spots.contains { $0.id == "openspot/spots" })
        XCTAssertEqual(scan.refused, [])
    }

    func testItListsTheRowForAuthorsThenTheCoreSpotsByName() async throws {
        let items = try await catalog.items(timeout: 5).items

        XCTAssertEqual(items.map(\.title), ["New spot", "Apps", "Zebra"])
        XCTAssertEqual(items[2].subtitle, "Open app")
        XCTAssertEqual(items[2].symbol, "star")
        XCTAssertEqual(items.map(\.isOn), [false, false, false])
    }

    func testAPickTurnsASpotOnAndThenOffAndTellsTheApp() async throws {
        let spot = try catalog

        try await spot.perform(.item(SpotItem(title: "Apps", run: "apps")), timeout: 5)
        XCTAssertEqual(file.read().arrangement.enabled, ["apps"])
        let on = try await spot.items(timeout: 5).items
        XCTAssertEqual(on.first { $0.run == "apps" }?.isOn, true)

        try await spot.perform(.item(SpotItem(title: "Apps", run: "apps")), timeout: 5)
        XCTAssertEqual(file.read().arrangement.enabled, [])
        let changes = await app.changes
        XCTAssertEqual(changes, 2)
    }

    func testAPickKeepsThePanelOpen() async throws {
        let output = try await catalog.items(timeout: 5)

        XCTAssertEqual(output.pick, .stay)
        XCTAssertFalse(output.keepsRecent)
    }

    func testASheetRereadsAfterAPick() async throws {
        let runs = SpotRuns()
        defer { runs.quit() }
        let sheet = runs.sheet(for: try catalog)
        sheet.open {}
        for _ in 0..<500 where sheet.list.shown.isEmpty { try await Task.sleep(for: .milliseconds(10)) }

        sheet.pick(SpotItem(title: "Apps", run: "apps"))

        let apps = { sheet.list.shown.first { $0.run == "apps" } }
        for _ in 0..<500 where apps()?.isOn != true { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(apps()?.isOn, true)
        XCTAssertEqual(file.read().arrangement.enabled, ["apps"])
    }

    func testAFileInThePluginsFolderShowsAsOnAndAPickChangesNothing() async throws {
        try "#!/bin/sh\n".writeScript(to: plugins.appendingPathComponent("apps.sh"))
        let spot = try catalog

        let items = try await spot.items(timeout: 5).items
        let apps = try XCTUnwrap(items.first { $0.run == "apps" })
        XCTAssertEqual(apps.isOn, true)
        XCTAssertEqual(apps.subtitle, "In your plugins folder")

        let toast = try await spot.perform(.item(SpotItem(title: "Apps", run: "apps")), timeout: 5)
        XCTAssertEqual(toast, "This spot is a file in your plugins folder.")
        XCTAssertEqual(file.read().arrangement.enabled, [])
    }

    func testTurningOnACoreWidgetLoadsItInAScan() async throws {
        try "[[widgets]]\ntitle = \"Overview\"\ngrid = [\"cpu\"]\nsize = \"square\"\n".write(to: core.appendingPathComponent("overview.toml"), atomically: true, encoding: .utf8)
        let spot = try catalog
        let items = try await spot.items(timeout: 5).items
        let row = try XCTUnwrap(items.first { $0.title == "Overview" })

        try await spot.perform(.item(row), timeout: 5)

        let scan = try SpotFolder(url: plugins, core: core, enabled: file.read().arrangement.enabled).scan()
        XCTAssertEqual(scan.spots.filter(\.headerState.isOnGrid).map(\.name), ["Overview"])
    }

    func testAReadAfterAPickIsNotAFirstAnswer() async throws {
        let runs = SpotRuns()
        defer { runs.quit() }
        let sheet = runs.sheet(for: try catalog)
        sheet.open {}
        for _ in 0..<500 where sheet.list.shown.isEmpty { try await Task.sleep(for: .milliseconds(10)) }

        sheet.pick(SpotItem(title: "Apps", run: "apps"))

        var waited = false
        for _ in 0..<500 where sheet.list.shown.first { $0.run == "apps" }?.isOn != true {
            waited = waited || sheet.kind == .waiting
            await Task.yield()
            try await Task.sleep(for: .milliseconds(2))
        }
        XCTAssertFalse(waited || sheet.kind == .waiting)
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
        try "#!/bin/sh\n".writeScript(to: plugins.appendingPathComponent("apps.sh"))

        let toast = try await catalog.perform(SpotAction(arguments: ["select-all"]), timeout: 5)

        XCTAssertNil(toast)
        XCTAssertEqual(file.read().arrangement.enabled, ["zebra"])
    }

    func testSelectAllIsACommandActionWithAKey() async throws {
        let actions = try await catalog.items(timeout: 5).actions
        let action = try XCTUnwrap(actions.first { $0.title == "Select all" })

        XCTAssertEqual(action.scope, .command)
        XCTAssertEqual(action.after, .stay)
        XCTAssertNotNil(action.key)
    }

    func testAnUnknownSpotIsAFault() async throws {
        do {
            _ = try await catalog.perform(.item(SpotItem(title: "Gone", run: "gone")), timeout: 5)
            XCTFail("It took a spot that does not exist.")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, "Spots has no such spot.")
        }
        XCTAssertEqual(file.read().arrangement.enabled, [])
    }

    func testTheRowForAuthorsHidesTheReviewAndOpensNewSpot() async throws {
        let spot = try catalog
        let output = try await spot.items(timeout: 5)
        let items = output.items
        let review = try XCTUnwrap(output.actions.first { $0.title == "Review code" })

        _ = try await spot.perform(.item(try XCTUnwrap(items.first)), timeout: 5)

        XCTAssertEqual(items.first?.title, "New spot")
        XCTAssertEqual(items.first?.hides, [review.id])
        XCTAssertNil(items.last?.hides)
        let opened = await app.opened
        XCTAssertEqual(opened, ["open openspot/new"])
    }

    func testItOffersAReviewOfACoreSpotThatStaysInTheSheet() async throws {
        let spot = try catalog
        let actions = try await spot.items(timeout: 5).actions
        let review = try XCTUnwrap(actions.first { $0.title == "Review code" })

        _ = try await spot.perform(.action(review, item: SpotItem(title: "Apps", run: "apps")), timeout: 5)

        XCTAssertEqual(review.after, .stay)
        let opened = await app.opened
        XCTAssertEqual(opened, ["review apps"])
    }

    func testAReviewThatCannotAddShowsTheTextWithNoAddPart() throws {
        let scan = try SpotFolder(url: plugins, core: core, enabled: ["apps"]).scan()
        let shared = try SharedSpot(sharing: XCTUnwrap(scan.spots.first { $0.id == "apps" }), from: scan)

        let review = try ReviewSpot(spot: shared, folder: plugins, canAdd: false)
        let sheet = try review.answer(["read"])

        XCTAssertFalse(sheet.contains("text=install"))
        XCTAssertTrue(sheet.contains("apps.sh"))
    }

    func testTheFirstLaunchListOffersTheLoginRowAndAPickTurnsItOn() async throws {
        await app.set(update: nil, calls: 0, isFirstLaunch: true)
        offerLogin()
        let spot = try catalog

        let rows = try await spot.items(timeout: 5).items
        XCTAssertEqual(rows.last?.run, "open_at_login")
        XCTAssertEqual(rows.last?.isOn, false)
        XCTAssertEqual(rows.last?.hides, rows.first?.hides)

        _ = try await spot.perform(.item(try XCTUnwrap(rows.last)), timeout: 5)
        XCTAssertTrue(opensAtLogin)
        _ = try await spot.perform(.item(try XCTUnwrap(rows.last)), timeout: 5)
        XCTAssertFalse(opensAtLogin)
    }

    func testTheNormalListHasNoLoginRow() async throws {
        let rows = try await catalog.items(timeout: 5).items

        XCTAssertEqual(rows.map(\.run), ["new", "apps", "zebra"])
    }

    func testAddAsksForASourceAndIsTheFormThatASearchWithNoRowOpens() async throws {
        let spot = try catalog
        let actions = try await spot.items(timeout: 5).actions
        let add = try XCTUnwrap(actions.first { $0.scope == .command && $0.isForm })

        let form = try await spot.form(add, item: nil, timeout: 5)

        XCTAssertEqual(add.id, "add")
        XCTAssertEqual(add.title, "Add a spot")
        XCTAssertEqual(form.fields.map(\.name), ["source"])
    }

    func testAddAddsASpotFromALocalGitRepositoryAndSaysSo() async throws {
        GitRepo.isolate()
        let repo = try GitRepo(at: root.appendingPathComponent("sources/coffee"))
        try repo.commit(["coffee.sh": "#!/bin/sh\n# title=Coffee\n"])
        let spot = try catalog
        let actions = try await spot.items(timeout: 5).actions
        let add = try XCTUnwrap(actions.first { $0.id == "add" })

        let toast = try await spot.perform(.action(add, item: nil), input: "source=\(repo.url.path)\n", timeout: 50)

        XCTAssertEqual(toast?.hasPrefix("Added coffee at "), true, toast ?? "")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: plugins.appendingPathComponent("coffee/coffee.sh").path))
    }

    func testAddOfASourceThatIsGoneFailsWithItsReason() async throws {
        let spot = try catalog
        let actions = try await spot.items(timeout: 5).actions
        let add = try XCTUnwrap(actions.first { $0.id == "add" })

        do {
            _ = try await spot.perform(.action(add, item: nil), input: "source=\(root.path)/gone\n", timeout: 50)
            XCTFail("It added a spot from nothing.")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, "Openspot cannot find \(root.path)/gone.")
        }
    }

    func testARowIsOnByItsValue() throws {
        let on = try XCTUnwrap(TextBlock.blocks(in: "row=apps\ntitle=Apps\nvalue=true\n").first)
        let old = try XCTUnwrap(TextBlock.blocks(in: "row=apps\ntitle=Apps\non=true\n").first)

        XCTAssertEqual(SpotItem(block: on)?.isOn, true)
        XCTAssertEqual(SpotItem(block: old)?.isOn, false)
    }
}
