import XCTest
@testable import OpenspotCore

final class SlashCommandPanelTests: PanelCase {
    private var input: URL {
        folder.appendingPathComponent("input")
    }

    private func writeNotes() throws {
        try script("notes", header: "title=Notes\non=sheet.open\n\nbutton=add\ntitle=Add note\n\nbutton=find\ntitle=Find note\nclose=false", """
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
        XCTAssertEqual(model.visible.map(\.state.title), ["Notes", "Add note", "Find note"])
        XCTAssertEqual(model.selected, 0)
        XCTAssertEqual(model.hint, "⏎ Notes \"buy milk\"")
        XCTAssertTrue(model.handleSearchKey(ActionKey(name: "down")))
        XCTAssertEqual(model.hint, "⏎ Add note \"buy milk\"")
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
        XCTAssertTrue(sent.contains("add\nname=bread"), sent)
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
        try script("translate", header: "title=Translate\non=sheet.open", """
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
