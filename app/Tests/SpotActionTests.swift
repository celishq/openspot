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
        XCTAssertEqual(SpotAction.level(69.6).arguments, ["level", "70"])
    }

    func testAClickOnACardWithAReadKeySendsRun() {
        let url = URL(fileURLWithPath: "/x")

        XCTAssertEqual(PluginCommand(id: "a", name: "A", url: url, read: .panel).click.arguments, ["run"])
    }

    func testAClickOnAFileWithNoReadSendsNoArgument() {
        let url = URL(fileURLWithPath: "/x")

        XCTAssertEqual(PluginCommand(id: "a", name: "A", url: url).click.arguments, [])
    }

    func testAListItemSendsItsRunValue() {
        XCTAssertEqual(SpotAction.item(SpotItem(title: "1 hour", run: "3600")).arguments, ["open", "3600"])
    }

    func testAReadPassesATextOnlyWhenThereIsOne() {
        XCTAssertEqual(SpotAction.read.arguments, ["read"])
        XCTAssertEqual(SpotAction.items(query: "").arguments, ["read"])
        XCTAssertEqual(SpotAction.items(query: "rep").arguments, ["read", "rep"])
    }

    func testAnActionSendsItsIdAndItsItem() {
        let delete = CommandAction(id: "delete", title: "Delete")

        XCTAssertEqual(SpotAction.action(delete, item: SpotItem(title: "One", run: "1")).arguments, ["delete", "1"])
        XCTAssertEqual(SpotAction.action(delete, item: nil).arguments, ["delete"])
    }
}
