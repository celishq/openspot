import XCTest
@testable import OpenspotCore

final class ShelfLayoutTests: XCTestCase {
    private let screen = CGSize(width: 1440, height: 900)

    private func panel(x: CGFloat) -> CGRect {
        CGRect(x: x, y: 200, width: 400, height: 500)
    }

    func testBothSidesHoldTheSameNumberOfColumnsSetByTheNarrowerSide() {
        let even = ShelfLayout(screen: screen, panel: panel(x: 520), sizes: [])
        let pushed = ShelfLayout(screen: screen, panel: panel(x: 300), sizes: [])

        XCTAssertGreaterThan(even.columns, pushed.columns)
        XCTAssertEqual(even.left, SpotTokens.arrangeMargin)
        XCTAssertEqual(even.right + SpotTokens.width(columns: even.columns), screen.width - SpotTokens.arrangeMargin)
        XCTAssertLessThanOrEqual(even.left + SpotTokens.width(columns: even.columns), 520 - SpotTokens.arrangeMargin)
        XCTAssertGreaterThanOrEqual(even.right, 920 + SpotTokens.arrangeMargin)
    }

    func testEachCardKeepsItsOwnSizeAndTheSpotsTakeTurnsBetweenTheSides() {
        let layout = ShelfLayout(screen: screen, panel: panel(x: 520), sizes: [.wide, .small, .large, .square])

        XCTAssertGreaterThanOrEqual(layout.columns, 4)
        XCTAssertEqual(layout.sizes, [.wide, .small, .large, .square])
        XCTAssertEqual(layout.rects.map(\.size), layout.sizes.map { CGSize(width: SpotTokens.width(columns: $0.columns), height: SpotTokens.height(rows: $0.rows)) })
        XCTAssertEqual(layout.rects[0].minX, layout.left)
        XCTAssertEqual(layout.rects[1].minX, layout.right)
        XCTAssertEqual(layout.rects[0].minY, layout.rects[1].minY)
        XCTAssertFalse(layout.rects[0].intersects(layout.rects[2]))
        XCTAssertFalse(layout.rects[1].intersects(layout.rects[3]))
        XCTAssertGreaterThanOrEqual(layout.rects[2].minX, layout.left)
        XCTAssertLessThanOrEqual(layout.rects[2].maxX, layout.left + SpotTokens.width(columns: layout.columns))
        XCTAssertGreaterThanOrEqual(layout.rects[3].minX, layout.right)
        XCTAssertEqual(layout.height, layout.rects.map(\.maxY).max()! + SpotTokens.rowGap)
    }

    func testACardWiderThanASideTakesTheLargestSizeThatFits() {
        let narrow = CGSize(width: 2 * SpotTokens.arrangeMargin + 2 * SpotTokens.width(columns: 2) + 400 + 2 * SpotTokens.arrangeMargin, height: 900)
        let layout = ShelfLayout(screen: narrow, panel: CGRect(x: SpotTokens.arrangeMargin * 2 + SpotTokens.width(columns: 2), y: 0, width: 400, height: 500), sizes: [.large, .strip])

        XCTAssertEqual(layout.columns, 2)
        XCTAssertEqual(layout.sizes, [.square, .wide])
    }

    func testANarrowScreenStillHoldsOneColumnEachSide() {
        let layout = ShelfLayout(screen: CGSize(width: 500, height: 600), panel: panel(x: 50), sizes: [.wide])

        XCTAssertEqual(layout.columns, 1)
        XCTAssertEqual(layout.sizes, [.small])
    }
}
