import XCTest
@testable import OpenspotCore

@MainActor
final class SpotTrustTests: PanelCase {
    private func addCups(source: String, key: String? = nil, isShipped: Bool? = nil) throws {
        try script("cups", header: "title=Cups\nview=cups.swift", "printf 'title=Cups\\n'")
        try "".write(to: spots.appendingPathComponent("cups.spot/cups.swift"), atomically: true, encoding: .utf8)
        let lock = SpotLock.standard(environment: model.files.environment, home: model.files.home)
        try FileManager.default.createDirectory(at: lock.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode([SpotLock.Entry(source: source, commit: nil, paths: ["cups.spot"], hash: nil, uses: [], key: key, isShipped: isShipped)]).write(to: lock.url)
    }

    private var cups: Spot? {
        model.card(id: "cups")?.spot
    }

    func testASpotAddedFromAnOutsideSourceIsRestrictedAndHasNoView() async throws {
        try addCups(source: "https://example.com/cups.git", key: AccountKey.make().publicKey)

        await model.reload()

        XCTAssertEqual(cups?.isRestricted, true)
        XCTAssertNil(cups?.view)
    }

    func testASpotThatNoAddBroughtKeepsItsView() async throws {
        try script("cups", header: "title=Cups\nview=cups.swift", "printf 'title=Cups\\n'")
        try "".write(to: spots.appendingPathComponent("cups.spot/cups.swift"), atomically: true, encoding: .utf8)

        await model.reload()

        XCTAssertEqual(cups?.isRestricted, false)
        XCTAssertNotNil(cups?.view)
    }

    func testASpotSignedByTheOwnAccountKeyIsNotRestricted() async throws {
        let mine = try AccountKey.make()
        try model.files.account.keep(mine)
        try addCups(source: "https://example.com/cups.git", key: mine.publicKey)

        await model.reload()

        XCTAssertEqual(cups?.isRestricted, false)
        XCTAssertNotNil(cups?.view)
    }

    func testASpotFromTheBuiltInStoreOfAnAppThatMovedIsNotRestricted() async throws {
        try addCups(source: "/Volumes/Old/Openspot.app/Contents/Resources/examples/cups.spot", isShipped: true)

        await model.reload()

        XCTAssertEqual(cups?.isRestricted, false)
    }

    func testASpotFromTheBuiltInStoreIsNotRestricted() async throws {
        let store = try XCTUnwrap(Store.builtIn(environment: model.files.environment))
        try addCups(source: store.url.appendingPathComponent("cups.spot").path)

        await model.reload()

        XCTAssertEqual(cups?.isRestricted, false)
    }

    func testASpotOfAnAddedStoreShowsNoView() throws {
        let root = folder!
        let store = root.appendingPathComponent("store", isDirectory: true)
        try TestSpot(header: "title=Cups\nview=cups.swift", body: "printf 'title=Cups\\n'").write(to: store.spotFile("cups"))
        try "".write(to: store.appendingPathComponent("cups.spot/cups.swift"), atomically: true, encoding: .utf8)
        let catalog = SpotCatalog(published: root.appendingPathComponent("published"), folder: SpotsFolder(url: root.appendingPathComponent("spots")), arrangement: SpotArrangement(), stores: [Store(url: store)])

        let item = try XCTUnwrap(catalog.item("cups"))

        XCTAssertNil(item.spot.view)
        XCTAssertTrue(item.spot.isRestricted)
    }

    private func writeConfig(_ text: String) throws {
        let url = model.files.config.url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func testASpotWhoseAuthorThePersonTrustsIsNotRestricted() async throws {
        let key = try AccountKey.make().publicKey
        try addCups(source: "https://example.com/cups.git", key: key)
        try writeConfig("[[trusted]]\nauthor = \"\(key)\"\n")

        await model.reload()

        XCTAssertEqual(cups?.isRestricted, false)
        XCTAssertNotNil(cups?.view)
    }

    func testAnUnsignedSpotThatThePersonTrustsIsNotRestricted() async throws {
        try addCups(source: "https://example.com/cups.git")
        try writeConfig("[[trusted]]\nsource = \"https://example.com/cups.git\"\n")

        await model.reload()

        XCTAssertEqual(cups?.isRestricted, false)
    }

    func testAnUnsignedSpotOfTheSameNameFromAnotherSourceStaysRestricted() async throws {
        try addCups(source: "/tmp/elsewhere/cups.spot")
        try writeConfig("[[trusted]]\nsource = \"https://example.com/cups.git\"\n")

        await model.reload()

        XCTAssertEqual(cups?.isRestricted, true)
    }

    func testTheSettingsOfARestrictedSpotTrustItsAuthor() async throws {
        let key = try AccountKey.make().publicKey
        try addCups(source: "https://example.com/cups.git", key: key)
        await model.reload()
        let settings = try XCTUnwrap(cups?.settingsSheet)

        XCTAssertTrue(try settings.answer(["read"]).contains("row=trust:cups\ntitle=Trust its author\n"))
        _ = try settings.answer(["open", "trust:cups"])
        await model.reload()

        XCTAssertEqual(model.config.trusted, [.author(key)])
        XCTAssertEqual(cups?.isRestricted, false)
        XCTAssertNil(cups?.settingsSheet.flatMap { try? $0.answer(["read"]) }?.range(of: "row=trust:"))
    }

    func testASpotSignedByTheOwnKeyIsTrustedWhenTheAccountSignsIn() async throws {
        let mine = try AccountKey.make()
        try addCups(source: "https://example.com/cups.git", key: mine.publicKey)
        await model.reload()
        XCTAssertEqual(cups?.isRestricted, true)

        try model.files.account.keep(mine)
        await model.reload()

        XCTAssertEqual(cups?.isRestricted, false)
    }

    func testAnEditOfTheLockReloadsTheSpots() throws {
        try addCups(source: "https://example.com/cups.git")
        let lock = SpotLock.standard(environment: model.files.environment, home: model.files.home).url
        let paths = SpotsWatchPaths(folder: spots, config: model.files.config.url)

        XCTAssertTrue(paths.reports(String(cString: try XCTUnwrap(realpath(lock.path, nil)))))
    }

    func testCarefulModeRestrictsASpotThatThePersonMade() async throws {
        try script("cups", header: "title=Cups\nview=cups.swift", "printf 'title=Cups\\n'")
        try "".write(to: spots.appendingPathComponent("cups.spot/cups.swift"), atomically: true, encoding: .utf8)
        try writeConfig("careful = true\n")

        await model.reload()

        XCTAssertEqual(cups?.isRestricted, true)
        XCTAssertNil(cups?.view)
    }
}
