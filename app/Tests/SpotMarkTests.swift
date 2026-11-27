import XCTest
@testable import OpenspotCore

@MainActor
final class SpotMarkTests: PanelCase {
    private func call(_ arguments: [String]) async throws -> CommandAnswer {
        let api = try XCTUnwrap(model.runs.api)
        let request = CommandRequest(arguments: arguments, folder: folder.path)
        let parsed = api.admit(try XCTUnwrap(api.call(of: request)), request: request)
        let work = try XCTUnwrap(api.work(for: parsed, request: request, input: { "" }))
        return await work()
    }

    private func drinks(_ titles: KeyValuePairs<String, String> = ["coffee": "Coffee", "tea": "Tea"]) async throws {
        for (id, title) in titles { try script(id, toml: "title = '\(title)'", "printf 'item=a\\ntitle=A\\n'") }
        takeCalls()
        await model.reload()
    }

    private var shown: [String] {
        model.visible.filter { $0.spot.name != "Maker" }.map(\.id)
    }

    private func maker(of id: String, in place: URL) throws -> URL {
        let done = folder.appendingPathComponent("built-\(id)")
        try "printf 'frame=\\nbackground=true\\nbuilds=\(id)\\n---\\n'\nwhile [ ! -e '\(done.path)' ]; do sleep 0.02; done\n".writeScript(to: place, toml: "title = 'Maker'")
        return done
    }

    private func makerRun() throws -> SpotRun {
        let id = try XCTUnwrap(model.entries.first { $0.spot.name == "Maker" }?.id)
        return try XCTUnwrap(model.runs.sheets[id])
    }

    private func build(_ id: String) async throws -> URL {
        let done = try maker(of: id, in: core.appendingPathComponent("openspot.spot/maker.sh"))
        await model.reload()
        try makerRun().pressCard()
        try await wait("the build of \(id)") { self.model.runs.buildingIDs.contains(id) }
        return done
    }

    func testOnlyASpotOfTheAppHidesTheSpotItBuilds() async throws {
        try await drinks()
        _ = try maker(of: "coffee", in: spots.spotFile("maker"))
        await model.reload()

        try makerRun().pressCard()

        let call = try makerRun()
        try await wait("the frame of the maker") { call.calls.first?.builds == "coffee" }
        XCTAssertEqual(model.runs.buildingIDs, [])
        XCTAssertTrue(shown.contains("coffee"))
    }

    private func mark(_ id: String, _ word: String) async throws {
        let answer = try await call(["spot", "mark", id, word])
        XCTAssertEqual(answer.code, 0, answer.errors)
    }

    func testABuildingSpotShowsNowhereButStillRuns() async throws {
        try await drinks()
        _ = try model.files.config.change { $0.arrangement.set(isInMenuBar: true, of: "coffee") }
        await model.reload()
        XCTAssertEqual(model.menuBarMarks.map(\.id), ["coffee"])

        _ = try await build("coffee")

        XCTAssertEqual(shown, ["tea"])
        XCTAssertEqual(model.menuBarMarks.map(\.id), [])
        model.query = "Coffee"
        XCTAssertFalse(shown.contains("coffee"))
        let run = try await call(["spot", "run", "coffee"])
        XCTAssertEqual(run.code, 0, run.errors)
        XCTAssertTrue(run.output.contains("title=A"), run.output)
    }

    func testASpotShowsAgainInItsPlaceWhenItsBuildEnds() async throws {
        try await drinks()
        let before = shown
        let done = try await build("coffee")
        XCTAssertFalse(shown.contains("coffee"))

        FileManager.default.createFile(atPath: done.path, contents: nil)

        try await wait("the end of the build") { self.model.runs.buildingIDs.isEmpty }
        XCTAssertEqual(shown, before)
        XCTAssertEqual(model.files.config.read().arrangement.choices.map(\.id), [])
    }

