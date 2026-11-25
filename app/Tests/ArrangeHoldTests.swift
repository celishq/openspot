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
