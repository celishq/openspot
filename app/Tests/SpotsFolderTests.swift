import XCTest
@testable import OpenspotCore

final class SpotsFolderTests: XCTestCase {
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
    /// Writes a script in its spot folder, or with `loose` true where the path says, as an older layout or an agent leaves it.
    private func write(_ path: String, header: String = "", body: String = "", loose: Bool = false) throws -> URL {
        let url = folder.appendingPathComponent(loose || path.split(separator: "/").contains { $0.hasSuffix(".spot") } ? path : path.inSpotFolder)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let lines = header.split(separator: "\n").map { "# \($0)\n" }.joined()
        try "#!/bin/sh\n\(lines)\(body)\n".writeScript(to: url)
        try FileManager.default.setAttributes([.creationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: url.path)
        return url
    }

    /// The spots folder as the app and the command open it, which wraps its loose files first.
    private var opened: SpotsFolder {
        SpotsFolder.standard(environment: ["OPENSPOT_SPOTS": folder.path], home: folder.appendingPathComponent("home"))
    }

    private var scan: ScanResult {
        get throws { try SpotsFolder(url: folder).scan() }
    }

    func testTheStampStaysWhileNothingThatAScanReadsChanges() throws {
        try write("a.sh", header: "title=A")
        try write("home/b.sh", header: "title=B")
        let spots = SpotsFolder(url: folder)

        XCTAssertEqual(spots.stamp(), spots.stamp())
    }

    func testTheStampChangesWithEachChangeThatAScanReads() throws {
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-linked-\(UUID().uuidString).sh")
        try "#!/bin/sh\n# title=L\n".writeScript(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }
        let a = try write("a.sh", header: "title=A")
        try write("home/b.sh", header: "title=B")
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("linked.sh"), withDestinationURL: outside)
        let spots = SpotsFolder(url: folder)
        let changes: [(String, () throws -> Void)] = [
            ("an edit of the same size", { try "#!/bin/sh\n# title=Z\n\n".write(to: a, atomically: false, encoding: .utf8) }),
            ("a mode", { try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: a.path) }),
            ("a new file in a subfolder", { try self.write("home/c.sh", header: "title=C") }),
            ("a rename", { try FileManager.default.moveItem(at: a, to: self.folder.appendingPathComponent("a.spot/d.sh")) }),
            ("a removed file", { try FileManager.default.removeItem(at: self.folder.appendingPathComponent("home.spot/b.sh")) }),
            ("an edit of a linked file", { try "#!/bin/sh\n# title=M\n".write(to: outside, atomically: false, encoding: .utf8) })
        ]

