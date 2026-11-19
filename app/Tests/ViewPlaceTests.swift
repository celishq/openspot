import XCTest
@testable import OpenspotCore

@MainActor
final class ViewPlaceTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: FakeHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-view-place-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        suite = "openspot-view-place-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        host = FakeHost()
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
            home: folder,
            defaults: defaults
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2))
        host.model = model
        for name in ["list", "other"] {
            try TestSpot(header: "on=sheet.open", body: "printf 'row=a\\ntitle=Apple\\n'").write(to: spots.spotFile(name))
        }
        try TestSpot(header: "on=sheet.open\noffers=card\noffers=window", body: "printf 'row=a\\ntitle=Apple\\n'").write(to: spots.spotFile("store"))
        await model.reload()
    }

    override func tearDown() async throws {
        model.quit()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    private var spots: URL {
        folder.appendingPathComponent("spots", isDirectory: true)
    }

    private func openList() async throws {
        model.isShown = true
        model.pushFirst("list", moving: false)
        try await wait("the sheet of the list") { self.model.openSheetID == "list" }
    }

    private func floatList() async throws {
        model.float("list")
        try await wait("the float of the list") { self.host.floats == ["list"] && self.model.runs.floating == ["list"] }
    }

    func testAViewOnACardClosesNoSheetAndNoFloat() async throws {
        try await openList()
        try await floatOther()

        model.close(.card)

        XCTAssertEqual(model.openSheetID, "list")
        XCTAssertEqual(host.landings, [])
        XCTAssertEqual(model.runs.floating, ["other"])
    }

    private func floatOther() async throws {
        model.float("other")
        try await wait("the float of the other spot") { self.model.runs.floating == ["other"] }
    }

    func testAViewInTheOpenSheetOfItsSpotClosesIt() async throws {
        try await openList()

        model.close(.sheet("list"))

        XCTAssertNil(model.openSheetID)
    }

    func testAViewOfOneSpotDoesNotCloseTheOpenSheetOfAnother() async throws {
        try await openList()

        model.close(.sheet("other"))

        XCTAssertEqual(model.openSheetID, "list")
    }

    func testAViewInAFloatLandsItAndLeavesTheOpenSheet() async throws {
        try await openList()
        try await floatOther()

        model.close(.detached("other"))

        XCTAssertEqual(host.landings, ["other"])
        XCTAssertEqual(model.runs.floating, [])
        XCTAssertEqual(model.openSheetID, "list")
    }

    func testAViewInAWindowLandsItAndOneOfALandedSpotLandsNothing() async throws {
        model.openWindow("store")
        try await wait("the window") { self.host.windows == ["store"] && self.model.runs.floating == ["store"] }

        model.close(.detached("list"))
        XCTAssertEqual(host.landings, [])
        model.close(.detached("store"))

        XCTAssertEqual(host.landings, ["store"])
        XCTAssertEqual(model.runs.floating, [])
    }

    func testOpeningAWindowThatIsOpenReadsItAgain() async throws {
        let shown = folder.appendingPathComponent("shown")
        try "first".write(to: shown, atomically: true, encoding: .utf8)
        try TestSpot(header: "on=sheet.open\noffers=window", body: "printf 'row=a\\ntitle=%s\\n' \"$(cat '\(shown.path)')\"").write(to: spots.spotFile("board"))
        await model.reload()
        model.openWindow("board")
        try await wait("the first words") { self.model.sheets["board"]?.list.all.first?.title == "first" }

        try "second".write(to: shown, atomically: true, encoding: .utf8)
        model.openWindow("board")

        try await wait("the second words") { self.model.sheets["board"]?.list.all.first?.title == "second" }
    }

    func testAViewInASampleClosesNothing() async throws {
        try await openList()
        try await floatOther()

        model.close(.sample)

        XCTAssertEqual(model.openSheetID, "list")
        XCTAssertEqual(host.landings, [])
        XCTAssertEqual(model.runs.floating, ["other"])
    }
}