    func testANewSpotIsFirstOnTheGridAndInItsSearchWithTheNewMark() async throws {
        try await drinks(["coffee": "Coffee", "tea": "Tea", "teapot": "Teapot"])
        let before = shown

        try await mark("teapot", "new")

        XCTAssertEqual(shown, ["teapot"] + before.filter { $0 != "teapot" })
        XCTAssertEqual(model.visible.map(\.isNew), [true, false, false])
        model.query = "tea"
        XCTAssertEqual(shown.first, "teapot")
        XCTAssertTrue(shown.contains("tea"))
        model.query = "coffee"
        XCTAssertEqual(shown, ["coffee"])
    }

    func testOpeningANewSpotClearsItsMarkForGood() async throws {
        try await drinks()
        let before = shown
        try await mark(before[1], "new")
        XCTAssertEqual(shown, before.reversed())
        model.isShown = true
        model.panelWillShow()

        model.tap(before[1])

        try await wait("the spot back in its place") { self.shown == before }
        XCTAssertEqual(model.visible.map(\.isNew), [false, false])
        XCTAssertFalse(model.files.config.read().arrangement.isNew(before[1]))
    }

    func testAMarkKeepsAcrossALoadOfTheConfig() async throws {
        try await drinks()
        let last = try XCTUnwrap(shown.last)
        try await mark(last, "new")

        let next = SpotsModel(host: host, files: model.files, runs: SpotRuns(stopPause: stopPause))
        await next.reload()

        XCTAssertEqual(next.visible.first?.id, last)
        next.quit()
    }

    func testAnUnknownSpotOrMarkFails() async throws {
        try await drinks()

        let unknown = try await call(["spot", "mark", "cocoa", "new"])
        let word = try await call(["spot", "mark", "tea", "hidden"])

        XCTAssertEqual(unknown.code, 1)
        XCTAssertEqual(unknown.errors, "Openspot has no spot `cocoa`. Run `openspot spot list` to see each one.\n")
        XCTAssertEqual(word.code, 2)
    }

    func testTheMarkOfARemovedSpotIsDropped() async throws {
        try await drinks()
        try await mark("tea", "new")
        try FileManager.default.removeItem(at: spots.spotFile("tea").deletingLastPathComponent())

        try await mark("coffee", "new")

        XCTAssertEqual(model.files.config.read().arrangement.newIDs, ["coffee"])
    }

    func testASelectedNewSpotNamesEditInTheFooter() async throws {
        try await drinks(["coffee": "Coffee", "tea": "Tea"])
        try await mark("tea", "new")
        model.isShown = true
        model.panelWillShow()

        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "tea" })
        XCTAssertTrue(model.hint.contains("⌘E Edit"), model.hint)
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "coffee" })
        XCTAssertFalse(model.hint.contains("⌘E Edit"), model.hint)
    }

    func testASpotThatABuildNamesBeforeItsFolderIsMadeStaysHidden() async throws {
        try await drinks()
        _ = try await build("cocoa")

        try script("cocoa", toml: "title = 'Cocoa'", "printf 'item=a\\ntitle=A\\n'")
        await model.reload()

        XCTAssertFalse(shown.contains("cocoa"))
        model.query = "cocoa"
        XCTAssertFalse(shown.contains("cocoa"))
    }

    func testASpotThatIsBuildingDoesNotOpen() async throws {
        try await drinks()
        _ = try await build("coffee")

        let answer = try await call(["spot", "open", "coffee"])

        XCTAssertEqual(answer.code, 1)
        XCTAssertTrue(answer.errors.contains("is still being built"), answer.errors)
        XCTAssertNil(model.openSheetID)
    }

    func testANewSpotNamesEditInItsFooterOnItsFirstOpen() async throws {
        try await drinks()
        try await mark("tea", "new")
        model.isShown = true
        model.panelWillShow()

        model.run(try XCTUnwrap(model.visible.first { $0.id == "tea" }))
        try await wait("the sheet") { model.openSheetID == "tea" }
        XCTAssertTrue(model.hint.contains("⌘E Edit"), model.hint)

        model.closeSheet(moving: false)
        try await wait("the mark off") { model.visible.first { $0.id == "tea" }?.isNew == false }
        model.run(try XCTUnwrap(model.visible.first { $0.id == "tea" }))
        try await wait("the sheet again") { model.openSheetID == "tea" }
        XCTAssertFalse(model.hint.contains("⌘E Edit"), model.hint)
    }
}
