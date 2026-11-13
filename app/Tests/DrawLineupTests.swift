import XCTest

/// Proves where rows dragged in the list of boards would land.
final class DrawLineupTests: XCTestCase {
    private let top = URL(fileURLWithPath: "/boards")
    private var work: URL { top.appendingPathComponent("Work") }
    private func board(_ name: String, in place: URL? = nil) -> URL { (place ?? top).appendingPathComponent("\(name).json") }

    /// Work (36, open, holds x), x (52), a (52), b (52), each 2 apart: Work 0-36, x 38-90, a 92-144, b 146-198.
    private var lineup: Lineup {
        Lineup(rows: [
            .init(url: work, isFolder: true, open: true, first: board("x", in: work), height: 36),
            .init(url: board("x", in: work), isFolder: false, height: 52),
            .init(url: board("a"), isFolder: false, height: 52),
            .init(url: board("b"), isFolder: false, height: 52)
        ], top: top)
    }

    func testTheMiddleOfAFolderTakesTheRowsIn() {
        XCTAssertEqual(lineup.landing(at: 18, gap: nil, gapHeight: 0), .into(work))
    }

    func testTheTopHalfOfARowPutsThemBeforeItAndTheBottomHalfAfterIt() {
        XCTAssertEqual(lineup.landing(at: 100, gap: nil, gapHeight: 0), .before(board("a"), in: top))
        XCTAssertEqual(lineup.landing(at: 130, gap: nil, gapHeight: 0), .before(board("b"), in: top))
        XCTAssertEqual(lineup.landing(at: 190, gap: nil, gapHeight: 0), .before(nil, in: top))
    }

    func testBelowAnOpenFolderTheyGoFirstInsideItAndBelowItsLastRowAtItsEnd() {
        XCTAssertEqual(lineup.landing(at: 33, gap: nil, gapHeight: 0), .before(board("x", in: work), in: work))
        XCTAssertEqual(lineup.landing(at: 80, gap: nil, gapHeight: 0), .before(nil, in: work))
    }

    func testAnOpenGapIsTakenOutSoAStillPointerKeepsItsPlace() {
        let landing = lineup.landing(at: 100, gap: nil, gapHeight: 0)
        XCTAssertEqual(lineup.landing(at: 100 + 54, gap: .some(board("a")), gapHeight: 54), landing)
    }

    func testBelowEveryRowTheyGoToTheEndOfTheTop() {
        XCTAssertEqual(lineup.landing(at: 500, gap: nil, gapHeight: 0), .before(nil, in: top))
    }
}
