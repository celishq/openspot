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
        try "#!/bin/sh\n\(lines)\(body)\n".writeScript(to: url)
        return url
    }

    private var scan: ScanResult {
        get throws { try PluginFolder(url: folder).scan() }
    }

    func testADebugBuildKeepsItsStateInItsOwnFolder() {
        let home = URL(fileURLWithPath: "/Users/a")

        XCTAssertEqual(PluginFolder.config(environment: [:], home: home, devState: "/repo/app/../.temp/openspot").path, "/repo/.temp/openspot")
        XCTAssertEqual(PluginFolder.config(environment: [:], home: home, devState: "").path, "/Users/a/.config/openspot")
        XCTAssertEqual(PluginFolder.config(environment: [:], home: home, devState: nil).path, "/Users/a/.config/openspot")
        XCTAssertEqual(PluginFolder.config(environment: ["OPENSPOT_CONFIG": "/x"], home: home, devState: "/repo").path, "/x")
    }

    func testRemoveTakesOnlyTheFileOfTheSpot() throws {
        try write("home/one.sh")
        try write("home/two.sh")
        var discarded: [String] = []
        let command = try XCTUnwrap(try scan.commands.first { $0.id == "home/one" })

        try PluginFolder(url: folder).remove(command) { url in
            discarded.append(url.lastPathComponent)
            try FileManager.default.removeItem(at: url)
        }

        XCTAssertEqual(discarded, ["one.sh"])
        XCTAssertEqual(try scan.commands.map(\.id), ["home/two"])
    }

    func testAShippedSpotCannotBeRemoved() throws {
        let shipped = PluginCommand(id: "openspot/plugins", name: "Plugins", url: folder, shipped: .build(PluginGuide(folder: folder, guide: folder, app: "")))

        XCTAssertThrowsError(try PluginFolder(url: folder).remove(shipped) { _ in XCTFail("It must not be discarded.") })
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
        XCTAssertFalse(command.stays)
        XCTAssertEqual(command.click.arguments, [])
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
        try write("a.sh", header: "read=sheet")
        try write("b.sh", header: "read=panel")
        try write("c.sh", header: "read=panel\nrank=3")

        let commands = try scan.commands

        XCTAssertEqual(commands.map(\.kind), [.list, .launch, .list])
        XCTAssertEqual(commands.map(\.readsState), [false, true, false])
        XCTAssertEqual(commands[2].rank, 3)
        XCTAssertTrue(commands[2].isGlobal)
    }

    func testReadIsAListOfMoments() throws {
        try write("a.sh", header: "read=panel, sheet,launch,wake,30\nkey=a")

        let read = try XCTUnwrap(try scan.commands.first?.read)

        XCTAssertEqual(read.moments, [.panel, .sheet, .launch, .wake, .every(30)])
        XCTAssertEqual(read.seconds, 30)
    }

    func testAMomentThatOnlyALaterPhaseActsOnReadsNothingOnAPanelOpen() throws {
        try write("a.sh", header: "read=launch")
        try write("b.sh", header: "read=wake")

        let commands = try scan.commands

        XCTAssertEqual(commands.map(\.kind), [.launch, .launch])
        XCTAssertEqual(commands.map(\.readsState), [false, false])
    }

    func testAHeaderKeepsTheFilesItsCardTakes() throws {
        try write("a.sh", header: "drop=mov, mkv,folder")
        try write("b.sh")

        XCTAssertEqual(try scan.commands.map(\.drop), [["mov", "mkv", "folder"], []])
    }

    func testANumberInAListOfMomentsWithNoKeyHasNoSpot() throws {
        try write("a.sh", header: "read=panel,30")

        let scan = try scan

        XCTAssertEqual(scan.commands, [])
        XCTAssertEqual(scan.metrics.map(\.read?.seconds), [30])
    }

    func testAStayingScriptIsAList() throws {
        try write("a.sh", header: "stay=true")

        let command = try XCTUnwrap(try scan.commands.first)

        XCTAssertTrue(command.stays)
        XCTAssertEqual(command.kind, .list)
    }

    func testOldHeaderKeysHaveNoEffect() throws {
        try write("a.sh", header: "live=true\nsearch=live\nrecents=false")

        let command = try XCTUnwrap(try scan.commands.first)

        XCTAssertEqual(try scan.refused, [])
        XCTAssertFalse(command.stays)
        XCTAssertEqual(command.kind, .launch)
        XCTAssertTrue(command.keepsRecent)
    }

    func testARankNeedsAMomentOutsideTheSheet() throws {
        try write("a.sh", header: "read=panel\nrank=1")
        try write("b.sh", header: "read=launch\nrank=2")
        try write("c.sh", header: "read=30\nrank=3\nkey=c")

        XCTAssertEqual(try scan.refused, [])
        XCTAssertEqual(try scan.commands.map(\.rank), [1, 2, 3])
        XCTAssertEqual(try scan.commands.map(\.kind), [.list, .list, .list])
    }

    func testANumberAsTheReadIsAMetricWithNoSpot() throws {
        try write("cups.sh", header: "name=Cups\nsymbol=cup.and.saucer\nread=30")

        let scan = try scan
        let metric = try XCTUnwrap(scan.metrics.first)

        XCTAssertEqual(scan.commands, [])
        XCTAssertEqual(metric.id, "cups")
        XCTAssertEqual(metric.name, "Cups")
        XCTAssertEqual(metric.symbol, "cup.and.saucer")
        XCTAssertEqual(metric.read?.seconds, 30)
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

    func testRefusesAHeaderWithAFault() throws {
        try write("a.sh", header: "read=sometimes")
        try write("b.sh", header: "size=huge")
        try write("c.sh", header: "key=ctrl+d")
        try write("e.sh", header: "read=panel\nrank=first")
        try write("f.sh", header: "rank=1")
        try write("h.sh", header: "read=sheet\nrank=1")
        try write("i.sh", header: "order=last")
        try write("j.sh", header: "read=open")
        try write("k.sh", header: "read=click")
        try write("l.sh", header: "read=panel,later")

        XCTAssertEqual(try scan.plugins, [])
        XCTAssertEqual(try scan.refused, [
            Refusal(file: "a", reason: "A has an unknown read: sometimes. Use panel, sheet, launch, wake or a number of seconds"),
            Refusal(file: "b", reason: "B has an unknown size: huge"),
            Refusal(file: "c", reason: "C has an unknown key: ctrl+d"),
            Refusal(file: "e", reason: "E needs a number as its rank"),
            Refusal(file: "f", reason: "F needs panel, launch or a number in its read to join the main search"),
            Refusal(file: "h", reason: "H needs panel, launch or a number in its read to join the main search"),
            Refusal(file: "i", reason: "I needs a number as its order"),
            Refusal(file: "j", reason: "J has an unknown read: open. Use panel, sheet, launch, wake or a number of seconds"),
            Refusal(file: "k", reason: "K has an unknown read: click. Use panel, sheet, launch, wake or a number of seconds"),
            Refusal(file: "l", reason: "L has an unknown read: panel,later. Use panel, sheet, launch, wake or a number of seconds")
        ])
    }

    func testAScanDoesNotRunAScript() throws {
        let marker = folder.appendingPathComponent("marker")
        try write("one.sh", header: "read=panel", body: "touch '\(marker.path)'")
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
