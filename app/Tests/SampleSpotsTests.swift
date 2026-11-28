import XCTest
@testable import OpenspotCore

final class SampleSpotsTests: RepoSpotsCase {
    func testACopyAsksForTheCopiedToast() throws {
        let spots = Repo.root.appendingPathComponent("spots")
        let tools = try temporaryFolder()
        try "#!/bin/sh\ncat >/dev/null\n".writeScript(to: tools.appendingPathComponent("pbcopy"))
        try "#!/bin/sh\ncat >/dev/null\n[ \"$1\" = toast ] && echo \"$2\" >> '\(tools.path)/toasts'\nexit 0\n".writeScript(to: tools.appendingPathComponent("openspot"))
        let examples = spots.deletingLastPathComponent().appendingPathComponent("examples")
        for (script, arguments, input) in [(spots.spotFile("emoji"), ["press"], "input.item=x\n"), (spots.spotFile("files"), ["copy"], "input.item=x\n"), (examples.spotFile("pulls"), ["copy"], "input.item=x\n")] {
            let process = Process()
            let out = Pipe()
            let stdin = Pipe()
            process.executableURL = script
            process.arguments = arguments
            process.environment = ["PATH": "\(tools.path):/usr/bin:/bin", "OPENSPOT_DATA": tools.path, "HOME": tools.path, "OPENSPOT_SH": spots.deletingLastPathComponent().appendingPathComponent("app/Shell/openspot.sh").path]
            process.standardInput = stdin
            process.standardOutput = out
            try process.run()
            stdin.fileHandleForWriting.write(Data(input.utf8))
            try stdin.fileHandleForWriting.close()
            process.waitUntilExit()
            let text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTAssertEqual(text, "", script.lastPathComponent)
        }
        XCTAssertEqual(try read("toasts", in: tools), "Copied\nCopied\nCopied\n")
    }

    func testASampleIsTheReadOfItsSpotOverSampleData() throws {
        for id in ["battery", "cpu", "devices", "disk", "memory"] {
            let spot = try XCTUnwrap(try scan.spots.first { $0.id == id }, id)
            let sample = try String(contentsOf: try XCTUnwrap(spot.sample, id), encoding: .utf8)
            XCTAssertTrue(sample.contains("exec \"$(dirname \"$0\")/\(id).sh\""), sample)
        }
    }

    func testTheSpotsOfANewMacFitThePanelWithNoScrolling() throws {
        let spots = Repo.root.appendingPathComponent("spots")
        let starting = Set(SpotsFolder(url: spots.appendingPathComponent("none"), core: spots).startingSpots())
        let core = try SpotsFolder(url: spots.appendingPathComponent("none"), core: spots).scan()
        let defaults = Config(text: try String(contentsOf: spots.deletingLastPathComponent().appendingPathComponent("app/defaults.toml"), encoding: .utf8)).arrangement
        let shown = core.spots.filter { starting.contains($0.id) && (defaults.isOnGrid(of: $0.id) ?? $0.isOnGrid) && !$0.isBuiltIn }
        let placements = GridLayout().place(shown.map { GridSpot(size: defaults.size(of: $0.id) ?? $0.size, cell: defaults.cells(of: $0.id)?[4]) })

        XCTAssertEqual(placements.count, shown.count)
    }

    func testNoCoreStoreOrExampleSpotSharesAnId() throws {
        let root = Repo.root
        let names = { (folder: String) in Set(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent(folder).path).filter { $0.hasSuffix(".spot") }) }

        let folders = try Repo.spotFolders.map { (name: $0, spots: try names($0)) }

