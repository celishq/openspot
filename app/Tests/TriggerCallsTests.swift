import XCTest
@testable import OpenspotCore

@MainActor
final class TriggerCallsTests: SpotRunsCase {
    private var client: String {
        Bundle(for: FakeHost.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot").path
    }

    private func spot(_ on: String, toml: String = "", view: String = "show|every|search|power.change") throws -> SpotRun {
        try script(toml: "\(toml)\n[on]\n\(on)", """
        in=$(cat)
        printf '%s|%s\\n' "$*" "$(printf '%s\\n' "$in" | grep -E '^(input\\.|event|item\\.|search)' | grep -v '^input\\.event=' | tr '\\n' ' ')" >> '\(path("calls"))'
        case "$1" in \(view)) printf 'text=a\\ntitle=A\\n' ;; esac
        """)
        return try sheet()
    }

    private var calls: [String] {
        log("calls")
    }

    func testAnOpenOfTheSheetCallsShowWithNoEvent() async throws {
        let sheet = try spot("every = 600")

        sheet.open {}

        try await wait("the show") { self.calls == ["show|"] }
    }

    func testAShowGetsTheEventThatAskedForItAsAnInput() async throws {
        menuBar.insert("script")
        try script(toml: "[on]\n\"panel.open\" = true", """
        printf '%s|%s\\n' "$*" "$(grep '^input\\.event=' | tr '\\n' ' ')" >> '\(path("calls"))'
        printf 'text=a\\ntitle=A\\n'
        """)
        _ = try sheet()

        runs.panelOpened()

        try await wait("the show of the open") { self.calls.contains("show|input.event=panel.open ") }
    }

    func testASpotReadsItsOwnSecretWithSettingGet() async throws {
        takeCalls()
        try AppPlaces.test(["OPENSPOT_CONFIG": folder.path]).secrets.keep("MARKER-5b1e", key: "token", of: "script")
        try script(toml: "[settings]\ntoken = { type = 'secret' }\n[on]\n\"sheet.open\" = true", """
        '\(client)' setting get token > '\(path("read"))'
        printf 'text=a\\ntitle=A\\n'
        """)
        let sheet = try sheet()

        sheet.open {}

        try await wait("the read") { self.log("read") == ["MARKER-5b1e"] }
    }

    func testACommandCallsCommandWithItsNameAndText() async throws {
        let sheet = try spot("command = [\"snooze\"]")

        _ = try await sheet.launch(CommandAction.word("snooze"), search: SearchQuery(text: "tomorrow"))

        try await wait("the command") { self.calls == ["command|input.name=snooze input.text=tomorrow "] }
    }

    func testAFormThatACommandAnswersWithSendsItsValuesToCommandWithTheWord() async throws {
        try script(toml: "[on]\ncommand = [\"snooze\"]", """
        in=$(cat)
        printf '%s|%s\\n' "$*" "$(printf '%s\\n' "$in" | grep '^input\\.' | tr '\\n' ' ')" >> '\(path("calls"))'
        case "$in" in
          *input.until=*) ;;
          *) printf 'frame=\\ntype=form\\ntitle=Snooze\\n\\nfield=until\\ntitle=Until\\n' ;;
        esac
        """)
        let sheet = try sheet()
        let word = CommandAction.word("snooze")

        let answer = try await sheet.launch(word, search: SearchQuery(text: ""))
        guard case .form(let form) = answer else { return XCTFail("no form: \(answer)") }
        var draft = FormDraft(form: form)
        draft.set("tomorrow", for: "until")
        _ = try await sheet.submit(word, item: nil, draft: draft)

        try await wait("the submit") { self.calls.count == 2 }
        XCTAssertEqual(calls, ["command|input.name=snooze input.text= ", "command|input.name=snooze input.until=tomorrow "])
    }

    func testWordsTypedAfterAButtonFillTheTextInputOfItsActionAndNoWordsAskWithItsForm() async throws {
        let sheet = try spot("\"sheet.open\" = true", toml: "[actions.start]\ninputs.minutes = { type = 'text', required = true }")
        let start = CommandAction(id: "start", title: "Keep awake for…", scope: .spot)

        let empty = try await sheet.launch(start, search: SearchQuery(text: "", layouts: []))
        _ = try await sheet.launch(start, search: SearchQuery(text: "45", layouts: []))

        guard case .form(let form) = empty else { return XCTFail("no form: \(empty)") }
        XCTAssertEqual(form.fields.map(\.name), ["minutes"])
        try await wait("the start") { self.calls == ["start|input.minutes=45 "] }
    }

    func testWordsTypedAfterAButtonFillItsFirstTextInputAndAskForTheOtherRequiredInputs() async throws {
        let sheet = try spot("\"sheet.open\" = true", toml: "[actions.new]\ninputs.url = { type = 'text', required = true }\ninputs.title = { type = 'text', required = true }")
        let new = CommandAction(id: "new", title: "New link", scope: .spot)

        let answer = try await sheet.launch(new, search: SearchQuery(text: "example.com", layouts: []))

        guard case .form(let form) = answer else { return XCTFail("no form: \(answer)") }
        XCTAssertEqual(form.title, "New link")
        XCTAssertEqual(form.fields.map(\.name), ["url", "title"])
        XCTAssertEqual(FormDraft(form: form).values["url"], "example.com")
        XCTAssertEqual(calls, [])
    }

    func testTheMainSearchCallsSearchWithItsText() async throws {
        let sheet = try spot("search = \"^https\"")

        runs.raise(.query("https://a.com"))

        try await wait("the search") { self.calls == ["search|input.text=https://a.com "] }
        try await wait("the answer") { sheet.answers.map(\.run) == ["a"] }
    }

    func testASearchGetsEachFormOfItsTextAsAlt() async throws {
        _ = try spot("search = \".\"")

        runs.raise(.query("ыфа"))

        try await wait("the search") { self.calls.count == 1 }
        XCTAssertTrue(calls[0].hasPrefix("search|input.text=ыфа "), calls[0])
        XCTAssertTrue(calls[0].contains("input.alt=yfa "), calls[0])
    }

    func testATextTypedInTheSheetGetsEachFormOfItAsAlt() async throws {
        let sheet = try spot("\"sheet.text\" = true", view: "show|sheet.text")
        sheet.open {}
        try await wait("the show") { self.calls == ["show|"] }

        sheet.search("ыфа")

        try await wait("the text") { self.calls.count == 2 }
        XCTAssertTrue(calls[1].hasPrefix("sheet.text|input.value=ыфа "), calls[1])
        XCTAssertTrue(calls[1].contains("input.alt=yfa "), calls[1])
    }

    func testASystemEventCallsTheHandlerOfItsNameWithItsValue() async throws {
        menuBar.insert("script")
        _ = try spot("\"power.change\" = true")
        try await wait("the first show") { self.calls == ["show|"] && !self.runs.isShowing }

        runs.raise(.named(EventName.powerChange, value: "ac"))

        try await wait("the event") { self.calls == ["show|", "power.change|input.value=ac "] }
    }

    func testAClipboardCopyCallsClipboardChange() async throws {
        menuBar.insert("script")
        _ = try spot("\"clipboard.change\" = true", view: "show|clipboard.change")
        try await wait("the first show") { self.calls == ["show|"] && !self.runs.isShowing }

        runs.raise(.named(EventName.clipboard, value: nil))

        try await wait("the event") { self.calls == ["show|", "clipboard.change|"] }
    }

    func testAnEventHandlerIsARead() async throws {
        takeCalls()
        menuBar.insert("script")
        try script(toml: "[on]\n\"power.change\" = true", """
        case "$1" in
          power.change) '\(client)' spot open other 2>> '\(path("errors"))' ;;
          *) printf 'text=a\\ntitle=A\\n' ;;
        esac
        """)
        _ = try sheet()
        try await wait("the first show") { !self.runs.isShowing && self.log() == ["show"] }

        runs.raise(.named(EventName.powerChange, value: "ac"))

        try await wait("the refusal") { self.log("errors").contains { $0.contains("cannot run in a show") } }
    }

    func testADropCallsDropWithEachFile() async throws {
        let sheet = try spot("drop = [\"txt\"]")
        let file = folder.appendingPathComponent("a.txt")
        try "a".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertTrue(sheet.drop([file.path]))

        try await wait("the drop") { self.calls.first == "drop|input.file=\(file.path) " }
    }

    func testADragCallsDragWithEachItem() async throws {
        let sheet = try spot("every = 600")

        sheet.dragged([SpotItem(title: "A", run: "a"), SpotItem(title: "B", run: "b")])

        try await wait("the drag") { self.calls.first == "drag|input.item=a input.item=b " }
    }

    func testAKeyRecordedOnARowCallsItsIDWithTheKey() async throws {
        let sheet = try spot("every = 600")

        sheet.set(SpotItem(title: "Key", run: "panel-key"), to: "cmd+k")

        try await wait("the key") { self.calls.first == "panel-key|input.value=cmd+k " }
    }

    func testAPickOfASwitchRowCallsItsIDWithItsNewValue() async throws {
        let sheet = try spot("every = 600")

        sheet.pick(SpotItem(title: "Lid", run: "lid", isOn: false, isToggle: true))

        try await wait("the switch") { self.calls.first == "lid|input.value=true " }
    }

    func testAPressOfAnItemCallsPressWithTheItem() async throws {
        let sheet = try spot("every = 600")

        sheet.pick(SpotItem(title: "A", run: "a", fields: [.init(key: "url", value: "x")]))

        try await wait("the press") { self.calls.first == "press|input.item=a input.item.url=x " }
    }

    func testAnActionOfAnItemCallsItsIDWithTheItemAndItsOwnKeys() async throws {
        let sheet = try spot("every = 600")
        let action = try XCTUnwrap(CommandAction(id: "remove", block: TextBlock(fields: [.init(key: "button", value: "remove"), .init(key: "title", value: "Remove")])))

        sheet.run(action, item: SpotItem(title: "A", run: "a", fields: [.init(key: "url", value: "x")]))

        try await wait("the action") { self.calls.first == "remove|input.item=a input.item.url=x " }
    }

    func testTheRouteOfThePageIsAnInput() async throws {
        let sheet = try spot("every = 600", toml: "pages = [\"date\"]")
        sheet.open {}
        try await wait("the show") { self.calls == ["show|"] && !self.runs.isShowing }

        sheet.show(FlowSheet(spot: "script", route: "date", title: "Date"))

        try await wait("the show of the page") { self.calls.last == "show|input.route=date " }
    }

    func testASendFromAViewCallsTheActionOfItsNodeWithTheValue() async throws {
        let sheet = try spot("every = 600", toml: "[actions.note]\ninputs.value = \"text\"")

        sheet.setCardPart("note", to: "hi")

        try await wait("the send") { self.calls.first == "note|input.value=hi " }
    }

    func testTheClockCallsEveryWhileAPlaceShows() async throws {
        menuBar.insert("script")
        _ = try spot("every = 1")
        try await wait("the first tick") { self.calls == ["every|"] && !self.runs.isShowing }

        time += 1

        try await wait("the next tick") { self.calls == ["every|", "every|"] }
    }
}
