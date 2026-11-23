import XCTest
@testable import OpenspotCore

@MainActor
final class SpotActionTests: XCTestCase {
    func testTogglingAnOffSpotSendsOn() {
        let state = SpotState(title: "Focus", on: false, control: "focus")
        XCTAssertEqual(SpotRun.toggling(state).block(id: 1), "call=1\narg=focus\ninput.value=true\n\n")
    }

    func testTogglingAnOnSpotSendsOff() {
        let state = SpotState(title: "Wi-Fi", on: true, control: "wifi")
        XCTAssertEqual(SpotRun.toggling(state).block(id: 1), "call=1\narg=wifi\ninput.value=false\n\n")
    }

    func testTheCommandOfAManifestSendsItsOwnID() throws {
        let offer = try XCTUnwrap(Manifest(text: "[actions.add]\ntitle = 'Add'", folder: "/spots").actions.first)
        XCTAssertEqual(SpotWords.action(CommandAction.command(offer), item: nil).arguments, ["add"])
    }

    func testASliderLevelIsSentAsARoundedNumber() {
        XCTAssertEqual(SpotRun.level(69.6, of: "volume").block(id: 1), "call=1\narg=volume\ninput.value=70\n\n")
    }

    func testAClickOnACardWithAReadKeyCallsPressWithNoItem() {
        let url = URL(fileURLWithPath: "/x")

        XCTAssertEqual(Message(Spot(id: "a", name: "A", url: url, triggers: .panel).click).block(id: 1), "call=1\narg=press\n\n")
    }

    func testAClickOnAFileWithNoReadCallsPressWithNoItem() {
        let url = URL(fileURLWithPath: "/x")

        XCTAssertEqual(Message(Spot(id: "a", name: "A", url: url).click).block(id: 1), "call=1\narg=press\n\n")
    }

    func testAListItemCallsPressWithItsRunAsTheItem() {
        XCTAssertEqual(Handler.press.message(["3600"]).block(id: 1), "call=1\narg=press\ninput.item=3600\n\n")
    }

    func testAReadHasNoArgumentsAndItsTextGoesOnStdinWithEachForm() {
        XCTAssertEqual(SpotWords.show.arguments, ["show"])
        let rep = SearchQuery(text: "rep", layouts: [])
        let safari = SearchQuery(text: "сафари", layouts: [])
        XCTAssertEqual(ShowEvent.typed(rep.text, inSheet: false).message(search: rep).text, "input.text=rep\n")
        XCTAssertEqual(ShowEvent.typed(safari.text, inSheet: false).message(search: safari).text, "input.text=сафари\ninput.alt=safari\n")
    }

    func testAnActionSendsItsIdAndItsItem() {
        let delete = CommandAction(id: "delete", title: "Delete")

        XCTAssertEqual(SpotWords.action(delete, item: SpotItem(title: "One", run: "1")).arguments, ["delete", "1"])
        XCTAssertEqual(SpotWords.action(delete, item: nil).arguments, ["delete"])
    }

    func testAValueOver64KilobytesInBytesLeavesTheArguments() {
        let long = String(repeating: "é", count: 32_769)

        let sent = Message(.set("a", to: long), given: "a=\(long)\nb=1\n").sent

        XCTAssertEqual(sent.arguments, ["a"])
        XCTAssertEqual(sent.input, "a=\(long)\nb=1\n")
    }

    func testALongRunJoinsTheValuesOfAFormAsValue() {
        let long = String(repeating: "x", count: 65_537)

        let sent = Message(SpotWords(arguments: ["edit", long]), inputs: [.init(key: "title", value: "A")]).sent

        XCTAssertEqual(sent.arguments, ["edit"])
        XCTAssertEqual(sent.input, "input.title=A\ninput.value=\(long)\n")
    }

    func testAShortValueStaysAndStdinDoesNotChange() {
        let sent = Message(.set("a", to: "b")).sent

        XCTAssertEqual(sent.arguments, ["a", "b"])
        XCTAssertNil(sent.input)
    }
}
