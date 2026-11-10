import XCTest
@testable import OpenspotCore

final class PanelResizeTests: XCTestCase {
    /// `a a b b / c c d d`: four wide spots.
    private let sizes: [SpotSize] = [.wide, .wide, .wide, .wide]
    private let limit = PanelSize(columns: 16, rows: 10)

    private func corner(_ size: PanelSize) -> CGPoint {
        CGPoint(x: SpotTokens.width(columns: size.columns), y: SpotTokens.height(rows: size.rows))
    }

    func testThePointerAtTheCornerKeepsTheSize() {
        let resize = PanelResize(start: PanelSize(columns: 4, rows: 6), sizes: sizes, limit: limit)

        XCTAssertEqual(resize.nearest(to: resize.corner(movedBy: .zero)), PanelSize(columns: 4, rows: 6))
    }

    func testThePointerPulledRightTakesTheNextStepOfFourColumns() {
        let resize = PanelResize(start: PanelSize(columns: 4, rows: 6), sizes: sizes, limit: limit)
        let right = SpotTokens.width(columns: 8) - SpotTokens.width(columns: 4)

        XCTAssertEqual(resize.nearest(to: resize.corner(movedBy: CGSize(width: right - 10, height: 0))), PanelSize(columns: 8, rows: 6))
        XCTAssertEqual(resize.nearest(to: resize.corner(movedBy: CGSize(width: right / 3, height: 0))), PanelSize(columns: 4, rows: 6))
    }

    func testTheRowsStopAtTheLowestCard() {
        let resize = PanelResize(start: PanelSize(columns: 4, rows: 6), sizes: sizes, limit: limit)

        XCTAssertEqual(resize.nearest(to: .zero), PanelSize(columns: 4, rows: 2))
        XCTAssertEqual(resize.nearest(to: CGPoint(x: SpotTokens.width(columns: 8), y: 0)), PanelSize(columns: 8, rows: 1))
    }

    func testTheSizeStopsAtTheLimit() {
        let resize = PanelResize(start: PanelSize(columns: 4, rows: 6), sizes: sizes, limit: PanelSize(columns: 8, rows: 7))

        XCTAssertEqual(resize.nearest(to: CGPoint(x: 5000, y: 5000)), PanelSize(columns: 8, rows: 7))
    }
}
