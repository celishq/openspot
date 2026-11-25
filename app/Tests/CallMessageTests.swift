import XCTest
@testable import OpenspotCore

@MainActor
final class CallMessageTests: SpotRunsCase {
    private func text(_ name: String) -> String {
        (try? String(contentsOfFile: path(name), encoding: .utf8)) ?? ""
    }

    private var keeps: String {
        "{ echo \"$*\"; cat; env | grep '^OPENSPOT_\\(REASON\\|VALUE\\|PAGE\\|SETTING_\\)' | sort; echo; } >> '\(path("calls"))'"
    }

    func testAShowCallCarriesItsEventOnStdinAndNotInTheEnvironment() async throws {
        try script(toml: "", keeps)
        let sheet = try sheet()

        sheet.show(need: .change)
        try await wait("the show") { self.text("calls").hasSuffix("\n\n") && !sheet.isShowing }
        sheet.answer("milk")

        try await wait("the answer") { self.text("calls").contains("search\n") && sheet.calls.isEmpty }
        XCTAssertEqual(text("calls"), "show\ninput.event=spot.change\n\nsearch\ninput.text=milk\n\n")
    }

    func testStdinHoldsTheInputsTheSettingsTheRouteAndThePickedItem() async throws {
        try script(toml: "[settings]\ncity = 'text'\ntoken = 'secret'", """
        case "$1" in
          show) printf 'frame=\\nclass=gap-part\\n\\nfield=search\\ntitle=Find\\nvalue=\\n\\nfield=title\\nvalue=Groceries\\n\\nitems=list\\n\\nitem=a\\nparent=list\\ntitle=A\\nmeeting=42\\n' ;;
          *) \(keeps) ;;
        esac
        """)
        let store = SecretStore(file: folder.appendingPathComponent("secrets.json"))
        try store.keep("k1", key: "token", of: "script")
        runs.secrets = store
        let sheet = try sheet()
        runs.take(settings: [SpotSetting(spot: "script", key: "city", value: "Paris")])
        runs.panelOpened()
        sheet.open {}
        try await wait("the sheet") { sheet.panel != nil && sheet.list.all.count == 1 && !sheet.isShowing }
        sheet.show(FlowSheet(spot: sheet.spot.id, route: "photo/12"))
        try await wait("the route") { !sheet.isShowing }

        sheet.pick(try XCTUnwrap(sheet.list.all.first))
        try await wait("the pick") { self.text("calls").hasSuffix("\n\n") && sheet.calls.isEmpty }
        sheet.set(try XCTUnwrap(sheet.panel?.parts.first { $0.id == "search" }), to: "milk")

        try await pass(0.3, on: clock)
        try await wait("the field") { self.text("calls").contains("input.value=milk") && sheet.calls.isEmpty }
        XCTAssertEqual(text("calls"), """
        press
        input.item=a
        input.item.item=a
        input.item.title=A
        input.item.meeting=42
        input.route=photo/12
        setting.city=Paris

        search
        input.search=milk
        input.title=Groceries
        input.value=milk
        input.route=photo/12
        setting.city=Paris


        """)
    }

    func testAStayingSpotGetsTheSameBlockAfterItsCall() async throws {
        try script(toml: "stay = true\n[settings]\ncity = 'text'", """
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

        try await wait("the call") { self.text("stdin").hasSuffix("\n\n") }
        XCTAssertEqual(text("stdin"), "call=1\narg=show\ninput.event=sheet.open\nsetting.city=Paris\n\n")
    }
}
