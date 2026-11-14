import XCTest
@testable import OpenspotCore

final class DoomExampleTests: SampleSpotsCase {
    private func engineCommit() throws -> String {
        let script = try String(contentsOf: examples.appendingPathComponent("doom.spot/doom.sh"), encoding: .utf8)
        let line = try XCTUnwrap(script.split(separator: "\n").first { $0.hasPrefix("engine_commit=") })
        return String(line.dropFirst("engine_commit=".count))
    }

    private func data(in folder: URL) -> URL {
        folder.appendingPathComponent(".config/openspot/data/doom")
    }

    private func engine(in folder: URL) throws -> URL {
        data(in: folder).appendingPathComponent("doom-\(try engineCommit())")
    }

    private func fakeEngine(at url: URL, in folder: URL, mark: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\necho \"\(mark) $*\" > '\(folder.path)/played'\npwd >> '\(folder.path)/played'\n".writeScript(to: url)
    }

    private func fakeCurl(in folder: URL) throws {
        try """
        #!/bin/sh
        out=""
        for a; do
          [ "$previous" = "-o" ] && out=$a
          previous=$a
          url=$a
        done
        echo "$url" >> '\(folder.path)/fetched'
        for word in $(cat '\(folder.path)/unreachable' 2>/dev/null); do
          case "$url" in *"$word"*) exit 22 ;; esac
        done
        size=$(cat '\(folder.path)/size' 2>/dev/null)
        if [ -n "$size" ]; then
          head -c $((size / 2)) /dev/zero > "$out"
          sleep 1
          head -c $((size - size / 2)) /dev/zero >> "$out"
        else
          echo 'not the real file' > "$out"
        fi

        """.writeScript(to: folder.appendingPathComponent("tools/curl"))
    }

    private func fakeClang(in folder: URL) throws {
        try fakeEngine(at: folder.appendingPathComponent("built"), in: folder, mark: "built")
        try """
        #!/bin/sh
        echo "$*" >> '\(folder.path)/compiled'
        if [ -f '\(folder.path)/clang-fails' ]; then
          echo 'xcrun: error: invalid active developer path (/Library/Developer/CommandLineTools), missing xcrun' >&2
          exit 1
        fi
        out=""
        for a; do
          [ "$previous" = "-o" ] && out=$a
          previous=$a
        done
        case " $* " in
          *" -c "*"/slow.c "*)
            n=0; while [ ! -f '\(folder.path)/release' ] && [ $n -lt 1500 ]; do sleep 0.02; n=$((n + 1)); done
            : > "$out" ;;
          *" -c "*) : > "$out" ;;
          *) cp '\(folder.path)/built' "$out" ;;
        esac

        """.writeScript(to: folder.appendingPathComponent("tools/clang"))
    }

    private func engineSource(in folder: URL, files: String = "i_main.o doomgeneric_xlib.o") throws {
        let source = data(in: folder).appendingPathComponent("doomgeneric-\(try engineCommit())")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try "SRC_DOOM = \(files)\n".write(to: source.appendingPathComponent("Makefile"), atomically: true, encoding: .utf8)
    }

    private func release(in folder: URL) {
        FileManager.default.createFile(atPath: folder.appendingPathComponent("release").path, contents: Data())
    }

    private func gameData(in folder: URL) throws {
        try FileManager.default.createDirectory(at: data(in: folder), withIntermediateDirectories: true)
        try "wad".write(to: data(in: folder).appendingPathComponent("doom1.wad"), atomically: true, encoding: .utf8)
    }

    private func press(_ spot: Spot, _ call: String = "open", onFrame: (String) -> Void = { _ in }) async -> (frames: [String], failure: String?) {
        var frames: [String] = []
        do {
            for try await frame in ScriptProcess(url: spot.url, arguments: [call], limit: 30, dataName: spot.dataName).start() {
                frames.append(frame)
                onFrame(frame)
            }
        } catch SpotError.failed(_, let line) {
            return (frames, line)
        } catch {
            return (frames, "\(error)")
        }
        return (frames, nil)
    }

