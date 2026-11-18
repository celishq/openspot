import XCTest
@testable import OpenspotCore

@MainActor
final class PanelKeysTests: PanelCase {
    private let enter = ActionKey(name: "return")
    private let settings = ActionKey(name: "return", isCommand: true)
    private let actions = ActionKey(name: "k", isCommand: true)
    private let history = ActionKey(name: "y", isCommand: true)
    private let tab = ActionKey(name: "\t")
    private let up = ActionKey(name: "up")
    private let down = ActionKey(name: "down")
    private let left = ActionKey(name: "left")
    private let right = ActionKey(name: "right")

    private func showGrid() async throws {
        try script("alpha", toml: "title = 'Alpha'", "true")
        try script("beta", toml: "title = 'Beta'", "true")
        try script("weather", toml: "title = 'Weather'\non = ['sheet.open']\npress = 'open'", ":")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
    }

    private func select(_ id: String) throws {
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == id })
    }

    private func openInfo() async throws {
        try script("info", toml: "on = ['sheet.open']\npages = ['a']", """
        page=$(sed -n 's/^route=//p')
        if [ -n "$page" ]; then printf 'text=detail\\ntitle=Detail\\n'; else printf 'text=first\\ntitle=First\\n'; fi
        """)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("info")
        try await wait("the first sheet") { self.model.openParts?.parts.first?.title == "First" }
    }

    func testTheModeFollowsWhatTakesTheKeys() async throws {
        try await showGrid()
        XCTAssertEqual(model.mode, .grid)
        try select("weather")

        XCTAssertTrue(model.handleKey(actions))
        XCTAssertEqual(model.mode, .menu)
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertEqual(model.mode, .grid)

        model.beginEditing()
        XCTAssertEqual(model.mode, .edit)
        model.toggleRecording(id: "alpha")
        XCTAssertEqual(model.mode, .recording)
        model.stopRecording()
        model.endEditing()
        XCTAssertEqual(model.mode, .grid)

        try await openList()
        XCTAssertEqual(model.mode, .sheet)
        XCTAssertTrue(model.handleKey(toGrid))
        try await wait("the grid") { self.model.mode == .grid }
    }

    func testTheCardsMoveOnlyWhileTheGridShowsInFront() async throws {
        try await showGrid()
        XCTAssertTrue(model.cardsMove)
        try select("weather")

        XCTAssertTrue(model.handleKey(actions))
        XCTAssertFalse(model.cardsMove)
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertTrue(model.cardsMove)

        model.beginEditing()
        XCTAssertFalse(model.cardsMove)
        model.endEditing()
        XCTAssertTrue(model.cardsMove)

        model.isShown = false
        XCTAssertFalse(model.cardsMove)
        model.isShown = true

        try await openList()
        XCTAssertFalse(model.cardsMove)
    }

    func testASearchThatFindsNoSpotTeachesTheSlash() async throws {
        try script("list", toml: "title = 'List'\non = ['sheet.open']", "printf 'row=a\\ntitle=A\\n'")
        await model.reload()

        model.query = "zzz"

        try await wait("the hint of the slash") { self.model.hint.hasPrefix("Type / and a spot's name to run it with text") }
        model.query = "lis"
        try await wait("the list found") { !self.model.visible.isEmpty }
        XCTAssertFalse(model.hint.contains("Type /"))
    }

    func testAKeyAddedInOneRowShowsInTheHint() async throws {
        try await showGrid()
        model.beginEditing()
        let rows = model.keyRows(of: .edit)

        XCTAssertEqual(KeyRow.hint(of: rows), "S Size   H Hide   ⇧ Arrows Move   Esc Done")
        XCTAssertEqual(model.hint, KeyRow.hint(of: rows))
        let added = rows + [KeyRow("x", words: "Extra") { _ in true }]
        XCTAssertEqual(KeyRow.hint(of: added), "S Size   H Hide   ⇧ Arrows Move   Esc Done   X Extra")
    }

    func testOnTheGridEscClearsTheSearchThenHidesAndTabGoesToTheText() async throws {
        try await showGrid()
        model.query = "al"
        model.landSearch()

        XCTAssertTrue(model.handleKey(escape))
        XCTAssertEqual(model.query, "")
        XCTAssertEqual(host.dismissals, 0)
        XCTAssertFalse(model.handleKey(tab))
        XCTAssertFalse(model.handleKey(history))
        XCTAssertFalse(model.handleKey(actions))
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertEqual(host.dismissals, 1)
    }

    func testOnTheGridTheArrowsMoveBetweenCardsAndReturnRunsTheSelectedOne() async throws {
        try await showGrid()
        XCTAssertEqual(model.selected, 0)

        XCTAssertTrue(model.handleSearchKey(right))
        XCTAssertEqual(model.selected, 1)
        XCTAssertTrue(model.handleSearchKey(left))
        XCTAssertEqual(model.selected, 0)
        XCTAssertTrue(model.handleSearchKey(down))
        XCTAssertTrue(model.handleSearchKey(up))

        XCTAssertTrue(model.handleSearchKey(enter))
        XCTAssertEqual(host.dismissals, 1)
    }

    func testReturnAndTheArrowsStayWithAFieldThatIsNotTheSearchField() async throws {
        try await showGrid()

        XCTAssertFalse(model.handleKey(enter))
        XCTAssertFalse(model.handleKey(right))
        XCTAssertFalse(model.handleKey(down))

        XCTAssertEqual(model.selected, 0)
        XCTAssertEqual(host.dismissals, 0)
    }

    func testWhileASearchIsTypedOnTheGridTheSideArrowsStayInTheText() async throws {
        try await showGrid()
        model.query = "a"
        model.landSearch()

        XCTAssertFalse(model.handleSearchKey(left))
        XCTAssertFalse(model.handleSearchKey(right))
        XCTAssertTrue(model.handleSearchKey(down))
    }

    func testInASheetOfRowsTheArrowsMoveByLinesAndReturnPicksTheRow() async throws {
        try script("fruit", toml: "on = ['sheet.open']", "printf 'row=a\\ntitle=Apple\\n\\nrow=b\\ntitle=Banana\\n\\nrow=c\\ntitle=Cherry\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("fruit")
        try await wait("the rows") { self.model.openItems?.shown.count == 3 }

        XCTAssertFalse(model.handleKey(down))
        XCTAssertTrue(model.handleSearchKey(down))
        XCTAssertEqual(model.openItems?.selectedItem?.run, "b")
        XCTAssertTrue(model.handleSearchKey(ActionKey(name: "down", isCommand: true)))
        XCTAssertEqual(model.openItems?.selectedItem?.run, "c")
        XCTAssertTrue(model.handleSearchKey(ActionKey(name: "up", isCommand: true)))
        XCTAssertEqual(model.openItems?.selectedItem?.run, "a")
        XCTAssertFalse(model.handleSearchKey(left))
        XCTAssertFalse(model.handleSearchKey(right))
        XCTAssertFalse(model.handleKey(tab))
        XCTAssertFalse(model.handleKey(history))
        XCTAssertFalse(model.handleKey(settings))
    }

    func testReturnInASheetOfRowsRunsTheSelectedRow() async throws {
        try await openList()

        XCTAssertFalse(model.handleKey(enter))
        XCTAssertTrue(model.handleSearchKey(enter))

        try await wait("the page") { self.titles == ["Detail a"] }
    }

    func testEscPopsAPageOfASheetOfPartsAsItDoesInASheetOfRows() async throws {
        try await openInfo()
        XCTAssertTrue(model.push(FlowSheet(spot: "info", page: "a")))
        try await wait("the page of parts") { self.model.openParts?.parts.first?.title == "Detail" }
        try await wait("the step to settle") { self.model.flowEdges.from == nil }

        XCTAssertTrue(model.handleKey(escape))

        try await wait("the first sheet") { self.model.openParts?.parts.first?.title == "First" }
        XCTAssertNil(model.flow.ahead)
        XCTAssertEqual(model.flow.pages, [FlowSheet(spot: "info")])
        try await wait("the step to settle") { self.model.flowEdges.from == nil }
        XCTAssertTrue(model.handleKey(escape))
        try await wait("the grid") { self.model.openSheetID == nil }
        XCTAssertEqual(host.dismissals, 0)
    }

    func testASheetOfPartsWithNoFocusLeavesReturnTabAndTheSideArrowsAlone() async throws {
        try await openInfo()

        XCTAssertFalse(model.handleKey(enter))
        XCTAssertFalse(model.handleSearchKey(enter))
        XCTAssertFalse(model.handleSearchKey(down))
        XCTAssertFalse(model.handleKey(tab))
        XCTAssertFalse(model.handleKey(left))
        XCTAssertFalse(model.handleKey(settings))
        XCTAssertFalse(model.handleKey(history))
        XCTAssertTrue(model.handleKey(down))
        XCTAssertEqual(model.openSheetID, "info")
    }

    func testTheMenuTakesEachKeyUntilItCloses() async throws {
        try await showGrid()
        try select("weather")
        let chosen = model.selected
        XCTAssertTrue(model.handleKey(actions))
        let menu = try XCTUnwrap(model.menu)

        XCTAssertTrue(model.handleKey(down))
        XCTAssertEqual(model.menu?.selected, 1)
        XCTAssertTrue(model.handleKey(up))
        XCTAssertEqual(model.menu?.selected, 0)
        XCTAssertEqual(model.handleKey(tab), !menu.isSearchable)
        XCTAssertTrue(model.handleKey(settings))
        XCTAssertTrue(model.handleKey(history))
        XCTAssertNotNil(model.menu)
        XCTAssertEqual(model.selected, chosen)
        XCTAssertNil(model.openSheetID)
        XCTAssertTrue(model.handleKey(actions))
        XCTAssertNil(model.menu)

        XCTAssertTrue(model.handleKey(actions))
        XCTAssertTrue(model.handleKey(enter))
        XCTAssertNil(model.menu)
    }

    func testEditSpotsTakesEveryKeyAndEscEndsIt() async throws {
        try await showGrid()
        model.beginEditing()

        XCTAssertTrue(model.handleKey(right))
        XCTAssertEqual(model.selected, 1)
        XCTAssertTrue(model.handleKey(enter))
        XCTAssertTrue(model.handleKey(tab))
        XCTAssertTrue(model.handleKey(actions))
        XCTAssertTrue(model.handleKey(settings))
        XCTAssertTrue(model.handleKey(history))
        XCTAssertNil(model.menu)
        XCTAssertNil(model.openSheetID)
        XCTAssertEqual(host.dismissals, 0)
        XCTAssertTrue(model.isEditing)

        XCTAssertTrue(model.handleKey(ActionKey(name: "right", isShift: true)))
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertFalse(model.isEditing)
    }

    func testEscWhileAKeyIsRecordedStopsTheRecordingAndKeepsTheSheet() async throws {
        try script("draw", toml: "title = 'Draw'\non = ['sheet.open']", "printf 'row=float\\ntitle=Float\\ntype=hotkey\\nshortcut=Record\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("draw")
        let sheet = "draw"
        try await wait("its rows") { self.model.openItems?.shown.map(\.run) == ["float"] }
        XCTAssertTrue(model.handleSearchKey(enter))
        XCTAssertEqual(model.recording, "float")
        XCTAssertEqual(model.hint, "Esc Cancel")

        XCTAssertFalse(model.handleKey(ActionKey(name: "s")))
        XCTAssertFalse(model.handleKey(enter))
        XCTAssertEqual(model.recording, "float")
        XCTAssertTrue(model.handleKey(escape))

        XCTAssertNil(model.recording)
        XCTAssertEqual(model.openSheetID, sheet)
    }

    private var pickData: URL {
        folder.appendingPathComponent("pick", isDirectory: true)
    }

    private var pickCalls: [String] {
        ((try? String(contentsOf: pickData.appendingPathComponent("calls"), encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    private var keyField: SpotPart? {
        model.openParts?.parts.first { $0.id == "key" }
    }

    private func writePick(key: String? = nil) throws {
        try FileManager.default.createDirectory(at: pickData, withIntermediateDirectories: true)
        if let key { try key.write(to: pickData.appendingPathComponent("key"), atomically: true, encoding: .utf8) }
        try script("pick", toml: "title = 'Pick'\non = ['sheet.open']", """
        data='\(pickData.path)'
        [ "$1" = show ] || echo "$*" >> "$data/calls"
        case "$1" in
          key) printf %s "$2" > "$data/key" ;;
          again) rm -f "$data/key" ;;
        esac
        case "$1" in
          show|key|again)
            key=$(cat "$data/key" 2>/dev/null)
            printf 'title=Choose your key\\ngrid=key\\ngrid=keep\\ngrid=again\\n\\nfield=key\\ntype=hotkey\\nvalue=%s\\n' "$key"
            [ -n "$key" ] || printf 'recording=true\\n'
            printf '\\nbutton=keep\\ntitle=Keep\\n\\nbutton=again\\ntitle=Try again\\nshortcut=escape\\n' ;;
        esac
        """)
    }

    private func nextTurn() async {
        await withCheckedContinuation { done in DispatchQueue.main.async { done.resume() } }
    }

    private func openChoice() async throws {
        try FileManager.default.createDirectory(at: pickData, withIntermediateDirectories: true)
        try script("choice", toml: "title = 'Choice'\non = ['sheet.open']", """
        data='\(pickData.path)'
        [ "$1" = show ] || echo "$*" >> "$data/calls"
        [ "$1" = key ] && printf %s "$2" > "$data/key"
        [ "$1" = use ] && printf 'toast=Used\\n'
        case "$1" in
          show|key|record)
            printf 'grid=key\\ngrid=key\\ngrid=use\\ngrid=record\\n\\nfield=key\\ntype=hotkey\\nvalue=%s\\n' "$(cat "$data/key" 2>/dev/null || printf ctrl+space)"
            [ "$1" != record ] || printf 'recording=true\\n'
            printf '\\nbutton=use\\ntitle=Use\\nshortcut=return\\n\\nbutton=record\\ntitle=Record\\nshortcut=escape\\n' ;;
        esac
        """)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("choice")
        try await wait("the key field") { self.keyField?.control == .shortcut("ctrl+space") }
        await nextTurn()
    }

    func testAFrameThatAsksToRecordRecordsItsFieldAndEscBringsTheKeyBack() async throws {
        try await openChoice()
        XCTAssertNil(model.recording)

        XCTAssertTrue(model.handleKey(escape))
        try await wait("the recording") { self.model.recording == "key" }
        XCTAssertTrue(model.handleKey(escape))

        XCTAssertNil(model.recording)
        XCTAssertEqual(keyField?.control, .shortcut("ctrl+space"))
        XCTAssertEqual(pickCalls, ["record"])
    }

    func testAKeyRecordedThroughTheButtonIsSentAndTheFocusGoesToUse() async throws {
        try await openChoice()
        XCTAssertTrue(model.handleKey(escape))
        try await wait("the recording") { self.model.recording == "key" }

        model.record(code: 49, modifiers: .option)

        try await wait("the sent key") { self.pickCalls == ["record", "key option+space"] && self.model.sheets["choice"]?.calls.isEmpty == true }
        XCTAssertEqual(keyField?.control, .shortcut("option+space"))
        XCTAssertEqual(model.openParts?.selectedPart?.id, "use")
    }

    func testSpacePressesTheFocusedButton() async throws {
        try await openChoice()
        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))
        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))
        XCTAssertEqual(model.openParts?.selectedPart?.id, "record")

        XCTAssertTrue(model.handleKey(ActionKey(name: " ")))

        try await wait("the recording") { self.model.recording == "key" }
    }

    private func openPick(key: String? = nil) async throws {
        try writePick(key: key)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("pick")
        try await wait("the key field") { self.keyField != nil }
    }

    func testTheOpenKeyStaysOffWhileASheetWithAKeyFieldShowsAndComesBackWhenItCloses() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }
        XCTAssertFalse(host.entryKeyIsOn)

        model.record(code: 49, modifiers: .option)
        try await wait("the kept key") { self.keyField?.control == .shortcut("option+space") }
        await nextTurn()
        XCTAssertNil(model.recording)
        XCTAssertFalse(host.entryKeyIsOn)

        model.closeSheet(moving: false)
        try await wait("the open key again") { self.host.entryKeyIsOn }
    }

    func testAPressOnAChosenKeyIsTakenAndChangesNothing() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }
        model.record(code: 49, modifiers: .option)
        try await wait("the kept key") { self.keyField?.control == .shortcut("option+space") }
        XCTAssertNil(model.recording)

        XCTAssertTrue(model.takesEveryKey)
        await nextTurn()

        XCTAssertNil(model.recording)
        XCTAssertEqual(keyField?.control, .shortcut("option+space"))
        XCTAssertFalse(pickCalls.contains("key ctrl+space"))
    }

    func testRecordingPutsTheFocusOnTheField() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }

        XCTAssertEqual(model.openParts?.selectedPart?.id, "key")
    }

    func testAPressWhoseFrameAsksToRecordRecordsAgain() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }
        XCTAssertTrue(model.handleKey(escape))
        XCTAssertNil(model.recording)
        await nextTurn()

        XCTAssertTrue(model.handleKey(escape))

        try await wait("the press of again") { self.pickCalls.contains("again") }
        try await wait("the recording again") { self.model.recording == "key" }
    }

    func testAPressWithNoKeyFieldIsLeftToThePanel() async throws {
        try writePick()
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        await nextTurn()

        XCTAssertNil(model.openSheetID)
        XCTAssertFalse(model.takesEveryKey)
    }

    func testEscThatStopsARecordingGivesTheFocusToThePartAfterAFieldWithAKey() async throws {
        try await openChoice()
        XCTAssertTrue(model.handleKey(escape))
        try await wait("the recording") { self.model.recording == "key" }

        XCTAssertTrue(model.handleKey(escape))

        XCTAssertNil(model.recording)
        XCTAssertEqual(model.openParts?.selectedPart?.id, "use")
    }

    func testAnAnswerWithNoPartsDoesNotRecordAgain() async throws {
        try await openChoice()
        XCTAssertTrue(model.handleKey(escape))
        try await wait("the recording") { self.model.recording == "key" }
        XCTAssertTrue(model.handleKey(escape))

        XCTAssertTrue(model.handleKey(enter))

        try await wait("the toast") { self.host.confirms.contains("Used") && self.model.sheets["choice"]?.calls.isEmpty == true }
        XCTAssertNil(model.recording)
    }

    func testTheOpenKeyTurnsOffAgainWhenThePanelShowsOverAKeyField() async throws {
        try await openPick(key: "option+space")
        await nextTurn()
        model.panelWillHide()
        try await wait("the open key") { self.host.entryKeyIsOn }

        model.panelWillShow()

        try await wait("the open key off") { !self.host.entryKeyIsOn }
    }

    func testTheOpenKeyComesBackWhenThePanelHidesOverAKeyField() async throws {
        try await openPick(key: "option+space")
        await nextTurn()
        XCTAssertFalse(host.entryKeyIsOn)

        model.panelWillHide()

        try await wait("the open key again") { self.host.entryKeyIsOn }
    }

    func testAfterAKeyTheFocusMovesToTheNextLineAndReturnPressesWhatTheArrowsChose() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }

        model.record(code: 49, modifiers: .option)
        try await wait("the kept key") { self.keyField?.control == .shortcut("option+space") }
        XCTAssertEqual(model.openParts?.selectedPart?.id, "keep")
        XCTAssertTrue(model.handleKey(ActionKey(name: "down")))
        XCTAssertEqual(model.openParts?.selectedPart?.id, "again")
        XCTAssertTrue(model.handleKey(enter))

        try await wait("the press of again") { (try? String(contentsOf: self.pickData.appendingPathComponent("calls"), encoding: .utf8))?.contains("again") == true }
    }

    func testAFieldThatAsksToRecordRecordsAsSoonAsItsSheetShows() async throws {
        try await openPick()

        try await wait("the recording") { self.model.recording == "key" }
    }

    func testAFieldThatAsksToRecordRecordsWhenItsPartsComeAfterItsSheet() async throws {
        try writePick()
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        model.pushFirst("pick", moving: false)
        XCTAssertEqual(model.openSheetID, "pick")
        XCTAssertNil(keyField)

        try await wait("the recording") { self.model.recording == "key" }
    }

    func testAFieldThatAsksToRecordDoesNotRecordWhileThePanelHides() async throws {
        try writePick()
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        await nextTurn()
        model.pushFirst("pick", moving: false)

        model.panelWillHide()

        try await wait("the key field") { self.keyField != nil }
        await nextTurn()
        XCTAssertNil(model.recording)
    }

    func testAFieldWithAKeyDoesNotRecordUntilPressed() async throws {
        try await openPick(key: "option+space")

        XCTAssertEqual(keyField?.value, "option+space")
        await nextTurn()
        XCTAssertNil(model.recording)
        XCTAssertEqual(model.openParts?.selectedPart?.id, "keep")
        XCTAssertTrue(model.handleKey(ActionKey(name: "up")))
        XCTAssertTrue(model.handleKey(enter))
        XCTAssertEqual(model.recording, "key")
    }

    func testHeldKeysShowOnlyWhileRecording() async throws {
        model.hold([.option])
        XCTAssertEqual(model.keys.held, [])

        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }
        model.hold([.option])
        XCTAssertEqual(model.keys.held, [.option])

        model.stopRecording()
        XCTAssertEqual(model.keys.held, [])
    }

    func testEscWhileAFieldRecordsStopsOnlyTheRecording() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }
        XCTAssertEqual(model.hint, "Esc Cancel")

        XCTAssertTrue(model.handleKey(escape))
        await nextTurn()

        XCTAssertNil(model.recording)
        XCTAssertEqual(model.openSheetID, "pick")
        XCTAssertEqual(model.openParts?.selectedPart?.id, "key")
        XCTAssertTrue(pickCalls.isEmpty)
        XCTAssertEqual(host.dismissals, 0)
    }

    func testReturnBeforeAnyKeyAsksForAModifierAndSavesNothing() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }

        model.record(code: 36, modifiers: [])

        XCTAssertEqual(model.keys.status, "Hold ⌃, ⌥ or ⌘ with a key.")
        XCTAssertEqual(model.recording, "key")
        XCTAssertEqual(keyField?.value, "")
        XCTAssertFalse(pickCalls.contains { $0.hasPrefix("key") })
    }

    func testAFieldThatRecordsAFreeKeySaysItIsFree() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }

        model.record(code: 49, modifiers: .option)

        XCTAssertEqual(model.keys.status, "⌥Space is free.")
        try await wait("the key call") { self.pickCalls.contains("key option+space") }
    }

    func testAFieldKeepsNoKeyOfTheAppsAndRecordsOn() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }

        model.record(code: 8, modifiers: .command)

        XCTAssertEqual(model.keys.status, "`⌘C` belongs to apps. Hold `⌥` or `⌃` with a key.")
        XCTAssertEqual(model.recording, "key")
        XCTAssertEqual(keyField?.value, "")
    }

    func testAKeyWithNoNameBesideAHeldModifierNamesTheKeysThatWork() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }

        model.record(code: 122, modifiers: .option)

        XCTAssertEqual(model.keys.status, "Openspot cannot use that key. Try a letter, a digit, a sign or an arrow.")
        XCTAssertEqual(model.recording, "key")
        XCTAssertEqual(keyField?.value, "")
    }

    func testAPressedKeyIsDownUntilItsRelease() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }
        XCTAssertFalse(model.keys.isKeyDown)

        model.record(code: 49, modifiers: [])
        XCTAssertTrue(model.keys.isKeyDown)
        XCTAssertEqual(model.keys.pressed, "Space")
        model.releaseKey()

        XCTAssertFalse(model.keys.isKeyDown)
        XCTAssertEqual(model.keys.pressed, "Space")
        XCTAssertEqual(model.recording, "key")
    }

    func testShiftAndAKeySaysWhatItTypesInEveryAppAndKeepsRecording() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }

        model.record(code: 13, modifiers: .shift)
        XCTAssertEqual(model.keys.pressed, "W")
        XCTAssertEqual(model.keys.status, "`⇧W` types a capital W in every app. Hold `⌃`, `⌥` or `⌘` with it.")
        model.record(code: 18, modifiers: .shift)
        XCTAssertEqual(model.keys.status, "`⇧1` types in every app. Hold `⌃`, `⌥` or `⌘` with it.")

        XCTAssertEqual(model.recording, "key")
    }

    func testAPressThatMakesNoShortcutShowsItsKeyUntilAKeyIsRecorded() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }
        XCTAssertNil(model.keys.pressed)

        model.record(code: 1, modifiers: [])
        XCTAssertEqual(model.keys.pressed, "S")
        XCTAssertEqual(model.keys.status, "Hold ⌃, ⌥ or ⌘ with a key.")
        model.record(code: 8, modifiers: .command)
        XCTAssertEqual(model.keys.pressed, "C")
        model.record(code: 36, modifiers: [])
        XCTAssertEqual(model.keys.pressed, "⏎")
        model.record(code: 49, modifiers: .option)

        XCTAssertNil(model.keys.pressed)
        XCTAssertEqual(keyField?.value, "option+space")
    }

    func testANewRecordingStartsWithNoPressedKey() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }
        model.record(code: 1, modifiers: [])
        model.stopRecording()

        model.toggleRecording(id: "key")

        XCTAssertEqual(model.recording, "key")
        XCTAssertNil(model.keys.pressed)
    }

    func testAnAppThatOpensWhileKeysAreHeldIsNamedAndTheRecordingGoesOn() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }
        model.hold([.command, .shift])

        model.appCameToFront("Raycast")

        XCTAssertEqual(model.keys.status, "⇧⌘ and a key opened Raycast. Change it there, or press another key.")
        XCTAssertEqual(model.keys.held, [])
        XCTAssertEqual(model.recording, "key")
    }

    func testAnAppThatOpensWithNoKeyHeldChangesNothing() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }

        model.appCameToFront("Raycast")

        XCTAssertNil(model.keys.status)
        XCTAssertEqual(model.recording, "key")
    }

    func testAnAppThatOpensWhileARowRecordsChangesNothing() async throws {
        try await openKeyRow()
        model.toggleRecording(id: "float")
        model.hold([.command])

        model.appCameToFront("Raycast")

        XCTAssertNil(model.keys.status)
        XCTAssertEqual(model.keys.held, [.command])
    }

    func testAFieldWhoseNewFrameAsksToRecordRecordsAgain() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }
        model.record(code: 49, modifiers: .option)
        XCTAssertNil(model.recording)
        try await wait("the kept key") { self.pickCalls.contains("key option+space") && self.model.sheets["pick"]?.calls.isEmpty == true }
        XCTAssertEqual(keyField?.value, "option+space")
        await nextTurn()
        XCTAssertNil(model.recording)

        XCTAssertTrue(model.handleKey(escape))

        try await wait("the cleared key") { self.keyField?.value == "" }
        XCTAssertTrue(pickCalls.contains("again"))
        try await wait("the recording again") { self.model.recording == "key" }
    }

    private func openKeyRow() async throws {
        try script("draw", toml: "title = 'Draw'\non = ['sheet.open']", "printf 'row=float\\ntitle=Float\\ntype=hotkey\\nshortcut=Record\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("draw")
        try await wait("its rows") { self.model.openItems?.shown.map(\.run) == ["float"] }
    }

    func testRecordingAKeyThatMacOSKeepsSaysWhatItDoes() async throws {
        let folder = self.folder.appendingPathComponent("Library/Preferences", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let entry: [String: Any] = ["enabled": true, "value": ["parameters": [32, 49, 1048576], "type": "standard"] as [String: Any]]
        let data = try PropertyListSerialization.data(fromPropertyList: ["AppleSymbolicHotKeys": ["64": entry]], format: .binary, options: 0)
        try data.write(to: folder.appendingPathComponent("com.apple.symbolichotkeys.plist"))
        try await openKeyRow()

        model.toggleRecording(id: "float")
        try await wait("the taken keys") { !self.model.keys.taken.isEmpty }
        model.record(code: 49, modifiers: .command)

        XCTAssertEqual(host.notes, ["⌘Space opens Spotlight."])
    }

    func testAModifierAddedWhileTheKeyIsHeldMakesTheShortcut() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }
        model.record(code: 13, modifiers: .shift)
        XCTAssertNotNil(model.keys.status)

        model.hold([.shift, .option])

        XCTAssertNil(model.recording)
        try await wait("the kept key") { self.keyField?.value == Shortcut(code: 13, modifiers: [.shift, .option])?.text }
    }

    func testNewModifiersAfterARefusedKeyClearItsWords() async throws {
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }
        model.record(code: 13, modifiers: .shift)
        model.releaseKey()
        model.hold([])

        model.hold(.command)

        XCTAssertNil(model.keys.status)
        XCTAssertEqual(model.recording, "key")
    }

    func testAKeyThatMacOSTakesForInputSourcesSaysHowToFreeIt() async throws {
        let folder = self.folder.appendingPathComponent("Library/Preferences", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let entry: [String: Any] = ["enabled": true, "value": ["parameters": [32, 49, 262144], "type": "standard"] as [String: Any]]
        let data = try PropertyListSerialization.data(fromPropertyList: ["AppleSymbolicHotKeys": ["60": entry]], format: .binary, options: 0)
        try data.write(to: folder.appendingPathComponent("com.apple.symbolichotkeys.plist"))
        try await openPick()
        try await wait("the recording") { self.model.recording == "key" }
        model.toggleRecording(id: "key")
        model.toggleRecording(id: "key")
        try await wait("the taken keys") { !self.model.keys.taken.isEmpty }

        model.hold(.control)
        model.hold([])
        model.inputSourceChanged()

        XCTAssertEqual(model.keys.status, "`⌃Space` switches the input source. Free it in Keyboard Shortcuts.")
        XCTAssertEqual(model.recording, "key")
    }

    func testAKeyOfAnotherSpotSaysItOpensThatSpot() async throws {
        try script("shelf", toml: "title = 'Shelf'", "true")
        _ = try model.files.config.change { $0.assign(.key(try XCTUnwrap(Shortcut(text: "ctrl+option+s"))), to: "shelf", act: .open) }
        try await openKeyRow()

        model.toggleRecording(id: "float")
        try await wait("the taken keys") { !self.model.keys.taken.isEmpty }
        model.record(code: 1, modifiers: [.control, .option])

        XCTAssertEqual(host.notes, ["⌃⌥S opens Shelf."])
    }

    func testCommandYOpensTheHistoryOfASpotWhoseReturnRunsItsCommand() async throws {
        try script("dictate", toml: "title = 'Dictate'\non = ['sheet.open']\n[commands.dictate]\ntitle = 'Dictate'", "printf 'row=a\\ntitle=Said\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.query = "dictate"
        model.landSearch()
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "dictate" })

        XCTAssertTrue(model.handleKey(history))

        try await wait("its rows") { self.model.openSheetID == "dictate" && self.titles == ["Said"] }
    }
}