        for (change, make) in changes {
            let before = spots.stamp()
            try make()
            XCTAssertNotEqual(spots.stamp(), before, change)
        }
        XCTAssertNotEqual(SpotsFolder(url: folder, core: folder, enabled: ["a"]).stamp(), SpotsFolder(url: folder, core: folder).stamp())
        XCTAssertNotEqual(spots.stamp(hosted: [Spot(id: "x", name: "X", url: folder)]), spots.stamp())
    }

    func testAKeptScanEqualsAScanAndSeesANewFile() throws {
        try write("a.sh", header: "title=A")
        let spots = SpotsFolder(url: folder)

        XCTAssertEqual(try spots.keptScan(), try scan)
        try write("home/b.sh", header: "title=B")

        XCTAssertEqual(try spots.keptScan().spots.map(\.name), ["A", "B"])
    }

    func testKeptCoreChoicesSeeANewCoreFile() throws {
        try write("a.spot/a.sh", header: "title=A")
        let spots = SpotsFolder(url: folder.appendingPathComponent("own"), core: folder)

        XCTAssertEqual(spots.keptCoreChoices().map(\.name), ["A"])
        try write("b.spot/b.sh", header: "title=B")

        XCTAssertEqual(spots.keptCoreChoices().map(\.name), ["A", "B"])
    }

    func testAScanReadsEachEntryUpToOneFolderDownThatIsNotHidden() {
        let spots = SpotsFolder(url: folder)

        XCTAssertTrue(spots.reads(folder.path))
        XCTAssertTrue(spots.reads(folder.appendingPathComponent("tool.sh").path))
        XCTAssertTrue(spots.reads(folder.appendingPathComponent("kit/tool.sh").path))
        XCTAssertFalse(spots.reads(folder.appendingPathComponent("kit/cache/data.json").path))
        XCTAssertFalse(spots.reads(folder.appendingPathComponent(".git/index").path))
        XCTAssertFalse(spots.reads(folder.appendingPathComponent("kit/.state").path))
        XCTAssertFalse(spots.reads("/elsewhere/tool.sh"))
    }

    func testADebugBuildKeepsItsStateInItsOwnFolder() {
        let home = URL(fileURLWithPath: "/Users/a")

        XCTAssertEqual(SpotsFolder.config(environment: [:], home: home, devState: "/repo/app/../.temp/openspot").path, "/repo/.temp/openspot")
        XCTAssertEqual(SpotsFolder.config(environment: [:], home: home, devState: "").path, "/Users/a/.config/openspot")
        XCTAssertEqual(SpotsFolder.config(environment: [:], home: home, devState: nil).path, "/Users/a/.config/openspot")
        XCTAssertEqual(SpotsFolder.config(environment: ["OPENSPOT_CONFIG": "/x"], home: home, devState: "/repo").path, "/x")
    }

    func testAScriptNamedAfterItsSpotFolderHasTheFolderNameAsItsID() throws {
        try write("weather.spot/weather.sh")
        try write("home.spot/coffee.sh")

        XCTAssertEqual(try scan.spots.map(\.id).sorted(), ["home/coffee", "weather"])
    }

    func testAFolderInsideASpotFolderIsNoSpot() throws {
        try write("confetti.spot/confetti.sh")
        try write("confetti.spot/confetti/helper.sh")

        XCTAssertEqual(try scan.spots.map(\.id), ["confetti"])
        XCTAssertEqual(try scan.refused, [])
    }

    func testAScanReadsNoLooseScriptAndNamesIt() throws {
        try write("weather.sh", loose: true)

        let result = try scan

        XCTAssertEqual(result.spots, [])
        XCTAssertEqual(result.refused.map(\.reason), ["weather.sh is outside a spot folder. Move it into weather.spot."])
    }

    func testOpeningTheFolderWrapsALooseScriptWithItsReadmePreviewAndProgramIntoASpotFolder() throws {
        try write("weather.sh", loose: true)
        try "Shows the weather.".write(to: folder.appendingPathComponent("weather.md"), atomically: true, encoding: .utf8)
        try "row=a\n".write(to: folder.appendingPathComponent("weather.preview.txt"), atomically: true, encoding: .utf8)
        try "notes".write(to: folder.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        XCTAssertEqual(try opened.scan().spots.map(\.id), ["weather"])

        let names = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("weather.spot").path).sorted()
        XCTAssertEqual(names, ["preview.txt", "readme.md", "weather.sh"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted(), ["notes.txt", "weather.spot"])
    }

    func testOpeningTheFolderWrapsAPlainFolderByItsName() throws {
        try write("home/coffee.sh", loose: true)

        XCTAssertEqual(try opened.scan().spots.map(\.id), ["home/coffee"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("home.spot/coffee.sh").path))
    }

    func testAScriptTakesItsViewIntoItsSpotFolder() throws {
        try write("cups.sh", header: "view=glass.swift", loose: true)
        try "import SwiftUI\n".write(to: folder.appendingPathComponent("glass.swift"), atomically: true, encoding: .utf8)

        _ = opened

        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("cups.spot/glass.swift").path))
    }

    func testAWrapNeverReplacesAFileAndTheScanNamesTheClash() throws {
        try write("battery/battery.sh", body: "echo liquid", loose: true)
        try write("battery.sh", body: "echo metric", loose: true)
        try write("clock.sh", loose: true)

        XCTAssertNoThrow(try SpotsFolder(url: folder).wrap())
        let result = try opened.scan()

        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("battery.spot/battery.sh"), encoding: .utf8).contains("liquid"), true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("battery.sh").path))
        XCTAssertEqual(result.refused.map(\.file), ["battery.sh"])
        XCTAssertEqual(result.spots.map(\.id), ["battery", "clock"])
    }

    func testRemoveTakesTheWholeSpotFolderOfItsOnlySpot() throws {
        try write("weather.spot/weather.sh")
        try "Shows the weather.".write(to: folder.appendingPathComponent("weather.spot/readme.md"), atomically: true, encoding: .utf8)
        var discarded: [String] = []
        let command = try XCTUnwrap(try scan.spots.first)

        try SpotsFolder(url: folder).remove(command) { url in
            discarded.append(url.lastPathComponent)
            try FileManager.default.removeItem(at: url)
        }

        XCTAssertEqual(discarded, ["weather.spot"])
    }

    func testRemoveTakesOnlyTheFileOfTheSpot() throws {
        try write("home/one.sh")
        try write("home/two.sh")
        var discarded: [String] = []
        let command = try XCTUnwrap(try scan.spots.first { $0.id == "home/one" })

        try SpotsFolder(url: folder).remove(command) { url in
            discarded.append(url.lastPathComponent)
            try FileManager.default.removeItem(at: url)
        }

        XCTAssertEqual(discarded, ["one.sh"])
        XCTAssertEqual(try scan.spots.map(\.id), ["home/two"])
    }

    func testASpotOfTheAppIsAlwaysOnAndCannotBeRemoved() throws {
        let core = folder.appendingPathComponent("core")
        _ = try write("core/openspot.spot/spots.sh", header: "title=Spots")
        _ = try write("core/apps.spot/apps.sh")
        let place = SpotsFolder(url: folder.appendingPathComponent("mine"), core: core)

        let spot = try XCTUnwrap(try place.scan().spots.first)

        XCTAssertEqual(try place.scan().spots.map(\.id), ["openspot/spots"])
        XCTAssertTrue(spot.isBuiltIn)
        XCTAssertFalse(place.isCore(spot))
        XCTAssertEqual(place.coreChoices().map(\.id), ["apps"])
        XCTAssertThrowsError(try place.remove(spot) { _ in XCTFail("It must not be discarded.") })
    }

    func testAFileOfThePersonHidesASpotOfTheApp() throws {
        _ = try write("core/openspot.spot/spots.sh", header: "title=Spots")
        _ = try write("mine/openspot.spot/spots.sh", header: "title=Mine")

        let scan = try SpotsFolder(url: folder.appendingPathComponent("mine"), core: folder.appendingPathComponent("core")).scan()

        XCTAssertEqual(scan.spots.map(\.name), ["Mine"])
        XCTAssertEqual(scan.spots.map(\.isBuiltIn), [false])
    }

    func testAnExecutableIsASpotWithItsHeader() throws {
        try write("one.sh", header: "title=First\nicon=moon\ndetail=Off")

        XCTAssertEqual(try scan.refused, [])
        let one = try XCTUnwrap(try scan.spots.first)
        XCTAssertEqual(one.id, "one")
        XCTAssertEqual(one.name, "First")
        XCTAssertEqual(one.size, .wide)
        XCTAssertEqual(one.symbol, "moon")
        XCTAssertEqual(one.subtitle, "Off")
        XCTAssertEqual(one.url.lastPathComponent, "one.sh")
    }

    func testAHeaderNamesAPictureAsARowDoesAndAPathStartsAtItsFolder() throws {
        try write("cup.sh", header: "icon=icons/cup.png")
        try write("safari.sh", header: "icon=/Applications/Safari.app")
        try write("tea.sh", header: "icon=🍵")

        let commands = try scan.spots
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

        let command = try XCTUnwrap(try scan.spots.first)

        XCTAssertEqual(command.name, "Say hello now")
        XCTAssertEqual(command.kind, .launch)
        XCTAssertEqual(command.size, .wide)
        XCTAssertEqual(command.symbol, "app")
        XCTAssertNil(command.read)
        XCTAssertFalse(command.readsState)
        XCTAssertEqual(command.pick, .close)
        XCTAssertFalse(command.isGlobal)
        XCTAssertEqual(command.mode, .once)
        XCTAssertEqual(command.click.arguments, ["open"])
    }

    func testEachExecutableInAFolderIsASpot() throws {
        try write("tools/two.sh")
        try write("tools/one.sh")
        try "shared code".write(to: folder.appendingPathComponent("tools.spot/shared.sh"), atomically: true, encoding: .utf8)

        XCTAssertEqual(try scan.spots.map(\.id), ["tools/one", "tools/two"])
    }

    func testSkipsAnEmptyFolderAndAFileThatIsNotExecutable() throws {
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("empty"), withIntermediateDirectories: true)
        try "text".write(to: folder.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        XCTAssertEqual(try scan.files, [])
        XCTAssertEqual(try scan.refused, [])
    }

    func testReadSaysWhatKindOfSpotItIsBeforeAnyRun() throws {
        try write("a.sh", header: "on=sheet.open")
        try write("b.sh", header: "on=panel.open")
        try write("c.sh", header: "on=panel.open\noffers=search")

        let commands = try scan.spots

        XCTAssertEqual(commands.map(\.kind), [.list, .launch, .list])
        XCTAssertEqual(commands.map(\.readsState), [false, true, false])
        XCTAssertTrue(commands[2].isGlobal)
    }

    func testReadIsAListOfPlacesBesideItsSeconds() throws {
        try write("a.sh", header: "on=panel.open\non=sheet.open\non=clock.30")

        let read = try XCTUnwrap(try scan.spots.first?.read)

        XCTAssertEqual(read.moments, [.panel, .sheet, .every(30)])
        XCTAssertEqual(read.seconds, 30)
    }

    func testRefusesTheOldReadKeysAndNamesTheEvents() throws {
        try write("a.sh", header: "read=launch")
        try write("b.sh", header: "read=panel,sheet")
        try write("c.sh", header: "every=30")
        try write("d.sh", header: "answers=^[0-9]")

        XCTAssertEqual(try scan.files, [])
        XCTAssertEqual(try scan.refused, [
            ScanResult.Refusal(file: "a", reason: "A has read=launch, which Openspot no longer reads. Write an event, such as on=sheet.open"),
            ScanResult.Refusal(file: "b", reason: "B has read=panel,sheet, which Openspot no longer reads. Write on=panel.open and on=sheet.open"),
            ScanResult.Refusal(file: "c", reason: "C has every=30, which Openspot no longer reads. Write on=clock.30"),
            ScanResult.Refusal(file: "d", reason: "D has answers=^[0-9], which Openspot no longer reads. Write on=search.text ^[0-9]")
        ])
    }

    func testModeIsOnceStayOrAlways() throws {
        try write("a.sh", header: "mode=stay")
        try write("b.sh", header: "mode=always")
        try write("c.sh", header: "mode=once")
        try write("d.sh", header: "mode=sometimes")

        let scan = try scan
        XCTAssertEqual(scan.spots.map(\.mode), [.stay, .always, .once])
        XCTAssertEqual(scan.refused, [ScanResult.Refusal(file: "d", reason: "D has an unknown mode: sometimes. Use once, stay or always")])
    }

    func testAJavaScriptFileWithAHeaderRunsInlineAndAnotherIsLeft() throws {
        for (name, text) in [("sum", "// title=Sum\nfunction main() { return '' }\n"), ("plain", "function shared() { return '' }\n"), ("stays", "// mode=stay\nfunction main() { return '' }\n")] {
            let file = folder.spotFile(name, extension: "js")
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: file, atomically: true, encoding: .utf8)
        }
        try write("a.sh", header: "mode=inline")

        let scan = try scan
        XCTAssertEqual(scan.spots.map(\.id), ["sum"])
        XCTAssertEqual(scan.spots.map(\.mode), [.inline])
        XCTAssertEqual(scan.refused, [
            ScanResult.Refusal(file: "a", reason: "A has mode=inline, which Openspot no longer reads. A .js file runs inline, so remove the line"),
            ScanResult.Refusal(file: "stays", reason: "Stays is a .js file, which runs inline, so it takes no mode=stay"),
        ])
    }

    func testAnExecutableJavaScriptFileRunsAsAProcess() throws {
        try "#!/usr/bin/env node\n// title=Node\n// mode=stay\nconsole.log('hi')\n".writeScript(to: folder.spotFile("node", extension: "js"))

        XCTAssertEqual(try scan.spots.map(\.mode), [.stay])
    }

    func testRefusesStayAndNamesTheMode() throws {
        try write("a.sh", header: "stay=true")
        try write("b.sh", header: "stay=always")

        XCTAssertEqual(try scan.refused, [
            ScanResult.Refusal(file: "a", reason: "A has stay, which Openspot no longer reads. Use mode=stay or mode=always"),
            ScanResult.Refusal(file: "b", reason: "B has stay, which Openspot no longer reads. Use mode=stay or mode=always"),
        ])
    }

    func testAHeaderKeepsTheFilesItsCardTakes() throws {
        try write("a.sh", header: "drop=mov, mkv,folder")
        try write("b.sh")

        XCTAssertEqual(try scan.spots.map(\.drop), [["mov", "mkv", "folder"], []])
    }

    func testANumberInAListOfMomentsStartsTheSpotOffTheGrid() throws {
        try write("a.sh", header: "on=panel.open\non=clock.30")

        let scan = try scan

        XCTAssertEqual(scan.spots.map(\.id), ["a"])
        XCTAssertEqual(scan.spots.map(\.headerState.isOnGrid), [false])
        XCTAssertEqual(scan.metrics.map(\.read?.seconds), [30])
    }

    func testOldHeaderKeysHaveNoEffect() throws {
        try write("a.sh", header: "live=true\nsearch=live\nrecents=false\norder=last\ngrid=false\nrank=1")

        let command = try XCTUnwrap(try scan.spots.first)

        XCTAssertEqual(try scan.refused, [])
        XCTAssertEqual(command.mode, .once)
        XCTAssertEqual(command.kind, .launch)
        XCTAssertTrue(command.keepsRecent)
        XCTAssertTrue(command.isOnGrid)
        XCTAssertFalse(command.isGlobal)
    }

    func testASpotThatOffersSearchHasACardAndOffersRowsIsRefusedWithItsFix() throws {
        try write("a.sh", header: "on=panel.open\noffers=search")
        try write("b.sh", header: "on=panel.open\noffers=rows")

        XCTAssertEqual(try scan.spots.map(\.headerState.isOnGrid), [true])
        XCTAssertEqual(try scan.refused, [ScanResult.Refusal(file: "b", reason: "B offers rows, which Openspot no longer reads. Use offers=search, and the person hides its card")])
    }

    func testTheMainSearchNeedsAMomentOutsideTheSheet() throws {
        try write("a.sh", header: "on=panel.open\noffers=search")
        try write("c.sh", header: "on=clock.30\noffers=search")

        XCTAssertEqual(try scan.refused, [])
        XCTAssertEqual(try scan.spots.map(\.isGlobal), [true, true])
        XCTAssertEqual(try scan.spots.map(\.kind), [.list, .list])
    }

    func testANumberAsTheReadIsAMetricWhoseCardStartsOffTheGrid() throws {
        try write("cups.sh", header: "title=Cups\nicon=cup.and.saucer\non=clock.30")

        let scan = try scan
        let metric = try XCTUnwrap(scan.metrics.first)

        XCTAssertEqual(scan.spots.map(\.id), ["cups"])
        XCTAssertFalse(metric.headerState.isOnGrid)
        XCTAssertEqual(metric.id, "cups")
        XCTAssertEqual(metric.name, "Cups")
        XCTAssertEqual(metric.symbol, "cup.and.saucer")
        XCTAssertEqual(metric.read?.seconds, 30)
    }

    func testAMetricIsAlsoAList() throws {
        try write("pulls.sh", header: "on=clock.120")

        let scan = try scan

        XCTAssertEqual(scan.metrics.map(\.id), ["pulls"])
        XCTAssertEqual(scan.spots.map(\.id), ["pulls"])
        XCTAssertEqual(scan.spots.first?.kind, .list)
        XCTAssertEqual(scan.spots.first?.readsState, false)
    }

    func testTheNewestFileComesFirstAndTheFolderSetsTheRest() throws {
        for (name, day) in [("a", 1.0), ("b", 2.0), ("c", 3.0), ("d", 2.0)] {
            let url = try write("\(name).sh")
            try FileManager.default.setAttributes([.creationDate: Date(timeIntervalSince1970: day * 86_400)], ofItemAtPath: url.path)
        }

        XCTAssertEqual(try scan.spots.map(\.id), ["c", "b", "d", "a"])
    }

    func testAScriptThatAWidgetOpensHasNoCardOnTheGrid() throws {
        try write("details.sh", header: "on=panel.open")
        try write("other.sh", header: "on=panel.open")
        try write("cpu.sh", header: "on=clock.60")
        try "#!/bin/sh\n# title=Box\n# grid.square=cpu\n# to=details\n".writeScript(to: folder.spotFile("box"))

        let commands = try scan.spots

        XCTAssertEqual(commands.first { $0.id == "details" }?.isOnGrid, false)
        XCTAssertEqual(commands.first { $0.id == "other" }?.isOnGrid, true)
    }

    func testRefusesAHeaderWithAFault() throws {
        try write("a.sh", header: "read=sometimes")
        try write("b.sh", header: "mode=huge")
        try write("c.sh", header: "shortcut=ctrl+d")
        try write("f.sh", header: "offers=search")
        try write("h.sh", header: "on=sheet.open\noffers=search")
        try write("j.sh", header: "read=open")
        try write("k.sh", header: "read=click")
        try write("l.sh", header: "read=panel,later")

        XCTAssertEqual(try scan.files, [])
        XCTAssertEqual(try scan.refused, [
            ScanResult.Refusal(file: "a", reason: "A has read=sometimes, which Openspot no longer reads. Write an event, such as on=sheet.open"),
            ScanResult.Refusal(file: "b", reason: "B has an unknown mode: huge. Use once, stay or always"),
            ScanResult.Refusal(file: "c", reason: "C has shortcut, which Openspot no longer reads. The person gives each spot its letter in Edit Spots"),
            ScanResult.Refusal(file: "f", reason: "F needs on=panel.open or a clock, such as on=clock.60, to join the main search"),
            ScanResult.Refusal(file: "h", reason: "H needs on=panel.open or a clock, such as on=clock.60, to join the main search"),
            ScanResult.Refusal(file: "j", reason: "J has read=open, which Openspot no longer reads. Write an event, such as on=sheet.open"),
            ScanResult.Refusal(file: "k", reason: "K has read=click, which Openspot no longer reads. Write an event, such as on=sheet.open"),
            ScanResult.Refusal(file: "l", reason: "L has read=panel,later, which Openspot no longer reads. Write on=panel.open")
        ])
    }

    func testRefusesAnAnswersPatternThatIsNoneAndTakesOneThatStays() throws {
        try write("m.sh", header: "on=search.text [0-9")
        try write("n.sh", header: "on=search.text ^[0-9]\nmode=stay")
        try write("o.sh", header: "on=search.text ^[0-9]\nmode=always")

        XCTAssertEqual(try scan.spots.map(\.id), ["n", "o"])
        XCTAssertEqual(try scan.refused, [
            ScanResult.Refusal(file: "m", reason: "M has an unknown filter in on=search.text [0-9. Write a regular expression after the event, such as on=search.text ^[0-9]"),
        ])
    }

    func testASpotThatOnlyAnswersTheSearchHasNoCardAndIsNotFound() throws {
        try write("calc.sh", header: "on=search.text ^[0-9]")
        try write("dict.sh", header: "on=sheet.open\non=search.text ^define ")

        let commands = try scan.spots
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
        try write("one.sh", header: "on=panel.open", body: "touch '\(marker.path)'")
        try write("two.sh", body: "touch '\(marker.path)'")

        _ = try scan

        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testAConfigPathHoldsTheSpotsFolder() {
        let folder = SpotsFolder.standard(environment: ["OPENSPOT_CONFIG": "/tmp/debug"], home: URL(fileURLWithPath: "/home"))

        XCTAssertEqual(folder.url.path, "/tmp/debug/spots")
    }

    func testThePluginsFolderOfAnOlderOpenspotBecomesTheSpotsFolderOnce() throws {
        try write("config/plugins/weather.spot/weather.sh")
        try "How to build a spot.".write(to: folder.appendingPathComponent("config/plugins/AGENTS.md"), atomically: true, encoding: .utf8)
        let environment = ["OPENSPOT_CONFIG": folder.appendingPathComponent("config").path]

        let spots = SpotsFolder.standard(environment: environment, home: folder)

        XCTAssertEqual(try spots.scan().spots.map(\.id), ["weather"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("config/plugins").path))
        try write("config/plugins/other.spot/other.sh")
        _ = SpotsFolder.standard(environment: environment, home: folder)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("config/plugins/other.spot/other.sh").path))
    }

    func testASpotsPathBeatsAConfigPath() {
        let folder = SpotsFolder.standard(environment: ["OPENSPOT_CONFIG": "/tmp/debug", "OPENSPOT_SPOTS": "/tmp/own"], home: URL(fileURLWithPath: "/home"))

        XCTAssertEqual(folder.url.path, "/tmp/own")
    }

    func testWithNoPathTheHomeHoldsTheSpotsFolder() {
        let folder = SpotsFolder.standard(environment: [:], home: URL(fileURLWithPath: "/home"))

        XCTAssertEqual(folder.url.path, "/home/.config/openspot/spots")
    }

    func testAShortcutInTheHeaderIsRefusedBecauseThePersonGivesTheLetter() throws {
        try write("a.sh", header: "title=One\nshortcut=d")

        XCTAssertEqual(try scan.spots.map(\.id), [])
        XCTAssertEqual(try scan.refused, [ScanResult.Refusal(file: "a", reason: "One has shortcut, which Openspot no longer reads. The person gives each spot its letter in Edit Spots")])
    }
}
