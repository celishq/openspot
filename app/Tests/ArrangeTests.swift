import XCTest
@testable import OpenspotCore

@MainActor
final class ArrangeTests: PanelCase {
    private var order: [String] {
        model.visible.map(\.id)
    }

    private var shelf: [String] {
        model.shelf.map(\.id)
    }

    private func place(of id: String) -> SpotPlacement? {
        model.visible.firstIndex { $0.id == id }.map { model.placements[$0] }
    }

    private func point(of cell: GridCell) -> CGPoint {
        let rect = SpotPlacement(index: 0, row: cell.row, column: cell.column, size: .small).rect
        let origin = SpotTokens.gridOrigin()
        return CGPoint(x: origin.x + rect.minX, y: origin.y + rect.minY)
    }


    private func toward(_ cell: GridCell, of id: String = "zeta") -> CGSize {
        let start = model.shelfOrigin(of: id) ?? .zero
        let target = point(of: cell)
        return CGSize(width: target.x - start.x, height: target.y - start.y)
    }

    private func spots(_ names: [String], title: (String) -> String = { $0.capitalized }) async throws {
        for name in names { try script(name, toml: "title = '\(title(name))'", "") }
        await model.reload()
    }

    private func arrangeWithOff(_ off: [String], on: [String]) async throws {
        model.dragRest = .zero
        try await spots(off + on)
        for id in off { model.takeOffGrid(id) }
        model.placeShelf(screen: CGSize(width: 1440, height: 900), panelOrigin: CGPoint(x: 520, y: 40))
        model.beginEditing()
    }

    func testArrangeListsYourSpotsOffTheGridByName() async throws {
        try await arrangeWithOff(["zeta", "alpha", "mango"], on: ["a", "b"])

        XCTAssertTrue(model.isArranging)
        XCTAssertEqual(Set(order), ["a", "b"])
        XCTAssertEqual(model.offGrid.map(\.id), ["alpha", "mango", "zeta"])
        XCTAssertEqual(shelf, ["alpha", "mango", "zeta"])
    }

    func testTypingKeepsOnlyTheMatchesInTheSameOrder() async throws {
        try await arrangeWithOff(["snooze", "tabs", "snoozetab", "notes"], on: ["a"])

        model.searchShelf("sn")

        XCTAssertEqual(model.shelfQuery, "sn")
        XCTAssertEqual(shelf, ["snooze", "snoozetab"])
        model.searchShelf("")
        XCTAssertEqual(shelf, ["notes", "snooze", "snoozetab", "tabs"])
    }

    func testArrangeOpensFromGridEditAndEscapeEndsIt() async throws {
        try await spots(["a"])

        model.editGrid()
        XCTAssertTrue(model.isArranging)
        XCTAssertFalse(model.handleKey(ActionKey(name: "s")))
        XCTAssertFalse(model.handleKey(ActionKey(name: "left")))
        model.searchShelf("x")

        XCTAssertTrue(model.handleKey(escape))
        XCTAssertFalse(model.isEditing)
        XCTAssertEqual(model.shelfQuery, "")
        XCTAssertEqual(host.arranged, [true, false])
    }

    func testASpotDraggedOntoAFreeSlotIsPinnedThereInTheSizeOfTheSlot() async throws {
        try await arrangeWithOff(["zeta"], on: ["a"])
        let slot = GridCell(row: 0, column: 3)

        model.dragShelfSpot("zeta", by: toward(slot))

        XCTAssertEqual(model.carry?.entry.id, "zeta")
        XCTAssertEqual(model.carry?.size, .small)
        XCTAssertEqual(model.pin?.target, .slot(slot, .small))

        model.dropShelfSpot(by: toward(slot))

        XCTAssertNil(model.pin)
        XCTAssertEqual(place(of: "zeta")?.cell, slot)
        XCTAssertEqual(place(of: "zeta")?.size, .small)
        XCTAssertEqual(place(of: "a")?.cell, GridCell(row: 0, column: 0))
        XCTAssertEqual(shelf, [])
        XCTAssertEqual(model.files.config.read().arrangement.isOnGrid(of: "zeta"), true)
    }