    private func spots(in folder: URL) throws -> URL {
        let spots = folder.appendingPathComponent("spots")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: examples.appendingPathComponent("doom.spot"), to: spots.appendingPathComponent("doom.spot"))
        return spots
    }

    @MainActor
    private static func pictures(spots: URL, changes: [@Sendable () throws -> Void]) async throws -> [(picture: String?, sheet: [[String]]?)] {
        var time = Date(timeIntervalSince1970: 1000)
        let runs = SpotRuns(now: { time }, stopPause: 0.2, tickPause: .milliseconds(50))
        defer { runs.quit() }
        runs.take(try SpotsFolder(url: spots).scan())
        let sheet = try XCTUnwrap(runs.sheets["doom"])
        let log = FrameLog(sheet)
        var pictures: [(picture: String?, sheet: [[String]]?)] = []
        for change in [{}] + changes {
            try change()
            time += 10
            let before = log.frames.count
            runs.panelOpened()
            for _ in 0..<500 where log.frames.count == before {
                try await Task.sleep(for: .milliseconds(10))
            }
            runs.panelClosed()
            let drawing = SpotOutput(text: log.last ?? "").layout?.rows
            pictures.append((sheet.state.face.hasView ? sheet.state.values["picture"]?.last : nil, drawing))
        }
        return pictures
    }

    private func lines(_ name: String, in folder: URL) -> [String] {
        ((try? read(name, in: folder)) ?? "").split(separator: "\n").map(String.init)
    }

    private func exists(_ name: String, in folder: URL) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path)
    }

    private func leftovers(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasPrefix("doom.") }
    }

    func testARunWithTheEngineAndTheGameDownloadsNothingAndPlaysFromTheDataFolder() async throws {
        let doom = try example("Doom")
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try self.gameData(in: folder)
            try self.fakeEngine(at: try self.engine(in: folder), in: folder, mark: "old")

            let run = await self.press(doom)

            let played = self.lines("played", in: folder)
            XCTAssertEqual(played.first, "old -iwad \(self.data(in: folder).path)/doom1.wad")
            XCTAssertEqual(played.last.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }, self.data(in: folder).resolvingSymlinksInPath().path)
            XCTAssertTrue(run.frames.contains { $0.contains("title=Playing\ndetail=Press to quit") }, "\(run.frames)")
            XCTAssertNil(run.failure)
            XCTAssertFalse(self.exists("fetched", in: folder))
            XCTAssertFalse(self.exists("compiled", in: folder))
        }
    }

    func testAnEngineOlderThanItsWindowLayerIsBuiltAgainAndThenPlays() async throws {
        let doom = try example("Doom")
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try self.gameData(in: folder)
            try self.engineSource(in: folder)
            try self.fakeEngine(at: try self.engine(in: folder), in: folder, mark: "old")
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: try self.engine(in: folder).path)

            _ = await self.press(doom)

            let compiled = self.lines("compiled", in: folder)
            XCTAssertTrue(compiled.contains { $0.split(separator: " ").contains("-c") && $0.contains("/i_main.c") }, "\(compiled)")
            XCTAssertFalse(compiled.contains { $0.contains("doomgeneric_xlib") }, "\(compiled)")
            XCTAssertTrue(compiled.contains { $0.contains("doom.spot/doomgeneric_mac.m") && $0.contains("-framework Cocoa") }, "\(compiled)")
            XCTAssertEqual(self.lines("played", in: folder).first, "built -iwad \(self.data(in: folder).path)/doom1.wad")
            XCTAssertFalse(self.exists("fetched", in: folder))
        }
    }

    func testAnEngineThatAnotherCommitBuiltIsBuiltAgainForThePinnedOne() async throws {
        let doom = try example("Doom")
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try self.gameData(in: folder)
            try self.engineSource(in: folder)
            try self.fakeEngine(at: self.data(in: folder).appendingPathComponent("doom"), in: folder, mark: "stale")

            _ = await self.press(doom)

            XCTAssertTrue(self.lines("compiled", in: folder).contains { $0.contains("doom.spot/doomgeneric_mac.m") })
            XCTAssertEqual(self.lines("played", in: folder).first, "built -iwad \(self.data(in: folder).path)/doom1.wad")
        }
    }

    func testAnEngineDownloadThatIsNotTheExpectedFileFailsAndLeavesNothing() async throws {
        let doom = try example("Doom")
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)

            let run = await self.press(doom)

            XCTAssertEqual(run.failure, "The download of the Doom engine is not the expected file, so Openspot did not keep it. Press Doom again to download it again.")
            XCTAssertEqual(self.lines("fetched", in: folder).count, 1)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: self.data(in: folder).path), [])
            XCTAssertEqual(try self.leftovers(in: folder), [])
            XCTAssertFalse(self.exists("played", in: folder))
        }
    }

    func testTheGameComesFromTheSecondAddressWhenTheFirstFailsAndIsCheckedThere() async throws {
        let doom = try example("Doom")
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try self.fakeEngine(at: try self.engine(in: folder), in: folder, mark: "old")
            try "deb.debian.org".write(to: folder.appendingPathComponent("unreachable"), atomically: true, encoding: .utf8)

            let run = await self.press(doom)

            let fetched = self.lines("fetched", in: folder)
            XCTAssertEqual(fetched.count, 2)
            XCTAssertTrue(fetched.first?.contains("deb.debian.org") == true, "\(fetched)")
            XCTAssertTrue(fetched.last?.contains("snapshot.debian.org") == true, "\(fetched)")
            XCTAssertEqual(run.failure, "The download of Doom is not the expected file, so Openspot did not keep it. Press Doom again to download it again.")
            XCTAssertFalse(self.exists("doom1.wad", in: self.data(in: folder)))
            XCTAssertEqual(try self.leftovers(in: folder), [])
            XCTAssertFalse(self.exists("played", in: folder))
        }
    }

    func testAGameThatNoAddressGivesFailsWithTheStepThatFixesIt() async throws {
        let doom = try example("Doom")
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try self.fakeEngine(at: try self.engine(in: folder), in: folder, mark: "old")
            try "debian.org".write(to: folder.appendingPathComponent("unreachable"), atomically: true, encoding: .utf8)

            let run = await self.press(doom)

            XCTAssertEqual(run.failure, "Openspot cannot download Doom. Check the connection to the internet, then press Doom again.")
            XCTAssertFalse(self.exists("played", in: folder))
        }
    }

    func testABuildWithNoCommandLineToolsFailsWithTheCommandThatInstallsThem() async throws {
        let doom = try example("Doom")
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try self.gameData(in: folder)
            try self.engineSource(in: folder)
            try "".write(to: folder.appendingPathComponent("clang-fails"), atomically: true, encoding: .utf8)

            let run = await self.press(doom)

            XCTAssertEqual(run.failure, "Openspot cannot build the Doom engine. Install the Command Line Tools with `xcode-select --install`, then press Doom again.")
            XCTAssertTrue(self.lines("compiled", in: folder).contains { $0.contains("/i_main.c") })
            XCTAssertFalse(FileManager.default.fileExists(atPath: try self.engine(in: folder).path))
            XCTAssertEqual(try self.leftovers(in: folder), [])
        }
    }

    func testADownloadShowsTheShareOfItsFileThatIsOnTheDisk() async throws {
        let doom = try example("Doom")
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try "3090826".write(to: folder.appendingPathComponent("size"), atomically: true, encoding: .utf8)

            let run = await self.press(doom)

            XCTAssertTrue(run.frames.contains { $0.contains("title=Downloading the Doom engine\nprogress=0.50\ndetail=50%") }, "\(run.frames)")
            XCTAssertTrue(run.frames.contains { $0.contains("title=Downloading the Doom engine\nprogress=1.00\ndetail=100%") }, "\(run.frames)")
        }
    }

    func testABuildShowsTheShareOfItsFilesThatAreCompiled() async throws {
        let doom = try example("Doom")
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try self.gameData(in: folder)
            try self.engineSource(in: folder, files: "quick.o slow.o doomgeneric_xlib.o")

            let run = await self.press(doom) { frame in
                if frame.contains("progress=0.50") { self.release(in: folder) }
            }

            XCTAssertTrue(run.frames.contains { $0.contains("title=Building the Doom engine\nprogress=0.50\ndetail=50%") }, "\(run.frames)")
            XCTAssertTrue(run.frames.contains { $0.contains("title=Building the Doom engine\nprogress=1.00\ndetail=100%") }, "\(run.frames)")
        }
    }

    func testTheCardShowsTheNewestGameScreenFromTheNextOpenOfThePanel() async throws {
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            let spots = try self.spots(in: folder)
            let screens = self.data(in: folder).appendingPathComponent("screens")
            let first = screens.appendingPathComponent("screen-1.png")
            let second = screens.appendingPathComponent("screen-2.png")

            let pictures = try await Self.pictures(spots: spots, changes: [
                {
                    try FileManager.default.createDirectory(at: screens, withIntermediateDirectories: true)
                    try Data("png".utf8).write(to: first)
                    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1000)], ofItemAtPath: first.path)
                },
                {
                    try Data("png".utf8).write(to: second)
                    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 2000)], ofItemAtPath: second.path)
                }
            ])

            XCTAssertEqual(pictures.map(\.picture), [nil, first.path, second.path])
            XCTAssertEqual(pictures.map(\.sheet), [nil, [["screen"], ["play"]], [["screen"], ["play"]]])
            XCTAssertFalse(self.exists("fetched", in: folder))
            XCTAssertFalse(self.exists("compiled", in: folder))
            XCTAssertFalse(self.exists("played", in: folder))
        }
    }

    func testThePlayButtonOfTheSheetStartsTheGameAsAPressOfTheCardDoes() async throws {
        let doom = try example("Doom")
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try self.gameData(in: folder)
            try self.fakeEngine(at: try self.engine(in: folder), in: folder, mark: "old")
            try FileManager.default.createDirectory(at: self.data(in: folder).appendingPathComponent("screens"), withIntermediateDirectories: true)

            _ = await self.press(doom, "play")

            XCTAssertEqual(self.lines("played", in: folder).first, "old -iwad \(self.data(in: folder).path)/doom1.wad")
        }
    }
}
