import XCTest
@testable import OpenspotCore

final class SpotKeysTests: XCTestCase {
    private func spot(_ toml: String, file: String = "script.sh", body: String = "#!/bin/sh\n", isApp: Bool = false) throws -> Spot {
        let url = try temporaryFolder().appendingPathComponent(file)
        try body.writeScript(to: url, toml: toml)
        let file = try SpotFile(file: url, id: url.deletingPathExtension().lastPathComponent, isApp: isApp)
        return try XCTUnwrap(file?.spots.first)
    }

    private func manifest(_ toml: String) throws -> Manifest {
        try Manifest(text: toml, folder: "/spots").script("cups.sh")
    }

    func testAScriptWithCommandsHasNoCardOnTheGridAndStaysInTheScan() throws {
        let command = try spot("[actions.left]\ntitle = 'Left side'")

        XCTAssertFalse(command.headerState.isOnGrid)
    }

    func testASpotThatListsInTheMainSearchAndASpotWithNoTriggerStartOnTheGrid() throws {
        let search = try spot("[on]\n\"panel.open\" = true\nsearch = true")
        let plain = try spot("")
        let clock = try spot("[on]\nevery = 60")

        XCTAssertEqual([search.triggers.lists, search.isFound, search.headerState.isOnGrid], [true, true, true])
        XCTAssertEqual([plain.triggers.lists, plain.isFound, plain.headerState.isOnGrid], [false, true, true])
        XCTAssertEqual([clock.isFound, clock.headerState.isOnGrid], [true, false])
    }

    func testACommandThatOffersActionsJoinsTheMenuOfEveryCardAndIsNoCommand() throws {
        let spot = try spot("title = 'Icon'\n[actions.change]\ntitle = 'Change Icon'\noffers = ['actions']\n[actions.reset]\ntitle = 'Reset'", file: "icon.sh", isApp: true)

        XCTAssertEqual(spot.offeredActions.map(\.action.id), ["change"])
        XCTAssertEqual(spot.offeredActions.first?.owner, "icon")
        XCTAssertEqual(spot.offeredActions.first?.group, "Icon")
        XCTAssertEqual(spot.offeredActions.first?.action.title, "Change Icon")
        XCTAssertEqual(spot.offeredActions.first?.origins, [])
        XCTAssertEqual(spot.offers.map(\.id), ["reset"])
        XCTAssertFalse(spot.isFound)
    }

    func testACommandWhoseIDStartsWithAnOfferedCommandAndADotJoinsItsPlace() throws {
        let toml = "[actions.change]\ntitle = 'Change Icon'\noffers = ['actions mine']\n[actions.'change.draw']\ntitle = 'Draw…'\n[actions.\"other.go\"]\ntitle = 'Go'"

        let spot = try spot(toml, file: "icon.sh", isApp: true)

        XCTAssertEqual(spot.offeredActions.map(\.action.id), ["change", "change.draw"])
        XCTAssertEqual(spot.offeredActions.last?.origins, [.mine])
        XCTAssertEqual(spot.offers.map(\.id), ["other.go"])
    }

    func testAJavaScriptSpotNamesTheHandlerThatSaysWhetherAnActionShows() throws {
        let folder = try temporaryFolder().appendingPathComponent("icon.spot")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let reset = "title = 'Reset Icon'\noffers = ['actions']"
        let toml = "title = 'Icon'\n[actions.reset]\n\(reset)\nwhen = 'hasIcon'\n[scripts.shell.actions.reset]\n\(reset)\nwhen = 'hasIcon'\n[scripts.wrong.actions.reset]\n\(reset)\nwhen = 'has icon()'\n"
        try toml.write(to: folder.appendingPathComponent("spot.toml"), atomically: true, encoding: .utf8)
        let js = folder.appendingPathComponent("icon.js")
        try "export default { hasIcon() { return true } }\n".write(to: js, atomically: true, encoding: .utf8)
        let shell = folder.appendingPathComponent("shell.sh")
        try "#!/bin/sh\n".writeScript(to: shell)
        let wrong = folder.appendingPathComponent("wrong.js")
        try "\n".write(to: wrong, atomically: true, encoding: .utf8)

        let spot = try XCTUnwrap(try SpotFile(file: js, id: "icon", isApp: true)?.spots.first)

        XCTAssertEqual(spot.offeredActions.first?.when, "hasIcon")
        XCTAssertThrowsError(try SpotFile(file: shell, id: "shell", isApp: true)) { XCTAssertTrue((($0 as? SpotError)?.reason ?? "").contains("only a JavaScript spot"), "\($0)") }
        XCTAssertThrowsError(try SpotFile(file: wrong, id: "wrong", isApp: true)) { XCTAssertTrue((($0 as? SpotError)?.reason ?? "").contains("such as when = \"hasIcon\""), "\($0)") }
    }

