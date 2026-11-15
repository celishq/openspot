import XCTest
@testable import OpenspotCore

final class SurfaceEdgeTests: XCTestCase {
    private func bounds(of size: SpotSize) -> CGRect {
        CGRect(x: 0, y: 0, width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
    }

    func testASmallAndAWideCardAreCapsulesAndEachOtherCardHasTheCornerOfASheet() {
        for size in SpotSize.all {
            let edge = SurfaceEdge(card: size)
            let isCapsule = size == .small || size == .wide

            XCTAssertEqual(edge.isCircular(in: bounds(of: size)), isCapsule, size.name)
            XCTAssertEqual(edge.corner(in: bounds(of: size)), isCapsule ? SpotTokens.rowHeight / 2 : SpotTokens.radius, size.name)
            XCTAssertEqual(edge.place(in: bounds(of: size)), bounds(of: size), size.name)
        }
    }

    func testTheRingOfACardIsTheEdgeOfTheCardMovedInByHalfItsLineForEachSize() {
        let half = SpotTokens.ring / 2
        for size in SpotSize.all {
            let card = SurfaceEdge(card: size)
            let ring = card.inset(by: half)

            XCTAssertEqual(ring.radius, card.radius, size.name)
            XCTAssertEqual(ring.isCircular(in: bounds(of: size)), card.isCircular(in: bounds(of: size)), size.name)
            XCTAssertEqual(ring.place(in: bounds(of: size)), bounds(of: size).insetBy(dx: half, dy: half), size.name)
            XCTAssertEqual(ring.corner(in: bounds(of: size)), card.corner(in: bounds(of: size)) - half, size.name)
        }
    }

    func testAnEdgeIsCircularOnlyWhenItsCornerIsHalfItsShortSide() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 40)

        XCTAssertTrue(SurfaceEdge(radius: 20).isCircular(in: rect))
        XCTAssertTrue(SurfaceEdge(radius: 500).isCircular(in: rect))
        XCTAssertEqual(SurfaceEdge(radius: 500).corner(in: rect), 20)
        XCTAssertFalse(SurfaceEdge(radius: 19).isCircular(in: rect))
        XCTAssertFalse(SurfaceEdge(radius: 0).isCircular(in: rect))
    }

    func testAnInsetPastTheRadiusLeavesASquareCorner() {
        let edge = SurfaceEdge(radius: 4).inset(by: 6)

        XCTAssertEqual(edge.corner(in: CGRect(x: 0, y: 0, width: 100, height: 100)), 0)
        XCTAssertEqual(edge.place(in: CGRect(x: 0, y: 0, width: 100, height: 100)), CGRect(x: 6, y: 6, width: 88, height: 88))
    }

    func testEachMarkOfACardTakesTheEdgeOfItsGlassForEachSize() {
        for size in SpotSize.all {
            for mark in CardMark.allCases {
                XCTAssertEqual(SurfaceEdge(card: size, mark: mark), SurfaceEdge(card: size, mark: .glass), "\(size.name) \(mark)")
            }
            XCTAssertEqual(SurfaceEdge(card: size, mark: .glass), SurfaceEdge(card: size), size.name)
        }
    }

    func testAFloatOfASheetHasTheEdgeOfASheetAndAFloatOfACardTheEdgeOfThatCard() {
        XCTAssertEqual(SurfaceEdge(float: .list, size: .small), .sheet)
        XCTAssertEqual(SurfaceEdge(float: .launch, size: .small), SurfaceEdge(card: .small))
        XCTAssertEqual(SurfaceEdge(float: .toggle, size: .large), SurfaceEdge(card: .large))
    }

    func testAPartInsideASurfaceHasTheCornerOfTheSurfaceLessThePadding() {
        XCTAssertEqual(SurfaceEdge.sheet.inner().radius, SpotTokens.radius - SpotTokens.padding)
        XCTAssertEqual(SurfaceEdge.window.inner().radius, SurfaceEdge.window.radius - SpotTokens.padding)
        XCTAssertEqual(SurfaceEdge(radius: 8).inner().radius, 0)
        XCTAssertEqual(SurfaceEdge.sheet.inner(by: 4).radius, SpotTokens.radius - 4)
    }
}
