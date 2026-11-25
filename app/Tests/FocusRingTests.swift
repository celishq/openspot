import XCTest
@testable import OpenspotCore

final class FocusRingTests: XCTestCase {
    private let frame = Frame(text: """
    frame=
    class=gap-part

    button=chip
    title=Forget
    class=rounded-full

    button=swap
    icon=arrow.up.arrow.down
    class=rounded-full

    button=plain
    title=Join

    button=row
    title=Open
    class=bg-transparent

    """)

    private func ring(of id: String) throws -> FocusRing {
        let part = try XCTUnwrap(frame.parts.first { $0.id == id })
        return FocusRing(part: part, look: frame.tree.look(of: id), surface: .sheet)
    }

    func testTheRingOfARoundedFullButtonIsACapsuleAroundTheButtonWithTheSameGapAllRound() throws {
        let gap = SpotTokens.focusGap

        XCTAssertEqual(try ring(of: "chip"), FocusRing(edge: SurfaceEdge(radius: .infinity), outset: CGSize(width: gap, height: gap), hugsControl: true))
    }

    func testTheRingOfARoundIconButtonIsACapsuleAroundTheButton() throws {
        let gap = SpotTokens.focusGap

        XCTAssertEqual(try ring(of: "swap"), FocusRing(edge: SurfaceEdge(radius: .infinity), outset: CGSize(width: gap, height: gap), hugsControl: true))
    }

    func testAPlainButtonAndARowKeepTheirRings() throws {
        let gap = SpotTokens.focusGap

        XCTAssertEqual(try ring(of: "plain"), FocusRing(edge: SurfaceEdge.sheet.inner(by: SpotTokens.padding - gap), outset: CGSize(width: gap, height: gap)))
        XCTAssertEqual(try ring(of: "row"), FocusRing(edge: SurfaceEdge.sheet.inner(), outset: CGSize(width: SpotTokens.controlPadding, height: 0)))
    }
}
