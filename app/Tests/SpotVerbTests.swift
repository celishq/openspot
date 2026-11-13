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
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
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
        host.app = "/Apps/Openspot.app/Contents/MacOS/Openspot"
        let trash = trash!
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
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

    private var spots: URL {
        folder.appendingPathComponent("spots", isDirectory: true)
    }

    private var trash: URL! {
        folder.appendingPathComponent("trash", isDirectory: true)
    }

    private func script(_ name: String, header: String = "", _ body: String = "echo") throws {
        let lines = header.split(separator: "\n").map { "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\n\(body)\n".writeScript(to: spots.spotFile(name))
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
        XCTAssertEqual(menu.rows.count, 5)
        let rows = menu.rows.filter { $0.action != nil }
        XCTAssertEqual(rows.map(\.title), ["Edit", "Copy prompt for AI", "Share", "Delete"])
        XCTAssertEqual(rows.map(\.keyLabel), ["⌘E", "", "⌘⇧C", "⌘⌫"])
    }

    func testARightOrForceClickOnACardOpensItsMenuAndTheClickThatEndsItRunsNothing() throws {
        try script("weather", header: "title=Weather")
        try script("clock", header: "title=Clock")
        model.reload()
        model.isShown = true
        let index = try XCTUnwrap(model.visible.firstIndex { $0.id == "weather" })
        let card = try XCTUnwrap(model.placements.first { $0.index == index }).rect

        let origin = SpotTokens.gridOrigin(scrollOffset: model.gridScroll)
        model.openMenu(at: CGPoint(x: origin.x + card.midX, y: origin.y + card.midY))
        model.tap("weather")

        XCTAssertEqual(model.selectedEntry?.id, "weather")
        XCTAssertEqual(model.menuTarget?.entry.id, "weather")
        XCTAssertEqual(model.menu?.selectedRow?.title, model.menu?.rows.first?.title)
    }

    func testTheMenuOpensSmallAndGrowsOnTheNextTurn() async throws {
        try script("weather", header: "title=Weather")
        _ = try select("weather")

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))

        XCTAssertEqual(model.menuSession?.phase, .opening)
        try await wait("the growth") { model.menuSession?.phase != .opening }
        XCTAssertEqual(host.motions.last, .sheet(isOpen: true))
        XCTAssertEqual(model.menuSession?.phase, .settled)
        let open = model.menu
        host.heldEnds = []
        model.closeMenu()
        XCTAssertNil(model.menu)
        XCTAssertEqual(model.menuSession?.menu, open)
        XCTAssertEqual(model.menuSession?.phase, .closing)
        XCTAssertEqual(host.motions.last, .sheet(isOpen: false))
        host.heldEnds?.forEach { $0() }
        XCTAssertNil(model.menuSession)
    }

    func testPointingAtAMenuRowSelectsIt() throws {
        try script("weather", header: "title=Weather")
        _ = try select("weather")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))

        model.point(at: .menuRow(2))

        XCTAssertEqual(model.menu?.selected, 2)
        XCTAssertNotNil(model.menu)
    }

    func testADragOfAForceClickHighlightsTheRowUnderItAndItsReleaseRunsThatRow() throws {
        try script("weather", header: "title=Weather")
        _ = try select("weather")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let menu = try XCTUnwrap(model.menu)
        let frame = ActionMenuFrame(item: CGRect(x: 90, y: 166, width: 64, height: 64), menu: menu, bounds: CGRect(x: 16, y: 166, width: 437, height: 500))
        model.placeMenu(frame)
        let row = { (index: Int) in CGPoint(x: frame.rect.midX, y: frame.rowRect(index, of: menu).midY) }

        model.dragMenu(to: row(1))
        XCTAssertEqual(model.menu?.selected, 1)
        model.releaseMenu(at: CGPoint(x: frame.rect.maxX + 40, y: row(1).y))
        XCTAssertNotNil(model.menu)

        model.dragMenu(to: row(2))
        model.releaseMenu(at: row(2))
        XCTAssertNil(model.menu)
    }

    func testPointingAtACardSelectsItUnlessAMenuIsOpenOrTheGridIsEdited() throws {
        try script("weather", header: "title=Weather")
        try script("clock", header: "title=Clock")
        _ = try select("weather")

        model.point(at: .card("clock"))
        XCTAssertEqual(model.selectedEntry?.id, "clock")

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        model.point(at: .card("weather"))
        XCTAssertEqual(model.selectedEntry?.id, "clock")
        model.closeMenu()

        model.beginEditing()
        model.point(at: .card("weather"))
        XCTAssertEqual(model.selectedEntry?.id, "clock")
    }

    func testTheCardOfTheOpenMenuIsFocusedAndTheOthersFaded() throws {
        try script("weather", header: "title=Weather")
        try script("clock", header: "title=Clock")
        _ = try select("weather")
        let weather = try XCTUnwrap(model.visible.firstIndex { $0.id == "weather" })
        let clock = try XCTUnwrap(model.visible.firstIndex { $0.id == "clock" })
        XCTAssertEqual(model.focus(ofCard: weather), .none)

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))

        XCTAssertEqual(model.focus(ofCard: weather), .focused)
        XCTAssertEqual(model.focus(ofCard: clock), .faded)
        model.closeMenu()
        XCTAssertEqual(model.focus(ofCard: clock), .none)
    }

    func testEditOpensTheFileInTheTextEditor() async throws {
        try script("weather")
        _ = try select("weather")
        XCTAssertTrue(model.handleKey(ActionKey(name: "e", isCommand: true)))
        try await wait("the editor") { saved("opened")?.hasPrefix("-t /") == true && saved("opened")?.hasSuffix("/spots/weather.spot/weather.sh\n") == true }
    }

    func testCopyPromptForAICopiesTheFileAndTheLastFailure() async throws {
        try script("ping", "echo 'Openspot cannot reach the server.' >&2; exit 1")
        let target = try select("ping")
        model.tap("ping")
        try await wait("the failure") { model.entries.first { $0.id == "ping" }?.failure != nil }

        model.run(CommandAction.copyPrompt, on: target)
        try await wait("the toast") { host.confirms.last == AgentPrompt.copied }

        let prompt = try XCTUnwrap(saved("clipboard"))
        XCTAssertTrue(prompt.contains(spots.spotFile("ping").path))
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
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.spotFile("weather").path))
        XCTAssertFalse(model.handleKey(ActionKey(name: "z", isCommand: true)))
    }

    func testACardOfAFileThatDoesNotLoadCanBeEditedAndDeleted() throws {
        try script("broken", header: "mode=huge")
        _ = try select("broken")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        XCTAssertEqual(model.menu?.rows.filter { $0.action != nil }.map(\.title), ["Edit", "Delete"])
        model.closeMenu()

        XCTAssertTrue(model.handleKey(ActionKey(name: "backspace", isCommand: true)))

        XCTAssertFalse(model.entries.contains { $0.id == "broken" })
        XCTAssertTrue(FileManager.default.fileExists(atPath: trash.appendingPathComponent("broken.spot").path))
    }
}
