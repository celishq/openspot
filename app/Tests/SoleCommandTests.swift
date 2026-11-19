import XCTest
@testable import OpenspotCore

@MainActor
final class SoleCommandTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: FakeHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-sole-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        suite = "openspot-sole-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        host = FakeHost()
        let core = folder.appendingPathComponent("core/openspot.spot", isDirectory: true)
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
        let files = AppPlaces(
            environment: [
                "OPENSPOT_SPOTS": spots.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path,
                "OPENSPOT_CORE": core.deletingLastPathComponent().path
            ],
            home: folder,
            defaults: defaults
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2))
        host.model = model
        model.runs.api = CommandAPI(mac: Mac(), places: files, app: ModelApp(model: model), runs: model.runs, rates: .offline)
    }


    override func tearDown() async throws {
        model.quit()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    private var spots: URL {
        folder.appendingPathComponent("spots", isDirectory: true)
    }

    private func script(_ name: String, toml: String) throws {
        try "#!/bin/sh\n\(TestSpot.toast) \"Ran $1\"\n".writeScript(to: spots.spotFile(name), toml: toml)
    }

    private func entry(_ id: String) throws -> SpotsModel.Entry {
        try XCTUnwrap(model.entries.first { $0.id == id })
    }

    func testReturnRunsTheOneCommandAtOnceAndItsSettingsRecordItsKey() async throws {
        try script("dictate", toml: "title = 'Dictate'\n[commands.dictate]\ntitle = 'Dictate'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        model.query = "dictate"
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "dictate" })
        XCTAssertEqual(model.hint, "⏎ Dictate   ⌘⏎ Settings   ⌘K Actions")
        model.run(try entry("dictate"))

        try await wait("the command") { host.confirms == ["Ran dictate"] }
        XCTAssertNil(model.recording)
        XCTAssertNil(model.openSheetID)
        XCTAssertEqual(host.dismissals, 1)

        model.isShown = true
        model.panelWillShow()
        model.query = "dictate"
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "dictate" })
        XCTAssertTrue(model.openSelectedSettings())
        try await wait("the key row") { model.openItems?.shown.contains { $0.run == "key:dictate:key.dictate" } == true }
        XCTAssertNil(model.recording)
        model.toggleRecording(id: "key:dictate:key.dictate")
        XCTAssertEqual(model.recording, "key:dictate:key.dictate")
        model.recordTap(.option)
        try await wait("the tap in the file") {
            model.files.config.read().keys == [GlobalKey(spot: "dictate", act: .command("dictate"), trigger: .tap(.option))]
        }
        XCTAssertEqual(model.openSheetID, SpotSettings.sheetID(of: "dictate"))
    }

    func testACommandWithConfirmAndNoKeyAsksForASecondReturn() async throws {
        try script("wipe", toml: "title = 'Wipe'\n[commands.wipe]\ntitle = 'Wipe'\nconfirm = 'Press again to wipe'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.query = "wipe"
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "wipe" })

        model.run(try entry("wipe"))

        XCTAssertEqual(model.hint, "⏎ Press again to wipe   ⌘⏎ Settings   ⌘K Actions")
        XCTAssertEqual(host.dismissals, 0)
        model.run(try entry("wipe"))
        try await wait("the command") { host.confirms == ["Ran wipe"] }
    }

    func testACommandWithConfirmAsksForASecondPressOfItsCard() async throws {
        try script("wipe", toml: "title = 'Wipe'\n[commands.wipe]\ntitle = 'Wipe'\nconfirm = 'Press again to wipe'")
        _ = try model.files.config.change { $0.assign(.tap(.option), to: "wipe", act: .command("wipe")) }
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.query = "wipe"
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "wipe" })

        model.run(try entry("wipe"))

        XCTAssertEqual(model.hint, "⏎ Press again to wipe   ⌘⏎ Settings   ⌘K Actions")
        XCTAssertEqual(host.dismissals, 0)
        model.run(try entry("wipe"))
        try await wait("the command") { host.confirms == ["Ran wipe"] }
        XCTAssertEqual(model.hint, "⏎ Wipe   ⌘⏎ Settings   ⌘K Actions")
    }

    func testAGlobalKeyOfACommandWithConfirmShowsItsCardAskingAndReturnRunsIt() async throws {
        try script("wipe", toml: "title = 'Wipe'\n[commands.wipe]\ntitle = 'Wipe'\nconfirm = 'Press again to wipe'")
        try script("other", toml: "title = 'Other'\n[commands.other]\ntitle = 'Other'")
        _ = try model.files.config.change { $0.assign(.tap(.option), to: "wipe", act: .command("wipe")) }
        await model.reload()
        let key = try XCTUnwrap(model.assignedKeys.first { $0.spot == "wipe" })

        model.press(key)

        XCTAssertEqual(model.selectedEntry?.id, "wipe")
        XCTAssertEqual(model.hint, "⏎ Press again to wipe   ⌘⏎ Settings   ⌘K Actions")
        XCTAssertEqual(host.shows, 1)
        try await wait("the panel") { self.model.isShown }
        XCTAssertTrue(model.handleSearchKey(ActionKey(name: "return")))
        try await wait("the command") { self.host.confirms == ["Ran wipe"] }
        XCTAssertEqual(host.dismissals, 1)
    }

    func testACommandWithConfirmAsksForASecondPressInTheMenu() async throws {
        try script("wipe", toml: "title = 'Wipe'\non = ['sheet.open']\n[commands.wipe]\ntitle = 'Wipe'\nconfirm = 'Press again to wipe'\n[commands.keep]\ntitle = 'Keep'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.query = "wipe"
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "wipe" })

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let menu = try XCTUnwrap(model.menu)

        XCTAssertEqual(menu.rows.first { $0.title == "Wipe" }?.action?.confirm, "Press again to wipe")
    }

    func testReturnOnASpotWithTwoCommandsOnlyOpensTheirKeys() async throws {
        try script("windows", toml: "title = 'Windows'\n[commands.left]\ntitle = 'Left'\n[commands.right]\ntitle = 'Right'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        model.run(try entry("windows"))

        try await wait("the key rows") { model.openSheetID == SpotSettings.sheetID(of: "windows") }
        try await wait("their rows") { model.openItems?.shown.map(\.run) == ["key:windows:open", "key:windows:key.left", "key:windows:key.right", "key:windows:float", "menubar:windows", "window:windows"] }
        XCTAssertNil(model.recording)
    }

    func testReturnRunsTheOneCommandOfASpotWithRowsAndCommandYOpensTheRowsAsHistory() async throws {
        try "#!/bin/sh\ncase \"$1\" in show) printf 'text=one\\ntitle=Hello there\\n\\ntext=two\\ntitle=Second\\n' ;; dictate) \(TestSpot.toast) 'Ran dictate' ;; esac\n"
            .writeScript(to: spots.spotFile("dictate"), toml: "title = 'Dictate'\non = ['sheet.open', 'app.update']\n[commands.dictate]\ntitle = 'Dictate'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.query = "dictate"
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "dictate" })

        XCTAssertEqual(try entry("dictate").spot.soleCommand, "dictate")
        XCTAssertFalse(try entry("dictate").spot.opensOnReturn)
        XCTAssertEqual(model.hint, "⏎ Dictate   ⌘⏎ Settings   ⌘K Actions")
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let menu = try XCTUnwrap(model.menu)
        XCTAssertEqual(menu.rows.map(\.title), ["Dictate", "History"])
        XCTAssertEqual(menu.rows.first { $0.title == "History" }?.keyLabel, "⌘Y")
        model.closeMenu()

        XCTAssertTrue(model.handleKey(ActionKey(name: "y", isCommand: true)))
        try await wait("its History with a search typed") { model.openSheetID == "dictate" }
        model.closeSheet(moving: false)

        model.run(.history, on: SpotsModel.Target(entry: try entry("dictate"), item: nil))
        try await wait("its own rows") { model.openItems?.shown.map(\.run) == ["one", "two"] }
        XCTAssertEqual(model.openSheetID, "dictate")
        model.closeSheet(moving: false)

        model.runSelected()
        try await wait("the command") { host.confirms == ["Ran dictate"] }
        XCTAssertNil(model.recording)
    }

    func testAKeyRowSaysSetUntilItHasAKeyAndChangeAfter() {
        let spot = Spot(id: "d", name: "d", url: URL(fileURLWithPath: "/d.sh"))
        let unset = Frame(text: "field=key:d:d\ntitle=Dictate\ntype=hotkey\n").items.first
        let set = Frame(text: "field=key:d:d\ntitle=Dictate\ntype=hotkey\nvalue=option\n").items.first

        XCTAssertEqual(ActionMenu(spot: spot, item: unset)?.rows.first?.title, "Set")
        XCTAssertEqual(ActionMenu(spot: spot, item: set)?.rows.first?.title, "Change")
    }

    func testARowThatSaysCloseFalseNamesItsEnterAndKeepsThePanelOpen() async throws {
        try "#!/bin/sh\ncase \"$1\" in show) printf 'button=open\\ntitle=Copy\\n\\ntext=model\\ntitle=Download\\nopen.title=Download\\nclose=false\\n\\ntext=text\\ntitle=Hello\\n' ;; esac\n"
            .writeScript(to: spots.spotFile("get"), toml: "title = 'Get'\non = ['sheet.open']")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.run(try entry("get"))
        try await wait("the rows") { model.openItems?.shown.count == 2 }

        XCTAssertEqual(model.hint.components(separatedBy: "   ").first, "⏎ Download")
        model.runSelectedItem()

        XCTAssertEqual(host.dismissals, 0)
        model.moveItemLine(by: 1)
        XCTAssertEqual(model.hint.components(separatedBy: "   ").first, "⏎ Copy")
        model.runSelectedItem()
        XCTAssertEqual(host.dismissals, 1)
    }

    func testASheetWithAGridAndNoSearchFieldShowsOnlyItsOwnItemsAsItsHistory() async throws {
        try "#!/bin/sh\ncase \"$1\" in show) printf 'text=whisper\\ntitle=Download\\npin=top\\n\\nframe=\\ngrid=list\\n' ;; esac\n"
            .writeScript(to: spots.spotFile("dictate"), toml: "title = 'Dictate'\non = ['sheet.open']\n[commands.dictate]\ntitle = 'Dictate'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        model.run(.history, on: SpotsModel.Target(entry: try entry("dictate"), item: nil))

        try await wait("the rows") { model.openItems?.shown.count == 1 }
        XCTAssertEqual(model.openItems?.shown.map(\.run), ["whisper"])
        XCTAssertEqual(model.openItems?.search, .off)
        XCTAssertEqual(model.sheets["dictate"]?.top.hasField, false)
    }

    func testAnOpenKeyOfASpotWithOneCommandRunsTheCommandAtOnce() async throws {
        try script("dictate", toml: "title = 'Dictate'\n[commands.dictate]\ntitle = 'Dictate'")
        await model.reload()
        let open = GlobalKey(spot: "dictate", act: .open, trigger: .key(try XCTUnwrap(Shortcut(text: "ctrl+option+d"))))

        model.press(open)

        XCTAssertEqual(host.shows, 0)
        XCTAssertNil(model.recording)
        try await wait("the command") { host.confirms == ["Ran dictate"] }
    }

    func testAKeyRecordedOnARowThatStaysOpenKeepsThePanelOpen() async throws {
        try "#!/bin/sh\ncase \"$1\" in show) printf 'field=k\\ntitle=Key\\ntype=hotkey\\nclose=false\\n' ;; esac\n".writeScript(to: spots.spotFile("keys"), toml: "on = ['sheet.open']")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("keys")
        try await wait("the key row") { model.openItems?.shown.first?.run == "k" }

        model.toggleRecording(id: "k")
        model.record(code: 0, modifiers: [.control, .option])

        XCTAssertNil(model.recording)
        XCTAssertEqual(host.dismissals, 0)
        XCTAssertEqual(model.openSheetID, "keys")
    }

    func testAnOpenKeyOfACommandWithConfirmShowsItsCardAskingAndReturnRunsIt() async throws {
        try script("wipe", toml: "title = 'Wipe'\n[commands.wipe]\ntitle = 'Wipe'\nconfirm = 'Press again to wipe'")
        _ = try model.files.config.change { $0.assign(.tap(.option), to: "wipe", act: .command("wipe")) }
        await model.reload()

        model.press(GlobalKey(spot: "wipe", act: .open, trigger: .key(try XCTUnwrap(Shortcut(text: "ctrl+option+w")))))

        XCTAssertEqual(host.shows, 1)
        XCTAssertEqual(model.hint, "⏎ Press again to wipe   ⌘⏎ Settings   ⌘K Actions")
        try await wait("the panel") { self.model.isShown }
        XCTAssertTrue(model.handleSearchKey(ActionKey(name: "return")))
        try await wait("the command") { host.confirms == ["Ran wipe"] }
    }

    func testKeysOpenTheSettingsOfTheirSpotWhichGrowFromItsCard() async throws {
        try script("dictate", toml: "title = 'Dictate'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        let settings = SpotSettings.sheetID(of: "dictate")

        XCTAssertTrue(model.openKeys(of: "dictate"))
        try await wait("the settings") { self.model.openSheetID == settings }

        XCTAssertEqual(SpotSheetCard.of(settings, in: model)?.id, "dictate")
        XCTAssertEqual(SpotSheetCard.of(settings, in: model)?.state?.title, "Dictate")
        XCTAssertNil(SpotSheetCard.of("dictate", in: model)?.state)
    }
}
