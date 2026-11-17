import XCTest
@testable import OpenspotCore

@MainActor
final class SpotTrustTests: PanelCase {
    private func addCups(source: String, key: String? = nil) throws {
        try script("cups", header: "title=Cups\nview=cups.swift", "printf 'title=Cups\\n'")
        try "".write(to: spots.appendingPathComponent("cups.spot/cups.swift"), atomically: true, encoding: .utf8)
        let lock = SpotLock.standard(environment: model.files.environment, home: model.files.home)
        try FileManager.default.createDirectory(at: lock.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode([SpotLock.Entry(source: source, commit: nil, paths: ["cups.spot"], hash: nil, uses: [], key: key)]).write(to: lock.url)
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
}
