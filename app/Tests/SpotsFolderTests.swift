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
    private func write(_ path: String, toml: String = "", body: String = "", loose: Bool = false) throws -> URL {
        let url = folder.appendingPathComponent(loose || path.split(separator: "/").contains { $0.hasSuffix(".spot") } ? path : path.inSpotFolder)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\n\(body)\n".writeScript(to: url, toml: toml)
        try FileManager.default.setAttributes([.creationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: url.path)
        return url
    }

    private var opened: SpotsFolder {
        SpotsFolder.standard(environment: ["OPENSPOT_SPOTS": folder.path], home: folder.appendingPathComponent("home"))
    }

    private var scan: ScanResult {
        get throws { try SpotsFolder(url: folder).scan() }
    }

    func testTheStampStaysWhileNothingThatAScanReadsChanges() throws {
        try write("a.sh", toml: "title = 'A'")
        try write("home/b.sh", toml: "title = 'B'")
        let spots = SpotsFolder(url: folder)

        XCTAssertEqual(KeptScan().load(spots).stamp, KeptScan().load(spots).stamp)
    }

    func testTheStampChangesWithEachChangeOfAFileAndNotWithAChoice() throws {
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-linked-\(UUID().uuidString).sh")
        try "#!/bin/sh\n".writeScript(to: outside, toml: "title = 'L'")
        defer { try? FileManager.default.removeItem(at: outside) }
        let a = try write("a.sh", toml: "title = 'A'")
        try write("home/b.sh", toml: "title = 'B'")
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("linked.sh"), withDestinationURL: outside)
        let spots = SpotsFolder(url: folder)
        let kept = KeptScan()
        let changes: [(String, () throws -> Void)] = [
            ("an edit of the same size", { try "#!/bin/sh\necho z\n\n".write(to: a, atomically: false, encoding: .utf8) }),
            ("a mode", { try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: a.path) }),
            ("a new file in a subfolder", { try self.write("home/c.sh", toml: "title = 'C'") }),
            ("a rename", { try FileManager.default.moveItem(at: a, to: self.folder.appendingPathComponent("a.spot/d.sh")) }),
            ("a removed file", { try FileManager.default.removeItem(at: self.folder.appendingPathComponent("home.spot/b.sh")) }),
            ("an edit of a linked file", { try "#!/bin/sh\necho m\n".write(to: outside, atomically: false, encoding: .utf8) })
        ]

        for (change, make) in changes {
            let before = kept.load(spots).stamp
            try make()
            XCTAssertNotEqual(kept.load(spots).stamp, before, change)
        }
        XCTAssertEqual(kept.load(SpotsFolder(url: folder, core: folder, enabled: ["a"])).stamp, kept.load(SpotsFolder(url: folder, core: folder)).stamp)
    }

    func testAScanSeesANewFile() throws {
        try write("a.sh", toml: "title = 'A'")
        XCTAssertEqual(try scan.spots.map(\.name), ["A"])

        try write("home/b.sh", toml: "title = 'B'")

        XCTAssertEqual(try scan.spots.map(\.name), ["A", "B"])
    }

    func testAFolderReadAsCoreAndThenAsOwnKeepsItsSpots() throws {
        try write("a.sh", toml: "title = 'A'")
        _ = try SpotsFolder(url: folder.appendingPathComponent("own"), core: folder).scan()

        XCTAssertEqual(try scan.spots.map(\.name), ["A"])
    }

    func testCoreChoicesSeeANewCoreFile() throws {
        try write("a.spot/a.sh", toml: "title = 'A'")
        let spots = SpotsFolder(url: folder.appendingPathComponent("own"), core: folder)

        XCTAssertEqual(spots.coreChoices().map(\.name), ["A"])
        try write("b.spot/b.sh", toml: "title = 'B'")

        XCTAssertEqual(spots.coreChoices().map(\.name), ["A", "B"])
    }

    func testALoadParsesOnlyTheFolderThatChanged() throws {
        try write("a.sh", toml: "title = 'A'")
        let b = try write("b.sh", toml: "title = 'B'")
        let kept = KeptScan()
        let work = ScanWork()

        try ScanWork.$meter.withValue(work) {
            _ = kept.load(SpotsFolder(url: folder))
            XCTAssertEqual(work.parses, 2)
            _ = kept.load(SpotsFolder(url: folder))
            XCTAssertEqual(work.parses, 2)
            try "#!/bin/sh\necho c\n".write(to: b, atomically: false, encoding: .utf8)
            _ = kept.load(SpotsFolder(url: folder))
            XCTAssertEqual(work.parses, 3)
        }
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

    func testOpeningTheFolderWrapsALooseScriptWithItsReadmeIntoASpotFolder() throws {
        try write("weather.sh", loose: true)
        try "Shows the weather.".write(to: folder.appendingPathComponent("weather.md"), atomically: true, encoding: .utf8)
        try "notes".write(to: folder.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        XCTAssertEqual(try opened.scan().spots.map(\.id), ["weather"])

        let names = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("weather.spot").path).sorted()
        XCTAssertEqual(names, ["readme.md", "spot.toml", "weather.sh"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted(), ["notes.txt", "weather.spot"])
    }

    func testOpeningTheFolderWrapsAPlainFolderByItsName() throws {
        try write("home/coffee.sh", loose: true)

        XCTAssertEqual(try opened.scan().spots.map(\.id), ["home/coffee"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("home.spot/coffee.sh").path))
    }

    func testAWrapNeverReplacesAFileAndTheScanNamesTheClash() throws {
        try write("battery/battery.sh", body: "echo liquid", loose: true)
        try write("battery.sh", body: "echo metric", loose: true)
        try write("clock.sh", loose: true)

        XCTAssertNoThrow(try SpotsFolder.wrap(folder))
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
        _ = try write("core/openspot.spot/spots.sh", toml: "title = 'Spots'")
        _ = try write("core/apps.spot/apps.sh")
        let place = SpotsFolder(url: folder.appendingPathComponent("mine"), core: core)

        let spot = try XCTUnwrap(try place.scan().spots.first)

        XCTAssertEqual(try place.scan().spots.map(\.id), ["openspot/spots"])
        XCTAssertTrue(spot.isBuiltIn)
        XCTAssertFalse(place.isCore(spot))
        XCTAssertEqual(place.coreChoices().map(\.id), ["apps"])
        XCTAssertThrowsError(try place.remove(spot) { _ in XCTFail("It must not be discarded.") })
    }

    func testAFolderOfThePersonWithTheNameOfTheAppsSpotsIsRefused() throws {
        _ = try write("core/openspot.spot/spots.sh", toml: "title = 'Spots'")
        _ = try write("mine/openspot.spot/spots.sh", toml: "title = 'Mine'")
        _ = try write("mine/Openspot.spot/store.sh", toml: "title = 'Store'\nuses = ['account']")

        let scan = try SpotsFolder(url: folder.appendingPathComponent("mine"), core: folder.appendingPathComponent("core")).scan()

        XCTAssertEqual(scan.spots.map(\.name), ["Spots"])
        XCTAssertEqual(scan.spots.map(\.isBuiltIn), [true])
        XCTAssertEqual(Set(scan.refused.map(\.reason)), ["The folder `openspot.spot` has the name of Openspot's own spots, so Openspot does not load it. Give it another name, such as `my-openspot.spot`."])
        XCTAssertFalse(scan.refused.isEmpty)
    }

    func testAnExecutableIsASpotWithItsHeader() throws {
        try write("one.sh", toml: "title = 'First'\nicon = 'moon'\ndetail = 'Off'")

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
        try write("cup.sh", toml: "icon = 'icons/cup.png'")
        try write("safari.sh", toml: "icon = '/Applications/Safari.app'")
        try write("tea.sh", toml: "icon = '🍵'")

        let commands = try scan.spots
        let cup = try XCTUnwrap(commands.first { $0.id == "cup" })
        let safari = try XCTUnwrap(commands.first { $0.id == "safari" })
        let tea = try XCTUnwrap(commands.first { $0.id == "tea" })

        XCTAssertEqual(cup.icon, .image(cup.url.deletingLastPathComponent().appendingPathComponent("icons/cup.png").path))
        XCTAssertEqual(safari.icon, .file("/Applications/Safari.app"))
        XCTAssertNil(tea.fileIcon)
        XCTAssertEqual(tea.glyph, "🍵")
    }

    func testAScriptWithNoHeaderIsAWideSpotNamedAfterItsFile() throws {
        try write("say-hello_now.sh")

        let command = try XCTUnwrap(try scan.spots.first)

        XCTAssertEqual(command.name, "Say hello now")
        XCTAssertEqual(command.kind, .list)
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
        try write("a.sh", toml: "on = ['sheet.open']")
        try write("b.sh", toml: "on = ['panel.open']")
        try write("c.sh", toml: "on = ['panel.open']\noffers = ['search']")

        let commands = try scan.spots

        XCTAssertEqual(commands.map(\.kind), [.list, .list, .list])
        XCTAssertEqual(commands.map(\.readsState), [false, true, false])
        XCTAssertTrue(commands[2].isGlobal)
    }

    func testReadIsAListOfPlacesBesideItsSeconds() throws {
        try write("a.sh", toml: "on = ['panel.open', 'sheet.open', 'clock.30']")

        let read = try XCTUnwrap(try scan.spots.first?.read)

        XCTAssertEqual(read.moments, [.panel, .sheet, .every(30)])
        XCTAssertEqual(read.seconds, 30)
    }

    func testModeIsOnceOrStay() throws {
        try write("a.sh", toml: "mode = 'stay'")
        try write("c.sh", toml: "mode = 'once'")
        try write("d.sh", toml: "mode = 'sometimes'")

        let scan = try scan
        XCTAssertEqual(scan.spots.map(\.mode), [.stay, .once])
        XCTAssertEqual(scan.refused, [ScanResult.Refusal(file: "d", reason: "D has an unknown mode: sometimes. Use once or stay")])
    }

    func testAJavaScriptFileThatItsSpotTomlDescribesRunsInlineAndAnotherIsLeft() throws {
        for (name, toml) in [("sum", "title = 'Sum'"), ("plain", nil), ("stays", "mode = 'stay'")] {
            let file = folder.spotFile(name, extension: "js")
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "function main() { return '' }\n".write(to: file, atomically: true, encoding: .utf8)
            try toml?.write(to: file.deletingLastPathComponent().appendingPathComponent(SpotToml.fileName), atomically: true, encoding: .utf8)
        }

        let scan = try scan
        XCTAssertEqual(scan.spots.map(\.id), ["sum"])
        XCTAssertEqual(scan.spots.map(\.mode), [.inline])
        XCTAssertEqual(scan.refused, [
            ScanResult.Refusal(file: "stays", reason: "Stays is a .js file, which runs inline, so it takes no mode=stay"),
        ])
    }

    func testAnExecutableJavaScriptFileRunsAsAProcess() throws {
        try "#!/usr/bin/env node\nconsole.log('hi')\n".writeScript(to: folder.spotFile("node", extension: "js"), toml: "title = 'Node'\nmode = 'stay'")

        XCTAssertEqual(try scan.spots.map(\.mode), [.stay])
    }

    func testAHeaderKeepsTheFilesItsCardTakes() throws {
        try write("a.sh", toml: "drop = 'mov, mkv,folder'")
        try write("b.sh")

        XCTAssertEqual(try scan.spots.map(\.drop), [["mov", "mkv", "folder"], []])
    }

    func testANumberInAListOfMomentsStartsTheSpotOffTheGrid() throws {
        try write("a.sh", toml: "on = ['panel.open', 'clock.30']")

        let scan = try scan

        XCTAssertEqual(scan.spots.map(\.id), ["a"])
        XCTAssertEqual(scan.spots.map(\.headerState.isOnGrid), [false])
        XCTAssertEqual(scan.metrics.map(\.read?.seconds), [30])
    }

    func testASpotThatOffersSearchAndCardHasACard() throws {
        try write("a.sh", toml: "on = ['panel.open']\noffers = ['search']")

        XCTAssertEqual(try scan.spots.map(\.headerState.isOnGrid), [true])
    }

    func testTheMainSearchNeedsAMomentOutsideTheSheet() throws {
        try write("a.sh", toml: "on = ['panel.open']\noffers = ['search']")
        try write("c.sh", toml: "on = ['clock.30']\noffers = ['search']")

        XCTAssertEqual(try scan.refused, [])
        XCTAssertEqual(try scan.spots.map(\.isGlobal), [true, true])
        XCTAssertEqual(try scan.spots.map(\.kind), [.list, .list])
    }

    func testANumberAsTheReadIsAMetricWhoseCardStartsOffTheGrid() throws {
        try write("cups.sh", toml: "title = 'Cups'\nicon = 'cup.and.saucer'\non = ['clock.30']")

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
        try write("pulls.sh", toml: "on = ['clock.120']")

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

    func testRefusesAHeaderWithAFault() throws {
        try write("b.sh", toml: "mode = 'huge'")
        try write("f.sh", toml: "offers = ['search']")

        XCTAssertEqual(try scan.files, [])
        XCTAssertEqual(try scan.refused, [
            ScanResult.Refusal(file: "b", reason: "B has an unknown mode: huge. Use once or stay"),
            ScanResult.Refusal(file: "f", reason: "F needs on=panel.open, on=sheet.open or a clock, such as on=clock.60, to join the main search")
        ])
    }

    func testRefusesAnAnswersPatternThatIsNoneAndTakesOneThatStays() throws {
        try write("m.sh", toml: "on = ['search.text [0-9']")
        try write("n.sh", toml: "on = ['search.text ^[0-9]']\nmode = 'stay'")
        try write("o.sh", toml: "on = ['search.text ^[0-9]', 'app.launch']\nmode = 'stay'")

        XCTAssertEqual(try scan.spots.map(\.id), ["n", "o"])
        XCTAssertEqual(try scan.refused, [
            ScanResult.Refusal(file: "m", reason: "M has an unknown filter in on=search.text [0-9. Write a regular expression after the event, such as on=search.text ^[0-9]"),
        ])
    }

    func testASpotThatOnlyAnswersTheSearchHasNoCardAndIsNotFound() throws {
        try write("calc.sh", toml: "on = ['search.text ^[0-9]']")
        try write("dict.sh", toml: "on = ['sheet.open', 'search.text ^define ']")

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
        try write("one.sh", toml: "on = ['panel.open']", body: "touch '\(marker.path)'")
        try write("two.sh", body: "touch '\(marker.path)'")

        _ = try scan

        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testAConfigPathHoldsTheSpotsFolder() {
        let folder = SpotsFolder.standard(environment: ["OPENSPOT_CONFIG": "/tmp/debug"], home: URL(fileURLWithPath: "/home"))

        XCTAssertEqual(folder.url.path, "/tmp/debug/spots")
    }

    func testASpotsPathBeatsAConfigPath() {
        let folder = SpotsFolder.standard(environment: ["OPENSPOT_CONFIG": "/tmp/debug", "OPENSPOT_SPOTS": "/tmp/own"], home: URL(fileURLWithPath: "/home"))

        XCTAssertEqual(folder.url.path, "/tmp/own")
    }

    func testWithNoPathTheHomeHoldsTheSpotsFolder() {
        let folder = SpotsFolder.standard(environment: [:], home: URL(fileURLWithPath: "/home"))

        XCTAssertEqual(folder.url.path, "/home/.config/openspot/spots")
    }


    func testALoadOverItsLimitKeepsEachFolderItReads() throws {
        for name in ["a", "b", "c"] { try write("\(name).sh", toml: "title = '\(name)'") }
        let kept = KeptScan(limit: 2)
        let work = ScanWork()

        ScanWork.$meter.withValue(work) {
            _ = kept.load(SpotsFolder(url: folder))
            _ = kept.load(SpotsFolder(url: folder))
        }

        XCTAssertEqual(work.parses, 3)
    }
}
