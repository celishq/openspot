import XCTest
@testable import OpenspotCore

final class IconBodyTests: XCTestCase {
    /// An alpha grid of this side, opaque inside the rectangle.
    private func alpha(side: Int, opaque: CGRect) -> [UInt8] {
        (0..<side * side).map { opaque.contains(CGPoint(x: CGFloat($0 % side) + 0.5, y: CGFloat($0 / side) + 0.5)) ? 255 : 0 }
    }

    func testAStandardAppIconKeepsItsFrame() {
        let body = IconBody(alpha: alpha(side: 512, opaque: CGRect(x: 50, y: 50, width: 412, height: 412)), side: 512)

        XCTAssertEqual(body.frame(in: 512), CGRect(x: 0, y: 0, width: 512, height: 512))
    }

    func testAWideIconShrinksUntilItsWidthIsTheBodyOfAnAppIcon() {
        let body = IconBody(alpha: alpha(side: 100, opaque: CGRect(x: 4, y: 20, width: 92, height: 60)), side: 100)
        let frame = body.frame(in: 100)

        XCTAssertEqual(frame.width * 92 / 100, 100 * IconBody.share, accuracy: 0.01)
        XCTAssertEqual(frame.midX, 50, accuracy: 0.01)
        XCTAssertEqual(frame.midY, 50, accuracy: 0.01)
    }

    func testAnEmptyIconKeepsItsFrame() {
        XCTAssertEqual(IconBody(alpha: [UInt8](repeating: 0, count: 16), side: 4).frame(in: 4), CGRect(x: 0, y: 0, width: 4, height: 4))
    }
}
