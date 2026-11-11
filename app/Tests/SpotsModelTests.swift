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
        model = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2, prepare: { await host.prepare($0, glyphs: $1) }))
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
        let lines = header.split(separator: "\n", omittingEmptySubsequences: false).map { "# \($0)" }.joined(separator: "\n")
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

    func testASheetTakesTheLookOfItsCardOnlyWhenItsScriptDrawsTheCard() async throws {
        try script("agenda", header: "read=panel", "printf 'grid.small=next\\n\\nnumber=next\\nvalue=09:30\\n\\nrow=e\\ntitle=Standup\\n'")
        try FileManager.default.createDirectory(at: plugins.appendingPathComponent("year"), withIntermediateDirectories: true)
        try script("year/year", header: "read=panel\nview=year.swift", "printf 'view=year\\ntitle=2026\\n\\nrow=e\\ntitle=Standup\\n'")
        try script("list", header: "read=panel", "printf 'row=a\\ntitle=Apple\\n'")
        model.reload()
        model.panelWillShow(holding: [])

        try await wait("the drawn cards") {
            SpotSheetCard.of("agenda", in: model)?.look?.id == "agenda" && SpotSheetCard.of("year/year", in: model)?.look?.id == "year/year"
        }
        try await wait("the list") { model.sheets["list"]?.list.shown.count == 1 }
        XCTAssertNotNil(SpotSheetCard.of("list", in: model))
        XCTAssertNil(SpotSheetCard.of("list", in: model)?.look)
    }

    func testADownloadedUpdateReadsEachSpotThatListsItWhileThePanelIsHidden() async throws {
        let seen = folder.appendingPathComponent("seen").path
        try script("news", header: "read=panel,app.update", "[ \"$OPENSPOT_REASON\" = app.update ] && printf '%s' \"$OPENSPOT_VALUE\" > '\(seen)'; printf 'title=News\n'")
        try script("other", header: "read=panel,app.front", "printf 'title=Other\n'")
        model.reload()

        model.updateIsReady("0.3.0")

        try await wait("the read of the update") { (try? String(contentsOfFile: seen, encoding: .utf8)) == "0.3.0" }
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

    func testAnOpenWithNoChangeTellsNoReaderOfTheCards() throws {
        try script("one", header: "title=One", "")
        model.panelWillShow(holding: [])
        model.panelWillHide()
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = model.entries } onChange: { changed = true }
        withObservationTracking { _ = model.sheets["one"]?.command } onChange: { changed = true }

        model.panelWillShow(holding: [])

        XCTAssertFalse(changed)
    }

    func testAnOpenTakesAChangeOfTheConfigFile() throws {
        try script("one", header: "title=One", "")
        try script("two", header: "title=Two", "")
        model.panelWillShow(holding: [])
        model.panelWillHide()
        var arrangement = SpotArrangement()
        arrangement.set(isOnGrid: false, of: "two")

        try model.files.config.write(arrangement)
        model.panelWillShow(holding: [])

        XCTAssertEqual(model.visible.map(\.id), ["one"])
    }

    func testAnOpenPanelReadsAgainAScriptWhoseBodyAloneChanged() async throws {
        try script("cups", header: "read=panel", "printf 'title=One cup\\n'")
        model.isShown = true
        model.panelWillShow(holding: [])
        try await wait("the first read") { model.entries.first { $0.id == "cups" }?.state.title == "One cup" }

        try "#!/bin/sh\n# read=panel\nprintf 'title=Two cups\\n'\n".write(to: plugins.appendingPathComponent("cups.sh"), atomically: false, encoding: .utf8)
        model.folderChanged()

        try await wait("the read of the changed body") { model.entries.first { $0.id == "cups" }?.state.title == "Two cups" }
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
        let ranked = SpotsModel(host: host, files: model.files, runs: SpotRuns(stopPause: 0.2, recent: { _ in ["a50"] }, prepare: { await host.prepare($0, glyphs: $1) }))
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

    func testAReadOfTheSameRowsGivesTheGlyphsItCollectedBefore() async throws {
        let calls = folder.appendingPathComponent("calls").path
        try script("faces", header: "read=sheet", "echo x >> '\(calls)'; for i in $(seq 1 100); do printf 'row=f%s\\ntitle=Face %s\\nicon=😀\\n\\n' $i $i; done")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("faces")
        try await wait("the glyphs") { !host.glyphLists.isEmpty }
        let sheet = try XCTUnwrap(model.sheets["faces"])
        try await wait("the end of the first read") { sheet.calls.isEmpty }

        sheet.read(need: .change)
        try await wait("the second read") { (try? String(contentsOfFile: calls, encoding: .utf8))?.count == 4 }
        try await wait("the end of the second read") { sheet.calls.isEmpty }

        XCTAssertEqual(host.glyphLists.count, 2)
        XCTAssertTrue(host.glyphLists[0].withUnsafeBufferPointer { first in host.glyphLists[1].withUnsafeBufferPointer { $0.baseAddress == first.baseAddress } })
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

    func testASizeInAReadLeavesTheCardAtTheSizeOfItsHeader() async throws {
        try script("grow", header: "read=panel\nsize=small", "printf 'size=large\\ndetail=Read\\n'")
        model.reload()
        model.panelWillShow(holding: [])
        try await wait("the read") { model.visible.first?.state.subtitle == "Read" }

        XCTAssertEqual(model.visible.first?.size, .small)
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

    func testAFormOfSeveralPicksStaysOpenThroughEachPickReadsTheSpotAgainAndSelectsAllOnCommandShiftA() async throws {
        let sent = folder.appendingPathComponent("sent").path
        let reads = folder.appendingPathComponent("reads").path
        try script("list", header: "read=sheet", """
        case "$1" in
          pick)
            input=$(cat)
            [ -z "$input" ] || printf '%s\n' "$input" >> '\(sent)'
            printf 'title=Pick\n\nchoice=shown\ntitle=Shown\ntype=multiple\nvalue=a\n\noption=a\ntitle=Apple\n\noption=b\ntitle=Banana\n\noption=c\ntitle=Cherry\n' ;;
          *)
            echo read >> '\(reads)'
            printf 'button=pick\ntitle=Pick\nscope=command\nform=true\n\nrow=a\ntitle=Apple\n' ;;
        esac
        """)
        let sends = { ((try? String(contentsOfFile: sent, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init) }
        let readCount = { ((try? String(contentsOfFile: reads, encoding: .utf8)) ?? "").split(separator: "\n").count }
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("list")
        try await wait("the open list") { model.openList == "list" && model.openEntry?.command.actions.contains(where: \.isForm) == true }
        let entry = try XCTUnwrap(model.openEntry)
        let action = try XCTUnwrap(entry.command.actions.first { $0.id == "pick" })
        model.openForm(action, on: (entry, nil))
        try await wait("the form") { model.form != nil }
        XCTAssertEqual(model.form?.draft.choices?.shown.map(\.isOn), [true, false, false])
        let before = readCount()

        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))
        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))
        try await wait("the pick") { sends() == ["shown=b"] }
        try await wait("the read after the pick") { readCount() > before }
        XCTAssertNotNil(model.form)
        XCTAssertEqual(model.form?.draft.choices?.selectedItem?.run, "b")
        XCTAssertTrue(model.handleKey(ActionKey(name: "a", isCommand: true, isShift: true)))
        try await wait("select all") { sends().count == 2 }

        XCTAssertEqual(sends().last, "shown=b\\nc")
        XCTAssertNotNil(model.form)
    }

    func testAFormOfOneChoiceSearchesItsRowsWithTheFieldAndEscapeClearsTheSearchFirst() async throws {
        let sent = folder.appendingPathComponent("sent").path
        try script("list", header: "read=sheet", """
        case "$1" in
          pick)
            input=$(cat)
            [ -z "$input" ] || printf '%s\n' "$input" >> '\(sent)'
            printf 'title=Pick\n\nchoice=shown\ntitle=Shown\ntype=multiple\nvalue=a\n\noption=a\ntitle=Apple\n\noption=b\ntitle=Banana\n\noption=c\ntitle=Blueberry\n' ;;
          *) printf 'button=pick\ntitle=Pick\nscope=command\nform=true\n\nrow=a\ntitle=Apple\n' ;;
        esac
        """)
        let sends = { ((try? String(contentsOfFile: sent, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init) }
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("list")
        try await wait("the open list") { model.openList == "list" && model.openEntry?.command.actions.contains(where: \.isForm) == true }
        let entry = try XCTUnwrap(model.openEntry)
        model.openForm(try XCTUnwrap(entry.command.actions.first { $0.id == "pick" }), on: (entry, nil))
        try await wait("the form") { model.form != nil }

        XCTAssertTrue(model.showsSearch)
        model.searchText = "b"
        XCTAssertEqual(model.searchText, "b")
        XCTAssertEqual(model.form?.draft.choices?.shown.map(\.title), ["Banana", "Blueberry"])
        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))
        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))
        try await wait("the pick") { sends() == ["shown=c"] }
        try await wait("the form again") { model.form?.draft.choices?.shown.first?.isOn == false && model.form?.draft.choices?.query == "b" }
        XCTAssertEqual(model.form?.draft.choices?.selectedItem?.run, "c")
        XCTAssertEqual(model.openItems?.query, "")
        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))
        XCTAssertEqual(model.searchText, "")
        XCTAssertNotNil(model.form)
        XCTAssertEqual(model.form?.draft.choices?.shown.count, 3)
        XCTAssertTrue(model.handleKey(ActionKey(name: "escape")))
        XCTAssertNil(model.form)
    }

    func testTheFormOfASettingMovesWithTheArrowsAndSearchesItsRows() async throws {
        try script("list", header: "read=sheet\n\nsetting=pick", """
        case "$1" in
          pick) printf 'title=Pick\n\nchoice=shown\ntitle=Shown\ntype=multiple\nvalue=a\n\noption=a\ntitle=Apple\n\noption=b\ntitle=Banana\n\noption=c\ntitle=Cherry\n' ;;
          *) printf 'row=a\ntitle=Apple\n' ;;
        esac
        """)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        let change = try XCTUnwrap(SettingsSpot.change(of: "setting:list:pick"))

        model.changeSetting(of: change.spot, with: change.action)
        try await wait("the form") { model.form != nil }
        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))
        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))

        XCTAssertEqual(model.form?.draft.choices?.selectedItem?.run, "c")
        XCTAssertTrue(model.showsSearch)
        model.searchText = "ban"
        XCTAssertEqual(model.form?.draft.choices?.shown.map(\.run), ["b"])
    }

    func testAFormTakesThePlaceOfThePartsOfTheSheetItOpensOn() async throws {
        try script("agenda", header: "read=sheet\n\nsetting=pick", """
        case "$1" in
          pick) printf 'title=Pick\n\nchoice=shown\ntitle=Shown\ntype=multiple\nvalue=a\n\noption=a\ntitle=Apple\n\noption=b\ntitle=Banana\n' ;;
          *) printf 'grid=items\ngrid.wide=next\n\nnumber=next\nvalue=09:30\n\nrepeat=items\n\nrow=e\ntitle=Standup\n' ;;
        esac
        """)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("agenda")
        try await wait("the sheet of parts") { model.shownParts(of: "agenda")?.showsRows == true }
        let change = try XCTUnwrap(SettingsSpot.change(of: "setting:agenda:pick"))

        model.changeSetting(of: change.spot, with: change.action)
        try await wait("the form") { model.form != nil }

        XCTAssertNil(model.shownParts(of: "agenda"))
        XCTAssertNil(model.openPanel)
        model.cancelForm()
        XCTAssertNotNil(model.shownParts(of: "agenda"))
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

    func testASheetHoldsWhatItsScriptPrintsOnlyWhileItsOpenMotionRuns() async throws {
        try await openList()

        XCTAssertTrue(host.openings.contains("list"))
        XCTAssertNil(model.runs.opening.moving)
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

    func testAPickOfARowThatOpensASpotOpensItInPlaceOfTheListWithNoCollapse() async throws {
        let build = plugins.appendingPathComponent("build.sh")
        try "#!/bin/sh\nprintf 'row=g\\ntitle=Guide\\n'\n".writeScript(to: build)
        let rows = plugins.appendingPathComponent("rows.sh")
        try "#!/bin/sh\nprintf 'row=\(CatalogSpot.buildRun)\\ntitle=New spot\\n'\n".writeScript(to: rows)
        host.shipped = [
            Spot(id: ShippedSpot.newID, name: "New spot", url: build, kind: .list, read: .sheet, isOnGrid: false),
            Spot(id: "picker", name: "Picker", url: rows, kind: .list, read: .sheet, rowOpens: [CatalogSpot.buildRun: ShippedSpot.newID])
        ]
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("picker")
        try await wait("the open list") { model.openList == "picker" && model.transition.phase == .open }
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

    func testTheGridSearchFindsAGlobalSpotWithNoKeyBesideARowOfTheSameName() async throws {
        try script("apps", header: "title=Apps\nread=panel\noffers=search", "printf 'row=shortcuts\\ntitle=Shortcuts\\n'")
        try script("shortcuts", header: "title=Shortcuts\nread=panel\noffers=search", "printf 'row=daily\\ntitle=Daily\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])

        model.searchText = "shortcuts"

        try await wait("the row of the app") { model.visible.contains { $0.id == "apps\nshortcuts" } }
        XCTAssertEqual(model.visible.map(\.id), ["shortcuts", "apps\nshortcuts"])
    }

    func testTheGridSearchFindsOnlyTheRowsOfASpotWhoseHeaderSaysGlobalRows() async throws {
        try script("settings", header: "title=System Settings\nread=panel\noffers=rows", "printf 'row=sound\\ntitle=Sound Settings\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])

        model.searchText = "settings"

        try await wait("the row") { model.visible.contains { $0.id == "settings\nsound" } }
        XCTAssertEqual(model.visible.map(\.id), ["settings\nsound"])
    }

    func testTypingBuildsTheCardsAsSearchedItemsOnce() throws {
        try script("notes", header: "title=Notes", "true")
        try script("mail", header: "title=Mail", "true")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        let before = model.spotListBuilds

        for text in ["n", "no", "not", "note", "notes"] { model.searchText = text }

        XCTAssertEqual(model.spotListBuilds - before, 1)
        XCTAssertEqual(model.visible.map(\.id), ["notes"])
    }

    func testAChangedTitleOfACardIsFoundOnTheNextKey() async throws {
        try script("mood", header: "title=Calm\nread=panel", "printf 'title=Stormy\n'")
        model.reload()
        model.isShown = true
        model.searchText = "c"
        XCTAssertEqual(model.visible.map(\.id), ["mood"])
        model.panelWillShow(holding: [])
        try await wait("the read title") { model.sheets["mood"]?.state.title == "Stormy" }

        model.searchText = "st"

        XCTAssertEqual(model.visible.map(\.id), ["mood"])
    }

    /// Shows the panel with a spot that answers the main search for text that starts with a digit.
    private func showAnswers(slow: String = "none") throws {
        let body = #"case "$2" in \#(slow)) sleep 0.5 ;; esac; case "$1" in read) [ -n "$2" ] && printf 'row=%s\ntitle=Is %s\ndetail=Read %s\n' "$2" "$2" "$2" ;; open) printf 'toast=Picked %s\n' "$2" ;; esac"#
        try script("calc", header: "title=Calc\nanswers=^[0-9]", body)
        try script("notes", header: "title=Notes 2\nread=sheet", "printf 'row=a\\ntitle=A\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
    }

    func testASpotAnswersTheMainSearchFirstWhileItsPatternMatchesTheText() async throws {
        try showAnswers()

        model.searchText = "2"
        try await wait("the answer") { model.visible.first?.id == "calc\n2" }
        XCTAssertEqual(model.visible.map(\.id), ["calc\n2", "notes"])
        XCTAssertEqual(model.visible.first?.state.title, "Is 2")
        XCTAssertEqual(model.visible.first?.state.subtitle, "Read 2")

        model.searchText = "notes"
        XCTAssertEqual(model.visible.map(\.id), ["notes"])

        model.searchText = ""
        XCTAssertFalse(model.visible.contains { $0.id.hasPrefix("calc") })
    }

    func testEachKeyMatchesEachAnswersPatternOnce() throws {
        try script("calc", header: "title=Calc\nanswers=^[0-9]", "true")
        try script("units", header: "title=Units\nanswers=[0-9] ?(km|mi)", "true")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        let before = model.answerMatches.count

        for text in ["1", "12", "12 k", "12 km", "12 kmh"] { model.searchText = text }

        XCTAssertEqual(model.answerMatches.count - before, 10)
    }

    func testTheLastAnswerStaysUntilTheNewestTextIsAnswered() async throws {
        try showAnswers(slow: "12")

        model.searchText = "1"
        try await wait("the first answer") { model.visible.first?.id == "calc\n1" }
        model.searchText = "12"
        XCTAssertEqual(model.visible.first?.id, "calc\n1")
        try await wait("the newer answer") { model.visible.first?.id == "calc\n12" }
    }

    func testAPickOfAnAnswerCallsItsSpotWithTheRow() async throws {
        try showAnswers()

        model.searchText = "7"
        try await wait("the answer") { model.visible.first?.id == "calc\n7" }
        model.runSelected()

        try await wait("the toast of the pick") { host.confirms.contains("Picked 7") }
    }

    func testAnAnswerIsAskedAgainWhenThePanelShowsAgain() async throws {
        let calls = folder.appendingPathComponent("calls").path
        let body = #"[ "$1" = read ] && [ -n "$2" ] && echo x >> '\#(calls)' && printf 'row=%s\ntitle=Call %s\n' "$2" "$(wc -l < '\#(calls)' | tr -d ' ')""#
        try script("calc", header: "title=Calc\nanswers=^[0-9]", body)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.searchText = "2"
        try await wait("the first answer") { model.visible.first?.state.title == "Call 1" }

        model.panelDidHide()
        XCTAssertFalse(model.visible.contains { $0.id == "calc\n2" })
        model.panelWillShow(holding: [])

        try await wait("the answer asked again") { model.visible.first?.state.title == "Call 2" }
    }

    func testReturnOnAnAnswerThatIsNotYetNewWaitsForTheNewest() async throws {
        try showAnswers(slow: "12")
        model.searchText = "1"
        try await wait("the first answer") { model.visible.first?.id == "calc\n1" }

        model.searchText = "12"
        model.runSelected()

        try await wait("the pick of the newest answer") { host.confirms.contains("Picked 12") }
        XCTAssertFalse(host.confirms.contains("Picked 1"))
    }

    func testAnAnswerAndARowOfItsSpotWithOneIdShowOnce() async throws {
        try script("both", header: "title=Both\nread=panel\noffers=rows\nanswers=^[0-9]", "printf 'row=7\\ntitle=7 days\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])

        model.searchText = "7"

        try await wait("the row and the answer") { model.sheets["both"]?.answers.count == 1 && model.sheets["both"]?.list.all.count == 1 }
        XCTAssertEqual(model.visible.map(\.id), ["both\n7"])
    }

    func testAnAnswerLeavesTheFailureOfTheSpotsRead() async throws {
        let body = #"[ -n "$2" ] || { echo 'Openspot cannot read.' >&2; exit 1; }; printf 'row=%s\ntitle=%s\n' "$2" "$2""#
        try script("calc", header: "title=Calc\nread=panel\nanswers=^[0-9]", body)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        try await wait("the failure of the read") { model.sheets["calc"]?.failure != nil }

        model.searchText = "2"

        try await wait("the answer") { model.visible.first?.id == "calc\n2" }
        XCTAssertNotNil(model.sheets["calc"]?.failure)
    }

    func testAKeyShowsTheSymbolOfItsCommandOrElseOfItsScriptForAMoment() async throws {
        try script("move", header: "icon=macwindow\n\ncommand=left\ntitle=Left side\nicon=rectangle.lefthalf.inset.filled\n\ncommand=plain\ntitle=Plain", "true")
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
        host.shipped = [Spot(id: ShippedSpot.newID, name: "New spot", url: new, kind: .list, read: .sheet, isOnGrid: false, opensWithNewKey: true)]
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
