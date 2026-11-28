import XCTest
@testable import OpenspotCore

final class PanelCallTests: PanelCase {
    private var api: CommandAPI!

    override func setUp() async throws {
        try await super.setUp()
        api = CommandAPI(mac: Mac(), places: model.files, app: ModelApp(model: model), runs: model.runs)
    }

    private func spot(_ name: String, _ body: String) throws {
        try "#!/bin/sh\n\(body)\n".writeScript(to: spots.spotFile(name), toml: "title = '\(name.capitalized)'")
    }

    private func call(_ words: String...) async throws -> CommandAnswer {
        let work = try XCTUnwrap(api.work(for: CommandRequest(arguments: ["panel"] + words, folder: folder.path), input: { "" }))
        return await work()
    }

    private func lines(_ answer: CommandAnswer) -> Set<String> {
        Set(answer.output.split(separator: "\n").map(String.init))
    }

    func testOpenShowsThePanelAndCloseHidesIt() async throws {
        let opened = try await call("open")
        XCTAssertEqual(opened.code, 0)
        XCTAssertEqual(host.shows, 1)

        model.isShown = true
        let closed = try await call("close")
        XCTAssertEqual(closed.code, 0)
        XCTAssertEqual(host.dismissals, 1)
    }

    func testStateTellsWhatThePanelShows() async throws {
        try spot("rows", "printf 'item=a\\ntitle=Alpha\\n\\nitem=b\\ntitle=Beta\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("rows")
        try await wait("the open rows") { self.model.openSheetID == "rows" && self.model.openItems?.shown.count == 2 }

        let state = lines(try await call("state"))

        XCTAssertTrue(state.isSuperset(of: ["open=true", "sheet=rows", "selected=a", "menu=false", "chips=0"]), "\(state)")
    }

    func testTypePutsTheWordsInTheFieldOneCharacterAtATime() async throws {
        try spot("rows", "printf 'item=a\\ntitle=Alpha\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        let typed = try await call("type", "ro", "--pace", "0")
        XCTAssertEqual(typed.code, 0)
        XCTAssertEqual(model.searchText, "ro")

        _ = try await call("type", "ws", "--pace", "0")
        XCTAssertEqual(model.searchText, "rows")

        _ = try await call("type", "x", "--clear", "--pace", "0")
        XCTAssertEqual(model.searchText, "x")
    }

    func testKeyPressesAKeyAsTheKeyboardDoes() async throws {
        try spot("rows", "printf 'item=a\\ntitle=Alpha\\n'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        _ = try await call("type", "rows", "--pace", "0")
        try await wait("the search") { self.model.selectedEntry?.id == "rows" }

        let pressed = try await call("key", "return")

        XCTAssertEqual(pressed.code, 0)
        try await wait("the open sheet") { self.model.openSheetID == "rows" }
    }

    func testAKeyThatNoRowTakesFailsWithItsName() async throws {
        let answer = try await call("key", "cmd+shift+q")

        XCTAssertEqual(answer.code, 1)
        XCTAssertTrue(answer.errors.contains("cmd+shift+q"), answer.errors)
    }

    func testPressPressesAPartOfTheOpenSheet() async throws {
        let calls = folder.appendingPathComponent("calls")
        try script("frame", toml: "[on]\n\"sheet.open\" = true", """
        case "$1" in
          go) echo go >> '\(calls.path)' ;;
          *) printf 'frame=\\nclass=gap-part\\n\\ntext=words\\ntitle=Hello\\n\\nbutton=go\\ntitle=Go\\n' ;;
        esac
        """)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.pushFirst("frame", moving: true)
        try await wait("the button") { self.model.openParts?.parts.contains { $0.id == "go" } == true }

        let pressed = try await call("press", "go")
        let missing = try await call("press", "nope")

        XCTAssertEqual(pressed.code, 0)
        try await wait("the press") { (try? String(contentsOf: calls, encoding: .utf8)) == "go\n" }
        XCTAssertEqual(missing.code, 1)
        XCTAssertTrue(missing.errors.contains("nope"), missing.errors)
    }

    func testWaitEndsOnceEachFactShowsAndFailsWithTheFactItMissed() async throws {
        model.isShown = true

        let met = try await call("wait", "open=true", "menu=false")
        let missed = try await call("wait", "sheet=nope", "--within", "1")

        XCTAssertEqual(met.code, 0)
        XCTAssertEqual(missed.code, 1)
        XCTAssertTrue(missed.errors.contains("sheet=nope"), missed.errors)
    }
}
