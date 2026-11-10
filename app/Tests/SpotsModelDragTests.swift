import XCTest
@testable import OpenspotCore

/// Proves the drag of a card in Edit Spots through the panel's model: where the cards go, what a release saves, and what
/// puts the cards back.
@MainActor
final class SpotsModelDragTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: TestHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-drag-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
        suite = "openspot-drag-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let host = TestHost()
        self.host = host
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2, prepare: { await host.prepare($0, glyphs: $1) }))
        host.model = model
        for (name, size) in [("a", "wide"), ("b", "wide"), ("c", "wide"), ("d", "small")] {
            let file = plugins.appendingPathComponent("\(name).sh")
            try "#!/bin/sh\n# size=\(size)\n".writeScript(to: file)
            try FileManager.default.setAttributes([.creationDate: Date(timeIntervalSince1970: 1_700_000_000)], ofItemAtPath: file.path)
        }
        model.reload()
        model.dragRest = .zero
        model.beginEditing()
    }

    override func tearDown() async throws {
        model.quit()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    private var plugins: URL {
        folder.appendingPathComponent("plugins", isDirectory: true)
    }

    private var core: URL {
        folder.appendingPathComponent("core", isDirectory: true)
    }

    private var trash: URL {
        folder.appendingPathComponent("trash", isDirectory: true)
    }

    private var files: SpotFiles {
        let trash = trash
        return SpotFiles(
            environment: ["OPENSPOT_PLUGINS": plugins.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path, "OPENSPOT_CORE": core.path],
            home: folder,
            defaults: defaults,
            trash: { url in
                try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
                let place = trash.appendingPathComponent(url.lastPathComponent)
                try FileManager.default.moveItem(at: url, to: place)
                return place
            }
        )
    }

    private var order: [String] {
        model.visible.map(\.id)
    }

    /// The pointer's move that takes the centre of a card to this point of the grid.
    private func move(_ id: String, to point: CGPoint) -> CGSize {
        let index = model.visible.firstIndex { $0.id == id } ?? 0
        let rect = model.placements[index].rect
        return CGSize(width: point.x - rect.midX, height: point.y - rect.midY)
    }

    /// The left half of a card, where a card dropped goes before it.
    private func leftHalf(of id: String) -> CGPoint {
        let rect = model.placements[model.visible.firstIndex { $0.id == id } ?? 0].rect
        return CGPoint(x: rect.minX + rect.width / 4, y: rect.midY)
    }

    private func savedOrder() -> [String] {
        let host = TestHost()
        let other = SpotsModel(host: host, files: files)
        other.reload()
        defer { other.quit() }
        return withExtendedLifetime(host) { other.visible.map(\.id) }
    }

    func testACardDraggedLeftOfAnotherMakesRoomThereAndAReleaseSavesIt() {
        XCTAssertEqual(order, ["a", "b", "c", "d"])
        let translation = move("d", to: leftHalf(of: "c"))

        model.dragSpot("d", by: translation)

        XCTAssertEqual(order, ["a", "b", "d", "c"])
        XCTAssertEqual(model.placements.map(\.size), [.wide, .wide, .wide, .wide])
        XCTAssertEqual(model.selected, 2)
        XCTAssertEqual(savedOrder(), ["a", "b", "c", "d"])

        model.dropSpot(by: translation)

        XCTAssertNil(model.drag)
        XCTAssertEqual(order, ["a", "b", "d", "c"])
        XCTAssertEqual(savedOrder(), ["a", "b", "d", "c"])
    }

    func testADroppedCardLandsUntilItsMotionEnds() {
        host.heldEnds = []
        let translation = move("d", to: leftHalf(of: "c"))
        model.dragSpot("d", by: translation)

        model.dropSpot(by: translation)

        XCTAssertNil(model.drag)
        XCTAssertEqual(model.landing, "d")
        XCTAssertEqual(model.lift.offset, translation)
        host.heldEnds?.forEach { $0() }
        XCTAssertNil(model.landing)
        XCTAssertEqual(model.lift.offset, .zero)
    }

    func testACardPutBackByEscapeLandsUntilItsMotionEnds() {
        host.heldEnds = []
        model.dragSpot("d", by: move("d", to: leftHalf(of: "c")))

        model.handleEditKey(ActionKey(name: "escape"))

        XCTAssertEqual(model.landing, "d")
        host.heldEnds?.forEach { $0() }
        XCTAssertNil(model.landing)
    }

    func testALiftedCardMovesWithTheGridWhenItScrollsAndLandsWhereThePointerIs() {
        let row = SpotTokens.rowHeight + SpotTokens.rowGap
        let translation = move("a", to: leftHalf(of: "a"))
        model.dragSpot("a", by: translation)

        model.gridScrolled(to: row)

        XCTAssertEqual(model.lift.offset, CGSize(width: translation.width, height: translation.height + row))
        XCTAssertEqual(order, ["b", "c", "a", "d"])
        model.dropSpot(by: translation)
        XCTAssertEqual(savedOrder(), ["b", "c", "a", "d"])
    }

    func testAResizedCardFollowsTheGridWhenItScrolls() {
        model.resizeSpot("c", by: .zero)

        model.gridScrolled(to: SpotTokens.rowHeight + SpotTokens.rowGap)

        XCTAssertEqual(model.placements[2].size, .square)
    }

    func testTheCardsWaitForThePointerToRestButAReleaseLandsAtOnce() {
        model.dragRest = .seconds(30)
        let translation = move("d", to: leftHalf(of: "c"))

        model.dragSpot("d", by: translation)

        XCTAssertEqual(order, ["a", "b", "c", "d"])
        model.dropSpot(by: translation)
        XCTAssertEqual(order, ["a", "b", "d", "c"])
    }

    func testTheCardsMakeRoomAfterARealRest() async throws {
        model.dragRest = .milliseconds(100)

        model.dragSpot("d", by: move("d", to: leftHalf(of: "c")))

        for _ in 0..<500 where order != ["a", "b", "d", "c"] {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(order, ["a", "b", "d", "c"])
    }

    func testTheLiftFollowsThePointerAndComesBackAtTheEnd() {
        model.dragSpot("a", by: CGSize(width: 5, height: 7))

        XCTAssertEqual(model.drag?.id, "a")
        XCTAssertEqual(model.lift.offset, CGSize(width: 5, height: 7))

        model.dropSpot(by: CGSize(width: 5, height: 7))

        XCTAssertNil(model.drag)
        XCTAssertEqual(model.lift.offset, .zero)
    }

    func testADraggedCardStaysAPaddingInsideTheWindow() {
        let rect = model.placements[0].rect
        let inset = SpotTokens.padding

        model.dragSpot("a", by: CGSize(width: -1000, height: -1000))
        XCTAssertEqual(model.lift.offset, CGSize(width: inset - SpotTokens.halo - rect.minX, height: inset - SpotTokens.gridTop - rect.minY))

        model.dragSpot("a", by: CGSize(width: 1000, height: 1000))
        XCTAssertEqual(model.lift.offset, CGSize(
            width: SpotTokens.panelWidth - inset - SpotTokens.halo - rect.maxX,
            height: SpotTokens.panelHeight - inset - SpotTokens.gridTop - rect.maxY
        ))
    }

    func testTheHintNamesWhatTheHKeyDoesToTheSelectedSpot() {
        XCTAssertEqual(model.hint, "S Size   H Hide   ⇧ Arrows Move   Esc Done")

        model.handleEditKey(ActionKey(name: "h"))
        XCTAssertEqual(model.hint, "S Size   H Show   ⇧ Arrows Move   Esc Done")

        model.handleEditKey(ActionKey(name: "h"))
        XCTAssertEqual(model.hint, "S Size   H Hide   ⇧ Arrows Move   Esc Done")
    }

    func testEscapePutsTheCardsBackAndKeepsEditSpots() {
        let translation = move("d", to: leftHalf(of: "c"))
        model.dragSpot("d", by: translation)

        model.handleEditKey(ActionKey(name: "escape"))
        model.dropSpot(by: translation)

        XCTAssertTrue(model.isEditing)
        XCTAssertNil(model.drag)
        XCTAssertEqual(order, ["a", "b", "c", "d"])
        XCTAssertEqual(model.selected, 3)
        XCTAssertEqual(savedOrder(), ["a", "b", "c", "d"])
    }

    func testAReleaseOffTheGridPutsTheCardsBack() {
        model.dragSpot("d", by: move("d", to: leftHalf(of: "c")))

        model.dropSpot(by: move("d", to: CGPoint(x: -SpotTokens.gridWidth, y: 0)))

        XCTAssertNil(model.drag)
        XCTAssertEqual(order, ["a", "b", "c", "d"])
        XCTAssertEqual(savedOrder(), ["a", "b", "c", "d"])
    }

    func testAHiddenCardMovesOnlyAmongTheHiddenCards() {
        model.setOnGrid(false, for: "b")
        model.setOnGrid(false, for: "a")
        XCTAssertEqual(order, ["c", "d", "a", "b"])

        let translation = move("b", to: CGPoint(x: 1, y: 1))
        model.dragSpot("b", by: translation)
        model.dropSpot(by: translation)

        XCTAssertEqual(order, ["c", "d", "b", "a"])
    }

    func testAPanelThatHidesEndsTheDrag() {
        model.dragSpot("d", by: move("d", to: leftHalf(of: "c")))

        model.panelWillHide()

        XCTAssertNil(model.drag)
        XCTAssertEqual(model.lift.offset, .zero)
    }

    private var down: CGSize {
        CGSize(width: 0, height: SpotTokens.rowHeight + SpotTokens.rowGap)
    }

    private var savedSize: SpotSize? {
        files.config.read().arrangement.size(of: "c")
    }

    func testACornerPulledDownARowMakesTheCardSquareAndAReleaseSavesIt() {
        model.resizeSpot("c", by: down)

        XCTAssertEqual(model.placements[2].size, .square)
        XCTAssertEqual(model.placements[3].size, .square)
        XCTAssertNil(savedSize)

        model.dropResize()

        XCTAssertNil(model.resize)
        XCTAssertEqual(model.placements[2].size, .square)
        XCTAssertEqual(savedSize, .square)
        XCTAssertEqual(model.selected, 2)
    }

    func testTheResizePointerLiesInTheHandleOfTheCornerItPulls() {
        let corner = CGPoint(x: SpotTokens.resizeHandle, y: SpotTokens.resizeHandle)
        model.resizeSpot("c", by: .zero)
        XCTAssertEqual(model.resizePointer, corner)

        model.resizeSpot("c", by: CGSize(width: -10, height: 0))
        XCTAssertEqual(model.resizePointer, CGPoint(x: corner.x - 10, y: corner.y))

        model.resizeSpot("c", by: down)
        XCTAssertEqual(model.placements[2].size, .square)
        XCTAssertEqual(model.resizePointer, corner)
    }

    func testTheResizePointerKeepsWhereThePersonPressedTheHandle() {
        let grip = CGPoint(x: 10, y: 20)
        model.resizeSpot("c", by: .zero, grip: grip)
        XCTAssertEqual(model.resizePointer, grip)

        model.resizeSpot("c", by: CGSize(width: 5, height: 0), grip: CGPoint(x: 1, y: 1))
        XCTAssertEqual(model.resizePointer, CGPoint(x: 15, y: 20))
    }

    func testEscapePutsTheSizeBackAndSavesNothing() {
        model.resizeSpot("c", by: down)

        model.handleEditKey(ActionKey(name: "escape"))
        model.dropResize()

        XCTAssertTrue(model.isEditing)
        XCTAssertNil(model.resize)
        XCTAssertEqual(model.placements[2].size, .wide)
        XCTAssertNil(savedSize)
    }

    func testAReleaseAtTheSameSizeSavesNothing() {
        model.resizeSpot("c", by: CGSize(width: 5, height: 5))

        model.dropResize()

        XCTAssertNil(model.resize)
        XCTAssertNil(savedSize)
    }

    func testTheGridGrowsDownPastTheRowsThePanelShows() throws {
        model.endEditing()
        for name in ["e", "f", "g", "h", "i", "j", "k", "l", "m"] {
            try "#!/bin/sh\n# size=wide\n".writeScript(to: plugins.appendingPathComponent("\(name).sh"))
        }
        model.reload()
        model.beginEditing()

        XCTAssertEqual(model.visible.filter(\.isOnGrid).count, 13)
        model.resizeSpot("c", by: .zero)
        XCTAssertEqual(model.resize?.choices.contains(.large), true)
    }

    func testAPanelThatHidesEndsTheResize() {
        model.resizeSpot("c", by: down)

        model.panelWillHide()

        XCTAssertNil(model.resize)
    }

    func testTheDockHoldsTheCoreSpotsThatAreOffAndNoCardOfThePanel() throws {
        try "#!/bin/sh\n# size=small\n".writeScript(to: core.appendingPathComponent("timer.sh"))
        try "#!/bin/sh\n# size=small\n".writeScript(to: core.appendingPathComponent("coin.sh"))
        model.setOnGrid(false, for: "d")

        model.endEditing()
        model.beginEditing()
        XCTAssertEqual(model.dock.shown.map(\.id), ["coin", "timer"])

        model.searchDock("ti")
        XCTAssertEqual(model.dock.shown.map(\.id), ["timer"])
    }

    func testTheMinusTurnsASpotOfThePluginsFolderOffIntoTheDockAndItStaysOff() {
        model.turnOff("a")

        XCTAssertEqual(order, ["b", "c", "d"])
        XCTAssertEqual(model.dock.items.map(\.id), ["a"])
        XCTAssertEqual(model.dock.items.map(\.isOwn), [true])
        XCTAssertEqual(savedOrder(), ["b", "c", "d"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: plugins.appendingPathComponent("a.sh").path))
    }

    func testASpotTurnedOnFromTheDockComesBackToThePanel() {
        model.turnOff("a")

        model.turnOn("a")

        XCTAssertTrue(order.contains("a"))
        XCTAssertEqual(model.dock.items.map(\.id), [])
    }

    func testACoreSpotTurnsOnFromTheDockAndOffIntoIt() throws {
        try "#!/bin/sh\n# size=small\n".writeScript(to: core.appendingPathComponent("timer.sh"))
        model.reload()
        XCTAssertEqual(model.dock.items.map(\.id), ["timer"])

        model.turnOn("timer")
        XCTAssertTrue(order.contains("timer"))
        XCTAssertEqual(model.dock.items.map(\.id), [])

        model.turnOff("timer")
        XCTAssertFalse(order.contains("timer"))
        XCTAssertEqual(model.dock.items.map(\.isOwn), [false])
    }

    func testTheDockDeletesOnlyASpotOfThePluginsFolderAndUndoPutsItBack() throws {
        try "#!/bin/sh\n# size=small\n".writeScript(to: core.appendingPathComponent("timer.sh"))
        model.turnOff("a")

        model.delete("timer")
        model.delete("a")

        XCTAssertEqual(model.dock.items.map(\.id), ["timer"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: trash.appendingPathComponent("a.sh").path))
        XCTAssertTrue(model.undoRemoval())
        XCTAssertEqual(model.dock.items.map(\.id), ["a", "timer"])
        XCTAssertFalse(order.contains("a"))
    }

    func testTypingInTheDockSearchTakesNoEditKeyAndEscapeEndsTheSearch() {
        model.searchDock("c")
        model.searchesDock(true)

        XCTAssertFalse(model.handleKey(ActionKey(name: "s")))
        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))
        XCTAssertFalse(model.isSearchingDock)
        XCTAssertEqual(model.dock.query, "")
        XCTAssertTrue(model.isEditing)
    }

    func testNoCardLiftsOutsideEditSpots() {
        model.endEditing()

        model.dragSpot("d", by: move("d", to: leftHalf(of: "c")))
        model.resizeSpot("c", by: down)

        XCTAssertNil(model.drag)
        XCTAssertNil(model.resize)
        XCTAssertEqual(order, ["a", "b", "c", "d"])
        XCTAssertEqual(model.placements[2].size, .wide)
    }
}
