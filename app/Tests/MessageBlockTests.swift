import XCTest
@testable import OpenspotCore

@MainActor
final class MessageBlockTests: XCTestCase {
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
        XCTAssertEqual(CommandAction.command(of: CommandAction.command(offer)), "add")
    }

    func testASliderLevelIsSentAsARoundedNumber() {
        XCTAssertEqual(SpotRun.level(69.6, of: "volume").block(id: 1), "call=1\narg=volume\ninput.value=70\n\n")
    }

    func testAPressWithNoItemSendsOnlyItsHandler() {
        XCTAssertEqual(Message(Handler.press.name).block(id: 1), "call=1\narg=press\n\n")
    }

    func testAListItemCallsPressWithItsRunAsTheItem() {
        XCTAssertEqual(Handler.press.message(["3600"]).block(id: 1), "call=1\narg=press\ninput.item=3600\n\n")
    }

    func testASearchHasNoArgumentsAndItsTextGoesOnStdinWithEachForm() {
        let rep = SearchQuery(text: "rep", layouts: [])
        let safari = SearchQuery(text: "сафари", layouts: [])
        XCTAssertEqual(ShowEvent.typed(rep.text, inSheet: false).message(search: rep).text, "input.text=rep\n")
        XCTAssertEqual(ShowEvent.typed(safari.text, inSheet: false).message(search: safari).text, "input.text=сафари\ninput.alt=safari\n")
    }
}
