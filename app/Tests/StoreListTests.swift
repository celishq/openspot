import XCTest
@testable import OpenspotCore

/// Proves `openspot store list`: each spot that comes with the app, each spot of the spots folder and each package of the
/// store, with whether the person has it and whether the store holds their own spot as it is.
final class StoreListTests: XCTestCase {
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

    private func list(enabled: Set<String> = ["apps"]) -> StoreList {
        StoreList(folder: SpotsFolder(url: spots, core: core, enabled: enabled, disabled: []), config: Config(text: ""), store: store)
    }

    func testItListsTheCoreSpotsYourOwnAndThePackagesOfTheStoreWithWhetherYouHaveThem() {
        let items = list().items

        XCTAssertEqual(items.map(\.id), ["apps", "mine", "shared", "timer"])
        XCTAssertEqual(items.map(\.origin), ["core", "mine", "store", "core"])
        XCTAssertEqual(items.map(\.added), [true, true, false, false])
        XCTAssertEqual(items.first { $0.id == "timer" }?.detail, "Counts down")
        XCTAssertEqual(items.first { $0.id == "shared" }?.path, store.appendingPathComponent("shared.spot").path)
        XCTAssertNil(items.first { $0.id == "timer" }?.path)
    }

    func testYourOwnSpotSaysWhetherTheStoreHoldsItAsItIs() throws {
        XCTAssertNil(list().items.first { $0.id == "mine" }?.published)

        try FileManager.default.copyItem(at: spots.appendingPathComponent("mine.spot"), to: store.appendingPathComponent("mine.spot"))
        XCTAssertEqual(list().items.first { $0.id == "mine" }?.published, "current")
        XCTAssertFalse(list().items.contains { $0.origin == "store" && $0.id == "mine" })

        try "#!/bin/sh\n# title=Mine\necho changed\n".writeScript(to: spots.appendingPathComponent("mine.spot/mine.sh"))
        XCTAssertEqual(list().items.first { $0.id == "mine" }?.published, "changed")
    }

    func testTheFramePrintsASpotBlockForEach() {
        let frame = list().frame()

        XCTAssertTrue(frame.contains("spot=timer\nname=Timer\n"), frame)
        XCTAssertTrue(frame.contains("origin=core\nadded=false\n"), frame)
        XCTAssertTrue(frame.contains("spot=shared\n"), frame)
    }
}
