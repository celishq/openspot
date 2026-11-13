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
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        suite = "openspot-panel-\(UUID().uuidString)"
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

    private var spots: URL {
        folder.appendingPathComponent("spots", isDirectory: true)
    }

    private func script(_ name: String, header: String, _ body: String) throws {
        let lines = header.split(separator: "\n", omittingEmptySubsequences: false).map { "# \($0)" }.joined(separator: "\n")
        try "#!/bin/sh\n\(lines)\n\(body)\n".writeScript(to: spots.spotFile(name))
    }

    private func wait(_ what: String, until condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("waited for \(what)")
    }

    func testThePanelKeepsItsFocusWhileTouchIDAsksAndTakesItBackAfter() async throws {
        host.show()
        try await wait("the panel to show") { model.isShown }
        let shows = host.shows

        let allowed = await model.allows("show your account words")

        XCTAssertTrue(allowed)
        XCTAssertEqual(host.heldDuringAsks, [true])
        XCTAssertFalse(model.holdsFocus)
        XCTAssertEqual(host.focusTakes, 1)
        XCTAssertEqual(host.presents, 0)
        XCTAssertEqual(host.shows, shows)
    }

    func testAKeyThatTheAPISetsHoldsTheKeysAgainAndBuildsNoGrid() throws {
        try script("move", header: "title=Move\n\nbutton=left\ntitle=Left side", ":")
        model.reload()
        let builds = model.gridBuilds
        let trigger = try XCTUnwrap(Trigger(text: "ctrl+option+l"))
        try model.files.config.assign(trigger, to: "move", act: .command("left"))

        model.configChanged(.keys)

        XCTAssertEqual(model.gridBuilds, builds)
        XCTAssertEqual(host.held.last, [GlobalKey(spot: "move", act: .command("left"), trigger: trigger)])
    }

    func testAPressReadsTheConfigOfTheLastReloadAndNotTheFile() throws {
        model.reload()
        try model.files.config.set("fix_key", to: "cmd+shift+9")

        XCTAssertEqual(model.config.fixKey, Config(text: "").fixKey)
        model.folderChanged()
        XCTAssertEqual(model.config.fixKey, Config(text: "fix_key = \"cmd+shift+9\"").fixKey)
    }

    func testAChoiceThatTheAppWritesBuildsNoGridWhenTheWatchReportsItsWrite() throws {
        try script("one", header: "title=One", "")
        model.reload()
        model.prefer(.wide, for: "one")
        let builds = model.gridBuilds

        model.folderChanged()

        XCTAssertEqual(model.gridBuilds, builds)
        XCTAssertEqual(model.config.arrangement.size(of: "one"), .wide)
    }

    func testAMenuBarPlaceAndAValueThatTheAPISetsBuildNoGridNowOrAtTheNextReload() throws {
        try script("cups", header: "title=Cups\non=clock.60", "printf 'text=c\\ntitle=3\\n'")
        try script("notes", header: "title=Notes", ":")
        model.reload()
        let builds = model.gridBuilds
        let entries = model.entries

        try model.files.config.showInMenuBar("cups", true)
        model.configChanged(.spots(["cups"]))
        try model.files.config.set(setting: "size", of: "cups", to: "big")
        model.configChanged(.value(spot: "cups", caller: nil))
        model.reload()

        XCTAssertEqual(model.gridBuilds, builds)
        XCTAssertEqual(model.entries, entries)
    }

    func testAFileThatChangesBesideASpotThatTheAPITurnsOnStillShowsItsCard() throws {
        try script("cups", header: "title=Cups\non=clock.60", "printf 'text=c\\ntitle=3\\n'")
        model.reload()
        try script("notes", header: "title=Notes", ":")
        try script("cups", header: "title=Mugs\non=clock.60", "printf 'text=c\\ntitle=3\\n'")

        model.configChanged(.spots(["other"]))
        model.folderChanged()

        XCTAssertEqual(Set(model.entries.map { $0.spot.name }), ["Mugs", "Notes"])
    }

    /// Shows the panel with one list of two rows, and opens that list.
    private func openList() async throws {
        try script("list", header: "on=sheet.open", "printf 'row=a\\ntitle=Apple\\n\\nrow=b\\ntitle=Banana\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("list")
        try await wait("the open list") { model.openList == "list" && model.openItems?.shown.count == 2 }
    }

    func testASheetTakesTheLookOfItsCardOnlyWhenItsScriptDrawsTheCard() async throws {
        try script("agenda", header: "on=panel.open", "printf 'grid.small=next\\n\\nnumber=next\\nvalue=09:30\\n\\nrow=e\\ntitle=Standup\\n'")
        try script("year", header: "on=panel.open\nview=year.swift", "printf 'view=year\\ntitle=2026\\n\\nrow=e\\ntitle=Standup\\n'")
        try script("list", header: "on=panel.open", "printf 'row=a\\ntitle=Apple\\n'")
        model.reload()
        model.panelWillShow(holding: [])

        try await wait("the drawn cards") {
            SpotSheetCard.of("agenda", in: model)?.look?.id == "agenda" && SpotSheetCard.of("year", in: model)?.look?.id == "year"
        }
        try await wait("the list") { model.sheets["list"]?.list.shown.count == 1 }
        XCTAssertNotNil(SpotSheetCard.of("list", in: model))
        XCTAssertNil(SpotSheetCard.of("list", in: model)?.look)
    }

    func testTheDefaultConfigOrdersItsSpotsUnderThePersonsOrder() throws {
        let added = Date(timeIntervalSince1970: 1_700_000_000)
        for name in ["a", "b", "c", "d"] {
            try script(name, header: "title=\(name.uppercased())", "")
            try FileManager.default.setAttributes([.creationDate: added], ofItemAtPath: spots.spotFile(name).path)
        }
        let defaults = folder.appendingPathComponent("defaults.toml")
        try "[[spots]]\nid = \"d\"\n\n[[spots]]\nid = \"b\"\n".write(to: defaults, atomically: true, encoding: .utf8)
        let files = AppPlaces(environment: model.files.environment, home: folder, defaults: self.defaults, defaultConfig: defaults)
        let ordered = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2))
        defer { ordered.quit() }

        ordered.reload()
        XCTAssertEqual(ordered.entries.map(\.id), ["a", "d", "c", "b"])

        try ordered.files.config.write(SpotArrangement(choices: [SpotArrangement.Choice(id: "b"), SpotArrangement.Choice(id: "a")]))
        ordered.reload()
        XCTAssertEqual(ordered.entries.map(\.id), ["b", "d", "c", "a"])
    }

    func testTheDefaultConfigSizesASpotUnderThePersonsSize() throws {
        try script("a", header: "title=A", "")
        try script("b", header: "title=B", "")
        try script("c", header: "title=C", "")
        let defaults = folder.appendingPathComponent("defaults.toml")
        try "[[spots]]\nid = \"a\"\nsize = \"small\"\n\n[[spots]]\nid = \"b\"\nsize = \"small\"\n".write(to: defaults, atomically: true, encoding: .utf8)
        let files = AppPlaces(environment: model.files.environment, home: folder, defaults: self.defaults, defaultConfig: defaults)
        let sized = SpotsModel(host: host, files: files, runs: SpotRuns(stopPause: 0.2))
        defer { sized.quit() }
        try sized.files.config.write(SpotArrangement(choices: [SpotArrangement.Choice(id: "b", size: .large)]))

        sized.reload()

        XCTAssertEqual(Dictionary(uniqueKeysWithValues: sized.entries.map { ($0.id, $0.size) }), ["a": .small, "b": .large, "c": .wide])
    }

    func testADownloadedUpdateReadsEachSpotThatListsItWhileThePanelIsHidden() async throws {
        let seen = folder.appendingPathComponent("seen").path
        try script("news", header: "on=panel.open\non=app.update", "[ \"$OPENSPOT_REASON\" = app.update ] && printf '%s' \"$OPENSPOT_VALUE\" > '\(seen)'; printf 'title=News\n'")
        try script("other", header: "on=panel.open\non=app.front", "printf 'title=Other\n'")
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

    func testATypedSearchShowsEachResultAsAFullWidthRowAndAnEmptyOneKeepsTheGrid() throws {
        try script("one", header: "title=One", "")
        try script("two", header: "title=Two", "")
        model.reload()
        let grid = model.placements

        model.searchText = "o"
        XCTAssertEqual(model.placements.map(\.size), [.strip, .strip])
        XCTAssertEqual(model.placements.map(\.row), [0, 1])

        model.searchText = ""
        XCTAssertEqual(model.placements, grid)
    }

    func testAWatchedChangeFindsAScriptMadeExecutableSinceTheLastLoad() throws {
        let late = spots.spotFile("late")
        try FileManager.default.createDirectory(at: late.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\n# title=Late\n".write(to: late, atomically: false, encoding: .utf8)
        model.reload()
        XCTAssertFalse(model.entries.contains { $0.id == "late" })

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: late.path)
        model.folderChanged()

        XCTAssertTrue(model.entries.contains { $0.id == "late" })
    }

    func testAnOpenWithNoChangeTellsNoReaderOfTheCards() throws {
        try script("one", header: "title=One", "")
        model.reload()
        model.panelWillShow(holding: [])
        model.panelWillHide()
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = model.entries } onChange: { changed = true }
        withObservationTracking { _ = model.sheets["one"]?.spot } onChange: { changed = true }

        model.panelWillShow(holding: [])

        XCTAssertFalse(changed)
    }

    func testAShowReadsNoConfigAndChecksNoFolder() throws {
        try script("one", header: "title=One", "")
        try script("two", header: "title=Two", "")
        model.reload()
        var arrangement = SpotArrangement()
        arrangement.set(isOnGrid: false, of: "two")
        try model.files.config.write(arrangement)
        try script("three", header: "title=Three", "")

        model.panelWillShow(holding: [])

        XCTAssertEqual(model.visible.map(\.id), ["one", "two"])
    }

    func testAWatchedChangeOfTheConfigFileTakesIt() throws {
        try script("one", header: "title=One", "")
        try script("two", header: "title=Two", "")
        model.reload()
        var arrangement = SpotArrangement()
        arrangement.set(isOnGrid: false, of: "two")

        try model.files.config.write(arrangement)
        model.folderChanged()

        XCTAssertEqual(model.visible.map(\.id), ["one"])
    }

    func testAnOpenPanelReadsAgainAScriptWhoseBodyAloneChanged() async throws {
        try script("cups", header: "on=panel.open", "printf 'title=One cup\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        try await wait("the first read") { model.entries.first { $0.id == "cups" }?.state.title == "One cup" }

        try "#!/bin/sh\n# on=panel.open\nprintf 'title=Two cups\\n'\n".write(to: spots.spotFile("cups"), atomically: false, encoding: .utf8)
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

    func testPointingAtARowSelectsItUnlessItsMenuIsOpen() async throws {
        try await openList()
        let rows = try XCTUnwrap(model.openItems?.shown)

        model.point(at: .item(rows[1]))
        XCTAssertEqual(model.openItems?.selectedItem?.run, rows[1].run)

        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        model.point(at: .item(rows[0]))
        XCTAssertEqual(model.openItems?.selectedItem?.run, rows[1].run)
    }

    func testTheSearchOfAnOpenListFiltersItsRowsAndLeavesTheGridsSearch() async throws {
        try await openList()

        model.searchText = "ban"

        XCTAssertEqual(model.openItems?.shown.map(\.run), ["b"])
        XCTAssertEqual(model.query, "")
    }

    func testAListDrawsAheadOnlyThePicturesOfTheRowsOnItsFirstScreen() async throws {
        try script("apps", header: "on=sheet.open", "for i in $(seq 1 100); do printf 'row=a%s\\ntitle=App %s\\nicon=/Applications/A%s.app\\n\\n' $i $i $i; done")
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
        try script("apps", header: "on=sheet.open", "for i in $(seq 1 100); do printf 'row=a%s\\ntitle=App %s\\nicon=/Applications/A%s.app\\n\\n' $i $i $i; done")
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
        try script("faces", header: "on=sheet.open", "for i in $(seq 1 100); do printf 'row=f%s\\ntitle=Face %s\\nicon=😀\\n\\n' $i $i; done")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("faces")
        try await wait("the glyphs") { !host.glyphLists.isEmpty }

        XCTAssertEqual(host.glyphLists, [Array(repeating: "😀", count: 100)])
    }

    func testAReadOfTheSameRowsGivesTheGlyphsItCollectedBefore() async throws {
        let calls = folder.appendingPathComponent("calls").path
        try script("faces", header: "on=sheet.open", "echo x >> '\(calls)'; for i in $(seq 1 100); do printf 'row=f%s\\ntitle=Face %s\\nicon=😀\\n\\n' $i $i; done")
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
        try script("other", header: "on=sheet.open", "printf 'row=a\\ntitle=A\\n'")
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
        try script("parts", header: "on=sheet.open", "printf 'text=a\\ntitle=A\\n'")
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

    func testASizeInAReadLeavesTheCardAtItsDefaultSize() async throws {
        try script("grow", header: "on=panel.open", "printf 'detail=Read\\nsize=large\\n'")
        model.reload()
        model.panelWillShow(holding: [])
        try await wait("the read") { model.visible.first?.state.subtitle == "Read" }

        XCTAssertEqual(model.visible.first?.size, .wide)
    }

    func testASubmitThatEndsAfterThePersonOpenedANewFormLeavesTheNewForm() async throws {
        let gate = folder.appendingPathComponent("gate").path
        let reads = folder.appendingPathComponent("reads").path
        try script("list", header: "on=sheet.open", """
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
            printf 'button=new\\ntitle=New\\nscope=spot\\nform=true\\n\\nbutton=edit\\ntitle=Edit\\nscope=spot\\nform=true\\n\\nrow=a\\ntitle=Apple\\n' ;;
        esac
        """)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("list")
        try await wait("the open list") { model.openList == "list" && model.openEntry?.spot.actions.contains(where: \.isForm) == true }
        let entry = try XCTUnwrap(model.openEntry)
        let action = try XCTUnwrap(entry.spot.actions.first { $0.id == "new" })
        let edit = try XCTUnwrap(entry.spot.actions.first { $0.id == "edit" })
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
        try script("list", header: "on=sheet.open", "printf 'row=a\\ntitle=Apple\\n'")
        try script("other", header: "on=sheet.open", "printf 'row=a\\ntitle=A\\n'")
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
        try script("list", header: "on=sheet.open", """
        case "$1" in
          pick)
            input=$(cat)
            [ -z "$input" ] || printf '%s\n' "$input" >> '\(sent)'
            printf 'title=Pick\n\nchoice=shown\ntitle=Shown\ntype=multiple\nvalue=a\n\noption=a\ntitle=Apple\n\noption=b\ntitle=Banana\n\noption=c\ntitle=Cherry\n' ;;
          *)
            echo read >> '\(reads)'
            printf 'button=pick\ntitle=Pick\nscope=spot\nform=true\n\nrow=a\ntitle=Apple\n' ;;
        esac
        """)
        let sends = { ((try? String(contentsOfFile: sent, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init) }
        let readCount = { ((try? String(contentsOfFile: reads, encoding: .utf8)) ?? "").split(separator: "\n").count }
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("list")
        try await wait("the open list") { model.openList == "list" && model.openEntry?.spot.actions.contains(where: \.isForm) == true }
        let entry = try XCTUnwrap(model.openEntry)
        let action = try XCTUnwrap(entry.spot.actions.first { $0.id == "pick" })
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
        try script("list", header: "on=sheet.open", """
        case "$1" in
          pick)
            input=$(cat)
            [ -z "$input" ] || printf '%s\n' "$input" >> '\(sent)'
            printf 'title=Pick\n\nchoice=shown\ntitle=Shown\ntype=multiple\nvalue=a\n\noption=a\ntitle=Apple\n\noption=b\ntitle=Banana\n\noption=c\ntitle=Blueberry\n' ;;
          *) printf 'button=pick\ntitle=Pick\nscope=spot\nform=true\n\nrow=a\ntitle=Apple\n' ;;
        esac
        """)
        let sends = { ((try? String(contentsOfFile: sent, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init) }
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("list")
        try await wait("the open list") { model.openList == "list" && model.openEntry?.spot.actions.contains(where: \.isForm) == true }
        let entry = try XCTUnwrap(model.openEntry)
        model.openForm(try XCTUnwrap(entry.spot.actions.first { $0.id == "pick" }), on: (entry, nil))
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
        try script("list", header: "on=sheet.open\n\nfield=pick", """
        case "$1" in
          pick) printf 'title=Pick\n\nchoice=shown\ntitle=Shown\ntype=multiple\nvalue=a\n\noption=a\ntitle=Apple\n\noption=b\ntitle=Banana\n\noption=c\ntitle=Cherry\n' ;;
          *) printf 'row=a\ntitle=Apple\n' ;;
        esac
        """)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        XCTAssertFalse(model.changeSetting("pick", of: "gone"))
        XCTAssertTrue(model.changeSetting("pick", of: "list"))
        try await wait("the form") { model.form != nil }
        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))
        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))

        XCTAssertEqual(model.form?.draft.choices?.selectedItem?.run, "c")
        XCTAssertTrue(model.showsSearch)
        model.searchText = "ban"
        XCTAssertEqual(model.form?.draft.choices?.shown.map(\.run), ["b"])
    }

    func testAFormTakesThePlaceOfThePartsOfTheSheetItOpensOn() async throws {
        try script("agenda", header: "on=sheet.open\n\nfield=pick", """
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
        XCTAssertTrue(model.changeSetting("pick", of: "agenda"))
        try await wait("the form") { model.form != nil }

        XCTAssertNil(model.shownParts(of: "agenda"))
        XCTAssertNil(model.openPanel)
        model.cancelForm()
        XCTAssertNotNil(model.shownParts(of: "agenda"))
    }

    func testAFormThatArrivesAfterThePanelHidDoesNotOpen() async throws {
        let gate = folder.appendingPathComponent("gate").path
        try script("list", header: "on=sheet.open", """
        case "$1" in
          new)
            n=0; while [ ! -f '\(gate)' ] && [ $n -lt 1500 ]; do sleep 0.02; n=$((n + 1)); done
            printf 'title=New\\n\\nfield=a\\ntitle=A\\n' ;;
          *) printf 'button=new\\ntitle=New\\nscope=spot\\nform=true\\n\\nrow=a\\ntitle=Apple\\n' ;;
        esac
        """)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("list")
        try await wait("the open list") { model.openList == "list" && model.openEntry?.spot.actions.isEmpty == false }
        let entry = try XCTUnwrap(model.openEntry)
        let action = try XCTUnwrap(entry.spot.actions.first { $0.id == "new" })
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
        try script("other", header: "on=sheet.open", "printf 'row=a\\ntitle=A\\n'")
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

    func testASpotThatTheAPIOpensOpensInPlaceOfTheListWithNoCollapse() async throws {
        try script("build", header: "on=sheet.open", "printf 'row=g\\ntitle=Guide\\n'")
        try script("picker", header: "on=sheet.open", "printf 'row=new\\ntitle=New spot\\n'")
        model.reload()
        model.setOnGrid(false, for: "build")
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("picker")
        try await wait("the open list") { model.openList == "picker" && model.transition.phase == .open }
        let entry = try XCTUnwrap(model.openEntry)
        host.motions = []
        host.phases = []

        XCTAssertEqual(entry.id, "picker")

        XCTAssertTrue(model.openSheet("build"))

        try await wait("the New spot sheet") { model.openList == "build" }
        XCTAssertEqual(model.transition.phase, .open)
        XCTAssertFalse(host.phases.contains(.closing))
        XCTAssertFalse(host.phases.contains(.ready))
        XCTAssertFalse(host.motions.contains(.sheet(isOpen: false)))
    }

    func testASheetWithNoCardShowsAndHidesAtOnce() async throws {
        try script("list", header: "on=sheet.open", "printf 'row=a\\ntitle=Apple\\n'")
        try script("other", header: "on=sheet.open", "printf 'row=a\\ntitle=A\\n'")
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
        try script("list", header: "on=sheet.open", "printf 'row=a\\ntitle=Apple\\n'")
        try script("other", header: "on=sheet.open", "printf 'row=a\\ntitle=A\\n'")
        model.reload()

        model.searchText = "oth"

        XCTAssertEqual(model.visible.map(\.id), ["other"])
    }

    /// Opens a sheet that a script prints on each read. The script writes each other call to the returned file.
    private func openParts(_ sheet: String) async throws -> URL {
        let calls = folder.appendingPathComponent("calls")
        try script("parts", header: "on=sheet.open", "if [ \"$1\" = read ]; then printf '\(sheet)'; else echo \"$@\" >> '\(calls.path)'; fi")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.open("parts", moving: true)
        try await wait("the open sheet") { model.openList == "parts" && model.openPanel != nil }
        return calls
    }

    private func calls(in file: URL) -> [String] {
        ((try? String(contentsOf: file, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    func testReturnOpensAFocusedMenuAndPressesAFocusedButton() async throws {
        let calls = try await openParts(
            "grid=look look\\ngrid=key key\\ngrid=make play\\n\\nchoice=look\\nvalue=a\\n\\noption=a\\ntitle=A\\n\\noption=b\\ntitle=B\\n\\n"
                + "field=key\\ntype=hotkey\\nvalue=option+c\\n\\nbutton=make\\ntitle=Make\\n\\nbutton=play\\ntitle=Play\\n\\nbutton=paste\\ntitle=Paste\\n"
        )

        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))
        XCTAssertEqual(model.sheets["parts"]?.menuOpening?.part, "look")
        for name in ["down", "down", "right"] { XCTAssertTrue(model.handleKey(ActionKey(name: name))) }
        XCTAssertEqual(model.openPanel?.selectedPart?.id, "play")
        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))

        try await wait("the press of play") { self.calls(in: calls) == ["play"] }
    }

    func testAKeyPressedWhileTheShortcutRowOnlyHasTheFocusIsNotRecorded() async throws {
        let calls = try await openParts("grid=key\\n\\nfield=key\\ntype=hotkey\\nvalue=option+c\\n")

        XCTAssertEqual(model.openPanel?.selectedPart?.id, "key")
        XCTAssertFalse(model.handleKey(ActionKey(name: "c", isCommand: true)))
        XCTAssertNil(model.recording)
        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))
        XCTAssertEqual(model.recording, "key")
        model.stopRecording()
        XCTAssertEqual(self.calls(in: calls), [])
    }

    func testTheSideArrowsStepAFocusedSliderAndLeaveAFieldItsText() async throws {
        _ = try await openParts("grid=level\\ngrid=note\\n\\nfield=level\\ntype=slider\\nvalue=50\\n\\nfield=note\\nvalue=Hi\\n")

        XCTAssertFalse(model.handleKey(ActionKey(name: "right")))
        XCTAssertFalse(model.handleKey(ActionKey(name: "return")))
        XCTAssertFalse(model.handleKey(ActionKey(name: "down")))
        XCTAssertTrue(model.handleKey(ActionKey(name: "up")))
        XCTAssertTrue(model.handleKey(ActionKey(name: "right")))
        XCTAssertEqual(model.openPanel?.parts.first?.value, "55")
        XCTAssertTrue(model.handleKey(ActionKey(name: "left")))
        XCTAssertTrue(model.handleKey(ActionKey(name: "left")))
        XCTAssertEqual(model.openPanel?.parts.first?.value, "45")
    }

    func testDownOnTheLastRowReachesTheButtonBelowAndUpComesBack() async throws {
        let calls = try await openParts(
            "grid=list\\ngrid=add\\n\\nrepeat=list\\n\\nbutton=add\\ntitle=Add\\n\\nrow=a\\ntitle=A\\n\\nrow=b\\ntitle=B\\n"
        )
        try await wait("the rows") { model.openItems?.shown.count == 2 }

        XCTAssertFalse(model.handleKey(ActionKey(name: "down")))
        model.moveItemLine(by: 1)
        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))
        XCTAssertEqual(model.openPanel?.selectedPart?.id, "add")
        XCTAssertTrue(model.handleKey(ActionKey(name: "return")))
        try await wait("the press of add") { self.calls(in: calls) == ["add"] }
        XCTAssertTrue(model.handleKey(ActionKey(name: "up")))
        XCTAssertNil(model.openPanel?.selectedPart)
        XCTAssertEqual(model.openItems?.selected, 1)
    }

    func testEnterRunsASpotWithPressOpenAndCommandEnterOpensItsSheet() async throws {
        let log = folder.appendingPathComponent("calls")
        try script("conf", header: "on=sheet.open\npress=open", "if [ \"$1\" = read ]; then printf 'row=a\\ntitle=A\\n'; else echo \"$@\" >> '\(log.path)'; fi")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        let calls = { ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init) }

        XCTAssertEqual(model.hint, "⏎ Run   ⌘⏎ Settings   ⌘K Actions")
        model.pressHint("⏎")
        try await wait("the run") { calls() == ["open"] }
        XCTAssertNil(model.openList)
        XCTAssertEqual(host.dismissals, 1)

        model.isShown = true
        model.panelWillShow(holding: [])
        XCTAssertTrue(model.handleKey(ActionKey(name: "return", isCommand: true)))
        try await wait("the sheet") { model.openList == "conf" }
        XCTAssertFalse(model.openSelected())
        XCTAssertEqual(calls(), ["open"])
    }

    func testAClickWithCommandOpensTheSheetOfASpotWithPressOpen() async throws {
        let log = folder.appendingPathComponent("calls")
        try script("conf", header: "on=sheet.open\npress=open", "if [ \"$1\" = read ]; then printf 'row=a\\ntitle=A\\n'; else echo \"$@\" >> '\(log.path)'; fi")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])

        model.tap("conf", opening: true)

        try await wait("the sheet") { model.openList == "conf" }
        XCTAssertFalse(FileManager.default.fileExists(atPath: log.path))
    }

    func testCommandEnterLeavesASpotWithNoPressOpenToItsActions() async throws {
        try script("list", header: "on=sheet.open", "printf 'row=a\\ntitle=A\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])

        XCTAssertFalse(model.hint.contains("Settings"))
        XCTAssertFalse(model.handleKey(ActionKey(name: "return", isCommand: true)))
        XCTAssertNil(model.openList)
    }

    func testTheGridSearchFindsAGlobalSpotWithNoKeyBesideARowOfTheSameName() async throws {
        try script("apps", header: "title=Apps\non=panel.open\noffers=search", "printf 'row=shortcuts\\ntitle=Shortcuts\\n'")
        try script("shortcuts", header: "title=Shortcuts\non=panel.open\noffers=search", "printf 'row=daily\\ntitle=Daily\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])

        model.searchText = "shortcuts"

        try await wait("the row of the app") { model.visible.contains { $0.id == "apps\nshortcuts" } }
        XCTAssertEqual(model.visible.map(\.id), ["shortcuts", "apps\nshortcuts"])
    }

    func testTheGridSearchFindsASpotThatOffersSearchAndItsRows() async throws {
        try script("settings", header: "title=System Settings\non=panel.open\noffers=search", "printf 'row=sound\\ntitle=Sound Settings\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])

        model.searchText = "settings"

        try await wait("the row") { model.visible.contains { $0.id == "settings\nsound" } }
        XCTAssertEqual(model.visible.map(\.id), ["settings", "settings\nsound"])
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

    func testAKeyInAFormOfOneChoiceTellsNoReaderOfTheFormsPlaceAndKind() async throws {
        try script("list", header: "on=sheet.open", """
        case "$1" in
          pick) printf 'title=Pick\n\nchoice=shown\ntitle=Shown\ntype=multiple\nvalue=a\n\noption=a\ntitle=Apple\n\noption=b\ntitle=Banana\n' ;;
          *) printf 'button=pick\ntitle=Pick\nscope=spot\nform=true\n\nrow=a\ntitle=Apple\n' ;;
        esac
        """)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("list")
        try await wait("the open list") { model.openList == "list" && model.openEntry?.spot.actions.contains(where: \.isForm) == true }
        let entry = try XCTUnwrap(model.openEntry)
        model.openForm(try XCTUnwrap(entry.spot.actions.first { $0.id == "pick" }), on: (entry, nil))
        try await wait("the form") { model.form != nil }
        XCTAssertNotNil(model.formRect)
        XCTAssertTrue(model.formHasChoices)
        XCTAssertTrue(model.formIsMultiple)
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = (model.formRect, model.formHasChoices, model.formIsMultiple, model.isMenuOpen, model.gridHeight) } onChange: { changed = true }

        model.searchText = "b"
        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))

        XCTAssertFalse(changed)
    }

    func testAMoveInTheActionsMenuTellsNoReaderThatTheMenuIsOpen() throws {
        try script("weather", header: "title=Weather", ":")
        model.reload()
        model.isShown = true
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "weather" })
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        XCTAssertTrue(model.isMenuOpen)
        nonisolated(unsafe) var changed = false
        withObservationTracking { _ = model.isMenuOpen } onChange: { changed = true }

        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))

        XCTAssertFalse(changed)
    }

    /// Reads what the body of the panel's root view, SpotsView, reads of the model, and what the body of the search field,
    /// SpotFieldView, reads, and calls `told` when a later change tells any of them.
    private func trackPanelAndField(_ told: @escaping @Sendable () -> Void) {
        withObservationTracking {
            let id = model.transition.id
            _ = (model.transition, model.fieldSheet, model.showsFieldDrop, model.isShown, model.isMenuOpen, model.menuBackdropHeight)
            _ = (model.gridHeight, model.formRect, model.formHasChoices, model.entries.first { $0.id == id })
            _ = SpotSheetCard.of(id, in: model)
            _ = model.sheets[id ?? ""].map { ($0.sheetRect, $0.showsField) }
            _ = model.transition.replaced.map { model.sheets[$0]?.sheetRect }
            _ = (model.isEditing, model.fieldDrop, model.entries.first { $0.id == id }?.state.title)
        } onChange: {
            told()
        }
    }

    func testAKeyInAFormTellsNeitherThePanelNorTheField() async throws {
        try script("list", header: "on=sheet.open", """
        case "$1" in
          pick) printf 'title=Pick\n\nchoice=shown\ntitle=Shown\nvalue=a\n\noption=a\ntitle=Apple\n\noption=b\ntitle=Banana\n' ;;
          *) printf 'button=pick\ntitle=Pick\nscope=spot\nform=true\n\nrow=a\ntitle=Apple\n' ;;
        esac
        """)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("list")
        try await wait("the open list") { model.openList == "list" && model.openEntry?.spot.actions.contains(where: \.isForm) == true }
        let entry = try XCTUnwrap(model.openEntry)
        model.openForm(try XCTUnwrap(entry.spot.actions.first { $0.id == "pick" }), on: (entry, nil))
        try await wait("the form") { model.form != nil }
        nonisolated(unsafe) var told = false
        trackPanelAndField { told = true }

        model.searchText = "b"
        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))

        XCTAssertEqual(model.form?.draft.choices?.query, "b")
        XCTAssertFalse(told)
    }

    func testAKeyInTheSearchOfALongSheetTellsNeitherThePanelNorTheField() async throws {
        try script("fruit", header: "on=sheet.open", "for i in $(seq 1 50); do printf 'row=a%s\\ntitle=Apple %s\\n\\nrow=p%s\\ntitle=Pear %s\\n\\n' $i $i $i $i; done")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.press("fruit")
        try await wait("the open list") { model.openList == "fruit" && model.openItems?.shown.count == 100 }
        let rect = try XCTUnwrap(model.openSheet?.sheetRect)
        nonisolated(unsafe) var told = false
        trackPanelAndField { told = true }

        model.searchText = "ap"

        XCTAssertEqual(model.openItems?.shown.count, 50)
        XCTAssertEqual(model.openSheet?.sheetRect, rect)
        XCTAssertEqual(model.openSheet?.showsField, true)
        XCTAssertFalse(told)
    }

    func testAKeyInTheActionsMenuTellsNeitherThePanelNorTheField() throws {
        try script("weather", header: "title=Weather", ":")
        model.reload()
        model.isShown = true
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "weather" })
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let menu = try XCTUnwrap(model.menu)
        model.placeMenu(ActionMenuFrame(item: CGRect(x: 16, y: 80, width: 80, height: 80), menu: menu, bounds: ActionMenuFrame.bounds(under: SpotTokens.gridTop)))
        XCTAssertGreaterThan(model.menuBackdropHeight, 0)
        nonisolated(unsafe) var told = false
        trackPanelAndField { told = true }

        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))
        model.searchMenu("e")

        XCTAssertFalse(told)
    }

    func testTheBackdropUnderTheMenuGrowsOnTheMenusMotionAndGoesWhenItsCloseEnds() throws {
        try script("weather", header: "title=Weather", ":")
        model.reload()
        model.isShown = true
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "weather" })
        XCTAssertTrue(model.handleKey(ActionKey(name: "k", isCommand: true)))
        let menu = try XCTUnwrap(model.menu)
        let frame = ActionMenuFrame(item: CGRect(x: 16, y: 80, width: 80, height: 80), menu: menu, bounds: ActionMenuFrame.bounds(under: SpotTokens.gridTop))

        model.placeMenu(frame)

        XCTAssertEqual(model.menuFrame, frame)
        XCTAssertEqual(model.menuBackdropHeight, frame.rect.maxY + SpotTokens.halo + SpotTokens.hintBlock)
        XCTAssertEqual(host.motions.last, .sheet(isOpen: true))
        model.closeMenu()
        XCTAssertNil(model.menuFrame)
        XCTAssertEqual(model.menuBackdropHeight, 0)
        XCTAssertEqual(host.motions.last, .sheet(isOpen: false))
    }

    func testTheHintOfTheGridKeepsItsWordsAndTellsNoReaderWhileTheyStayTheSame() async throws {
        try script("notes", header: "title=Notes", "true")
        try script("mail", header: "title=Mail", "true")
        model.reload()
        model.isShown = true
        model.followHint()
        XCTAssertEqual(model.gridHint, HintWords(model.hint))
        XCTAssertFalse(model.gridHint.groups.isEmpty)
        nonisolated(unsafe) var told = false
        withObservationTracking { _ = (model.gridHint, model.sheetHint) } onChange: { told = true }

        model.selected = 1
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(model.gridHint, HintWords(model.hint))
        XCTAssertFalse(told)
    }

    func testTheHintOfTheGridFadesToTheWordsOfEditSpots() async throws {
        try script("notes", header: "title=Notes", "true")
        model.reload()
        model.isShown = true
        model.followHint()
        let grid = model.gridHint

        model.beginEditing()

        try await wait("the words of Edit Spots") { model.gridHint == HintWords(model.hint) && model.gridHint != grid }
        XCTAssertEqual(host.motions.last, .fade)
    }

    func testTheSameTextOfTheSearchFindsNothingAgain() throws {
        try script("notes", header: "title=Notes", "true")
        model.reload()
        model.query = "no"
        let before = model.visibleUpdates

        model.query = "no"

        XCTAssertEqual(model.visibleUpdates, before)
    }

    func testNewRowsOfACardOnTheGridWithNoSearchFindNothingAgain() throws {
        try script("notes", header: "title=Notes", "true")
        model.reload()
        let before = model.visibleUpdates

        model.sheets["notes"]?.list = ItemList(items: [SpotItem(title: "A", run: "a")])

        XCTAssertEqual(model.visibleUpdates, before)
        XCTAssertEqual(model.visible.map(\.id), ["notes"])
    }

    func testAStateThatTakesACardOffTheGridHidesItWithNoSearch() throws {
        try script("notes", header: "title=Notes", "true")
        model.reload()

        model.sheets["notes"]?.state = SpotState(title: "Notes", isOnGrid: false)

        XCTAssertEqual(model.visible.map(\.id), [])
    }

    func testAChangedTitleOfACardIsFoundOnTheNextKey() async throws {
        try script("mood", header: "title=Calm\non=panel.open", "printf 'title=Stormy\n'")
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
        let body = #"case "$OPENSPOT_VALUE" in \#(slow)) sleep 0.5 ;; esac; case "$1" in read) [ -n "$OPENSPOT_VALUE" ] && printf 'row=%s\ntitle=Is %s\ndetail=Read %s\n' "$OPENSPOT_VALUE" "$OPENSPOT_VALUE" "$OPENSPOT_VALUE" ;; open) printf 'toast=Picked %s\n' "$2" ;; esac"#
        try script("calc", header: "title=Calc\non=search.text ^[0-9]", body)
        try script("notes", header: "title=Notes 2\non=sheet.open", "printf 'row=a\\ntitle=A\\n'")
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

    func testAnAnswerThatDrawsALargeCardTakesTwoFullRowsAndAPressSendsItsMainValue() async throws {
        let body = #"case "$1" in read) printf 'grid.large=sum sum sum sum\ngrid.large=answer answer answer answer\nmain=answer\n\ntext=sum\ntitle=%s\n\nnumber=answer\nvalue=14\n' "$OPENSPOT_VALUE" ;; open) printf 'toast=Picked %s\n' "$2" ;; esac"#
        try script("calc", header: "title=Calc\non=search.text ^[0-9]", body)
        try script("notes", header: "title=Notes 2\non=sheet.open", "printf 'row=a\\ntitle=A\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])

        model.searchText = "2"
        try await wait("the answer card") { model.visible.first?.id == "calc\n14" }

        XCTAssertEqual(model.placements.map(\.size), [.large, .strip])
        XCTAssertEqual(model.visible.first?.state.face.answerSize, .large)
        model.runSelected()
        try await wait("the toast of the pick") { host.confirms.contains("Picked 14") }
    }

    func testEachKeyMatchesEachAnswersPatternOnce() throws {
        try script("calc", header: "title=Calc\non=search.text ^[0-9]", "true")
        try script("units", header: "title=Units\non=search.text [0-9] ?(km|mi)", "true")
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
        let body = #"[ "$1" = read ] && [ -n "$OPENSPOT_VALUE" ] && echo x >> '\#(calls)' && printf 'row=%s\ntitle=Call %s\n' "$OPENSPOT_VALUE" "$(wc -l < '\#(calls)' | tr -d ' ')""#
        try script("calc", header: "title=Calc\non=search.text ^[0-9]", body)
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

    func testReturnOnAKeptRowOfASlowInlineSpotWaitsForTheNewestAnswer() async throws {
        try FileManager.default.createDirectory(at: spots.appendingPathComponent("calc.spot"), withIntermediateDirectories: true)
        try """
        // title=Calc
        // on=search.text ^[0-9]
        function main([id, row], env) {
          const text = id === "open" ? row : env.OPENSPOT_VALUE
          if (id === "open") return `toast=Picked ${text}\\n`
          if (text === "12") { const end = Date.now() + 300; while (Date.now() < end) {} }
          return `row=${text}\\ntitle=Is ${text}\\n`
        }
        """.write(to: spots.spotFile("calc", extension: "js"), atomically: true, encoding: .utf8)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.searchText = "1"
        try await wait("the first answer") { model.visible.first?.id == "calc\n1" }

        model.searchText = "12"
        XCTAssertEqual(model.visible.first?.id, "calc\n1")
        model.runSelected()

        try await wait("the pick of the newest answer") { host.confirms.contains("Picked 12") }
        XCTAssertFalse(host.confirms.contains("Picked 1"))
    }

    func testAStayingSpotAnswersTheKeptTextWhenThePanelShowsAgain() async throws {
        try script("calc", header: "title=Calc\nmode=stay\non=search.text ^[0-9]", """
        while IFS= read -r line; do
          case "$line" in call=*) call=${line#call=}; text= ;; env.OPENSPOT_VALUE=*) text=${line#env.OPENSPOT_VALUE=} ;; esac
          [ -n "$line" ] || { [ -n "$text" ] && printf 'end=%s\\n\\nrow=%s\\ntitle=%s\\n---\\n' "$call" "$text" "$text" || printf 'end=%s\\n---\\n' "$call"; }
        done
        """)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        model.searchText = "5"
        try await wait("the answer") { model.visible.first?.id == "calc\n5" }

        model.panelWillHide()
        model.panelDidHide()
        model.panelWillShow(holding: [])

        try await wait("the answer again") { model.visible.first?.id == "calc\n5" }
    }

    func testAnAnswerAndARowOfItsSpotWithOneIdShowOnce() async throws {
        try script("both", header: "title=Both\non=panel.open\noffers=search\non=search.text ^[0-9]", "printf 'row=7\\ntitle=7 days\\n'")
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])

        model.searchText = "7"

        try await wait("the row and the answer") { model.sheets["both"]?.answers.count == 1 && model.sheets["both"]?.list.all.count == 1 }
        XCTAssertEqual(model.visible.map(\.id), ["both\n7"])
    }

    func testAnAnswerLeavesTheFailureOfTheSpotsRead() async throws {
        let body = #"[ -n "$OPENSPOT_VALUE" ] || { echo 'Openspot cannot read.' >&2; exit 1; }; printf 'row=%s\ntitle=%s\n' "$OPENSPOT_VALUE" "$OPENSPOT_VALUE""#
        try script("calc", header: "title=Calc\non=panel.open\non=search.text ^[0-9]", body)
        model.reload()
        model.isShown = true
        model.panelWillShow(holding: [])
        try await wait("the failure of the read") { model.sheets["calc"]?.failure != nil }

        model.searchText = "2"

        try await wait("the answer") { model.visible.first?.id == "calc\n2" }
        XCTAssertNotNil(model.sheets["calc"]?.failure)
    }

    func testAKeyShowsTheSymbolOfItsCommandOrElseOfItsScriptForAMoment() async throws {
        try script("move", header: "icon=macwindow\n\nbutton=left\ntitle=Left side\nicon=rectangle.lefthalf.inset.filled\n\nbutton=plain\ntitle=Plain", "true")
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

    func testTheAPIOpensASheetWithThePanelHiddenAndNoSpotForAnUnknownID() async throws {
        try script("list", header: "on=sheet.open", "printf 'row=a\\ntitle=Apple\\n'")
        model.reload()

        XCTAssertFalse(model.openSheet("gone"))
        XCTAssertTrue(model.openSheet("list"))

        XCTAssertEqual(host.shows, 1)
        try await wait("the sheet") { model.openList == "list" }
    }

    func testAKeyOfTheConfigOpensTheSheetOfItsSpotFromTheGridAndFromEditSpots() async throws {
        let new = spots.spotFile("new")
        try "#!/bin/sh\n# on=sheet.open\nprintf 'row=g\\ntitle=Guide\\n'\n".writeScript(to: new)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("config"), withIntermediateDirectories: true)
        try "[[spots]]\nid = \"new\"\ngrid = false\nkey = \"cmd+n\"\n".write(to: folder.appendingPathComponent("config/config.toml"), atomically: true, encoding: .utf8)
        model.reload()
        model.isShown = true

        XCTAssertTrue(model.handleKey(ActionKey(name: "n", isCommand: true)))
        try await wait("the New spot sheet") { model.openList == "new" }

        model.closeList(moving: false)
        model.beginEditing()
        XCTAssertTrue(model.handleKey(ActionKey(name: "n", isCommand: true)))
        XCTAssertFalse(model.isEditing)
        try await wait("the New spot sheet from Edit Spots") { model.openList == "new" }
    }

    func testAKeywordFindsASpotAndTheStoreStartsEditSpotsWithTheSearchCleared() throws {
        try script("store", header: "title=Spots\nkeywords=edit spots", "true")
        model.reload()

        model.query = "edit spots"
        XCTAssertEqual(model.visible.first?.id, "store")

        model.openStore()
        XCTAssertTrue(model.isEditing)
        XCTAssertEqual(model.query, "")
    }
}
