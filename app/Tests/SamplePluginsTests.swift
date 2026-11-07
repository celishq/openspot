import XCTest
@testable import OpenspotCore

final class SamplePluginsTests: XCTestCase {
    private var scan: ScanResult {
        get throws {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            let folder = root.appendingPathComponent("plugins")
            let shipped = ShippedSpot.commands(folder: folder, guide: root.appendingPathComponent("app/Shell/GUIDE.md"), app: "")
            return try PluginFolder(url: folder).scan(shipped: shipped)
        }
    }

    func testTheFolderHoldsEveryCommandAndRefusesNone() throws {
        let scan = try scan

        XCTAssertEqual(scan.refused, [])
        XCTAssertEqual(scan.commands.map(\.name), ["Translate", "Apps", "Caffeinate", "Color picker", "Confetti", "Emoji", "Files", "Links", "Overview", "Screenshot", "Pull requests", "Snippets", "Windows", "Spots", "Settings", "Build"])
        XCTAssertEqual(scan.commands.map(\.key?.name), ["t", "a", "c", "o", "k", "e", "f", "l", nil, "v", "g", "n", nil, "p", nil, nil])
    }

    func testACopyAsksForTheCopiedToast() throws {
        let plugins = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("plugins")
        let tools = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-copy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tools) }
        try "#!/bin/sh\ncat >/dev/null\n".writeScript(to: tools.appendingPathComponent("pbcopy"))
        for (script, call) in [("emoji.sh", "open"), ("files.sh", "copy"), ("pulls.sh", "copy")] {
            let process = Process()
            let out = Pipe()
            process.executableURL = plugins.appendingPathComponent(script)
            process.arguments = [call, "x"]
            process.environment = ["PATH": "\(tools.path):/usr/bin:/bin", "OPENSPOT_DATA": tools.path, "HOME": tools.path]
            process.standardOutput = out
            try process.run()
            process.waitUntilExit()
            let text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTAssertEqual(text, "toast=Copied\n", script)
        }
    }

    func testConfettiStaysOffTheGridAndItsSourceTypeChecks() async throws {
        let confetti = try XCTUnwrap(try scan.commands.first { $0.id == "confetti" })
        XCTAssertFalse(confetti.isOnGrid)
        XCTAssertEqual(confetti.symbol, "party.popper")

        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-typecheck", confetti.url.path])
    }

    func testNoMetricShowsTwiceInTheGrid() throws {
        let places = try scan.commands.flatMap(\.places)

        XCTAssertEqual(places.count, Set(places).count)
    }

    func testTheSpotsFitThePanelWithNoScrolling() throws {
        let placements = SpotGrid().place(try scan.commands.filter(\.isOnGrid).map(\.size))
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

    func testTheCheckFindsNoFaultInTheFolder() async throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        try await withPrivateHome { folder in
            try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("tools/openspot"))
            let faults = await PluginCheck(folder: PluginFolder(url: root.appendingPathComponent("plugins"))).faults()

            XCTAssertEqual(faults, [])
        }
    }

    /// The frame that Windows gives a slot, on an area at 0 25 with a size of 1200 by 900.
    private func windowFrame(_ slot: String, from window: String) async throws -> String {
        let command = try XCTUnwrap(try scan.scripts.first { $0.name == "Windows" })
        let words = ["frame", slot, "0", "25", "1200", "900"] + window.split(separator: " ").map(String.init)
        let answer = try await SpotRuns().answer(of: command, SpotAction(arguments: words))
        return answer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func testWindowsListsItsCommandsAndHoldsNoKey() throws {
        let command = try XCTUnwrap(try scan.scripts.first { $0.name == "Windows" })

        XCTAssertEqual(command.offers.map(\.id), ["full", "center", "left", "right"])
        XCTAssertNil(command.key)
    }

    func testWindowsFillsTheAreaAndCentresAt65Percent() async throws {
        let window = "100 100 400 300"

        let full = try await windowFrame("full", from: window)
        let center = try await windowFrame("center", from: window)

        XCTAssertEqual(full, "0 25 1200 900")
        XCTAssertEqual(center, "210 183 780 585")
    }

    func testWindowsRotatesASideThroughItsSizes() async throws {
        let first = try await windowFrame("left", from: "100 100 400 300")
        let second = try await windowFrame("left", from: first)
        let third = try await windowFrame("left", from: second)
        let fourth = try await windowFrame("left", from: third)
        XCTAssertEqual([first, second, third, fourth], ["0 25 300 900", "0 25 400 900", "0 25 600 900", "0 25 300 900"])

        let right = try await windowFrame("right", from: "100 100 400 300")
        let nextRight = try await windowFrame("right", from: right)
        XCTAssertEqual([right, nextRight], ["900 25 300 900", "800 25 400 900"])
    }

    func testWindowsStillRotatesAWindowThatKeepsItsOwnSize() async throws {
        let wide = try await windowFrame("left", from: "0 25 350 900")
        let rounded = try await windowFrame("left", from: "0 25 392 890")

        XCTAssertEqual(wide, "0 25 400 900")
        XCTAssertEqual(rounded, "0 25 600 900")
    }

    func testEveryCommandCanBeRun() throws {
        for command in try scan.commands where command.kind != .widget && command.shipped == nil {
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
        XCTAssertFalse(lines.keepsRecent)
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

    func testCaffeinateMovesItsRecordIntoPlace() async throws {
        let caffeinate = try XCTUnwrap(try scan.commands.first { $0.name == "Caffeinate" })
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-record-\(UUID().uuidString)")
        let tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        let log = folder.appendingPathComponent("moved")
        let move = tools.appendingPathComponent("mv")
        try "#!/bin/sh\necho \"$2\" >> '\(log.path)'\nexec /bin/mv \"$@\"\n".writeScript(to: move)
        let before = ProcessInfo.processInfo.environment
        setenv("TMPDIR", folder.path, 1)
        setenv("PATH", "\(tools.path):/usr/bin:/bin", 1)
        defer {
            if let tmp = before["TMPDIR"] { setenv("TMPDIR", tmp, 1) } else { unsetenv("TMPDIR") }
            if let path = before["PATH"] { setenv("PATH", path, 1) }
            try? FileManager.default.removeItem(at: folder)
        }

        try await caffeinate.perform(.item(SpotItem(title: "1 minute", run: "60")), timeout: 5)
        let moved = try? String(contentsOf: log, encoding: .utf8)
        let started = try await caffeinate.state(timeout: 5)
        try await caffeinate.perform(.item(SpotItem(title: "Turn off", run: "off")), timeout: 5)

        XCTAssertEqual(moved, folder.appendingPathComponent("openspot-caffeinate").path + "\n")
        XCTAssertEqual(started.on, true)
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

    func testScreenshotCopiesTheNewestCaptureAndAVideoAsAFile() throws {
        let plugins = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("plugins")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-capture-\(UUID().uuidString)")
        let tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let image = folder.appendingPathComponent("Screenshot.png")
        let video = folder.appendingPathComponent("Screen Recording.mov")
        let log = folder.appendingPathComponent("osascript")
        try "#!/bin/sh\necho '\(folder.path)'\n".writeScript(to: tools.appendingPathComponent("defaults"))
        try "#!/bin/sh\ncase \"$*\" in *kMDItemScreenCaptureType*) printf '%s\\0%s\\0' '\(image.path)' '\(video.path)' ;; esac\n".writeScript(to: tools.appendingPathComponent("mdfind"))
        try "#!/bin/sh\nprintf '%s\\n' \"$@\" >> '\(log.path)'\n".writeScript(to: tools.appendingPathComponent("osascript"))
        try "#!/bin/sh\n".writeScript(to: tools.appendingPathComponent("sleep"))

        for (newest, older, form) in [(video, image, "NSURL"), (image, video, "PNGf")] {
            try? FileManager.default.removeItem(at: log)
            FileManager.default.createFile(atPath: older.path, contents: Data())
            FileManager.default.createFile(atPath: newest.path, contents: Data())
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -60)], ofItemAtPath: older.path)
            try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: newest.path)
            let process = Process()
            process.executableURL = plugins.appendingPathComponent("paste-screenshot.sh")
            process.environment = ["PATH": "\(tools.path):/usr/bin:/bin", "HOME": folder.path]
            try process.run()
            process.waitUntilExit()
            let calls = (try? String(contentsOf: log, encoding: .utf8)) ?? ""

            XCTAssertEqual(process.terminationStatus, 0, newest.lastPathComponent)
            XCTAssertTrue(calls.contains(newest.path), calls)
            XCTAssertTrue(calls.contains(form), calls)
        }
    }

    func testAFixableFailureLinksItsFix() throws {
        let plugins = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("plugins")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-fix-\(UUID().uuidString)")
        let tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let image = folder.appendingPathComponent("Screenshot.png")
        FileManager.default.createFile(atPath: image.path, contents: Data())
        try "#!/bin/sh\necho '\(folder.path)'\n".writeScript(to: tools.appendingPathComponent("defaults"))
        try "#!/bin/sh\nprintf '%s\\0' '\(image.path)'\n".writeScript(to: tools.appendingPathComponent("mdfind"))
        try "#!/bin/sh\ncase \"$*\" in *keystroke*|*JavaScript*) exit 1 ;; esac\n".writeScript(to: tools.appendingPathComponent("osascript"))
        for name in ["pbcopy", "pbpaste", "sleep"] {
            try "#!/bin/sh\ncat >/dev/null 2>&1 &\n".writeScript(to: tools.appendingPathComponent(name))
        }
        let accessibility = "open=x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\n"

        let paste = "Copied. Press `⌘V`, or allow Openspot in Accessibility.\n"
        for (script, arguments, fix, message) in [
            ("paste-screenshot.sh", [], accessibility, paste),
            ("emoji.sh", ["paste", "x"], accessibility, paste),
            ("windows.sh", ["left"], accessibility, "Allow Openspot in Accessibility, then press the key again.\n")
        ] {
            let process = Process()
            let out = Pipe()
            let errors = Pipe()
            process.executableURL = plugins.appendingPathComponent(script)
            process.arguments = arguments
            process.environment = ["PATH": "\(tools.path):/usr/bin:/bin", "HOME": folder.path, "OPENSPOT_DATA": folder.path]
            process.standardOutput = out
            process.standardError = errors
            try process.run()
            process.waitUntilExit()
            let text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let said = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            XCTAssertEqual(process.terminationStatus, 1, script)
            XCTAssertEqual(text, fix, script)
            XCTAssertEqual(said, message, script)
        }
    }

    func testFilesSearchesItselfAndGivesNothingForATooShortSearch() async throws {
        let files = try XCTUnwrap(try scan.commands.first { $0.name == "Files" })

        let lines = try await files.items(query: "a", timeout: 5)

        XCTAssertEqual(lines.search, .script)
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
            try "#!/bin/sh\n\(script)\n".writeScript(to: tool)
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
            let expected = folder.appendingPathComponent(".config/openspot/data/links/icons/icons.test.icon").path

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
            let marker = folder.appendingPathComponent(".config/openspot/data/links/icons/none.test.none").path

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

            XCTAssertTrue(FileManager.default.fileExists(atPath: config.appendingPathComponent("data/snippets/snippets.json").path))
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
            let data = folder.appendingPathComponent(".config/openspot/data/links")
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

    /// Runs the color picker with a stand-in for the openspot command, which prints this answer.
    private func pickColor(answer: String, in folder: URL) async throws -> String? {
        try "#!/bin/sh\n[ \"$1 $2\" = 'color pick' ] && printf '%s' '\(answer)'\n".writeScript(to: folder.appendingPathComponent("tools/openspot"))
        let picker = try XCTUnwrap(try scan.commands.first { $0.name == "Color picker" })
        return try await picker.perform(picker.click, timeout: 5)
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

    /// Puts a stand-in for the openspot command on the path. It knows two languages and translates to upper case.
    private func fakeTranslate(in folder: URL, status: String? = nil) throws -> PluginCommand {
        let reply = status.map { "printf 'status=\($0)\\nfrom=ru\\nto=en\\n'" } ?? #"""
        case "$text" in *[а-я]*) found=ru ;; *) found=en ;; esac
        [ "$from" = auto ] || found=$from
        written=$(printf %s "$text" | tr a-mo-z A-MO-Z | sed 's/\\/\\\\/g' | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')
        printf 'text=%s\nfrom=%s\n' "$written" "$found"
        """#
        let script = """
        #!/bin/sh
        if [ "$2" = languages ]; then
          printf 'preferred=en\\npreferred=ru\\n\\nlanguage=en\\nname=English\\n\\nlanguage=ru\\nname=Russian\\n'
          exit 0
        fi
        from=$3
        text=$(cat; printf x)
        text=${text%x}
        \(reply)

        """
        let tool = folder.appendingPathComponent("tools/openspot")
        try script.writeScript(to: tool)
        return try XCTUnwrap(try scan.commands.first { $0.name == "Translate" })
    }

    private func text(of id: String, in output: PluginOutput) -> String? {
        output.parts.first { $0.id == id }?.value
    }

    /// Runs a handler through the calls as an open sheet does: one run for each, with the values of the sheet on stdin.
    /// Returns the answer to the last one.
    @MainActor
    private static func drive(_ command: PluginCommand, _ actions: [SpotAction]) async throws -> PluginOutput {
        var last = try await command.items(timeout: 10)
        var panel = try XCTUnwrap(SpotPanel(output: last))
        for action in actions {
            if action.arguments.count == 2 { panel.set(action.arguments[1], of: action.arguments[0]) }
            last = PluginOutput(text: try await SpotRuns().answer(of: command, action, input: panel.values, limit: 30))
            panel.take(last, answering: panel.generation)
        }
        return last
    }

    private func fakeEmoji(in folder: URL) throws -> PluginCommand {
        let script = """
        #!/bin/sh
        printf 'row=thumbs up, %s\\nrun=👍\\nglyph=👍\\n' "$3"

        """
        try script.writeScript(to: folder.appendingPathComponent("tools/openspot"))
        return try XCTUnwrap(try scan.commands.first { $0.name == "Emoji" })
    }

    func testEmojiIsAGridWithItsToneAndNoFaults() async throws {
        try await withPrivateHome { folder in
            let output = try await self.fakeEmoji(in: folder).items(timeout: 10)

            XCTAssertEqual(output.sheetFaults, [])
            XCTAssertEqual(output.perLine, 7)
            XCTAssertEqual(output.items.map(\.title), ["thumbs up, none"])
            XCTAssertEqual(self.text(of: "tone", in: output), "none")
            XCTAssertEqual(output.primary, "Copy")
        }
    }

    func testEmojiKeepsTheToneThatThePersonChooses() async throws {
        try await withPrivateHome { folder in
            let emoji = try self.fakeEmoji(in: folder)

            _ = try await SpotRuns().answer(of: emoji, .set("tone", to: "dark"), input: nil, limit: 30)
            let output = try await emoji.items(timeout: 10)

            XCTAssertEqual(self.text(of: "tone", in: output), "dark")
            XCTAssertEqual(output.items.map(\.title), ["thumbs up, dark"])
        }
    }

    func testEmojiMovesToTheNextToneAndWrapsAround() async throws {
        try await withPrivateHome { folder in
            let emoji = try self.fakeEmoji(in: folder)
            let first = try await emoji.items(timeout: 10)
            let tone = try XCTUnwrap(first.actions.first { $0.id == "next-tone" })
            let row = SpotItem(title: "thumbs up", run: "👍")
            XCTAssertEqual(tone.key, ActionKey(name: "t", isCommand: true))

            _ = try await SpotRuns().answer(of: emoji, .action(tone, item: row), input: nil, limit: 30)
            let next = try await emoji.items(timeout: 10)
            XCTAssertEqual(self.text(of: "tone", in: next), "light")

            _ = try await SpotRuns().answer(of: emoji, .set("tone", to: "dark"), input: nil, limit: 30)
            _ = try await SpotRuns().answer(of: emoji, .action(tone, item: row), input: nil, limit: 30)
            let wrapped = try await emoji.items(timeout: 10)
            XCTAssertEqual(self.text(of: "tone", in: wrapped), "none")
        }
    }

    func testEmojiCopiesThePick() async throws {
        try await withPrivateHome { folder in
            let emoji = try self.fakeEmoji(in: folder)

            _ = try await SpotRuns().answer(of: emoji, .item(SpotItem(title: "thumbs up", run: "👍")), input: nil, limit: 30)

            XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("clipboard"), encoding: .utf8), "👍")
        }
    }

    /// Reads a sheet, and returns how long its first parts took and how many options its target menu ends with.
    @MainActor
    private static func firstParts(of command: PluginCommand) async throws -> (seconds: TimeInterval, options: Int) {
        let sheet = SpotRuns().sheet(for: command)
        let start = Date()
        let options: () -> Int = {
            guard case .menu(let options, _)? = sheet.panel?.parts.first(where: { $0.id == "target" })?.control else { return 0 }
            return options.count
        }
        sheet.open {}
        while sheet.panel == nil, Date().timeIntervalSince(start) < 10 { try await Task.sleep(for: .milliseconds(10)) }
        let seconds = Date().timeIntervalSince(start)
        while options() < 2, Date().timeIntervalSince(start) < 10 { try await Task.sleep(for: .milliseconds(10)) }
        let count = options()
        sheet.close()
        return (seconds, count)
    }

    func testAReadAnswersWithItsFirstFrame() async throws {
        try await withPrivateHome { folder in
            let url = folder.appendingPathComponent("frames.sh")
            try "#!/bin/sh\nprintf 'part=a\\n---\\n'\nprintf 'part=b\\n'\n".writeScript(to: url)

            let text = try await SpotRuns().answer(of: PluginCommand(id: "frames", name: "Frames", url: url), .read, limit: 5)

            XCTAssertEqual(text, "part=a\n")
        }
    }

    func testTranslateShowsItsPartsBeforeItKnowsItsLanguages() async throws {
        try await withPrivateHome { folder in
            _ = try self.fakeTranslate(in: folder)
            let tool = folder.appendingPathComponent("tools/openspot")
            let fake = try String(contentsOf: tool, encoding: .utf8)
            try fake.replacingOccurrences(of: "if [ \"$2\" = languages ]; then", with: "if [ \"$2\" = languages ]; then\n  sleep 1").writeScript(to: tool)
            let translate = try XCTUnwrap(try self.scan.commands.first { $0.name == "Translate" })

            let result = try await Self.firstParts(of: translate)

            XCTAssertLessThan(result.seconds, 1)
            XCTAssertEqual(result.options, 2)
        }
    }

    func testTranslateIsASheetOfPartsWithItsLanguagesAndNoFaults() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)

            let output = try await translate.items(timeout: 10)

            XCTAssertFalse(translate.stays)
            XCTAssertEqual(translate.read, .sheet)
            XCTAssertEqual(translate.kind, .list)
            XCTAssertEqual(output.kind, .list)
            XCTAssertEqual(output.sheetFaults, [])
            XCTAssertEqual(output.layout?.rows.first, ["s", "s", ".", "."])
            XCTAssertEqual(output.parts.map(\.id), ["source", "input", "target", "output", "swap"])
            XCTAssertEqual(self.text(of: "source", in: output), "auto")
            XCTAssertEqual(self.text(of: "target", in: output), "en")
        }
    }

    func testTranslateAnswersTypedTextAndOffersToCopy() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)

            let output = try await Self.drive(translate, [.set("source", to: "ru"), .set("target", to: "en"), .set("input", to: "hi")])

            XCTAssertEqual(self.text(of: "output", in: output), "HI")
            XCTAssertEqual(output.parts.last?.id, "copy")
            XCTAssertEqual(output.parts.last?.key, ActionKey(name: "return", isCommand: true))
        }
    }

    func testTranslateMovesItsTargetWhenTheTextIsAlreadyInIt() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)

            let output = try await Self.drive(translate, [.set("input", to: "hi")])

            XCTAssertEqual(self.text(of: "target", in: output), "ru")
        }
    }

    func testTranslateSwapsTheLanguagesAndTheTexts() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)

            let output = try await Self.drive(translate, [.set("source", to: "ru"), .set("target", to: "en"), .set("input", to: "hi"), .press("swap")])

            XCTAssertEqual(self.text(of: "source", in: output), "en")
            XCTAssertEqual(self.text(of: "target", in: output), "ru")
            XCTAssertEqual(self.text(of: "input", in: output), "HI")
        }
    }

    func testTranslateKeepsTheChosenLanguagesForTheNextRead() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)

            _ = try await Self.drive(translate, [.set("source", to: "en"), .set("target", to: "ru")])
            let output = try await translate.items(timeout: 10)

            XCTAssertEqual(self.text(of: "source", in: output), "en")
            XCTAssertEqual(self.text(of: "target", in: output), "ru")
        }
    }

    func testTranslateLinksToSettingsWhenALanguageIsMissing() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder, status: "missing")

            let output = try await Self.drive(translate, [.set("input", to: "привет")])

            XCTAssertEqual(self.text(of: "output", in: output), "Russian to English is not installed")
            XCTAssertEqual(output.parts.last?.id, "settings")
        }
    }

    func testTranslateCopiesItsOutput() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)

            let output = try await Self.drive(translate, [.set("source", to: "ru"), .set("target", to: "en"), .set("input", to: "one\ntwo"), .press("copy")])

            XCTAssertEqual(output.summary?.value("toast"), "Copied")
            XCTAssertEqual(try self.read("clipboard", in: folder), "OnE\nTWO")
        }
    }

    func testTranslateShowsNoTextOnANewOpenAndKeepsItsLanguages() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)

            _ = try await Self.drive(translate, [.set("source", to: "en"), .set("target", to: "ru"), .set("input", to: "hi")])
            let output = try await translate.items(timeout: 10)

            XCTAssertEqual(self.text(of: "input", in: output), "")
            XCTAssertEqual(self.text(of: "output", in: output), "")
            XCTAssertEqual(self.text(of: "source", in: output), "en")
            XCTAssertEqual(self.text(of: "target", in: output), "ru")
        }
    }

    func testTranslateMovesItsSavedFileIntoPlaceAndLeavesNoTempFile() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)
            let log = folder.appendingPathComponent("moved").path
            let mover = folder.appendingPathComponent("tools/mv")
            try "#!/bin/sh\necho \"$2\" >> '\(log)'\nexec /bin/mv \"$@\"\n".writeScript(to: mover)

            _ = try await Self.drive(translate, [.set("target", to: "ru")])

            let data = folder.appendingPathComponent(".config/openspot/data/translate")
            XCTAssertEqual(try self.read("moved", in: folder).split(separator: "\n").map { String($0.split(separator: "/").last ?? "") }, ["translate-languages", "translate"])
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: data.path).sorted(), ["translate", "translate-languages"])
            XCTAssertEqual(try String(contentsOf: data.appendingPathComponent("translate"), encoding: .utf8), "source=auto\ntarget=ru\n")
        }
    }

    func testTranslateTakesABigPaste() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)
            let big = String(repeating: String(repeating: "a", count: 99) + "\\", count: 10_000)

            let output = try await Self.drive(translate, [.set("source", to: "ru"), .set("target", to: "en"), .set("input", to: big)])

            XCTAssertEqual(self.text(of: "output", in: output), big.uppercased())
        }
    }

    func testTranslateShowsTheMessageOfACommandThatFails() async throws {
        try await withPrivateHome { folder in
            let translate = try self.fakeTranslate(in: folder)
            let tool = folder.appendingPathComponent("tools/openspot")
            let working = try String(contentsOf: tool, encoding: .utf8)
            _ = try await translate.items(timeout: 10)
            try "#!/bin/sh\ncat >/dev/null\necho 'could not start. Run it again.' >&2\nexit 1\n".write(to: tool, atomically: true, encoding: .utf8)
            defer { try? working.write(to: tool, atomically: true, encoding: .utf8) }

            let output = try await Self.drive(translate, [.set("input", to: "hi")])

            XCTAssertEqual(self.text(of: "output", in: output), "could not start. Run it again.")
            XCTAssertEqual(self.text(of: "input", in: output), "hi")
            XCTAssertEqual(output.parts.last?.id, "swap")
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
