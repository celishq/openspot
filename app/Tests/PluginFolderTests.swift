import XCTest
@testable import OpenspotCore

final class PluginFolderTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("openspot-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    @discardableResult
    private func write(_ path: String, header: String = "", body: String = "") throws -> URL {
        let url = folder.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let lines = header.split(separator: "\n").map { "# \($0)\n" }.joined()
        try "#!/bin/sh\n\(lines)\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private var scan: ScanResult {
        get throws { try PluginFolder(url: folder).scan() }
    }

    func testAnExecutableIsASpotWithItsHeader() throws {
        try write("one.sh", header: "name=First\nsize=square\nsymbol=moon\nsubtitle=Off\nkey=o")

        XCTAssertEqual(try scan.refused, [])
        let one = try XCTUnwrap(try scan.commands.first)
        XCTAssertEqual(one.id, "one")
        XCTAssertEqual(one.name, "First")
        XCTAssertEqual(one.size, .square)
        XCTAssertEqual(one.symbol, "moon")
        XCTAssertEqual(one.subtitle, "Off")
        XCTAssertEqual(one.key?.name, "o")
        XCTAssertEqual(one.url.lastPathComponent, "one.sh")
    }

    func testAScriptWithNoHeaderIsAWideLaunchSpotNamedAfterItsFile() throws {
        try write("say-hello_now.sh")

        let command = try XCTUnwrap(try scan.commands.first)

        XCTAssertEqual(command.name, "Say hello now")
        XCTAssertEqual(command.kind, .launch)
        XCTAssertEqual(command.size, .wide)
        XCTAssertEqual(command.symbol, "app")
        XCTAssertNil(command.key)
        XCTAssertNil(command.read)
        XCTAssertFalse(command.readsState)
        XCTAssertEqual(command.pick, .close)
        XCTAssertFalse(command.isGlobal)
        XCTAssertEqual(command.search, .local)
        XCTAssertTrue(command.keepsRecent)
    }

    func testEachExecutableInAFolderIsASpot() throws {
        try write("tools/two.sh")
        try write("tools/one.sh")
        try "shared code".write(to: folder.appendingPathComponent("tools/shared.sh"), atomically: true, encoding: .utf8)

        XCTAssertEqual(try scan.commands.map(\.id), ["tools/one", "tools/two"])
    }

    func testSkipsAnEmptyFolderAndAFileThatIsNotExecutable() throws {
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("empty"), withIntermediateDirectories: true)
        try "text".write(to: folder.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        XCTAssertEqual(try scan.plugins, [])
        XCTAssertEqual(try scan.refused, [])
    }

    func testReadSaysWhatKindOfSpotItIsBeforeAnyRun() throws {
        try write("click.sh", header: "read=click")
        try write("open.sh", header: "read=open")
        try write("ranked.sh", header: "read=open\nrank=3\nrecents=false")

        let commands = try scan.commands

        XCTAssertEqual(commands.map(\.kind), [.list, .launch, .list])
        XCTAssertEqual(commands.map(\.readsState), [false, true, false])
        XCTAssertEqual(commands[2].rank, 3)
        XCTAssertTrue(commands[2].isGlobal)
        XCTAssertFalse(commands[2].keepsRecent)
    }

    func testANumberAsTheReadIsAMetricWithNoSpot() throws {
        try write("cups.sh", header: "name=Cups\nsymbol=cup.and.saucer\nread=30")

        let scan = try scan
        let metric = try XCTUnwrap(scan.metrics.first)

        XCTAssertEqual(scan.commands, [])
        XCTAssertEqual(metric.id, "cups")
        XCTAssertEqual(metric.label, "Cups")
        XCTAssertEqual(metric.symbol, "cup.and.saucer")
        XCTAssertEqual(metric.refresh, 30)
    }

    func testAMetricWithAKeyIsAlsoAList() throws {
        try write("pulls.sh", header: "read=120\nkey=g")

        let scan = try scan

        XCTAssertEqual(scan.metrics.map(\.id), ["pulls"])
        XCTAssertEqual(scan.commands.map(\.id), ["pulls"])
        XCTAssertEqual(scan.commands.first?.kind, .list)
        XCTAssertEqual(scan.commands.first?.readsState, false)
    }

    func testAnOrderMovesASpotAndTheFolderSetsTheRest() throws {
        try write("a.sh", header: "order=1")
        try write("b.sh")
        try write("c.sh", header: "order=-1")
        try write("d.sh")

        XCTAssertEqual(try scan.commands.map(\.id), ["c", "b", "d", "a"])
    }

    func testAListCanSearchLive() throws {
        try write("one.sh", header: "read=click\nsearch=live")

        XCTAssertEqual(try scan.commands.first?.search, .live)
    }

    func testRefusesAHeaderWithAFault() throws {
        try write("a.sh", header: "read=sometimes")
        try write("b.sh", header: "size=huge")
        try write("c.sh", header: "key=ctrl+d")
        try write("d.sh", header: "search=later")
        try write("e.sh", header: "read=open\nrank=first")
        try write("f.sh", header: "rank=1")
        try write("g.sh", header: "read=open\nsearch=live")
        try write("h.sh", header: "read=click\nsearch=live\nrank=1")
        try write("i.sh", header: "order=last")

        XCTAssertEqual(try scan.plugins, [])
        XCTAssertEqual(try scan.refused, [
            Refusal(file: "a", reason: "A has an unknown read: sometimes. Use click, open or a number of seconds"),
            Refusal(file: "b", reason: "B has an unknown size: huge"),
            Refusal(file: "c", reason: "C has an unknown key: ctrl+d"),
            Refusal(file: "d", reason: "D has an unknown search: later"),
            Refusal(file: "e", reason: "E needs a number as its rank"),
            Refusal(file: "f", reason: "F needs read=open to join the main search"),
            Refusal(file: "g", reason: "G needs read=click to search live"),
            Refusal(file: "h", reason: "H needs read=open to join the main search"),
            Refusal(file: "i", reason: "I needs a number as its order")
        ])
    }

    func testAScanDoesNotRunAScript() throws {
        let marker = folder.appendingPathComponent("marker")
        try write("one.sh", header: "read=open", body: "touch '\(marker.path)'")
        try write("two.sh", body: "touch '\(marker.path)'")

        _ = try scan

        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testAConfigPathHoldsThePluginFolder() {
        let folder = PluginFolder.standard(environment: ["OPENSPOT_CONFIG": "/tmp/debug"], home: URL(fileURLWithPath: "/home"))

        XCTAssertEqual(folder.url.path, "/tmp/debug/plugins")
    }

    func testAPluginPathBeatsAConfigPath() {
        let folder = PluginFolder.standard(environment: ["OPENSPOT_CONFIG": "/tmp/debug", "OPENSPOT_PLUGINS": "/tmp/own"], home: URL(fileURLWithPath: "/home"))

        XCTAssertEqual(folder.url.path, "/tmp/own")
    }

    func testWithNoPathTheHomeHoldsThePluginFolder() {
        let folder = PluginFolder.standard(environment: [:], home: URL(fileURLWithPath: "/home"))

        XCTAssertEqual(folder.url.path, "/home/.config/openspot/plugins")
    }

    func testTheFirstCommandKeepsATakenKey() throws {
        try write("a.sh", header: "name=One\nkey=d")
        try write("b.sh", header: "name=Two\nkey=D")

        XCTAssertEqual(try scan.commands.map(\.key?.name), ["d", nil])
        XCTAssertEqual(try scan.refused, [Refusal(file: "b", reason: "Two cannot use key d, because another command has it")])
    }
}
