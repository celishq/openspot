import XCTest
@testable import OpenspotCore

final class NodePartReadsTests: PanelCase {
    private func track(_ reads: [String: () -> Void]) -> () -> Set<String> {
        nonisolated(unsafe) var told: Set<String> = []
        for (name, read) in reads {
            withObservationTracking(read) { told.insert(name) }
        }
        return { told }
    }

    func testATypedValueTellsOnlyTheReaderOfItsPart() async throws {
        try script("form", toml: "", "printf 'frame=\\nclass=gap-part\\n\\nfield=name\\ntitle=Name\\nvalue=Ada\\n\\nswitch=wifi\\ntitle=Wi-Fi\\nvalue=true\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.pushFirst("form", moving: true)
        try await wait("the parts") { self.model.openParts != nil }
        let run = try XCTUnwrap(model.sheets["form"])
        let name = try XCTUnwrap(run[part: "name"])
        let wifi = try XCTUnwrap(run[part: "wifi"])

        var told = track(["name": { _ = run[part: "name"] }, "wifi": { _ = run[part: "wifi"] }, "panel": { _ = run.panel }])
        model.setPart(name, to: "Grace")
        XCTAssertEqual(told(), ["name"])
        XCTAssertEqual(run[part: "name"]?.control, .text("Grace", placeholder: nil, isReadOnly: false))

        told = track(["name": { _ = run[part: "name"] }, "wifi": { _ = run[part: "wifi"] }, "panel": { _ = run.panel }])
        model.setPart(wifi, to: "false")
        XCTAssertEqual(told(), ["wifi"])
        XCTAssertEqual(run.panel?.parts.first { $0.id == "wifi" }?.control, .toggle(false))
    }

    func testAFlipOnACardTellsOnlyTheReaderOfItsSwitch() async throws {
        try script("clock", toml: "[on]\n\"panel.open\" = true", "printf 'frame=\\nclass=gap-part\\n\\nswitch=power\\nclass=card:flex\\nvalue=false\\n\\nswitch=light\\nclass=card:flex\\nvalue=false\\n'")
        await model.reload()
        model.panelWillShow()
        try await wait("the card") { self.model.sheets["clock"]?[cardPart: "power"] != nil }
        let run = try XCTUnwrap(model.sheets["clock"])

        let told = track(["power": { _ = run[cardPart: "power"] }, "light": { _ = run[cardPart: "light"] }, "state": { _ = run.state }])
        model.setCardPart("clock", "power", to: "true")

        XCTAssertEqual(told(), ["power"])
        XCTAssertEqual(run[cardPart: "power"]?.control, .toggle(true))
    }
}
