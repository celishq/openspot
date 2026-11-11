import XCTest
@testable import OpenspotCore

final class SpotActionTests: XCTestCase {
    func testTogglingAnOffSpotSendsOn() {
        let state = SpotState(title: "Focus", on: false, control: "focus")
        XCTAssertEqual(SpotAction.toggle(state).arguments, ["focus", "true"])
    }

    func testTogglingAnOnSpotSendsOff() {
        let state = SpotState(title: "Wi-Fi", on: true, control: "wifi")
        XCTAssertEqual(SpotAction.toggle(state).arguments, ["wifi", "false"])
    }

    func testASliderLevelIsSentAsARoundedNumber() {
        XCTAssertEqual(SpotAction.level(69.6, of: "volume").arguments, ["volume", "70"])
    }

    func testAClickOnACardWithAReadKeySendsOpenWithNoRow() {
        let url = URL(fileURLWithPath: "/x")

        XCTAssertEqual(Spot(id: "a", name: "A", url: url, read: .panel).click.arguments, ["open"])
    }

    func testAClickOnAFileWithNoReadSendsOpenWithNoRow() {
        let url = URL(fileURLWithPath: "/x")

        XCTAssertEqual(Spot(id: "a", name: "A", url: url).click.arguments, ["open"])
    }

    func testAListItemSendsItsRunValue() {
        XCTAssertEqual(SpotAction.item(SpotItem(title: "1 hour", run: "3600")).arguments, ["open", "3600"])
    }

    func testAReadPassesATextOnlyWhenThereIsOne() {
        XCTAssertEqual(SpotAction.read.arguments, ["read"])
        XCTAssertEqual(SpotAction.items(query: "").arguments, ["read"])
        XCTAssertEqual(SpotAction.items(query: "rep").arguments, ["read", "rep"])
        XCTAssertEqual(SpotAction.items(query: "сафари", forms: ["safari"]).arguments, ["read", "сафари", "safari"])
    }

    func testAnActionSendsItsIdAndItsItem() {
        let delete = CommandAction(id: "delete", title: "Delete")

        XCTAssertEqual(SpotAction.action(delete, item: SpotItem(title: "One", run: "1")).arguments, ["delete", "1"])
        XCTAssertEqual(SpotAction.action(delete, item: nil).arguments, ["delete"])
    }

    func testAValueOver64KilobytesInBytesLeavesTheArguments() {
        let long = String(repeating: "é", count: 32_769)

        let sent = SpotAction.set("a", to: long).sent(input: "a=\(long)\nb=1\n")

        XCTAssertEqual(sent.arguments, ["a"])
        XCTAssertEqual(sent.input, "a=\(long)\nb=1\n")
    }

    func testALongRunJoinsTheValuesOfAFormAsValue() {
        let long = String(repeating: "x", count: 65_537)

        let sent = SpotAction(arguments: ["edit", long]).sent(input: "title=A\n")

        XCTAssertEqual(sent.arguments, ["edit"])
        XCTAssertEqual(sent.input, "title=A\nvalue=\(long)\n")
    }

    func testAShortValueStaysAndStdinDoesNotChange() {
        let sent = SpotAction.set("a", to: "b").sent(input: nil)

        XCTAssertEqual(sent.arguments, ["a", "b"])
        XCTAssertNil(sent.input)
    }
}
