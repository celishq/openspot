import XCTest
@testable import OpenspotCore

/// Proves the acts that the app adds to each spot of the person: Edit opens the sheet where the person describes a change
/// for an agent, Share copies it, and Delete moves it so that `⌘Z` puts it back.
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
        let editor = [
            "#!/bin/sh", "# title=Change", "# on=sheet.open", "# edits=spots",
            "case \"$1\" in",
            "  read) printf 'grid=describe\\ngrid=copy\\n\\nfield=describe\\ntype=multiline\\n\\nbutton=copy\\ntitle=Copy prompt\\nlook=strong\\nshortcut=cmd+return\\n'",
            "    [ -z \"${OPENSPOT_EDIT_FILE-}\" ] || printf '\\nbutton=editor\\ntitle=Open in editor\\nscope=spot\\nclose=true\\n' ;;",
            "  copy) echo \"$OPENSPOT_EDIT|${OPENSPOT_EDIT_FILE-}|${OPENSPOT_EDIT_FAILURE-}\" >> '\(folder.path)/edits' ;;",
            "  editor) open -t \"$OPENSPOT_EDIT_FILE\" ;;",
            "esac"
        ]
        try editor.joined(separator: "\n").appending("\n").writeScript(to: core.appendingPathComponent("openspot.spot/change.sh"))
        try "#!/bin/sh\n# title=Cups\necho\n".writeScript(to: core.spotFile("cups"))
        let files = AppPlaces(
            environment: ["OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path, "OPENSPOT_CORE": core.path],
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

    private var core: URL {
        folder.appendingPathComponent("core", isDirectory: true)
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
        XCTAssertEqual(rows.map(\.title), ["Share", "Settings", "Edit", "Delete"])
        XCTAssertEqual(rows.map(\.keyLabel), ["⌘⇧C", "⌘⏎", "⌘E", "⌘⌫"])
        XCTAssertFalse(menu.rows.contains { $0.title == "Copy prompt for AI" })
    }

    func testTheFooterOfASpotOfThePersonLeavesEditToTheActionsMenu() throws {
        try script("weather", header: "title=Weather")
        try script("notes", header: "title=Notes\non=sheet.open")

        _ = try select("weather")
        XCTAssertEqual(model.hint, "⏎ Run   ⌘⏎ Settings   ⌘K Actions")
        _ = try select("notes")
        XCTAssertEqual(model.hint, "⏎ Open   ⌘⏎ Settings   ⌘K Actions")
        XCTAssertTrue(model.handleKey(ActionKey(name: "e", isCommand: true)))
    }

    func testCommandEOpensTheEditSheetOfTheSpotFromItsCardWithItsFileAndOpenInEditor() async throws {
        try script("weather", header: "title=Weather")
        _ = try select("weather")
        let sheet = OwnedSheet.edit.id(of: "weather")

        XCTAssertTrue(model.handleKey(ActionKey(name: "e", isCommand: true)))

        try await wait("the Edit sheet") { model.openList == sheet && model.openPanel != nil }
        XCTAssertEqual(model.openEntry?.state.title, "Edit Weather")
        XCTAssertEqual(SpotSheetCard.of(sheet, in: model)?.id, "weather")
        XCTAssertEqual(model.openPanel?.parts.map(\.id), ["describe", "copy"])
        XCTAssertEqual(model.hint, "⌘⏎ Copy prompt   ⌘K Actions")
        XCTAssertTrue(model.handleKey(ActionKey(name: "return", isCommand: true)))
        try await wait("the copy") { saved("edits") == "weather|\(spots.spotFile("weather").path)|\n" }

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let row = try XCTUnwrap(model.menu?.rows.firstIndex { $0.title == "Open in editor" })
        model.pressMenu(row: row)
        try await wait("the editor") { saved("opened") == "-t \(spots.spotFile("weather").path)\n" }
    }

    func testEditInTheMenuOpensTheEditSheetWithTheLastFailureOfTheSpot() async throws {
        try script("ping", "echo 'Openspot cannot reach the server.' >&2; exit 1")
        _ = try select("ping")
        model.tap("ping")
        try await wait("the failure") { model.entries.first { $0.id == "ping" }?.failure != nil }
        model.isShown = true

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        model.pressMenu(row: try XCTUnwrap(model.menu?.rows.firstIndex { $0.title == "Edit" }))
        try await wait("the Edit sheet") { model.openList == OwnedSheet.edit.id(of: "ping") && model.openPanel != nil }
        model.pressPart(try XCTUnwrap(model.openPanel?.parts.last))

        try await wait("the copy") { saved("edits")?.hasSuffix("|Openspot cannot reach the server.\n") == true }
        XCTAssertTrue(saved("edits")?.hasPrefix("ping|\(spots.spotFile("ping").path)|") == true)
    }

    func testACoreSpotHasEditWithNoFileToOpenAndASpotOfTheAppHasNone() async throws {
        try model.files.config.turn("cups", on: true)
        _ = try select("cups")

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let rows = try XCTUnwrap(model.menu?.rows.filter { $0.action != nil })
        XCTAssertEqual(rows.map(\.title), ["Share", "Settings", "Edit", "Turn off"])
        XCTAssertEqual(rows.first { $0.title == "Edit" }?.keyLabel, "⌘E")
        model.closeMenu()
        XCTAssertTrue(model.handleKey(ActionKey(name: "e", isCommand: true)))
        try await wait("the Edit sheet") { model.openList == OwnedSheet.edit.id(of: "cups") && model.openPanel != nil }
        model.pressPart(try XCTUnwrap(model.openPanel?.parts.last))
        try await wait("the copy") { saved("edits") == "cups||\n" }
        _ = model.handleKey(ActionKey(name: "k", isCommand: true))
        XCTAssertNil(model.menu?.rows.first { $0.title == "Open in editor" })
        model.closeMenu()
        model.closeList(moving: false)

        let change = try XCTUnwrap(model.entries.first { $0.spot.editsSpots })
        XCTAssertFalse(model.openEdit(of: change))
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == change.id })
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        XCTAssertFalse(model.menu?.rows.contains { $0.title == "Edit" } ?? false)
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
