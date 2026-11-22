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
        printf '%s|%s\\n' "$*" "$(printf '%s\\n' "$in" | grep -E '^(input\\.|event|item\\.|search)' | tr '\\n' ' ')" >> '\(path("calls"))'
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

    func testACommandCallsCommandWithItsNameAndText() async throws {
        let sheet = try spot("command = [\"snooze\"]")

        _ = try await sheet.launch(CommandAction.word("snooze"), search: SearchQuery(text: "tomorrow"))

        try await wait("the command") { self.calls == ["command|input.name=snooze input.text=tomorrow "] }
    }

    func testTheMainSearchCallsSearchWithItsText() async throws {
        let sheet = try spot("search = \"^https\"")

        runs.raise(.query("https://a.com"))

        try await wait("the search") { self.calls == ["search|input.text=https://a.com "] }
        try await wait("the answer") { sheet.answers.map(\.run) == ["a"] }
    }

    func testASystemEventCallsTheHandlerOfItsNameWithItsValue() async throws {
        menuBar.insert("script")
        _ = try spot("\"power.change\" = true")
        try await wait("the first show") { self.calls == ["show|"] && !self.runs.isShowing }

        runs.raise(.named(SpotEvent.powerChange, value: "ac"))

        try await wait("the event") { self.calls == ["show|", "power.change|input.value=ac "] }
    }

    func testAClipboardCopyCallsClipboardChange() async throws {
        menuBar.insert("script")
        _ = try spot("\"clipboard.change\" = true", view: "show|clipboard.change")
        try await wait("the first show") { self.calls == ["show|"] && !self.runs.isShowing }

        runs.raise(.named(SpotEvent.clipboard, value: nil))

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

        runs.raise(.named(SpotEvent.powerChange, value: "ac"))

        try await wait("the refusal") { self.log("errors").contains { $0.contains("cannot run in a show") } }
    }

    func testADropCallsDropWithEachFile() async throws {
        let sheet = try spot("drop = [\"txt\"]")
        let file = folder.appendingPathComponent("a.txt")
        try "a".write(to: file, atomically: true, encoding: .utf8)

        XCTAssertTrue(sheet.drop([file.path]))

        try await wait("the drop") { self.calls == ["drop|input.file=\(file.path) "] }
    }

    func testADragCallsDragWithEachItem() async throws {
        let sheet = try spot("every = 600")

        sheet.dragged([SpotItem(title: "A", run: "a"), SpotItem(title: "B", run: "b")])

        try await wait("the drag") { self.calls == ["drag|input.item=a input.item=b "] }
    }

    func testAPressOfAnItemCallsPressWithTheItem() async throws {
        let sheet = try spot("every = 600")

        sheet.pick(SpotItem(title: "A", run: "a", fields: [.init(key: "url", value: "x")]))

        try await wait("the press") { self.calls == ["press|input.item=a "] }
    }

    func testASendFromAViewCallsTheActionOfItsNodeWithTheValue() async throws {
        let sheet = try spot("every = 600", toml: "[actions.note]\ninputs.value = \"text\"")

        sheet.setCardPart("note", to: "hi")

        try await wait("the send") { self.calls == ["note|input.value=hi "] }
    }

    func testTheClockCallsEveryWhileAPlaceShows() async throws {
        menuBar.insert("script")
        _ = try spot("every = 1")
        try await wait("the first tick") { self.calls == ["every|"] && !self.runs.isShowing }

        time += 1

        try await wait("the next tick") { self.calls == ["every|", "every|"] }
    }

    func testASpotWithTheOldOnKeepsTheOldShow() async throws {
        menuBar.insert("script")
        try script(toml: "on = ['power.change']", """
        printf '%s|%s\\n' "$*" "$(grep -E '^event' | tr '\\n' ' ')" >> '\(path("calls"))'
        printf 'text=a\\ntitle=A\\n'
        """)
        _ = try sheet()
        try await wait("the first show") { self.calls.count == 1 && !self.runs.isShowing }

        runs.raise(.named(SpotEvent.powerChange, value: "ac"))

        try await wait("the event") { self.calls.last == "show|event=power.change event.value=ac " }
    }
}
