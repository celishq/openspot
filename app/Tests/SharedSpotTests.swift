import XCTest
@testable import OpenspotCore

final class SharedSpotTests: XCTestCase {
    private var plugins: URL!
    private var target: URL!

    override func setUpWithError() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-shared-\(UUID().uuidString)")
        plugins = root.appendingPathComponent("plugins")
        target = root.appendingPathComponent("target")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: plugins.deletingLastPathComponent())
    }

    @discardableResult
    private func script(_ path: String, _ text: String = "#!/bin/sh\n", in folder: URL? = nil) throws -> URL {
        let url = (folder ?? plugins).appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func plain(_ path: String, _ data: Data) throws {
        let url = plugins.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    private func sharing(_ id: String) throws -> SharedSpot {
        let folder = PluginFolder(url: plugins)
        let scan = try folder.scan()
        let command = try XCTUnwrap(scan.plugins.flatMap(\.commands).first { $0.id == id })
        return try SharedSpot(sharing: command, from: scan)
    }

    private func document(_ files: String, format: Int = 1) -> Data {
        Data(#"{"format":\#(format),"files":[\#(files)]}"#.utf8)
    }

    private func assertRefused(_ data: Data, says words: String, line: UInt = #line) {
        XCTAssertThrowsError(try SharedSpot(data: data), line: line) { error in
            XCTAssertTrue((error as? PluginError)?.reason.contains(words) == true, "\(error)", line: line)
        }
    }

    func testAScriptKeepsItsBytesAndItsExecutableMarkThroughTheFile() throws {
        let text = "#!/bin/sh\r\n# title=Weather é\n\tprintf '\\\\n'\n"
        try script("weather.sh", text)

        let read = try SharedSpot(data: sharing("weather").data)

        XCTAssertEqual(read.files.map(\.path), ["weather.sh"])
        XCTAssertEqual(read.files.first?.isExecutable, true)
        XCTAssertEqual(read.files.first?.text, text)
    }

    func testTheFileIsPlainJSONWithAFormatNumberAndNoFactsOfTheScript() throws {
        try script("weather.sh", "#!/bin/sh\n# title=Weather\n")

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: sharing("weather").data) as? [String: Any])

        XCTAssertEqual(json["format"] as? Int, 1)
        XCTAssertEqual(Set(json.keys), ["format", "files"])
    }

    func testAScriptInAFolderTravelsWithTheFolderButNotItsHiddenFiles() throws {
        try script("home/coffee.sh")
        try plain("home/lib/shared.sh", Data("shared code\n".utf8))
        try plain("home/.env", Data("TOKEN=1\n".utf8))
        try script("other.sh")

        let spot = try sharing("home/coffee")

        XCTAssertEqual(spot.files.map(\.path).sorted(), ["home/coffee.sh", "home/lib/shared.sh"])
        XCTAssertEqual(spot.files.first { $0.path == "home/lib/shared.sh" }?.isExecutable, false)
    }

    func testAFileThatIsNotTextTravelsWhenItDoesNotRun() throws {
        try script("home/coffee.sh")
        let picture = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF])
        try plain("home/icon.png", picture)

        let read = try SharedSpot(data: sharing("home/coffee").data)

        let icon = try XCTUnwrap(read.files.first { $0.path == "home/icon.png" })
        XCTAssertEqual(icon.contents, picture)
        XCTAssertNil(icon.text)
    }

    func testAWidgetTravelsWithEachMetricItPlacesAndTheCommandItOpens() throws {
        try script("cpu.sh", "#!/bin/sh\n# read=5\n")
        try script("home/disk.sh", "#!/bin/sh\n# read=5\n")
        try script("links.sh", "#!/bin/sh\n# read=sheet\n")
        try script("other.sh")
        try plain("board.toml", Data("""
        [[widgets]]
        title = "Desk"
        grid = ["a a b b"]
        places = { a = "cpu", b = "home/disk" }
        opens = "links"

        """.utf8))

        let spot = try sharing("board/Desk")

        XCTAssertEqual(spot.files.map(\.path).sorted(), ["board.toml", "cpu.sh", "home/disk.sh", "links.sh"])
        XCTAssertEqual(spot.files.first?.path, "board.toml")
    }

    func testAWidgetThatOpensAShippedSpotCarriesNoFileForIt() throws {
        try script("cpu.sh", "#!/bin/sh\n# read=5\n")
        try plain("board.toml", Data("""
        [[widgets]]
        title = "Desk"
        grid = ["a"]
        places = { a = "cpu" }
        size = "square"
        opens = "openspot/plugins"

        """.utf8))
        let folder = PluginFolder(url: plugins)
        let shipped = Spot(id: "openspot/plugins", name: "Plugins", url: plugins, kind: .list, shipped: .quit(QuitSpot {}))
        let scan = try folder.scan(shipped: [shipped])
        let widget = try XCTUnwrap(scan.commands.first { $0.id == "board/Desk" })

        let spot = try SharedSpot(sharing: widget, from: scan)

        XCTAssertEqual(spot.files.map(\.path).sorted(), ["board.toml", "cpu.sh"])
    }

    func testACompiledProgramTravelsWithItsBytesAndStaysExecutable() throws {
        let program = plugins.appendingPathComponent("tool")
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: program)

        let read = try SharedSpot(data: sharing("tool").data)
        try read.add(to: target)

        let added = target.appendingPathComponent("tool")
        XCTAssertEqual(try Data(contentsOf: added), try Data(contentsOf: program))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: added.path))
    }

    func testAShippedSpotDoesNotTravel() throws {
        let shipped = Spot(id: "openspot/plugins", name: "Plugins", url: plugins, shipped: .quit(QuitSpot {}))

        XCTAssertThrowsError(try SharedSpot(sharing: shipped, from: ScanResult(plugins: [], refused: [])))
    }

    func testAFolderOverTheSizeLimitDoesNotTravel() throws {
        try script("home/coffee.sh")
        try plain("home/big.bin", Data(count: SharedSpot.sizeLimit + 1))

        XCTAssertThrowsError(try sharing("home/coffee")) { error in
            XCTAssertEqual((error as? PluginError)?.reason, "This spot is over the 64 MB limit.")
        }
    }

    func testAFileWithANewerFormatAsksForANewerApp() {
        assertRefused(document("", format: 2), says: "newer Openspot")
    }

    func testAFileThatIsNotASpotSaysSo() {
        assertRefused(Data("not json".utf8), says: "not a spot")
        assertRefused(Data(#"{"files":[]}"#.utf8), says: "not a spot")
        assertRefused(document(#"{"path":"a.sh"}"#), says: "not a spot")
    }

    func testAFileWithNoFilesIsRefused() {
        assertRefused(document(""), says: "holds no files")
    }

    func testAPathThatCouldLeaveThePluginsFolderIsRefused() {
        for path in ["../a.sh", "/tmp/a.sh", "home/../../a.sh", ".zshrc", "home/.ssh/a", "", "home//a.sh", "a\\u0000b", "a\\nb"] {
            assertRefused(document(#"{"path":"\#(path)","text":"x"}"#), says: "cannot use the path")
        }
    }

    func testPathsThatClashAreRefused() {
        assertRefused(document(#"{"path":"a.sh","text":"x"},{"path":"A.SH","text":"y"}"#), says: "twice")
        assertRefused(document(#"{"path":"a","text":"x"},{"path":"a/b","text":"y"}"#), says: "twice")
    }

    func testTextThatHidesItsOrderIsRefused() throws {
        assertRefused(document(#"{"path":"a.sh","text":"safe‮evil"}"#), says: "hidden characters")
    }

    func testAFileOverTheSizeLimitIsRefused() throws {
        let text = String(repeating: "x", count: SharedSpot.sizeLimit + 1)
        assertRefused(document(#"{"path":"a.sh","text":"\#(text)"}"#), says: "64 MB")
    }

    func testAddWritesEachFileWithItsMark() throws {
        let spot = try SharedSpot(data: document(##"{"path":"home/a.sh","executable":true,"text":"#!/bin/sh\n"},{"path":"home/b","text":"b"}"##))

        try spot.add(to: target)

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: target.appendingPathComponent("home/a.sh").path))
        XCTAssertFalse(FileManager.default.isExecutableFile(atPath: target.appendingPathComponent("home/b").path))
        XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("home/b"), encoding: .utf8), "b")
    }

    func testAddSendsAFileItReplacesToTheBin() throws {
        let old = try script("a.sh", "old", in: target)
        let spot = try SharedSpot(data: document(#"{"path":"a.sh","executable":true,"text":"new"}"#))
        var discarded: [String] = []

        try spot.add(to: target) { url in
            discarded.append(try String(contentsOf: url, encoding: .utf8))
            try FileManager.default.removeItem(at: url)
        }

        XCTAssertEqual(discarded, ["old"])
        XCTAssertEqual(try String(contentsOf: old, encoding: .utf8), "new")
    }

    func testAddLeavesAnEqualFileAlone() throws {
        try script("a.sh", "same", in: target)
        let spot = try SharedSpot(data: document(#"{"path":"a.sh","executable":true,"text":"same"}"#))

        try spot.add(to: target) { _ in XCTFail("An equal file is not replaced.") }
    }

    func testAddDoesNotWriteThroughALinkOrOverAFolder() throws {
        let outside = target.deletingLastPathComponent().appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: target.appendingPathComponent("home"), withDestinationURL: outside)
        try FileManager.default.createDirectory(at: target.appendingPathComponent("taken"), withIntermediateDirectories: true)

        let through = try SharedSpot(data: document(#"{"path":"home/a.sh","text":"x"}"#))
        XCTAssertThrowsError(try through.add(to: target))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.appendingPathComponent("a.sh").path))

        let over = try SharedSpot(data: document(#"{"path":"taken","text":"x"}"#))
        XCTAssertThrowsError(try over.add(to: target))
    }

    func testAFileNameComesFromTheNameOfTheSpot() {
        XCTAssertEqual(SharedSpot.fileName(for: "Weather"), "Weather.spot")
        XCTAssertEqual(SharedSpot.fileName(for: "../A/b:c"), "A-b-c.spot")
        XCTAssertEqual(SharedSpot.fileName(for: "..."), "Spot.spot")
    }

    func testOnlyADragOfASpotFileAddsASpot() {
        XCTAssertTrue(SharedSpot.isFile(["/a/Weather.spot"]))
        XCTAssertTrue(SharedSpot.isFile(["/a/Weather.SPOT"]))
        XCTAssertFalse(SharedSpot.isFile(["/a/Weather.spot", "/a/b.png"]))
        XCTAssertFalse(SharedSpot.isFile([]))
    }

    func testTextThatIsThePathOfASpotFileNamesIt() throws {
        let file = target.appendingPathComponent("My spot.spot")
        try Data("{}".utf8).write(to: file)
        let path = file.path

        XCTAssertEqual(SharedSpot.file(in: path)?.path, path)
        XCTAssertEqual(SharedSpot.file(in: "  \(path)\n")?.path, path)
        XCTAssertEqual(SharedSpot.file(in: "'\(path)'")?.path, path)
        XCTAssertEqual(SharedSpot.file(in: path.replacingOccurrences(of: " ", with: "\\ "))?.path, path)
        XCTAssertEqual(SharedSpot.file(in: file.absoluteString)?.path, path)
    }

    func testOtherTextNamesNoSpotFile() throws {
        let other = target.appendingPathComponent("notes.txt")
        try Data("x".utf8).write(to: other)

        XCTAssertNil(SharedSpot.file(in: ""))
        XCTAssertNil(SharedSpot.file(in: "weather.spot"))
        XCTAssertNil(SharedSpot.file(in: other.path))
        XCTAssertNil(SharedSpot.file(in: target.appendingPathComponent("gone.spot").path))
    }

    func testTheNoticeWarnsTheSenderAboutSecrets() throws {
        try script("weather.sh")
        try script("home/a.sh")
        try plain("home/b", Data("b".utf8))

        XCTAssertEqual(try sharing("weather").notice(name: "Weather"), "Weather copied. Check it for secrets before you send it.")
        XCTAssertEqual(try sharing("home/a").notice(name: "A"), "A copied, with 2 files. Check them for secrets before you send them.")
    }
}
