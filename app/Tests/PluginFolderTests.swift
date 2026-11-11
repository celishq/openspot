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
        try FileManager.default.setAttributes([.creationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: url.path)
        return url
    }

    private var scan: ScanResult {
        get throws { try PluginFolder(url: folder).scan() }
    }

    func testTheStampStaysWhileNothingThatAScanReadsChanges() throws {
        try write("a.sh", header: "title=A")
        try write("home/b.sh", header: "title=B")
        let plugins = PluginFolder(url: folder)

        XCTAssertEqual(plugins.stamp(), plugins.stamp())
    }

    func testTheStampChangesWithEachChangeThatAScanReads() throws {
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-linked-\(UUID().uuidString).sh")
        try "#!/bin/sh\n# title=L\n".writeScript(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }
        let a = try write("a.sh", header: "title=A")
        try write("home/b.sh", header: "title=B")
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("linked.sh"), withDestinationURL: outside)
        let plugins = PluginFolder(url: folder)
        let changes: [(String, () throws -> Void)] = [
            ("an edit of the same size", { try "#!/bin/sh\n# title=Z\n\n".write(to: a, atomically: false, encoding: .utf8) }),
            ("a mode", { try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: a.path) }),
            ("a new file in a subfolder", { try self.write("home/c.sh", header: "title=C") }),
            ("a rename", { try FileManager.default.moveItem(at: a, to: self.folder.appendingPathComponent("d.sh")) }),
            ("a removed file", { try FileManager.default.removeItem(at: self.folder.appendingPathComponent("home/b.sh")) }),
            ("an edit of a linked file", { try "#!/bin/sh\n# title=M\n".write(to: outside, atomically: false, encoding: .utf8) })
        ]

        for (change, make) in changes {
            let before = plugins.stamp()
            try make()
            XCTAssertNotEqual(plugins.stamp(), before, change)
        }
        XCTAssertNotEqual(PluginFolder(url: folder, core: folder, enabled: ["a"]).stamp(), PluginFolder(url: folder, core: folder).stamp())
        XCTAssertNotEqual(plugins.stamp(shipped: [Spot(id: "x", name: "X", url: folder)]), plugins.stamp())
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
        let shipped = Spot(id: "openspot/plugins", name: "Plugins", url: folder, shipped: .quit(QuitSpot {}))

        XCTAssertThrowsError(try PluginFolder(url: folder).remove(shipped) { _ in XCTFail("It must not be discarded.") })
    }

    func testAnExecutableIsASpotWithItsHeader() throws {
        try write("one.sh", header: "title=First\nsize=square\nicon=moon\ndetail=Off")

        XCTAssertEqual(try scan.refused, [])
        let one = try XCTUnwrap(try scan.commands.first)
        XCTAssertEqual(one.id, "one")
        XCTAssertEqual(one.name, "First")
        XCTAssertEqual(one.size, .square)
        XCTAssertEqual(one.symbol, "moon")
        XCTAssertEqual(one.subtitle, "Off")
        XCTAssertEqual(one.url.lastPathComponent, "one.sh")
    }

    func testAHeaderNamesAPictureAsARowDoesAndAPathStartsAtItsFolder() throws {
        try write("cup.sh", header: "icon=icons/cup.png")
        try write("safari.sh", header: "icon=/Applications/Safari.app")
        try write("tea.sh", header: "icon=🍵")

        let commands = try scan.commands
        let cup = try XCTUnwrap(commands.first { $0.id == "cup" })
        let safari = try XCTUnwrap(commands.first { $0.id == "safari" })
        let tea = try XCTUnwrap(commands.first { $0.id == "tea" })

        XCTAssertEqual(cup.icon, .image(cup.url.deletingLastPathComponent().appendingPathComponent("icons/cup.png").path))
        XCTAssertEqual(safari.icon, .file("/Applications/Safari.app"))
        XCTAssertNil(tea.icon)
        XCTAssertEqual(tea.glyph, "🍵")
    }

    func testAScriptWithNoHeaderIsAWideLaunchSpotNamedAfterItsFile() throws {
        try write("say-hello_now.sh")

        let command = try XCTUnwrap(try scan.commands.first)

        XCTAssertEqual(command.name, "Say hello now")
        XCTAssertEqual(command.kind, .launch)
        XCTAssertEqual(command.size, .wide)
        XCTAssertEqual(command.symbol, "app")
        XCTAssertNil(command.read)
        XCTAssertFalse(command.readsState)
        XCTAssertEqual(command.pick, .close)
        XCTAssertFalse(command.isGlobal)
        XCTAssertFalse(command.stays)
        XCTAssertEqual(command.click.arguments, ["open"])
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
        try write("c.sh", header: "read=panel\noffers=search")

        let commands = try scan.commands

        XCTAssertEqual(commands.map(\.kind), [.list, .launch, .list])
        XCTAssertEqual(commands.map(\.readsState), [false, true, false])
        XCTAssertTrue(commands[2].isGlobal)
    }

    func testReadIsAListOfMoments() throws {
        try write("a.sh", header: "read=panel, sheet,30")

        let read = try XCTUnwrap(try scan.commands.first?.read)

        XCTAssertEqual(read.moments, [.panel, .sheet, .every(30)])
        XCTAssertEqual(read.seconds, 30)
    }

    func testRefusesTheLaunchAndWakeMoments() throws {
        try write("a.sh", header: "read=launch")
        try write("b.sh", header: "read=panel,wake")

        XCTAssertEqual(try scan.plugins, [])
        XCTAssertEqual(try scan.refused, [
            ScanResult.Refusal(file: "a", reason: "A has an unknown read: launch. Use sheet, panel or a number of seconds"),
            ScanResult.Refusal(file: "b", reason: "B has an unknown read: panel,wake. Use sheet, panel or a number of seconds")
        ])
    }

    func testStayIsTrueOrAlways() throws {
        try write("a.sh", header: "stay=true")
        try write("b.sh", header: "stay=always")
        try write("c.sh", header: "stay=sometimes")

        let scan = try scan
        XCTAssertEqual(scan.commands.map(\.stays), [true, true])
        XCTAssertEqual(scan.commands.map(\.staysAlways), [false, true])
        XCTAssertEqual(scan.refused, [ScanResult.Refusal(file: "c", reason: "C has an unknown stay: sometimes. Use true or always")])
    }

    func testAHeaderKeepsTheFilesItsCardTakes() throws {
        try write("a.sh", header: "drop=mov, mkv,folder")
        try write("b.sh")

        XCTAssertEqual(try scan.commands.map(\.drop), [["mov", "mkv", "folder"], []])
    }

    func testANumberInAListOfMomentsStartsTheSpotOffTheGrid() throws {
        try write("a.sh", header: "read=panel,30")

        let scan = try scan

        XCTAssertEqual(scan.commands.map(\.id), ["a"])
        XCTAssertEqual(scan.commands.map(\.headerState.isOnGrid), [false])
        XCTAssertEqual(scan.metrics.map(\.read?.seconds), [30])
    }

    func testOldHeaderKeysHaveNoEffect() throws {
        try write("a.sh", header: "live=true\nsearch=live\nrecents=false\norder=last\ngrid=false\nrank=1")

        let command = try XCTUnwrap(try scan.commands.first)

        XCTAssertEqual(try scan.refused, [])
        XCTAssertFalse(command.stays)
        XCTAssertEqual(command.kind, .launch)
        XCTAssertTrue(command.keepsRecent)
        XCTAssertTrue(command.isOnGrid)
        XCTAssertFalse(command.isGlobal)
    }

    func testASpotThatOffersSearchHasACardAndOneThatOffersRowsHasNone() throws {
        try write("a.sh", header: "read=panel\noffers=search")
        try write("b.sh", header: "read=panel\noffers=rows")

        XCTAssertEqual(try scan.commands.map(\.headerState.isOnGrid), [true, false])
    }

    func testTheMainSearchNeedsAMomentOutsideTheSheet() throws {
        try write("a.sh", header: "read=panel\noffers=search")
        try write("c.sh", header: "read=30\noffers=search")

        XCTAssertEqual(try scan.refused, [])
        XCTAssertEqual(try scan.commands.map(\.isGlobal), [true, true])
        XCTAssertEqual(try scan.commands.map(\.kind), [.list, .list])
    }

    func testANumberAsTheReadIsAMetricWhoseCardStartsOffTheGrid() throws {
        try write("cups.sh", header: "title=Cups\nicon=cup.and.saucer\nread=30")

        let scan = try scan
        let metric = try XCTUnwrap(scan.metrics.first)

        XCTAssertEqual(scan.commands.map(\.id), ["cups"])
        XCTAssertFalse(metric.headerState.isOnGrid)
        XCTAssertEqual(metric.id, "cups")
        XCTAssertEqual(metric.name, "Cups")
        XCTAssertEqual(metric.symbol, "cup.and.saucer")
        XCTAssertEqual(metric.read?.seconds, 30)
    }

    func testAMetricIsAlsoAList() throws {
        try write("pulls.sh", header: "read=120")

        let scan = try scan

        XCTAssertEqual(scan.metrics.map(\.id), ["pulls"])
        XCTAssertEqual(scan.commands.map(\.id), ["pulls"])
        XCTAssertEqual(scan.commands.first?.kind, .list)
        XCTAssertEqual(scan.commands.first?.readsState, false)
    }

    func testTheNewestFileComesFirstAndTheFolderSetsTheRest() throws {
        for (name, day) in [("a", 1.0), ("b", 2.0), ("c", 3.0), ("d", 2.0)] {
            let url = try write("\(name).sh")
            try FileManager.default.setAttributes([.creationDate: Date(timeIntervalSince1970: day * 86_400)], ofItemAtPath: url.path)
        }

        XCTAssertEqual(try scan.commands.map(\.id), ["c", "b", "d", "a"])
    }

    func testAScriptThatAWidgetOpensHasNoCardOnTheGrid() throws {
        try write("details.sh", header: "read=panel")
        try write("other.sh", header: "read=panel")
        try write("cpu.sh", header: "read=60")
        try "[[widgets]]\ntitle = \"Box\"\ngrid = [\"cpu\"]\nsize = \"square\"\nopens = \"details\"\n".write(to: folder.appendingPathComponent("box.toml"), atomically: true, encoding: .utf8)

        let commands = try scan.commands

        XCTAssertEqual(commands.first { $0.id == "details" }?.isOnGrid, false)
        XCTAssertEqual(commands.first { $0.id == "other" }?.isOnGrid, true)
    }

    func testRefusesAHeaderWithAFault() throws {
        try write("a.sh", header: "read=sometimes")
        try write("b.sh", header: "size=huge")
        try write("c.sh", header: "shortcut=ctrl+d")
        try write("f.sh", header: "offers=search")
        try write("h.sh", header: "read=sheet\noffers=search")
        try write("j.sh", header: "read=open")
        try write("k.sh", header: "read=click")
        try write("l.sh", header: "read=panel,later")

        XCTAssertEqual(try scan.plugins, [])
        XCTAssertEqual(try scan.refused, [
            ScanResult.Refusal(file: "a", reason: "A has an unknown read: sometimes. Use sheet, panel or a number of seconds"),
            ScanResult.Refusal(file: "b", reason: "B has an unknown size: huge"),
            ScanResult.Refusal(file: "c", reason: "C has shortcut, which Openspot no longer reads. The person gives each spot its letter in Edit Spots"),
            ScanResult.Refusal(file: "f", reason: "F needs panel or a number in its read to join the main search"),
            ScanResult.Refusal(file: "h", reason: "H needs panel or a number in its read to join the main search"),
            ScanResult.Refusal(file: "j", reason: "J has an unknown read: open. Use sheet, panel or a number of seconds"),
            ScanResult.Refusal(file: "k", reason: "K has an unknown read: click. Use sheet, panel or a number of seconds"),
            ScanResult.Refusal(file: "l", reason: "L has an unknown read: panel,later. Use sheet, panel or a number of seconds")
        ])
    }

    func testRefusesAnAnswersPatternThatIsNoneOrThatStays() throws {
        try write("m.sh", header: "answers=[0-9")
        try write("n.sh", header: "answers=^[0-9]\nstay=true")
        try write("o.sh", header: "answers=^[0-9]\nstay=always")

        XCTAssertEqual(try scan.plugins, [])
        XCTAssertEqual(try scan.refused, [
            ScanResult.Refusal(file: "m", reason: "M has an unknown answers pattern: [0-9. Write a regular expression, such as answers=^[0-9]"),
            ScanResult.Refusal(file: "n", reason: "N answers the main search, so it runs once for each call. Remove stay or answers"),
            ScanResult.Refusal(file: "o", reason: "O answers the main search, so it runs once for each call. Remove stay or answers"),
        ])
    }

    func testASpotThatOnlyAnswersTheSearchHasNoCardAndIsNotFound() throws {
        try write("calc.sh", header: "answers=^[0-9]")
        try write("dict.sh", header: "read=sheet\nanswers=^define ")

        let commands = try scan.commands
        let calc = commands.first { $0.id == "calc" }
        let dict = commands.first { $0.id == "dict" }

        XCTAssertEqual(calc?.answers?.text, "^[0-9]")
        XCTAssertEqual(calc?.answers?.matches("2+2"), true)
        XCTAssertEqual(calc?.answers?.matches("safari"), false)
        XCTAssertEqual(calc?.isOnGrid, false)
        XCTAssertEqual(calc?.isFound, false)
        XCTAssertEqual(dict?.isOnGrid, true)
        XCTAssertEqual(dict?.isFound, true)
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

    func testAShortcutInTheHeaderIsRefusedBecauseThePersonGivesTheLetter() throws {
        try write("a.sh", header: "title=One\nshortcut=d")

        XCTAssertEqual(try scan.commands.map(\.id), [])
        XCTAssertEqual(try scan.refused, [ScanResult.Refusal(file: "a", reason: "One has shortcut, which Openspot no longer reads. The person gives each spot its letter in Edit Spots")])
    }
}