        for (index, folder) in folders.enumerated() {
            for other in folders.dropFirst(index + 1) {
                XCTAssertEqual(folder.spots.intersection(other.spots), [], "\(folder.name) and \(other.name)")
            }
        }
    }

    func testTheCheckFindsNoFaultInTheSpotsAndTheExamples() async throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        try await withPrivateHome { folder in
            try "#!/bin/sh\ncase \"$1 $2\" in 'app status') echo '{}' ;; 'spot list'|'setting list') echo '[]' ;; esac\n".writeScript(to: folder.appendingPathComponent("tools/openspot"))
            let views = ViewLibrary(cache: folder.appendingPathComponent("views"))
            let shipped = Set(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("spots").path).map { ($0 as NSString).deletingPathExtension })
            let places = [
                "spots": SpotsFolder(url: folder.appendingPathComponent("none"), core: root.appendingPathComponent("spots")),
                "store": SpotsFolder(url: root.appendingPathComponent("store")),
                "examples": SpotsFolder(url: root.appendingPathComponent("examples"))
            ]
            let found = await withTaskGroup(of: (String, [String]).self) { group in
                for (name, place) in places {
                    group.addTask { (name, await SpotCheck(folder: place, timeout: 60, views: views, environment: TestEnvironment.values).faults()) }
                }
                return await group.reduce(into: [:]) { $0[$1.0] = $1.1 }
            }
            for (name, faults) in found {
                XCTAssertEqual(faults, [], name)
            }
        }
    }

    func testRelaySendsALineOverItsSocketAndShowsTheLineThatComesBack() async throws {
        let root = Repo.root
        let port = try freePort()
        try await withPrivateHome { folder in
            let relay = ScriptProcess(url: root.appendingPathComponent("examples/relay.spot/relay.sh"), mode: .stays, limit: 60, stopPause: 0.2, variables: ["RELAY_PORT": String(port)], base: TestEnvironment.values)
            defer { relay.end() }
            var frames = relay.start().makeAsyncIterator()

            relay.send(Message(ScriptEntry.show.name), id: 1)
            var sheet = try await self.next(&frames, of: relay)
            while FrameRoot(text: sheet ?? "").isMark { sheet = try await self.next(&frames, of: relay) }
            XCTAssertTrue(sheet?.contains("title=No message yet") == true, sheet ?? "")

            var call = 2
            var seen: [String] = []
            while !seen.contains(where: { $0.contains("title=hello") }), call < 40 {
                relay.send(Message("send", inputs: [.init(key: "peer", value: "127.0.0.1:\(port)"), .init(key: "message", value: "hello")]), id: call)
                while let frame = try await self.next(&frames, of: relay) {
                    seen.append(frame)
                    if Frame(text: frame).ends == [String(call)] { break }
                }
                call += 1
            }

            XCTAssertTrue(self.toasts(in: folder).contains("Sent"), "\(self.toasts(in: folder))")
            XCTAssertTrue(self.toasts(in: folder).contains("hello"), "\(self.toasts(in: folder))")
            XCTAssertTrue(seen.contains { $0.contains("text=last\nclass=col-span-3 row-span-2 bar:flex\ntitle=hello\ndetail=From a peer") }, "\(seen)")
        }
    }

    private func freePort() throws -> Int {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else { throw POSIXError(.EBADF) }
        defer { Darwin.close(socket) }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(socket, $0, size) == 0 && Darwin.getsockname(socket, $0, &size) == 0 }
        }
        guard bound else { throw POSIXError(.EADDRINUSE) }
        return Int(UInt16(bigEndian: address.sin_port))
    }

    private func next(_ frames: inout AsyncThrowingStream<String, Error>.Iterator, of relay: ScriptProcess) async throws -> String? {
        let limit = Task { @MainActor in
            try await RunClock().sleep(.seconds(60), nil)
            XCTFail("Relay printed no frame in 60 seconds")
            relay.end()
        }
        defer { limit.cancel() }
        return try await frames.next()
    }

    func testWindowsPlacesEachSlotWithOneMoveOfTemplates() throws {
        XCTAssertEqual(try windowCall("full"), "window\nmove\n0 0 1 1\n")
        XCTAssertEqual(try windowCall("center"), "window\nmove\n0.175 0.175 0.65 0.65\n")
        XCTAssertEqual(try windowCall("left"), "window\nmove\n0 0 1/4 1\n0 0 1/3 1\n0 0 1/2 1\n")
        XCTAssertEqual(try windowCall("right"), "window\nmove\n3/4 0 1/4 1\n2/3 0 1/3 1\n1/2 0 1/2 1\n")
    }

    func testEveryCommandCanBeRun() throws {
        for command in try scan.spots where command.host == nil && command.mode != .inline {
            XCTAssertTrue(FileManager.default.isExecutableFile(atPath: command.url.path), command.name)
        }
    }

    func testAppsListsEachAppWithItsPathAndNoBadLine() async throws {
        let apps = try XCTUnwrap(try scan.spots.first { $0.name == "Apps" })

        try await withPrivateHome { folder in
            let found = ["/Applications/Zed.app", "/System/Applications/Notes.app", "/Applications/Back\\slash.app"]
            try "#!/bin/sh\nprintf '%s\\n' \(found.map { "'\($0)'" }.joined(separator: " "))\n".writeScript(to: folder.appendingPathComponent("tools/find"))
            try "#!/bin/sh\necho /usr/libexec/logd\n".writeScript(to: folder.appendingPathComponent("tools/ps"))

            let lines = try await apps.items(timeout: 60)

            XCTAssertEqual(lines.errors, [])
            XCTAssertEqual(lines.items.map(\.title), ["Back\\slash", "Finder", "Notes", "Zed"])
            XCTAssertEqual(lines.items.map(\.run), ["/Applications/Back\\slash.app", "/System/Library/CoreServices/Finder.app", "/System/Applications/Notes.app", "/Applications/Zed.app"])
            XCTAssertEqual(lines.items.map(\.iconFile), lines.items.map(\.run))
            XCTAssertTrue(apps.triggers.lists)
        }
    }

    func testScreenshotPastesTheNewestCaptureOfBothFoldersBySpotlightOrNot() throws {
        let spots = Repo.root.appendingPathComponent("spots")
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

        let lines = try await files.items(query: "a", timeout: 60)

        XCTAssertEqual(files.triggers.searchesSheet, true)
        XCTAssertEqual(lines.items, [])
    }

    func testPullRequestsCountEachStateAndOfferEachOne() async throws {
        let scan = try SpotsFolder(url: examples).scan()
        let metric = try XCTUnwrap(scan.metrics.first { $0.id == "pulls" })
        let list = try XCTUnwrap(scan.spots.first { $0.id == "pulls" })
        try await withPrivateHome { folder in
            let value = try await metric.read(timeout: 60)
            let lines = try await list.items(timeout: 60)

            XCTAssertEqual(value.title, "4")
            XCTAssertEqual(value.rows?.map(\.tone), [.bad, .warn, .good, nil])
            XCTAssertEqual(value.rows?.first?.title, "Fix \\ \"tray\"")
            XCTAssertEqual(lines.errors, [])
            XCTAssertEqual(lines.items.map(\.run), (1...3).map { "https://github.test/a/\($0)" } + ["https://github.test/b/4"])
            XCTAssertEqual(lines.items.last?.subtitle, "No checks · To review · b")
            XCTAssertTrue(metric.canShowInMenuBar)
            XCTAssertEqual(list.id, metric.id)

            let item = try XCTUnwrap(lines.items.first)
            try await list.handle(item, timeout: 60)
            XCTAssertEqual(try self.read("opened", in: folder), item.run + "\n")
            try await list.perform("copy", input: Message("copy", inputs: [.init(key: "item", value: item.run)]).text, timeout: 60)
            XCTAssertEqual(try self.read("clipboard", in: folder), item.run)
        }
    }

    func testPullRequestsHideWhenThereAreNone() async throws {
        let metric = try XCTUnwrap(try SpotsFolder(url: examples).scan().metrics.first { $0.id == "pulls" })
        try await withPrivateHome { folder in
            try #"{"data":{"mine":{"nodes":[]},"asked":{"nodes":[]}}}"#.write(to: folder.appendingPathComponent("gh-answer"), atomically: true, encoding: .utf8)

            let value = try await metric.read(timeout: 60)

            XCTAssertTrue(value.isHidden)
        }
    }

    func testTheColorPickerCopiesAPickAndNothingOnACancel() async throws {
        try await withPrivateHome { folder in
            try await self.pickColor(answer: "#0080FF", in: folder)
            XCTAssertEqual(self.toasts(in: folder), ["Copied #0080FF"])
            XCTAssertEqual(try self.read("clipboard", in: folder), "#0080FF")
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("direct").path))

            try FileManager.default.removeItem(at: folder.appendingPathComponent("clipboard"))
            try await self.pickColor(answer: "", in: folder)
            XCTAssertEqual(self.toasts(in: folder), ["Copied #0080FF"])
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("clipboard").path))
        }
    }

    func testEmojiIsAGridWithItsToneAndNoFaults() async throws {
        try await withPrivateHome { folder in
            let output = try await self.fakeEmoji(in: folder).items(timeout: 60)
            let faults = try await self.fakeEmoji(in: folder).sheetFaults(timeout: 60)

            XCTAssertEqual(faults, [])
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

            _ = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: emoji, "tone", input: "input.value=dark\n", limit: 30)
            let output = try await emoji.items(timeout: 60)

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

            let first = try await emoji.items(timeout: 60)
            let kept = try await emoji.items(timeout: 60)
            let callsWhenKept = try self.read("calls", in: folder)
            try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: tool.path)
            let made = try await emoji.items(timeout: 60)

            XCTAssertEqual(first.items.map(\.title), ["thumbs up, none", "rightwards arrow"])
            XCTAssertEqual(kept.items.map(\.title), first.items.map(\.title))
            XCTAssertEqual(callsWhenKept, "emoji\nsymbols\n")
            XCTAssertEqual(made.items.map(\.title), first.items.map(\.title))
            XCTAssertEqual(try self.read("calls", in: folder), "emoji\nsymbols\nemoji\nsymbols\n")
        }
    }

    func testEmojiKeepsItsRowsWhenAnotherPreferenceChangesAndMakesThemForANewLanguage() async throws {
        try await withPrivateHome { folder in
            let emoji = try self.fakeEmoji(in: folder)
            let tool = folder.appendingPathComponent("tools/openspot")
            let calls = folder.appendingPathComponent("calls").path
            let fake = try String(contentsOf: tool, encoding: .utf8).replacingOccurrences(of: "case \"$1\" in", with: "echo \"$1\" >> '\(calls)'\ncase \"$1\" in")
            try fake.writeScript(to: tool)
            let preferences = folder.appendingPathComponent("Library/Preferences/.GlobalPreferences.plist")
            try FileManager.default.createDirectory(at: preferences.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "a".write(to: preferences, atomically: false, encoding: .utf8)

            _ = try await emoji.items(timeout: 60)
            try "b".write(to: preferences, atomically: false, encoding: .utf8)
            _ = try await emoji.items(timeout: 60)
            let callsWhenKept = try self.read("calls", in: folder)
            try "(\n    \"uk-UA\"\n)".write(to: folder.appendingPathComponent("languages"), atomically: true, encoding: .utf8)
            _ = try await emoji.items(timeout: 60)

            XCTAssertEqual(callsWhenKept, "emoji\nsymbols\n")
            XCTAssertEqual(try self.read("calls", in: folder), "emoji\nsymbols\nemoji\nsymbols\n")
        }
    }

    func testEmojiShowsTheSymbolsAndKeepsNothingWhenTheEmojiFail() async throws {
        try await withPrivateHome { folder in
            let emoji = try self.fakeEmoji(in: folder)
            let tool = folder.appendingPathComponent("tools/openspot")
            let fake = try String(contentsOf: tool, encoding: .utf8).replacingOccurrences(of: "emoji) printf", with: "emoji) exit 1; printf")
            try fake.writeScript(to: tool)

            let failed = try await emoji.items(timeout: 60)
            let data = folder.appendingPathComponent(".config/openspot/data/\(try XCTUnwrap(emoji.dataName))")

            XCTAssertEqual(failed.items.map(\.title), ["rightwards arrow"])
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: data.path).filter { $0.hasPrefix("rows") }, [])
        }
    }

    func testEmojiMovesToTheNextToneAndWrapsAround() async throws {
        try await withPrivateHome { folder in
            let emoji = try self.fakeEmoji(in: folder)
            let first = try await emoji.items(timeout: 60)
            let tone = try XCTUnwrap(first.actions.first { $0.id == "next-tone" })
            let row = SpotItem(title: "thumbs up", run: "👍")
            XCTAssertEqual(tone.key, ActionKey(name: "t", isCommand: true))

            _ = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: emoji, tone.id, input: "input.item=\(row.run)\n", limit: 30)
            let next = try await emoji.items(timeout: 60)
            XCTAssertEqual(self.text(of: "tone", in: next), "light")

            _ = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: emoji, "tone", input: "input.value=dark\n", limit: 30)
            _ = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: emoji, tone.id, input: "input.item=\(row.run)\n", limit: 30)
            let wrapped = try await emoji.items(timeout: 60)
            XCTAssertEqual(self.text(of: "tone", in: wrapped), "none")
        }
    }

    func testEmojiCopiesThePick() async throws {
        try await withPrivateHome { folder in
            let emoji = try self.fakeEmoji(in: folder)

            _ = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: emoji, "press", input: "input.item=👍\n", limit: 30)

            XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("clipboard"), encoding: .utf8), "👍")
        }
    }

    func testFilesCopiesThePath() async throws {
        try await withPrivateHome { folder in
            let files = try XCTUnwrap(try self.scan.spots.first { $0.name == "Files" })

            try await files.perform("copy", input: "input.item=/a/b é.txt\n", timeout: 60)

            XCTAssertEqual(self.toasts(in: folder), ["Copied"])
            XCTAssertEqual(try self.read("clipboard", in: folder), "/a/b é.txt")
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("direct").path))
        }
    }

    func testEmojiPastesThePickAndPutsBackTheClipboard() async throws {
        try await withPrivateHome { folder in
            let emoji = try self.fakeEmoji(in: folder)
            try "before".write(to: folder.appendingPathComponent("clipboard"), atomically: true, encoding: .utf8)

            _ = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: emoji, "paste", input: "input.item=👍\n", limit: 30)

            XCTAssertEqual(try self.read("pasted", in: folder), "👍")
            XCTAssertEqual(try self.read("clipboard", in: folder), "before")
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("direct").path))
        }
    }

    func testAReadAnswersWithItsFirstFrame() async throws {
        try await withPrivateHome { folder in
            let url = folder.appendingPathComponent("frames.sh")
            try "#!/bin/sh\nprintf 'text=a\\n---\\n'\nprintf 'text=b\\n'\n".writeScript(to: url)

            let text = try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: Spot(id: "frames", name: "Frames", url: url), ScriptEntry.show.name, limit: 60)

            XCTAssertEqual(text, "text=a\n")
        }
    }

    func testAppsAndFilesOfferToShowInFinder() async throws {
        let commands = try ["Apps", "Files"].map { name in try XCTUnwrap(try scan.spots.first { $0.name == name }) }
        try await withPrivateHome { _ in
            for command in commands {
                let actions = try await command.items(timeout: 60).actions
                XCTAssertEqual(actions.first?.id, "reveal", command.name)
            }
        }
    }
}
