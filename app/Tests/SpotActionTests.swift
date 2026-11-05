import XCTest
@testable import OpenspotCore

final class SpotActionTests: XCTestCase {
    func testTogglingAnOffSpotSendsOn() {
        let state = SpotState(title: "Focus", on: false)
        XCTAssertEqual(SpotAction.toggle(state).arguments, ["on"])
    }

    func testTogglingAnOnSpotSendsOff() {
        let state = SpotState(title: "Wi-Fi", on: true)
        XCTAssertEqual(SpotAction.toggle(state).arguments, ["off"])
    }

    func testASliderLevelIsSentAsARoundedNumber() {
        XCTAssertEqual(SpotAction.level(69.6).arguments, ["70"])
    }

    func testARunSendsNoArguments() {
        XCTAssertEqual(SpotAction.run.arguments, [])
    }

    func testAListItemSendsItsRunValue() {
        XCTAssertEqual(SpotAction.item(SpotItem(title: "1 hour", run: "3600")).arguments, ["3600"])
    }

    func testItemsPassesASearchOnlyWhenThereIsOne() {
        XCTAssertEqual(SpotAction.items(query: "").arguments, ["items"])
        XCTAssertEqual(SpotAction.items(query: "rep").arguments, ["items", "rep"])
    }

    func testAnActionSendsItsIdAndItsItem() {
        let delete = CommandAction(id: "delete", title: "Delete")

        XCTAssertEqual(SpotAction.action(delete, item: SpotItem(title: "One", run: "1")).arguments, ["delete", "1"])
        XCTAssertEqual(SpotAction.action(delete, item: nil).arguments, ["delete"])
    }

    func testAFormAsksByTheIdOfItsAction() {
        let edit = CommandAction(id: "edit", title: "Edit", isForm: true)

        XCTAssertEqual(SpotAction.form(edit, item: SpotItem(title: "One", run: "1")).arguments, ["form", "edit", "1"])
    }
}
