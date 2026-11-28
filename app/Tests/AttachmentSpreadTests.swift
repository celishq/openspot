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
        XCTAssertFalse(model.isFieldCovered)
        XCTAssertEqual(spread.selection, model.attachments.selected)
        XCTAssertEqual(spread.places.map(\.chip.source), model.attachments.chips.map(\.source))
        XCTAssertLessThan(spread.places[0].x, spread.places[1].x)
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
            stack.fold()
            stack.place()
            XCTAssertEqual(stack.layout.places.map(\.chip.source), order)
            stack.turn(by: 1)
            XCTAssertEqual(stack.selected, "a")
            stack.spread()
            stack.place()
            XCTAssertEqual(stack.layout.places.map(\.chip.source), order)
            stack.turn(by: 1)
            stack.fold()
            stack.place()
            stack.leave()
            stack.fold()
            stack.place()
            XCTAssertEqual(stack.layout.places.map(\.chip.source), ["b"] + late + ["a"])
            stack.turn(by: 1)
            stack.spread()
            stack.place()
            XCTAssertEqual(stack.layout.places.map(\.chip.source), ["b"] + late + ["a"])
        }
    }

    func testTheFirstTabRingsTheFrontTileAndLeavesItInPlace() async throws {
        try await openWithTwoChips()
        let stack = spread.places.map(\.chip.source)

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(model.attachments.selected, stack.first)
        XCTAssertEqual(spread.places.map(\.chip.source), stack)
        XCTAssertLessThan(spread.places[0].x, spread.places[1].x)
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
        model.attachments.pause = .milliseconds(50)

        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(tab))
        try await wait("the fold") { !self.spread.isSpread }

        XCTAssertEqual(spread.places.first?.chip.source, model.attachments.selected)
        XCTAssertEqual(spread.places.map(\.depth), [0, 1])
        XCTAssertFalse(model.isFieldCovered)
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

    func testEscOnTheSecondChipKeepsItInFrontAndTheNextTabStartsFromIt() async throws {
        try await openWithTwoChips()
        let second = model.attachments.chips[1].source
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertEqual(model.attachments.selected, second)

        XCTAssertTrue(model.handleKey(escape))

        XCTAssertNil(model.attachments.selected)
        XCTAssertEqual(spread.places.first?.chip.source, second)
        XCTAssertEqual(spread.places.first?.opacity, 1)
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertEqual(model.attachments.selected, second)
        XCTAssertEqual(spread.places.map(\.chip.source), model.attachments.chips.map(\.source).reversed())
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
        model.attachments.pause = .milliseconds(50)
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
        XCTAssertFalse(model.isFieldCovered)

        XCTAssertTrue(model.handleKey(tab))

        XCTAssertEqual(spread.spreadCount, SpotTokens.attachmentFit)
        XCTAssertGreaterThan(spread.spreadCount, AttachmentStack.pile)
        XCTAssertEqual(spread.places.filter { $0.depth == 0 }.count, SpotTokens.attachmentFit)
        XCTAssertTrue(model.isFieldCovered)
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertFalse(model.isFieldCovered)
    }

    func testARowNarrowerThanTheChipsShiftsOnlyWhenTheRingLeavesIt() {
        let sources = ["a", "b", "c", "d", "e"]
        var stack = AttachmentStack(fit: 3)
        stack.open(over: nil, unread: sources.map { ($0, .symbol("doc")) })
        for source in sources { stack.fill(source, with: AttachmentValue(text: source), look: .symbol("doc")) }
        let row = { stack.layout.places.filter { $0.depth == 0 }.sorted { $0.x < $1.x }.map(\.chip.source) }

        for _ in 0..<4 {
            stack.turn(by: 1)
            stack.spread()
            stack.place()
        }

        XCTAssertEqual(row(), ["b", "c", "d"])
        for _ in 0..<2 {
            stack.turn(by: 1)
            stack.spread()
            stack.place()
        }
        XCTAssertEqual(row(), ["d", "e", "a"])
    }

    func testAStackWithNoChoiceShowsOnlyItsFrontIconQuietly() {
        var stack = AttachmentStack(fit: 3)
        stack.open(over: nil, unread: ["a", "b", "c"].map { ($0, .symbol("doc")) })

        XCTAssertTrue(stack.layout.isQuiet)
        XCTAssertEqual(stack.layout.places.map(\.x), [0, 0, 0])
        XCTAssertEqual(stack.layout.places.map(\.scale), Array(repeating: SpotTokens.attachmentQuietScale, count: 3))
        XCTAssertEqual(stack.layout.places.map(\.opacity), [1, MotionTokens.hiddenOpacity, MotionTokens.hiddenOpacity])

        stack.turn(by: 1)
        stack.spread()
        stack.place()

        XCTAssertFalse(stack.layout.isQuiet)
    }

    func testAChipThatOnlyChangesItsScaleKeepsItsPlace() {
        var stack = AttachmentStack(fit: 3)
        stack.open(over: nil, unread: [("a", .symbol("doc"))])
        let quiet = stack.layout.places[0]

        stack.turn(by: 1)
        stack.place()
        let selected = stack.layout.places[0]

        XCTAssertNotEqual(selected.scale, quiet.scale)
        XCTAssertEqual(selected.x, quiet.x)
    }

    func testTheIconsSitAsFarFromTheFieldsRightEdgeAsFromItsTopAndBottom() {
        var stack = AttachmentStack(fit: 3)
        stack.open(over: nil, unread: [("a", .symbol("doc"))])
        let quiet = stack.layout.places[0]
        let quietRight = SpotTokens.attachmentEdge + (SpotTokens.attachmentCard - SpotTokens.attachmentIcon * quiet.scale) / 2 - quiet.x

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
        stack.fold()
        stack.place()
        let step = SpotTokens.attachmentStep
        let shrink = SpotTokens.attachmentShrink

        let card = SpotTokens.attachmentCard
        let pile = [-2 * step, -step + card * shrink / 2, card * shrink, card * shrink]
        XCTAssertEqual(stack.layout.places.count, pile.count)
        for (place, x) in zip(stack.layout.places, pile) { XCTAssertEqual(place.x, x, accuracy: 0.001) }
        XCTAssertEqual(stack.layout.places.map(\.scale), [1, 1 - shrink, 1 - 2 * shrink, 1 - 2 * shrink])
        XCTAssertEqual(stack.layout.places.map(\.opacity), [1, 1, 1, MotionTokens.hiddenOpacity])
        XCTAssertEqual(stack.layout.places.map(\.layer), [0, -1, -2, -3])
    }

    func testASpreadRowLaysItsCardsOnePitchApartWithTheRestBehindItsLast() {
        let sources = ["a", "b", "c", "d", "e"]
        var stack = AttachmentStack(fit: 3)
        stack.open(over: nil, unread: sources.map { ($0, .symbol("doc")) })
        stack.turn(by: 1)
        stack.spread()
        stack.place()
        let pitch = SpotTokens.attachmentCard + SpotTokens.attachmentSpreadGap
        let step = SpotTokens.attachmentStep

        let back = step + SpotTokens.attachmentCard * SpotTokens.attachmentShrink / 2
        let row = [(-2 * pitch).rounded(), (-pitch).rounded(), 0, back, back]
        XCTAssertEqual(stack.layout.places.count, row.count)
        for (place, x) in zip(stack.layout.places, row) { XCTAssertEqual(place.x, x, accuracy: 0.001) }
        XCTAssertEqual(stack.layout.places.map(\.scale), [1, 1, 1, 1 - SpotTokens.attachmentShrink, 1 - SpotTokens.attachmentShrink])
        XCTAssertEqual(stack.layout.places.map(\.opacity), [1, 1, 1, 1 - SpotTokens.attachmentCardFade, MotionTokens.hiddenOpacity])
        XCTAssertEqual(stack.layout.places.map(\.layer), [0, -1, -2, -3, -4])
    }

    func testTabMovesOnlyTheRingAndTheFoldBringsTheChosenChipToTheFront() {
        var stack = AttachmentStack(fit: 6)
        stack.open(over: nil, unread: ["a", "b", "c", "d"].map { ($0, .symbol("doc")) })
        let row = { stack.layout.places.sorted { $0.x < $1.x }.map(\.chip.source) }
        let press = { (step: Int) in
            stack.turn(by: step)
            stack.spread()
            stack.place()
        }

        press(1)
        XCTAssertEqual(stack.selected, "a")
        press(1)
        XCTAssertEqual(stack.selected, "b")
        XCTAssertEqual(row(), ["a", "b", "c", "d"])

        stack.leave()
        stack.place()
        XCTAssertEqual(stack.layout.places.map(\.chip.source), ["b", "c", "d", "a"])
        XCTAssertEqual(stack.layout.places.map(\.layer), [0, -1, -2, -3])

        press(1)
        XCTAssertEqual(stack.selected, "b")
        XCTAssertEqual(row(), ["b", "c", "d", "a"])
        press(1)
        press(1)
        press(-1)
        XCTAssertEqual(stack.selected, "c")
        XCTAssertEqual(row(), ["b", "c", "d", "a"])

        stack.fold()
        stack.place()
        XCTAssertEqual(stack.layout.places.map(\.chip.source), ["c", "d", "a", "b"])
        press(1)
        XCTAssertEqual(row(), ["c", "d", "a", "b"])
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
