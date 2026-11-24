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
        model.visible.map(\.id)
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

        try await mark("coffee", "building")

        XCTAssertEqual(shown, ["tea"])
        XCTAssertEqual(model.menuBarMarks.map(\.id), [])
        model.query = "Coffee"
        XCTAssertFalse(shown.contains("coffee"))
        let run = try await call(["spot", "run", "coffee"])
        XCTAssertEqual(run.code, 0, run.errors)
        XCTAssertTrue(run.output.contains("title=A"), run.output)
    }

    func testNoneShowsABuildingSpotAgainInItsPlace() async throws {
        try await drinks()
        let before = shown
        try await mark("coffee", "building")

        try await mark("coffee", "none")

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
        XCTAssertNil(model.files.config.read().arrangement.mark(of: before[1]))
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

        try await mark("coffee", "building")

        XCTAssertNil(model.files.config.read().arrangement.mark(of: "tea"))
        XCTAssertEqual(model.files.config.read().arrangement.mark(of: "coffee"), .building)
    }
}
