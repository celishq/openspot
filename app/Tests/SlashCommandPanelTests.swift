import XCTest
@testable import OpenspotCore

final class SlashCommandPanelTests: PanelCase {
    override func setUp() async throws {
        try await super.setUp()
        takeCalls()
    }

    private var input: URL {
        folder.appendingPathComponent("input")
    }

    private func writeNotes() throws {
        try script("notes", toml: "title = 'Notes'\n[actions.add]\ninputs.text = { type = 'text', required = true }\n[actions.find]\ninputs.text = { type = 'text', required = true }\n[on]\n\"panel.open\" = true\n\"sheet.open\" = true", """
        stdin=$(cat)
        printf '%s\\n%s\\n' "$*" "$stdin" >> '\(input.path)'
        text=$(printf '%s\\n' "$stdin" | sed -n 's/^input\\.text=//p' | head -n 1)
        name=$(printf '%s\\n' "$stdin" | sed -n 's/^input\\.name=//p' | head -n 1)
        case "$1" in
          add)
            if [ "$text" = ask ] && [ -z "$name" ]; then printf 'frame=\\ntype=form\\ntitle=Add a note\\n\\nfield=text\\ntitle=Text\\nvalue=ask\\n\\nfield=name\\ntitle=Name\\n'
            elif [ "$text" = page ]; then printf 'frame=\\ntitle=Add a note\\n\\nfield=name\\ntitle=Name\\n'
            elif [ -n "$name" ]; then \(TestSpot.toast) "Saved $name"; else \(TestSpot.toast) "Saved $text"; fi ;;
          find) printf 'text=Found %s\\n' "$text" ;;
          *) printf 'text=a\\ntitle=A\\n\\nbutton=add\\ntitle=Add note\\nscope=spot\\nplaceholder=What to add\\n\\nbutton=find\\ntitle=Find note\\nscope=spot\\nplaceholder=What to find\\n' ;;
        esac
        """)
    }

    private func type(_ query: String) {
        model.query = query
        model.landSearch()
    }

    private func open() async {
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        if model.entry("notes") != nil {
            try? await wait("the buttons of notes") { self.model.entry("notes")?.spot.actions.isEmpty == false }
        }
    }

    private var sent: String {
        (try? String(contentsOf: input, encoding: .utf8)) ?? ""
    }

    func testASlashWordListsTheMatchingCommandsWithTheFirstHighlighted() async throws {
        try writeNotes()
        try script("trash", toml: "title = 'Trash'", "\(TestSpot.toast) Emptied")
        await open()

        type("/note buy milk")

        XCTAssertEqual(model.slash, SlashCommand("/note buy milk"))
        XCTAssertEqual(model.visible.map(\.state.title), ["Add note", "Find note"])
        XCTAssertEqual(model.selected, 0)
        XCTAssertEqual(model.hint, "⏎ Add note \"buy milk\"")
        XCTAssertTrue(model.handleSearchKey(ActionKey(name: "down")))
        XCTAssertEqual(model.hint, "⏎ Find note \"buy milk\"")
    }

    func testASpotThatThePersonKeepsOutOfSearchIsNotFoundAndListsNoCommand() async throws {
        try writeNotes()
        try script("trash", toml: "title = 'Trash'", "\(TestSpot.toast) Emptied")
        _ = try model.files.config.change { $0.arrangement.arrange(["notes"]) }
        try String(contentsOf: model.files.config.url, encoding: .utf8).appending("search = false\n").write(to: model.files.config.url, atomically: true, encoding: .utf8)
        await open()

        type("notes")
        XCTAssertFalse(model.visible.contains { $0.spot.id == "notes" })
        type("/note")
        XCTAssertEqual(model.visible.map(\.state.title), [])
        type("trash")
        XCTAssertEqual(model.visible.first?.id, "trash")
    }

