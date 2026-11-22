import XCTest
@testable import OpenspotCore

final class BoxLayoutTests: XCTestCase {
    private func block(_ width: CGFloat, _ height: CGFloat, _ classes: String = "") -> BoxLayout.Child {
        BoxLayout.Child(style: Style(classes: classes)) { _, _ in CGSize(width: width, height: height) }
    }

    private func words(_ length: CGFloat, line: CGFloat = 10, _ classes: String = "") -> BoxLayout.Child {
        BoxLayout.Child(style: Style(classes: classes)) { width, _ in
            guard let width, width < length else { return CGSize(width: length, height: line) }
            return CGSize(width: width, height: line * (length / max(width, 1)).rounded(.up))
        }
    }

    private func place(_ classes: String, _ children: [BoxLayout.Child], width: CGFloat? = 100, height: CGFloat? = nil) -> BoxLayout.Placement {
        BoxLayout(style: Style(classes: classes)).place(children, width: width, height: height)
    }

    func testAColumnStacksItsChildrenAtTheirGapAndStretchesThem() {
        let placed = place("gap-2", [block(40, 10), block(60, 20)])

        XCTAssertEqual(placed.frames, [CGRect(x: 0, y: 0, width: 100, height: 10), CGRect(x: 0, y: 18, width: 100, height: 20)])
        XCTAssertEqual(placed.size, CGSize(width: 100, height: 38))
    }

    func testItemsCenterCentersEachChildAcrossTheColumn() {
        let placed = place("items-center", [block(40, 10), block(60, 20, "self-end")])

        XCTAssertEqual(placed.frames, [CGRect(x: 30, y: 0, width: 40, height: 10), CGRect(x: 40, y: 10, width: 60, height: 20)])
    }

    func testJustifyBetweenPutsTheLastChildOfARowAtItsEnd() {
        let placed = place("flex-row justify-between", [block(20, 10), block(30, 16)])

        XCTAssertEqual(placed.frames, [CGRect(x: 0, y: 0, width: 20, height: 16), CGRect(x: 70, y: 0, width: 30, height: 16)])
        XCTAssertEqual(placed.size, CGSize(width: 100, height: 16))
    }

    func testAGrowingChildTakesTheFreeWidthOfARow() {
        let placed = place("flex-row gap-1 items-start", [block(20, 10, "grow"), block(30, 10)])

        XCTAssertEqual(placed.frames, [CGRect(x: 0, y: 0, width: 66, height: 10), CGRect(x: 70, y: 0, width: 30, height: 10)])
    }

    func testAFractionOrAStepSetsTheWidthOfAChild() {
        let placed = place("flex-row items-start", [block(10, 10, "w-1/2"), block(10, 10, "w-10")])

        XCTAssertEqual(placed.frames.map(\.width), [50, 40])
    }

    func testARowThatOverflowsShrinksItsChildrenAndTheirWordsWrap() {
        let placed = place("flex-row items-start", [words(80), words(80), block(20, 10, "shrink-0")])

        XCTAssertEqual(placed.frames.map(\.width), [40, 40, 20])
        XCTAssertEqual(placed.frames.map(\.height), [20, 20, 10])
    }

    func testAnAbsoluteChildCoversTheBoxAndTakesNoRoom() {
        let placed = place("relative", [block(10, 10, "absolute inset-0"), block(50, 20), block(8, 8, "absolute bottom-0 right-0")])

        XCTAssertEqual(placed.size, CGSize(width: 100, height: 20))
        XCTAssertEqual(placed.frames, [
            CGRect(x: 0, y: 0, width: 100, height: 20),
            CGRect(x: 0, y: 0, width: 100, height: 20),
            CGRect(x: 92, y: 12, width: 8, height: 8)
        ])
    }

    func testAnAbsoluteChildPinsToTheOuterEdgeOfItsBoxPastItsPadding() {
        let placed = place("relative p-3", [block(50, 20), block(10, 10, "absolute inset-0"), block(8, 8, "absolute bottom-0 right-0")])

        XCTAssertEqual(placed.size, CGSize(width: 100, height: 20))
        XCTAssertEqual(placed.frames[1], CGRect(x: -12, y: -12, width: 124, height: 44))
        XCTAssertEqual(placed.frames[2], CGRect(x: 104, y: 24, width: 8, height: 8))
        let outset = BoxLayout(style: Style(classes: "relative"), outset: 4).place([block(50, 20), block(10, 10, "absolute inset-0")], width: 100, height: nil)
        XCTAssertEqual(outset.frames[1], CGRect(x: -4, y: -4, width: 108, height: 28))
    }

    func testAGridPlacesItsChildrenInEqualColumnsAndSpans() {
        let placed = place("grid grid-cols-2 gap-2", [block(10, 10, "col-span-2"), block(10, 10), block(10, 14)], width: 108)

        XCTAssertEqual(placed.frames, [
            CGRect(x: 0, y: 0, width: 108, height: 10),
            CGRect(x: 0, y: 18, width: 50, height: 14),
            CGRect(x: 58, y: 18, width: 50, height: 14)
        ])
        XCTAssertEqual(placed.size, CGSize(width: 108, height: 32))
    }

    func testAGridOfAGivenHeightSharesItsFreeHeightAmongItsRows() {
        let placed = place("grid grid-cols-2 gap-2", [block(10, 10, "row-span-2"), block(10, 10), block(10, 10)], width: 108, height: 60)

        XCTAssertEqual(placed.frames, [
            CGRect(x: 0, y: 0, width: 50, height: 60),
            CGRect(x: 58, y: 0, width: 50, height: 26),
            CGRect(x: 58, y: 34, width: 50, height: 26)
        ])
    }

    func testASquareInARowOfAGivenHeightTakesItsHeightAsItsWidth() {
        let placed = place("flex-row", [block(10, 10, "aspect-square")], width: 200, height: 60)

        XCTAssertEqual(placed.frames, [CGRect(x: 0, y: 0, width: 60, height: 60)])
    }

    func testAColumnWithAGrowingChildFillsItsHeight() {
        let placed = place("", [block(10, 10), block(10, 10, "grow")], height: 60)

        XCTAssertEqual(placed.frames.map(\.height), [10, 50])
        XCTAssertEqual(placed.size, CGSize(width: 100, height: 60))
    }

    func testAMeasuredValueKeepsItsOwnPoints() {
        let placed = place("gap-part", [block(10, 10), block(10, 10)])

        XCTAssertEqual(placed.frames[1].minY, 10 + SpotTokens.partGap)
    }

    func testAnAbsoluteChildPinsToTheHeightTheBoxIsGiven() {
        let placed = place("relative", [block(10, 10, "absolute inset-0"), block(10, 6, "absolute bottom-0 left-0 right-0")], height: 40)

        XCTAssertEqual(placed.frames, [CGRect(x: 0, y: 0, width: 100, height: 40), CGRect(x: 0, y: 34, width: 100, height: 6)])
    }
}
