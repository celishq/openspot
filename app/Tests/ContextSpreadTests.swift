import XCTest
@testable import OpenspotCore

@MainActor
final class ContextSpreadTests: ContextCase {
    private let tab = ActionKey(name: "tab")

    private func openWithTwoChips() async throws {
        try taker("keep", takes: "'url'")
        try taker("reader", takes: "'text'")
        try source(adds: "url=https://example.com/a title=A")
        try source("selection", adds: "text=hola app=com.apple.Safari")
        await open()
        try await wait("two values") { self.model.context.chips.count == 2 && self.model.context.chips.allSatisfy { $0.value != nil } }
    }

    private var spread: ContextSpread {
        model.contextSpread
    }

    func testTabSpreadsTheStackIntoARowWithTheSelectedChipMarked() async throws {
        try await openWithTwoChips()
        XCTAssertFalse(spread.isSpread)

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertTrue(spread.isSpread)
        XCTAssertTrue(model.isContextSpread)
        XCTAssertEqual(spread.selected, model.context.selected)
        XCTAssertEqual(spread.places.map(\.chip.source), model.context.chips.map(\.source))
        XCTAssertEqual(spread.places.map(\.slot), [0, 1])
        XCTAssertTrue(model.handleKey(escape))
    }

    func testTheRowFoldsAfterAPauseWithTheSelectionInFront() async throws {
        try await openWithTwoChips()
        model.contextFold.pause = .milliseconds(50)

        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the fold") { !self.spread.isSpread }

        XCTAssertEqual(spread.places.first?.chip.source, model.context.selected)
        XCTAssertEqual(spread.places.map(\.depth), [0, 1])
        XCTAssertFalse(model.isContextSpread)
        XCTAssertTrue(model.context.isOn)
    }

    func testEscFoldsTheRowAtOnce() async throws {
        try await openWithTwoChips()
        XCTAssertTrue(model.handleKey(tab))

        XCTAssertTrue(model.handleKey(escape))

        XCTAssertFalse(spread.isSpread)
        XCTAssertNil(spread.selected)
        XCTAssertNil(model.contextFold.watch)
    }

    func testAClosedPanelFoldsTheRowAndStopsItsPause() async throws {
        try await openWithTwoChips()
        XCTAssertTrue(model.handleKey(tab))

        model.panelWillHide()

        XCTAssertFalse(spread.isSpread)
        XCTAssertNil(model.contextFold.watch)
    }

    func testPressesDuringTheMotionFoldIntoOneStepToTheNewestState() async throws {
        try await openWithTwoChips()
        let first = model.context.chips[0].source
        let second = model.context.chips[1].source
        host.heldEnds = []

        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertEqual(spread.selected, first)
        XCTAssertEqual(model.context.selected, second)

        let ends = host.heldEnds ?? []
        host.heldEnds = []
        ends.forEach { $0() }

        XCTAssertEqual(spread.selected, second)
        XCTAssertTrue(spread.isSpread)
        XCTAssertEqual(host.heldEnds?.count, 1)
        host.heldEnds = nil
        XCTAssertTrue(model.handleKey(escape))
    }
}
