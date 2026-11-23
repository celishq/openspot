import XCTest
@testable import OpenspotCore

final class SnippetsSpotTests: SampleSpotsCase {
    func testAConfigPathHoldsTheDataOfASpot() async throws {
        let snippets = try XCTUnwrap(try scan.spots.first { $0.name == "Snippets" })
        try await withPrivateHome { folder in
            let config = folder.appendingPathComponent("debug-config")
            try await TestEnvironment.with(["OPENSPOT_CONFIG": config.path]) {
                let new = try await self.action("new", of: snippets)
                var draft = FormDraft(form: try await snippets.form(new, item: nil, timeout: 60))
                draft.set("A", for: "title")
                draft.set("B", for: "content")

                _ = try await snippets.submit(new, item: nil, draft: draft, timeout: 60)
            }

            XCTAssertTrue(FileManager.default.fileExists(atPath: config.appendingPathComponent("data/snippets/snippets.json").path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent(".config").path))
        }
    }

    func testNewTakesTheTextOfASlashCommandAsItsText() async throws {
        let snippets = try XCTUnwrap(try scan.spots.first { $0.name == "Snippets" })
        try await withPrivateHome { _ in
            let new = try await self.action("new", of: snippets)
            XCTAssertEqual(new.placeholder, "Text to keep")

            XCTAssertEqual(snippets.typedActions.first { $0.id == "new" }?.textInput?.name, "content")
            XCTAssertFalse(try XCTUnwrap(snippets.typedActions.first { $0.id == "new" }).lacksInput)

            for input in ["", "input.content=hello there\n"] {
                let output = try await Self.answer(of: snippets, "new", input: input)
                let form = try XCTUnwrap(ItemForm(output: output), input)
                XCTAssertEqual(form.title, "New snippet")
                XCTAssertEqual(form.fields.map(\.label), ["Name", "Text"])
                XCTAssertEqual(form.fields.map(\.type), [.text, .multiline])
                XCTAssertEqual(FormDraft(form: form).values["content"] ?? "", input.isEmpty ? "" : "hello there")
            }
        }
    }

    func testAReadStartsOnlyJq() async throws {
        let snippets = try XCTUnwrap(try scan.spots.first { $0.name == "Snippets" })
        try await withPrivateHome { folder in
            let new = try await action("new", of: snippets)
            var draft = FormDraft(form: try await snippets.form(new, item: nil, timeout: 60))
            draft.set("A", for: "title")
            draft.set("B", for: "content")
            _ = try await snippets.submit(new, item: nil, draft: draft, timeout: 60)
            try "#!/bin/sh\necho cat >> '\(folder.path)/started'\nexec /bin/cat \"$@\"\n".writeScript(to: folder.appendingPathComponent("tools/cat"))

            let items = try await snippets.items(timeout: 60).items

            XCTAssertEqual(items.map(\.title), ["A"])
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("started").path))
        }
    }

    func testSnippetsKeepsExactTextThroughNewCopyEditPasteAndDelete() async throws {
        let snippets = try XCTUnwrap(try scan.spots.first { $0.name == "Snippets" })
        let text = "Say \"héllo\" \\ now\n\tthen $HOME\n"
        try await withPrivateHome { folder in
            let empty = try await snippets.items(timeout: 60)
            XCTAssertEqual(empty.items, [])

            let new = try await action("new", of: snippets)
            let form = try await snippets.form(new, item: nil, timeout: 60)
            var draft = FormDraft(form: form)
            draft.set("Hello", for: "title")
            draft.set(text, for: "content")
            _ = try await snippets.submit(new, item: nil, draft: draft, timeout: 60)
            let run = try self.read("selected", in: folder).trimmingCharacters(in: .newlines)

            let lines = try await snippets.items(timeout: 60)
            XCTAssertEqual(lines.errors, [])
            let item = try XCTUnwrap(lines.items.first)
            XCTAssertEqual(item.run, run)
            XCTAssertEqual(item.title, "Hello")
            XCTAssertEqual(item.subtitle, "Say \"héllo\" \\ now then $HOME ")

            try await snippets.perform("press", input: "input.item=\(item.run)\n", timeout: 60)
            XCTAssertEqual(try self.read("clipboard", in: folder), text)

            let edit = try await action("edit", of: snippets)
            let filled = try await snippets.form(edit, item: item, timeout: 60)
            XCTAssertEqual(filled.fields.map(\.value), ["Hello", text])
            var changed = FormDraft(form: filled)
            changed.set("Changed", for: "title")
            _ = try await snippets.submit(edit, item: item, draft: changed, timeout: 60)
            let edited = try await snippets.items(timeout: 60).items
            XCTAssertEqual(edited.map(\.title), ["Changed"])

            try "before".write(to: folder.appendingPathComponent("clipboard"), atomically: true, encoding: .utf8)
            try await snippets.perform("paste", input: "input.item=\(item.run)\n", timeout: 60)
            XCTAssertEqual(try self.read("pasted", in: folder), text)
            XCTAssertEqual(try self.read("clipboard", in: folder), "before")
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("direct").path))

            try await snippets.perform("delete", input: "input.item=\(item.run)\n", timeout: 60)
            let gone = try await snippets.items(timeout: 60).items
            XCTAssertEqual(gone, [])
        }
    }

    func testACopyOfAMissingSnippetFails() async throws {
        let snippets = try XCTUnwrap(try scan.spots.first { $0.name == "Snippets" })
        try await withPrivateHome { _ in
            do {
                try await snippets.perform("press", input: "input.item=gone\n", timeout: 60)
                XCTFail("expected a failure")
            } catch let error as SpotError {
                XCTAssertEqual(error.reason, "This snippet is gone.")
            }
        }
    }
}
