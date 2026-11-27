import XCTest
@testable import OpenspotCore

@MainActor
final class ArrangeHoldTests: PanelCase {
    private var order: [String] {
        model.visible.map(\.id)
    }

    private var reading: [String] {
        zip(model.visible, model.placements).sorted { ($0.1.cell.row, $0.1.cell.column) < ($1.1.cell.row, $1.1.cell.column) }.map(\.0.id)
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

    func testGridTopPutsASpotFirstAndTheOthersMoveAlong() async throws {
        try await spots(["a", "b", "c"], off: ["d"])
        takeCalls()

        let onGrid = try await call(["grid", "top", "c"])
        XCTAssertEqual(onGrid.output, "C is at the top of the grid.\n", onGrid.errors)
        XCTAssertEqual(reading, ["c", "a", "b"])

        let offGrid = try await call(["grid", "top", "d"])
        XCTAssertEqual(offGrid.code, 0, offGrid.errors)
        XCTAssertEqual(reading, ["d", "c", "a", "b"])

        let gone = try await call(["grid", "top", "nope"])
        XCTAssertEqual(gone.code, 1)
        XCTAssertEqual(gone.errors, "You have no spot `nope` to put on top. Run `openspot grid list` to see each one.\n")
    }

    func testGridTopOnAFullGridMovesTheLastSpotsOffIt() async throws {
        try await spots((0..<40).map { "s\($0)" }, off: ["z"])
        takeCalls()
        let full = model.visible.map(\.id)

        let topped = try await call(["grid", "top", "z"])

        XCTAssertEqual(topped.code, 0, topped.errors)
        XCTAssertEqual(reading.first, "z")
        let gone = full.filter { !self.model.visible.map(\.id).contains($0) }
        XCTAssertFalse(gone.isEmpty)
        XCTAssertTrue(topped.output.hasPrefix("Z is at the top of the grid. Moved "), topped.output)
        XCTAssertTrue(gone.allSatisfy { topped.output.contains($0.capitalized) }, topped.output)
    }
}
