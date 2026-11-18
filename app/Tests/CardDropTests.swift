import XCTest
@testable import OpenspotCore

final class CardDropTests: PanelCase {
    func testADropOnACardWithRowsOpensItsSheetWithTheFocusAndOnAnyOtherCardClosesThePanel() async throws {
        try script("shelf", toml: "on = ['sheet.open']\ndrop = '*'", "case \"$1\" in show) printf 'text=a\\ntitle=A\\n' ;; esac")
        try script("plain", toml: "drop = '*'", "true")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        let file = folder.appendingPathComponent("a.txt")
        try Data().write(to: file)

        host.draggedPaths = [file.path]
        model.followDrag()
        try await wait("the kinds of the dragged file") { self.model.acceptsDrop([file.path], on: "plain") }
        XCTAssertTrue(model.drop([file.path], on: "plain"))
        XCTAssertEqual(host.dismissals, 1)
        XCTAssertNil(model.openSheetID)

        host.draggedPaths = [file.path]
        model.followDrag()
        try await wait("the kinds of the dragged file") { self.model.acceptsDrop([file.path], on: "shelf") }
        XCTAssertTrue(model.drop([file.path], on: "shelf"))
        try await wait("the sheet of the shelf") { self.model.openSheetID == "shelf" && self.titles == ["A"] }
        XCTAssertEqual(host.dismissals, 1)
        XCTAssertTrue(model.holdsFocus)
    }
}
