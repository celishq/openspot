import XCTest
@testable import OpenspotCore

@MainActor
final class WireTests: SpotRunsCase {
    private static let view = "frame=\\nclass=gap-part\\n\\nfield=search\\nvalue=\\n\\nfield=title\\nvalue=Groceries\\n\\nbutton=go\\ntitle=Go\\n\\nitems=list\\n\\nitem=a\\nparent=list\\ntitle=A\\nmeeting=42\\n"

    private func spot(_ on: String, toml: String = "") throws -> SpotRun {
        try script(toml: "pages = ['photo']\n[settings]\ncity = 'text'\n\(toml)\n[on]\n\(on)", """
        in=$(cat)
        printf 'args=%s\\n%s\\n--\\n' "$*" "$in" >> '\(path("calls"))'
        case "$1" in show|every|sheet.text) printf '\(Self.view)' ;; esac
        """)
        runs.take(settings: [SpotSetting(spot: "script", key: "city", value: "Paris")])
        return try sheet()
    }

    private var calls: [String] {
        let text = (try? String(contentsOfFile: path("calls"), encoding: .utf8)) ?? ""
        return text.components(separatedBy: "\n--\n").dropLast()
    }

    private func sent(_ handler: String, by sheet: SpotRun, _ act: () async throws -> Void) async throws -> String {
        let count = calls.count
        try await act()
        let found = { self.calls.dropFirst(count).first { $0.hasPrefix("args=\(handler)\n") || $0 == "args=\(handler)" } }
        try await wait("the call of \(handler)") { found() != nil && sheet.calls.isEmpty }
        return try XCTUnwrap(found())
    }

    private func opened(_ sheet: SpotRun) async throws {
        sheet.open {}
        try await wait("the sheet") { sheet.panel != nil && sheet.list.all.count == 1 && sheet.calls.isEmpty }
    }

    func testTheShowsOfASheetAndItsPartsSendTheirHandlerAndInputs() async throws {
        let sheet = try spot("\"sheet.open\" = true")
        try await opened(sheet)
        XCTAssertEqual(calls, ["args=show\ninput.event=sheet.open\nsetting.city=Paris"])

        let field = try await sent("search", by: sheet) { sheet.set(try XCTUnwrap(sheet.panel?.parts.first { $0.id == "search" }), to: "milk") }
        let button = try await sent("go", by: sheet) { sheet.press(try XCTUnwrap(sheet.panel?.parts.first { $0.id == "go" })) }
        let pick = try await sent("press", by: sheet) { sheet.pick(try XCTUnwrap(sheet.list.all.first)) }
        let change = try await sent("show", by: sheet) { sheet.show(need: .change) }
        let page = try await sent("show", by: sheet) { sheet.show(FlowSheet(spot: "script", route: "photo")) }
        try await wait("the list") { sheet.list.all.count == 1 }
        let routed = try await sent("press", by: sheet) { sheet.pick(try XCTUnwrap(sheet.list.all.first)) }

        XCTAssertEqual(field, "args=search\ninput.search=milk\ninput.title=Groceries\ninput.value=milk\nsetting.city=Paris")
        XCTAssertEqual(button, "args=go\ninput.search=\ninput.title=Groceries\nsetting.city=Paris")
        XCTAssertEqual(pick, "args=press\ninput.item=a\ninput.item.item=a\ninput.item.title=A\ninput.item.meeting=42\nsetting.city=Paris")
        XCTAssertEqual(change, "args=show\ninput.search=\ninput.title=Groceries\ninput.event=spot.change\nsetting.city=Paris")
        XCTAssertEqual(page, "args=show\ninput.event=sheet.open\ninput.route=photo\nsetting.city=Paris")
        XCTAssertEqual(routed, "args=press\ninput.item=a\ninput.item.item=a\ninput.item.title=A\ninput.item.meeting=42\ninput.route=photo\nsetting.city=Paris")
    }