    func testASpotOverTheShelfKeepsItsOwnSizeAndADropThereLeavesItOff() async throws {
        try await arrangeWithOff(["zeta"], on: ["a"])

        model.dragShelfSpot("zeta", by: CGSize(width: 10, height: 10))

        XCTAssertNil(model.pin?.target)
        XCTAssertEqual(model.carry?.size, .wide)

        model.dropShelfSpot(by: CGSize(width: 10, height: 10))

        XCTAssertNil(model.pin)
        XCTAssertEqual(order, ["a"])
        XCTAssertEqual(shelf, ["zeta"])
    }

    func testASpotDraggedOverACardPushesItAsideAndTheDropKeepsBoth() async throws {
        try await arrangeWithOff(["zeta"], on: ["a", "b"])
        let cell = try XCTUnwrap(place(of: "b")).cell

        model.dragShelfSpot("zeta", by: toward(cell))

        XCTAssertEqual(model.pin?.target, .slot(cell, .wide))
        XCTAssertNotEqual(place(of: "b")?.cell, cell)
        XCTAssertEqual(model.pin?.landing, SpotPlacement(index: 0, row: cell.row, column: cell.column, size: .wide).rect)

        model.dropShelfSpot(by: toward(cell))

        XCTAssertEqual(Set(order), ["a", "b", "zeta"])
        XCTAssertEqual(place(of: "zeta")?.cell, cell)
        XCTAssertNotEqual(place(of: "b")?.cell, cell)
        XCTAssertEqual(shelf, [])
        XCTAssertNotEqual(model.files.config.read().arrangement.isOnGrid(of: "b"), false)
    }

    func testAfterAPinAndAResizeTheNextSpotStillDragsIn() async throws {
        try await arrangeWithOff(["yak", "zeta"], on: ["a"])
        let slot = GridCell(row: 1, column: 0)
        model.dragShelfSpot("zeta", by: toward(slot))
        model.dropShelfSpot(by: toward(slot))
        try await wait("zeta lands", until: { model.landing == nil && model.carry == nil })

        model.resizeSpot("zeta", by: CGSize(width: -SpotTokens.cell, height: 0))
        model.dropResize()
        XCTAssertEqual(place(of: "zeta")?.size, .small)
        try await wait("the resize lands", until: { model.gesture == nil && model.landing == nil && model.carry == nil })

        model.dragShelfSpot("yak", by: toward(GridCell(row: 2, column: 0), of: "yak"))
        XCTAssertEqual(model.pin?.id, "yak")
        XCTAssertNotNil(model.pin?.target)
        model.dropShelfSpot(by: toward(GridCell(row: 2, column: 0), of: "yak"))
        XCTAssertTrue(order.contains("yak"))

        model.dragSpot("zeta", by: CGSize(width: SpotTokens.cell * 2, height: 0))
        XCTAssertEqual(model.drag?.id, "zeta")
    }

    func testTheCardsGiveWayOnlyOnceThePointerRests() async throws {
        try await arrangeWithOff(["zeta"], on: ["a", "b"])
        model.dragRest = .seconds(30)
        let cell = try XCTUnwrap(place(of: "b")).cell

        model.dragShelfSpot("zeta", by: toward(cell))
        model.dragShelfSpot("zeta", by: toward(GridCell(row: 0, column: 0)))
        model.dragShelfSpot("zeta", by: toward(cell))

        XCTAssertEqual(place(of: "b")?.cell, cell)
        model.dropShelfSpot(by: toward(cell))

        XCTAssertEqual(place(of: "zeta")?.cell, cell)
        XCTAssertNotEqual(place(of: "b")?.cell, cell)
    }

    func testADragThatLeavesTheGridPutsThePushedCardsBack() async throws {
        try await arrangeWithOff(["zeta"], on: ["a", "b"])
        let cell = try XCTUnwrap(place(of: "b")).cell

        model.dragShelfSpot("zeta", by: toward(cell))
        model.dragShelfSpot("zeta", by: CGSize(width: 10, height: 10))

        XCTAssertNil(model.pin?.target)
        XCTAssertEqual(place(of: "b")?.cell, cell)
    }

    func testACardDraggedOffTheGridInArrangeGoesOffTheGrid() async throws {
        try await arrangeWithOff([], on: ["a", "b"])
        let away = CGSize(width: -900, height: 40)

        model.dragSpot("a", by: away)
        XCTAssertEqual(model.lift.offset, away)
        model.dropSpot(by: away)

        XCTAssertEqual(order, ["b"])
        XCTAssertEqual(shelf, ["a"])
    }

