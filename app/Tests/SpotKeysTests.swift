import XCTest
@testable import OpenspotCore

final class SpotKeysTests: XCTestCase {
    private func spot(_ toml: String, file: String = "script.sh", body: String = "#!/bin/sh\n") throws -> Spot {
        let url = try temporaryFolder().appendingPathComponent(file)
        try body.writeScript(to: url, toml: toml)
        let file = try SpotFile(file: url, id: url.deletingPathExtension().lastPathComponent)
        return try XCTUnwrap(file?.spots.first)
    }

    private func block(_ toml: String) throws -> TextBlock {
        try SpotToml(text: toml, folder: "/spots").block(of: "cups.sh")
    }

    func testAScriptWithCommandsHasNoCardOnTheGridAndStaysInTheScan() throws {
        let command = try spot("[commands.left]\ntitle = 'Left side'")

        XCTAssertFalse(command.headerState.isOnGrid)
    }

    func testEachOffersItemNamesOnePlaceAndASpotWithNoOffersOffersItsCard() throws {
        let all = try spot("on = ['panel.open', 'app.front']\noffers = ['card', 'search', 'menubar']")
        let float = try spot("on = ['sheet.open']\noffers = ['float']")
        let clock = try spot("on = ['clock.60']\noffers = ['card']")
        let none = try spot("on = ['sheet.open']")
        let search = try spot("on = ['panel.open']\noffers = ['search']")
        let nowhere = try spot("on = ['sheet.open']\noffers = ['none']")
        let window = try spot("on = ['sheet.open']\noffers = ['card', 'window']")

        XCTAssertEqual([all.offersCard, all.headerState.isOnGrid, all.isGlobal, all.showsValueInMenuBar, all.offersFloat], [true, true, true, true, false])
        XCTAssertEqual([float.offersCard, float.headerState.isOnGrid, float.isGlobal, float.showsValueInMenuBar, float.offersFloat], [false, false, false, false, true])
        XCTAssertEqual([clock.offersCard, clock.headerState.isOnGrid], [true, false])
        XCTAssertEqual([none.offersCard, none.headerState.isOnGrid, none.isGlobal, none.showsValueInMenuBar, none.offersFloat], [true, true, false, false, false])
        XCTAssertEqual([search.offersCard, search.headerState.isOnGrid, search.isGlobal], [false, false, true])
        XCTAssertTrue(search.isFound)
        XCTAssertEqual([nowhere.offersCard, nowhere.headerState.isOnGrid, nowhere.isGlobal, nowhere.showsValueInMenuBar, nowhere.offersFloat], [false, false, false, false, false])
        XCTAssertEqual([window.offersCard, window.offersWindow, nowhere.offersWindow], [true, true, false])
        XCTAssertThrowsError(try spot("on = ['sheet.open']\noffers = ['none', 'card']"))
    }

    func testACommandThatOffersActionsJoinsTheMenuOfEveryCardAndIsNoCommand() throws {
        let spot = try spot("title = 'Icon'\n[commands.change]\ntitle = 'Change Icon'\noffers = ['actions']\n[commands.reset]\ntitle = 'Reset'", file: "icon.sh")

        XCTAssertEqual(spot.offeredActions.map(\.action.id), ["change"])
        XCTAssertEqual(spot.offeredActions.first?.owner, "icon")
        XCTAssertEqual(spot.offeredActions.first?.group, "Icon")
        XCTAssertEqual(spot.offeredActions.first?.action.title, "Change Icon")
        XCTAssertEqual(spot.offeredActions.first?.origins, [])
        XCTAssertEqual(spot.offers.map(\.id), ["reset"])
        XCTAssertFalse(spot.offersCard)
    }

    func testACommandWhoseIDStartsWithAnOfferedCommandAndADotJoinsItsPlace() throws {
        let toml = "[commands.change]\ntitle = 'Change Icon'\noffers = ['actions mine']\n[commands.'change.draw']\ntitle = 'Draw…'\n[commands.\"other.go\"]\ntitle = 'Go'"

        let spot = try spot(toml, file: "icon.sh")

        XCTAssertEqual(spot.offeredActions.map(\.action.id), ["change", "change.draw"])
        XCTAssertEqual(spot.offeredActions.last?.origins, [.mine])
        XCTAssertEqual(spot.offers.map(\.id), ["other.go"])
    }

