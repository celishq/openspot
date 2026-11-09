import XCTest
@testable import OpenspotCore

/// Proves the acts that the app adds to each spot of the person: they open its file, copy a prompt for an agent, and delete
/// it so that `⌘Z` puts it back.
@MainActor
final class SpotVerbTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: TestHost!
    private var model: SpotsModel!
    private let path = ProcessInfo.processInfo.environment["PATH"]

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-verb-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        for (name, body) in [("pbcopy", "cat > '\(folder.path)/clipboard.new' && mv '\(folder.path)/clipboard.new' '\(folder.path)/clipboard'"), ("open", "echo \"$@\" > '\(folder.path)/opened'")] {
            try "#!/bin/sh\n\(body)\n".writeScript(to: tools.appendingPathComponent(name))
        }
        setenv("PATH", "\(tools.path):/usr/bin:/bin", 1)
        suite = "openspot-verb-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        host = TestHost()
        host.shipped = ShippedSpot.commands(folder: plugins, guide: folder.appendingPathComponent("GUIDE.md"), app: "/Apps/Openspot.app/Contents/MacOS/Openspot")
        let trash = trash!
        let files = SpotFiles(
            environment: ["OPENSPOT_PLUGINS": plugins.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
            home: folder,
            defaults: defaults,
            trash: { url in
                let place = trash.appendingPathComponent(url.lastPathComponent)
                try FileManager.default.moveItem(at: url, to: place)
                return place
            }
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2))
        host.model = model
    }

    override func tearDown() async throws {
        model.quit()
        if let path { setenv("PATH", path, 1) }
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    private var plugins: URL {
        folder.appendingPathComponent("plugins", isDirectory: true)
    }

    private var trash: URL! {
        folder.appendingPathComponent("trash", isDirectory: true)
    }

    private func script(_ name: String, header: String = "", _ body: String = "echo") throws {
        let lines = header.split(separator: "\n").map { "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\n\(body)\n".writeScript(to: plugins.appendingPathComponent("\(name).sh"))
    }

    private func wait(_ what: String, until condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    private func saved(_ name: String) -> String? {
        try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
    }

    /// Shows the panel with the card of this spot selected.
    private func select(_ id: String) throws -> SpotsModel.Target {
        model.reload()
        model.isShown = true
        let entry = try XCTUnwrap(model.entries.first { $0.id == id })
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == id })
        return (entry, nil)
    }

    func testTheMenuOfASpotOfThePersonOffersEachActWithItsKey() throws {
        try script("weather", header: "title=Weather")
        _ = try select("weather")

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))

        let menu = try XCTUnwrap(model.menu)
        XCTAssertEqual(menu.rows.count, 6)
        let rows = menu.rows.filter { $0.action != nil }
        XCTAssertEqual(rows.map(\.title), ["Edit", "Copy prompt for AI", "Share", "Delete"])
        XCTAssertEqual(rows.map(\.keyLabel), ["⌘E", "", "⌘⇧C", "⌘⌫"])
    }

    func testEditOpensTheFileInTheTextEditor() async throws {
        try script("weather")
        _ = try select("weather")
        XCTAssertTrue(model.handleKey(ActionKey(name: "e", isCommand: true)))
        try await wait("the editor") { saved("opened")?.hasPrefix("-t /") == true && saved("opened")?.hasSuffix("/plugins/weather.sh\n") == true }
    }

    func testCopyPromptForAICopiesTheFileAndTheLastFailure() async throws {
        try script("ping", "echo 'Openspot cannot reach the server.' >&2; exit 1")
        let target = try select("ping")
        model.tap("ping")
        try await wait("the failure") { model.entries.first { $0.id == "ping" }?.failure != nil }

        model.run(CommandAction.copyPrompt, on: target)
        try await wait("the toast") { host.confirms.last == AgentPrompt.copied }

        let prompt = try XCTUnwrap(saved("clipboard"))
        XCTAssertTrue(prompt.contains(plugins.appendingPathComponent("ping.sh").path))
        XCTAssertTrue(prompt.contains("Ask me what to change"))
        XCTAssertTrue(prompt.contains("Openspot cannot reach the server."))
    }

    func testDeleteAsksNothingKeepsThePanelAndCommandZPutsTheSpotBack() throws {
        try script("weather", header: "title=Weather")
        _ = try select("weather")

        XCTAssertTrue(model.handleKey(ActionKey(name: "backspace", isCommand: true)))

        XCTAssertNil(model.menu)
        XCTAssertFalse(model.entries.contains { $0.id == "weather" })
        XCTAssertEqual(host.dismissals, 0)
        XCTAssertEqual(host.confirms.last, "Moved Weather to the Trash. Press `⌘Z` to put it back.")

        XCTAssertTrue(model.handleKey(ActionKey(name: "z", isCommand: true)))

        XCTAssertEqual(model.selectedEntry?.id, "weather")
        XCTAssertTrue(FileManager.default.fileExists(atPath: plugins.appendingPathComponent("weather.sh").path))
        XCTAssertFalse(model.handleKey(ActionKey(name: "z", isCommand: true)))
    }

    func testACardOfAFileThatDoesNotLoadCanBeEditedAndDeleted() throws {
        try script("broken", header: "shortcut=??")
        _ = try select("broken")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        XCTAssertEqual(model.menu?.rows.filter { $0.action != nil }.map(\.title), ["Edit", "Delete"])
        model.closeMenu()

        XCTAssertTrue(model.handleKey(ActionKey(name: "backspace", isCommand: true)))

        XCTAssertFalse(model.entries.contains { $0.id == "broken" })
        XCTAssertTrue(FileManager.default.fileExists(atPath: trash.appendingPathComponent("broken.sh").path))
    }
}
