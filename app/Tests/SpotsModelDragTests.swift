import XCTest
@testable import OpenspotCore

@MainActor
final class SpotsModelDragTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: FakeHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-drag-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
        try "[[spots]]\nid = \"coin\"\nsize = \"small\"\n\n[[spots]]\nid = \"timer\"\nsize = \"small\"\n\n[[spots]]\nid = \"d\"\nsize = \"small\"\n"
            .write(to: folder.appendingPathComponent("defaults.toml"), atomically: true, encoding: .utf8)
        suite = "openspot-drag-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let host = FakeHost()
        self.host = host
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2, prepare: { await host.prepare($0, glyphs: $1) }))
        host.model = model
        for name in ["a", "b", "c", "d"] {
            let file = spots.appendingPathComponent("\(name).spot/\(name).sh")
            try "#!/bin/sh\n".writeScript(to: file)
            try FileManager.default.setAttributes([.creationDate: Date(timeIntervalSince1970: 1_700_000_000)], ofItemAtPath: file.path)
        }
        await model.reload()
        model.dragRest = .zero
        model.beginEditing()
    }

    override func tearDown() async throws {
        model.quit()
        SpotTokens.take(SpotTokens.layout.with(columns: SpotTokens.columns))
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
                try FileManager.default.moveItem(at: url, to: trash.appendingPathComponent(url.lastPathComponent))
            },
            defaultConfig: folder.appendingPathComponent("defaults.toml")
        )
    }

    private var order: [String] {
        model.visible.map(\.id)
    }

    private var cells: [GridCell] {
        model.placements.map(\.cell)
    }

    private func place(of id: String) -> SpotPlacement {
        model.placements[model.visible.firstIndex { $0.id == id } ?? 0]
    }

    private func move(_ id: String, to cell: GridCell) -> CGSize {
        let rect = place(of: id).rect
        let target = SpotPlacement(index: 0, row: cell.row, column: cell.column, size: .small).rect
        return CGSize(width: target.minX - rect.minX, height: target.minY - rect.minY)
    }

    private var offInConfig: [String] {
        (try? model.files.config.read().arrangement.choices.filter { $0.isOnGrid == false }.map(\.id).sorted()) ?? []
    }

    private func savedCells() async -> [String: GridCell] {
        let host = FakeHost()
        let other = SpotsModel(host: host, files: files)
        await other.reload()
        defer { other.quit() }
        return withExtendedLifetime(host) { Dictionary(uniqueKeysWithValues: other.visible.indices.map { (other.visible[$0].id, other.placements[$0].cell) }) }
    }

    private let row0 = GridCell(row: 0, column: 0)
    private let home = [GridCell(row: 0, column: 0), GridCell(row: 0, column: 2), GridCell(row: 1, column: 0), GridCell(row: 1, column: 2)]

    func testTheCardsLieInReadingOrderWithTheSizesTheyChose() {
        XCTAssertEqual(order, ["a", "b", "c", "d"])
        XCTAssertEqual(cells, home)
        XCTAssertEqual(model.placements.map(\.size), [.wide, .wide, .wide, .small])
    }

    func testACardDraggedToAFreeCellLiesThereAndAReleaseSavesItsCell() async {
        let translation = move("d", to: GridCell(row: 3, column: 1))

        model.dragSpot("d", by: translation)

        XCTAssertEqual(place(of: "d").cell, GridCell(row: 3, column: 1))
        XCTAssertEqual(order, ["a", "b", "c", "d"])
        let before = await savedCells()
        XCTAssertEqual(before["d"], GridCell(row: 1, column: 2))

        model.dropSpot(by: translation)

        XCTAssertNil(model.drag)
        XCTAssertEqual(place(of: "d").cell, GridCell(row: 3, column: 1))
        let after = await savedCells()
        XCTAssertEqual(after["d"], GridCell(row: 3, column: 1))
        XCTAssertEqual(after["a"], row0)
    }

    func testACardDraggedOverAnotherPushesTheRestOnInReadingOrder() {
        let translation = move("d", to: row0)

        model.dragSpot("d", by: translation)
        model.dropSpot(by: translation)

        XCTAssertEqual(cells, [GridCell(row: 0, column: 1), GridCell(row: 1, column: 0), GridCell(row: 1, column: 2), row0])
        XCTAssertEqual(model.selected, 3)
    }

    func testACardDraggedOverAHoleSmallerThanItTakesTheSizeOfTheHoleWhileHeld() async throws {
        try files.config.change { config in
            config.arrangement.set(size: .square, of: "a")
            config.arrangement.set(cell: GridCell(row: 4, column: 0), of: "a", columns: 4)
            config.arrangement.set(cell: GridCell(row: 0, column: 2), of: "b", columns: 4)
            config.arrangement.set(cell: GridCell(row: 1, column: 0), of: "c", columns: 4)
            config.arrangement.set(cell: GridCell(row: 1, column: 2), of: "d", columns: 4)
        }
        await model.reload()
        XCTAssertEqual(place(of: "a"), SpotPlacement(index: 0, row: 4, column: 0, size: .square))

        let translation = move("a", to: row0)
        model.dragSpot("a", by: translation)

        XCTAssertEqual(place(of: "a"), SpotPlacement(index: 0, row: 0, column: 0, size: .wide))
        model.dropSpot(by: translation)
        XCTAssertEqual(files.config.read().arrangement.size(of: "a"), .wide)
    }

    func testADroppedCardLandsUntilItsMotionEnds() {
        host.heldEnds = []
        let translation = move("d", to: GridCell(row: 2, column: 0))
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
        model.dragSpot("d", by: move("d", to: GridCell(row: 2, column: 0)))

        _ = model.handleKey(ActionKey(name: "escape"))

        XCTAssertEqual(model.landing, "d")
        host.heldEnds?.forEach { $0() }
        XCTAssertNil(model.landing)
    }

    func testTheCardsWaitForThePointerToRestButAReleaseLandsAtOnce() {
        model.dragRest = .seconds(30)
        let translation = move("d", to: row0)

        model.dragSpot("d", by: translation)

        XCTAssertEqual(place(of: "a").cell, row0)
        model.dropSpot(by: translation)
        XCTAssertEqual(place(of: "d").cell, row0)
    }

    func testTheCardsMakeRoomAfterARealRest() async throws {
        model.dragRest = .milliseconds(100)

        model.dragSpot("d", by: move("d", to: row0))

        try await wait("a gives way") { self.place(of: "a").cell != self.row0 }
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

    func testEditSpotsOffersNoHideKey() {
        XCTAssertEqual(model.hint, "S Size   ⇧ Arrows Move   Esc Done")
    }

    func testAShiftArrowMovesTheSelectedCardOneCell() {
        model.selected = 3

        _ = model.handleKey(ActionKey(name: "down", isShift: true))

        XCTAssertEqual(place(of: "d").cell, GridCell(row: 2, column: 2))
    }

    func testEscapePutsTheCardsBackAndKeepsEditSpots() async {
        let translation = move("d", to: row0)
        model.dragSpot("d", by: translation)

        _ = model.handleKey(ActionKey(name: "escape"))
        model.dropSpot(by: translation)

        XCTAssertTrue(model.isEditing)
        XCTAssertNil(model.drag)
        XCTAssertEqual(cells, home)
        XCTAssertEqual(model.selected, 3)
    }

    func testAReleaseOffTheGridPutsTheCardsBack() async {
        model.dragSpot("d", by: move("d", to: row0))

        model.dropSpot(by: CGSize(width: -3 * SpotTokens.gridWidth, height: 0))

        XCTAssertNil(model.drag)
        XCTAssertEqual(cells, home)
        let saved = await savedCells()
        XCTAssertEqual(saved["d"], GridCell(row: 1, column: 2))
    }

    func testEditSpotsShowsNoShelfAndASpotOffTheGridStaysOff() async throws {
        try files.config.change { $0.arrangement.set(isOnGrid: false, of: "a") }
        await model.reload()

        XCTAssertEqual(order, ["b", "c", "d"])
    }

    func testTheGridHoldsSevenRowsAndASpotWithNoRoomIsLeftForSearch() async throws {
        model.endEditing()
        for index in 0..<26 {
            try "#!/bin/sh\n".writeScript(to: spots.spotFile("x\(index)"))
        }
        await model.reload()

        XCTAssertLessThan(model.visible.count, 30)
        XCTAssertEqual(model.placements.map(\.row).max(), SpotTokens.rows - 1)
        XCTAssertLessThan(model.grid.freeCells(around: model.placements).count, 2)
        XCTAssertEqual(model.placements.indices.map { $0 }, model.placements.map(\.index))
    }

    func testATipGoesWhenADragStartsOrEditSpotsEnds() {
        model.tip = SpotTip(id: "d", anchor: .leadingCorner, text: "Turn off")
        model.dragSpot("d", by: move("d", to: row0))
        XCTAssertNil(model.tip)
        model.cancelDrag()

        model.tip = SpotTip(id: "b", anchor: .leadingCorner, text: "Turn off")
        model.endEditing()
        XCTAssertNil(model.tip)
    }

    func testAPanelThatHidesEndsTheDrag() {
        model.dragSpot("d", by: move("d", to: row0))

        model.panelWillHide()

        XCTAssertNil(model.drag)
        XCTAssertNil(model.carry)
        XCTAssertEqual(model.lift.offset, .zero)
    }

    func testOffTheGridTheCardsGoBackToTheirPlacesBeforeTheRelease() {
        model.dragSpot("d", by: move("d", to: row0))
        XCTAssertNotEqual(place(of: "a").cell, row0)

        model.dragSpot("d", by: CGSize(width: 0, height: SpotTokens.panelHeight))

        XCTAssertEqual(place(of: "a").cell, row0)
    }

    func testTheCarriedCardGlidesToItsPlaceSettlingFromItsLiftAndGoesWhenItLands() {
        host.heldEnds = []
        let translation = move("d", to: GridCell(row: 2, column: 2))
        model.dragSpot("d", by: translation)
        XCTAssertEqual(model.carry?.entry.id, "d")
        XCTAssertEqual(model.carry?.isLanding, false)

        model.dropSpot(by: translation)

        let place = place(of: "d").rect
        XCTAssertEqual(model.lift.origin, CGPoint(x: SpotTokens.halo + place.minX, y: SpotTokens.gridTop + place.minY))
        XCTAssertEqual(model.carry?.entry.id, "d")
        XCTAssertEqual(model.carry?.isLanding, true)
        host.heldEnds?.forEach { $0() }
        XCTAssertNil(model.carry)
    }

    func testACardPutBackGlidesToWhereItStarted() {
        host.heldEnds = []
        let start = model.placements[3].rect
        model.dragSpot("d", by: move("d", to: row0))

        _ = model.handleKey(ActionKey(name: "escape"))

        XCTAssertEqual(model.lift.origin, CGPoint(x: SpotTokens.halo + start.minX, y: SpotTokens.gridTop + start.minY))
        host.heldEnds?.forEach { $0() }
        XCTAssertNil(model.carry)
    }

    private var down: CGSize {
        CGSize(width: 0, height: SpotTokens.cell + SpotTokens.rowGap)
    }

    private var across: CGSize {
        CGSize(width: 2 * (SpotTokens.cell + SpotTokens.columnGap), height: 0)
    }

    private var savedSize: SpotSize? {
        files.config.read().arrangement.size(of: "c")
    }

    func testACornerPulledAcrossMakesTheCardAStripPushingTheCardItCoversAndAReleaseSavesIt() async {
        model.resizeSpot("c", by: across)

        XCTAssertEqual(model.placements[2].size, .strip)
        XCTAssertEqual(place(of: "d").cell, GridCell(row: 2, column: 0))
        XCTAssertNil(savedSize)

        model.dropResize()

        XCTAssertNil(model.resize)
        XCTAssertEqual(model.placements[2].size, .strip)
        XCTAssertEqual(savedSize, .strip)
        XCTAssertEqual(model.selected, 2)
        let saved = await savedCells()
        XCTAssertEqual(saved["d"], GridCell(row: 2, column: 0))
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

        _ = model.handleKey(ActionKey(name: "escape"))
        model.dropResize()

        XCTAssertTrue(model.isEditing)
        XCTAssertNil(model.resize)
        XCTAssertEqual(model.placements[2].size, .wide)
        XCTAssertEqual(place(of: "d").cell, GridCell(row: 1, column: 2))
        XCTAssertNil(savedSize)
    }

    func testAReleaseAtTheSameSizeSavesNothing() {
        model.resizeSpot("c", by: CGSize(width: 5, height: 5))

        model.dropResize()

        XCTAssertNil(model.resize)
        XCTAssertNil(savedSize)
    }

    func testMoreColumnsWidenTheGridAtBothSidesAndKeepEachWidthsOwnCells() async {
        model.moveSpot("d", to: GridCell(row: 4, column: 3))

        model.set(columns: 8)
        defer { model.grid = GridLayout() }

        XCTAssertEqual(files.config.read().grid, GridLayout(columns: 8))
        XCTAssertEqual(SpotTokens.gridWidth, SpotTokens.width(columns: 8))
        XCTAssertEqual(cells, [GridCell(row: 0, column: 0), GridCell(row: 0, column: 2), GridCell(row: 0, column: 4), GridCell(row: 0, column: 6)])
        model.moveSpot("a", to: GridCell(row: 3, column: 6))
        model.set(columns: 4)
        XCTAssertEqual(place(of: "d").cell, GridCell(row: 4, column: 3))
        XCTAssertEqual(place(of: "a").cell, row0)
    }

    private var pointOnGrid: PointerTarget {
        .grid(CGPoint(x: model.placements[0].rect.midX, y: model.placements[0].rect.midY))
    }

    func testTheGridEndsAtItsLastRowAndEditingShowsAllSevenRows() {
        let rows = SpotPlacement.height(of: model.placements)
        XCTAssertEqual(model.gridHeight, SpotTokens.contentHeight(gridHeight: model.grid.height))

        model.endEditing()

        XCTAssertEqual(model.gridHeight, SpotTokens.contentHeight(gridHeight: rows))
    }

    func testAHeldCommandAloneStartsNoEditing() {
        model.endEditing()

        model.hold([.command])

        XCTAssertFalse(model.isEditing)
    }

    func testAPointerMoveOverTheGridWithCommandHeldStartsEditingAndTheReleaseEndsIt() {
        model.endEditing()
        let placements = model.placements

        model.hold([.command])
        model.point(at: pointOnGrid)

        XCTAssertTrue(model.isEditing)
        XCTAssertEqual(model.placements, placements)
        model.hold([])
        XCTAssertFalse(model.isEditing)
    }

    func testACommandReleasedDuringADragEndsEditingOnceTheCardLands() {
        model.endEditing()
        host.heldEnds = []
        model.hold([.command])
        model.point(at: pointOnGrid)
        let translation = move("d", to: GridCell(row: 3, column: 0))
        model.dragSpot("d", by: translation)

        model.hold([])
        XCTAssertTrue(model.isEditing)
        model.dropSpot(by: translation)
        XCTAssertTrue(model.isEditing)
        host.heldEnds?.forEach { $0() }

        XCTAssertFalse(model.isEditing)
        XCTAssertEqual(place(of: "d").cell, GridCell(row: 3, column: 0))
    }

    func testEditingOpenedByRearrangeStaysWhenCommandIsReleased() {
        model.endEditing()
        model.editGrid()

        model.hold([.command])
        model.hold([])

        XCTAssertTrue(model.isEditing)
    }

    func testACommandHeldOverTheGridWhileASearchShowsStartsNoEditing() {
        model.endEditing()
        model.query = "a"

        model.hold([.command])
        model.point(at: pointOnGrid)

        XCTAssertFalse(model.isEditing)
    }

    private func fillTheGrid() async throws {
        model.endEditing()
        for index in 0..<26 {
            try "#!/bin/sh\n".writeScript(to: spots.spotFile("x\(index)"))
        }
        await model.reload()
        model.beginEditing()
    }

    func testALiveDragStillPushesWhenASpotIsLeftOut() async throws {
        try await fillTheGrid()
        XCTAssertFalse(model.leftOut.isEmpty)
        let first = order[0]
        let last = order[order.count - 1]
        let start = place(of: first).cell

        model.dragSpot(last, by: move(last, to: start))

        XCTAssertEqual(place(of: last).cell, start)
        XCTAssertNotEqual(place(of: first).cell, start)
    }

    func testAReloadDuringADragDropsTheDrag() async throws {
        model.dragSpot("d", by: move("d", to: row0))
        try "#!/bin/sh\n".writeScript(to: spots.spotFile("e"))

        await model.reload()
        model.dropSpot(by: move("d", to: row0))

        XCTAssertNil(model.drag)
        XCTAssertNotEqual(files.config.read().arrangement.cells(of: "a")?[4], GridCell(row: 0, column: 1))
    }

    func testAColumnSwitchDuringADragDropsTheDrag() {
        model.dragSpot("d", by: move("d", to: row0))

        model.set(columns: 8)
        defer { model.grid = GridLayout() }

        XCTAssertNil(model.drag)
    }

    func testAKeyWithCommandEndsTheEditOfAHeldCommandAndAnotherMoveStartsNone() {
        model.endEditing()
        model.hold([.command])
        model.point(at: pointOnGrid)
        XCTAssertTrue(model.isEditing)

        _ = model.handleKey(ActionKey(name: "s", isCommand: true))

        XCTAssertFalse(model.isEditing)
        XCTAssertNil(files.config.read().arrangement.size(of: "a"))
        model.point(at: pointOnGrid)
        XCTAssertFalse(model.isEditing)
        model.hold([])
        model.hold([.command])
        model.point(at: pointOnGrid)
        XCTAssertTrue(model.isEditing)
    }

    func testAHideForgetsAHeldCommand() {
        model.endEditing()
        model.hold([.command])

        model.panelWillHide()
        model.point(at: pointOnGrid)

        XCTAssertFalse(model.isEditing)
    }

    func testTheFreeCellsAreKeptForTheSlotsToDraw() {
        XCTAssertEqual(model.freeCells.count, 4 * SpotTokens.rows - 7)
    }

    func testAPanelThatHidesEndsTheResize() {
        model.resizeSpot("c", by: down)

        model.panelWillHide()

        XCTAssertNil(model.resize)
    }

    private var store: URL {
        folder.appendingPathComponent("config/store", isDirectory: true)
    }

    private func publication(of id: String) -> SpotPublication? {
        let scan = (try? SpotsFolder(url: spots).scan()) ?? ScanResult(files: [], refused: [])
        return SpotCatalog.publications(of: scan, in: store)[id]
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
        await model.spotsChanged()
        XCTAssertEqual(publication(of: "a"), .changed)
        let third = await model.publish("a")
        XCTAssertEqual(third, .published)
        XCTAssertEqual(publication(of: "a"), .current)
    }

    func testAPublishSignsOnlyAfterTouchID() async throws {
        try "Does a.".write(to: spots.appendingPathComponent("a.spot/readme.md"), atomically: true, encoding: .utf8)
        _ = try model.files.account.keyMadeOnce()
        host.allowsActs = false

        let denied = await model.publish("a")

        XCTAssertEqual(denied, .failed)
        XCTAssertNil(publication(of: "a"))
        XCTAssertEqual(host.asked, ["sign your spot"])
        XCTAssertEqual(host.notes.last, "A was not published. Touch ID didn't pass, so Openspot signed nothing.")
    }

    func testAPublishWithNoAccountOpensAccountAndWaitsForTheKey() async throws {
        try FileManager.default.createDirectory(at: core.appendingPathComponent("openspot.spot"), withIntermediateDirectories: true)
        await model.reload()
        try "Does a.".write(to: spots.appendingPathComponent("a.spot/readme.md"), atomically: true, encoding: .utf8)

        let result = await model.publish("a")

        XCTAssertEqual(result, .failed)
        XCTAssertEqual(model.flow.current, FlowSheet(spot: AccountSheet.id))
        XCTAssertEqual(host.notes, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.appendingPathComponent("a.spot").path))

        _ = try await model.runs.answer(of: model.account.spot, "new", limit: 60)
        _ = try await model.runs.answer(of: model.account.spot, "create", input: "input.handle=tony\n", limit: 60)

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.appendingPathComponent("a.spot").path))
    }

    func testAPublishThatAccountFinishesGoesBackToTheSheetBehindAccount() async throws {
        try FileManager.default.createDirectory(at: core.appendingPathComponent("openspot.spot"), withIntermediateDirectories: true)
        try "#!/bin/sh\nprintf 'text=x\\ntitle=X\\n'\n".writeScript(to: spots.appendingPathComponent("b.spot/b.sh"), toml: "")
        await model.reload()
        try "Does a.".write(to: spots.appendingPathComponent("a.spot/readme.md"), atomically: true, encoding: .utf8)
        model.endEditing(moving: false)
        model.isShown = true
        model.panelWillShow()
        XCTAssertTrue(model.open("b"))
        try await wait("the sheet of b") { self.model.openSheetID == "b" }

        _ = await model.publish("a")
        try await wait("the account") { self.model.openSheetID == AccountSheet.id }
        _ = try await model.runs.answer(of: model.account.spot, "create", input: "route=handle\ninput.handle=tony\n", limit: 60)

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.appendingPathComponent("a.spot").path))
        try await wait("the sheet behind") { self.model.flow.current == FlowSheet(spot: "b") }
    }

    func testAPushOfAPublishPageFromACallerPublishesNothing() async throws {
        try FileManager.default.createDirectory(at: core.appendingPathComponent("openspot.spot"), withIntermediateDirectories: true)
        await model.reload()
        try "Does a.".write(to: spots.appendingPathComponent("a.spot/readme.md"), atomically: true, encoding: .utf8)

        model.push(FlowSheet(spot: AccountSheet.id, route: "publish:a"))
        _ = try await model.runs.answer(of: model.account.spot, "new", input: "route=publish:a\n", limit: 60)
        _ = try await model.runs.answer(of: model.account.spot, "create", input: "route=publish:a\ninput.handle=tony\n", limit: 60)

        XCTAssertNotNil(try model.files.account.key())
        XCTAssertNotEqual(model.flow.current?.route, "publish:a")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.appendingPathComponent("a.spot").path))
        XCTAssertEqual(host.asked, [])
    }

    func testAPublishThatWaitsIsForgottenWhenItsSheetsClose() async throws {
        try FileManager.default.createDirectory(at: core.appendingPathComponent("openspot.spot"), withIntermediateDirectories: true)
        await model.reload()
        try "Does a.".write(to: spots.appendingPathComponent("a.spot/readme.md"), atomically: true, encoding: .utf8)
        _ = await model.publish("a")

        model.open(AccountSheet.id)
        _ = try await model.runs.answer(of: model.account.spot, "new", limit: 60)
        _ = try await model.runs.answer(of: model.account.spot, "create", input: "input.handle=tony\n", limit: 60)

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.appendingPathComponent("a.spot").path))
    }

    func testASpotWithNoReadmeAsksForOneAndIsNotPublished() async {
        let result = await model.publish("a")

        XCTAssertEqual(result, .needsReadme)
        XCTAssertEqual(host.notes, ["Write a readme for A, then publish it again."])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.appendingPathComponent("a.spot").path))
    }

    func testACoreSpotIsNotPublished() async throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        await model.reload()

        let result = await model.publish("timer")
        XCTAssertEqual(result, .notOwn)
    }

    func testTheMinusTakesASpotOfTheSpotsFolderOffTheGridAndKeepsItOn() async {
        model.takeOffGrid("a")

        XCTAssertEqual(order, ["b", "c", "d"])
        XCTAssertEqual(offInConfig, ["a"])
        XCTAssertTrue(model.entries.contains { $0.id == "a" })
        let shown = await savedCells()
        XCTAssertEqual(shown.keys.sorted(), ["b", "c", "d"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.spotFile("a").path))
    }

    func testTheMinusTakesACoreSpotOffTheGridAndKeepsItOn() async throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        try model.files.config.pin("timer", on: true)
        await model.reload()
        XCTAssertTrue(order.contains("timer"))

        model.takeOffGrid("timer")

        XCTAssertFalse(order.contains("timer"))
        XCTAssertEqual(try model.files.config.read().arrangement.isOnGrid(of: "timer"), false)
        XCTAssertTrue(model.entries.contains { $0.id == "timer" })
    }

    func testACardReleasedOverTheStoresWindowTurnsItsSpotOff() {
        let translation = move("a", to: GridCell(row: 0, column: 1))
        model.dragSpot("a", by: translation)
        host.isPointerOverWindow = true

        model.dropSpot(by: translation)

        XCTAssertFalse(order.contains("a"))
        XCTAssertEqual(offInConfig, ["a"])
    }

    func testTheStoreFindsTheCardOfASpotThatIsOffByItsStoreID() async throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"), toml: "detail = 'Counts down'")
        let friends = folder.appendingPathComponent("friends", isDirectory: true)
        try "#!/bin/sh\n".writeScript(to: friends.appendingPathComponent("shared.spot/shared.sh"), toml: "title = 'Shared'")
        _ = try ConfigFile(url: folder.appendingPathComponent("config/config.toml")).change { $0.add(store: Store(url: friends)) }
        await model.reload()

        XCTAssertEqual(model.storeEntry("a")?.id, "a")
        XCTAssertEqual(model.storeEntry("timer")?.spot.subtitle, "Counts down")
        XCTAssertEqual(model.storeEntry("shared")?.spot.name, "Shared")
        XCTAssertNil(model.storeEntry("missing"))
    }

    func testNoCardLiftsOutsideEditSpots() {
        model.endEditing()

        model.dragSpot("d", by: move("d", to: row0))
        model.resizeSpot("c", by: down)

        XCTAssertNil(model.drag)
        XCTAssertNil(model.resize)
        XCTAssertEqual(order, ["a", "b", "c", "d"])
        XCTAssertEqual(model.placements[2].size, .wide)
    }
}