    func testAJavaScriptSpotNamesTheFunctionThatSaysWhetherAnActionShows() throws {
        let folder = try temporaryFolder().appendingPathComponent("icon.spot")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let reset = "title = 'Reset Icon'\noffers = ['actions']"
        let toml = "title = 'Icon'\n[commands.reset]\n\(reset)\nwhen = 'hasIcon'\n[scripts.shell.commands.reset]\n\(reset)\nwhen = 'hasIcon'\n[scripts.wrong.commands.reset]\n\(reset)\nwhen = 'has icon()'\n"
        try toml.write(to: folder.appendingPathComponent("spot.toml"), atomically: true, encoding: .utf8)
        let js = folder.appendingPathComponent("icon.js")
        try "function hasIcon(id) { return true }\n".write(to: js, atomically: true, encoding: .utf8)
        let shell = folder.appendingPathComponent("shell.sh")
        try "#!/bin/sh\n".writeScript(to: shell)
        let wrong = folder.appendingPathComponent("wrong.js")
        try "\n".write(to: wrong, atomically: true, encoding: .utf8)

        let spot = try XCTUnwrap(try SpotFile(file: js, id: "icon")?.spots.first)

        XCTAssertEqual(spot.offeredActions.first?.hooks[.when], "hasIcon")
        XCTAssertThrowsError(try SpotFile(file: shell, id: "shell")) { XCTAssertTrue((($0 as? SpotError)?.reason ?? "").contains("only a JavaScript spot"), "\($0)") }
        XCTAssertThrowsError(try SpotFile(file: wrong, id: "wrong")) { XCTAssertTrue((($0 as? SpotError)?.reason ?? "").contains("such as when=hasIcon"), "\($0)") }
    }

    func testAnActionsFilterNamesTheOriginsOfTheCardsItFits() throws {
        let spot = try spot("[commands.off]\ntitle = 'Turn off'\noffers = ['actions core, builtin']")

        XCTAssertEqual(spot.offeredActions.first?.origins, [.core, .builtIn])
    }

    func testActionsIsAPlaceOfACommandOnly() throws {
        let cases = [
            ("offers = ['actions']", "on a command"),
            ("[commands.go]\ntitle = 'Go'\noffers = ['card']", "offers=actions"),
            ("[commands.go]\ntitle = 'Go'\noffers = ['actions planets']", "mine, core or builtin"),
            ("[commands.go]\ntitle = 'Go'\noffers = ['actions']\n[commands.'go.far']\ntitle = 'Far'\noffers = ['actions']", "submenu of go")
        ]
        for (toml, hint) in cases {
            XCTAssertThrowsError(try spot(toml), toml) { error in
                XCTAssertTrue((error as? SpotError)?.reason.contains(hint) == true, "\(toml): \(error)")
            }
        }
    }

    func testAPlaceThatTheSpotCannotFillRefusesIt() throws {
        let cases = [
            ("offers = ['float']", "a sheet"),
            ("offers = ['window']", "a sheet"),
            ("on = ['sheet.open']\noffers = ['menubar']", "a clock"),
            ("offers = ['card, search']", "one place on each line")
        ]
        for (toml, hint) in cases {
            XCTAssertThrowsError(try spot(toml), toml) { error in
                XCTAssertTrue((error as? SpotError)?.reason.contains(hint) == true, "\(toml): \(error)")
            }
        }
    }

    func testPressOpenMakesAPressOfASpotWithASheetRunIt() throws {
        let run = try spot("on = ['sheet.open']\npress = 'open'")
        let open = try spot("on = ['sheet.open']")

        XCTAssertTrue(run.pressRuns)
        XCTAssertEqual(run.openTitle(hasItem: false), "Run")
        XCTAssertFalse(open.pressRuns)
        XCTAssertEqual(open.openTitle(hasItem: false), "Open")
        XCTAssertThrowsError(try spot("on = ['sheet.open']\npress = 'jump'")) { error in
            XCTAssertTrue((error as? SpotError)?.reason.contains("Use open or sheet") == true, "\(error)")
        }
    }

