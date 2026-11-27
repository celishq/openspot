import XCTest
@testable import OpenspotCore

@MainActor
final class DraftSpotTests: PanelCase {
    private func call(_ arguments: [String]) async throws -> CommandAnswer {
        let api = try XCTUnwrap(model.runs.api)
        let request = CommandRequest(arguments: arguments, folder: folder.path)
        let parsed = api.admit(try XCTUnwrap(api.call(of: request)), request: request)
        let work = try XCTUnwrap(api.work(for: parsed, request: request, input: { "" }))
        return await work()
    }

    private func cocoa(state: String = "draft") async throws {
        try script("tea", toml: "title = 'Tea'", "printf 'item=a\\ntitle=A\\n'")
        try script("cocoa", toml: "title = 'Cocoa'\nstate = \"\(state)\"\n\n[on]\nschedule = [\"0 9 * * *\"]\n\n[actions.save]\ntitle = \"Save to Cocoa\"\ninputs.text = { type = \"text\", required = true }", "printf 'item=a\\ntitle=A\\n'")
        takeCalls()
        await model.reload()
    }

    private var shown: [String] {
        model.visible.map(\.id)
    }

    func testADraftLoadsButShowsNowhere() async throws {
        try await cocoa()
        _ = try model.files.config.change { $0.arrangement.set(isInMenuBar: true, of: "cocoa") }
        await model.reload()

        XCTAssertNotNil(model.entries.first { $0.id == "cocoa" })
        XCTAssertEqual(shown, ["tea"])
        XCTAssertEqual(model.menuBarMarks.map(\.id), [])
        model.query = "Cocoa"
        XCTAssertFalse(shown.contains("cocoa"))
    }

    func testADraftRunsNoTriggerOfItsOwn() async throws {
        try await cocoa()

        let spot = try XCTUnwrap(model.entries.first { $0.id == "cocoa" }?.spot)

        XCTAssertTrue(spot.isDraft)
        XCTAssertEqual(spot.triggers.schedule, [])
    }

    func testADraftRunsWhenAskedButDoesNotOpen() async throws {
        try await cocoa()

        let run = try await call(["spot", "run", "cocoa"])
        let open = try await call(["spot", "open", "cocoa"])

        XCTAssertEqual(run.code, 0, run.errors)
        XCTAssertTrue(run.output.contains("title=A"), run.output)
        XCTAssertEqual(open.code, 1)
        XCTAssertTrue(open.errors.contains("is a draft"), open.errors)
        XCTAssertNil(model.openSheetID)
    }

    func testASpotWithAnotherStateDoesNotLoad() async throws {
        try await cocoa(state: "done")

        XCTAssertNil(model.entries.first { $0.id == "cocoa" && $0.spot.host == nil })
    }

    func testADraftIsNotOfferedToArrange() async throws {
        try await cocoa()

        XCTAssertEqual(model.gridSpots().map(\.id), ["tea"])
        XCTAssertEqual(model.pin("cocoa"), .unknown)
    }

    func testADraftOffersNoActionAndIsNotListedAsYours() async throws {
        try await cocoa()

        let spot = try XCTUnwrap(model.entries.first { $0.id == "cocoa" }?.spot)
        XCTAssertTrue(spot.chipActions.isEmpty)
        XCTAssertTrue(spot.bindings.isEmpty)
        let revealed = await model.reveal("cocoa")
        XCTAssertFalse(revealed)
        XCTAssertFalse(SpotCatalog(folder: model.files.spots, arrangement: SpotChoices(), stores: [], lock: nil).items.contains { $0.id == "cocoa" })
    }
}