    func testACardDroppedOutsideThePanelFliesIntoItsShelfSlotNotBackToTheGrid() async throws {
        try await arrangeWithOff([], on: ["a", "b"])
        let away = CGSize(width: -900, height: 40)
        model.dragSpot("a", by: away)
        host.heldEnds = []

        model.dropSpot(by: away)

        XCTAssertEqual(order, ["b"])
        XCTAssertEqual(model.landing, "a")
        XCTAssertEqual(model.carry?.isLanding, true)
        XCTAssertEqual(model.lift.origin, model.shelfOrigin(of: "a"))

        host.heldEnds?.forEach { $0() }

        XCTAssertNil(model.landing)
        XCTAssertNil(model.carry)
    }

    func testAShelfSpotDroppedOnTheShelfFliesIntoItsNewSlot() async throws {
        try await arrangeWithOff(["alpha", "zeta"], on: ["a"])
        let alpha = try XCTUnwrap(model.shelfOrigin(of: "alpha"))
        let zeta = try XCTUnwrap(model.shelfOrigin(of: "zeta"))
        let move = CGSize(width: alpha.x - zeta.x, height: alpha.y - zeta.y)
        model.dragShelfSpot("zeta", by: move)
        host.heldEnds = []

        model.dropShelfSpot(by: move)

        XCTAssertNil(model.pin)
        XCTAssertEqual(model.landing, "zeta")
        XCTAssertEqual(model.carry?.isLanding, true)
        XCTAssertEqual(model.lift.origin, alpha)

        host.heldEnds?.forEach { $0() }

        XCTAssertNil(model.landing)
        XCTAssertNil(model.carry)
    }

    func testAnAppSpotDraggedOutsideThePanelInArrangeGoesToTheShelf() async throws {
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("openspot.spot/new.sh"), toml: "title = 'New spot'")
        try await arrangeWithOff([], on: ["a"])
        let id = try XCTUnwrap(model.visible.first { $0.spot.name == "New spot" }?.id)
        let away = CGSize(width: -900, height: 40)

        model.dragSpot(id, by: away)
        model.dropSpot(by: away)