    func testTheHintOfTheHighlightedCommandShowsUntilTextFollows() async throws {
        try writeNotes()
        await open()

        type("/add")
        XCTAssertEqual(model.slashPlaceholder, "What to add")

        type("/add milk")
        XCTAssertNil(model.slashPlaceholder)

        type("/note")
        XCTAssertEqual(model.slashPlaceholder, "What to add")
        XCTAssertTrue(model.handleSearchKey(ActionKey(name: "down")))
        XCTAssertEqual(model.slashPlaceholder, "What to find")
    }

    func testEachRowSaysWhatReturnDoesWithTheText() async throws {
        try writeNotes()
        await open()

        type("/note")
        XCTAssertEqual(model.visible.map(\.state.subtitle), ["What to add", "What to find"])

        type("/note milk")
        XCTAssertEqual(model.visible.map(\.state.subtitle), ["With \"milk\"", "With \"milk\""])
    }

    func testAStayingSpotAnswersASlashCommand() async throws {
        try script("ping", toml: "title = 'Ping'\nstay = true\n[on]\ncommand = ['ping', 'pong']", """
        . "$OPENSPOT_SH"
        main() { case "$1 $(value name)" in 'command ping') \(TestSpot.toast) "Ping $(value text)" ;; esac; }
        openspot_serve main "$@"
        """)
        await open()

        type("/ping hi")
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.state.title == "ping" })
        model.runSelected()

        try await wait("the toast") { self.host.confirms == ["Ping hi"] }
        try await wait("the close") { self.host.dismissals == 1 }
    }

    func testAClickOnACommandRunsItWithTheText() async throws {
        try writeNotes()
        await open()

        type("/add buy milk")
        model.tap(try XCTUnwrap(model.visible.first).id)

        try await wait("the toast") { self.host.confirms == ["Saved buy milk"] }
    }

    func testWithNoTextReturnRunsTheCommandOfItsRow() async throws {
        try script("solo", toml: "title = 'Solo'\n[on]\ncommand = ['solo']", "\(TestSpot.toast) Ran")
        await open()

        type("/solo")
        XCTAssertEqual(model.hint, "⏎ solo")
        model.runSelected()

        try await wait("the command") { self.host.confirms == ["Ran"] }
    }

    func testTheLeadKeepsTheSpacesTypedBeforeTheCommand() async throws {
        try writeNotes()
        await open()

        type("  /add x")

        XCTAssertEqual(model.slash?.lead, "  ")
    }

    func testALoneSlashListsEveryCommandThatTakesText() async throws {
        try writeNotes()
        try script("windows", toml: "title = 'Windows'\n[actions.full]\ntitle = 'Full screen'", "\(TestSpot.toast) Full")
        try script("trash", toml: "title = 'Trash'", "\(TestSpot.toast) Emptied")
        try script("say", toml: "title = 'Say'\n[on]\ncommand = ['say']", "\(TestSpot.toast) Said")
        await open()

        type("/")

        XCTAssertEqual(model.slash, SlashCommand("/"))
        XCTAssertEqual(Set(model.visible.map(\.state.title)), ["Add note", "Find note", "say"])
        XCTAssertEqual(model.selected, 0)
    }

    func testACommandWordCallsCommandWithItsNameAndTheText() async throws {
        try script("say", toml: "title = 'Say'\n[on]\ncommand = ['say']", """
        stdin=$(cat)
        printf '%s\\n%s\\n' "$*" "$stdin" >> '\(input.path)'
        \(TestSpot.toast) Said
        """)
        await open()

        type("/say hi")
        model.runSelected()

        try await wait("the toast") { self.host.confirms == ["Said"] }
        XCTAssertTrue(sent.hasPrefix("command\ninput.name=say\ninput.text=hi\n"), sent)
    }

    func testASlashAfterTheTextListsEveryCommandAndReturnSendsTheText() async throws {
        try writeNotes()
        await open()

        type("buy milk /")
        XCTAssertEqual(model.visible.map(\.state.title), ["Add note", "Find note"])
        model.runSelected()

        try await wait("the toast") { self.host.confirms == ["Saved buy milk"] }
    }

    func testTheWordsAfterAButtonFillItsFirstInputAndItsDrawnFormAsksForTheRest() async throws {
        try script("jot", toml: "title = 'Jot'\n[actions.new]\ninputs.text = { type = 'text', required = true }\ninputs.title = { type = 'text', required = true }\n[on]\n\"panel.open\" = true\n\"sheet.open\" = true", """
        . "$OPENSPOT_SH"
        case "$1" in
          new) \(TestSpot.toast) "Jotted $(value text)" ;;
          *) printf 'text=a\\ntitle=A\\n\\nbutton=new\\ntitle=New jot\\nscope=spot\\nplaceholder=What to jot\\n' ;;
        esac
        """)
        await open()
        try await wait("the button of the read") { self.model.entry("jot")?.spot.actions.isEmpty == false }

        type("/jot milk")
        XCTAssertEqual(model.visible.map(\.state.title), ["New jot"])
        model.runSelected()

        try await wait("the form") { self.model.form?.draft.values["text"] == "milk" }
    }

    func testAWordThatNamesNoCommandStaysText() async throws {
        try writeNotes()
        await open()

        type("/Users")

        XCTAssertNil(model.slash)
        XCTAssertFalse(model.visible.contains { $0.state.title == "Add note" })
    }

    func testReturnRunsTheCommandWithTheTextOnStdinAndClosesThePanel() async throws {
        try writeNotes()
        await open()

        type("buy milk /add")
        model.runSelected()

        try await wait("the toast") { self.host.confirms == ["Saved buy milk"] }
        XCTAssertTrue(sent.contains("add\ninput.text=buy milk"), sent)
        try await wait("the close") { self.host.dismissals == 1 }
        XCTAssertNil(model.openSheetID)
    }

    func testAFirstFrameWithFieldsOpensTheFormAndItsValuesGoToTheSameCall() async throws {
        try writeNotes()
        await open()

        type("/add ask")
        model.runSelected()
        try await wait("the form") { self.model.form != nil }
        try await wait("the sheet") { self.model.openSheetID == "notes" }
        XCTAssertEqual(host.dismissals, 0)
        model.setFormValue("bread", for: "name")
        model.submitForm()
        try await wait("the toast") { self.host.confirms == ["Saved bread"] }
        XCTAssertTrue(sent.contains("name=bread"), sent)
    }

    func testAFirstFrameWithFieldsAndNoTypeFormOpensTheSheet() async throws {
        try writeNotes()
        await open()

        type("/add page")
        model.runSelected()

        try await wait("the sheet") { self.model.openSheetID == "notes" }
        XCTAssertNil(model.form)
    }

    func testAFirstFrameWithSomethingToShowOpensTheSheet() async throws {
        try writeNotes()
        await open()

        type("/find milk")
        model.runSelected()

        try await wait("the sheet") { self.model.openSheetID == "notes" }
        XCTAssertTrue(sent.contains("find\ninput.text=milk"), sent)
        XCTAssertEqual(host.dismissals, 0)
        XCTAssertNil(model.form)
    }

    func testACommandThatAnswersWithAViewOpensTheSheetWithIt() async throws {
        try script("translate", toml: "title = 'Translate'\n[on]\ncommand = ['translate']", """
        stdin=$(cat)
        printf '%s\\n%s\\n' "$*" "$stdin" >> '\(input.path)'
        printf 'field=input\\n'
        """)
        await open()

        type("/translate hello world")
        model.runSelected()

        try await wait("the sheet") { self.model.openSheetID == "translate" }
        XCTAssertTrue(sent.hasPrefix("command\ninput.name=translate\ninput.text=hello world\n"), sent)
    }
}
