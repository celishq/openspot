import XCTest
@testable import OpenspotCore

@MainActor
final class EditSheetTests: PanelCase {
    private var release: URL {
        folder.appendingPathComponent("release")
    }

    private var hold: URL {
        folder.appendingPathComponent("hold")
    }

    override func setUp() async throws {
        try await super.setUp()
        let core = folder.appendingPathComponent("core", isDirectory: true)
        let app = core.appendingPathComponent("openspot.spot")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try "[scripts.new]\ntitle = 'New spot'\nedits = 'spots'\n\n[scripts.new.on]\n\"sheet.open\" = true\n".write(to: app.appendingPathComponent("spot.toml"), atomically: true, encoding: .utf8)
        try """
        #!/bin/sh
        case "$1" in
          show) if [ -f '\(hold.path)' ]; then while [ ! -f '\(release.path)' ]; do sleep 0.01; done; fi; printf 'frame=\\nclass=gap-part\\n\\nfield=describe\\nvalue=\\n\\nbutton=done\\ntitle=Done\\n' ;;
          done) while [ ! -f '\(release.path)' ]; do sleep 0.01; done ;;
        esac
        """.writeScript(to: app.appendingPathComponent("new.sh"))
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path, "OPENSPOT_CORE": core.path],
            home: folder,
            defaults: defaults
        )
        model.quit()
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: stopPause))
        host.model = model
    }

    func testAPressThatAnswersWithNoViewClosesThePanelWhenItsCallEnds() async throws {
        try script("weather", toml: "title = 'Weather'", "printf 'item=a\\ntitle=A\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        let weather = try XCTUnwrap(model.cards.first { $0.id == "weather" })
        XCTAssertTrue(model.openEdit(of: weather))
        let id = OwnedSheet.edit.id(of: "weather")
        try await wait("the edit sheet") { self.model.openSheetID == id && self.model.sheets[id]?.panel?.parts.contains { $0.id == "done" } == true }
        let sheet = try XCTUnwrap(model.sheets[id])
        let done = try XCTUnwrap(sheet.panel?.parts.first { $0.id == "done" })

        model.pressPart(done)
        try await wait("the call of done") { sheet.calls.contains { $0.handler == "done" } }
        XCTAssertEqual(host.dismissals, 0)
        FileManager.default.createFile(atPath: release.path, contents: Data())

        try await wait("the close") { self.host.dismissals == 1 }
    }

    func testNewSpotOpensAgainWithItsFormBeforeItsScriptAnswers() async throws {
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.presentSheet(of: "openspot/new")
        try await wait("the form") { self.model.sheets["openspot/new"]?.panel?.parts.contains { $0.id == "describe" } == true }
        model.closeSheet(moving: false)
        model.isShown = false
        model.panelDidHide()
        try await wait("the form dropped") { self.model.sheets["openspot/new"]?.panel == nil }
        FileManager.default.createFile(atPath: hold.path, contents: Data())

        model.isShown = true
        model.panelWillShow()
        model.presentSheet(of: "openspot/new")

        XCTAssertEqual(model.sheets["openspot/new"]?.panel?.parts.contains { $0.id == "describe" }, true)
        FileManager.default.createFile(atPath: release.path, contents: Data())
    }
}
