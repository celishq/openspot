import XCTest
@testable import OpenspotCore

@MainActor
final class SpotVerbTests: XCTestCase {
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
            "#!/bin/sh",
            "case \"$1\" in",
            "  show) printf 'frame=\\nclass=gap-part\\n\\nfield=describe\\ntype=multiline\\n\\nbutton=copy\\ntitle=Copy prompt\\nlook=strong\\nshortcut=cmd+return\\nclose=false\\n'",
            "    [ -z \"${OPENSPOT_EDIT_FILE-}\" ] || printf '\\nbutton=editor\\ntitle=Open in editor\\nscope=spot\\n' ;;",
            "  copy) echo \"$OPENSPOT_EDIT|${OPENSPOT_EDIT_FILE-}|${OPENSPOT_EDIT_FAILURE-}\" >> '\(folder.path)/edits' ;;",
            "  editor) open -t \"$OPENSPOT_EDIT_FILE\" ;;",
            "esac"
        ]
        let app = core.appendingPathComponent("openspot.spot")
        try editor.joined(separator: "\n").appending("\n").writeScript(to: app.appendingPathComponent("change.sh"), toml: "title = 'Change'\nedits = 'spots'")
        try actions.writeInline(to: app.appendingPathComponent("actions.js"), toml: actionsToml)
        try icon.writeScript(to: app.appendingPathComponent("icon.sh"), toml: "title = 'Icon'\nicon = 'paintbrush.pointed'\nviews = ['drawer.swift']\nuses = ['spots']\n\n[actions.draw]\ninputs.spot = { type = 'text', required = true }\n\n[on]\ndrop = [\"png\", \"svg\"]")
        try "import SwiftUI\n\nstruct SpotView: View {\n    let spot: SpotInput\n\n    var body: some View {\n        Color.clear\n    }\n}\n".write(to: app.appendingPathComponent("drawer.swift"), atomically: true, encoding: .utf8)
        try "#!/bin/sh\necho\n".writeScript(to: core.spotFile("cups"), toml: "title = 'Cups'")
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
        model.runs.api = CommandAPI(mac: Mac(), places: files, app: ModelApp(model: model), runs: model.runs)
    }

    override func tearDown() async throws {
        model.quit()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    private let actions = """
        const calls = {
          settings: (id) => ["spot", "settings", id],
          edit: (id) => ["spot", "edit", id],
          share: (id) => ["spot", "share", id],
          delete: (id) => ["spot", "delete", id],
          off: (id) => ["setting", "set", "--spot", id, "enabled", "false"],
          "icon.draw": (id) => ["spot", "run", "openspot/icon", "draw", `spot=${id}`],
          "icon.file": (id) => ["spot", "run", "openspot/icon", "file", `spot=${id}`],
        };

        export default {
          ...Object.fromEntries(Object.keys(calls).map((act) => [act, async ({ item }) => { openspot.call(calls[act](item)) }])),
          hasIcon() {
            return "";
          },
        };

        """

    private let actionsToml = """
        title = 'Card actions'
        icon = 'ellipsis.circle'
        uses = ['spots']
        [actions.share]
        title = 'Share'
        shortcut = 'cmd+shift+c'
        offers = ['actions mine, core']
        [actions.settings]
        title = 'Settings'
        shortcut = 'cmd+return'
        close = false
        offers = ['actions']
        [actions.edit]
        title = 'Edit'
        shortcut = 'cmd+e'
        close = false
        offers = ['actions mine, core']
        [actions.icon]
        title = 'Change Icon'
        offers = ['actions']
        [actions."icon.draw"]
        title = 'Draw…'
        close = false
        [actions."icon.file"]
        title = 'Choose File…'
        close = false
        [actions."icon.reset"]
        title = 'Reset Icon'
        close = false
        when = 'hasIcon'
        [actions.delete]
        title = 'Delete'
        shortcut = 'cmd+backspace'
        close = false
        offers = ['actions mine']
        [actions.off]
        title = 'Turn off'
        shortcut = 'cmd+backspace'
        offers = ['actions core']
        """

    private var icon: String {
        """
        #!/bin/sh
        case "$1" in
          draw) sed -n 's/^input\\.spot=//p' > '\(folder.path)/drawn' ;;
          show) printf 'frame=\\ntitle=Icon\\nclass=grid grid-cols-2 gap-part\\n\\ndrawer=drawer\\nclass=col-span-2\\ndots=.\\n\\nbutton=clear\\ntitle=Clear\\nclose=false\\n\\nbutton=save\\ntitle=Save\\nshortcut=return\\nlook=strong\\n' ;;
        esac

        """
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

    private func script(_ name: String, toml: String = "", _ body: String = "echo") throws {
        try TestSpot(toml: toml, body: "\(body)").write(to: spots.spotFile(name))
    }

    private func saved(_ name: String) -> String? {
        try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
    }

    private func select(_ id: String) async throws -> SpotsModel.Target {
        await model.reload()
        model.isShown = true
        let entry = try XCTUnwrap(model.entries.first { $0.id == id })
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == id })
        return (entry, nil)
    }

    func testTheMenuOfASpotOfThePersonOffersEachActWithItsKey() async throws {
        try script("weather", toml: "title = 'Weather'")
        _ = try await select("weather")

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))

        let menu = try XCTUnwrap(model.menu)
        XCTAssertEqual(menu.rows.count, 6)
        let rows = menu.rows.filter { $0.action != nil }
        XCTAssertEqual(rows.map(\.title), ["Share", "Settings", "Edit", "Change Icon", "Delete"])
        XCTAssertEqual(rows.map(\.keyLabel), ["⇧⌘C", "⌘⏎", "⌘E", "›", "⌘⌫"])
        XCTAssertEqual(rows.first { $0.title == "Change Icon" }?.children.map(\.title), ["Draw…", "Choose File…"])
        XCTAssertEqual(rows.map(\.isDestructive), [false, false, false, false, true])
        XCTAssertEqual(menu.headers.map(\.title), [])
        XCTAssertFalse(menu.rows.contains { $0.title == "Copy prompt for AI" })
    }

    func testTheFooterOfASpotOfThePersonLeavesEditToTheActionsMenu() async throws {
        try script("weather", toml: "title = 'Weather'")
        try script("notes", toml: "title = 'Notes'")

        _ = try await select("weather")
        XCTAssertEqual(model.hint, "⏎ Open   ⌘⏎ Settings   ⌘K Actions")
        _ = try await select("notes")
        XCTAssertEqual(model.hint, "⏎ Open   ⌘⏎ Settings   ⌘K Actions")
        XCTAssertTrue(model.handleKey(ActionKey(name: "e", isCommand: true)))
    }

    func testCommandEOpensTheEditSheetOfTheSpotFromItsCardWithItsFileAndOpenInEditor() async throws {
        try script("weather", toml: "title = 'Weather'")
        _ = try await select("weather")
        let sheet = OwnedSheet.edit.id(of: "weather")

        XCTAssertTrue(model.handleKey(ActionKey(name: "e", isCommand: true)))

        try await wait("the Edit sheet") { model.openSheetID == sheet && model.openParts != nil }
        XCTAssertEqual(model.openEntry?.state.title, "Edit Weather")
        XCTAssertEqual(SpotSheetCard.of(sheet, in: model)?.id, "weather")
        XCTAssertEqual(model.openParts?.parts.map(\.id), ["describe", "copy"])
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
        _ = try await select("ping")
        model.tap("ping")
        try await wait("the failure") { model.entries.first { $0.id == "ping" }?.failure != nil }
        model.closeSheet(moving: false)
        model.isShown = true

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        model.pressMenu(row: try XCTUnwrap(model.menu?.rows.firstIndex { $0.title == "Edit" }))
        try await wait("the Edit sheet") { model.openSheetID == OwnedSheet.edit.id(of: "ping") && model.openParts != nil }
        model.pressPart(try XCTUnwrap(model.openParts?.parts.last))

        try await wait("the copy") { saved("edits")?.hasSuffix("|Openspot cannot reach the server.\n") == true }
        XCTAssertTrue(saved("edits")?.hasPrefix("ping|\(spots.spotFile("ping").path)|") == true)
    }

    func testTurnOffInTheMenuOfACardRunsTheHandlerOfTheRealActionsAndTurnsTheSpotOff() async throws {
        let real = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots/openspot.spot/actions.js")
        try String(contentsOf: real, encoding: .utf8).writeInline(to: core.appendingPathComponent("openspot.spot/actions.js"), toml: actionsToml)
        try model.files.config.turn("cups", on: true)
        _ = try await select("cups")

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        model.pressMenu(row: try XCTUnwrap(model.menu?.rows.firstIndex { $0.title == "Turn off" }))

        try await wait("the spot turned off") { model.files.config.read().arrangement.disabled.contains("cups") }
    }

    func testAnInlineHandlerOfTheAppRunsIconThroughABinding() async throws {
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: folder.appendingPathComponent("tools/openspot"))
        let app = core.appendingPathComponent("openspot.spot")
        let real = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots/openspot.spot/icon.sh")
        try String(contentsOf: real, encoding: .utf8).writeScript(
            to: app.appendingPathComponent("icon.sh"), toml: "title = 'Icon'\nuses = ['spots']\n[on]\n\"sheet.open\" = true\n[actions.draw]\ninputs.spot = { type = 'text', required = true }"
        )
        let actions = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots/openspot.spot/actions.js")
        try String(contentsOf: actions, encoding: .utf8).writeInline(to: app.appendingPathComponent("actions.js"), toml: actionsToml + "\n[bindings]\nicon = { spot = 'openspot/icon' }")
        try model.files.config.turn("cups", on: true)
        let target = try await select("cups")
        let draw = try XCTUnwrap(model.runs.sheets["openspot/actions"]?.spot.offeredActions.first { $0.action.id == "icon.draw" }?.action)

        model.run(draw, offeredBy: "openspot/actions", on: target)

        try await wait("the sheet of the icon") { model.openSheetID == "openspot/icon" }
    }

    func testACoreSpotHasEditWithNoFileToOpenAndASpotOfTheAppHasNone() async throws {
        try model.files.config.turn("cups", on: true)
        _ = try await select("cups")

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let rows = try XCTUnwrap(model.menu?.rows.filter { $0.action != nil })
        XCTAssertEqual(rows.map(\.title), ["Share", "Settings", "Edit", "Change Icon", "Turn off"])
        XCTAssertEqual(rows.first { $0.title == "Edit" }?.keyLabel, "⌘E")
        model.closeMenu()
        XCTAssertTrue(model.handleKey(ActionKey(name: "e", isCommand: true)))
        try await wait("the Edit sheet") { model.openSheetID == OwnedSheet.edit.id(of: "cups") && model.openParts != nil }
        model.pressPart(try XCTUnwrap(model.openParts?.parts.last))
        try await wait("the copy") { saved("edits") == "cups||\n" }
        _ = model.handleKey(ActionKey(name: "k", isCommand: true))
        XCTAssertNil(model.menu?.rows.first { $0.title == "Open in editor" })
        model.closeMenu()
        model.closeSheet(moving: false)

        let change = try XCTUnwrap(model.entries.first { $0.spot.editsSpots })
        XCTAssertFalse(model.openEdit(of: change))
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == change.id })
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        XCTAssertFalse(model.menu?.rows.contains { $0.title == "Edit" } ?? false)
    }

    func testAnActionThatASpotOffersShowsInEachCardsMenuAndRunsThatSpotWithTheCardsID() async throws {
        let calls = folder.appendingPathComponent("calls").path
        try script("weather", toml: "title = 'Weather'")
        try "#!/bin/sh\necho \"$1 $(sed -n 's/^input\\.item=//p')\" >> '\(calls)'\n".writeScript(to: core.appendingPathComponent("openspot.spot/stars.sh"), toml: "title = 'Stars'\n\n[actions.star]\ntitle = 'Star'\noffers = ['actions']")
        _ = try await select("weather")

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let menu = try XCTUnwrap(model.menu)
        XCTAssertEqual(menu.rows.dropFirst().map(\.title), ["Share", "Settings", "Edit", "Change Icon", "Delete", "Star"])
        XCTAssertEqual(menu.headers.map(\.title), [])
        model.menu?.select(try XCTUnwrap(menu.rows.last?.action))
        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))

        try await wait("the call of the stars spot") { saved("calls") != nil }
        XCTAssertEqual(saved("calls"), "star weather\n")
    }

    func testAnOfferedActionClosesThePanelUnlessItHasCloseFalse() async throws {
        let calls = folder.appendingPathComponent("calls").path
        try script("weather", toml: "title = 'Weather'")
        try "#!/bin/sh\necho \"$1 $(sed -n 's/^input\\.item=//p')\" >> '\(calls)'\n".writeScript(to: core.appendingPathComponent("openspot.spot/stars.sh"), toml: "title = 'Stars'\n\n[actions.star]\ntitle = 'Star'\nclose = false\noffers = ['actions']\n[actions.mark]\ntitle = 'Mark'\noffers = ['actions']")
        _ = try await select("weather")

        for title in ["Star", "Mark"] {
            XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
            model.menu?.select(try XCTUnwrap(model.menu?.rows.first { $0.title == title }?.action))
            XCTAssertTrue(model.handleKey(ActionKey(name: "return")))
            try await wait("the call of \(title)") { saved("calls")?.contains(title.lowercased()) == true }
            try await wait("the menu closed") { model.menu == nil }
            XCTAssertEqual(host.dismissals, title == "Star" ? 0 : 1)
        }
    }

    func testAMenuRowThatAnotherSpotRunsKeepsTheMenuUntilItsRunEnds() async throws {
        let gate = folder.appendingPathComponent("gate").path
        try script("weather", toml: "title = 'Weather'")
        try "#!/bin/sh\n[ \"$1\" = star ] && touch '\(gate).run' && while [ ! -f '\(gate)' ]; do sleep 0.01; done; true\n".writeScript(to: core.appendingPathComponent("openspot.spot/stars.sh"), toml: "title = 'Stars'\n\n[actions.star]\ntitle = 'Star'\nclose = false\noffers = ['actions']")
        _ = try await select("weather")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let row = try XCTUnwrap(model.menu?.rows.last)
        model.menu?.select(try XCTUnwrap(row.action))

        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))
        try await wait("the run of the star") { FileManager.default.fileExists(atPath: gate + ".run") }
        XCTAssertNotNil(model.menu)

        try Data().write(to: URL(fileURLWithPath: gate))
        try await wait("the close at the end of the run") { model.menu == nil }
    }

    func testDrawInTheMenuRunsTheDrawOfTheIconSpotWithTheSpotOfTheCard() async throws {
        try script("weather", toml: "title = 'Weather'")
        _ = try await select("weather")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let menu = try XCTUnwrap(model.menu)
        model.menu?.select(try XCTUnwrap(menu.shown.first { $0.title == "Change Icon" }?.action))
        XCTAssertTrue(model.handleKey(ActionKey(name: "right")))
        XCTAssertEqual(model.menu?.selectedRow?.title, "Draw…")

        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))

        try await wait("the draw") { saved("drawn") == "weather\n" }
    }

    func testTheSheetOfTheIconSpotOpensThoughItHasNoCard() async throws {
        try script("weather", toml: "title = 'Weather'")
        await model.reload()

        XCTAssertTrue(model.push(FlowSheet(spot: "openspot/icon")))

        XCTAssertEqual(model.openSheetID, "openspot/icon")
    }

    func testFilesAreAskedForOnlyForASpotThatTakesThem() async throws {
        try script("weather", toml: "title = 'Weather'")
        await model.reload()

        XCTAssertTrue(model.chooseFiles(for: "openspot/icon"))
        XCTAssertFalse(model.chooseFiles(for: "weather"))
        XCTAssertFalse(model.chooseFiles(for: "gone"))
    }

    func testAHookOfAJavaScriptSpotShowsAnActionOnlyOnTheCardsItSaysYesTo() async throws {
        try script("weather", toml: "title = 'Weather'")
        try script("notes", toml: "title = 'Notes'")
        let tools = core.appendingPathComponent("openspot.spot/tools.js")
        try FileManager.default.createDirectory(at: tools.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "export default { isWeather({ item, origin }) { return item === \"weather\" && origin === \"mine\" }, always() { return true } }\n".writeInline(to: tools, toml: "title = 'Tools'\n\n[actions.star]\ntitle = 'Star'\noffers = ['actions']\nwhen = 'isWeather'\n[actions.mark]\ntitle = 'Mark'\noffers = ['actions']\nwhen = 'always'")
        let titles = { self.model.menu?.rows.map(\.title) ?? [] }

        _ = try await select("notes")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        try await wait("the yes of the second hook on notes") { titles().contains("Mark") }
        let notes = titles()
        model.closeMenu()
        _ = try await select("weather")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        try await wait("the yes of both hooks on weather") { titles().contains("Mark") && titles().contains("Star") }

        XCTAssertFalse(notes.contains("Star"))
        XCTAssertEqual(Array(titles().suffix(2)), ["Star", "Mark"])
    }

    func testASlowHookLeavesTheMenuOpenAtOnceAndItsLateYesJoinsIt() async throws {
        try script("weather", toml: "title = 'Weather'")
        let slow = core.appendingPathComponent("openspot.spot/slow.js")
        try FileManager.default.createDirectory(at: slow.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "export default { late() { const end = Date.now() + 300; while (Date.now() < end) {} return true } }\n".writeInline(to: slow, toml: "title = 'Slow'\n\n[actions.late]\ntitle = 'Late'\noffers = ['actions']\nwhen = 'late'")
        _ = try await select("weather")

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let first = model.menu?.rows.map(\.title) ?? []
        try await wait("the late yes of the slow hook") { model.menu?.rows.contains { $0.title == "Late" } == true }

        XCTAssertFalse(first.isEmpty)
        XCTAssertFalse(first.contains("Late"))
    }

    func testTheSubmenuShowsBesideItsRowUntilBackOrTheMenusClose() async throws {
        try script("weather", toml: "title = 'Weather'")
        _ = try await select("weather")
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

    func testTheIconSettingOfASpotWinsOverItsHeaderIconUntilItIsRemoved() async throws {
        try script("weather", toml: "title = 'Weather'\nicon = 'cloud'")
        let drawn = folder.appendingPathComponent("drawn.svg").path

        try model.files.config.set(setting: "icon", of: "weather", to: drawn)
        await model.reload()
        let changed = try XCTUnwrap(model.entries.first { $0.id == "weather" }?.spot)
        try model.files.config.set(setting: "icon", of: "weather", to: nil)
        await model.reload()
        let back = try XCTUnwrap(model.entries.first { $0.id == "weather" }?.spot)

        XCTAssertEqual([changed.image, changed.headerSymbol], [drawn, nil])
        XCTAssertEqual([back.image, back.headerSymbol], [nil, "cloud"])
    }

    func testEachActOfTheAPIDoesWhatTheCardsRowDidAndANameOfNoCardDoesNothing() async throws {
        try script("weather", toml: "title = 'Weather'")
        await model.reload()

        XCTAssertTrue(model.act(.settings, on: "weather"))
        try await wait("the Settings sheet") { model.openSheetID == SpotSettings.sheetID(of: "weather") }
        XCTAssertTrue(model.act(.edit, on: "weather"))
        try await wait("the Edit sheet") { model.openSheetID == OwnedSheet.edit.id(of: "weather") }
        XCTAssertTrue(model.act(.delete, on: "weather"))
        try await wait("the toast of the removal") { self.host.confirms.contains { $0.hasPrefix("Moved Weather to the Trash") } }
        XCTAssertFalse(FileManager.default.fileExists(atPath: spots.spotFile("weather").path))
        XCTAssertFalse(model.act(.edit, on: "gone"))
    }

    func testTheSecretOfARemovedSpotGoesWithIt() async throws {
        try script("weather", toml: "title = 'Weather'\n\n[settings]\ntoken = { type = 'secret' }")
        try script("clock", toml: "title = 'Clock'\n\n[settings]\ntoken = { type = 'secret' }")
        try model.files.secrets.keep("weather-secret", key: "token", of: "weather")
        try model.files.secrets.keep("clock-secret", key: "token", of: "clock")
        await model.reload()

        XCTAssertTrue(model.act(.delete, on: "weather"))
        try await wait("the toast of the removal") { self.host.confirms.contains { $0.hasPrefix("Moved Weather to the Trash") } }

        XCTAssertEqual(try SecretStore(file: model.files.secrets.file).read(), ["clock": ["token": "clock-secret"]])
    }

    func testTheFormOfASecretKeepsItInTheStoreNotTheConfigAndRefusesAShortOne() async throws {
        try script("weather", toml: "title = 'Weather'\n\n[settings]\ntoken = { type = 'secret' }")
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        XCTAssertTrue(model.changeSetting("token", of: "weather"))
        let field = model.form?.draft.form.fields.first
        model.setFormValue("1234567", for: "token")
        model.submitForm()
        let short = host.notes.last
        let kept = try SecretStore(file: model.files.secrets.file).read()
        model.setFormValue("12345678", for: "token")
        model.submitForm()
        try await wait("the kept secret") { model.form == nil }

        XCTAssertEqual(field?.type, .secret)
        XCTAssertEqual(short, "Openspot didn't keep this secret, because it is shorter than 8 characters. Type the whole value.")
        XCTAssertEqual(kept, [:])
        XCTAssertNil(model.form)
        XCTAssertEqual(try SecretStore(file: model.files.secrets.file).read(), ["weather": ["token": "12345678"]])
        XCTAssertFalse((try? String(contentsOf: model.files.config.url, encoding: .utf8))?.contains("12345678") ?? false)
    }

    func testARightOrForceClickOnACardOpensItsMenuAndTheClickThatEndsItRunsNothing() async throws {
        try script("weather", toml: "title = 'Weather'")
        try script("clock", toml: "title = 'Clock'")
        await model.reload()
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
        try script("weather", toml: "title = 'Weather'")
        _ = try await select("weather")

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

    func testPointingAtAMenuRowSelectsIt() async throws {
        try script("weather", toml: "title = 'Weather'")
        _ = try await select("weather")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))

        model.point(at: .menuRow(2))

        XCTAssertEqual(model.menu?.selected, 2)
        XCTAssertNotNil(model.menu)
    }

    func testADragOfAForceClickHighlightsTheRowUnderItAndItsReleaseRunsThatRow() async throws {
        try script("weather", toml: "title = 'Weather'")
        _ = try await select("weather")
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
        try await wait("the close at the end of the row's run") { model.menu == nil }
    }

    func testPointingAtACardSelectsItUnlessAMenuIsOpenOrTheGridIsEdited() async throws {
        try script("weather", toml: "title = 'Weather'")
        try script("clock", toml: "title = 'Clock'")
        _ = try await select("weather")

        let middle = { (id: String) in
            let index = try XCTUnwrap(self.model.visible.firstIndex { $0.id == id })
            let rect = try XCTUnwrap(self.model.placements.first { $0.index == index }).rect
            return CGPoint(x: rect.midX, y: rect.midY)
        }

        model.point(at: .grid(try middle("clock")))
        XCTAssertEqual(model.selectedEntry?.id, "clock")

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        model.point(at: .grid(try middle("weather")))
        XCTAssertEqual(model.selectedEntry?.id, "clock")
        model.closeMenu()

        model.beginEditing()
        model.point(at: .grid(try middle("weather")))
        XCTAssertEqual(model.selectedEntry?.id, "clock")
        XCTAssertEqual(model.pointedCard, "weather")
        model.point(at: .grid(nil))
        XCTAssertNil(model.pointedCard)
    }

    func testAPointBetweenCardsPointsAtNoCard() async throws {
        try script("weather", toml: "title = 'Weather'")
        _ = try await select("weather")
        let rect = try XCTUnwrap(model.placements.first).rect

        model.point(at: .grid(CGPoint(x: rect.maxX + SpotTokens.columnGap / 2, y: rect.midY)))

        XCTAssertNil(model.pointedCard)
    }

    func testOpeningTheMenuDimsEachOtherCardOnceItGrows() async throws {
        try script("weather", toml: "title = 'Weather'")
        try script("clock", toml: "title = 'Clock'")
        try script("notes", toml: "title = 'Notes'")
        _ = try await select("weather")
        let weather = try XCTUnwrap(model.visible.firstIndex { $0.id == "weather" })
        let others = model.placements.map(\.index).filter { $0 != weather }
        XCTAssertGreaterThanOrEqual(others.count, 2)
        XCTAssertEqual(model.gridShade, GridShade())

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))

        XCTAssertFalse(model.gridShade.isOn)
        XCTAssertEqual(model.focus(ofCard: weather), .none)
        XCTAssertFalse(model.gridShade.dims(others[0]))
        let card = try XCTUnwrap(model.placements.first { $0.index == weather }).rect
        let rest = card.insetBy(dx: -card.width * (MotionTokens.focusedScale - 1) / 2, dy: -card.height * (MotionTokens.focusedScale - 1) / 2)
        let placed = model.menuItemAtRest(card)
        XCTAssertEqual(placed.minX, rest.minX, accuracy: 1e-9)
        XCTAssertEqual(placed.maxY, rest.maxY, accuracy: 1e-9)
        try await wait("the grown menu") { model.menuSession?.isGrown == true }
        XCTAssertEqual(model.focus(ofCard: weather), .focused)
        XCTAssertEqual(others.filter { model.focus(ofCard: $0) != .none }, [])
        XCTAssertTrue(model.gridShade.isOn)
        XCTAssertEqual(others.filter { model.gridShade.dims($0) }, others)
        XCTAssertFalse(model.gridShade.dims(weather))
        XCTAssertTrue(model.gridShade.coversField)
        XCTAssertFalse(model.dimsField)
        XCTAssertFalse(GridShade(over: model.placements, leaving: model.visible.count, isOn: true).coversField)
        nonisolated(unsafe) var moved = false
        withObservationTracking { _ = model.gridShade } onChange: { moved = true }
        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))
        XCTAssertFalse(moved)

        host.heldEnds = []
        model.closeMenu()

        XCTAssertFalse(model.gridShade.isOn)
        XCTAssertFalse(model.gridShade.dims(others[0]))
        for end in host.heldEnds ?? [] { end() }
        XCTAssertEqual(model.gridShade, GridShade())
        XCTAssertEqual(model.focus(ofCard: weather), .none)
    }

    func testAGridThatChangesUnderAnOpenMenuDimsItsNewCards() async throws {
        try script("weather", toml: "title = 'Weather'")
        try script("clock", toml: "title = 'Clock'")
        _ = try await select("weather")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        try await wait("the grown menu") { model.menuSession?.isGrown == true }
        let before = model.gridShade

        try script("alarm", toml: "title = 'Alarm'")
        await model.reload()

        let weather = try XCTUnwrap(model.visible.firstIndex { $0.id == "weather" })
        XCTAssertEqual(model.selected, weather)
        XCTAssertNotEqual(model.gridShade, before)
        XCTAssertTrue(model.gridShade.isOn)
        let others = model.placements.map(\.index).filter { $0 != weather }
        XCTAssertEqual(others.filter { model.gridShade.dims($0) }, others)
        XCTAssertFalse(model.gridShade.dims(weather))
    }

    func testCopyPromptForAICopiesTheFileTheLastFailureAndTheStatsOfTheSpot() async throws {
        try script("ping", "echo 'Openspot cannot reach the server.' >&2; exit 1")
        let target = try await select("ping")
        model.tap("ping")
        try await wait("the failure") { model.entries.first { $0.id == "ping" }?.failure != nil }

        _ = target
        XCTAssertTrue(model.act(.prompt, on: "ping"))
        try await wait("the toast") { host.confirms.last == AgentPrompt.copied }

        let prompt = try XCTUnwrap(saved("clipboard"))
        XCTAssertTrue(prompt.contains(spots.spotFile("ping").path))
        XCTAssertTrue(prompt.contains("Make every call pass"))
        XCTAssertTrue(prompt.contains("What Openspot counted of this spot"))
        XCTAssertFalse(prompt.contains("Ask me what to change"))
        XCTAssertTrue(prompt.contains("Openspot cannot reach the server."))
    }

    func testDeleteAsksNothingKeepsThePanelAndCommandZLeavesTheSpotInTheTrash() async throws {
        try script("weather", toml: "title = 'Weather'")
        _ = try await select("weather")

        XCTAssertTrue(model.handleKey(ActionKey(name: "backspace", isCommand: true)))
        try await wait("the delete and its toast") { !model.entries.contains { $0.id == "weather" } && !host.confirms.isEmpty }

        XCTAssertNil(model.menu)
        XCTAssertEqual(host.dismissals, 0)
        XCTAssertEqual(host.confirms.last, "Moved Weather to the Trash.")

        XCTAssertFalse(model.handleKey(ActionKey(name: "z", isCommand: true)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: spots.spotFile("weather").path))
    }

    func testACardOfAFileThatDoesNotLoadIsThePersonsAndCanBeDeleted() async throws {
        try script("broken", toml: "answers = 'huge'")
        _ = try await select("broken")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        XCTAssertEqual(model.menu?.rows.filter { $0.action != nil }.map(\.title), ["Share", "Settings", "Edit", "Change Icon", "Delete"])
        model.closeMenu()

        XCTAssertTrue(model.handleKey(ActionKey(name: "backspace", isCommand: true)))
        try await wait("the delete") { !model.entries.contains { $0.id == "broken" } }

        XCTAssertTrue(FileManager.default.fileExists(atPath: trash.appendingPathComponent("broken.spot").path))
    }

    private func call(_ arguments: [String]) async throws -> CommandAnswer {
        let api = try XCTUnwrap(model.runs.api)
        let request = CommandRequest(arguments: arguments, folder: folder.path)
        let parsed = api.admit(try XCTUnwrap(api.call(of: request)), request: request)
        let work = try XCTUnwrap(api.work(for: parsed, request: request, input: { "" }))
        return await work()
    }

    func testASpotThatACallWritesIsOnTheGridWhenTheCallAnswers() async throws {
        await model.reload()

        let answer = try await call(["spot", "new", "coffee"])

        XCTAssertEqual(answer.code, 0)
        XCTAssertTrue(model.entries.contains { $0.id == "coffee" })
    }

    func testACallRunsALooseScriptThatItMovesIntoASpotFolder() async throws {
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        try "#!/bin/sh\necho brewed\n".writeScript(to: spots.appendingPathComponent("coffee.sh"), toml: "title = 'Coffee'")

        let answer = try await call(["spot", "run", "coffee"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.spotFile("coffee").path))
    }
}
