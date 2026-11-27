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
}
