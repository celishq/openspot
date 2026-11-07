import XCTest
@testable import OpenspotCore

final class WindowMoveTests: XCTestCase {
    private let area = CGRect(x: 0, y: 25, width: 1200, height: 900)
    private let window = CGRect(x: 100, y: 100, width: 400, height: 300)

    private func target(_ frames: String, from window: CGRect) -> CGRect? {
        WindowMove(words: frames.split(separator: " ").map(String.init))?.target(window: window, area: area)
    }

    func testAFrameInPointsIsTheTarget() {
        XCTAssertEqual(target("-1440 25 720 900", from: window), CGRect(x: -1440, y: 25, width: 720, height: 900))
    }

    func testAPercentAFractionOrAPlainNumberUpTo1IsAPartOfTheArea() {
        XCTAssertEqual(target("0 0 1 1", from: window), area)
        XCTAssertEqual(target("0% 0% 100% 100%", from: window), area)
        XCTAssertEqual(target("0.175 0.175 0.65 0.65", from: window), CGRect(x: 210, y: 183, width: 780, height: 585))
        XCTAssertEqual(target("2/3 0 1/3 1", from: window), CGRect(x: 800, y: 25, width: 400, height: 900))
        XCTAssertEqual(target("50% 0 1/2 1", from: window), CGRect(x: 600, y: 25, width: 600, height: 900))
    }

    func testAPartAndPointsMixInOneFrame() {
        XCTAssertEqual(target("100 0 1/2 600", from: window), CGRect(x: 100, y: 25, width: 600, height: 600))
    }

    func testAListOfFramesMovesTheWindowToTheFrameAfterTheOneItHolds() {
        let sides = "0 0 25% 1 0 0 1/3 1 0 0 0.5 1"
        var frame = window
        var widths: [CGFloat] = []
        for _ in 0..<4 {
            frame = target(sides, from: frame) ?? .zero
            widths.append(frame.width)
        }

        XCTAssertEqual(widths, [300, 400, 600, 300])
    }

    func testAWindowWithin20PointsOfAFrameHoldsIt() {
        let sides = "0 0 25% 1 0 0 1/3 1 0 0 0.5 1"

        XCTAssertEqual(target(sides, from: CGRect(x: 0, y: 25, width: 392, height: 890))?.width, 600)
        XCTAssertEqual(target(sides, from: CGRect(x: 0, y: 25, width: 350, height: 900))?.width, 300)
    }

    func testAWindowThatKeepsItsOwnSizeHoldsTheEdgeOfTheAreaItTouches() {
        let left = WindowMove.origin(of: CGSize(width: 700, height: 800), target: CGRect(x: 0, y: 25, width: 600, height: 900), area: area)
        let right = WindowMove.origin(of: CGSize(width: 700, height: 800), target: CGRect(x: 600, y: 25, width: 600, height: 900), area: area)
        let centre = WindowMove.origin(of: CGSize(width: 700, height: 500), target: CGRect(x: 210, y: 183, width: 780, height: 585), area: area)

        XCTAssertEqual(left, CGPoint(x: 0, y: 25))
        XCTAssertEqual(right, CGPoint(x: 500, y: 25))
        XCTAssertEqual(centre, CGPoint(x: 250, y: 226))
    }
}
