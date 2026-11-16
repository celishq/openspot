import XCTest
@testable import OpenspotCore

final class SpotStoreTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-store-list-\(UUID().uuidString)")
        try "#!/bin/sh\n# detail=Counts down\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        try "#!/bin/sh\n# title=Apps\n".writeScript(to: core.appendingPathComponent("apps.spot/apps.sh"))
        try "#!/bin/sh\n# title=Mine\n".writeScript(to: spots.appendingPathComponent("mine.spot/mine.sh"))
        try "#!/bin/sh\n# title=Shared\n# detail=From a friend\n".writeScript(to: store.appendingPathComponent("shared.spot/shared.sh"))
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

    private func list(enabled: Set<String> = ["apps"], stores: [StoreFolder] = []) -> SpotStore {
        var arrangement = config.read().arrangement
        enabled.forEach { arrangement.set(isEnabled: true, of: $0) }
        return SpotStore(url: store, folder: SpotsFolder(url: spots, core: core, enabled: [], disabled: []), arrangement: arrangement, stores: stores)
    }

    func testEachStoreFolderListsItsSpotsWithTheFolderTheyCameFrom() throws {
        let friends = folder.appendingPathComponent("friends", isDirectory: true)
        try "#!/bin/sh\n# title=Clock\n".writeScript(to: friends.appendingPathComponent("clock.spot/clock.sh"))
        let shelf = list(stores: [StoreFolder(url: friends), StoreFolder(url: folder.appendingPathComponent("gone"))])

        XCTAssertEqual(shelf.items.map(\.id), ["apps", "clock", "mine", "shared", "timer"])
        XCTAssertEqual(shelf.items.first { $0.id == "clock" }?.origin, .store)
        XCTAssertEqual(shelf.items.first { $0.id == "clock" }?.store?.path, friends.path)
        XCTAssertEqual(shelf.items.first { $0.id == "shared" }?.store?.path, store.path)
        XCTAssertNil(shelf.items.first { $0.id == "mine" }?.store)
        XCTAssertTrue(try shelf.text(.frame).contains("store=\(friends.path)\n"))
    }

    func testTheBuiltInStoreIsNamedOpenspotAndComesFromTheExamplesOfTheApp() throws {
        let examples = folder.appendingPathComponent("examples", isDirectory: true)
        let builtIn = try XCTUnwrap(StoreFolder.builtIn(environment: ["OPENSPOT_EXAMPLES": examples.path]))
        try "#!/bin/sh\n# title=Year\n".writeScript(to: examples.appendingPathComponent("year.spot/year.sh"))

        XCTAssertEqual(builtIn.name, "Openspot")
        XCTAssertTrue(builtIn.isBuiltIn)
        XCTAssertEqual(builtIn.url.path, examples.path)
        XCTAssertEqual(list(stores: [builtIn]).items.first { $0.id == "year" }?.store?.path, examples.path)
    }

    func testTheConfigKeepsEachStoreFolderOnce() throws {
        let friends = StoreFolder(url: folder.appendingPathComponent("friends"))

        _ = try config.change { $0.add(store: friends); $0.add(store: StoreFolder(url: folder.appendingPathComponent("friends/"))) }
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
        XCTAssertEqual(items.map(\.isAdded), [true, true, false, false])
        XCTAssertEqual(items.first { $0.id == "timer" }?.spot.subtitle, "Counts down")
        XCTAssertEqual(items.first { $0.id == "shared" }?.package?.path, store.appendingPathComponent("shared.spot").path)
        XCTAssertNil(items.first { $0.id == "timer" }?.package)
    }

    func testYourOwnSpotSaysWhetherTheStoreHoldsItAsItIs() throws {
        XCTAssertNil(list().items.first { $0.id == "mine" }?.publication)

        try FileManager.default.copyItem(at: spots.appendingPathComponent("mine.spot"), to: store.appendingPathComponent("mine.spot"))
        XCTAssertEqual(list().items.first { $0.id == "mine" }?.publication, .current)
        XCTAssertFalse(list().items.contains { $0.origin == .store && $0.id == "mine" })

        try "#!/bin/sh\n# title=Mine\necho changed\n".writeScript(to: spots.appendingPathComponent("mine.spot/mine.sh"))
        XCTAssertEqual(list().items.first { $0.id == "mine" }?.publication, .changed)
    }

    func testTheFramePrintsASpotBlockForEach() throws {
        let frame = try list().text(.frame)

        XCTAssertTrue(frame.contains("spot=timer\nname=Timer\n"), frame)
        XCTAssertTrue(frame.contains("origin=core\nadded=false\n"), frame)
        XCTAssertTrue(frame.contains("spot=shared\n"), frame)
        XCTAssertTrue(frame.contains("step=get\n"), frame)
    }

    func testGetTurnsOnACoreSpotByTheIDThatTheListPrints() async throws {
        let id = try XCTUnwrap(list().items.first { $0.origin == .core && !$0.isAdded }?.id)

        let item = try await list().get(id, config: config, environment: [:])

        XCTAssertEqual(item.spot.name, "Timer")
        XCTAssertTrue(config.read().arrangement.enabled.contains(id))
    }

    func testGetOfAnIDThatTheStoreLacksSaysHowToSeeEachOne() async {
        do {
            _ = try await list().get("gone", config: config, environment: [:])
            XCTFail("a get of a missing spot passed")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, "`gone` is not a spot of the store. Run `openspot store list` to see each one.")
        }
    }
}
