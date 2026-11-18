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
        try script("editor", toml: "title = 'Editor'\non = ['sheet.open']\n[settings.editor]", """
        touch '\(called.path)'
        [ "$1" = editor ] && printf 'frame=\\ntitle=Editor\\n\\nfield=editor\\ntitle=Editor\\n'
        """)
        await model.reload()

        XCTAssertTrue(model.changeSetting("editor", of: "editor"))

        try await wait("the call") { FileManager.default.fileExists(atPath: self.called.path) }
        try await wait("the answer") { self.model.pendingAsk == nil }
        XCTAssertNil(model.form)
    }

    func testAFailureShowsAfterItsAskWasLeft() async throws {
        try script("notes", toml: "title = 'Notes'\non = ['sheet.open']", """
        [ "$1" = add ] || { printf 'row=a\\ntitle=A\\nopen=add\\n'; exit 0; }
        touch '\(called.path)'
        while [ ! -f '\(go.path)' ]; do sleep 0.02; done
        echo 'No notes folder' >&2
        exit 3
        """)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        let entry = try XCTUnwrap(model.entry("notes"))

        model.openForm(CommandAction(id: "add", title: "Add", scope: .spot, isForm: true), on: (entry, nil))
        try await wait("the call") { FileManager.default.fileExists(atPath: self.called.path) }
        model.closeSheet(moving: false)
        FileManager.default.createFile(atPath: go.path, contents: nil)

        try await wait("the failure") { self.host.notes.contains { $0.hasPrefix("Add failed.") } }
    }
}
