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
        XCTAssertEqual(scan.commands.map(\.name), ["Apps", "Caffeinate", "Color picker", "Files", "Links", "Overview", "Screenshot", "Pull requests", "Snippets", "Translate", "Plugins"])
        XCTAssertEqual(scan.commands.map(\.key?.name), ["a", "c", "o", "f", "l", nil, "v", "g", "n", "t", "p"])
    }

    func testNoMetricShowsTwiceInTheGrid() throws {
        let places = try scan.commands.flatMap(\.places)

        XCTAssertEqual(places.count, Set(places).count)
    }

    func testTheSpotsFitThePanelWithNoScrolling() throws {
        let placements = SpotGrid().place(try scan.commands.map(\.size))
        let rows = placements.map { $0.row + $0.size.rows }.max()

        XCTAssertEqual(rows, 6)
    }

    func testEveryMetricPrintsAValue() async throws {
        let metrics = try scan.metrics
        try await withPrivateHome { _ in
            for metric in metrics {
                _ = try await metric.read(timeout: 10)
                XCTAssertTrue(FileManager.default.isExecutableFile(atPath: metric.url.path), metric.id)
            }
        }
    }

    func testTheCPUTrendGrowsWithEachRead() async throws {
        let cpu = try XCTUnwrap(try scan.metrics.first { $0.id == "cpu" })

        let first = try await cpu.read(timeout: 10).points?.count ?? 0
        let second = try await cpu.read(timeout: 10).points?.count ?? 0

        XCTAssertGreaterThanOrEqual(second, min(first + 1, 30))
    }

    func testTheCPUTrendSurvivesABadHistoryAndAShortPath() async throws {
        let cpu = try XCTUnwrap(try scan.metrics.first { $0.id == "cpu" })
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-cpu-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "5\n\nnonsense\n7\n".write(to: folder.appendingPathComponent("openspot-cpu"), atomically: true, encoding: .utf8)
        let environment = ProcessInfo.processInfo.environment
        setenv("TMPDIR", folder.path + "/", 1)
        setenv("PATH", "/usr/bin:/bin", 1)
        defer {
            if let tmp = environment["TMPDIR"] { setenv("TMPDIR", tmp, 1) } else { unsetenv("TMPDIR") }
            if let path = environment["PATH"] { setenv("PATH", path, 1) }
            try? FileManager.default.removeItem(at: folder)
        }

        let points = try await cpu.read(timeout: 10).points

        XCTAssertEqual(points?.prefix(2), [5, 7])
        XCTAssertEqual(points?.count, 3)
    }

    func testEveryCommandCanBeRun() throws {
        for command in try scan.commands where command.kind != .widget {
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
        XCTAssertEqual(lines.pick, .close)
        XCTAssertEqual(lines.primary, "Select")
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

        let toast = try await caffeinate.perform(.item(SpotItem(title: "1 minute", run: "60")), timeout: 5)
        XCTAssertEqual(toast, "Caffeinate is on for 1 minute")
        let started = try await caffeinate.state(timeout: 5)
        let first = try await caffeinate.items(timeout: 5).items.first
        XCTAssertEqual(started.on, true)
        XCTAssertEqual(first?.run, "off")

        let stopToast = try await caffeinate.perform(.item(try XCTUnwrap(first)), timeout: 5)
        XCTAssertEqual(stopToast, "Caffeinate is off")
        let stopped = try await caffeinate.state(timeout: 5)
        XCTAssertEqual(stopped.on, false)
    }

    func testLinksComeBeforeAppsInTheMainSearch() throws {
        let links = try XCTUnwrap(try scan.commands.first { $0.name == "Links" })
        let apps = try XCTUnwrap(try scan.commands.first { $0.name == "Apps" })

        XCTAssertLessThan(links.rank, apps.rank)
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
            ("gh", Self.fakeGh(answer: folder.appendingPathComponent("gh-answer").path)),
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

    /// Answers a query with the saved answer, or else with one pull request in each state.
    private static func fakeGh(answer: String) -> String {
        """
        [ -f '\(answer)' ] && { cat '\(answer)'; exit 0; }
        cat <<'END'
        {"data":{
          "mine":{"nodes":[
            {"title":"Fix \\\\ \\"tray\\"","url":"https://github.test/a/1","repository":{"name":"a"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"FAILURE"}}}]}},
            {"title":"Live mode","url":"https://github.test/a/2","repository":{"name":"a"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING"}}}]}},
            {"title":"Docs","url":"https://github.test/a/3","repository":{"name":"a"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS"}}}]}}
          ]},
          "asked":{"nodes":[
            {"title":"Live mode","url":"https://github.test/a/2","repository":{"name":"a"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING"}}}]}},
            {"title":"Review me","url":"https://github.test/b/4","repository":{"name":"b"},"commits":{"nodes":[{"commit":{"statusCheckRollup":null}}]}}
          ]}
        }}
        END
        """
    }

    func testPullRequestsCountEachStateAndOfferEachOne() async throws {
        let scan = try scan
        let metric = try XCTUnwrap(scan.metrics.first { $0.id == "pulls" })
        let list = try XCTUnwrap(scan.commands.first { $0.id == "pulls" })
        try await withPrivateHome { folder in
            let value = try await metric.read(timeout: 5)
            let lines = try await list.items(timeout: 5)

            XCTAssertEqual(value.title, "4")
            XCTAssertEqual(value.rows?.map(\.tone), [.bad, .warn, .good, nil])
            XCTAssertEqual(value.rows?.first?.title, "Fix \\ \"tray\"")
            XCTAssertEqual(lines.errors, [])
            XCTAssertEqual(lines.items.map(\.run), (1...3).map { "https://github.test/a/\($0)" } + ["https://github.test/b/4"])
            XCTAssertEqual(lines.items.last?.subtitle, "No checks · To review · b")
            XCTAssertTrue(metric.isTray)
            XCTAssertEqual(list.id, metric.id)

            let item = try XCTUnwrap(lines.items.first)
            try await list.perform(.item(item), timeout: 5)
            XCTAssertEqual(try self.read("opened", in: folder), item.run + "\n")
            try await list.perform(.action(try await self.action("copy", of: list), item: item), timeout: 5)
            XCTAssertEqual(try self.read("clipboard", in: folder), item.run)
        }
    }

    func testPullRequestsHideWhenThereAreNone() async throws {
        let metric = try XCTUnwrap(try scan.metrics.first { $0.id == "pulls" })
        try await withPrivateHome { folder in
            try #"{"data":{"mine":{"nodes":[]},"asked":{"nodes":[]}}}"#.write(to: folder.appendingPathComponent("gh-answer"), atomically: true, encoding: .utf8)

            let value = try await metric.read(timeout: 5)

            XCTAssertTrue(value.isHidden)
        }
    }

    func testAgentsShowInTheMenuBar() throws {
        XCTAssertEqual(try scan.metrics.filter(\.isTray).map(\.id), ["agents", "pulls"])
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
        let new = try await action("new", of: links)
        var draft = FormDraft(form: try await links.form(new, item: nil, timeout: 5))
        draft.set("Site", for: "title")
        draft.set(url, for: "url")
        _ = try await links.submit(new, item: nil, draft: draft, timeout: 5)
    }

    func testLinksShowsTheIconASiteNamesOnItsPage() async throws {
        let links = try XCTUnwrap(try scan.commands.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            try await self.savedLink("https://icons.test/deep/page", in: links)
            let expected = folder.appendingPathComponent(".config/openspot/data/icons/icons.test.icon").path

            for _ in 0..<50 where !FileManager.default.fileExists(atPath: expected) {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            let items = try await links.items(timeout: 5).items
            let site = items.first { $0.title == "Site" }

            XCTAssertEqual(site?.image, expected)
            XCTAssertEqual(site?.subtitle, "icons.test")
        }
    }

    func testLinksKeepsItsGlyphAndDoesNotAskAgainWhenASiteHasNoIcon() async throws {
        let links = try XCTUnwrap(try scan.commands.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            try await self.savedLink("https://none.test", in: links)
            let marker = folder.appendingPathComponent(".config/openspot/data/icons/none.test.none").path

            for _ in 0..<50 where !FileManager.default.fileExists(atPath: marker) {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            let before = try self.read("fetched", in: folder)
            let items = try await links.items(timeout: 5).items
            let site = items.first { $0.title == "Site" }
            try await Task.sleep(nanoseconds: 500_000_000)

            XCTAssertNil(site?.image)
            XCTAssertEqual(site?.symbol, "link")
            XCTAssertEqual(try self.read("fetched", in: folder), before)
        }
    }

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

            XCTAssertTrue(FileManager.default.fileExists(atPath: config.appendingPathComponent("data/snippets.json").path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent(".config").path))
        }
    }

    /// Reads a script to find the action that it prints.
    private func action(_ id: String, of command: PluginCommand) async throws -> CommandAction {
        let actions = try await command.items(timeout: 5).actions
        return try XCTUnwrap(actions.first { $0.id == id })
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

    func testLinksCompletesALinkAndOpensAndCopiesIt() async throws {
        let links = try XCTUnwrap(try scan.commands.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            let new = try await action("new", of: links)
            var draft = FormDraft(form: try await links.form(new, item: nil, timeout: 5))
            draft.set("Docs", for: "title")
            draft.set(" github.com/a/b ", for: "url")
            _ = try await links.submit(new, item: nil, draft: draft, timeout: 5)

            let saved = try await links.items(timeout: 5).items
            let item = try XCTUnwrap(saved.first { $0.title == "Docs" })
            XCTAssertEqual(item.subtitle, "github.com")
            XCTAssertEqual(item.hides, ["reveal"])

            try await links.perform(.item(item), timeout: 5)
            XCTAssertEqual(try self.read("opened", in: folder), "https://github.com/a/b\n")

            try await links.perform(.action(try await self.action("copy", of: links), item: item), timeout: 5)
            XCTAssertEqual(try self.read("clipboard", in: folder), "https://github.com/a/b")
        }
    }

    func testLinksRefusesALinkWithSpaces() async throws {
        let links = try XCTUnwrap(try scan.commands.first { $0.name == "Links" })
        try await withPrivateHome { _ in
            let new = try await action("new", of: links)
            var draft = FormDraft(form: try await links.form(new, item: nil, timeout: 5))
            draft.set("Bad", for: "title")
            draft.set("not a link", for: "url")
            do {
                _ = try await links.submit(new, item: nil, draft: draft, timeout: 5)
                XCTFail("expected a failure")
            } catch let error as PluginError {
                XCTAssertEqual(error.reason, "Enter a link with no spaces, or a path.")
            }
        }
    }

    func testLinksStartWithTheFolderShortcuts() async throws {
        let links = try XCTUnwrap(try scan.commands.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            let items = try await links.items(timeout: 5).items

            XCTAssertEqual(items.map(\.title), ["Downloads", "Screenshots"])
            XCTAssertEqual(items.first?.subtitle, "~/Downloads")
            XCTAssertEqual(items.first?.file, folder.path + "/Downloads")
            XCTAssertNil(items.first?.hides)
        }
    }

    func testLinksKeepsItsListAfterEachShortcutIsDeleted() async throws {
        let links = try XCTUnwrap(try scan.commands.first { $0.name == "Links" })
        try await withPrivateHome { _ in
            let delete = try await self.action("delete", of: links)
            for item in try await links.items(timeout: 5).items {
                try await links.perform(.action(delete, item: item), timeout: 5)
            }

            let items = try await links.items(timeout: 5).items

            XCTAssertEqual(items, [])
        }
    }

    func testSavedQuicklinksMoveToLinks() async throws {
        let links = try XCTUnwrap(try scan.commands.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            let data = folder.appendingPathComponent(".config/openspot/data")
            try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
            let old = data.appendingPathComponent("quicklinks.json")
            try #"[{"id":"1","title":"Docs","url":"https://docs.test"}]"#.write(to: old, atomically: true, encoding: .utf8)

            let items = try await links.items(timeout: 5).items

            XCTAssertEqual(items.map(\.title), ["Docs", "Downloads", "Screenshots"])
            XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        }
    }

    func testLinksOpensAFolderAndKeepsSpacesInItsPath() async throws {
        let links = try XCTUnwrap(try scan.commands.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            let place = folder.appendingPathComponent("My Work")
            try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
            let new = try await self.action("new", of: links)
            var draft = FormDraft(form: try await links.form(new, item: nil, timeout: 5))
            draft.set("Work", for: "title")
            draft.set("~/My Work", for: "url")
            let run = try await links.submit(new, item: nil, draft: draft, timeout: 5)
            let all = try await links.items(timeout: 5).items
            let item = try XCTUnwrap(all.first { $0.run == run })

            try await links.perform(.item(item), timeout: 5)

            XCTAssertEqual(item.file, place.path)
            XCTAssertEqual(try self.read("opened", in: folder), place.path + "\n")
        }
    }

    func testLinksSaysWhenAFolderIsGone() async throws {
        let links = try XCTUnwrap(try scan.commands.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            let downloads = try await links.items(timeout: 5).items.first { $0.title == "Downloads" }
            do {
                try await links.perform(.item(try XCTUnwrap(downloads)), timeout: 5)
                XCTFail("expected a failure")
            } catch let error as PluginError {
                XCTAssertEqual(error.reason, "Cannot find \(folder.path)/Downloads.")
            }
        }
    }

    func testLinksShowsAFolderInFinder() async throws {
        let links = try XCTUnwrap(try scan.commands.first { $0.name == "Links" })
        try await withPrivateHome { folder in
            try FileManager.default.createDirectory(at: folder.appendingPathComponent("Downloads"), withIntermediateDirectories: true)
            let downloads = try await links.items(timeout: 5).items.first { $0.title == "Downloads" }

            try await links.perform(.action(try await self.action("reveal", of: links), item: downloads), timeout: 5)

            XCTAssertEqual(try self.read("opened", in: folder), "-R\n")
        }
    }

    /// Runs the color picker with a stand-in for the app, which prints this answer to its helper call.
    private func pickColor(answer: String, in folder: URL) async throws -> String? {
        let app = folder.appendingPathComponent("fake-app")
        try "#!/bin/sh\n[ \"$1\" = --pick-color ] && printf '%s' '\(answer)'\n".write(to: app, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: app.path)
        let picker = try XCTUnwrap(try scan.commands.first { $0.name == "Color picker" })
        let output = try await PluginRun(url: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "OPENSPOT_APP='\(app.path)' '\(picker.url.path)'"], timeout: 5).output()
        return PluginOutput(text: output).summary?.value("toast")
    }

    func testTheColorPickerCopiesAPickAndNothingOnACancel() async throws {
        try await withPrivateHome { folder in
            let picked = try await self.pickColor(answer: "#0080FF", in: folder)
            XCTAssertEqual(picked, "Copied #0080FF")
            XCTAssertEqual(try self.read("clipboard", in: folder), "#0080FF")

            try FileManager.default.removeItem(at: folder.appendingPathComponent("clipboard"))
            let cancelled = try await self.pickColor(answer: "", in: folder)
            XCTAssertNil(cancelled)
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("clipboard").path))
        }
    }

    func testTranslateCopiesARowAndOpensTheSettingsForAMissingLanguage() async throws {
        let translate = try XCTUnwrap(try scan.commands.first { $0.name == "Translate" })
        try await withPrivateHome { folder in
            let empty = try await translate.items(timeout: 5)
            XCTAssertEqual(empty.items, [])
            XCTAssertEqual(empty.primary, "Copy")

            let toast = try await translate.perform(.item(SpotItem(title: "Привет", run: "Привет")), timeout: 5)
            XCTAssertEqual(toast, "Copied")
            XCTAssertEqual(try self.read("clipboard", in: folder), "Привет")

            let silent = try await translate.perform(.item(SpotItem(title: "Add", run: ":settings:ru")), timeout: 5)
            XCTAssertNil(silent)
            XCTAssertTrue(try self.read("opened", in: folder).contains("Localization-Settings"))
        }
    }

    func testAppsAndFilesOfferToShowInFinder() async throws {
        for name in ["Apps", "Files"] {
            let command = try XCTUnwrap(try scan.commands.first { $0.name == name })
            let actions = try await command.items(timeout: 10).actions
            XCTAssertEqual(actions.first?.id, "reveal", name)
        }
    }
}
