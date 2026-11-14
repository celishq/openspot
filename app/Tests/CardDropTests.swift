import XCTest
@testable import OpenspotCore

final class CardDropTests: PanelCase {
    func test_D8_aDropOnACardWithRowsOpensItsSheetWithTheFocusAndOnAnyOtherCardClosesThePanel() async throws {
        try script("shelf", header: "on=sheet.open\ndrop=*", "case \"$1\" in read) printf 'row=a\\ntitle=A\\n' ;; esac")
        try script("plain", header: "drop=*", "true")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        let file = folder.appendingPathComponent("a.txt")
        try Data().write(to: file)

        XCTAssertTrue(model.drop([file.path], on: "plain"))
        XCTAssertEqual(host.dismissals, 1)
        XCTAssertNil(model.openList)

        XCTAssertTrue(model.drop([file.path], on: "shelf"))
        try await waitFor("the sheet of the shelf") { self.model.openList == "shelf" && self.titles == ["A"] }
        XCTAssertEqual(host.dismissals, 1)
        XCTAssertTrue(model.holdsFocus)
    }
}
