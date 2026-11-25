import XCTest
@testable import OpenspotCore

final class SpotInstallTests: XCTestCase {
    private var root: URL!
    private var places: AppPlaces!

    override func setUpWithError() throws {
        root = try temporaryFolder()
        let trash = root.appendingPathComponent("trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        places = AppPlaces(
            environment: ["OPENSPOT_CONFIG": root.appendingPathComponent("config").path, "OPENSPOT_SPOTS": spots.path, "OPENSPOT_CORE": core.path],
            home: root,
            defaults: UserDefaults(suiteName: "openspot-install-\(UUID().uuidString)") ?? .standard,
            trash: { url in try FileManager.default.moveItem(at: url, to: trash.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)) },
            defaultConfig: nil
        )
        try "#!/bin/sh\n".writeScript(to: source.appendingPathComponent("clock.spot/clock.sh"), toml: "title = 'Clock'")
        try "#!/bin/sh\npbcopy\n".writeScript(to: source.appendingPathComponent("paste.spot/paste.sh"), toml: "title = 'Paste'\nuses = ['clipboard']")
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"), toml: "title = 'Timer'")
    }

    private var spots: URL { root.appendingPathComponent("spots", isDirectory: true) }
    private var core: URL { root.appendingPathComponent("core", isDirectory: true) }
    private var source: URL { root.appendingPathComponent("friends", isDirectory: true) }

    private var catalog: SpotCatalog {
        SpotCatalog(published: places.store, folder: places.spots, arrangement: places.config.read().arrangement, stores: [Store(url: source)])
    }

    private func install(_ id: String, isConfirmed: Bool = false) async throws -> String {
        let install = try XCTUnwrap(try catalog.install(id, in: places))
        return try await install.run(isConfirmed: isConfirmed)
    }

    func testInstallCopiesTheFolderOfItsSourceAndLeavesTheSourceAsItIs() async throws {
        let said = try await install("clock")

        XCTAssertEqual(said, "Installed Clock.\n")
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("clock.spot/clock.sh").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.appendingPathComponent("clock.spot/clock.sh").path))
        XCTAssertEqual(try places.lock.entries().map(\.paths), [["clock.spot"]])
    }

    func testInstallMakesTheSpotSearchableAndLeavesItOffTheGrid() async throws {
        _ = try await install("clock")

        let arrangement = places.config.read().arrangement
        XCTAssertEqual(arrangement.isOnGrid(of: "clock"), false)
        XCTAssertNotEqual(arrangement.isFound(of: "clock"), false)
    }

    func testAnInstallKeepsWhereThePersonPutTheSpotBefore() async throws {
        _ = try places.config.change { $0.arrangement.set(isOnGrid: true, of: "clock") }

        _ = try await install("clock")

        XCTAssertEqual(places.config.read().arrangement.isOnGrid(of: "clock"), true)
    }

    func testASpotThatAsksForTrustIsCopiedOnlyAfterAYes() async throws {
        do {
            _ = try await install("paste")
            XCTFail("an install with a use passed with no yes")
        } catch {
            let said = (error as? SpotError)?.reason ?? ""
            XCTAssertTrue(said.hasPrefix("Paste\n\nUses\nclipboard\n\n"), said)
            XCTAssertTrue(said.contains("Can also\nCopy with pbcopy in place of openspot clipboard\n\n"), said)
            XCTAssertTrue(said.contains("Files\npaste.spot/paste.sh\npaste.spot/spot.toml\n\n"), said)
            XCTAssertTrue(said.hasSuffix("Openspot installed nothing. Run `openspot store get paste --yes` to install it."), said)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: spots.appendingPathComponent("paste.spot").path))

        _ = try await install("paste", isConfirmed: true)

        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("paste.spot/paste.sh").path))
    }

    func testACoreSpotNeedsNoInstall() throws {
        XCTAssertNil(try catalog.install("timer", in: places))
    }

    func testTheReviewOfAnInstallShowsItsFilesBeforeItsInstallButtonCopiesThem() async throws {
        let review = try XCTUnwrap(try catalog.install("clock", in: places)).review()
        let sheet = Frame(text: try review.answer(["show"]))

        let button = try XCTUnwrap(sheet.parts.first { $0.id == "install" })
        XCTAssertEqual(button.title, "Install")
        XCTAssertFalse(FileManager.default.fileExists(atPath: spots.appendingPathComponent("clock.spot").path))
        let text = try XCTUnwrap(sheet.parts.first { $0.id == "review" }).control
        guard case .text(let shown, _, _) = text else { return XCTFail("the review shows no text") }
        XCTAssertTrue(shown.contains("clock.spot/clock.sh\n#!/bin/sh\n"), shown)

        let answer = try await review.add()

        XCTAssertEqual(answer.effects, [.toast("Installed Clock.")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("clock.spot/clock.sh").path))
        XCTAssertEqual(places.config.read().arrangement.isOnGrid(of: "clock"), false)
    }
}
