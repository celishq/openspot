import XCTest
@testable import OpenspotCore

final class PanelAskTests: PanelCase {
    private var called: URL {
        folder.appendingPathComponent("called")
    }

    private var go: URL {
        folder.appendingPathComponent("go")
    }

    func testASettingFormDoesNotOpenInAHiddenPanel() async throws {
        try script("editor", toml: "title = 'Editor'\n[settings]\neditor = { type = 'text' }", """
        touch '\(called.path)'
        [ "$1" = editor ] && printf 'frame=\\ntitle=Editor\\n\\nfield=editor\\ntitle=Editor\\n'
        """)
        await model.reload()

        XCTAssertTrue(model.changeSetting("editor", of: "editor"))

        try await wait("the call") { FileManager.default.fileExists(atPath: self.called.path) }
        try await wait("the answer") { self.model.pendingAsk == nil }
        XCTAssertNil(model.form)
    }

    func testThePanelHoldsItsFocusWhileAPickerAsksAndTakesItBackAfter() async throws {
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        let takes = host.focusTakes

        let held = await model.holdingFocus { self.model.holdsFocus }

        XCTAssertTrue(held)
        XCTAssertFalse(model.holdsFocus)
        XCTAssertEqual(host.focusTakes, takes + 1)
    }

    func testASettingThatItsSpotChangesLeavesThePanelOpen() async throws {
        try script("editor", toml: "title = 'Editor'\n[settings]\neditor = { type = 'text' }", "touch '\(called.path)'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()

        XCTAssertTrue(model.changeSetting("editor", of: "editor"))

        try await wait("the call") { FileManager.default.fileExists(atPath: self.called.path) }
        try await wait("the answer") { self.model.pendingAsk == nil }
        XCTAssertEqual(host.dismissals, 0)
    }

    func testASettingWithOptionsIsAChoiceThatOpenspotKeepsWithNoCall() async throws {
        try script("snooze", toml: "title = 'Snooze'\n[settings]\nmorning = { type = 'choice', options = ['7:00', '8:00', '9:00'] }", "[ \"$1\" = show ] || touch '\(called.path)'")
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        try? FileManager.default.removeItem(at: called)

        XCTAssertTrue(model.changeSetting("morning", of: "snooze"))

        let field = try XCTUnwrap(model.form?.draft.form.fields.first)
        XCTAssertEqual(field.type, .choice)
        XCTAssertEqual(field.options.map(\.id), ["7:00", "8:00", "9:00"])
        model.chooseFormOption(SpotItem(title: "9:00", run: "9:00"))
        try await wait("the kept value") { self.model.files.config.read().setting("morning", of: "snooze") == "9:00" }
        XCTAssertFalse(FileManager.default.fileExists(atPath: called.path))
    }

    func testAFailureShowsAfterItsAskWasLeft() async throws {
        try script("notes", toml: "title = 'Notes'", """
        [ "$1" = add ] || { printf 'text=a\\ntitle=A\\nopen.title=add\\n'; exit 0; }
        touch '\(called.path)'
        while [ ! -f '\(go.path)' ]; do sleep 0.02; done
        echo 'No notes folder' >&2
        exit 3
        """)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        let entry = try XCTUnwrap(model.entry("notes"))

        model.ask(CommandAction(id: "add", title: "Add", scope: .spot), on: (entry, nil)) { [sheets = model.sheets] in
            try await sheets["notes"]?.change(CommandAction(id: "add", title: "Add", scope: .spot))
        }
        try await wait("the call") { FileManager.default.fileExists(atPath: self.called.path) }
        model.closeSheet(moving: false)
        FileManager.default.createFile(atPath: go.path, contents: nil)

        try await wait("the failure") { self.host.notes.contains { $0.hasPrefix("Add failed.") } }
    }
}