    func testTheItemsAndTheCardSendTheirHandlerAndInputs() async throws {
        let sheet = try spot("every = 600")
        let item = SpotItem(title: "A", run: "a", fields: [.init(key: "url", value: "x")])
        let action = try XCTUnwrap(CommandAction(id: "remove", block: TextBlock(fields: [.init(key: "button", value: "remove"), .init(key: "title", value: "Remove")])))

        let key = try await sent("panel-key", by: sheet) { sheet.set(SpotItem(title: "Key", run: "panel-key"), to: "cmd+k") }
        let toggle = try await sent("lid", by: sheet) { sheet.pick(SpotItem(title: "Lid", run: "lid", isOn: false, isToggle: true, fields: [.init(key: "kind", value: "lid")])) }
        let run = try await sent("remove", by: sheet) { sheet.run(action, item: item) }
        let answer = try await sent("remove", by: sheet) { _ = await sheet.answer(to: action, item: item) }
        let send = try await sent("note", by: sheet) { sheet.setCardPart("note", to: "hi") }
        let ping = try await sent("ping", by: sheet) { sheet.setCardPart("ping", to: nil) }
        let global = try await sent("go", by: sheet) { sheet.pressKey("go") }
        let call = try await sent("go", by: sheet) { _ = try await sheet.call("go", inputs: [.init(key: "x", value: "1")]) }
        let drag = try await sent("drag", by: sheet) { sheet.dragged([SpotItem(title: "A", run: "a"), SpotItem(title: "B", run: "b")]) }
        let card = try await sent("press", by: sheet) { sheet.pressCard() }

        XCTAssertEqual(key, "args=panel-key\ninput.value=cmd+k\nsetting.city=Paris")
        XCTAssertEqual(toggle, "args=lid\ninput.value=true\ninput.item.kind=lid\nsetting.city=Paris")
        XCTAssertEqual(run, "args=remove\ninput.item=a\ninput.item.url=x\nsetting.city=Paris")
        XCTAssertEqual(answer, "args=remove\ninput.item=a\ninput.item.url=x\nsetting.city=Paris")
        XCTAssertEqual(send, "args=note\ninput.value=hi\nsetting.city=Paris")
        XCTAssertEqual(ping, "args=ping\nsetting.city=Paris")
        XCTAssertEqual(global, "args=go\nsetting.city=Paris")
        XCTAssertEqual(call, "args=go\ninput.x=1\nsetting.city=Paris")
        XCTAssertEqual(drag, "args=drag\ninput.item=a\ninput.item=b\nsetting.city=Paris")
        XCTAssertEqual(card, "args=press\nsetting.city=Paris")
    }

    func testADropSendsDropWithEachFile() async throws {
        let sheet = try spot("drop = [\"txt\"]")
        let file = folder.appendingPathComponent("a.txt")
        try "a".write(to: file, atomically: true, encoding: .utf8)

        let drop = try await sent("drop", by: sheet) { XCTAssertTrue(sheet.drop([file.path, file.path])) }

        XCTAssertEqual(drop, "args=drop\ninput.file=\(file.path)\ninput.file=\(file.path)\nsetting.city=Paris")
    }

    func testACommandAndItsFormSendCommandWithTheWord() async throws {
        let sheet = try spot("command = [\"snooze\"]", toml: "[actions.start]\ntitle = 'Start'\ninputs.minutes = { type = 'text', required = true }")
        let word = CommandAction.word("snooze")
        let start = CommandAction(id: "start", title: "Start", scope: .spot)
        var draft = FormDraft(form: try XCTUnwrap(ItemForm(output: Frame(text: "frame=\ntype=form\ntitle=Snooze\n\nfield=until\ntitle=Until\n"))))
        draft.set("noon", for: "until")

        let command = try await sent("command", by: sheet) { _ = try await sheet.launch(word, search: SearchQuery(text: "tomorrow")) }
        let submit = try await sent("command", by: sheet) { _ = try await sheet.submit(word, item: nil, draft: draft) }
        let launch = try await sent("start", by: sheet) { _ = try await sheet.launch(start, search: SearchQuery(text: "45", layouts: [])) }

        XCTAssertEqual(command, "args=command\ninput.name=snooze\ninput.text=tomorrow\nsetting.city=Paris")
        XCTAssertEqual(submit, "args=command\ninput.name=snooze\ninput.until=noon\nsetting.city=Paris")
        XCTAssertEqual(launch, "args=start\ninput.minutes=45\nsetting.city=Paris")
    }

    func testTheSearchesSendTheirTextAndEachFormOfIt() async throws {
        let sheet = try spot("search = \".\"\n\"sheet.text\" = true")

        let main = try await sent("search", by: sheet) { runs.raise(.query("ыфа")) }
        try await opened(sheet)
        let typed = try await sent("sheet.text", by: sheet) { sheet.search("ыфа") }

        XCTAssertEqual(main, "args=search\ninput.text=ыфа\ninput.alt=yfa\nsetting.city=Paris")
        XCTAssertEqual(typed, "args=sheet.text\ninput.search=\ninput.title=Groceries\ninput.value=ыфа\ninput.alt=yfa\nsetting.city=Paris")
    }

