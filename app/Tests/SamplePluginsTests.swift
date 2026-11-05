import XCTest
@testable import OpenspotCore

final class SamplePluginsTests: XCTestCase {
    private var scan: ScanResult {
        get throws {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            return try PluginFolder(url: root.appendingPathComponent("plugins")).scan()
        }
    }

    func testTheFolderHoldsEveryCommandAndRefusesNone() throws {
        let scan = try scan

        XCTAssertEqual(scan.refused, [])
        XCTAssertEqual(scan.commands.map(\.name), ["Apps", "Caffeinate", "Files", "Downloads", "Screenshots", "Paste Screenshot", "Quicklinks", "Snippets"])
        XCTAssertEqual(scan.commands.map(\.key?.name), ["a", "c", "f", "d", "s", "v", "l", "n"])
    }

    func testOnePluginHoldsSeveralCommands() throws {
        let folders = try XCTUnwrap(try scan.plugins.first { $0.name == "Folders" })

        XCTAssertEqual(folders.commands.map(\.name), ["Downloads", "Screenshots"])
    }

    func testEveryCommandCanBeRun() throws {
        for command in try scan.commands {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: command.url.path), command.name)
        }
    }

    func testCaffeinateReportsIfItIsOnAndOffersItsDurations() async throws {
        let caffeinate = try XCTUnwrap(try scan.commands.first { $0.name == "Caffeinate" })

        let state = try await caffeinate.state(timeout: 5)
        let lines = try await caffeinate.items(timeout: 5)

        XCTAssertEqual(state.title, "Caffeinate")
        XCTAssertNotNil(state.on)
        XCTAssertEqual(lines.items.map(\.run).filter { $0 != "off" }, ["1800", "3600", "7200", "0"])
        XCTAssertEqual(lines.errors, [])
        XCTAssertEqual(caffeinate.pick, .close)
        XCTAssertFalse(caffeinate.keepsRecent)
    }

    func testCaffeinateOffersTurnOffFirstAndStopsOnIt() async throws {
        let caffeinate = try XCTUnwrap(try scan.commands.first { $0.name == "Caffeinate" })
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-caffeinate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let before = ProcessInfo.processInfo.environment["TMPDIR"]
        setenv("TMPDIR", folder.path + "/", 1)
        defer {
            if let before { setenv("TMPDIR", before, 1) } else { unsetenv("TMPDIR") }
            try? FileManager.default.removeItem(at: folder)
        }

        try await caffeinate.perform(.item(SpotItem(title: "1 minute", run: "60")), timeout: 5)
        let started = try await caffeinate.state(timeout: 5)
        let first = try await caffeinate.items(timeout: 5).items.first
        XCTAssertEqual(started.on, true)
        XCTAssertEqual(first?.run, "off")

        try await caffeinate.perform(.item(try XCTUnwrap(first)), timeout: 5)
        let stopped = try await caffeinate.state(timeout: 5)
        XCTAssertEqual(stopped.on, false)
    }

    func testAppsListsEachAppWithItsPathAndNoBadLine() async throws {
        let apps = try XCTUnwrap(try scan.commands.first { $0.name == "Apps" })

        let lines = try await apps.items(timeout: 10)
        let finder = try XCTUnwrap(lines.items.first { $0.title == "Finder" })

        XCTAssertEqual(lines.errors, [])
        XCTAssertEqual(finder.run, "/System/Library/CoreServices/Finder.app")
        XCTAssertEqual(finder.file, finder.run)
        XCTAssertTrue(apps.isGlobal)
        XCTAssertGreaterThan(lines.items.filter { $0.run.hasPrefix("/System/Applications/") }.count, 5)
    }

    func testFilesIsLiveAndGivesNothingForATooShortSearch() async throws {
        let files = try XCTUnwrap(try scan.commands.first { $0.name == "Files" })

        let lines = try await files.items(query: "a", timeout: 5)

        XCTAssertEqual(files.search, .live)
        XCTAssertEqual(lines.items, [])
    }

    /// Runs with an empty home and with fake clipboard and open tools, so a test touches nothing of the person's.
    private func withPrivateHome(_ body: (URL) async throws -> Void) async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-home-\(UUID().uuidString)")
        let tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        for (name, script) in [
            ("pbcopy", "cat > '\(folder.path)/clipboard'"),
            ("pbpaste", "cat '\(folder.path)/clipboard' 2>/dev/null"),
            ("open", "echo \"$1\" > '\(folder.path)/opened'"),
            ("curl", Self.fakeCurl(log: folder.appendingPathComponent("fetched").path)),
            ("osascript", "cp '\(folder.path)/clipboard' '\(folder.path)/pasted'")
        ] {
            let tool = tools.appendingPathComponent(name)
            try "#!/bin/sh\n\(script)\n".write(to: tool, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tool.path)
        }
        let home = ProcessInfo.processInfo.environment["HOME"]
        let path = ProcessInfo.processInfo.environment["PATH"]
        setenv("HOME", folder.path, 1)
        setenv("PATH", "\(tools.path):/usr/bin:/bin", 1)
        defer {
            if let home { setenv("HOME", home, 1) }
            if let path { setenv("PATH", path, 1) }
            try? FileManager.default.removeItem(at: folder)
        }
        try await body(folder)
    }

    /// A web with one site: icons.test names a small image on its page, and each other site has no image at all.
    private static func fakeCurl(log: String) -> String {
        """
        out=""
        for a; do
          [ "$previous" = "-o" ] && out=$a
          previous=$a
          url=$a
        done
        echo "$url" >> '\(log)'
        case "$url" in
          https://icons.test/)
            echo '<head><link href="/a.png" rel="icon"></head>'
            ;;
          https://icons.test/a.png)
            echo 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' | base64 -D > "$out"
            printf 'image/png'
            ;;
          *)
            exit 22
            ;;
        esac
        """
    }

    private func savedLink(_ url: String, in links: PluginCommand) async throws {
        let new = try action("new", of: links)
        var draft = FormDraft(form: try await links.form(new, item: nil, timeout: 5))
        draft.set("Site", for: "title")
        draft.set(url, for: "url")
        _ = try await links.submit(new, item: nil, draft: draft, timeout: 5)
    }

    func testQuicklinksShowsTheIconASiteNamesOnItsPage() async throws {
        let links = try XCTUnwrap(try scan.commands.first { $0.name == "Quicklinks" })
        try await withPrivateHome { folder in
            try await self.savedLink("https://icons.test/deep/page", in: links)
            let expected = folder.appendingPathComponent(".config/openspot/data/icons/icons.test.icon").path

            for _ in 0..<50 where !FileManager.default.fileExists(atPath: expected) {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            let items = try await links.items(timeout: 5).items

            XCTAssertEqual(items.first?.image, expected)
            XCTAssertEqual(items.first?.subtitle, "icons.test")
        }
    }

    func testQuicklinksKeepsItsGlyphAndDoesNotAskAgainWhenASiteHasNoIcon() async throws {
        let links = try XCTUnwrap(try scan.commands.first { $0.name == "Quicklinks" })
        try await withPrivateHome { folder in
            try await self.savedLink("https://none.test", in: links)
            let marker = folder.appendingPathComponent(".config/openspot/data/icons/none.test.none").path

            for _ in 0..<50 where !FileManager.default.fileExists(atPath: marker) {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            let before = try self.read("fetched", in: folder)
            let items = try await links.items(timeout: 5).items
            try await Task.sleep(nanoseconds: 500_000_000)

            XCTAssertNil(items.first?.image)
            XCTAssertEqual(items.first?.symbol, "link")
            XCTAssertEqual(try self.read("fetched", in: folder), before)
        }
    }

    func testAConfigPathHoldsTheDataOfAPlugin() async throws {
        let snippets = try XCTUnwrap(try scan.commands.first { $0.name == "Snippets" })
        try await withPrivateHome { folder in
            let config = folder.appendingPathComponent("debug-config")
            setenv("OPENSPOT_CONFIG", config.path, 1)
            defer { unsetenv("OPENSPOT_CONFIG") }
            let new = try self.action("new", of: snippets)
            var draft = FormDraft(form: try await snippets.form(new, item: nil, timeout: 5))
            draft.set("A", for: "title")
            draft.set("B", for: "content")

            _ = try await snippets.submit(new, item: nil, draft: draft, timeout: 5)

            XCTAssertTrue(FileManager.default.fileExists(atPath: config.appendingPathComponent("data/snippets.json").path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent(".config").path))
        }
    }

    private func action(_ id: String, of command: PluginCommand) throws -> CommandAction {
        try XCTUnwrap(command.actions.first { $0.id == id })
    }

    private func read(_ name: String, in folder: URL) throws -> String {
        try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
    }

    func testSnippetsKeepsExactTextThroughNewCopyEditPasteAndDelete() async throws {
        let snippets = try XCTUnwrap(try scan.commands.first { $0.name == "Snippets" })
        let text = "Say \"héllo\" \\ now\n\tthen $HOME\n"
        try await withPrivateHome { folder in
            let empty = try await snippets.items(timeout: 5)
            XCTAssertEqual(empty.items, [])

            let new = try action("new", of: snippets)
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

            let edit = try action("edit", of: snippets)
            let filled = try await snippets.form(edit, item: item, timeout: 5)
            XCTAssertEqual(filled.fields.map(\.value), ["Hello", text])
            var changed = FormDraft(form: filled)
            changed.set("Changed", for: "title")
            _ = try await snippets.submit(edit, item: item, draft: changed, timeout: 5)
            let edited = try await snippets.items(timeout: 5).items
            XCTAssertEqual(edited.map(\.title), ["Changed"])

            try "before".write(to: folder.appendingPathComponent("clipboard"), atomically: true, encoding: .utf8)
            try await snippets.perform(.action(try self.action("paste", of: snippets), item: item), timeout: 5)
            XCTAssertEqual(try self.read("pasted", in: folder), text)
            XCTAssertEqual(try self.read("clipboard", in: folder), "before")

            try await snippets.perform(.action(try self.action("delete", of: snippets), item: item), timeout: 5)
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

    func testQuicklinksCompletesALinkAndOpensAndCopiesIt() async throws {
        let links = try XCTUnwrap(try scan.commands.first { $0.name == "Quicklinks" })
        try await withPrivateHome { folder in
            let new = try action("new", of: links)
            var draft = FormDraft(form: try await links.form(new, item: nil, timeout: 5))
            draft.set("Docs", for: "title")
            draft.set(" github.com/a/b ", for: "url")
            _ = try await links.submit(new, item: nil, draft: draft, timeout: 5)

            let saved = try await links.items(timeout: 5).items
            let item = try XCTUnwrap(saved.first)
            XCTAssertEqual(item.subtitle, "github.com")

            try await links.perform(.item(item), timeout: 5)
            XCTAssertEqual(try self.read("opened", in: folder), "https://github.com/a/b\n")

            try await links.perform(.action(try self.action("copy", of: links), item: item), timeout: 5)
            XCTAssertEqual(try self.read("clipboard", in: folder), "https://github.com/a/b")
        }
    }

    func testQuicklinksRefusesALinkWithSpaces() async throws {
        let links = try XCTUnwrap(try scan.commands.first { $0.name == "Quicklinks" })
        try await withPrivateHome { _ in
            let new = try action("new", of: links)
            var draft = FormDraft(form: try await links.form(new, item: nil, timeout: 5))
            draft.set("Bad", for: "title")
            draft.set("not a link", for: "url")
            do {
                _ = try await links.submit(new, item: nil, draft: draft, timeout: 5)
                XCTFail("expected a failure")
            } catch let error as PluginError {
                XCTAssertEqual(error.reason, "Enter a link with no spaces.")
            }
        }
    }

    func testAppsAndFilesOfferToShowInFinder() throws {
        for name in ["Apps", "Files"] {
            let command = try XCTUnwrap(try scan.commands.first { $0.name == name })
            XCTAssertEqual(command.actions.first?.id, "reveal", name)
        }
    }
}
