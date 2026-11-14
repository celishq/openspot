import XCTest
@testable import OpenspotCore

final class SampleSpotsTests: SampleSpotsCase {
    func testACopyAsksForTheCopiedToast() throws {
        let spots = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots")
        let tools = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-copy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tools) }
        try "#!/bin/sh\ncat >/dev/null\n".writeScript(to: tools.appendingPathComponent("pbcopy"))
        try "#!/bin/sh\ncat >/dev/null\n".writeScript(to: tools.appendingPathComponent("openspot"))
        let examples = spots.deletingLastPathComponent().appendingPathComponent("examples")
        for (script, call) in [(spots.spotFile("emoji"), "open"), (spots.spotFile("files"), "copy"), (examples.spotFile("pulls"), "copy")] {
            let process = Process()
            let out = Pipe()
            process.executableURL = script
            process.arguments = [call, "x"]
            process.environment = ["PATH": "\(tools.path):/usr/bin:/bin", "OPENSPOT_DATA": tools.path, "HOME": tools.path, "OPENSPOT_SH": spots.deletingLastPathComponent().appendingPathComponent("app/Shell/openspot.sh").path]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = out
            try process.run()
            process.waitUntilExit()
            let text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTAssertEqual(text, "toast=Copied\n", script.lastPathComponent)
        }
    }

    func testConfettiSourceTypeChecks() async throws {
        let confetti = try XCTUnwrap(try scan.spots.first { $0.id == "confetti" })
        XCTAssertEqual(confetti.symbol, "party.popper")
        XCTAssertFalse(confetti.kind.opensSheet)
        XCTAssertEqual(confetti.settings.map(\.title), ["Look", "Shortcut"])
        let source = confetti.url.deletingPathExtension().appendingPathComponent("confetti.swift")

        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-typecheck", source.path])
    }

    func testConfettiRefusesAPlayKeyThatTheAppsUse() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-key-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: data) }
        try "option+c".write(to: data.appendingPathComponent("key"), atomically: true, encoding: .utf8)

        for key in ["cmd+c", "cmd+shift+v"] {
            let process = Process()
            let out = Pipe()
            process.executableURL = root.appendingPathComponent("spots/confetti.spot/confetti.sh")
            process.arguments = ["key", key]
            process.environment = [
                "PATH": "/usr/bin:/bin", "OPENSPOT_DATA": data.path, "HOME": data.path,
                "OPENSPOT_SH": root.appendingPathComponent("app/Shell/openspot.sh").path
            ]
            process.standardOutput = out
            process.standardInput = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            let text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            XCTAssertTrue(text.contains("belongs to the apps on your Mac"), text)
            XCTAssertTrue(text.contains("⌥C still plays it"), text)
            XCTAssertEqual(try String(contentsOf: data.appendingPathComponent("key"), encoding: .utf8), "option+c")
            XCTAssertFalse(FileManager.default.fileExists(atPath: data.appendingPathComponent("listen.pid").path))
        }
    }

    /// Runs a call of Confetti with its data in a folder of the test, and returns what it prints.
    private func confetti(_ arguments: [String], input: String = "", data: URL) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let process = Process()
        let out = Pipe()
        let stdin = Pipe()
        process.executableURL = root.appendingPathComponent("spots/confetti.spot/confetti.sh")
        process.arguments = arguments
        process.environment = [
            "PATH": "/usr/bin:/bin", "OPENSPOT_DATA": data.path, "HOME": data.path,
            "OPENSPOT_SH": root.appendingPathComponent("app/Shell/openspot.sh").path
        ]
        process.standardOutput = out
        process.standardInput = stdin
        try process.run()
        stdin.fileHandleForWriting.write(Data(input.utf8))
        try stdin.fileHandleForWriting.close()
        process.waitUntilExit()
        return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    func testConfettiAsksForItsLookAsAChoiceAndKeepsThePick() throws {
        let data = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-look-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: data) }

        let form = SpotOutput(text: try confetti(["look"], data: data))
        XCTAssertEqual(form.summary?.value("title"), "Look")
        let choice = try XCTUnwrap(ItemForm(output: form)?.fields.first)
        XCTAssertTrue(choice.options.map(\.id).contains("gold"))

        try "#!/bin/sh\necho \"$@\" >> '\(data.path)/played'\n".writeScript(to: data.appendingPathComponent("confetti"))
        let again = SpotOutput(text: try confetti(["look"], input: "look=gold\n", data: data))
        XCTAssertEqual(try String(contentsOf: data.appendingPathComponent("default"), encoding: .utf8), "gold")
        XCTAssertEqual(ItemForm(output: again)?.soleChoice?.value, "gold")
        XCTAssertTrue(try String(contentsOf: data.appendingPathComponent("played"), encoding: .utf8).contains("gold.look"))
    }

    func testConfettiWithNoKeyStopsListeningAndSaysSo() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-key-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: data) }
        try "option+c".write(to: data.appendingPathComponent("key"), atomically: true, encoding: .utf8)
        let process = Process()
        let out = Pipe()
        process.executableURL = root.appendingPathComponent("spots/confetti.spot/confetti.sh")
        process.arguments = ["key", ""]
        process.environment = [
            "PATH": "/usr/bin:/bin", "OPENSPOT_DATA": data.path, "HOME": data.path,
            "OPENSPOT_SH": root.appendingPathComponent("app/Shell/openspot.sh").path
        ]
        process.standardOutput = out
        process.standardInput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        let text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        XCTAssertTrue(text.contains("Confetti has no shortcut now."), text)
        XCTAssertEqual(try String(contentsOf: data.appendingPathComponent("key"), encoding: .utf8), "")
        XCTAssertFalse(FileManager.default.fileExists(atPath: data.appendingPathComponent("listen.pid").path))
    }

    func testNoMetricShowsTwiceInTheGrid() throws {
        let places = try scan.spots.flatMap(\.places)

        XCTAssertEqual(places.count, Set(places).count)
    }

    func testTheSpotsFitThePanelWithNoScrolling() throws {
        let spots = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots")
        let all = Set(try FileManager.default.contentsOfDirectory(atPath: spots.path).map { ($0 as NSString).deletingPathExtension })
        let core = try SpotsFolder(url: spots.appendingPathComponent("none"), core: spots, enabled: all).scan()
        let defaults = Config(text: try String(contentsOf: spots.deletingLastPathComponent().appendingPathComponent("app/defaults.toml"), encoding: .utf8)).arrangement
        let placements = SpotGrid().place(core.spots.filter { (defaults.isOnGrid(of: $0.id) ?? $0.isOnGrid) && !$0.isBuiltIn }.map { defaults.size(of: $0.id) ?? $0.size })
        let rows = placements.map { $0.row + $0.size.rows }.max()

        XCTAssertLessThanOrEqual(rows ?? 0, 6)
    }

    func testTheCPUTrendGrowsWithEachRead() async throws {
        let cpu = try XCTUnwrap(try scan.metrics.first { $0.id == "cpu" })

        try await withPrivateHome { _ in
            let first = try await cpu.read(timeout: 10).points?.count ?? 0
            let second = try await cpu.read(timeout: 10).points?.count ?? 0

            XCTAssertEqual(second, first + 1)
        }
    }

    func testALookAtTheCPUShowsItNowAndLeavesItsTrendForTheReads() async throws {
        let cpu = try XCTUnwrap(try scan.metrics.first { $0.id == "cpu" })

        try await withPrivateHome { _ in
            let first = try await cpu.read(timeout: 10).points?.count ?? 0
            let look = MetricValue(output: SpotOutput(text: try await ScriptProcess.output(url: cpu.url, arguments: ["show"], limit: 10)))
            let second = try await cpu.read(timeout: 10).points?.count ?? 0

            XCTAssertEqual(look?.points?.count, first + 1)
            XCTAssertNotNil(look?.title)
            XCTAssertEqual(second, first + 1)
        }
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

    func testTheCheckFindsNoFaultInTheSpotsAndTheExamples() async throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        try await withPrivateHome { folder in
            try "#!/bin/sh\ncase \"$1 $2\" in 'app status') echo '{}' ;; 'spot list'|'setting list') echo '[]' ;; esac\n".writeScript(to: folder.appendingPathComponent("tools/openspot"))
            let views = ViewLibrary(cache: folder.appendingPathComponent("views"))
            for name in ["spots", "examples"] {
                let faults = await SpotCheck(folder: SpotsFolder(url: root.appendingPathComponent(name)), views: views).faults()

                XCTAssertEqual(faults, [], name)
            }
        }
    }

    func testRelaySendsALineOverItsSocketAndShowsTheLineThatComesBack() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let port = Int.random(in: 40000...60000)
        let relay = ScriptProcess(url: root.appendingPathComponent("examples/relay.spot/relay.sh"), mode: .stays, limit: 10, stopPause: 0.2, variables: ["RELAY_PORT": String(port)])
        defer { relay.end() }
        var frames = relay.start().makeAsyncIterator()

        relay.send(.read, id: 1)
        var sheet = try await frames.next()
        while SpotOutput(text: sheet ?? "").isMark { sheet = try await frames.next() }
        XCTAssertTrue(sheet?.contains("title=No message yet") == true, sheet ?? "")

        var call = 2
        var seen: [String] = []
        while !seen.contains(where: { $0.contains("title=hello") }), call < 40 {
            relay.send(SpotAction(arguments: ["send"]), input: "peer=127.0.0.1:\(port)\nmessage=hello\n", id: call)
            while let frame = try await frames.next() {
                seen.append(frame)
                if SpotOutput(text: frame).ends == [String(call)] { break }
            }
            if seen.contains(where: { $0.hasPrefix("toast=Sent") }) { seen.append(try await frames.next() ?? "") }
            call += 1
        }

        XCTAssertTrue(seen.contains("toast=Sent\n\n"), "\(seen)")
        XCTAssertTrue(seen.contains { $0.contains("text=last\ntitle=hello\ndetail=From a peer") }, "\(seen)")
    }

    func testWindowsPlacesEachSlotWithOneMoveOfTemplates() throws {
        XCTAssertEqual(try windowCall("full"), "window\nmove\n0 0 1 1\n")
        XCTAssertEqual(try windowCall("center"), "window\nmove\n0.175 0.175 0.65 0.65\n")
        XCTAssertEqual(try windowCall("left"), "window\nmove\n0 0 1/4 1\n0 0 1/3 1\n0 0 1/2 1\n")
        XCTAssertEqual(try windowCall("right"), "window\nmove\n3/4 0 1/4 1\n2/3 0 1/3 1\n1/2 0 1/2 1\n")
    }

    func testEveryCommandCanBeRun() throws {
        for command in try scan.spots where command.kind != .widget && command.host == nil && command.mode != .inline {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: command.url.path), command.name)
        }
    }

    func testCaffeinateOffersItsDurationsAsASheetOfRowsAlone() async throws {
        let caffeinate = try XCTUnwrap(try scan.spots.first { $0.name == "Caffeinate" })

        try await withPrivateHome { _ in
            let state = try await caffeinate.state(timeout: 5)
            let lines = try await caffeinate.items(timeout: 5)

            XCTAssertEqual(state.title, "Caffeinate")
            XCTAssertEqual(state.subtitle, "Off")
            XCTAssertEqual(state.on, false)
            XCTAssertEqual(lines.items.map(\.run), ["1800", "3600", "7200", "14400", "28800", "0"])
            XCTAssertEqual(lines.items.map(\.title), ["30 minutes", "1 hour", "2 hours", "4 hours", "8 hours", "Until turned off"])
            XCTAssertEqual(lines.parts.map(\.id), [])
            XCTAssertNil(lines.layout)
            XCTAssertEqual(lines.errors, [])
            XCTAssertEqual(lines.pick, .close)
            XCTAssertEqual(lines.openTitle, "Select")
            XCTAssertFalse(lines.keepsRecent)
        }
    }

    func testCaffeinateOffersTurnOffFirstAndStopsOnIt() async throws {
        let caffeinate = try XCTUnwrap(try scan.spots.first { $0.name == "Caffeinate" })
        try await withPrivateHome { _ in
            try await self.turnCaffeinateOnAndOff(caffeinate)
        }
    }

    func testAppsListsEachAppWithItsPathAndNoBadLine() async throws {
        let apps = try XCTUnwrap(try scan.spots.first { $0.name == "Apps" })

        try await withPrivateHome { folder in
            let found = ["/Applications/Zed.app", "/System/Applications/Notes.app", "/Applications/Back\\slash.app"]
            try "#!/bin/sh\nprintf '%s\\n' \(found.map { "'\($0)'" }.joined(separator: " "))\n".writeScript(to: folder.appendingPathComponent("tools/find"))
            try "#!/bin/sh\necho /usr/libexec/logd\n".writeScript(to: folder.appendingPathComponent("tools/ps"))

            let lines = try await apps.items(timeout: 10)

            XCTAssertEqual(lines.errors, [])
            XCTAssertEqual(lines.items.map(\.title), ["Back\\slash", "Finder", "Notes", "Zed"])
            XCTAssertEqual(lines.items.map(\.run), ["/Applications/Back\\slash.app", "/System/Library/CoreServices/Finder.app", "/System/Applications/Notes.app", "/Applications/Zed.app"])
            XCTAssertEqual(lines.items.map(\.iconFile), lines.items.map(\.run))
            XCTAssertTrue(apps.isGlobal)
        }
    }

    func testScreenshotPastesTheNewestCaptureOfBothFoldersBySpotlightOrNot() throws {
        let spots = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spots")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-capture-\(UUID().uuidString)")
        let tools = folder.appendingPathComponent("tools")
        let images = folder.appendingPathComponent("images")
        let videos = folder.appendingPathComponent("videos")
        for made in [tools, images, videos] {
            try FileManager.default.createDirectory(at: made, withIntermediateDirectories: true)
        }
        defer { try? FileManager.default.removeItem(at: folder) }
        let image = images.appendingPathComponent("Screenshot.png")
        let video = videos.appendingPathComponent("Screen Recording.mov")
        let other = images.appendingPathComponent("notes.txt")
        let log = folder.appendingPathComponent("openspot")
        try "#!/bin/sh\ncase \"$*\" in *location-screenrecording*) echo '\(videos.path)' ;; *) echo '\(images.path)' ;; esac\n".writeScript(to: tools.appendingPathComponent("defaults"))
        try "#!/bin/sh\nexit 0\n".writeScript(to: tools.appendingPathComponent("mdfind"))
        try "#!/bin/sh\necho \"$*\" >> '\(log.path)'\n".writeScript(to: tools.appendingPathComponent("openspot"))
        for capture in [image, video] {
            FileManager.default.createFile(atPath: capture.path, contents: Data())
            XCTAssertEqual(setxattr(capture.path, "com.apple.metadata:kMDItemScreenCaptureType", "selection", 9, 0, 0), 0)
        }
        FileManager.default.createFile(atPath: other.path, contents: Data())

        for (newest, older) in [(video, image), (image, video)] {
            try? FileManager.default.removeItem(at: log)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -120)], ofItemAtPath: older.path)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -60)], ofItemAtPath: newest.path)
            try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: other.path)
            let process = Process()
            process.executableURL = spots.spotFile("paste-screenshot")
            process.environment = ["PATH": "\(tools.path):/usr/bin:/bin", "HOME": folder.path]
            try process.run()
            process.waitUntilExit()

            XCTAssertEqual(process.terminationStatus, 0, newest.lastPathComponent)
            XCTAssertEqual(try String(contentsOf: log, encoding: .utf8), "clipboard copy \(newest.path)\nclipboard paste\n")
        }
    }

    func testFilesSearchesItselfAndGivesNothingForATooShortSearch() async throws {
        let files = try XCTUnwrap(try scan.spots.first { $0.name == "Files" })

        let lines = try await files.items(query: "a", timeout: 5)

        XCTAssertEqual(files.read?.searchesSheet, true)
        XCTAssertEqual(lines.items, [])
    }

    func testPullRequestsCountEachStateAndOfferEachOne() async throws {
        let scan = try exampleScan
        let metric = try XCTUnwrap(scan.metrics.first { $0.id == "pulls" })
        let list = try XCTUnwrap(scan.spots.first { $0.id == "pulls" })
        try await withPrivateHome { folder in
            let value = try await metric.read(timeout: 5)
            let lines = try await list.items(timeout: 5)

            XCTAssertEqual(value.title, "4")
            XCTAssertEqual(value.rows?.map(\.tone), [.bad, .warn, .good, nil])
            XCTAssertEqual(value.rows?.first?.title, "Fix \\ \"tray\"")
            XCTAssertEqual(lines.errors, [])
            XCTAssertEqual(lines.items.map(\.run), (1...3).map { "https://github.test/a/\($0)" } + ["https://github.test/b/4"])
            XCTAssertEqual(lines.items.last?.subtitle, "No checks · To review · b")
            XCTAssertTrue(metric.canShowInMenuBar)
            XCTAssertEqual(list.id, metric.id)

            let item = try XCTUnwrap(lines.items.first)
            try await list.perform(.item(item), timeout: 5)
            XCTAssertEqual(try self.read("opened", in: folder), item.run + "\n")
            try await list.perform(.action(try await self.action("copy", of: list), item: item), timeout: 5)
            XCTAssertEqual(try self.read("clipboard", in: folder), item.run)
        }
    }

    func testPullRequestsHideWhenThereAreNone() async throws {
        let metric = try XCTUnwrap(try exampleScan.metrics.first { $0.id == "pulls" })
        try await withPrivateHome { folder in
            try #"{"data":{"mine":{"nodes":[]},"asked":{"nodes":[]}}}"#.write(to: folder.appendingPathComponent("gh-answer"), atomically: true, encoding: .utf8)

            let value = try await metric.read(timeout: 5)

            XCTAssertTrue(value.isHidden)
        }
    }

    func testAgentsPullRequestsAndTheClockCanShowInTheMenuBar() throws {
        let scripts = try exampleScan.scripts.filter { ["agents", "clock", "pulls"].contains($0.id) }

        XCTAssertEqual(scripts.map(\.canShowInMenuBar), [true, true, true])
    }

    func testTheColorPickerCopiesAPickAndNothingOnACancel() async throws {
        try await withPrivateHome { folder in
            let picked = try await self.pickColor(answer: "#0080FF", in: folder)
            XCTAssertEqual(picked, "Copied #0080FF")
            XCTAssertEqual(try self.read("clipboard", in: folder), "#0080FF")
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("direct").path))

            try FileManager.default.removeItem(at: folder.appendingPathComponent("clipboard"))
            let cancelled = try await self.pickColor(answer: "", in: folder)
            XCTAssertNil(cancelled)
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("clipboard").path))
        }
    }

    func testEmojiIsAGridWithItsToneAndNoFaults() async throws {
        try await withPrivateHome { folder in
            let output = try await self.fakeEmoji(in: folder).items(timeout: 10)

            XCTAssertEqual(output.sheetFaults, [])
            XCTAssertEqual(output.perLine, 7)
            XCTAssertEqual(output.items.map(\.title), ["thumbs up, none", "rightwards arrow"])
            XCTAssertEqual(output.items.last?.subtitle, "Rightwards Arrows")
            XCTAssertEqual(self.text(of: "tone", in: output), "none")
            XCTAssertEqual(output.openTitle, "Copy")
        }
    }

    func testEmojiKeepsTheToneThatThePersonChooses() async throws {
        try await withPrivateHome { folder in
            let emoji = try self.fakeEmoji(in: folder)

            _ = try await SpotRuns().answer(of: emoji, .set("tone", to: "dark"), input: nil, limit: 30)
            let output = try await emoji.items(timeout: 10)

            XCTAssertEqual(self.text(of: "tone", in: output), "dark")
            XCTAssertEqual(output.items.map(\.title), ["thumbs up, dark", "rightwards arrow"])
        }
    }

    func testEmojiKeepsItsRowsUntilTheAppChanges() async throws {
        try await withPrivateHome { folder in
            let emoji = try self.fakeEmoji(in: folder)
            let tool = folder.appendingPathComponent("tools/openspot")
            let calls = folder.appendingPathComponent("calls").path
            let fake = try String(contentsOf: tool, encoding: .utf8).replacingOccurrences(of: "case \"$1\" in", with: "echo \"$1\" >> '\(calls)'\ncase \"$1\" in")
            try fake.writeScript(to: tool)

            let first = try await emoji.items(timeout: 10)
            let kept = try await emoji.items(timeout: 10)
            let callsWhenKept = try self.read("calls", in: folder)
            try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: tool.path)
            let made = try await emoji.items(timeout: 10)

            XCTAssertEqual(first.items.map(\.title), ["thumbs up, none", "rightwards arrow"])
            XCTAssertEqual(kept.items.map(\.title), first.items.map(\.title))
            XCTAssertEqual(callsWhenKept, "emoji\nsymbols\n")
            XCTAssertEqual(made.items.map(\.title), first.items.map(\.title))
            XCTAssertEqual(try self.read("calls", in: folder), "emoji\nsymbols\nemoji\nsymbols\n")
        }
    }

    func testEmojiShowsTheSymbolsAndKeepsNothingWhenTheEmojiFail() async throws {
        try await withPrivateHome { folder in
            let emoji = try self.fakeEmoji(in: folder)
            let tool = folder.appendingPathComponent("tools/openspot")
            let fake = try String(contentsOf: tool, encoding: .utf8).replacingOccurrences(of: "emoji) printf", with: "emoji) exit 1; printf")
            try fake.writeScript(to: tool)

            let failed = try await emoji.items(timeout: 10)
            let data = folder.appendingPathComponent(".config/openspot/data/\(try XCTUnwrap(emoji.dataName))")

            XCTAssertEqual(failed.items.map(\.title), ["rightwards arrow"])
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: data.path).filter { $0.hasPrefix("rows") }, [])
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

    func testFilesCopiesThePath() async throws {
        try await withPrivateHome { folder in
            let files = try XCTUnwrap(try self.scan.spots.first { $0.name == "Files" })

            let toast = try await files.perform(SpotAction(arguments: ["copy", "/a/b é.txt"]), timeout: 5)

            XCTAssertEqual(toast, "Copied")
            XCTAssertEqual(try self.read("clipboard", in: folder), "/a/b é.txt")
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("direct").path))
        }
    }

    func testEmojiPastesThePickAndPutsBackTheClipboard() async throws {
        try await withPrivateHome { folder in
            let emoji = try self.fakeEmoji(in: folder)
            try "before".write(to: folder.appendingPathComponent("clipboard"), atomically: true, encoding: .utf8)

            _ = try await SpotRuns().answer(of: emoji, SpotAction(arguments: ["paste", "👍"]), input: nil, limit: 30)

            XCTAssertEqual(try self.read("pasted", in: folder), "👍")
            XCTAssertEqual(try self.read("clipboard", in: folder), "before")
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("direct").path))
        }
    }

    func testAReadAnswersWithItsFirstFrame() async throws {
        try await withPrivateHome { folder in
            let url = folder.appendingPathComponent("frames.sh")
            try "#!/bin/sh\nprintf 'text=a\\n---\\n'\nprintf 'text=b\\n'\n".writeScript(to: url)

            let text = try await SpotRuns().answer(of: Spot(id: "frames", name: "Frames", url: url), .read, limit: 5)

            XCTAssertEqual(text, "text=a\n")
        }
    }

    func testAppsAndFilesOfferToShowInFinder() async throws {
        let commands = try ["Apps", "Files"].map { name in try XCTUnwrap(try scan.spots.first { $0.name == name }) }
        try await withPrivateHome { _ in
            for command in commands {
                let actions = try await command.items(timeout: 10).actions
                XCTAssertEqual(actions.first?.id, "reveal", command.name)
            }
        }
    }
}
