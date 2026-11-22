@testable import OpenspotCore
import XCTest

@MainActor
final class SheetHeaderTests: XCTestCase {
    private let line: CGFloat = 9
    private var header: SheetHeader {
        SheetHeader(width: { CGFloat($0.count) * 10 }, secondLine: line)
    }

    func testADetailThatFitsOneLineAddsNothing() {
        XCTAssertEqual(header.extra(for: "Short"), 0)
        XCTAssertEqual(header.extra(for: nil), 0)
    }

    func testADetailWiderThanTheHeaderAddsASecondLine() {
        let long = String(repeating: "a", count: Int(SpotTokens.sheetWordsWidth / 10) + 1)

        XCTAssertEqual(header.extra(for: long), line)
    }

    func testTheSecondLineGrowsTheSheetAndTakesItsRoomFromTheParts() throws {
        let text = "frame=\nclass=gap-part\n\nnumber=cpu\nvalue=1\nvalue=2\n\nitems=list\n\ntext=a\nparent=list\ntitle=A\n"
        var panel = try XCTUnwrap(SheetParts(output: Frame(text: text)))
        let flat = SpotTokens.panelRect(panel).height

        panel.place(top: SheetTop(header: line, hasField: false))

        XCTAssertEqual(panel.placement.height, SpotTokens.partsMaxHeight - line)
        XCTAssertEqual(SpotTokens.panelRect(panel).height, flat)
        XCTAssertEqual(SpotTokens.sheetRect(rows: 1, top: SheetTop(header: line, hasField: true)).height - SpotTokens.sheetRect(rows: 1).height, line)
    }
}
