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
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
        try "[[spots]]\nid = \"coin\"\nsize = \"small\"\n\n[[spots]]\nid = \"timer\"\nsize = \"small\"\n\n[[spots]]\nid = \"d\"\nsize = \"small\"\n"
            .write(to: folder.appendingPathComponent("defaults.toml"), atomically: true, encoding: .utf8)
        suite = "openspot-drag-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let host = TestHost()
        self.host = host
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2, prepare: { await host.prepare($0, glyphs: $1) }))
        host.model = model
        for name in ["a", "b", "c", "d"] {
            let file = spots.appendingPathComponent("\(name).spot/\(name).sh")
            try "#!/bin/sh\n".writeScript(to: file)
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

    private var spots: URL {
        folder.appendingPathComponent("spots", isDirectory: true)
    }

    private var core: URL {
        folder.appendingPathComponent("core", isDirectory: true)
    }

    private var trash: URL {
        folder.appendingPathComponent("trash", isDirectory: true)
    }

    private var files: AppPlaces {
        let trash = trash
        return AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path, "OPENSPOT_CORE": core.path],
            home: folder,
            defaults: defaults,
            trash: { url in
                try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
                let place = trash.appendingPathComponent(url.lastPathComponent)
                try FileManager.default.moveItem(at: url, to: place)
                return place
            },
            defaultConfig: folder.appendingPathComponent("defaults.toml")
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

    /// The spots that the store shows as off.
    private var offInStore: [String] {
        model.dock.items.filter { $0.state == .off }.map(\.id)
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

    func testTheHKeyPutsTheSelectedSpotInSearchOnlyInTheStore() {
        XCTAssertEqual(model.hint, "S Size   H Hide   L Letter   ⇧ Arrows Move   Esc Done")

        model.handleEditKey(ActionKey(name: "h"))

        XCTAssertEqual(order, ["b", "c", "d"])
        XCTAssertEqual(model.dock.items.first { $0.id == "a" }?.state, .searchOnly)
        XCTAssertEqual(model.hint, "S Size   H Hide   L Letter   ⇧ Arrows Move   Esc Done")
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

    func testInEditSpotsTheGridShowsOnlyTheCardsOnTheGrid() {
        model.setOnGrid(false, for: "a")

        XCTAssertEqual(order, ["b", "c", "d"])
        XCTAssertEqual(model.placements.map(\.top), [0, 0, 0])
        XCTAssertEqual(model.dock.items.first { $0.id == "a" }?.state, .searchOnly)
    }

    func testASearchOnlySpotDraggedFromTheStoreGoesOnTheGridThere() {
        model.setOnGrid(false, for: "d")
        model.dockFrame = dock
        let translation = dockMove("d", to: leftHalf(of: "b"))

        model.dragDockSpot("d", by: translation)
        model.dropDockSpot(by: translation)

        XCTAssertEqual(order, ["a", "d", "b", "c"])
        XCTAssertEqual(model.dock.items.first { $0.id == "d" }?.state, .onGrid)
    }

    func testTheStateChoiceOfAListingPutsASpotInSearchTurnsItOffAndBringsItBack() {
        model.setState(.searchOnly, of: "a")
        XCTAssertEqual(order, ["b", "c", "d"])
        XCTAssertEqual(model.dock.items.first { $0.id == "a" }?.state, .searchOnly)

        model.setState(.off, of: "a")
        XCTAssertEqual(offInStore, ["a"])

        model.setState(.onGrid, of: "a")
        XCTAssertEqual(offInStore, [])
        XCTAssertTrue(order.contains("a"))
    }

    func testATipGoesWhenItsControlActsOrEditSpotsEnds() {
        model.tip = SpotTip(id: "a", anchor: .trailingCorner, text: "Hide from grid")
        model.setOnGrid(false, for: "a")
        XCTAssertNil(model.tip)

        model.tip = SpotTip(id: "d", anchor: .leadingCorner, text: "Turn off")
        model.dragSpot("d", by: move("d", to: leftHalf(of: "c")))
        XCTAssertNil(model.tip)
        model.cancelDrag()

        model.tip = SpotTip(id: "b", anchor: .leadingCorner, text: "Turn off")
        model.endEditing()
        XCTAssertNil(model.tip)
    }

    func testAScrollEndsTheTip() {
        model.tip = SpotTip(id: "a", anchor: .trailingCorner, text: "Hide from grid")
        model.gridScrolled(to: 40)
        XCTAssertNil(model.tip)

        model.tip = SpotTip(id: "a", anchor: .trailingCorner, text: "Hide from grid")
        model.dockScrolled(to: 40)
        XCTAssertNil(model.tip)
    }

    func testAPanelThatHidesEndsTheDrag() {
        model.dragSpot("d", by: move("d", to: leftHalf(of: "c")))

        model.panelWillHide()

        XCTAssertNil(model.drag)
        XCTAssertNil(model.carry)
        XCTAssertEqual(model.lift.offset, .zero)
    }

    /// The dock under the panel, in the panel's space, as the window sets it in Edit Spots.
    private let dock = CGRect(x: -300, y: SpotTokens.panelHeight, width: SpotTokens.dockWidth, height: SpotTokens.dockHeight(rows: 3))

    /// The pointer's move, since the drag started, that takes the centre of the lifted card to this point of the grid.
    private func dragMove(to point: CGPoint) -> CGSize {
        let rect = model.drag.map { $0.rect(at: $0.home) } ?? .zero
        return CGSize(width: point.x - rect.midX, height: point.y - rect.midY)
    }

    /// A point of the panel's space as a point of the grid, which has not scrolled.
    private func inGrid(_ point: CGPoint) -> CGPoint {
        let origin = SpotTokens.gridOrigin(scrollOffset: 0)
        return CGPoint(x: point.x - origin.x, y: point.y - origin.y)
    }

    func testACardReleasedOnTheStoreTurnsNothingOffAndGoesBack() {
        model.dockFrame = dock
        let translation = move("a", to: inGrid(CGPoint(x: dock.midX, y: dock.midY)))

        model.dragSpot("a", by: translation)
        XCTAssertEqual(model.carry?.isOverDock, true)

        model.dropSpot(by: translation)
        XCTAssertNil(model.drag)
        XCTAssertEqual(order, ["a", "b", "c", "d"])
        XCTAssertEqual(offInStore, [])
        XCTAssertEqual(savedOrder(), ["a", "b", "c", "d"])
    }

    func testOffTheGridTheCardsGoBackToTheirPlacesBeforeTheRelease() {
        model.dragSpot("d", by: move("d", to: leftHalf(of: "c")))
        XCTAssertEqual(order, ["a", "b", "d", "c"])

        let start = model.drag.map { $0.rect(at: $0.home) } ?? .zero
        model.dragSpot("d", by: dragMove(to: CGPoint(x: SpotTokens.gridWidth + SpotTokens.rowHeight, y: start.midY)))

        XCTAssertEqual(order, ["a", "b", "c", "d"])
    }

    func testInEditSpotsADraggedCardReachesTheDockAndStaysAPaddingInsideTheWindow() {
        model.dockFrame = dock
        let rect = model.placements[0].rect

        model.dragSpot("a", by: CGSize(width: 0, height: 5000))

        XCTAssertEqual(model.lift.offset.height, dock.maxY - SpotTokens.padding - SpotTokens.gridTop - rect.maxY)
        XCTAssertEqual(model.lift.origin, CGPoint(x: SpotTokens.halo + rect.minX, y: dock.maxY - SpotTokens.padding - rect.height))
    }

    func testTheCarriedCardGlidesToItsPlaceSettlingFromItsLiftAndGoesWhenItLands() {
        host.heldEnds = []
        let translation = move("d", to: leftHalf(of: "c"))
        model.dragSpot("d", by: translation)
        XCTAssertEqual(model.carry?.entry.id, "d")
        XCTAssertEqual(model.carry?.isLanding, false)

        model.dropSpot(by: translation)

        let place = model.placements[model.visible.firstIndex { $0.id == "d" } ?? 0].rect
        XCTAssertEqual(model.lift.origin, CGPoint(x: SpotTokens.halo + place.minX, y: SpotTokens.gridTop + place.minY))
        XCTAssertEqual(model.carry?.entry.id, "d")
        XCTAssertEqual(model.carry?.isLanding, true)
        host.heldEnds?.forEach { $0() }
        XCTAssertNil(model.carry)
    }

    /// Where the card of a spot of the dock lies in the panel's space, with the dock not scrolled.
    private func tile(_ id: String) -> CGRect {
        let index = model.dock.shown.firstIndex { $0.id == id } ?? 0
        return model.dock.rects[index].offsetBy(dx: dock.minX + SpotDock.rowsOrigin.x, dy: dock.minY + SpotDock.rowsOrigin.y)
    }

    /// The pointer's move that takes the centre of the dock's card of a spot to this point of the grid.
    private func dockMove(_ id: String, to point: CGPoint) -> CGSize {
        let start = tile(id)
        let grid = SpotTokens.gridOrigin(scrollOffset: 0)
        return CGSize(width: point.x + grid.x - start.midX, height: point.y + grid.y - start.midY)
    }

    func testASpotDraggedFromTheDockMakesRoomOnTheGridAndAReleaseTurnsItOnThere() throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("clock.spot/clock.sh"))
        model.reload()
        model.dockFrame = dock
        model.showStoreSection(.store)
        let translation = dockMove("clock", to: leftHalf(of: "b"))

        model.dragDockSpot("clock", by: translation)
        XCTAssertEqual(model.carry?.entry.id, "clock")
        XCTAssertEqual(order, ["a", "clock", "b", "c", "d"])

        model.dropDockSpot(by: translation)
        XCTAssertNil(model.carry)
        XCTAssertEqual(order, ["a", "clock", "b", "c", "d"])
        XCTAssertEqual(offInStore, [])
        XCTAssertEqual(savedOrder(), ["a", "clock", "b", "c", "d"])
    }

    func testASpotDroppedFromTheDockKeepsItsSizeOnTheGrid() throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        model.reload()
        model.dockFrame = dock
        model.showStoreSection(.store)
        model.setOnGrid(false, for: "d")
        let translation = dockMove("timer", to: leftHalf(of: "c"))
        let size = { self.model.placements[self.model.visible.firstIndex { $0.id == "timer" } ?? 0].size }

        model.dragDockSpot("timer", by: translation)
        XCTAssertEqual(model.carry?.size, .small)
        XCTAssertEqual(size(), .small)

        model.dropDockSpot(by: translation)
        XCTAssertEqual(order, ["a", "b", "timer", "c"])
        XCTAssertEqual(size(), .small)
    }

    func testASpotOfTheDockReleasedOffTheGridGlidesBackToItsTileAndStaysOff() throws {
        host.heldEnds = []
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        model.reload()
        model.dockFrame = dock
        model.showStoreSection(.store)
        model.dragDockSpot("timer", by: dockMove("timer", to: leftHalf(of: "b")))
        XCTAssertTrue(order.contains("timer"))

        let away = CGSize(width: 0, height: -5)
        model.dragDockSpot("timer", by: away)
        XCTAssertEqual(order, ["a", "b", "c", "d"])

        model.dropDockSpot(by: away)
        XCTAssertEqual(model.lift.origin, tile("timer").origin)
        XCTAssertEqual(model.carry?.isLanding, true)
        host.heldEnds?.forEach { $0() }
        XCTAssertNil(model.carry)
        XCTAssertEqual(offInStore, ["timer"])
        XCTAssertEqual(savedOrder(), ["a", "b", "c", "d"])
    }

    func testACardPutBackGlidesToWhereItStarted() {
        host.heldEnds = []
        let start = model.placements[3].rect
        model.dragSpot("d", by: move("d", to: leftHalf(of: "c")))

        model.handleEditKey(ActionKey(name: "escape"))

        XCTAssertEqual(model.lift.origin, CGPoint(x: SpotTokens.halo + start.minX, y: SpotTokens.gridTop + start.minY))
        host.heldEnds?.forEach { $0() }
        XCTAssertNil(model.carry)
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

    func testASidePanelShowsEmptyAndNoCardMoves() {
        let before = model.placements.map(\.rect)

        model.show(.left, true)

        XCTAssertEqual(model.panels, GridPanels(hasLeft: true))
        XCTAssertEqual(files.config.read().panels, GridPanels(hasLeft: true))
        let shift = CGFloat(SpotTokens.columns) * (SpotTokens.cell + SpotTokens.columnGap)
        XCTAssertEqual(model.placements.map { $0.rect.offsetBy(dx: -shift, dy: 0) }, before)
        XCTAssertEqual(model.gridOrigin.x, SpotTokens.halo - shift)
    }

    func testASearchShowsNoSidePanelAndAnEmptyFieldShowsThemAgain() {
        model.show(.left, true)
        XCTAssertEqual(model.shownPanels, GridPanels(hasLeft: true))

        model.query = "a"
        XCTAssertEqual(model.shownPanels, GridPanels())

        model.query = ""
        XCTAssertEqual(model.shownPanels, GridPanels(hasLeft: true))
    }

    func testACardDroppedOnASidePanelStaysThereAndHidingThePanelMovesItBackToTheEnd() async throws {
        model.show(.right, true)
        let column = model.panels.firstColumn(of: .right)
        let point = CGPoint(x: SpotPlacement(index: 0, row: 0, column: column, size: .small).rect.midX, y: model.placements[0].rect.midY)

        let translation = move("a", to: point)
        model.dragSpot("a", by: translation)
        model.dropSpot(by: translation)

        XCTAssertEqual(model.visible.first { $0.id == "a" }?.panel, .right)
        XCTAssertEqual(files.config.read().arrangement.panel(of: "a"), .right)
        model.show(.right, false)
        for _ in 0..<500 where model.panels.hasRight { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(model.panels.hasRight)
        XCTAssertEqual(model.visible.first { $0.id == "a" }?.panel, .center)
        XCTAssertEqual(model.visible.filter(\.isOnGrid).last?.id, "a")
    }

    func testADraggedCardMakesItsRoomInThePanelItWouldLandIn() {
        model.show(.right, true)
        let column = model.panels.firstColumn(of: .right)
        let point = CGPoint(x: SpotPlacement(index: 0, row: 0, column: column, size: .small).rect.midX, y: model.placements[0].rect.midY)

        model.dragSpot("a", by: move("a", to: point))

        let index = model.visible.firstIndex { $0.id == "a" } ?? -1
        XCTAssertGreaterThanOrEqual(model.placements.first { $0.index == index }?.column ?? -1, column)
    }

    func testAPanelThatShowsIsEmptyEvenWhenAnOldChoiceNamedIt() throws {
        var arrangement = files.config.read().arrangement
        arrangement.set(panel: .right, of: "b")
        try files.config.write(arrangement)
        model.reload()
        XCTAssertLessThan(model.placements.map(\.column).max() ?? 0, SpotTokens.columns)

        model.show(.right, true)

        XCTAssertLessThan(model.placements.map(\.column).max() ?? 0, SpotTokens.columns)
        XCTAssertNil(files.config.read().arrangement.panel(of: "b"))
    }

    func testTheGridTakesTheSidePanelsOfTheConfig() throws {
        try files.config.set("right_panel", to: true)

        model.reload()

        XCTAssertEqual(model.panels, GridPanels(hasRight: true))
    }

    func testTheGridGrowsDownPastTheRowsThePanelShows() throws {
        model.endEditing()
        for name in ["e", "f", "g", "h", "i", "j", "k", "l", "m"] {
            try "#!/bin/sh\n".writeScript(to: spots.spotFile(name))
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

    func testTheStoreShowsEverySpotWithItsStateAndOrigin() async throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("coin.spot/coin.sh"))
        model.setOnGrid(false, for: "d")

        model.endEditing()
        model.beginEditing()
        XCTAssertFalse(model.dock.items.contains { $0.id == "coin" })
        for _ in 0..<500 where !model.dock.items.contains(where: { $0.id == "coin" }) {
            try await Task.sleep(for: .milliseconds(10))
        }
        let states = Dictionary(uniqueKeysWithValues: model.dock.items.map { ($0.id, $0.state) })
        XCTAssertEqual(states, ["a": .onGrid, "b": .onGrid, "c": .onGrid, "d": .searchOnly, "coin": .off, "timer": .off])
        XCTAssertEqual(model.dock.items.first { $0.id == "a" }?.origin, .mine)
        XCTAssertEqual(model.dock.items.first { $0.id == "coin" }?.origin, .core)

        model.searchDock("ti")
        XCTAssertEqual(model.dock.shown.map(\.id), ["timer"])
    }

    func testEachSectionOfTheStoreShowsItsSpots() throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        model.setOnGrid(false, for: "d")
        model.reload()

        let shown = { (section: SpotDock.Section) -> [String] in
            self.model.showStoreSection(section)
            return self.model.dock.shown.map(\.id)
        }
        XCTAssertEqual(shown(.store), ["timer"])
        XCTAssertEqual(shown(.mine), ["a", "b", "c", "d"])
        XCTAssertEqual(shown(.added), ["a", "b", "c", "d"])
    }

    func testTheNextStepAddsASpotToSearchThenToTheGridAndTheMenuTakesItBack() throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        model.reload()
        let state = { self.model.dock.items.first { $0.id == "timer" }?.state }

        model.takeStep(of: "timer")
        XCTAssertEqual(state(), .searchOnly)

        model.takeStep(of: "timer")
        XCTAssertEqual(state(), .onGrid)

        model.choose(.place(.off), for: "timer")
        XCTAssertEqual(state(), .off)
    }

    func testTurnOnAllTurnsOnEachSpotThatIsOff() throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        model.turnOff("a")

        model.turnOnAll()

        XCTAssertEqual(offInStore, [])
        XCTAssertTrue(order.contains("a"))
        XCTAssertTrue(order.contains("timer"))
    }

    func testAClickOnAStoreCardOpensItsListingAndEscapeClosesIt() async throws {
        try "#!/bin/sh\n# detail=Counts down\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        try "Counts down.".write(to: core.appendingPathComponent("timer.spot/readme.md"), atomically: true, encoding: .utf8)
        model.reload()
        model.showStoreSection(.store)

        model.openListing("timer")
        XCTAssertEqual(model.dock.opened, "timer")
        XCTAssertFalse(model.dock.isSheetOut)
        XCTAssertEqual(model.dockListing?.readme, "Counts down.")
        for _ in 0..<1000 where !model.dock.isSheetOut { await Task.yield() }
        XCTAssertTrue(model.dock.isSheetOut)

        model.searchDock("")
        XCTAssertEqual(model.dock.opened, "timer")

        model.handleEditKey(ActionKey(name: "escape"))
        XCTAssertNil(model.dock.opened)
        XCTAssertTrue(model.isEditing)
    }

    private var store: URL {
        folder.appendingPathComponent("config/store", isDirectory: true)
    }

    private func publication(of id: String) -> SpotDock.Publication? {
        model.dock.items.first { $0.id == id }?.publication
    }

    func testPublishWritesAPackageOnceAndAgainOnlyWhenTheFilesChange() async throws {
        try "Does a.".write(to: spots.appendingPathComponent("a.spot/readme.md"), atomically: true, encoding: .utf8)
        _ = try model.files.account.keyMadeOnce()
        XCTAssertNil(publication(of: "a"))

        let first = await model.publish("a")
        XCTAssertEqual(first, .published)
        let log = try ReleaseLog(text: String(contentsOf: store.appendingPathComponent("a.spot/releases.jsonl"), encoding: .utf8))
        XCTAssertEqual(log.last?.version, 1)
        XCTAssertEqual(try String(contentsOf: spots.appendingPathComponent("a.spot/releases.jsonl"), encoding: .utf8), log.text)
        XCTAssertEqual(try String(contentsOf: store.appendingPathComponent("a.spot/readme.md"), encoding: .utf8), "Does a.")
        XCTAssertEqual(publication(of: "a"), .current)
        let again = await model.publish("a")
        XCTAssertEqual(again, .unchanged)

        let script = try FileHandle(forWritingTo: spots.appendingPathComponent("a.spot/a.sh"))
        try script.seekToEnd()
        try script.write(contentsOf: Data("echo changed\n".utf8))
        try script.close()
        model.spotsChanged()
        XCTAssertEqual(publication(of: "a"), .changed)
        let third = await model.publish("a")
        XCTAssertEqual(third, .published)
        XCTAssertEqual(publication(of: "a"), .current)
    }

    func testShareCopiesTheStoresPackageAsOneZipThatOpensWithItsReadme() async throws {
        try "Does a.".write(to: spots.appendingPathComponent("a.spot/readme.md"), atomically: true, encoding: .utf8)
        _ = try model.files.account.keyMadeOnce()
        XCTAssertNil(model.sharePackage("a"))
        _ = await model.publish("a")

        let file = try XCTUnwrap(model.sharePackage("a"))

        XCTAssertEqual(file.pathExtension, "spot")
        XCTAssertEqual(try SpotPackage(contentsOf: file).files.first { $0.path == "a.spot/readme.md" }?.text, "Does a.")
    }

    func testAPublishWithNoAccountAsksToSetOneUpAndWritesNothing() async throws {
        try "Does a.".write(to: spots.appendingPathComponent("a.spot/readme.md"), atomically: true, encoding: .utf8)

        let result = await model.publish("a")

        XCTAssertEqual(result, .failed)
        XCTAssertEqual(host.notes, ["Set up your account, then publish again."])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.appendingPathComponent("a.spot").path))
    }

    func testASpotWithNoReadmeOpensItsListingAndIsNotPublished() async {
        let result = await model.publish("a")

        XCTAssertEqual(result, .needsReadme)
        XCTAssertEqual(model.dock.opened, "a")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.appendingPathComponent("a.spot").path))
    }

    func testACoreSpotIsNotPublished() async throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        model.reload()

        let result = await model.publish("timer")
        XCTAssertEqual(result, .notOwn)
    }

    func testACardOfTheSpotsFolderReleasedOnTheStoreIsPublished() async throws {
        try "Does b.".write(to: spots.appendingPathComponent("b.spot/readme.md"), atomically: true, encoding: .utf8)
        _ = try model.files.account.keyMadeOnce()
        model.dockFrame = dock
        let translation = move("b", to: inGrid(CGPoint(x: dock.midX, y: dock.midY)))

        model.dragSpot("b", by: translation)
        model.dropSpot(by: translation)

        let package = store.appendingPathComponent("b.spot")
        for _ in 0..<500 where !FileManager.default.fileExists(atPath: package.path) {
            await Task.yield()
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.path))
        XCTAssertEqual(order, ["a", "b", "c", "d"])
    }

    func testTheStoreFollowsTheEyeOfACard() {
        model.setOnGrid(false, for: "b")

        XCTAssertEqual(model.dock.items.first { $0.id == "b" }?.state, .searchOnly)
    }

    func testASpotThatIsOnStaysInTheStoreAndItsCardOnTheGridIsSelected() {
        model.dockFrame = dock
        model.dragDockSpot("c", by: CGSize(width: 0, height: -200))

        XCTAssertNil(model.carry)
        XCTAssertEqual(model.selected, 2)
        model.turnOn("c")
        XCTAssertEqual(order, ["a", "b", "c", "d"])
    }

    func testTheMinusTurnsASpotOfTheSpotsFolderOffIntoTheDockAndItStaysOff() {
        model.turnOff("a")

        XCTAssertEqual(order, ["b", "c", "d"])
        XCTAssertEqual(offInStore, ["a"])
        XCTAssertEqual(model.dock.items.first { $0.id == "a" }?.origin, .mine)
        XCTAssertEqual(savedOrder(), ["b", "c", "d"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.spotFile("a").path))
    }

    func testASpotTurnedOnFromTheDockComesBackToThePanel() {
        model.turnOff("a")

        model.turnOn("a")

        XCTAssertTrue(order.contains("a"))
        XCTAssertEqual(offInStore, [])
    }

    func testACoreSpotTurnsOnFromTheDockAndOffIntoIt() throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        model.reload()
        XCTAssertEqual(offInStore, ["timer"])

        model.turnOn("timer")
        XCTAssertTrue(order.contains("timer"))
        XCTAssertEqual(offInStore, [])

        model.turnOff("timer")
        XCTAssertFalse(order.contains("timer"))
        XCTAssertEqual(model.dock.items.first { $0.id == "timer" }?.state, .off)
        XCTAssertEqual(model.dock.items.first { $0.id == "timer" }?.origin, .core)
    }

    func testTheDockDeletesOnlyASpotOfTheSpotsFolderAndUndoPutsItBack() throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        model.turnOff("a")

        model.delete("timer")
        model.delete("a")

        XCTAssertEqual(offInStore, ["timer"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: trash.appendingPathComponent("a.spot").path))
        XCTAssertTrue(model.undoRemoval())
        XCTAssertEqual(offInStore, ["a", "timer"])
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
