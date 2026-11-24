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

    private var spread: ContextLayout {
        model.context.layout
    }

    func testTabSpreadsTheStackIntoARowWithTheSelectedChipMarked() async throws {
        try await openWithTwoChips()
        XCTAssertFalse(spread.isSpread)

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertTrue(spread.isSpread)
        XCTAssertEqual(model.contextShape, .spread)
        XCTAssertEqual(spread.selection, model.context.selected)
        XCTAssertEqual(spread.places.map(\.chip.source), model.context.chips.map(\.source))
        XCTAssertEqual(spread.places.map(\.slot), [0, 1])
        XCTAssertTrue(model.handleKey(escape))
    }

    func testTheFirstTabRingsTheFrontTileAndLeavesItInPlace() async throws {
        try await openWithTwoChips()
        let stack = spread.places.map(\.chip.source)

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(model.context.selected, stack.first)
        XCTAssertEqual(spread.places.map(\.chip.source), stack)
        XCTAssertEqual(spread.places.map(\.slot), [0, 1])
    }

    func testTabMovesTheRingToTheNextTileOfTheStack() async throws {
        try await openWithTwoChips()
        let stack = spread.places.map(\.chip.source)

        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(model.context.selected, stack.last)
        XCTAssertEqual(spread.places.map(\.chip.source), stack)
    }

    func testATabWhileTheRowIsSpreadMovesNothing() async throws {
        try await openWithTwoChips()
        XCTAssertTrue(model.handleKey(tab))
        let before = host.motions.count

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(host.motions[before...].compactMap { $0 }, [])
        XCTAssertTrue(spread.isSpread)
    }

    func testTheKindShowsOnlyOnTilesOfOneApp() async throws {
        try taker("keep", takes: "'url', 'text'")
        try source(adds: "url=https://example.com/a app=com.apple.Safari")
        try source("selection", adds: "text=hola app=com.apple.Safari")
        try source("finder", adds: "text=notes app=com.apple.finder")
        await open()
        try await wait("three values") { self.model.context.chips.count == 3 && self.model.context.chips.allSatisfy { $0.value != nil } }

        let kinds = Dictionary(uniqueKeysWithValues: spread.places.map { ($0.chip.source, $0.chip.showsKind) })

        XCTAssertEqual(kinds, ["tab": true, "selection": true, "finder": false])
    }

    func testTheRowFoldsAfterAPauseWithTheSelectionInFront() async throws {
        try await openWithTwoChips()
        model.contextPause = .milliseconds(50)

        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the fold") { !self.spread.isSpread }

        XCTAssertEqual(spread.places.first?.chip.source, model.context.selected)
        XCTAssertEqual(spread.places.map(\.depth), [0, 1])
        XCTAssertEqual(model.contextShape, .folded)
        XCTAssertTrue(model.context.isOn)
    }

    func testEscFoldsTheRowAtOnce() async throws {
        try await openWithTwoChips()
        XCTAssertTrue(model.handleKey(tab))

        XCTAssertTrue(model.handleKey(escape))

        XCTAssertFalse(spread.isSpread)
        XCTAssertNil(spread.selection)
        XCTAssertNil(model.contextWatch)
    }

    func testAClosedPanelStopsThePauseAndTheNextOpenFoldsTheRow() async throws {
        try await openWithTwoChips()
        XCTAssertTrue(model.handleKey(tab))

        model.panelWillHide()
        XCTAssertNil(model.contextWatch)
        model.panelDidHide()
        model.panelWillShow()

        XCTAssertFalse(spread.isSpread)
    }

    func testAPanelThatHidesAfterEscKeepsItsCardsWhereTheyLie() async throws {
        try await openWithTwoChips()
        model.contextPause = .milliseconds(50)
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the fold") { !self.spread.isSpread }
        XCTAssertTrue(model.handleKey(escape))
        let before = spread.places.map(\.chip.source)

        model.panelWillHide()

        XCTAssertEqual(spread.places.map(\.chip.source), before)
    }

    func testTabLaysEveryChipThatFitsTheFieldInOneRowAndHidesItsWords() async throws {
        try taker("keep", takes: "'text'")
        for name in ["a", "b", "c", "d", "e", "f"] {
            try source(name, adds: "text=\(name) app=com.apple.Safari")
        }
        await open()
        try await wait("six values") { self.chips.count == 6 && self.chips.allSatisfy { $0.value != nil } }
        XCTAssertNotEqual(model.contextShape, .wide)

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(spread.spreadCount, SpotTokens.contextFit)
        XCTAssertGreaterThan(spread.spreadCount, ContextStack.pile)
        XCTAssertEqual(spread.places.filter { $0.depth == 0 }.map(\.slot), Array(0..<SpotTokens.contextFit))
        XCTAssertEqual(model.contextShape, .wide)
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertNotEqual(model.contextShape, .wide)
    }

    func testARowNarrowerThanTheChipsShiftsWithTheSelection() {
        let sources = ["a", "b", "c", "d", "e"]
        var stack = ContextStack(fit: 3)
        stack.open(over: nil, loading: sources.map { ($0, .symbol("doc")) })
        for source in sources { stack.fill(source, with: ContextValue(text: source), look: .symbol("doc")) }
        let row = { stack.layout.places.filter { $0.depth == 0 }.sorted { $0.slot < $1.slot }.map(\.chip.source) }

        for _ in 0..<4 {
            stack.turn(by: 1)
            stack.place(spreads: true)
        }

        XCTAssertEqual(row(), ["b", "c", "d"])
        for _ in 0..<2 {
            stack.turn(by: 1)
            stack.place(spreads: true)
        }
        XCTAssertEqual(row(), ["a", "b", "c"])
    }

    func testAStackAtRestPilesItsCardsSmallerAndFurtherRightBehindTheFront() {
        let sources = ["a", "b", "c", "d"]
        var stack = ContextStack(fit: 3)
        stack.open(over: nil, loading: sources.map { ($0, .symbol("doc")) })
        let step = SpotTokens.contextStep
        let shrink = SpotTokens.contextShrink

        XCTAssertEqual(stack.layout.places.map(\.x), [-2 * step, -step, 0, 0])
        XCTAssertEqual(stack.layout.places.map(\.scale), [1, 1 - shrink, 1 - 2 * shrink, 1 - 2 * shrink])
        XCTAssertEqual(stack.layout.places.map(\.opacity), [1, 1, 1, MotionTokens.hiddenOpacity])
        XCTAssertEqual(stack.layout.places.map(\.layer), [0, -1, -2, -3])
    }

    func testASpreadRowLaysItsCardsOnePitchApartWithTheRestBehindItsFirst() {
        let sources = ["a", "b", "c", "d", "e"]
        var stack = ContextStack(fit: 3)
        stack.open(over: nil, loading: sources.map { ($0, .symbol("doc")) })
        stack.turn(by: 1)
        stack.place(spreads: true)
        let pitch = SpotTokens.contextCard + SpotTokens.contextSpreadGap
        let step = SpotTokens.contextStep

        XCTAssertEqual(stack.layout.places.map(\.x), [-2 * pitch, -pitch, 0, -2 * pitch + step, -2 * pitch + step])
        XCTAssertEqual(stack.layout.places.map(\.scale), [1, 1, 1, 1 - SpotTokens.contextShrink, 1 - SpotTokens.contextShrink])
        XCTAssertEqual(stack.layout.places.map(\.opacity), [1, 1, 1, 1 - SpotTokens.contextCardFade, MotionTokens.hiddenOpacity])
        XCTAssertEqual(stack.layout.places.map(\.layer), [0, -1, -2, -3, -6])
    }

    func testPressesDuringTheMotionFoldIntoOneStepToTheNewestState() async throws {
        try await openWithTwoChips()
        let first = model.context.chips[0].source
        let second = model.context.chips[1].source
        host.heldEnds = []

        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertEqual(spread.selection, first)
        XCTAssertEqual(model.context.selected, second)

        let ends = host.heldEnds ?? []
        host.heldEnds = []
        ends.forEach { $0() }

        XCTAssertEqual(spread.selection, second)
        XCTAssertTrue(spread.isSpread)
        XCTAssertEqual(host.heldEnds?.count, 1)
        host.heldEnds = nil
        XCTAssertTrue(model.handleKey(escape))
    }
}
