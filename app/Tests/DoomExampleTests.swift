import XCTest
@testable import OpenspotCore

/// Proves the Doom example with its real script, in a private home, with stand-ins for `curl` and `clang`.
final class DoomExampleTests: SamplePluginsCase {
    private var examples: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("examples")
    }

    private func doom() throws -> Spot {
        try XCTUnwrap(try PluginFolder(url: examples).scan().commands.first { $0.name == "Doom" })
    }

    /// The commit of the engine that the script pins, which names the folder of its source.
    private func engineCommit() throws -> String {
        let script = try String(contentsOf: examples.appendingPathComponent("doom/doom.sh"), encoding: .utf8)
        let line = try XCTUnwrap(script.split(separator: "\n").first { $0.hasPrefix("engine_commit=") })
        return String(line.dropFirst("engine_commit=".count))
    }

    private func data(in folder: URL) -> URL {
        folder.appendingPathComponent(".config/openspot/data/doom")
    }

    /// A curl that logs each address to `fetched`, fails for each address that holds a word of the file `unreachable`,
    /// and writes a file that is not the real one for each other address. With a number in the file `size`, it writes
    /// half of that many bytes, waits one second, then writes the rest.
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

    /// A clang that logs each call to `compiled`, fails as a Mac with no Command Line Tools does while the file
    /// `clang-fails` is there, writes an empty object for `-c`, one second later for a file named `slow`, and links an
    /// engine that writes its arguments and its folder to `played`.
    private func fakeClang(in folder: URL) throws {
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
          *" -c "*"/slow.c "*) sleep 1; : > "$out" ;;
          *" -c "*) : > "$out" ;;
          *) printf '#!/bin/sh\\necho "$*" > "%s/played"\\npwd >> "%s/played"\\n' '\(folder.path)' '\(folder.path)' > "$out"; chmod +x "$out" ;;
        esac

        """.writeScript(to: folder.appendingPathComponent("tools/clang"))
    }

    /// An engine that is already built, which writes `old` to `played` when it starts.
    private func builtEngine(in folder: URL) throws {
        try "#!/bin/sh\necho old > '\(folder.path)/played'\n".writeScript(to: data(in: folder).appendingPathComponent("doom"))
    }

    private func engineSource(in folder: URL, files: String = "i_main.o doomgeneric_xlib.o") throws {
        let source = data(in: folder).appendingPathComponent("doomgeneric-\(try engineCommit())")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try "SRC_DOOM = \(files)\n".write(to: source.appendingPathComponent("Makefile"), atomically: true, encoding: .utf8)
    }

    private func gameData(in folder: URL) throws {
        try FileManager.default.createDirectory(at: data(in: folder), withIntermediateDirectories: true)
        try "wad".write(to: data(in: folder).appendingPathComponent("doom1.wad"), atomically: true, encoding: .utf8)
    }

    /// Presses the card once, as the panel does, and returns all that the run printed.
    @MainActor
    private static func press(_ spot: Spot) async throws -> String {
        try await SpotRuns().answer(of: spot, .run, limit: 30)
    }

    private func failure(of spot: Spot) async throws -> String {
        do {
            _ = try await Self.press(spot)
        } catch PluginError.failed(_, let line) {
            return line
        }
        XCTFail("the run did not fail")
        return ""
    }

    /// Runs the script once, as a press of its card does, and returns all that it printed, also when it fails.
    private func frames(in folder: URL) throws -> String {
        let process = Process()
        let out = Pipe()
        process.executableURL = examples.appendingPathComponent("doom/doom.sh")
        process.arguments = ["run"]
        process.environment = [
            "PATH": "\(folder.path)/tools:/usr/bin:/bin",
            "HOME": folder.path,
            "TMPDIR": folder.path + "/",
            "OPENSPOT_DATA": data(in: folder).path
        ]
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        try FileManager.default.createDirectory(at: data(in: folder), withIntermediateDirectories: true)
        try process.run()
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return text
    }

    /// Copies the example into a plugins folder of its own, so that the panel reads no other spot.
    private func plugins(in folder: URL) throws -> URL {
        let plugins = folder.appendingPathComponent("plugins")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: examples.appendingPathComponent("doom"), to: plugins.appendingPathComponent("doom"))
        return plugins
    }

    /// Opens the panel once for each change and once more, each 10 seconds after the last, as a person does, and returns
    /// the picture that the card of the spot drew after each read, or nil for its default card. Each change runs while the
    /// panel is closed.
    @MainActor
    private static func pictures(plugins: URL, changes: [@Sendable () throws -> Void]) async throws -> [String?] {
        var time = Date(timeIntervalSince1970: 1000)
        let runs = SpotRuns(now: { time }, stopPause: 0.2, tickPause: .milliseconds(50))
        defer { runs.quit() }
        runs.take(try PluginFolder(url: plugins).scan())
        let sheet = try XCTUnwrap(runs.sheets["doom/doom"])
        var pictures: [String?] = []
        for change in [{}] + changes {
            try change()
            time += 10
            let before = sheet.lastFrame
            runs.panelOpened()
            for _ in 0..<500 where sheet.lastFrame == before || sheet.lastFrame == nil {
                try await Task.sleep(for: .milliseconds(10))
            }
            runs.panelClosed()
            let shot = sheet.state.face.parts.first { $0.id == "shot" }
            if case .image(let path)? = shot?.control {
                XCTAssertEqual(sheet.state.face.drawing(for: .square), [["shot"]])
                pictures.append(path)
            } else {
                pictures.append(nil)
            }
        }
        return pictures
    }

    private func lines(_ name: String, in folder: URL) -> [String] {
        ((try? read(name, in: folder)) ?? "").split(separator: "\n").map(String.init)
    }

    private func exists(_ name: String, in folder: URL) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path)
    }

    /// The files that a run left in the temporary folder.
    private func leftovers(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasPrefix("doom.") }
    }

    func testARunWithTheEngineAndTheGameDownloadsNothingAndPlaysFromTheDataFolder() async throws {
        let doom = try doom()
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try self.gameData(in: folder)
            try "#!/bin/sh\necho \"$*\" > '\(folder.path)/played'\npwd >> '\(folder.path)/played'\n".writeScript(to: self.data(in: folder).appendingPathComponent("doom"))

            let output = try await Self.press(doom)

            let data = self.data(in: folder).resolvingSymlinksInPath().path
            XCTAssertEqual(self.lines("played", in: folder).map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }.last, data)
            XCTAssertEqual(self.lines("played", in: folder).first, "-iwad \(self.data(in: folder).path)/doom1.wad")
            XCTAssertTrue(output.contains("title=Playing\ndetail=Press to quit"), output)
            XCTAssertFalse(self.exists("fetched", in: folder))
            XCTAssertFalse(self.exists("compiled", in: folder))
        }
    }

    func testAnEngineOlderThanItsWindowLayerIsBuiltAgainAndThenPlays() async throws {
        let doom = try doom()
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try self.gameData(in: folder)
            try self.engineSource(in: folder)
            try self.builtEngine(in: folder)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: self.data(in: folder).appendingPathComponent("doom").path)

            _ = try await Self.press(doom)

            let compiled = self.lines("compiled", in: folder)
            XCTAssertTrue(compiled.contains { $0.split(separator: " ").contains("-c") && $0.contains("/i_main.c") }, "\(compiled)")
            XCTAssertFalse(compiled.contains { $0.contains("doomgeneric_xlib") }, "\(compiled)")
            XCTAssertTrue(compiled.contains { $0.contains("doom/doomgeneric_mac.m") && $0.contains("-framework Cocoa") }, "\(compiled)")
            XCTAssertEqual(self.lines("played", in: folder).first, "-iwad \(self.data(in: folder).path)/doom1.wad")
            XCTAssertFalse(self.exists("fetched", in: folder))
        }
    }

    func testAnEngineDownloadThatIsNotTheExpectedFileFailsAndLeavesNothing() async throws {
        let doom = try doom()
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)

            let line = try await self.failure(of: doom)

            XCTAssertEqual(line, "The downloaded Doom engine is not the expected file, so Openspot did not build it. Press Doom again to download it again.")
            XCTAssertEqual(self.lines("fetched", in: folder).count, 1)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: self.data(in: folder).path), [])
            XCTAssertEqual(try self.leftovers(in: folder), [])
            XCTAssertFalse(self.exists("played", in: folder))
        }
    }

    func testTheGameComesFromTheSecondAddressWhenTheFirstFailsAndIsCheckedThere() async throws {
        let doom = try doom()
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try FileManager.default.createDirectory(at: self.data(in: folder), withIntermediateDirectories: true)
            try self.builtEngine(in: folder)
            try "deb.debian.org".write(to: folder.appendingPathComponent("unreachable"), atomically: true, encoding: .utf8)

            let line = try await self.failure(of: doom)

            let fetched = self.lines("fetched", in: folder)
            XCTAssertEqual(fetched.count, 2)
            XCTAssertTrue(fetched.first?.contains("deb.debian.org") == true, "\(fetched)")
            XCTAssertTrue(fetched.last?.contains("snapshot.debian.org") == true, "\(fetched)")
            XCTAssertEqual(line, "The downloaded Doom is not the expected file, so Openspot did not keep it. Press Doom again to download it again.")
            XCTAssertFalse(self.exists("doom1.wad", in: self.data(in: folder)))
            XCTAssertEqual(try self.leftovers(in: folder), [])
            XCTAssertFalse(self.exists("played", in: folder))
        }
    }

    func testAGameThatNoAddressGivesFailsWithTheStepThatFixesIt() async throws {
        let doom = try doom()
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try FileManager.default.createDirectory(at: self.data(in: folder), withIntermediateDirectories: true)
            try self.builtEngine(in: folder)
            try "debian.org".write(to: folder.appendingPathComponent("unreachable"), atomically: true, encoding: .utf8)

            let line = try await self.failure(of: doom)

            XCTAssertEqual(line, "Openspot cannot download Doom. Check the connection to the internet, then press Doom again.")
            XCTAssertFalse(self.exists("played", in: folder))
        }
    }

    func testABuildWithNoCommandLineToolsFailsWithTheCommandThatInstallsThem() async throws {
        let doom = try doom()
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try self.gameData(in: folder)
            try self.engineSource(in: folder)
            try "".write(to: folder.appendingPathComponent("clang-fails"), atomically: true, encoding: .utf8)

            let line = try await self.failure(of: doom)

            XCTAssertEqual(line, "Openspot cannot build the Doom engine. Install the Command Line Tools with `xcode-select --install`, then press Doom again.")
            XCTAssertTrue(self.lines("compiled", in: folder).contains { $0.contains("/i_main.c") })
            XCTAssertFalse(self.exists("doom", in: self.data(in: folder)))
            XCTAssertEqual(try self.leftovers(in: folder), [])
        }
    }

    func testADownloadShowsTheShareOfItsFileThatIsOnTheDisk() async throws {
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try "3090826".write(to: folder.appendingPathComponent("size"), atomically: true, encoding: .utf8)

            let frames = try self.frames(in: folder)

            XCTAssertTrue(frames.contains("title=Downloading the engine\nvalue=0.50\ndetail=50%\n---"), frames)
            XCTAssertTrue(frames.contains("title=Downloading the engine\nvalue=1.00\ndetail=100%\n---"), frames)
        }
    }

    func testABuildShowsTheShareOfItsFilesThatAreCompiled() async throws {
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            try self.gameData(in: folder)
            try self.engineSource(in: folder, files: "quick.o slow.o doomgeneric_xlib.o")

            let frames = try self.frames(in: folder)

            XCTAssertTrue(frames.contains("title=Building the engine\nvalue=0.50\ndetail=50%\n---"), frames)
            XCTAssertTrue(frames.contains("title=Building the engine\nvalue=1.00\ndetail=100%\n---"), frames)
        }
    }

    func testTheCardShowsTheNewestGameScreenFromTheNextOpenOfThePanel() async throws {
        try await withPrivateHome { folder in
            try self.fakeCurl(in: folder)
            try self.fakeClang(in: folder)
            let plugins = try self.plugins(in: folder)
            let screens = self.data(in: folder).appendingPathComponent("screens")
            let first = screens.appendingPathComponent("screen-1.png")
            let second = screens.appendingPathComponent("screen-2.png")

            let pictures = try await Self.pictures(plugins: plugins, changes: [
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

            XCTAssertEqual(pictures, [nil, first.path, second.path])
            XCTAssertFalse(self.exists("fetched", in: folder))
            XCTAssertFalse(self.exists("compiled", in: folder))
            XCTAssertFalse(self.exists("played", in: folder))
        }
    }

    func testTheCardIsSquareTheSizeNearestToTheShapeOfTheGameScreen() throws {
        XCTAssertEqual(try doom().size, .square)
    }
}
