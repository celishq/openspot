import XCTest
@testable import OpenspotCore

/// The setup and the helpers of the tests that prove the panel with real spots: a folder of spots, a test host, and a list
/// whose row `a` opens its page.
@MainActor
class PanelCase: XCTestCase {
    var folder: URL!
    var defaults: UserDefaults!
    var suite = ""
    var host: TestHost!
    var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-panel-case-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        suite = "openspot-panel-case-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let host = TestHost()
        self.host = host
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
            home: folder,
            defaults: defaults
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2, prepare: { await host.prepare($0, glyphs: $1) }))
        host.model = model
    }

    override func tearDown() async throws {
        model.quit()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    var spots: URL {
        folder.appendingPathComponent("spots", isDirectory: true)
    }

    let back = ActionKey(name: "[", isCommand: true)
    let forward = ActionKey(name: "]", isCommand: true)
    let escape = ActionKey(name: "escape")
    let toGrid = ActionKey(name: "escape", isCommand: true)

    func script(_ name: String, header: String, _ body: String) throws {
        let lines = header.split(separator: "\n", omittingEmptySubsequences: false).map { "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\n\(body)\n".writeScript(to: spots.spotFile(name))
    }

    func waitFor(_ what: String, until condition: @escaping () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    var titles: [String] {
        model.openItems?.shown.map(\.title) ?? []
    }

    /// Opens a list whose row `a` opens its page, which shows one row named after the page.
    func openList() async throws {
        try script("list", header: "title=List\non=sheet.open\npages=*", """
        if [ -n "$OPENSPOT_PAGE" ]; then printf 'row=x\\ntitle=Detail %s\\n' "$OPENSPOT_PAGE"; else printf 'row=a\\ntitle=A\\npush=true\\n'; fi
        """)
        try script("other", header: "on=sheet.open", "printf 'row=o\\ntitle=Other\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("list")
        try await waitFor("the open list") { self.model.transition.phase == .open && self.titles == ["A"] }
    }

    func openPage() async throws {
        model.runSelectedItem()
        try await waitFor("the page") { self.titles == ["Detail a"] }
    }
}
