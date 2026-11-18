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

    private func move(_ id: String, to point: CGPoint) -> CGSize {
        let index = model.visible.firstIndex { $0.id == id } ?? 0
        let rect = model.placements[index].rect
        return CGSize(width: point.x - rect.midX, height: point.y - rect.midY)
    }

    private func leftHalf(of id: String) -> CGPoint {
        let rect = model.placements[model.visible.firstIndex { $0.id == id } ?? 0].rect
        return CGPoint(x: rect.minX + rect.width / 4, y: rect.midY)
    }

    private var offInConfig: [String] {
        (try? model.files.config.read().arrangement.choices.filter { $0.isEnabled == false }.map(\.id).sorted()) ?? []
    }

    private func savedOrder() async -> [String] {
        let host = FakeHost()
        let other = SpotsModel(host: host, files: files)
        await other.reload()
        defer { other.quit() }
        return withExtendedLifetime(host) { other.visible.map(\.id) }
    }

    func testACardDraggedLeftOfAnotherMakesRoomThereAndAReleaseSavesIt() async {
        XCTAssertEqual(order, ["a", "b", "c", "d"])
        let translation = move("d", to: leftHalf(of: "c"))

        model.dragSpot("d", by: translation)

        XCTAssertEqual(order, ["a", "b", "d", "c"])
        XCTAssertEqual(model.placements.map(\.size), [.wide, .wide, .wide, .wide])
        XCTAssertEqual(model.selected, 2)
        let shown = await savedOrder()
        XCTAssertEqual(shown, ["a", "b", "c", "d"])

        model.dropSpot(by: translation)

        XCTAssertNil(model.drag)
        XCTAssertEqual(order, ["a", "b", "d", "c"])
        let shown2 = await savedOrder()
        XCTAssertEqual(shown2, ["a", "b", "d", "c"])
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

        _ = model.handleKey(ActionKey(name: "escape"))

        XCTAssertEqual(model.landing, "d")
        host.heldEnds?.forEach { $0() }
        XCTAssertNil(model.landing)
    }

    func testALiftedCardMovesWithTheGridWhenItScrollsAndLandsWhereThePointerIs() async {
        let row = SpotTokens.cell + SpotTokens.rowGap
        let translation = move("a", to: leftHalf(of: "a"))
        model.dragSpot("a", by: translation)

        model.gridScrolled(to: row)

        XCTAssertEqual(model.lift.offset, CGSize(width: translation.width, height: translation.height + row))
        XCTAssertEqual(order, ["b", "c", "a", "d"])
        model.dropSpot(by: translation)
        let shown = await savedOrder()
        XCTAssertEqual(shown, ["b", "c", "a", "d"])
    }

    func testAResizedCardFollowsTheGridWhenItScrolls() {
        model.resizeSpot("c", by: .zero)

        model.gridScrolled(to: SpotTokens.cell + SpotTokens.rowGap)

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

        for _ in 0..<6000 where order != ["a", "b", "d", "c"] {
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

    func testTheHKeyPutsTheSelectedSpotInSearchOnly() {
        XCTAssertEqual(model.hint, "S Size   H Hide   ⇧ Arrows Move   Esc Done")

        _ = model.handleKey(ActionKey(name: "h"))

        XCTAssertEqual(order, ["b", "c", "d", "a"])
        XCTAssertEqual(model.cards.first { $0.id == "a" }?.isOnGrid, false)
        XCTAssertEqual(model.hint, "S Size   H Hide   ⇧ Arrows Move   Esc Done")
    }

    func testEscapePutsTheCardsBackAndKeepsEditSpots() async {
        let translation = move("d", to: leftHalf(of: "c"))
        model.dragSpot("d", by: translation)

        _ = model.handleKey(ActionKey(name: "escape"))
        model.dropSpot(by: translation)

        XCTAssertTrue(model.isEditing)
        XCTAssertNil(model.drag)
        XCTAssertEqual(order, ["a", "b", "c", "d"])
        XCTAssertEqual(model.selected, 3)
        let shown = await savedOrder()
        XCTAssertEqual(shown, ["a", "b", "c", "d"])
    }

    func testAReleaseOffTheGridPutsTheCardsBack() async {
        model.dragSpot("d", by: move("d", to: leftHalf(of: "c")))

        model.dropSpot(by: move("d", to: CGPoint(x: -SpotTokens.gridWidth, y: 0)))

        XCTAssertNil(model.drag)
        XCTAssertEqual(order, ["a", "b", "c", "d"])
        let shown = await savedOrder()
        XCTAssertEqual(shown, ["a", "b", "c", "d"])
    }

    func testInEditSpotsTheCardsInSearchOnlyLieOnAShelfUnderTheGrid() {
        model.setOnGrid(false, for: "a")

        XCTAssertEqual(order, ["b", "c", "d", "a"])
        XCTAssertEqual(model.placements.map(\.top), [SpotTokens.groupTitleBand, SpotTokens.groupTitleBand, SpotTokens.groupTitleBand, 2 * SpotTokens.groupTitleBand])
        XCTAssertGreaterThan(model.placements[3].rect.minY, model.placements[0].rect.maxY)

        model.endEditing()
        XCTAssertEqual(order, ["b", "c", "d"])
    }

    func testAReportOfASpotOnTheShelfMovesNoCard() {
        model.setOnGrid(false, for: "a")

        XCTAssertFalse(model.mayMove("a"))
        XCTAssertFalse(model.mayMove("b"))
        XCTAssertEqual(model.groupBands?.grid, 3)
        XCTAssertEqual(model.groupBands?.shelf, 1)
    }

    func testTheShelfLeavesOutASpotWithNoCardOfItsOwn() async throws {
        try "#!/bin/sh\n".writeScript(to: spots.appendingPathComponent("rows.spot/rows.sh"), toml: "on = ['panel.open']\noffers = ['search']")
        await model.reload()

        XCTAssertFalse(order.contains("rows"))
    }

    func testWithEveryCardInSearchOnlyTheShelfStillHasItsTitleBand() {
        for id in ["a", "b", "c", "d"] { model.setOnGrid(false, for: id) }

        XCTAssertEqual(Set(model.placements.map(\.top)), [2 * SpotTokens.groupTitleBand])
    }

    func testACardDraggedUnderTheGridGoesToSearchOnly() async {
        let below = CGPoint(x: SpotTokens.cell / 2, y: SpotGrid.height(of: model.placements) + SpotTokens.cell)
        let translation = move("b", to: below)

        model.dragSpot("b", by: translation)
        model.dropSpot(by: translation)

        XCTAssertEqual(order, ["a", "c", "d", "b"])
        XCTAssertEqual(model.cards.first { $0.id == "b" }?.isOnGrid, false)
        let shown = await savedOrder()
        XCTAssertEqual(shown, ["a", "c", "d"])
    }

    func testACardDraggedFromTheShelfOntoTheGridGoesOnTheGridThere() {
        model.setOnGrid(false, for: "d")
        let translation = move("d", to: leftHalf(of: "b"))

        model.dragSpot("d", by: translation)
        model.dropSpot(by: translation)

        XCTAssertEqual(order, ["a", "d", "b", "c"])
        XCTAssertEqual(model.cards.first { $0.id == "d" }?.isOnGrid, true)
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

    }

    func testAPanelThatHidesEndsTheDrag() {
        model.dragSpot("d", by: move("d", to: leftHalf(of: "c")))

        model.panelWillHide()

        XCTAssertNil(model.drag)
        XCTAssertNil(model.carry)
        XCTAssertEqual(model.lift.offset, .zero)
    }

    private func dragMove(to point: CGPoint) -> CGSize {
        let rect = model.drag.map { $0.rect(at: $0.home) } ?? .zero
        return CGSize(width: point.x - rect.midX, height: point.y - rect.midY)
    }

    private func inGrid(_ point: CGPoint) -> CGPoint {
        let origin = model.gridOrigin
        return CGPoint(x: point.x - origin.x, y: point.y - origin.y)
    }

    func testOffTheGridTheCardsGoBackToTheirPlacesBeforeTheRelease() {
        model.dragSpot("d", by: move("d", to: leftHalf(of: "c")))
        XCTAssertEqual(order, ["a", "b", "d", "c"])

        let start = model.drag.map { $0.rect(at: $0.home) } ?? .zero
        model.dragSpot("d", by: dragMove(to: CGPoint(x: SpotTokens.gridWidth + SpotTokens.cell, y: start.midY)))

        XCTAssertEqual(order, ["a", "b", "c", "d"])
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

    func testACardPutBackGlidesToWhereItStarted() {
        host.heldEnds = []
        let start = model.placements[3].rect
        model.dragSpot("d", by: move("d", to: leftHalf(of: "c")))

        _ = model.handleKey(ActionKey(name: "escape"))

        XCTAssertEqual(model.lift.origin, CGPoint(x: SpotTokens.halo + start.minX, y: SpotTokens.gridTop + start.minY))
        host.heldEnds?.forEach { $0() }
        XCTAssertNil(model.carry)
    }

    private var down: CGSize {
        CGSize(width: 0, height: SpotTokens.cell + SpotTokens.rowGap)
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

        _ = model.handleKey(ActionKey(name: "escape"))
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
        for _ in 0..<6000 where model.panels.hasRight { try await Task.sleep(for: .milliseconds(10)) }
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

    func testAPanelThatShowsIsEmptyEvenWhenAnOldChoiceNamedIt() async throws {
        var arrangement = files.config.read().arrangement
        arrangement.set(panel: .right, of: "b")
        try files.config.write(arrangement)
        await model.reload()
        XCTAssertLessThan(model.placements.map(\.column).max() ?? 0, SpotTokens.columns)

        model.show(.right, true)

        XCTAssertLessThan(model.placements.map(\.column).max() ?? 0, SpotTokens.columns)
        XCTAssertNil(files.config.read().arrangement.panel(of: "b"))
    }

    func testTheGridTakesTheSidePanelsOfTheConfig() async throws {
        try files.config.change { $0.show(.right, true) }

        await model.reload()

        XCTAssertEqual(model.panels, GridPanels(hasRight: true))
    }

    func testTheGridGrowsDownPastTheRowsThePanelShows() async throws {
        model.endEditing()
        for name in ["e", "f", "g", "h", "i", "j", "k", "l", "m"] {
            try "#!/bin/sh\n".writeScript(to: spots.spotFile(name))
        }
        await model.reload()
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

        _ = try await model.runs.answer(of: model.account.spot, SpotAction(arguments: ["new"]), limit: 60)
        _ = try await model.runs.answer(of: model.account.spot, SpotAction(arguments: ["create"]), input: "handle=tony\n", limit: 60)

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.appendingPathComponent("a.spot").path))
    }

    func testAPublishThatAccountFinishesGoesBackToTheSheetBehindAccount() async throws {
        try FileManager.default.createDirectory(at: core.appendingPathComponent("openspot.spot"), withIntermediateDirectories: true)
        try "#!/bin/sh\nprintf 'row=x\\ntitle=X\\n'\n".writeScript(to: spots.appendingPathComponent("b.spot/b.sh"), toml: "on = ['sheet.open']")
        await model.reload()
        try "Does a.".write(to: spots.appendingPathComponent("a.spot/readme.md"), atomically: true, encoding: .utf8)
        model.endEditing(moving: false)
        model.isShown = true
        model.panelWillShow()
        XCTAssertTrue(model.open("b"))
        try await wait("the sheet of b") { self.model.openSheetID == "b" }

        _ = await model.publish("a")
        try await wait("the account") { self.model.openSheetID == AccountSheet.id }
        _ = try await model.runs.answer(of: model.account.spot, SpotAction(arguments: ["create"]), input: "handle=tony\n", limit: 60, variables: ["OPENSPOT_PAGE": "handle"])

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.appendingPathComponent("a.spot").path))
        try await wait("the sheet behind") { self.model.flow.current == FlowSheet(spot: "b") }
    }

    func testAPushOfAPublishPageFromACallerPublishesNothing() async throws {
        try FileManager.default.createDirectory(at: core.appendingPathComponent("openspot.spot"), withIntermediateDirectories: true)
        await model.reload()
        try "Does a.".write(to: spots.appendingPathComponent("a.spot/readme.md"), atomically: true, encoding: .utf8)

        model.push(FlowSheet(spot: AccountSheet.id, page: "publish:a"))
        _ = try await model.runs.answer(of: model.account.spot, SpotAction(arguments: ["new"]), limit: 60, variables: ["OPENSPOT_PAGE": "publish:a"])
        _ = try await model.runs.answer(of: model.account.spot, SpotAction(arguments: ["create"]), input: "handle=tony\n", limit: 60, variables: ["OPENSPOT_PAGE": "publish:a"])

        XCTAssertNotNil(try model.files.account.key())
        XCTAssertNotEqual(model.flow.current?.page, "publish:a")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.appendingPathComponent("a.spot").path))
        XCTAssertEqual(host.asked, [])
    }

    func testAPublishThatWaitsIsForgottenWhenItsSheetsClose() async throws {
        try FileManager.default.createDirectory(at: core.appendingPathComponent("openspot.spot"), withIntermediateDirectories: true)
        await model.reload()
        try "Does a.".write(to: spots.appendingPathComponent("a.spot/readme.md"), atomically: true, encoding: .utf8)
        _ = await model.publish("a")

        model.open(AccountSheet.id)
        _ = try await model.runs.answer(of: model.account.spot, SpotAction(arguments: ["new"]), limit: 60)
        _ = try await model.runs.answer(of: model.account.spot, SpotAction(arguments: ["create"]), input: "handle=tony\n", limit: 60)

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

    func testTheMinusTurnsASpotOfTheSpotsFolderOffAndItStaysOff() async {
        model.turnOff("a")

        XCTAssertEqual(order, ["b", "c", "d"])
        XCTAssertEqual(offInConfig, ["a"])
        let shown = await savedOrder()
        XCTAssertEqual(shown, ["b", "c", "d"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.spotFile("a").path))
    }

    func testACoreSpotTurnedOnByTheConfigTurnsOffByTheMinus() async throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"))
        try model.files.config.turn("timer", on: true)
        await model.reload()
        XCTAssertTrue(order.contains("timer"))

        model.turnOff("timer")

        XCTAssertFalse(order.contains("timer"))
        XCTAssertFalse(try model.files.config.read().arrangement.enabled.contains("timer"))
    }

    func testACardReleasedOverTheStoresWindowTurnsItsSpotOff() {
        let translation = move("a", to: leftHalf(of: "b"))
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

        model.dragSpot("d", by: move("d", to: leftHalf(of: "c")))
        model.resizeSpot("c", by: down)

        XCTAssertNil(model.drag)
        XCTAssertNil(model.resize)
        XCTAssertEqual(order, ["a", "b", "c", "d"])
        XCTAssertEqual(model.placements[2].size, .wide)
    }
}
