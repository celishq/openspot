import XCTest
@testable import OpenspotCore

final class ShelfLayoutTests: XCTestCase {
    private let screen = CGSize(width: 1440, height: 900)
    private let margin = SpotTokens.arrangeMargin

    private func panel(x: CGFloat) -> CGRect {
        CGRect(x: x, y: 200, width: 400, height: 500)
    }

    private func fit(_ room: CGFloat) -> Int {
        Int(((room - 2 * margin + SpotTokens.columnGap) / (SpotTokens.cell + SpotTokens.columnGap)).rounded(.down))
    }

    func testEachSideFillsItsOwnRoomUpToThePanel() {
        let layout = ShelfLayout(screen: screen, panel: panel(x: 300), sizes: [])

        XCTAssertEqual(layout.leftColumns, fit(300))
        XCTAssertEqual(layout.rightColumns, fit(1440 - 700))
        XCTAssertGreaterThan(layout.rightColumns, layout.leftColumns)
        XCTAssertEqual(layout.left + SpotTokens.width(columns: layout.leftColumns), 300 - margin)
        XCTAssertGreaterThanOrEqual(layout.left, margin)
        XCTAssertEqual(layout.right, 700 + margin)
        XCTAssertLessThanOrEqual(layout.right + SpotTokens.width(columns: layout.rightColumns), 1440 - margin)
    }

    func testEachCardKeepsItsOwnSizeWithinItsSide() {
        let layout = ShelfLayout(screen: screen, panel: panel(x: 520), sizes: [.wide, .small, .large, .square])

        XCTAssertEqual(layout.sizes, [.wide, .small, .large, .square])
        XCTAssertEqual(layout.rects.map(\.size), layout.sizes.map { CGSize(width: SpotTokens.width(columns: $0.columns), height: SpotTokens.height(rows: $0.rows)) })
        for (index, rect) in layout.rects.enumerated() {
            let inLeft = rect.minX >= layout.left && rect.maxX <= layout.left + SpotTokens.width(columns: layout.leftColumns)
            let inRight = rect.minX >= layout.right && rect.maxX <= layout.right + SpotTokens.width(columns: layout.rightColumns)
            XCTAssertTrue(inLeft || inRight, "card \(index)")
            for other in layout.rects.indices where other > index {
                XCTAssertFalse(rect.intersects(layout.rects[other]), "cards \(index) and \(other)")
            }
        }
        XCTAssertEqual(layout.height, layout.rects.map(\.maxY).max()! + SpotTokens.rowGap)
    }

    func testTheWiderSideTakesMoreSpots() {
        let layout = ShelfLayout(screen: screen, panel: panel(x: 300), sizes: Array(repeating: .small, count: 30))

        let onRight = layout.rects.filter { $0.minX >= layout.right }.count
        XCTAssertGreaterThan(onRight, 30 - onRight)
        XCTAssertEqual(layout.rects[0].minY, SpotTokens.rowGap)
    }

    func testACardWiderThanItsSideTakesTheLargestSizeThatFits() {
        let room = 2 * margin + SpotTokens.width(columns: 2)
        let layout = ShelfLayout(screen: CGSize(width: 2 * room + 400, height: 900), panel: CGRect(x: room, y: 0, width: 400, height: 500), sizes: [.large, .strip])

        XCTAssertEqual(layout.leftColumns, 2)
        XCTAssertEqual(layout.rightColumns, 2)
        XCTAssertEqual(layout.sizes, [.square, .wide])
    }

    func testANarrowScreenStillHoldsOneColumnEachSide() {
        let layout = ShelfLayout(screen: CGSize(width: 500, height: 600), panel: panel(x: 50), sizes: [.wide])

        XCTAssertEqual(layout.leftColumns, 1)
        XCTAssertEqual(layout.rightColumns, 1)
        XCTAssertEqual(layout.sizes, [.small])
    }
}
