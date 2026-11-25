import XCTest
@testable import OpenspotCore

@MainActor
final class ActionFormTests: PanelCase {
    func testAPressOfAnActionWithAnEmptyRequiredInputAsksForItWithAFormDrawnFromItsTypes() async throws {
        let given = folder.appendingPathComponent("given").path
        try script("snooze", toml: """
        title = "Snooze"

        [actions.snooze]
        title = "Snooze Tab"
        inputs.url = { type = "url", required = true, description = "The tab to snooze" }
        inputs.minutes = { type = "number", default = 5 }
        inputs.size = { type = "choice", options = ["s", "m"], default = "m" }
        inputs.loud = "bool"
        """, """
        . "$OPENSPOT_SH"
        case "$1" in
          snooze)
            case "$(value url)" in
              *bad*) echo "error=Cannot reach that tab" ;;
              *) printf '%s %s %s %s' "$(value url)" "$(value minutes)" "$(value size)" "$(value loud)" > '\(given)' ;;
            esac
            ;;
        esac
        """)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        let entry = try XCTUnwrap(model.entry("snooze"))
        let offer = try XCTUnwrap(entry.spot.commands.first { $0.id == "snooze" })

        model.run(CommandAction.command(offer), on: (entry, nil))

        try await wait("the form") { self.model.form != nil }
        let form = try XCTUnwrap(model.form?.draft.form)
        XCTAssertEqual(form.title, "Snooze Tab")
        XCTAssertEqual(form.fields.map(\.name), ["url", "minutes", "size", "loud"])
        XCTAssertEqual(form.fields.map(\.type), [.text, .text, .choice, .switch])
        XCTAssertEqual(form.fields.map(\.value), [nil, "5", "m", "false"])
        XCTAssertEqual(form.fields.first?.placeholder, "The tab to snooze")
        XCTAssertFalse(FileManager.default.fileExists(atPath: given))

        model.setFormValue("https://bad.example", for: "url")
        model.submitForm()
        try await wait("the failure") { self.host.notes.contains { $0.contains("Cannot reach that tab") } }
        XCTAssertNotNil(model.form)

        model.setFormValue("https://good.example", for: "url")
        model.submitForm()
        try await wait("the call") { (try? String(contentsOfFile: given, encoding: .utf8)) == "https://good.example 5 m false" && self.model.form == nil }
        XCTAssertEqual(try String(contentsOfFile: given, encoding: .utf8), "https://good.example 5 m false")
    }
}