        XCTAssertFalse(order.contains(id))
        XCTAssertEqual(shelf, [id])
    }

    private func away(_ id: String, to target: CGPoint) throws -> CGSize {
        let index = try XCTUnwrap(model.visible.firstIndex { $0.id == id })
        let rect = model.placements[index].rect
        let origin = SpotTokens.gridOrigin()
        return CGSize(width: target.x - origin.x - rect.minX, height: target.y - origin.y - rect.minY)
    }

    func testAPinnedShelfSpotLeavesItsSlotAndTheOthersHoldStill() async throws {
        try await arrangeWithOff(["alpha", "mango", "zeta"], on: ["a"])
        let alpha = model.shelfOrigin(of: "alpha")
        let zeta = model.shelfOrigin(of: "zeta")

        model.pin("mango")

        XCTAssertEqual(shelf, ["alpha", "zeta"])
        XCTAssertEqual(model.shelfOrigin(of: "alpha"), alpha)
        XCTAssertEqual(model.shelfOrigin(of: "zeta"), zeta)
    }

    func testACardDroppedOnTheShelfTakesTheSlotUnderItAndShiftsOnlyWhatIsInItsWay() async throws {
        try await arrangeWithOff(["alpha", "mango", "zeta"], on: ["a", "b"])
        let alpha = try XCTUnwrap(model.shelfOrigin(of: "alpha"))
        let mango = model.shelfOrigin(of: "mango")
        let move = try away("b", to: alpha)

        model.dragSpot("b", by: move)
        model.dropSpot(by: move)

        XCTAssertEqual(order, ["a"])
        XCTAssertEqual(model.shelfOrigin(of: "b"), alpha)
        XCTAssertNotEqual(model.shelfOrigin(of: "alpha"), alpha)
        XCTAssertEqual(model.shelfOrigin(of: "mango"), mango)
    }

    func testACardDroppedPastTheEndOfASideFallsToItsEnd() async throws {
        try await arrangeWithOff(["alpha"], on: ["a", "b"])
        let alpha = try XCTUnwrap(model.shelfOrigin(of: "alpha"))
        let move = try away("b", to: CGPoint(x: alpha.x, y: alpha.y + 600))

        model.dragSpot("b", by: move)
        model.dropSpot(by: move)

        let b = try XCTUnwrap(model.shelfOrigin(of: "b"))
        XCTAssertEqual(model.shelfOrigin(of: "alpha"), alpha)
        XCTAssertLessThan(b.y, alpha.y + 600)
        XCTAssertGreaterThan(b.y, alpha.y)
    }

    func testAShelfSpotDroppedOnTheShelfMovesToTheSlotUnderIt() async throws {
        try await arrangeWithOff(["alpha", "mango", "zeta"], on: ["a"])
        let alpha = try XCTUnwrap(model.shelfOrigin(of: "alpha"))
        let zeta = try XCTUnwrap(model.shelfOrigin(of: "zeta"))
        let move = CGSize(width: alpha.x - zeta.x, height: alpha.y - zeta.y)

        model.dragShelfSpot("zeta", by: move)
        model.dropShelfSpot(by: move)

        XCTAssertNil(model.pin)
        XCTAssertEqual(model.shelfOrigin(of: "zeta"), alpha)
        XCTAssertNotEqual(model.shelfOrigin(of: "alpha"), alpha)
    }

    func testReopeningArrangePacksTheShelfByNameAgain() async throws {
        try await arrangeWithOff(["alpha", "mango", "zeta"], on: ["a"])
        let alpha = model.shelfOrigin(of: "alpha")
        let mango = model.shelfOrigin(of: "mango")
        model.pin("alpha")
        XCTAssertNotEqual(model.shelfOrigin(of: "mango"), alpha)

        model.endEditing()
        model.beginEditing()

        XCTAssertEqual(shelf, ["mango", "zeta"])
        XCTAssertEqual(model.shelfOrigin(of: "mango"), alpha)
        XCTAssertNotEqual(model.shelfOrigin(of: "mango"), mango)
    }

    func testASpotTakenOffByItsMinusComesBackByAPin() async throws {
        try await spots(["a", "b"])
        model.takeOffGrid("a")
        XCTAssertEqual(order, ["b"])

        XCTAssertEqual(model.pin("a"), .pinned(GridCell(row: 0, column: 2)))

        XCTAssertEqual(Set(order), ["a", "b"])
        XCTAssertEqual(model.offGrid.map(\.id), [])
        XCTAssertEqual(model.pin("a"), .onGrid)
        XCTAssertEqual(model.pin("nope"), .unknown)
    }

    func testAPinIntoAFullGridFindsNoSlotAndTheSpotWithNoRoomCountsAsOff() async throws {
        let names = (1...15).map { String(format: "s%02d", $0) }
        try await spots(names)
        XCTAssertEqual(order.count, 14)
        let left = try XCTUnwrap(model.offGrid.first?.id)

        XCTAssertEqual(model.offGrid.count, 1)
        XCTAssertEqual(model.pin(left), .full)
    }

    func testAFullGridSwapsTheCardUnderTheDropUnlessItCannotLeave() {
        let grid = GridLayout(columns: 4, rows: 1)
        let cards = [SpotPlacement(index: 0, row: 0, column: 0, size: .wide), SpotPlacement(index: 1, row: 0, column: 2, size: .wide)]
        let pin = SpotPin(id: "zeta", start: .zero, size: .wide, choices: SpotSize.all, grid: grid, placements: cards, ids: [nil, "b"])

        XCTAssertNil(pin.moved(by: .zero).target)
        XCTAssertEqual(pin.moved(by: CGSize(width: cards[1].rect.minX, height: 0)).target, .swap("b", GridCell(row: 0, column: 2), .wide))
        XCTAssertEqual(pin.moved(by: CGSize(width: cards[1].rect.minX, height: 0)).layout, cards)
    }

    func testAPinThatFitsPushesTheCardsAsTheHeldDragDoes() {
        let grid = GridLayout(columns: 4, rows: 2)
        let card = SpotPlacement(index: 0, row: 0, column: 0, size: .wide)
        let pin = SpotPin(id: "zeta", start: .zero, size: .wide, choices: SpotSize.all, grid: grid, placements: [card], ids: [nil])

        let moved = pin.moved(by: .zero)

        XCTAssertEqual(moved.target, .slot(GridCell(row: 0, column: 0), .wide))
        XCTAssertEqual(moved.layout, [SpotPlacement(index: 0, row: 0, column: 2, size: .wide)])
    }
}
