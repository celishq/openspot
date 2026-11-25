import XCTest
@testable import OpenspotCore

final class SpotCatalogTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-store-list-\(UUID().uuidString)")
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"), toml: "detail = 'Counts down'")
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("apps.spot/apps.sh"), toml: "title = 'Apps'")
        try "#!/bin/sh\n".writeScript(to: spots.appendingPathComponent("mine.spot/mine.sh"), toml: "title = 'Mine'")
        try "#!/bin/sh\n".writeScript(to: store.appendingPathComponent("shared.spot/shared.sh"), toml: "title = 'Shared'\ndetail = 'From a friend'")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private var core: URL { folder.appendingPathComponent("core", isDirectory: true) }
    private var spots: URL { folder.appendingPathComponent("spots", isDirectory: true) }
    private var store: URL { folder.appendingPathComponent("store", isDirectory: true) }

    private var config: ConfigFile {
        ConfigFile(url: folder.appendingPathComponent("config.toml"))
    }

    private func list(stores: [Store]? = nil) -> SpotCatalog {
        SpotCatalog(published: store, folder: SpotsFolder(url: spots, core: core), arrangement: config.read().arrangement, stores: stores ?? [Store(url: store)])
    }

    func testEachStoreFolderListsItsSpotsWithTheFolderTheyCameFrom() throws {
        let friends = folder.appendingPathComponent("friends", isDirectory: true)
        try "#!/bin/sh\n".writeScript(to: friends.appendingPathComponent("clock.spot/clock.sh"), toml: "title = 'Clock'")
        let shelf = list(stores: [Store(url: friends), Store(url: folder.appendingPathComponent("gone")), Store(url: store)])

        XCTAssertEqual(shelf.items.map(\.id), ["apps", "clock", "mine", "shared", "timer"])
        XCTAssertEqual(shelf.items.first { $0.id == "clock" }?.origin, .store)
        XCTAssertEqual(shelf.items.first { $0.id == "clock" }?.store?.url.path, friends.path)
        XCTAssertEqual(shelf.items.first { $0.id == "shared" }?.store?.url.path, store.path)
        XCTAssertNil(shelf.items.first { $0.id == "mine" }?.store)
        XCTAssertTrue(try shelf.text(.frame).contains("store=\(friends.path)\n"))
    }

    func testTheBuiltInStoreIsNamedOpenspotAndComesFromTheExamplesOfTheApp() throws {
        let examples = folder.appendingPathComponent("examples", isDirectory: true)
        let builtIn = try XCTUnwrap(Store.builtIn(environment: ["OPENSPOT_EXAMPLES": examples.path]))
        try "#!/bin/sh\n".writeScript(to: examples.appendingPathComponent("year.spot/year.sh"), toml: "title = 'Year'")

        XCTAssertEqual(builtIn.name, "Openspot")
        XCTAssertTrue(builtIn.isBuiltIn)
        XCTAssertEqual(builtIn.url.path, examples.path)
        XCTAssertEqual(list(stores: [builtIn]).items.first { $0.id == "year" }?.store?.url.path, examples.path)
    }

    func testTheFolderThatPublishWritesIsNoStore() {
        XCTAssertFalse(list(stores: []).items.contains { $0.id == "shared" })
    }

    func testTheConfigKeepsEachStoreFolderOnce() throws {
        let friends = Store(url: folder.appendingPathComponent("friends"))

        _ = try config.change { $0.add(store: friends); $0.add(store: Store(url: folder.appendingPathComponent("friends/"))) }
        XCTAssertEqual(config.read().stores, [friends])
        XCTAssertEqual(friends.name, "friends")

        _ = try config.change { $0.remove(store: friends) }
        XCTAssertEqual(config.read().stores, [])
        XCTAssertEqual(config.read().faults, [])
    }

    func testItListsTheCoreSpotsYourOwnAndThePackagesOfTheStoreWithWhetherYouHaveThem() {
        let items = list().items

        XCTAssertEqual(items.map(\.id), ["apps", "mine", "shared", "timer"])
        XCTAssertEqual(items.map(\.origin), [.core, .mine, .store, .core])
        XCTAssertEqual(items.map(\.isAdded), [true, true, false, true])
        XCTAssertEqual(items.first { $0.id == "timer" }?.spot.subtitle, "Counts down")
        XCTAssertEqual(items.first { $0.id == "shared" }?.package?.path, store.appendingPathComponent("shared.spot").path)
        XCTAssertNil(items.first { $0.id == "timer" }?.package)
    }

    func testYourOwnSpotSaysWhetherTheStoreHoldsItAsItIs() throws {
        XCTAssertNil(list().items.first { $0.id == "mine" }?.publication)

        try FileManager.default.copyItem(at: spots.appendingPathComponent("mine.spot"), to: store.appendingPathComponent("mine.spot"))
        XCTAssertEqual(list().items.first { $0.id == "mine" }?.publication, .current)
        XCTAssertFalse(list().items.contains { $0.origin == .store && $0.id == "mine" })

        try "#!/bin/sh\necho changed\n".writeScript(to: spots.appendingPathComponent("mine.spot/mine.sh"), toml: "title = 'Mine'")
        XCTAssertEqual(list().items.first { $0.id == "mine" }?.publication, .changed)
    }

    func testTheFramePrintsASpotBlockForEach() throws {
        let frame = try list().text(.frame)

        XCTAssertTrue(frame.contains("item=timer\ntitle=Timer\n"), frame)
        XCTAssertTrue(frame.contains("origin=core\nadded=true\n"), frame)
        XCTAssertTrue(frame.contains("item=shared\n"), frame)
        XCTAssertTrue(frame.contains("step=get\n"), frame)
    }

    func testACoreSpotAndYourOwnSpotWithAScheduleAreAddedAndAGetChangesNothing() async throws {
        try "#!/bin/sh\n".writeScript(to: spots.appendingPathComponent("daily.spot/daily.sh"), toml: "title = 'Daily'\n[on]\nschedule = ['0 9 * * *']")
        XCTAssertEqual(list().items.first { $0.id == "daily" }?.step, "publish")

        let item = try await list().get("timer", lock: AppPlaces.test().lock)

        XCTAssertEqual(item.spot.name, "Timer")
        XCTAssertEqual(config.read().arrangement.choices, [])
    }

    func testGetOfAnIDThatTheStoreLacksSaysHowToSeeEachOne() async {
        do {
            _ = try await list().get("gone", lock: AppPlaces.test().lock)
            XCTFail("a get of a missing spot passed")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, "`gone` is not a spot of the store. Run `openspot store list` to see each one.")
        }
    }
}
