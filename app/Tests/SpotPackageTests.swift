import XCTest
@testable import OpenspotCore

final class SpotPackageTests: XCTestCase {
    private var spots: URL!
    private var target: URL!

    override func setUpWithError() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-shared-\(UUID().uuidString)")
        spots = root.appendingPathComponent("spots")
        target = root.appendingPathComponent("target")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: spots.deletingLastPathComponent())
    }

    @discardableResult
    private func script(_ path: String, _ text: String = "#!/bin/sh\n", in folder: URL? = nil) throws -> URL {
        let url = (folder ?? spots).appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func plain(_ path: String, _ data: Data) throws {
        let url = spots.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    private func sharing(_ id: String) throws -> SpotPackage {
        let folder = SpotsFolder(url: spots)
        let scan = try folder.scan()
        let command = try XCTUnwrap(scan.files.flatMap(\.spots).first { $0.id == id })
        return try SpotPackage(sharing: command, from: scan)
    }

    private func file(_ path: String, _ text: String = "#!/bin/sh\n", runs: Bool = true) -> SpotPackage.File {
        SpotPackage.File(path: path, isExecutable: runs, contents: Data(text.utf8))
    }

    private func assertRefused(_ files: [SpotPackage.File], says words: String, line: UInt = #line) {
        XCTAssertThrowsError(try SpotPackage(files: files), line: line) { error in
            XCTAssertTrue((error as? SpotError)?.reason.contains(words) == true, "\(error)", line: line)
        }
    }

    private func sent(_ spot: SpotPackage) throws -> SpotPackage {
        let zip = target.deletingLastPathComponent().appendingPathComponent("sent-\(UUID().uuidString).spot")
        try spot.zip(to: zip)
        return try SpotPackage(contentsOf: zip)
    }

    func testAScriptKeepsItsBytesAndItsExecutableMarkThroughTheZip() throws {
        let text = "#!/bin/sh\r\n# title=Weather é\n\tprintf '\\\\n'\n"
        try script("weather.spot/weather.sh", text)
        try plain("weather.spot/readme.md", Data("Shows the weather.\n".utf8))

        let read = try sent(sharing("weather"))

        XCTAssertEqual(read.files.map(\.path), ["weather.spot/readme.md", "weather.spot/weather.sh"])
        XCTAssertEqual(read.files.last?.isExecutable, true)
        XCTAssertEqual(read.files.last?.text, text)
        XCTAssertEqual(read.roots, ["weather.spot"])
    }

    func testAScriptTravelsWithItsWholeSpotFolderButNotItsHiddenFiles() throws {
        try script("home.spot/coffee.sh")
        try plain("home.spot/lib/shared.sh", Data("shared code\n".utf8))
        try plain("home.spot/.env", Data("TOKEN=1\n".utf8))
        try script("other.spot/other.sh")

        let spot = try sharing("home/coffee")

        XCTAssertEqual(spot.files.map(\.path).sorted(), ["home.spot/coffee.sh", "home.spot/lib/shared.sh"])
        XCTAssertEqual(spot.files.first { $0.path == "home.spot/lib/shared.sh" }?.isExecutable, false)
    }

    func testAFileThatIsNotTextTravelsWhenItDoesNotRun() throws {
        try script("home.spot/coffee.sh")
        let picture = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF])
        try plain("home.spot/icon.png", picture)

        let read = try sent(sharing("home/coffee"))

        let icon = try XCTUnwrap(read.files.first { $0.path == "home.spot/icon.png" })
        XCTAssertEqual(icon.contents, picture)
        XCTAssertNil(icon.text)
    }

    func testAWidgetTravelsWithEachSpotFolderItPlacesAndOpens() throws {
        try script("cpu.spot/cpu.sh", "#!/bin/sh\n# on=clock.5\n")
        try script("home.spot/disk.sh", "#!/bin/sh\n# on=clock.5\n")
        try script("links.spot/links.sh", "#!/bin/sh\n# on=sheet.open\n")
        try script("other.spot/other.sh")
        try script("board.spot/board.sh", "#!/bin/sh\n# title=Desk\n# grid.strip=cpu cpu home/disk home/disk\n# to=links\n")

        let spot = try sharing("board")

        XCTAssertEqual(spot.files.map(\.path).sorted(), ["board.spot/board.sh", "cpu.spot/cpu.sh", "home.spot/disk.sh", "links.spot/links.sh"])
        XCTAssertEqual(spot.roots.first, "board.spot")
    }

    func testAWidgetThatOpensASpotOfTheAppCarriesNoFileForIt() throws {
        try script("cpu.spot/cpu.sh", "#!/bin/sh\n# on=clock.5\n")
        try script("board.spot/board.sh", "#!/bin/sh\n# title=Desk\n# grid.square=cpu\n# to=openspot/spots\n")
        let core = spots.deletingLastPathComponent().appendingPathComponent("core")
        _ = try script("openspot.spot/spots.sh", "#!/bin/sh\n# on=sheet.open\n", in: core)
        let scan = try SpotsFolder(url: spots, core: core).scan()
        let widget = try XCTUnwrap(scan.spots.first { $0.id == "board" })

        let spot = try SpotPackage(sharing: widget, from: scan)

        XCTAssertEqual(spot.files.map(\.path).sorted(), ["board.spot/board.sh", "cpu.spot/cpu.sh"])
    }

    func testACompiledProgramTravelsWithItsBytesAndStaysExecutable() throws {
        let program = spots.appendingPathComponent("tool.spot/tool")
        try FileManager.default.createDirectory(at: program.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: program)

        let read = try sent(sharing("tool"))
        try read.add(to: target)

        let added = target.appendingPathComponent("tool.spot/tool")
        XCTAssertEqual(try Data(contentsOf: added), try Data(contentsOf: program))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: added.path))
    }

    func testASpotOfTheAppDoesNotTravel() throws {
        let shipped = Spot(id: "openspot/spots", name: "Spots", url: spots).builtIn()

        XCTAssertThrowsError(try SpotPackage(sharing: shipped, from: ScanResult(files: [], refused: [])))
    }

    func testAFolderOverTheSizeLimitDoesNotTravel() throws {
        try script("home.spot/coffee.sh")
        try plain("home.spot/big.bin", Data(count: SpotPackage.sizeLimit + 1))

        XCTAssertThrowsError(try sharing("home/coffee")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "This spot is over the 64 MB limit.")
        }
    }

    func testAFileThatIsNotAZipOfSpotFoldersSaysSo() throws {
        let text = target.appendingPathComponent("Weather.spot")
        try Data(#"{"format":1,"files":[]}"#.utf8).write(to: text)

        XCTAssertThrowsError(try SpotPackage(contentsOf: text)) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "This file is not a spot.")
        }
    }

    func testAZipWithNoSpotFolderHoldsNoSpot() async throws {
        let loose = target.appendingPathComponent("loose")
        try script("weather.sh", in: loose)
        let zip = target.appendingPathComponent("Loose.spot")
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/ditto"), arguments: ["-c", "-k", loose.path, zip.path])

        XCTAssertThrowsError(try SpotPackage(contentsOf: zip)) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "This file holds no spot.")
        }
    }

    func testAZipWithALinkIsRefused() async throws {
        let place = target.appendingPathComponent("linked")
        try script("timer.spot/timer.sh", in: place)
        try FileManager.default.createSymbolicLink(atPath: place.appendingPathComponent("timer.spot/secret").path, withDestinationPath: "/etc/hosts")
        let zip = target.appendingPathComponent("Timer.spot")
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/ditto"), arguments: ["-c", "-k", place.path, zip.path])

        XCTAssertThrowsError(try SpotPackage(contentsOf: zip))
    }

    func testAZipOverTheLimitIsRefusedBeforeItUnpacks() throws {
        let spot = try SpotPackage(files: [file("timer.spot/timer.sh"), file("timer.spot/readme.md", String(repeating: "a", count: 10_000), runs: false)])
        let zip = target.appendingPathComponent("Timer.spot")
        try spot.zip(to: zip)

        XCTAssertThrowsError(try SpotPackage(contentsOf: zip, limit: 5_000))
        XCTAssertNoThrow(try SpotPackage(contentsOf: zip))
    }

    func testASpotFolderOnTheDiskOpensAsItIs() throws {
        try script("timer.spot/timer.sh")

        XCTAssertEqual(try SpotPackage(contentsOf: spots.appendingPathComponent("timer.spot")).files.map(\.path), ["timer.spot/timer.sh"])
    }

    func testAnEntryThatLeavesTheFolderIsUnsafe() {
        XCTAssertTrue(SpotPackage.isSafe(entry: "timer.spot/timer.sh"))
        XCTAssertFalse(SpotPackage.isSafe(entry: "../timer.sh"))
        XCTAssertFalse(SpotPackage.isSafe(entry: "timer.spot/../../timer.sh"))
        XCTAssertFalse(SpotPackage.isSafe(entry: "/etc/hosts"))
    }

    func testAFileOutsideASpotFolderIsRefused() {
        assertRefused([file("a.sh")], says: "is not in a .spot folder")
        assertRefused([file("home/a.sh")], says: "is not in a .spot folder")
        assertRefused([file("a.spot")], says: "is not in a .spot folder")
    }

    func testNoFilesIsRefused() {
        assertRefused([], says: "holds no files")
    }

    func testAPathThatCouldLeaveTheSpotsFolderIsRefused() {
        for path in ["../a.sh", "/tmp/a.sh", "home.spot/../../a.sh", ".zshrc", "home.spot/.ssh/a", "", "home.spot//a.sh", "a.spot/a\u{0}b", "a.spot/a\nb"] {
            assertRefused([file(path)], says: "cannot use the path")
        }
    }

    func testPathsThatClashAreRefused() {
        assertRefused([file("a.spot/a.sh"), file("A.SPOT/A.SH")], says: "twice")
        assertRefused([file("a.spot/a"), file("a.spot/a/b")], says: "twice")
    }

    func testTextThatHidesItsOrderIsRefused() throws {
        assertRefused([file("a.spot/a.sh", "safe\u{202E}evil")], says: "hidden characters")
    }

    func testAFileOverTheSizeLimitIsRefused() throws {
        assertRefused([SpotPackage.File(path: "a.spot/a.sh", isExecutable: true, contents: Data(count: SpotPackage.sizeLimit + 1))], says: "64 MB")
    }

    func testAddWritesEachFileWithItsMark() throws {
        let spot = try SpotPackage(files: [file("home.spot/a.sh"), file("home.spot/b", "b", runs: false)])

        try spot.add(to: target)

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: target.appendingPathComponent("home.spot/a.sh").path))
        XCTAssertFalse(FileManager.default.isExecutableFile(atPath: target.appendingPathComponent("home.spot/b").path))
        XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("home.spot/b"), encoding: .utf8), "b")
    }

    func testAddSendsAFileItReplacesToTheBin() throws {
        let old = try script("a.spot/a.sh", "old", in: target)
        let spot = try SpotPackage(files: [file("a.spot/a.sh", "new")])
        var discarded: [String] = []

        try spot.add(to: target) { url in
            discarded.append(try String(contentsOf: url, encoding: .utf8))
            try FileManager.default.removeItem(at: url)
        }

        XCTAssertEqual(discarded, ["old"])
        XCTAssertEqual(try String(contentsOf: old, encoding: .utf8), "new")
    }

    func testAddLeavesAnEqualFileAlone() throws {
        try script("a.spot/a.sh", "same", in: target)
        let spot = try SpotPackage(files: [file("a.spot/a.sh", "same")])

        try spot.add(to: target) { _ in XCTFail("An equal file is not replaced.") }
    }

    func testAddDoesNotWriteThroughALinkOrOverAFolder() throws {
        let outside = target.deletingLastPathComponent().appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: target.appendingPathComponent("home.spot"), withDestinationURL: outside)
        try FileManager.default.createDirectory(at: target.appendingPathComponent("taken.spot/taken"), withIntermediateDirectories: true)

        let through = try SpotPackage(files: [file("home.spot/a.sh", "x")])
        XCTAssertThrowsError(try through.add(to: target))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.appendingPathComponent("a.sh").path))

        let over = try SpotPackage(files: [file("taken.spot/taken", "x")])
        XCTAssertThrowsError(try over.add(to: target))
    }

    func testAFileNameComesFromTheNameOfTheSpot() {
        XCTAssertEqual(SpotPackage.fileName(for: "Weather"), "Weather.spot")
        XCTAssertEqual(SpotPackage.fileName(for: "../A/b:c"), "A-b-c.spot")
        XCTAssertEqual(SpotPackage.fileName(for: "..."), "Spot.spot")
    }

    func testOnlyADragOfASpotFileOrFolderAddsASpot() {
        XCTAssertTrue(SpotPackage.isFile(["/a/Weather.spot"]))
        XCTAssertTrue(SpotPackage.isFile(["/a/Weather.SPOT"]))
        XCTAssertFalse(SpotPackage.isFile(["/a/Weather.spot", "/a/b.png"]))
        XCTAssertFalse(SpotPackage.isFile([]))
    }

    func testTextThatIsThePathOfASpotFileNamesIt() throws {
        let file = target.appendingPathComponent("My spot.spot")
        try Data("{}".utf8).write(to: file)
        let path = file.path

        XCTAssertEqual(SpotPackage.file(in: path)?.path, path)
        XCTAssertEqual(SpotPackage.file(in: "  \(path)\n")?.path, path)
        XCTAssertEqual(SpotPackage.file(in: "'\(path)'")?.path, path)
        XCTAssertEqual(SpotPackage.file(in: path.replacingOccurrences(of: " ", with: "\\ "))?.path, path)
        XCTAssertEqual(SpotPackage.file(in: file.absoluteString)?.path, path)
    }

    func testOtherTextNamesNoSpotFile() throws {
        let other = target.appendingPathComponent("notes.txt")
        try Data("x".utf8).write(to: other)

        XCTAssertNil(SpotPackage.file(in: ""))
        XCTAssertNil(SpotPackage.file(in: "weather.spot"))
        XCTAssertNil(SpotPackage.file(in: other.path))
        XCTAssertNil(SpotPackage.file(in: target.appendingPathComponent("gone.spot").path))
    }

    func testTextThatIsThePathOfASpotFolderNamesIt() throws {
        let folder = target.appendingPathComponent("weather.spot")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        XCTAssertEqual(SpotPackage.file(in: folder.path)?.path, folder.path)
    }

    func test_P7_theNoticeWarnsTheSenderAboutSecrets() throws {
        try script("weather.spot/weather.sh")
        try script("home.spot/a.sh")
        try plain("home.spot/b", Data("b".utf8))

        XCTAssertEqual(try sharing("weather").notice(name: "Weather"), "Weather copied. Check it for secrets before you send it.")
        XCTAssertEqual(try sharing("home/a").notice(name: "A"), "A copied, with 2 files. Check them for secrets before you send them.")
    }
}
