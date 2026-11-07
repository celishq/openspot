import XCTest
@testable import OpenspotCore

/// Proves the Snippets plugin with its real script in a private home.
final class SnippetsPluginTests: SamplePluginsCase {
    func testAConfigPathHoldsTheDataOfAPlugin() async throws {
        let snippets = try XCTUnwrap(try scan.commands.first { $0.name == "Snippets" })
        try await withPrivateHome { folder in
            let config = folder.appendingPathComponent("debug-config")
            setenv("OPENSPOT_CONFIG", config.path, 1)
            defer { unsetenv("OPENSPOT_CONFIG") }
            let new = try await self.action("new", of: snippets)
            var draft = FormDraft(form: try await snippets.form(new, item: nil, timeout: 5))
            draft.set("A", for: "title")
            draft.set("B", for: "content")

            _ = try await snippets.submit(new, item: nil, draft: draft, timeout: 5)

            XCTAssertTrue(FileManager.default.fileExists(atPath: config.appendingPathComponent("data/snippets/snippets.json").path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent(".config").path))
        }
    }

    func testSnippetsKeepsExactTextThroughNewCopyEditPasteAndDelete() async throws {
        let snippets = try XCTUnwrap(try scan.commands.first { $0.name == "Snippets" })
        let text = "Say \"héllo\" \\ now\n\tthen $HOME\n"
        try await withPrivateHome { folder in
            let empty = try await snippets.items(timeout: 5)
            XCTAssertEqual(empty.items, [])

            let new = try await action("new", of: snippets)
            let form = try await snippets.form(new, item: nil, timeout: 5)
            var draft = FormDraft(form: form)
            draft.set("Hello", for: "title")
            draft.set(text, for: "content")
            let run = try await snippets.submit(new, item: nil, draft: draft, timeout: 5)

            let lines = try await snippets.items(timeout: 5)
            XCTAssertEqual(lines.errors, [])
            let item = try XCTUnwrap(lines.items.first)
            XCTAssertEqual(item.run, run)
            XCTAssertEqual(item.title, "Hello")
            XCTAssertEqual(item.subtitle, "Say \"héllo\" \\ now then $HOME ")

            try await snippets.perform(.item(item), timeout: 5)
            XCTAssertEqual(try self.read("clipboard", in: folder), text)

            let edit = try await action("edit", of: snippets)
            let filled = try await snippets.form(edit, item: item, timeout: 5)
            XCTAssertEqual(filled.fields.map(\.value), ["Hello", text])
            var changed = FormDraft(form: filled)
            changed.set("Changed", for: "title")
            _ = try await snippets.submit(edit, item: item, draft: changed, timeout: 5)
            let edited = try await snippets.items(timeout: 5).items
            XCTAssertEqual(edited.map(\.title), ["Changed"])

            try "before".write(to: folder.appendingPathComponent("clipboard"), atomically: true, encoding: .utf8)
            try await snippets.perform(.action(try await self.action("paste", of: snippets), item: item), timeout: 5)
            XCTAssertEqual(try self.read("pasted", in: folder), text)
            XCTAssertEqual(try self.read("clipboard", in: folder), "before")

            try await snippets.perform(.action(try await self.action("delete", of: snippets), item: item), timeout: 5)
            let gone = try await snippets.items(timeout: 5).items
            XCTAssertEqual(gone, [])
        }
    }

    func testACopyOfAMissingSnippetFails() async throws {
        let snippets = try XCTUnwrap(try scan.commands.first { $0.name == "Snippets" })
        try await withPrivateHome { _ in
            do {
                try await snippets.perform(.item(SpotItem(title: "Gone", run: "gone")), timeout: 5)
                XCTFail("expected a failure")
            } catch let error as PluginError {
                XCTAssertEqual(error.reason, "This snippet is gone.")
            }
        }
    }
}
