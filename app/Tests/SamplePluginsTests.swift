import XCTest
@testable import OpenspotCore

final class SamplePluginsTests: SamplePluginsCase {
    func testACopyAsksForTheCopiedToast() throws {
        let plugins = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("plugins")
        let tools = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-copy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tools) }
        try "#!/bin/sh\ncat >/dev/null\n".writeScript(to: tools.appendingPathComponent("pbcopy"))
        try "#!/bin/sh\ncat >/dev/null\n".writeScript(to: tools.appendingPathComponent("openspot"))
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

    func testConfettiSourceTypeChecks() async throws {
        let confetti = try XCTUnwrap(try scan.commands.first { $0.id == "confetti" })
        XCTAssertEqual(confetti.symbol, "party.popper")

        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-typecheck", confetti.url.path])
    }

    func testNoMetricShowsTwiceInTheGrid() throws {
        let places = try scan.commands.flatMap(\.places)

        XCTAssertEqual(places.count, Set(places).count)
    }

    func testTheSpotsFitThePanelWithNoScrolling() throws {
        let plugins = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("plugins")
        let all = Set(try FileManager.default.contentsOfDirectory(atPath: plugins.path).map { ($0 as NSString).deletingPathExtension })
        let core = try PluginFolder(url: plugins.appendingPathComponent("none"), core: plugins, enabled: all).scan()
        let placements = SpotGrid().place(core.commands.filter(\.isOnGrid).map(\.size))
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

    func testTheCheckFindsNoFaultInThePluginsAndTheExamples() async throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        try await withPrivateHome { folder in
            try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("tools/openspot"))
            let views = ViewLibrary(cache: folder.appendingPathComponent("views"))
            for name in ["plugins", "examples"] {
                let faults = await PluginCheck(folder: PluginFolder(url: root.appendingPathComponent(name)), views: views).faults()

                XCTAssertEqual(faults, [], name)
            }
        }
    }

    func testWindowsPlacesEachSlotWithOneMoveOfTemplates() throws {
        XCTAssertEqual(try windowCall("full"), "window\nmove\n0 0 1 1\n")
        XCTAssertEqual(try windowCall("center"), "window\nmove\n0.175 0.175 0.65 0.65\n")
        XCTAssertEqual(try windowCall("left"), "window\nmove\n0 0 1/4 1\n0 0 1/3 1\n0 0 1/2 1\n")
        XCTAssertEqual(try windowCall("right"), "window\nmove\n3/4 0 1/4 1\n2/3 0 1/3 1\n1/2 0 1/2 1\n")
    }

    func testEveryCommandCanBeRun() throws {
        for command in try scan.commands where command.kind != .widget && command.shipped == nil {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: command.url.path), command.name)
        }
    }

    func testCaffeinateReportsIfItIsOnAndOffersItsDurations() async throws {
        let caffeinate = try XCTUnwrap(try scan.commands.first { $0.name == "Caffeinate" })

        try await withPrivateHome { _ in
            let state = try await caffeinate.state(timeout: 5)
            let lines = try await caffeinate.items(timeout: 5)

            XCTAssertEqual(state.title, "Caffeinate")
            XCTAssertEqual(state.on, false)
            XCTAssertEqual(lines.items.map(\.run), ["1800", "3600", "7200", "0"])
            XCTAssertEqual(lines.errors, [])
            XCTAssertEqual(lines.pick, .close)
            XCTAssertEqual(lines.primary, "Select")
            XCTAssertFalse(lines.keepsRecent)
        }
    }

    func testCaffeinateOffersTurnOffFirstAndStopsOnIt() async throws {
        let caffeinate = try XCTUnwrap(try scan.commands.first { $0.name == "Caffeinate" })
        try await withPrivateHome { _ in
            try await self.turnCaffeinateOnAndOff(caffeinate)
        }
    }

    func testAppsListsEachAppWithItsPathAndNoBadLine() async throws {
        let apps = try XCTUnwrap(try scan.commands.first { $0.name == "Apps" })

        try await withPrivateHome { folder in
            let found = ["/Applications/Zed.app", "/System/Applications/Notes.app", "/Applications/Back\\slash.app"]
            try "#!/bin/sh\nprintf '%s\\n' \(found.map { "'\($0)'" }.joined(separator: " "))\n".writeScript(to: folder.appendingPathComponent("tools/find"))

            let lines = try await apps.items(timeout: 10)

            XCTAssertEqual(lines.errors, [])
            XCTAssertEqual(lines.items.map(\.title), ["Back\\slash", "Finder", "Notes", "Zed"])
            XCTAssertEqual(lines.items.map(\.run), ["/Applications/Back\\slash.app", "/System/Library/CoreServices/Finder.app", "/System/Applications/Notes.app", "/Applications/Zed.app"])
            XCTAssertEqual(lines.items.map(\.file), lines.items.map(\.run))
            XCTAssertTrue(apps.isGlobal)
        }
    }

    func testScreenshotPastesTheNewestCaptureOfBothFoldersBySpotlightOrNot() throws {
        let plugins = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("plugins")
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
            process.executableURL = plugins.appendingPathComponent("paste-screenshot.sh")
            process.environment = ["PATH": "\(tools.path):/usr/bin:/bin", "HOME": folder.path]
            try process.run()
            process.waitUntilExit()

            XCTAssertEqual(process.terminationStatus, 0, newest.lastPathComponent)
            XCTAssertEqual(try String(contentsOf: log, encoding: .utf8), "clipboard copy \(newest.path)\nclipboard paste\n")
        }
    }

    func testFilesSearchesItselfAndGivesNothingForATooShortSearch() async throws {
        let files = try XCTUnwrap(try scan.commands.first { $0.name == "Files" })

        let lines = try await files.items(query: "a", timeout: 5)

        XCTAssertEqual(lines.search, .script)
        XCTAssertEqual(lines.items, [])
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

    func testEmojiIsAGridWithItsToneAndNoFaults() async throws {
        try await withPrivateHome { folder in
            let output = try await self.fakeEmoji(in: folder).items(timeout: 10)

            XCTAssertEqual(output.sheetFaults, [])
            XCTAssertEqual(output.perLine, 7)
            XCTAssertEqual(output.items.map(\.title), ["thumbs up, none", "rightwards arrow"])
            XCTAssertEqual(output.items.last?.subtitle, "Rightwards Arrows")
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
            XCTAssertEqual(output.items.map(\.title), ["thumbs up, dark", "rightwards arrow"])
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

    func testAReadAnswersWithItsFirstFrame() async throws {
        try await withPrivateHome { folder in
            let url = folder.appendingPathComponent("frames.sh")
            try "#!/bin/sh\nprintf 'part=a\\n---\\n'\nprintf 'part=b\\n'\n".writeScript(to: url)

            let text = try await SpotRuns().answer(of: Spot(id: "frames", name: "Frames", url: url), .read, limit: 5)

            XCTAssertEqual(text, "part=a\n")
        }
    }

    func testAppsAndFilesOfferToShowInFinder() async throws {
        let commands = try ["Apps", "Files"].map { name in try XCTUnwrap(try scan.commands.first { $0.name == name }) }
        try await withPrivateHome { _ in
            for command in commands {
                let actions = try await command.items(timeout: 10).actions
                XCTAssertEqual(actions.first?.id, "reveal", command.name)
            }
        }
    }
}
