import XCTest
@testable import OpenspotCore

@MainActor
final class ArrangeHoldTests: PanelCase {
    private var order: [String] {
        model.visible.map(\.id)
    }

    private func holdOverTheGrid() {
        model.hold([.command])
        model.point(at: .grid(CGPoint(x: model.placements[0].rect.midX, y: model.placements[0].rect.midY)))
    }

    private func spots(_ names: [String], off: [String]) async throws {
        for name in names + off { try script(name, toml: "title = '\(name.capitalized)'", "") }
        await model.reload()
        model.isShown = true
        for id in off { model.takeOffGrid(id) }
    }

    func testAHeldCommandCountsTheSpotsOffTheGridInTheHint() async throws {
        try await spots(["a"], off: ["b", "c"])

        holdOverTheGrid()

        XCTAssertTrue(model.isEditing)
        XCTAssertTrue(model.hint.hasPrefix("2 of your spots are off the grid"), model.hint)
    }

    func testAPlusOpensAShortListThatFiltersAndReturnPinsTheChosenSpotThere() async throws {
        try await spots(["a"], off: ["snooze", "notes", "tabs"])
        holdOverTheGrid()
        let cell = GridCell(row: 2, column: 2)

        model.openSlotPick(at: cell)
        XCTAssertEqual(model.slotPick?.ids, ["notes", "snooze", "tabs"])
        model.hold([])
        XCTAssertTrue(model.isEditing)
        model.searchSlotPick("n")
        XCTAssertEqual(model.slotPick?.ids, ["notes", "snooze"])
        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))
        XCTAssertEqual(model.slotPick?.chosen, "snooze")

        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))

        XCTAssertNil(model.slotPick)
        XCTAssertFalse(model.isEditing)
        XCTAssertEqual(model.visible.firstIndex { $0.id == "snooze" }.map { model.placements[$0].cell }, cell)
    }

    func testEscapeClosesTheListAndPinsNothing() async throws {
        try await spots(["a"], off: ["b"])
        holdOverTheGrid()
        model.openSlotPick(at: GridCell(row: 3, column: 0))

        XCTAssertTrue(model.handleKey(escape))

        XCTAssertNil(model.slotPick)
        XCTAssertEqual(order, ["a"])
    }

    func testTheListShowsAtMostSixSpots() async throws {
        try await spots(["a"], off: (1...9).map { "s\($0)" })
        holdOverTheGrid()

        model.openSlotPick(at: GridCell(row: 3, column: 0))

        XCTAssertEqual(model.slotPick?.ids.count, SlotPick.limit)
    }

    private func call(_ arguments: [String]) async throws -> CommandAnswer {
        let work = try XCTUnwrap(model.runs.api?.work(for: .test(arguments), input: { "" }))
        return await work()
    }

    func testGridListPutsTheSpotsOffTheGridFirstAndGridPinTakesTheFirstFreeSlot() async throws {
        try await spots(["a", "b"], off: ["c"])
        takeCalls()

        let list = try await call(["grid", "list"])
        XCTAssertEqual(list.output.components(separatedBy: "\n").filter { $0.hasPrefix("item=") }, ["item=c", "item=a", "item=b"])
        XCTAssertTrue(list.output.contains("item=c\ntitle=C\nicon="), list.output)
        XCTAssertTrue(list.output.contains("detail=Off the grid"))

        let pin = try await call(["grid", "pin", "c"])
        XCTAssertEqual(pin.output, "C is on the grid.\n")
        XCTAssertTrue(order.contains("c"))
        let again = try await call(["grid", "pin", "c"])
        XCTAssertEqual(again.errors, "C is on the grid already.\n")
        let gone = try await call(["grid", "pin", "nope"])
        XCTAssertEqual(gone.code, 1)
    }
}