    func testAnUnknownPlaceRefusesTheSpot() throws {
        XCTAssertThrowsError(try spot("on = ['panel.open']\noffers = ['dock']")) { error in
            XCTAssertTrue((error as? SpotError)?.reason.contains("Use card, search, menubar, float, window or none") == true, "\(error)")
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

    func testAViewIsASwiftFileBesideTheScript() throws {
        let spot = try XCTUnwrap(try SpotFile(script: URL(fileURLWithPath: "/spots/home/cups.sh"), header: block("view = 'cups.swift'"), id: "home/cups").spots.first)

        XCTAssertEqual(spot.view, "/spots/home/cups.swift")
    }

    func testAnEditOfAViewChangesItsSpot() throws {
        let folder = try temporaryFolder()
        let view = folder.appendingPathComponent("cups.swift")
        try "".write(to: view, atomically: true, encoding: .utf8)
        let header = try block("view = 'cups.swift'")
        let script = folder.appendingPathComponent("cups.sh")
        let before = try SpotFile(script: script, header: header, id: "cups").spots.first

        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000_000)], ofItemAtPath: view.path)
        let after = try SpotFile(script: script, header: header, id: "cups").spots.first

        XCTAssertNotEqual(before, after)
    }

    func testAViewThatTheScanDoesNotWatchHasNoDate() throws {
        let folder = try temporaryFolder()
        let real = folder.appendingPathComponent("real.spot")
        let linked = folder.appendingPathComponent("linked.spot")
        try FileManager.default.createDirectory(at: real.appendingPathComponent("views"), withIntermediateDirectories: true)
        try "".write(to: real.appendingPathComponent("views/cups.swift"), atomically: true, encoding: .utf8)
        try "".write(to: real.appendingPathComponent("cups.swift"), atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: real)

        let deeper = try SpotFile(script: real.appendingPathComponent("cups.sh"), header: block("view = 'views/cups.swift'"), id: "cups").spots.first
        let throughLink = try SpotFile(script: linked.appendingPathComponent("cups.sh"), header: block("view = 'cups.swift'"), id: "cups").spots.first

        XCTAssertNil(deeper?.viewDate)
        XCTAssertNil(throughLink?.viewDate)
    }

    func testAnAnswersPatternIsTheWholeEvent() throws {
        let header = try block(#"on = ['search.text ^\s*([0-9,.]|(?i:today|now)\b)']"#)

        let spot = try XCTUnwrap(try SpotFile(script: URL(fileURLWithPath: "/spots/calc.sh"), header: header, id: "calc").spots.first)

        XCTAssertEqual(spot.answers?.text, #"^\s*([0-9,.]|(?i:today|now)\b)"#)
        XCTAssertEqual(["1,5", "Today", "notes"].map { spot.answers?.matches($0) }, [true, true, false])
    }

    func testAPictureOnTheWebKeepsItsURL() throws {
        let spot = try XCTUnwrap(try SpotFile(script: URL(fileURLWithPath: "/spots/home/cups.sh"), header: block("icon = 'https://example.com/cups.png'"), id: "home/cups").spots.first)

        XCTAssertEqual(spot.icon, .image("https://example.com/cups.png"))
    }

    func testAViewThatIsNoSwiftFileIsRefused() throws {
        let header = try block("title = 'Cups'\nview = 'cups.txt'")

        XCTAssertThrowsError(try SpotFile(script: URL(fileURLWithPath: "/spots/cups.sh"), header: header, id: "cups")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "Cups needs a Swift file for its view, such as view=cups.swift")
        }
    }

    func testASpotTomlOverItsLimitIsAFault() throws {
        let keywords = (0..<8000).map { "'word\($0)'" }.joined(separator: ", ")

        XCTAssertThrowsError(try spot("title = 'Huge'\nkeywords = [\(keywords)]", file: "huge.sh")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "Huge cannot load: spot.toml is over 64 KB. Keep it shorter.")
        }
    }

    func testAFrameCopiesNoHeader() throws {
        let spot = Spot(id: "a", name: "A", url: URL(fileURLWithPath: "/spots/a.sh"), read: .sheet, keywords: ["one", "two"])

        let framed = spot.taking(SpotOutput(text: "frame=\ntitle=Open\nrow=x\ntitle=X\n"))

        XCTAssertTrue(framed.header === spot.header)
        XCTAssertLessThan(MemoryLayout<Spot>.size, MemoryLayout<SpotFacts>.size / 2)
    }
}