    func testAnActionsFilterNamesTheOriginsOfTheCardsItFits() throws {
        let spot = try spot("[actions.off]\ntitle = 'Turn off'\noffers = ['actions core, builtin']", isApp: true)

        XCTAssertEqual(spot.offeredActions.first?.origins, [.core, .builtIn])
    }

    func testActionsIsAPlaceOfAnActionOfTheAppOnly() throws {
        let cases = [
            ("offers = ['actions']", "unknown key in its spot.toml: offers"),
            ("[actions.go]\ntitle = 'Go'\noffers = ['card']", "offers = [\"actions\"]"),
            ("[actions.go]\ntitle = 'Go'\noffers = ['actions planets']", "mine, core or builtin"),
            ("[actions.go]\ntitle = 'Go'\noffers = ['actions']\n[actions.'go.far']\ntitle = 'Far'\noffers = ['actions']", "submenu of go")
        ]
        XCTAssertThrowsError(try spot("[actions.go]\ntitle = 'Go'\noffers = ['actions']")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "Script has an unknown key in [actions.go]: offers")
        }
        for (toml, hint) in cases {
            XCTAssertThrowsError(try spot(toml, isApp: true), toml) { error in
                XCTAssertTrue((error as? SpotError)?.reason.contains(hint) == true, "\(toml): \(error)")
            }
        }
    }

    func testASpotThatOffersSearchWithNoReadingEventReadsAtEachOpenOfItsSheet() throws {
        for toml in ["[on]\nsearch = true", "[on]\n\"clipboard.change\" = true\nsearch = true"] {
            let spot = try spot(toml)

            XCTAssertEqual(spot.showsInSheet, true, toml)
            XCTAssertTrue(spot.showsOfferedItems, toml)
        }
    }

    func testASearchThatListsShowsItsListInASheetOnlyWithNoPanelOpenAndNoEvery() throws {
        for toml in ["[on]\nsearch = true\n\"panel.open\" = true", "[on]\nsearch = true\nevery = 60"] {
            let spot = try spot(toml)

            XCTAssertFalse(spot.showsOfferedItems, toml)
            XCTAssertFalse(spot.showsInSheet, toml)
        }
    }

    func testEachKeywordFindsTheSpot() throws {
        let spot = try spot("title = 'Timer'\nkeywords = ['countdown', 'pomodoro timer']")

        XCTAssertEqual(spot.keywords, ["countdown", "pomodoro timer"])
    }

    func testACommentHeaderInTheScriptIsOrdinaryText() throws {
        let spot = try spot("", file: "morning.sh", body: "#!/bin/sh\n# title=Evening\n# icon=sun.max\nsay hello\n")

        XCTAssertEqual(spot.name, "Morning")
        XCTAssertNil(spot.icon)
    }

    func testAnEditOfAViewChangesItsSpot() throws {
        let folder = try temporaryFolder()
        let view = folder.appendingPathComponent("cups.swift")
        try "".write(to: view, atomically: true, encoding: .utf8)
        let manifest = try manifest("views = ['cups.swift']")
        let script = folder.appendingPathComponent("cups.sh")
        let before = try SpotFile(script: script, manifest: manifest, id: "cups").spots.first

        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000_000)], ofItemAtPath: view.path)
        let after = try SpotFile(script: script, manifest: manifest, id: "cups").spots.first

        XCTAssertNotEqual(before, after)
        XCTAssertEqual(after?.viewDates[view.path], Date(timeIntervalSince1970: 1_000_000))
    }

    func testAViewThatTheScanDoesNotWatchHasNoDate() throws {
        let folder = try temporaryFolder()
        let real = folder.appendingPathComponent("real.spot")
        let linked = folder.appendingPathComponent("linked.spot")
        try FileManager.default.createDirectory(at: real.appendingPathComponent("views"), withIntermediateDirectories: true)
        try "".write(to: real.appendingPathComponent("views/cups.swift"), atomically: true, encoding: .utf8)
        try "".write(to: real.appendingPathComponent("cups.swift"), atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: real)

        let deeper = try SpotFile(script: real.appendingPathComponent("cups.sh"), manifest: manifest("views = ['views/cups.swift']"), id: "cups").spots.first
        let throughLink = try SpotFile(script: linked.appendingPathComponent("cups.sh"), manifest: manifest("views = ['cups.swift']"), id: "cups").spots.first

        XCTAssertEqual(deeper?.viewDates, [:])
        XCTAssertEqual(throughLink?.viewDates, [:])
    }

    func testTheOldViewKeyKeepsTheSpotFromLoading() {
        XCTAssertThrowsError(try spot("view = 'cups.swift'"))
    }

    func testAnAnswersPatternIsTheWholeEvent() throws {
        let manifest = try manifest(#"[on]\#nsearch = '^\s*([0-9,.]|(?i:today|now)\b)'"#)

        let spot = try XCTUnwrap(try SpotFile(script: URL(fileURLWithPath: "/spots/calc.sh"), manifest: manifest, id: "calc").spots.first)

        XCTAssertEqual(spot.triggers.search?.text, #"^\s*([0-9,.]|(?i:today|now)\b)"#)
        XCTAssertEqual(["1,5", "Today", "notes"].map { spot.triggers.search?.matches($0) }, [true, true, false])
    }

    func testAPictureOnTheWebKeepsItsURL() throws {
        let spot = try XCTUnwrap(try SpotFile(script: URL(fileURLWithPath: "/spots/home/cups.sh"), manifest: manifest("icon = 'https://example.com/cups.png'"), id: "home/cups").spots.first)

        XCTAssertEqual(spot.icon, .image("https://example.com/cups.png"))
    }

    func testEachFileOfViewsIsAKindNamedByItsStem() throws {
        let spot = try XCTUnwrap(try SpotFile(script: URL(fileURLWithPath: "/spots/cups.sh"), manifest: manifest("title = 'Cups'\nviews = ['liquid.swift', 'parts/dial.swift']"), id: "cups").spots.first)

        XCTAssertEqual(spot.views, ["liquid": "/spots/liquid.swift", "dial": "/spots/parts/dial.swift"])
        XCTAssertEqual(spot.kinds.count, BlockKind.all.count + 2)
    }

    func testAViewsFileThatIsNoSwiftFileIsRefused() throws {
        let manifest = try manifest("title = 'Cups'\nviews = ['liquid.txt']")

        XCTAssertThrowsError(try SpotFile(script: URL(fileURLWithPath: "/spots/cups.sh"), manifest: manifest, id: "cups")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "Cups needs a Swift file for each of its views, such as views = [\"liquid.swift\"]")
        }
    }

    func testASpotTomlOverItsLimitIsAFault() throws {
        let keywords = (0..<8000).map { "'word\($0)'" }.joined(separator: ", ")

        XCTAssertThrowsError(try spot("title = 'Huge'\nkeywords = [\(keywords)]", file: "huge.sh")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "Huge cannot load: spot.toml is over 64 KB. Keep it shorter.")
        }
    }

    func testAFrameCopiesNoHeader() throws {
        let spot = Spot(id: "a", name: "A", url: URL(fileURLWithPath: "/spots/a.sh"), triggers: .sheet, keywords: ["one", "two"])

        let framed = spot.taking(Frame(text: "frame=\ntitle=Open\ntext=x\ntitle=X\n"))

        XCTAssertTrue(framed.header === spot.header)
        XCTAssertLessThan(MemoryLayout<Spot>.size, MemoryLayout<SpotFacts>.size / 2)
    }
}
