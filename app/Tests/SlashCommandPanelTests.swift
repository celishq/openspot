import XCTest
@testable import OpenspotCore

final class SlashCommandPanelTests: PanelCase {
    private var input: URL {
        folder.appendingPathComponent("input")
    }

    private func writeNotes() throws {
        try script("notes", header: "title=Notes\non=sheet.open\n\nbutton=add\ntitle=Add note\nplaceholder=What to add\n\nbutton=find\ntitle=Find note\nclose=false\nplaceholder=What to find", """
        stdin=$(cat)
        printf '%s\\n%s\\n' "$*" "$stdin" >> '\(input.path)'
        search=$(printf '%s\\n' "$stdin" | sed -n 's/^search=//p' | head -n 1)
        name=$(printf '%s\\n' "$stdin" | sed -n 's/^name=//p' | head -n 1)
        case "$1" in
          add)
            if [ "$search" = ask ]; then printf 'title=Add a note\\n\\nfield=name\\ntitle=Name\\n'; else printf 'toast=Saved %s%s\\n' "$search" "$name"; fi ;;
          find) printf 'text=Found %s\\n' "$search" ;;
          *) printf 'row=a\\ntitle=A\\n' ;;
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
        model.panelWillShow(holding: [])
    }

    private var sent: String {
        (try? String(contentsOf: input, encoding: .utf8)) ?? ""
    }

    func testASlashWordListsTheMatchingCommandsWithTheFirstHighlighted() async throws {
        try writeNotes()
        try script("trash", header: "title=Trash", "printf 'toast=Emptied\\n'")
        await open()

        type("/note buy milk")

        XCTAssertEqual(model.slash, SlashCommand("/note buy milk"))
        XCTAssertEqual(model.visible.map(\.state.title), ["Add note", "Find note"])
        XCTAssertEqual(model.selected, 0)
        XCTAssertEqual(model.hint, "⏎ Add note \"buy milk\"")
        XCTAssertTrue(model.handleSearchKey(ActionKey(name: "down")))
        XCTAssertEqual(model.hint, "⏎ Find note \"buy milk\"")
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
        try script("ping", header: "title=Ping\nmode=stay\n\nbutton=ping\ntitle=Ping\nplaceholder=What to ping\n\nbutton=pong\ntitle=Pong\nplaceholder=What to pong", """
        . "$OPENSPOT_SH"
        main() { case "$1" in ping) openspot_kv toast "Ping $(value search)" ;; esac; }
        openspot_serve main "$@"
        """)
        await open()

        type("/ping hi")
        model.selected = try XCTUnwrap(model.visible.firstIndex { $0.id == "ping\nping" })
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
        try script("solo", header: "title=Solo\n\nbutton=solo\ntitle=Solo\nplaceholder=What", "printf 'toast=Ran\\n'")
        await open()

        type("/solo")
        XCTAssertEqual(model.hint, "⏎ Solo")
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
        try script("windows", header: "title=Windows\n\nbutton=full\ntitle=Full screen", "printf 'toast=Full\\n'")
        try script("trash", header: "title=Trash", "printf 'toast=Emptied\\n'")
        try script("say", header: "title=Say\nplaceholder=What to say", "printf 'toast=Said\\n'")
        await open()

        type("/")

        XCTAssertEqual(model.slash, SlashCommand("/"))
        XCTAssertEqual(Set(model.visible.map(\.state.title)), ["Add note", "Find note", "Say"])
        XCTAssertEqual(model.selected, 0)
    }

    func testASpotWithAPlaceholderRunsOpenWithTheText() async throws {
        try script("say", header: "title=Say\nplaceholder=What to say", """
        stdin=$(cat)
        printf '%s\\n%s\\n' "$*" "$stdin" >> '\(input.path)'
        printf 'toast=Said\\n'
        """)
        await open()

        type("/say hi")
        model.runSelected()

        try await wait("the toast") { self.host.confirms == ["Said"] }
        XCTAssertTrue(sent.contains("open\nsearch=hi"), sent)
    }

    func testASlashAfterTheTextListsEveryCommandAndReturnSendsTheText() async throws {
        try writeNotes()
        await open()

        type("buy milk /")
        XCTAssertEqual(model.visible.map(\.state.title), ["Add note", "Find note"])
        model.runSelected()

        try await wait("the toast") { self.host.confirms == ["Saved buy milk"] }
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
        XCTAssertTrue(sent.contains("add\nsearch=buy milk"), sent)
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

    func testACommandThatStaysOpensItsSheetAtItsFirstFrame() async throws {
        try writeNotes()
        await open()

        type("/find milk")
        model.runSelected()

        try await wait("the sheet") { self.model.openSheetID == "notes" }
        XCTAssertTrue(sent.contains("find\nsearch=milk"), sent)
        XCTAssertEqual(host.dismissals, 0)
        XCTAssertNil(model.form)
    }

    func testASheetSpotGetsTheTextOnTheStdinOfItsRead() async throws {
        try script("translate", header: "title=Translate\non=sheet.open\nplaceholder=Text to translate", """
        stdin=$(cat)
        printf '%s\\n%s\\n' "$*" "$stdin" >> '\(input.path)'
        printf 'field=input\\n'
        """)
        await open()

        type("/translate hello world")
        model.runSelected()

        try await wait("the sheet") { self.model.openSheetID == "translate" }
        try await wait("the text in the read") { self.sent.contains("search=hello world") }
        XCTAssertTrue(sent.contains("read\n"), sent)
    }
}
