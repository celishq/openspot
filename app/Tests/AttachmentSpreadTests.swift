import XCTest
@testable import OpenspotCore

@MainActor
final class AttachmentSpreadTests: AttachmentCase {
    private let tab = ActionKey(name: "tab")

    private func openWithTwoChips() async throws {
        try taker("keep", takes: "'url'")
        try taker("reader", takes: "'text'")
        try source(adds: "url=https://example.com/a title=A")
        try source("selection", adds: "text=hola app=com.apple.Safari")
        await open()
        try await wait("two values") { self.model.attachments.chips.count == 2 && self.model.attachments.chips.allSatisfy { $0.value != nil } }
    }

    private var spread: AttachmentLayout {
        model.attachments.layout
    }

    func testTabSpreadsTheStackIntoARowWithTheSelectedChipMarked() async throws {
        try await openWithTwoChips()
        XCTAssertFalse(spread.isSpread)

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertTrue(spread.isSpread)
        XCTAssertEqual(model.attachmentShape, .spread)
        XCTAssertEqual(spread.selection, model.attachments.selected)
        XCTAssertEqual(spread.places.map(\.chip.source), model.attachments.chips.map(\.source))
        XCTAssertEqual(spread.places.map(\.slot), [0, 1])
        XCTAssertTrue(model.handleKey(escape))
    }

    func testEachChipKeepsThePlaceWhereItFirstShowsWhicheverValueArrivesFirst() {
        let safari = FrontApp(bundleID: "com.apple.Safari")
        for late in [["x", "y"], ["y", "x"]] {
            var stack = AttachmentStack(fit: 6)
            stack.open(over: safari, unread: [("a", nil), ("b", nil)])
            let values = ["a": AttachmentValue(url: "https://a.com"), "b": AttachmentValue(text: "b", app: "com.apple.Safari"), "x": AttachmentValue(url: "https://x.com"), "y": AttachmentValue(text: "y", app: "com.apple.Safari")]
            for source in ["b", "a"] + late { stack.fill(source, with: values[source]!, look: nil) }
            let order = ["a", "b"] + late

            XCTAssertEqual(stack.chips.map(\.source), order)
            XCTAssertEqual(stack.layout.places.map(\.chip.source), ["a", "b"])
            stack.place(spreads: false)
            XCTAssertEqual(stack.layout.places.map(\.chip.source), order)
            stack.turn(by: 1)
            XCTAssertEqual(stack.selected, "a")
            stack.place(spreads: true)
            XCTAssertEqual(stack.layout.places.map(\.chip.source), order)
            stack.turn(by: 1)
            stack.place(spreads: false)
            stack.leave()
            stack.place(spreads: false)
            XCTAssertEqual(stack.layout.places.map(\.chip.source), order)
            stack.turn(by: 1)
            stack.place(spreads: true)
            XCTAssertEqual(stack.layout.places.map(\.chip.source), order)
        }
    }

    func testTheFirstTabRingsTheFrontTileAndLeavesItInPlace() async throws {
        try await openWithTwoChips()
        let stack = spread.places.map(\.chip.source)

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(model.attachments.selected, stack.first)
        XCTAssertEqual(spread.places.map(\.chip.source), stack)
        XCTAssertEqual(spread.places.map(\.slot), [0, 1])
    }

    func testTabMovesTheRingToTheNextTileOfTheStack() async throws {
        try await openWithTwoChips()
        let stack = spread.places.map(\.chip.source)

        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(model.attachments.selected, stack.last)
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
        try await wait("three values") { self.model.attachments.chips.count == 3 && self.model.attachments.chips.allSatisfy { $0.value != nil } }

        let kinds = Dictionary(uniqueKeysWithValues: spread.places.map { ($0.chip.source, $0.chip.showsKind) })

        XCTAssertEqual(kinds, ["tab": true, "selection": true, "finder": false])
    }

    func testTheRowFoldsAfterAPauseWithTheSelectionInFront() async throws {
        try await openWithTwoChips()
        model.attachmentPause = .milliseconds(50)

        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the fold") { !self.spread.isSpread }

        XCTAssertEqual(spread.places.first?.chip.source, model.attachments.selected)
        XCTAssertEqual(spread.places.map(\.depth), [0, 1])
        XCTAssertEqual(model.attachmentShape, .folded)
        XCTAssertTrue(model.attachments.isOn)
    }

    func testEscFoldsTheRowAtOnce() async throws {
        try await openWithTwoChips()
        XCTAssertTrue(model.handleKey(tab))

        XCTAssertTrue(model.handleKey(escape))

        XCTAssertFalse(spread.isSpread)
        XCTAssertNil(spread.selection)
        XCTAssertNil(model.attachmentWatch)
    }

    func testAClosedPanelStopsThePauseAndTheNextOpenFoldsTheRow() async throws {
        try await openWithTwoChips()
        XCTAssertTrue(model.handleKey(tab))

        model.panelWillHide()
        XCTAssertNil(model.attachmentWatch)
        model.panelDidHide()
        model.panelWillShow()

        XCTAssertFalse(spread.isSpread)
    }

