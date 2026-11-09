import XCTest
@testable import OpenspotCore

/// Proves the panel's decisions: which sheet opens and closes, where the search goes, and what a pick leaves behind.
@MainActor
final class SpotsModelTests: XCTestCase {
    private var folder: URL!
    private var defaults: UserDefaults!
    private var suite = ""
    private var host: TestHost!
    private var model: SpotsModel!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-panel-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        suite = "openspot-panel-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        host = TestHost()
        let files = SpotFiles(
            environment: ["OPENSPOT_PLUGINS": plugins.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
            home: folder,
            defaults: defaults
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2))
        host.model = model
    }

    override func tearDown() async throws {
        model.quit()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    private var plugins: URL {
        folder.appendingPathComponent("plugins", isDirectory: true)
    }

    private func script(_ name: String, header: String, _ body: String) throws {
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

    /// Shows the panel with one list of two rows, and opens that list.
    private func openList() async throws {
        try script("list", header: "read=sheet", "printf 'row=a\\ntitle=Apple\\n\\nrow=b\\ntitle=Banana\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("list")
        try await wait("the open list") { model.openList == "list" && model.openItems?.shown.count == 2 }
    }

    func testAPressOfAListOpensItsSheetAndAStepBackClosesIt() async throws {
        try await openList()

        XCTAssertEqual(host.shows, 1)
        XCTAssertTrue(model.stepBack())

        XCTAssertNil(model.openList)
        XCTAssertEqual(model.sheets["list"]?.isOpen, false)
    }

    func testTheSearchOfAnOpenListFiltersItsRowsAndLeavesTheGridsSearch() async throws {
        try await openList()

        model.searchText = "ban"

        XCTAssertEqual(model.openItems?.shown.map(\.run), ["b"])
        XCTAssertEqual(model.query, "")
    }

    func testAStepBackClearsTheSearchBeforeItClosesTheList() async throws {
        try await openList()
        model.searchText = "ban"

        XCTAssertTrue(model.stepBack())
        XCTAssertEqual(model.openList, "list")
        XCTAssertEqual(model.searchText, "")
        XCTAssertTrue(model.stepBack())

        XCTAssertNil(model.openList)
        XCTAssertFalse(model.stepBack())
    }

    func testAPickClosesThePanelAndTheListRemembersTheRowOnceThePanelHasFaded() async throws {
        try await openList()
        let entry = try XCTUnwrap(model.openEntry)

        model.pick(SpotItem(title: "Banana", run: "b"), of: entry)

        XCTAssertEqual(host.dismissals, 1)
        XCTAssertNil(model.openList)
        XCTAssertEqual(model.files.recent(of: "list"), ["b"])
    }

    func testOpeningASheetClosesTheRunOfTheSheetBefore() async throws {
        try await openList()
        try script("other", header: "read=sheet", "printf 'row=a\\ntitle=A\\n'")
        model.reload()

        model.open("other", moving: true)

        try await wait("the other sheet") { model.openList == "other" }
        XCTAssertEqual(model.runs.openID, "other")
        XCTAssertEqual(model.sheets["list"]?.isOpen, false)
    }

    func testTheCloseButtonMovesTheSheetAndAFadedPickCutsIt() async throws {
        try await openList()

        host.motions = []
        model.closeList(moving: true)
        XCTAssertEqual(host.motions.compactMap { $0 }, [.sheet(isOpen: false)])
        model.open("list", moving: true)
        try await wait("the open list") { model.openList == "list" }
        host.motions = []
        model.pick(SpotItem(title: "Apple", run: "a"), of: try XCTUnwrap(model.openEntry))

        XCTAssertNil(model.openList)
        XCTAssertEqual(host.motions.compactMap { $0 }, [])
        XCTAssertFalse(host.motions.isEmpty)
    }

    func testAPanelThatHidesCutsASheetOfPartsAndItsRun() async throws {
        try script("parts", header: "read=sheet", "printf 'text=a\\ntitle=A\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.open("parts", moving: true)
        try await wait("the open sheet") { model.openList == "parts" && model.openPanel != nil }

        host.motions = []
        model.panelWillHide()
        model.panelDidHide()

        XCTAssertNil(model.openList)
        XCTAssertNil(model.runs.openID)
        XCTAssertEqual(host.motions.compactMap { $0 }, [])
        XCTAssertFalse(host.motions.isEmpty)
    }

    func testAReadThatChangesTheSizeOfACardLaysOutTheGridAgain() async throws {
        let large = folder.appendingPathComponent("large").path
        try script("grow", header: "read=panel", "if [ -f '\(large)' ]; then printf 'size=large\\n'; else printf 'size=small\\n'; fi")
        model.reload()
        model.panelWillShow(holding: [])
        try await wait("the small card") { model.visible.first?.size == .small }
        let small = model.placements

        FileManager.default.createFile(atPath: large, contents: Data())
        model.sheets["grow"]?.read(need: .change)

        try await wait("the large card") { model.visible.first?.size == .large }
        XCTAssertEqual(model.placements, SpotGrid().place(model.visible.map(\.size)))
        XCTAssertNotEqual(model.placements, small)
    }

    func testASubmitThatEndsAfterThePersonOpenedANewFormLeavesTheNewForm() async throws {
        let gate = folder.appendingPathComponent("gate").path
        let reads = folder.appendingPathComponent("reads").path
        try script("list", header: "read=sheet", """
        case "$1" in
          new)
            input=$(cat)
            if [ -z "$input" ]; then printf 'title=New\\n\\nfield=a\\ntitle=A\\n'; exit 0; fi
            touch '\(folder.appendingPathComponent("saving").path)'
            n=0; while [ ! -f '\(gate)' ] && [ $n -lt 1500 ]; do sleep 0.02; n=$((n + 1)); done
            printf 'b\\n' ;;
          edit) printf 'title=Edit\\n\\nfield=e\\ntitle=E\\n' ;;
          *)
            echo read >> '\(reads)'
            printf 'button=new\\ntitle=New\\nscope=command\\nform=true\\n\\nbutton=edit\\ntitle=Edit\\nscope=command\\nform=true\\n\\nrow=a\\ntitle=Apple\\n' ;;
        esac
        """)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("list")
        try await wait("the open list") { model.openList == "list" && model.openEntry?.command.actions.contains(where: \.isForm) == true }
        let entry = try XCTUnwrap(model.openEntry)
        let action = try XCTUnwrap(entry.command.actions.first { $0.id == "new" })
        let edit = try XCTUnwrap(entry.command.actions.first { $0.id == "edit" })
        model.openForm(action, on: (entry, nil))
        try await wait("the form") { model.form != nil }
        model.setFormValue("x", for: "a")
        model.submitForm()
        try await wait("the save") { FileManager.default.fileExists(atPath: self.folder.appendingPathComponent("saving").path) }

        model.cancelForm()
        model.openForm(edit, on: (entry, nil))
        try await wait("the new form") { model.form?.action.id == "edit" }
        FileManager.default.createFile(atPath: gate, contents: Data())

        try await wait("the read after the save") {
            ((try? String(contentsOfFile: reads, encoding: .utf8)) ?? "").split(separator: "\n").count == 2 && model.openItems?.isLoading == false
        }
        XCTAssertEqual(model.form?.action.id, "edit")
    }

    func testThePanelsShowAndHideStepsSelectTheFirstCardAndLeaveEditSpots() async throws {
        try script("list", header: "read=sheet", "printf 'row=a\\ntitle=Apple\\n'")
        try script("other", header: "read=sheet", "printf 'row=a\\ntitle=A\\n'")
        model.reload()
        model.selected = 1
        model.beginEditing()

        model.panelWillHide()

        XCTAssertFalse(model.isEditing)
        XCTAssertFalse(model.isShown)
        model.panelWillShow(holding: [])
        XCTAssertEqual(model.selected, 0)
        try await wait("the shown panel") { model.isShown }
    }

    func testAFormThatArrivesAfterThePanelHidDoesNotOpen() async throws {
        let gate = folder.appendingPathComponent("gate").path
        try script("list", header: "read=sheet", """
        case "$1" in
          new)
            n=0; while [ ! -f '\(gate)' ] && [ $n -lt 1500 ]; do sleep 0.02; n=$((n + 1)); done
            printf 'title=New\\n\\nfield=a\\ntitle=A\\n' ;;
          *) printf 'button=new\\ntitle=New\\nscope=command\\nform=true\\n\\nrow=a\\ntitle=Apple\\n' ;;
        esac
        """)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("list")
        try await wait("the open list") { model.openList == "list" && model.openEntry?.command.actions.isEmpty == false }
        let entry = try XCTUnwrap(model.openEntry)
        let action = try XCTUnwrap(entry.command.actions.first { $0.id == "new" })
        model.openForm(action, on: (entry, nil))
        try await wait("the form call") { model.sheets["list"]?.calls.isEmpty == false }

        host.dismiss()
        FileManager.default.createFile(atPath: gate, contents: Data())

        try await wait("the end of the form call") { model.sheets["list"]?.calls.isEmpty == true }
        for _ in 0..<10 { await Task.yield() }
        XCTAssertNil(model.form)
    }

    func testASheetThatOpensWhileAnotherShowsTakesItsPlaceWithNoCollapseAndNoCard() async throws {
        try await openList()
        try script("other", header: "read=sheet", "printf 'row=a\\ntitle=A\\n'")
        model.reload()
        try await wait("the open list") { model.transition.phase == .open }
        host.motions = []
        host.phases = []

        model.open("other", moving: true)

        try await wait("the other sheet") { model.openList == "other" }
        XCTAssertEqual(model.transition.phase, .open)
        XCTAssertFalse(host.phases.contains(.closing))
        XCTAssertFalse(host.phases.contains(.ready))
        XCTAssertFalse(host.motions.contains(.sheet(isOpen: false)))
    }

    func testAPickOfTheNewSpotRowOpensNewSpotInPlaceOfTheListWithNoCollapse() async throws {
        let build = plugins.appendingPathComponent("build.sh")
        try "#!/bin/sh\nprintf 'row=g\\ntitle=Guide\\n'\n".writeScript(to: build)
        host.shipped = [Spot(id: ShippedSpot.newID, name: "New spot", url: build, kind: .list, read: .sheet, isOnGrid: false)]
        try await openList()
        try await wait("the open list") { model.transition.phase == .open }
        let entry = try XCTUnwrap(model.openEntry)
        host.motions = []
        host.phases = []

        model.pick(SpotItem(title: "New spot", run: CatalogSpot.buildRun), of: entry)

        try await wait("the New spot sheet") { model.openList == ShippedSpot.newID }
        XCTAssertEqual(model.transition.phase, .open)
        XCTAssertFalse(host.phases.contains(.closing))
        XCTAssertFalse(host.phases.contains(.ready))
        XCTAssertFalse(host.motions.contains(.sheet(isOpen: false)))
    }

    func testASheetWithNoCardShowsAndHidesAtOnce() async throws {
        try script("list", header: "read=sheet", "printf 'row=a\\ntitle=Apple\\n'")
        try script("other", header: "read=sheet", "printf 'row=a\\ntitle=A\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.setOnGrid(false, for: "other")
        host.motions = []
        host.phases = []

        model.open("other", moving: true)

        try await wait("the sheet") { model.openList == "other" }
        XCTAssertEqual(model.transition.phase, .open)
        XCTAssertFalse(host.phases.contains(.ready))
        XCTAssertEqual(host.motions.compactMap { $0 }, [])
        model.closeList(moving: true)
        XCTAssertNil(model.transition.id)
        XCTAssertEqual(host.motions.compactMap { $0 }, [])
    }

    func testTheGridSearchFindsASpotByItsName() async throws {
        try script("list", header: "read=sheet", "printf 'row=a\\ntitle=Apple\\n'")
        try script("other", header: "read=sheet", "printf 'row=a\\ntitle=A\\n'")
        model.reload()

        model.searchText = "oth"

        XCTAssertEqual(model.visible.map(\.id), ["other"])
    }

    func testAKeyShowsTheSymbolOfItsCommandOrElseOfItsScriptForAMoment() async throws {
        try script("move", header: "icon=macwindow\ncommand=left:Left side:rectangle.lefthalf.inset.filled\ncommand=plain:Plain", "true")
        model.reload()
        model.flashPause = .milliseconds(50)
        let shortcut = try XCTUnwrap(Shortcut(text: "ctrl+left"))

        model.press(GlobalKey(spot: "move", command: "left", shortcut: shortcut))
        XCTAssertEqual(model.flashSymbol, "rectangle.lefthalf.inset.filled")
        model.press(GlobalKey(spot: "move", command: "plain", shortcut: shortcut))
        XCTAssertEqual(model.flashSymbol, "macwindow")

        try await wait("the end of the flash") { model.flashSymbol == nil }
    }

    func testAKeyOfAScriptThatIsGoneShowsNothing() throws {
        model.reload()

        model.press(GlobalKey(spot: "gone", command: "left", shortcut: try XCTUnwrap(Shortcut(text: "ctrl+left"))))

        XCTAssertNil(model.flashSymbol)
    }

    func testAShowOfASpotOpensThePanelWithItsCardSelected() throws {
        try script("one", header: "", "echo")
        try script("two", header: "", "echo")

        XCTAssertTrue(model.reveal("one"))

        XCTAssertEqual(host.shows, 1)
        XCTAssertEqual(model.selectedEntry?.id, "one")
        XCTAssertFalse(model.reveal("three"))
    }

    func testCommandNOpensTheNewSpotSheetFromTheGridAndFromEditSpots() async throws {
        let new = plugins.appendingPathComponent("new.sh")
        try "#!/bin/sh\nprintf 'row=g\\ntitle=Guide\\n'\n".writeScript(to: new)
        host.shipped = [Spot(id: ShippedSpot.newID, name: "New spot", url: new, kind: .list, read: .sheet, isOnGrid: false)]
        model.reload()
        model.isShown = true

        XCTAssertTrue(model.handleKey(ActionKey(name: "n", isCommand: true)))
        try await wait("the New spot sheet") { model.openList == ShippedSpot.newID }

        model.closeList(moving: false)
        model.beginEditing()
        XCTAssertTrue(model.handleKey(ActionKey(name: "n", isCommand: true)))
        XCTAssertFalse(model.isEditing)
        try await wait("the New spot sheet from Edit Spots") { model.openList == ShippedSpot.newID }
    }
}