    func testTheClockSendsEveryAndTheTextOfASearchedSheet() async throws {
        menuBar.insert("script")
        let sheet = try spot("every = 1\n\"sheet.text\" = true")
        try await wait("the first tick") { self.calls.count == 1 && sheet.calls.isEmpty }
        let tick = calls[0]
        try await opened(sheet)
        _ = try await sent("sheet.text", by: sheet) { sheet.search("ab") }

        let searched = try await sent("sheet.text", by: sheet) { time += 1 }

        XCTAssertEqual(tick, "args=every\nsetting.city=Paris")
        XCTAssertEqual(searched, "args=sheet.text\ninput.search=\ninput.title=Groceries\ninput.value=ab\nsetting.city=Paris")
    }

    func testTheEventsOfTheMacSendTheirHandlerAndValue() async throws {
        menuBar.insert("script")
        let sheet = try spot("\"panel.open\" = true\n\"power.change\" = true\n\"clipboard.change\" = true\n\"app.launch\" = true\n\"spot.want\" = true")

        let panel = try await sent("show", by: sheet) { runs.panelOpened() }
        let power = try await sent("power.change", by: sheet) { runs.raise(.named(EventName.powerChange, value: "ac")) }
        let clipboard = try await sent("clipboard.change", by: sheet) { runs.raise(.named(EventName.clipboard, value: nil)) }
        let launch = try await sent("app.launch", by: sheet) { runs.launched() }
        let want = try await sent("show", by: sheet) { runs.want("script") }

        XCTAssertEqual(panel, "args=show\ninput.event=panel.open\nsetting.city=Paris")
        XCTAssertEqual(power, "args=power.change\ninput.value=ac\nsetting.city=Paris")
        XCTAssertEqual(clipboard, "args=clipboard.change\nsetting.city=Paris")
        XCTAssertEqual(launch, "args=app.launch\nsetting.city=Paris")
        XCTAssertEqual(want, "args=show\ninput.event=spot.want\nsetting.city=Paris")
    }

    func testARunFromTerminalAndACheckSendTheirHandler() async throws {
        let sheet = try spot("\"sheet.open\" = true")
        let settings = [TextBlock.Field(key: "city", value: "Paris")]

        _ = await TerminalRun(spot: sheet.spot, handler: nil, input: nil, inputs: [], settings: settings, careful: nil, callers: nil, environment: nil, folder: nil).start { _ in }
        _ = await TerminalRun(spot: sheet.spot, handler: "go", input: "x=2\n", inputs: [.init(key: "x", value: "1")], settings: settings, careful: nil, callers: nil, environment: nil, folder: nil).start { _ in }
        _ = try await runs.answer(of: sheet.spot, Handler.show.name)

        XCTAssertEqual(calls, ["args=show\ninput.event=sheet.open\nsetting.city=Paris", "args=go\ninput.x=1\nx=2\nsetting.city=Paris", "args=show\n"])
    }

    func testAStayingSpotGetsEachCallAsABlock() async throws {
        try script(toml: "stay = true\n[settings]\ncity = 'text'\n[on]\n\"sheet.open\" = true", """
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("stdin"))'
          case $line in
            call=*) n=${line#call=} ;;
            '') printf 'call=%s\\n---\\ntitle=Hi\\n---\\nend=%s\\n---\\n' "$n" "$n" ;;
          esac
        done
        """)
        let sheet = try sheet()
        runs.take(settings: [SpotSetting(spot: "script", key: "city", value: "Paris")])
        runs.panelOpened()
        sheet.open {}
        try await wait("the show") { ((try? String(contentsOfFile: self.path("stdin"), encoding: .utf8)) ?? "").hasSuffix("\n\n") }

        sheet.pick(SpotItem(title: "A", run: "a", fields: [.init(key: "url", value: "x")]))

        try await wait("the press") { ((try? String(contentsOfFile: self.path("stdin"), encoding: .utf8)) ?? "").components(separatedBy: "\n\n").count == 3 }
        XCTAssertEqual(try String(contentsOfFile: path("stdin"), encoding: .utf8), """
        call=1
        arg=show
        input.event=sheet.open
        setting.city=Paris

        call=2
        arg=press
        input.item=a
        input.item.url=x
        setting.city=Paris


        """)
        let before = try String(contentsOfFile: path("stdin"), encoding: .utf8)
        _ = try await StayMode.answer(of: sheet.spot, Handler.show.name, input: "x=2\n", limit: 10, variables: [:], in: runs)
        XCTAssertEqual(try String(contentsOfFile: path("stdin"), encoding: .utf8).dropFirst(before.count), "call=1\narg=show\ninput.event=panel.open\nx=2\n\n")
    }
}
