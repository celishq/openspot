import XCTest
@testable import OpenspotCore

final class ShelfLayoutTests: XCTestCase {
    private let screen = CGSize(width: 1440, height: 900)

    private func panel(x: CGFloat) -> CGRect {
        CGRect(x: x, y: 200, width: 400, height: 500)
    }

    func testBothSidesHoldTheSameNumberOfColumnsSetByTheNarrowerSide() {
        let even = ShelfLayout(screen: screen, panel: panel(x: 520))
        let pushed = ShelfLayout(screen: screen, panel: panel(x: 300))

        XCTAssertGreaterThan(even.columns, pushed.columns)
        XCTAssertEqual(even.left, SpotTokens.arrangeMargin)
        XCTAssertEqual(even.right + ShelfLayout.width(columns: even.columns), screen.width - SpotTokens.arrangeMargin)
        XCTAssertLessThanOrEqual(even.left + ShelfLayout.width(columns: even.columns), 520 - SpotTokens.arrangeMargin)
        XCTAssertGreaterThanOrEqual(even.right, 920 + SpotTokens.arrangeMargin)
    }

    func testSpotsReadInRowsAcrossBothSides() {
        let layout = ShelfLayout(screen: screen, panel: panel(x: 520))
        let n = layout.columns

        XCTAssertEqual(layout.rect(of: 0).minX, layout.left)
        XCTAssertEqual(layout.rect(of: n).minX, layout.right)
        XCTAssertEqual(layout.rect(of: n).minY, layout.rect(of: 0).minY)
        XCTAssertEqual(layout.rect(of: 2 * n).minX, layout.left)
        XCTAssertEqual(layout.rect(of: 2 * n).minY, layout.rect(of: 0).minY + layout.rowPitch)
        XCTAssertEqual(layout.rows(of: 2 * n + 1), 2)
    }

    func testANarrowScreenStillHoldsOneColumnEachSide() {
        let layout = ShelfLayout(screen: CGSize(width: 500, height: 600), panel: panel(x: 50))

        XCTAssertEqual(layout.columns, 1)
    }
}
