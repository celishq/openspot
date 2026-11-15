import XCTest
@testable import OpenspotCore

@MainActor
final class SpotVerbTests: XCTestCase {
    private struct ModelApp: RunningApp {
        let model: SpotsModel

        func act(_ act: CardAct, on id: String) async -> Bool { await model.act(act, on: id) }
        func configChanged(_ change: ConfigChange) async { await model.configChanged(change) }
        func status() async -> (update: String?, calls: Int, isFirstLaunch: Bool) { (nil, 0, false) }
        func checkUpdate() async -> Bool { false }
        func installUpdate() async -> Bool { false }
        func quit() async {}
        func open(_ id: String) async -> Bool { false }
        func push(_ id: String, page: String?, title: String?, replace: Bool) async -> Bool { false }
        func pop(_ id: String, all: Bool) async -> Bool { false }
        func review(_ id: String) async -> Bool { false }
        func choose(for id: String) async -> Bool { false }
        func editGrid() async {}
        func publish(_ id: String) async -> SpotPublish { .notOwn }
        func reveal(_ id: String) async -> Bool { false }
        func sandbox(_ file: URL?, isCareful: Bool) async {}
        func changeSetting(_ key: String, of spot: String) async -> Bool { false }
        func allows(_ reason: String) async -> Bool { false }
    }

    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: FakeHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-verb-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        for (name, body) in [("pbcopy", "cat > '\(folder.path)/clipboard.new' && mv '\(folder.path)/clipboard.new' '\(folder.path)/clipboard'"), ("open", "echo \"$@\" > '\(folder.path)/opened'")] {
            try "#!/bin/sh\n\(body)\n".writeScript(to: tools.appendingPathComponent(name))
        }
        suite = "openspot-verb-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        host = FakeHost()
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
        for name in ["actions.js", "icon.sh", "icon.swift"] {
            try FileManager.default.createSymbolicLink(at: core.appendingPathComponent("openspot.spot/\(name)"), withDestinationURL: repoSpots.appendingPathComponent("openspot.spot/\(name)"))
        }
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
        model = SpotsModel(host: host, files: files, runs: SpotRuns(environment: ProcessInfo.processInfo.environment.merging(["PATH": "\(tools.path):/usr/bin:/bin"]) { _, new in new }, stopPause: 0.2))
        host.model = model
        model.runs.api = CommandAPI(mac: FakeMac(opens: false), app: ModelApp(model: model), runs: model.runs)
    }

    override func tearDown() async throws {
        model.quit()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    private var repoSpots: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots")
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
        try TestSpot(header: header, body: "\(body)").write(to: spots.spotFile(name))
    }

    private func saved(_ name: String) -> String? {
        try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
    }

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
        XCTAssertEqual(rows.map(\.title), ["Share", "Settings", "Edit", "Change Icon", "Delete"])
        XCTAssertEqual(rows.map(\.keyLabel), ["⌘⇧C", "⌘⏎", "⌘E", "›", "⌘⌫"])
        XCTAssertEqual(rows.first { $0.title == "Change Icon" }?.children.map(\.title), ["Draw…", "Choose File…"])
        XCTAssertEqual(rows.map(\.isDestructive), [false, false, false, false, true])
        XCTAssertEqual(menu.headers.map(\.title), [])
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
        XCTAssertEqual(rows.map(\.title), ["Share", "Settings", "Edit", "Change Icon", "Turn off"])
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

    func testAnActionThatASpotOffersShowsInEachCardsMenuAndRunsThatSpotWithTheCardsID() async throws {
        let calls = folder.appendingPathComponent("calls").path
        try script("weather", header: "title=Weather")
        try "#!/bin/sh\n# title=Stars\n#\n# button=star\n# title=Star\n# offers=actions\necho \"$@\" >> '\(calls)'\n".writeScript(to: spots.spotFile("stars"))
        _ = try select("weather")

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let menu = try XCTUnwrap(model.menu)
        XCTAssertEqual(menu.rows.dropFirst().map(\.title), ["Share", "Settings", "Edit", "Change Icon", "Delete", "Star"])
        XCTAssertEqual(menu.headers.map(\.title), ["Stars"])
        model.menu?.select(try XCTUnwrap(menu.rows.last?.action))
        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))

        try await wait("the call of the stars spot") { saved("calls") != nil }
        XCTAssertEqual(saved("calls"), "star weather\n")
    }

    func testTheSheetOfTheIconSpotOpensThoughItHasNoCard() throws {
        try script("weather", header: "title=Weather")
        model.reload()

        XCTAssertTrue(model.push(FlowSheet(spot: "openspot/icon")))

        XCTAssertEqual(model.openList, "openspot/icon")
    }

    func testFilesAreAskedForOnlyForASpotThatTakesThem() throws {
        try script("weather", header: "title=Weather")
        model.reload()

        XCTAssertTrue(model.chooseFiles(for: "openspot/icon"))
        XCTAssertFalse(model.chooseFiles(for: "weather"))
        XCTAssertFalse(model.chooseFiles(for: "gone"))
    }

    func testAHookOfAJavaScriptSpotShowsAnActionOnlyOnTheCardsItSaysYesTo() async throws {
        try script("weather", header: "title=Weather")
        try script("notes", header: "title=Notes")
        let tools = spots.spotFile("tools", extension: "js")
        try FileManager.default.createDirectory(at: tools.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "// title=Tools\n//\n// button=star\n// title=Star\n// offers=actions\n// when=isWeather\n//\n// button=mark\n// title=Mark\n// offers=actions\n// when=always\nfunction isWeather(id, origin) { return id === \"weather\" && origin === \"mine\" }\nfunction always() { return true }\n".write(to: tools, atomically: true, encoding: .utf8)
        let titles = { self.model.menu?.rows.map(\.title) ?? [] }

        _ = try select("notes")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        try await wait("the yes of the second hook on notes") { titles().contains("Mark") }
        let notes = titles()
        model.closeMenu()
        _ = try select("weather")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        try await wait("the yes of both hooks on weather") { titles().contains("Mark") && titles().contains("Star") }

        XCTAssertFalse(notes.contains("Star"))
        XCTAssertEqual(Array(titles().suffix(2)), ["Star", "Mark"])
    }

    func testASlowHookLeavesTheMenuOpenAtOnceAndItsLateYesJoinsIt() async throws {
        try script("weather", header: "title=Weather")
        let slow = spots.spotFile("slow", extension: "js")
        try FileManager.default.createDirectory(at: slow.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "// title=Slow\n//\n// button=late\n// title=Late\n// offers=actions\n// when=late\nfunction late() { const end = Date.now() + 300; while (Date.now() < end) {} return true }\n".write(to: slow, atomically: true, encoding: .utf8)
        _ = try select("weather")

        let start = Date()
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let opened = Date().timeIntervalSince(start)
        let first = model.menu?.rows.map(\.title) ?? []
        try await wait("the late yes of the slow hook") { model.menu?.rows.contains { $0.title == "Late" } == true }

        XCTAssertLessThan(opened, 0.2)
        XCTAssertFalse(first.contains("Late"))
    }

    func testTheSubmenuShowsBesideItsRowUntilBackOrTheMenusClose() throws {
        try script("weather", header: "title=Weather")
        _ = try select("weather")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let menu = try XCTUnwrap(model.menu)
        let frame = ActionMenuFrame(item: CGRect(x: 20, y: 120, width: 60, height: 60), menu: menu, bounds: ActionMenuFrame.bounds(under: 80))
        model.placeMenu(frame)
        let parent = try XCTUnwrap(menu.shown.firstIndex { $0.title == "Change Icon" })
        model.menu?.select(try XCTUnwrap(menu.shown[parent].action))

        XCTAssertTrue(model.handleKey(ActionKey(name: "right")))
        let shown = host.submenus
        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))
        let selected = model.menu?.selectedRow?.title
        XCTAssertTrue(model.handleKey(ActionKey(name: "left")))
        model.pressMenu(row: parent)
        model.closeMenu()

        XCTAssertEqual(shown, [frame.rowRect(parent, of: menu)])
        XCTAssertEqual(selected, "Choose File…")
        XCTAssertEqual(host.submenus, [frame.rowRect(parent, of: menu), nil, frame.rowRect(parent, of: menu), nil])
    }

    func testTheIconSettingOfASpotWinsOverItsHeaderIconUntilItIsRemoved() throws {
        try script("weather", header: "title=Weather\nicon=cloud")
        let drawn = folder.appendingPathComponent("drawn.svg").path

        try model.files.config.set(setting: "icon", of: "weather", to: drawn)
        model.reload()
        let changed = try XCTUnwrap(model.entries.first { $0.id == "weather" }?.spot)
        try model.files.config.set(setting: "icon", of: "weather", to: nil)
        model.reload()
        let back = try XCTUnwrap(model.entries.first { $0.id == "weather" }?.spot)

        XCTAssertEqual([changed.image, changed.headerSymbol], [drawn, nil])
        XCTAssertEqual([back.image, back.headerSymbol], [nil, "cloud"])
    }

    func testEachActOfTheAPIDoesWhatTheCardsRowDidAndANameOfNoCardDoesNothing() async throws {
        try script("weather", header: "title=Weather")
        model.reload()

        XCTAssertTrue(model.act(.settings, on: "weather"))
        try await wait("the Settings sheet") { model.openList == SpotSettings.sheetID(of: "weather") }
        XCTAssertTrue(model.act(.edit, on: "weather"))
        try await wait("the Edit sheet") { model.openList == OwnedSheet.edit.id(of: "weather") }
        XCTAssertTrue(model.act(.delete, on: "weather"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: spots.spotFile("weather").path))
        XCTAssertTrue(model.handleKey(ActionKey(name: "z", isCommand: true)))
        XCTAssertFalse(model.act(.edit, on: "gone"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.spotFile("weather").path))
    }

    func testARightOrForceClickOnACardOpensItsMenuAndTheClickThatEndsItRunsNothing() throws {
        try script("weather", header: "title=Weather")
        try script("clock", header: "title=Clock")
        model.reload()
        model.isShown = true
        let index = try XCTUnwrap(model.visible.firstIndex { $0.id == "weather" })
        let card = try XCTUnwrap(model.placements.first { $0.index == index }).rect

        let origin = model.gridOrigin
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

    func testCopyPromptForAICopiesTheFileAndTheLastFailure() async throws {
        try script("ping", "echo 'Openspot cannot reach the server.' >&2; exit 1")
        let target = try select("ping")
        model.tap("ping")
        try await wait("the failure") { model.entries.first { $0.id == "ping" }?.failure != nil }

        _ = target
        XCTAssertTrue(model.act(.prompt, on: "ping"))
        try await wait("the toast") { host.confirms.last == AgentPrompt.copied }

        let prompt = try XCTUnwrap(saved("clipboard"))
        XCTAssertTrue(prompt.contains(spots.spotFile("ping").path))
        XCTAssertTrue(prompt.contains("Ask me what to change"))
        XCTAssertTrue(prompt.contains("Openspot cannot reach the server."))
    }

    func testDeleteAsksNothingKeepsThePanelAndCommandZPutsTheSpotBack() async throws {
        try script("weather", header: "title=Weather")
        _ = try select("weather")

        XCTAssertTrue(model.handleKey(ActionKey(name: "backspace", isCommand: true)))
        try await wait("the delete") { !model.entries.contains { $0.id == "weather" } }

        XCTAssertNil(model.menu)
        XCTAssertEqual(host.dismissals, 0)
        XCTAssertEqual(host.confirms.last, "Moved Weather to the Trash. Press `⌘Z` to put it back.")

        XCTAssertTrue(model.handleKey(ActionKey(name: "z", isCommand: true)))

        XCTAssertEqual(model.selectedEntry?.id, "weather")
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.spotFile("weather").path))
        XCTAssertFalse(model.handleKey(ActionKey(name: "z", isCommand: true)))
    }

    func testACardOfAFileThatDoesNotLoadIsThePersonsAndCanBeDeleted() async throws {
        try script("broken", header: "mode=huge")
        _ = try select("broken")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        XCTAssertEqual(model.menu?.rows.filter { $0.action != nil }.map(\.title), ["Share", "Settings", "Edit", "Change Icon", "Delete"])
        model.closeMenu()

        XCTAssertTrue(model.handleKey(ActionKey(name: "backspace", isCommand: true)))
        try await wait("the delete") { !model.entries.contains { $0.id == "broken" } }

        XCTAssertTrue(FileManager.default.fileExists(atPath: trash.appendingPathComponent("broken.spot").path))
    }
}
