import XCTest
@testable import OpenspotCore

final class FlowKeepTests: PanelCase {
    private var clock: FakeClock!

    override func setUp() async throws {
        try await super.setUp()
        model.quit()
        clock = FakeClock()
        let host = FakeHost()
        self.host = host
        let files = AppPlaces(environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path], home: folder, defaults: defaults)
        model = SpotsModel(host: host, files: files, runs: SpotRuns(clock: clock.value, stopPause: 0.2, prepare: { await host.prepare($0, glyphs: $1) }))
        host.model = model
        try script("parts", toml: "[on]\n\"sheet.open\" = true", "printf 'frame=\\nclass=gap-part\\n\\nfield=name\\ntitle=Name\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.pushFirst("parts", moving: true)
        try await wait("the open sheet") { self.model.openSheetID == "parts" && self.model.openParts != nil }
    }

    private func hide(for seconds: TimeInterval) {
        model.panelWillHide()
        model.panelDidHide()
        clock.advance(by: seconds)
        model.panelWillShow()
    }

    func testASheetOfPartsStaysWhenThePanelComesBackSoon() throws {
        let name = try XCTUnwrap(model.openParts?.parts.first { $0.id == "name" })
        model.setPart(name, to: "Ann")

        hide(for: 30)

        XCTAssertEqual(model.openSheetID, "parts")
        XCTAssertEqual(model.openParts?.parts.first { $0.id == "name" }?.value, "Ann")
    }

    func testThePanelComesBackOnTheGridAfterAPause() throws {
        hide(for: SpotsModel.flowKeep + 1)

        XCTAssertNil(model.openSheetID)
        XCTAssertNil(model.runs.openID)
    }
}
