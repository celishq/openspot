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

    func testTheCommandOfAManifestSendsItsOwnID() throws {
        let offer = try XCTUnwrap(Manifest(text: "[commands.add]\ntitle = 'Add'", folder: "/spots").commands.first)
        XCTAssertEqual(SpotAction.action(CommandAction.command(offer), item: nil).arguments, ["add"])
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

    func testAReadHasNoArgumentsAndItsTextGoesOnStdinWithEachForm() {
        XCTAssertEqual(SpotAction.show.arguments, ["show"])
        let rep = SearchQuery(text: "rep", layouts: [])
        let safari = SearchQuery(text: "сафари", layouts: [])
        XCTAssertEqual(Message(.show, search: rep.text, searchForms: rep.forms).text, "search=rep\n")
        XCTAssertEqual(Message(.show, search: safari.text, searchForms: safari.forms).text, "search=сафари\nsearch.alt=safari\n")
    }

    func testAnActionSendsItsIdAndItsItem() {
        let delete = CommandAction(id: "delete", title: "Delete")

        XCTAssertEqual(SpotAction.action(delete, item: SpotItem(title: "One", run: "1")).arguments, ["delete", "1"])
        XCTAssertEqual(SpotAction.action(delete, item: nil).arguments, ["delete"])
    }

    func testAValueOver64KilobytesInBytesLeavesTheArguments() {
        let long = String(repeating: "é", count: 32_769)

        let sent = Message(.set("a", to: long), given: "a=\(long)\nb=1\n").sent

        XCTAssertEqual(sent.arguments, ["a"])
        XCTAssertEqual(sent.input, "a=\(long)\nb=1\n")
    }

    func testALongRunJoinsTheValuesOfAFormAsValue() {
        let long = String(repeating: "x", count: 65_537)

        let sent = Message(SpotAction(arguments: ["edit", long]), inputs: [.init(key: "title", value: "A")]).sent

        XCTAssertEqual(sent.arguments, ["edit"])
        XCTAssertEqual(sent.input, "input.title=A\ninput.value=\(long)\n")
    }

    func testAShortValueStaysAndStdinDoesNotChange() {
        let sent = Message(.set("a", to: "b")).sent

        XCTAssertEqual(sent.arguments, ["a", "b"])
        XCTAssertNil(sent.input)
    }
}