    func testAPanelThatHidesAfterEscKeepsItsCardsWhereTheyLie() async throws {
        try await openWithTwoChips()
        model.attachmentPause = .milliseconds(50)
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
        XCTAssertNotEqual(model.attachmentShape, .wide)

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(spread.spreadCount, SpotTokens.attachmentFit)
        XCTAssertGreaterThan(spread.spreadCount, AttachmentStack.pile)
        XCTAssertEqual(spread.places.filter { $0.depth == 0 }.map(\.slot), Array(0..<SpotTokens.attachmentFit))
        XCTAssertEqual(model.attachmentShape, .wide)
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertNotEqual(model.attachmentShape, .wide)
    }

    func testARowNarrowerThanTheChipsShiftsWithTheSelection() {
        let sources = ["a", "b", "c", "d", "e"]
        var stack = AttachmentStack(fit: 3)
        stack.open(over: nil, unread: sources.map { ($0, .symbol("doc")) })
        for source in sources { stack.fill(source, with: AttachmentValue(text: source), look: .symbol("doc")) }
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

    func testAStackWithNoChoiceShowsOnlyItsFrontIconQuietly() {
        var stack = AttachmentStack(fit: 3)
        stack.open(over: nil, unread: ["a", "b", "c"].map { ($0, .symbol("doc")) })

        XCTAssertTrue(stack.layout.isQuiet)
        XCTAssertTrue(stack.layout.showsHint)
        XCTAssertEqual(stack.layout.places.map(\.isQuiet), [true, true, true])
        XCTAssertEqual(stack.layout.places.map(\.x), Array(repeating: SpotTokens.attachmentQuietX, count: 3))
        XCTAssertEqual(stack.layout.places.map(\.scale), Array(repeating: SpotTokens.attachmentQuietScale, count: 3))
        XCTAssertEqual(stack.layout.places.map(\.opacity), [1, MotionTokens.hiddenOpacity, MotionTokens.hiddenOpacity])

        stack.turn(by: 1)
        stack.place(spreads: true)

        XCTAssertFalse(stack.layout.isQuiet)
        XCTAssertEqual(stack.layout.places.map(\.isQuiet), [false, false, false])
    }

    func testTheIconsSitAsFarFromTheFieldsRightEdgeAsFromItsTopAndBottom() {
        let quietRight = SpotTokens.attachmentEdge - SpotTokens.attachmentQuietX + SpotTokens.attachmentInset * SpotTokens.attachmentQuietScale

        XCTAssertEqual(quietRight, (SpotTokens.cell - SpotTokens.attachmentQuietIcon) / 2, accuracy: 0.001)
        XCTAssertEqual(SpotTokens.attachmentEdge, (SpotTokens.cell - SpotTokens.attachmentCard) / 2)
    }

    func testAChipThatReadsShowsTheIconOfItsApp() {
        let safari = FrontApp(bundleID: "com.apple.Safari", path: "/Applications/Safari.app")
        var stack = AttachmentStack(fit: 3)
        stack.open(over: safari, unread: [("lazy", .symbol("globe"))])
        stack.mark("lazy", .loading)

        XCTAssertEqual(stack.chips.map(\.isLoading), [true])
        XCTAssertEqual(stack.chips.map(\.look), [.file(FileIcon(path: "/Applications/Safari.app"))])
    }

    func testAStackAtRestPilesItsCardsSmallerAndFurtherRightBehindTheFront() {
        let sources = ["a", "b", "c", "d"]
        var stack = AttachmentStack(fit: 3)
        stack.open(over: nil, unread: sources.map { ($0, .symbol("doc")) })
        stack.turn(by: 1)
        stack.place(spreads: false)
        let step = SpotTokens.attachmentStep
        let shrink = SpotTokens.attachmentShrink

        XCTAssertEqual(stack.layout.places.map(\.x), [-2 * step, -step, 0, 0])
        XCTAssertEqual(stack.layout.places.map(\.scale), [1, 1 - shrink, 1 - 2 * shrink, 1 - 2 * shrink])
        XCTAssertEqual(stack.layout.places.map(\.opacity), [1, 1, 1, MotionTokens.hiddenOpacity])
        XCTAssertEqual(stack.layout.places.map(\.layer), [0, -1, -2, -3])
    }

    func testASpreadRowLaysItsCardsOnePitchApartWithTheRestBehindItsFirst() {
        let sources = ["a", "b", "c", "d", "e"]
        var stack = AttachmentStack(fit: 3)
        stack.open(over: nil, unread: sources.map { ($0, .symbol("doc")) })
        stack.turn(by: 1)
        stack.place(spreads: true)
        let pitch = SpotTokens.attachmentCard + SpotTokens.attachmentSpreadGap
        let step = SpotTokens.attachmentStep

        XCTAssertEqual(stack.layout.places.map(\.x), [-2 * pitch, -pitch, 0, -2 * pitch + step, -2 * pitch + step])
        XCTAssertEqual(stack.layout.places.map(\.scale), [1, 1, 1, 1 - SpotTokens.attachmentShrink, 1 - SpotTokens.attachmentShrink])
        XCTAssertEqual(stack.layout.places.map(\.opacity), [1, 1, 1, 1 - SpotTokens.attachmentCardFade, MotionTokens.hiddenOpacity])
        XCTAssertEqual(stack.layout.places.map(\.layer), [0, -1, -2, -3, -6])
    }

    func testPressesDuringTheMotionFoldIntoOneStepToTheNewestState() async throws {
        try await openWithTwoChips()
        let first = spread.places[0].chip.source
        let second = spread.places[1].chip.source
        host.heldEnds = []

        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertEqual(spread.selection, first)
        XCTAssertEqual(model.attachments.selected, second)

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
