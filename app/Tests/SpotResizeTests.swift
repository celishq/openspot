import XCTest
@testable import OpenspotCore

final class SpotResizeTests: XCTestCase {
    /// `a a b b / c c d d`: three wide spots and a small one, which grows to fill its row.
    private let sizes: [SpotSize] = [.wide, .wide, .wide, .small]

    private func corner(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.maxX, y: rect.maxY)
    }

    func testEachSizeLaysOutTheGridAndASizeThatChangesNothingIsLeftOut() {
        let resize = SpotResize(id: "c", index: 2, sizes: sizes, choices: SpotSize.all)

        XCTAssertEqual(resize.choices, [.wide, .square, .strip, .large])
        XCTAssertEqual(resize.placement(of: .square), SpotPlacement(index: 2, row: 1, column: 0, size: .square))
        XCTAssertEqual(resize.layout(of: .square)[3], SpotPlacement(index: 3, row: 1, column: 2, size: .square))
    }

    func testThePointerAtItsOwnCornerKeepsTheSize() {
        let resize = SpotResize(id: "c", index: 2, sizes: sizes, choices: SpotSize.all)

        XCTAssertEqual(resize.size, .wide)
        XCTAssertEqual(resize.nearest(to: resize.corner(movedBy: .zero)), .wide)
    }

    func testThePointerPulledDownARowTakesTheSquare() {
        let resize = SpotResize(id: "c", index: 2, sizes: sizes, choices: SpotSize.all)

        let pointer = resize.corner(movedBy: CGSize(width: 0, height: SpotTokens.rowHeight + SpotTokens.rowGap))

        XCTAssertEqual(pointer, corner(of: resize.placement(of: .square)?.rect ?? .zero))
        XCTAssertEqual(resize.nearest(to: pointer), .square)
    }

    func testThePointerPulledToTheFarEdgeTakesTheStripOrTheLarge() {
        let resize = SpotResize(id: "c", index: 2, sizes: sizes, choices: SpotSize.all)
        let start = resize.corner(movedBy: .zero)

        XCTAssertEqual(resize.nearest(to: CGPoint(x: SpotTokens.gridWidth, y: start.y)), .strip)
        XCTAssertEqual(resize.nearest(to: CGPoint(x: SpotTokens.gridWidth, y: start.y + SpotTokens.rowHeight)), .large)
    }

    func testASizeThatNeedsMoreRowsThanTheGridShowsIsLeftOut() {
        let resize = SpotResize(id: "c", index: 2, sizes: sizes, choices: SpotSize.all, rows: 2)

        XCTAssertEqual(resize.choices, [.wide])
    }

    func testACardThatOffersOneSizeHasNothingToChoose() {
        let resize = SpotResize(id: "c", index: 2, sizes: sizes, choices: [])

        XCTAssertEqual(resize.choices, [.wide])
        XCTAssertEqual(resize.nearest(to: .zero), .wide)
    }
}
