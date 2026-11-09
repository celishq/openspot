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
        let host = TestHost()
        self.host = host
        let files = SpotFiles(
            environment: ["OPENSPOT_PLUGINS": plugins.path, "OPENSPOT_CONFIG": folder.appendingPathComponent("config").path],
            home: folder,
            defaults: defaults
        )
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2, prepare: { await host.prepare($0) }))
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

    func testAPointOfTheGridFindsTheCardWhosePlaceHoldsIt() throws {
        try script("one", header: "title=One", "")
        try script("two", header: "title=Two", "")
        model.reload()
        let first = try XCTUnwrap(model.placements.first)
        let second = try XCTUnwrap(model.placements.dropFirst().first)
        let gap = CGPoint(x: first.rect.maxX + SpotTokens.columnGap / 2, y: first.rect.midY)

        XCTAssertEqual(model.card(at: CGPoint(x: first.rect.midX, y: first.rect.midY)), model.visible[first.index].id)
        XCTAssertEqual(model.card(at: CGPoint(x: second.rect.midX, y: second.rect.midY)), model.visible[second.index].id)
        XCTAssertNil(model.card(at: gap))
        XCTAssertNil(model.card(at: CGPoint(x: -1, y: -1)))
    }

    func testAnOpenFindsAScriptMadeExecutableSinceTheOpenBefore() throws {
        let late = plugins.appendingPathComponent("late.sh")
        try "#!/bin/sh\n# title=Late\n".write(to: late, atomically: false, encoding: .utf8)
        model.panelWillShow(holding: [])
        XCTAssertFalse(model.entries.contains { $0.id == "late" })

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: late.path)
        model.panelWillShow(holding: [])

        XCTAssertTrue(model.entries.contains { $0.id == "late" })
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

    func testAListDrawsAheadOnlyThePicturesOfTheRowsOnItsFirstScreen() async throws {
        try script("apps", header: "read=sheet", "for i in $(seq 1 100); do printf 'row=a%s\\ntitle=App %s\\nicon=/Applications/A%s.app\\n\\n' $i $i $i; done")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("apps")
        try await wait("the rows and their pictures") { model.openItems?.shown.count == 100 && !host.prepared.isEmpty }

        let first = SpotTokens.firstScreen(perLine: 1)
        XCTAssertLessThan(first, 20)
        XCTAssertEqual(Set(host.prepared.map(\.run)), Set((1...first).map { "a\($0)" }))
    }

    func testAListDrawsAheadTheRowsItShowsFirstWithARecentPickOnTop() async throws {
        try script("apps", header: "read=sheet", "for i in $(seq 1 100); do printf 'row=a%s\\ntitle=App %s\\nicon=/Applications/A%s.app\\n\\n' $i $i $i; done")
        let host = TestHost()
        let ranked = SpotsModel(host: host, files: model.files, runs: SpotRuns(stopPause: 0.2, recent: { _ in ["a50"] }, prepare: { await host.prepare($0) }))
        host.model = ranked
        defer { ranked.quit() }
        ranked.reload()
        ranked.isShown = true
        ranked.panelWillShow(holding: [])
        ranked.press("apps")
        try await wait("the rows and their pictures") { ranked.openItems?.shown.count == 100 && !host.prepared.isEmpty }

        XCTAssertEqual(ranked.openItems?.shown.first?.run, "a50")
        XCTAssertTrue(host.prepared.contains { $0.run == "a50" })
    }

    func testAListAsksForThePicturesOfAllItsGlyphsOnce() async throws {
        try script("faces", header: "read=sheet", "for i in $(seq 1 100); do printf 'row=f%s\\ntitle=Face %s\\nicon=😀\\n\\n' $i $i; done")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("faces")
        try await wait("the glyphs") { !host.glyphLists.isEmpty }

        XCTAssertEqual(host.glyphLists, [Array(repeating: "😀", count: 100)])
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

    func testAPickOfTheBuildRowOpensBuildInPlaceOfTheListWithNoCollapse() async throws {
        let build = plugins.appendingPathComponent("build.sh")
        try "#!/bin/sh\nprintf 'row=g\\ntitle=Guide\\n'\n".writeScript(to: build)
        host.shipped = [Spot(id: ShippedSpot.buildID, name: "Build", url: build, kind: .list, read: .sheet, isOnGrid: false)]
        try await openList()
        try await wait("the open list") { model.transition.phase == .open }
        let entry = try XCTUnwrap(model.openEntry)
        host.motions = []
        host.phases = []

        model.pick(SpotItem(title: "Build your own", run: CatalogSpot.buildRun), of: entry)

        try await wait("the build sheet") { model.openList == ShippedSpot.buildID }
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
}

/// A host that records what the model asks of the app, and makes each change at once.
@MainActor
private final class TestHost: SpotsHost {
    var dismissals = 0
    var shows = 0
    var notes: [String] = []
    var confirms: [String] = []
    var isPointerOverDrop = false
    var draggedPaths: [String] = []
    var isMouseDown = false
    var pastedPaths: [String] = []
    var motions: [PanelMotion?] = []
    /// The phase of the sheet's transition after each change.
    var phases: [SheetTransition.Phase] = []
    /// The spots that ship with the app in this test.
    var shipped: [Spot] = []
    /// The rows whose pictures the model asked to draw ahead.
    var prepared: [SpotItem] = []
    /// The glyphs of each whole list whose pictures the model asked for.
    var glyphLists: [[String]] = []
    /// The model whose show and hide steps the panel runs, as the app's window does.
    weak var model: SpotsModel?

    nonisolated deinit {}

    func dismiss() {
        dismissals += 1
        model?.panelWillHide()
        model?.panelDidHide()
    }

    func show() {
        shows += 1
        model?.panelWillShow(holding: [])
    }

    func present() {}

    func notify(_ text: String) {
        notes.append(text)
    }

    func notify(_ text: String, fix: URL) {
        notes.append(text)
    }

    func confirm(_ text: String) {
        confirms.append(text)
    }

    func applyConfig() {}

    func setEntryKey(on isOn: Bool) {}

    func hold(_ keys: [GlobalKey]) {}

    func chooseFiles(for command: Spot, then take: @escaping ([String]) -> Void) {}

    func copy(_ file: URL) {}

    func prepare(_ items: [SpotItem]) async {
        prepared += items
    }

    func prepare(glyphs: [String]) {
        glyphLists.append(glyphs)
    }

    func shippedSpots(folder: PluginFolder, config: ConfigFile, update: UpdateSpot?, offersLogin: Bool) -> [Spot] {
        shipped
    }

    func change(_ motion: PanelMotion?, _ body: () -> Void, completion: @escaping @MainActor () -> Void) {
        motions.append(motion)
        body()
        if let phase = model?.transition.phase { phases.append(phase) }
        completion()
    }
}
