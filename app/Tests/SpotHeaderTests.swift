import XCTest
@testable import OpenspotCore

final class SpotHeaderTests: XCTestCase {
    func testAScriptWithCommandsHasNoCardOnTheGridAndStaysInTheScan() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-grid-\(UUID().uuidString)")
        try Data("#!/bin/sh\n#\n# button=left\n# title=Left side\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        defer { try? FileManager.default.removeItem(at: url) }

        let command = try XCTUnwrap(try SpotFile(file: url, id: "script")?.spots.first)

        XCTAssertFalse(command.headerState.isOnGrid)
    }

    func testEachOffersLineNamesOnePlaceAndASpotWithNoLineOffersItsCard() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-places-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        func spot(_ header: String) throws -> Spot {
            let url = folder.appendingPathComponent("\(UUID().uuidString).sh")
            try "#!/bin/sh\n\(header)".writeScript(to: url)
            return try XCTUnwrap(try SpotFile(file: url, id: url.lastPathComponent)?.spots.first)
        }

        let all = try spot("# on=panel.open\n# on=app.front\n# offers=card\n# offers=search\n# offers=menubar\n")
        let float = try spot("# on=sheet.open\n# offers=float\n")
        let clock = try spot("# on=clock.60\n# offers=card\n")
        let none = try spot("# on=sheet.open\n")
        let search = try spot("# on=panel.open\n# offers=search\n")
        let nowhere = try spot("# on=sheet.open\n# offers=none\n")

        XCTAssertEqual([all.offersCard, all.headerState.isOnGrid, all.isGlobal, all.canShowInMenuBar, all.offersFloat], [true, true, true, true, false])
        XCTAssertEqual([float.offersCard, float.headerState.isOnGrid, float.isGlobal, float.canShowInMenuBar, float.offersFloat], [false, false, false, false, true])
        XCTAssertEqual([clock.offersCard, clock.headerState.isOnGrid], [true, false])
        XCTAssertEqual([none.offersCard, none.headerState.isOnGrid, none.isGlobal, none.canShowInMenuBar, none.offersFloat], [true, true, false, false, false])
        XCTAssertEqual([search.offersCard, search.headerState.isOnGrid, search.isGlobal], [false, false, true])
        XCTAssertTrue(search.isFound)
        XCTAssertEqual([nowhere.offersCard, nowhere.headerState.isOnGrid, nowhere.isGlobal, nowhere.canShowInMenuBar, nowhere.offersFloat], [false, false, false, false, false])
        let both = folder.appendingPathComponent("both.sh")
        try "#!/bin/sh\n# on=sheet.open\n# offers=none\n# offers=card\n".writeScript(to: both)
        XCTAssertThrowsError(try SpotFile(file: both, id: "both"))
    }

    func testAButtonThatOffersActionsJoinsTheMenuOfEveryCardAndIsNoCommand() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-actions-\(UUID().uuidString)")
        try "#!/bin/sh\n# title=Icon\n#\n# button=change\n# title=Change Icon\n# offers=actions\n#\n# button=reset\n# title=Reset\n".writeScript(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let spot = try XCTUnwrap(try SpotFile(file: url, id: "icon")?.spots.first)

        XCTAssertEqual(spot.offeredActions.map(\.action.id), ["change"])
        XCTAssertEqual(spot.offeredActions.first?.owner, "icon")
        XCTAssertEqual(spot.offeredActions.first?.group, "Icon")
        XCTAssertEqual(spot.offeredActions.first?.action.title, "Change Icon")
        XCTAssertEqual(spot.offeredActions.first?.origins, [])
        XCTAssertEqual(spot.offers.map(\.id), ["reset"])
        XCTAssertFalse(spot.offersCard)
    }

    func testAButtonWhoseIDStartsWithAnOfferedButtonAndADotJoinsItsPlace() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-actions-\(UUID().uuidString)")
        try "#!/bin/sh\n#\n# button=change\n# title=Change Icon\n# offers=actions mine\n#\n# button=change.draw\n# title=Draw…\n#\n# button=other.go\n# title=Go\n".writeScript(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let spot = try XCTUnwrap(try SpotFile(file: url, id: "icon")?.spots.first)

        XCTAssertEqual(spot.offeredActions.map(\.action.id), ["change", "change.draw"])
        XCTAssertEqual(spot.offeredActions.last?.origins, [.mine])
        XCTAssertEqual(spot.offers.map(\.id), ["other.go"])
    }

    func testAJavaScriptSpotNamesTheFunctionThatSaysWhetherAnActionShows() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-when-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let js = folder.appendingPathComponent("icon.js")
        try "// title=Icon\n//\n// button=reset\n// title=Reset Icon\n// offers=actions\n// when=hasIcon\nfunction hasIcon(id) { return true }\n".write(to: js, atomically: true, encoding: .utf8)
        let shell = folder.appendingPathComponent("icon.sh")
        try "#!/bin/sh\n#\n# button=reset\n# title=Reset Icon\n# offers=actions\n# when=hasIcon\n".writeScript(to: shell)
        let wrong = folder.appendingPathComponent("wrong.js")
        try "// title=Icon\n//\n// button=reset\n// title=Reset Icon\n// offers=actions\n// when=has icon()\n".write(to: wrong, atomically: true, encoding: .utf8)

        let spot = try XCTUnwrap(try SpotFile(file: js, id: "icon")?.spots.first)

        XCTAssertEqual(spot.offeredActions.first?.when, "hasIcon")
        XCTAssertThrowsError(try SpotFile(file: shell, id: "shell")) { XCTAssertTrue((($0 as? SpotError)?.reason ?? "").contains("only a JavaScript spot"), "\($0)") }
        XCTAssertThrowsError(try SpotFile(file: wrong, id: "wrong")) { XCTAssertTrue((($0 as? SpotError)?.reason ?? "").contains("such as when=hasIcon"), "\($0)") }
    }

    func testAnActionsFilterNamesTheOriginsOfTheCardsItFits() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-actions-\(UUID().uuidString)")
        try "#!/bin/sh\n#\n# button=off\n# title=Turn off\n# offers=actions core, builtin\n".writeScript(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let spot = try XCTUnwrap(try SpotFile(file: url, id: "tools")?.spots.first)

        XCTAssertEqual(spot.offeredActions.first?.origins, [.core, .builtIn])
    }

    func testActionsIsAPlaceOfAButtonOnly() throws {
        let cases = [
            ("# offers=actions\n", "a button"),
            ("#\n# button=go\n# title=Go\n# offers=card\n", "offers=actions"),
            ("#\n# button=go\n# title=Go\n# offers=actions planets\n", "mine, core or builtin"),
            ("#\n# button=go\n# title=Go\n# offers=actions\n#\n# button=go.far\n# title=Far\n# offers=actions\n", "submenu of go")
        ]
        for (header, hint) in cases {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-actions-\(UUID().uuidString)")
            try "#!/bin/sh\n\(header)".writeScript(to: url)
            defer { try? FileManager.default.removeItem(at: url) }

            XCTAssertThrowsError(try SpotFile(file: url, id: "script"), header) { error in
                XCTAssertTrue((error as? SpotError)?.reason.contains(hint) == true, "\(header): \(error)")
            }
        }
    }

    func testAPlaceThatTheSpotCannotFillRefusesIt() throws {
        let cases = [
            ("# offers=float\n", "a sheet"),
            ("# on=sheet.open\n# offers=menubar\n", "a clock"),
            ("# offers=card, search\n", "one place on each line")
        ]
        for (header, hint) in cases {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-place-\(UUID().uuidString)")
            try "#!/bin/sh\n\(header)".writeScript(to: url)
            defer { try? FileManager.default.removeItem(at: url) }

            XCTAssertThrowsError(try SpotFile(file: url, id: "script"), header) { error in
                XCTAssertTrue((error as? SpotError)?.reason.contains(hint) == true, "\(header): \(error)")
            }
        }
    }

    func testPressOpenMakesAPressOfASpotWithASheetRunIt() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-press-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let runs = folder.appendingPathComponent("runs.sh"), opens = folder.appendingPathComponent("opens.sh")
        let unknown = folder.appendingPathComponent("unknown.sh")
        try "#!/bin/sh\n# on=sheet.open\n# press=open\n".writeScript(to: runs)
        try "#!/bin/sh\n# on=sheet.open\n".writeScript(to: opens)
        try "#!/bin/sh\n# on=sheet.open\n# press=jump\n".writeScript(to: unknown)

        let run = try XCTUnwrap(try SpotFile(file: runs, id: "runs")?.spots.first)
        let open = try XCTUnwrap(try SpotFile(file: opens, id: "opens")?.spots.first)

        XCTAssertTrue(run.pressRuns)
        XCTAssertEqual(run.openTitle(hasItem: false), "Run")
        XCTAssertFalse(open.pressRuns)
        XCTAssertEqual(open.openTitle(hasItem: false), "Open")
        XCTAssertThrowsError(try SpotFile(file: unknown, id: "unknown")) { error in
            XCTAssertTrue((error as? SpotError)?.reason.contains("Use open or sheet") == true, "\(error)")
        }
    }

    func testAnUnknownPlaceRefusesTheSpot() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-place-\(UUID().uuidString)")
        try "#!/bin/sh\n# on=panel.open\n# offers=dock\n".writeScript(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try SpotFile(file: url, id: "script")) { error in
            XCTAssertTrue((error as? SpotError)?.reason.contains("Use card, search, menubar, float or none") == true, "\(error)")
        }
    }

    func testGlobalFloatAndTrayRefuseTheSpotAndNameTheirNewWay() throws {
        let cases = [
            ("on=panel.open\n# global=true", "offers=search"),
            ("on=panel.open\n# global=rows", "offers=search"),
            ("on=sheet.open\n# float=true", "offers=float"),
            ("on=clock.60\n# tray=true", "offers=menubar")
        ]
        for (header, hint) in cases {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-old-\(UUID().uuidString)")
            try "#!/bin/sh\n# \(header)\n".writeScript(to: url)
            defer { try? FileManager.default.removeItem(at: url) }

            XCTAssertThrowsError(try SpotFile(file: url, id: "script"), header) { error in
                XCTAssertTrue((error as? SpotError)?.reason.contains(hint) == true, "\(header): \(error)")
            }
        }
    }

    func testEachKeywordOfTheHeaderFindsTheSpot() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-keyword-\(UUID().uuidString)")
        try "#!/bin/sh\n# title=Timer\n# keywords=countdown,  pomodoro timer , ,\n".writeScript(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let spot = try XCTUnwrap(try SpotFile(file: url, id: "timer")?.spots.first)

        XCTAssertEqual(spot.keywords, ["countdown", "pomodoro timer"])
    }

    func testASizeLineRefusesTheSpotAndNamesItsFix() throws {
        for header in ["title=Timer\n# size=small", "title=Timer\n# grid.small=cpu\n# size=small"] {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-size-\(UUID().uuidString)")
            try "#!/bin/sh\n# \(header)\n".writeScript(to: url)
            defer { try? FileManager.default.removeItem(at: url) }

            XCTAssertThrowsError(try SpotFile(file: url, id: "timer"), header) { error in
                XCTAssertEqual((error as? SpotError)?.reason, "Timer has size=small, which Openspot no longer reads. Openspot sizes a card by the person's choice, so remove it", header)
            }
        }
    }

    func testAKeywordLineRefusesTheSpotAndNamesTheList() throws {
        for header in ["title=Timer\n# keyword=countdown", "grid.small=cpu\n# keyword=load"] {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-keyword-\(UUID().uuidString)")
            try "#!/bin/sh\n# \(header)\n".writeScript(to: url)
            defer { try? FileManager.default.removeItem(at: url) }

            XCTAssertThrowsError(try SpotFile(file: url, id: "timer"), header) { error in
                XCTAssertTrue((error as? SpotError)?.reason.contains("Write keywords=a, b") == true, "\(header): \(error)")
            }
        }
    }

    func testReadsTheCommentLinesUnderTheFirstLine() {
        let header = SpotHeader(text: "#!/bin/sh\n# title=Morning\n#\n# Prose has no key.\n#icon=sun.max\nsay hello\n# shortcut=m\n")

        XCTAssertEqual(header.block.value("title"), "Morning")
        XCTAssertEqual(header.block.value("icon"), "sun.max")
        XCTAssertNil(header.block.value("shortcut"))
    }

    func testReadsTheCommentsOfOtherLanguages() {
        XCTAssertEqual(SpotHeader(text: "#!/usr/bin/env lua\n-- on=clock.5\nprint(1)").block.value("on"), "clock.5")
        XCTAssertEqual(SpotHeader(text: "#!/usr/bin/env bun\n// on=clock.5\nconsole.log(1)").block.value("on"), "clock.5")
    }

    func testAProgramHasNoHeader() {
        XCTAssertEqual(SpotHeader(text: "\u{7F}ELF\u{0}\u{0}\n# title=Lost").block.fields, [])
    }

    func testABlankLineEndsTheHeader() {
        XCTAssertNil(SpotHeader(text: "#!/bin/sh\n\n# title=Late\n").block.value("title"))
    }

    func testAViewIsASwiftFileBesideTheScript() throws {
        let folder = URL(fileURLWithPath: "/spots/home")
        let header = SpotHeader(text: "#!/bin/sh\n# view=cups.swift\n").block

        let spot = try XCTUnwrap(try SpotFile(script: folder.appendingPathComponent("cups.sh"), header: header, id: "home/cups").spots.first)

        XCTAssertEqual(spot.view, "/spots/home/cups.swift")
    }

    func testAnEditOfAViewChangesItsSpot() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-view-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let view = folder.appendingPathComponent("cups.swift")
        try "".write(to: view, atomically: true, encoding: .utf8)
        let header = SpotHeader(text: "#!/bin/sh\n# view=cups.swift\n").block
        let script = folder.appendingPathComponent("cups.sh")
        let before = try SpotFile(script: script, header: header, id: "cups").spots.first

        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000_000)], ofItemAtPath: view.path)
        let after = try SpotFile(script: script, header: header, id: "cups").spots.first

        XCTAssertNotEqual(before, after)
    }

    func testAnEditOfTheLibraryBesideAViewChangesItsSpot() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-view-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try "".write(to: folder.appendingPathComponent("cups.swift"), atomically: true, encoding: .utf8)
        let library = folder.appendingPathComponent("cups.view")
        try "".write(to: library, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000_000)], ofItemAtPath: library.path)
        let header = SpotHeader(text: "#!/bin/sh\n# view=cups.swift\n").block
        let script = folder.appendingPathComponent("cups.sh")
        let before = try SpotFile(script: script, header: header, id: "cups").spots.first

        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: library.path)
        let after = try SpotFile(script: script, header: header, id: "cups").spots.first

        XCTAssertNotEqual(before, after)
    }

    func testAViewThatTheScanDoesNotWatchHasNoDate() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-view-\(UUID().uuidString)")
        let real = folder.appendingPathComponent("real.spot")
        let linked = folder.appendingPathComponent("linked.spot")
        try FileManager.default.createDirectory(at: real.appendingPathComponent("views"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try "".write(to: real.appendingPathComponent("views/cups.swift"), atomically: true, encoding: .utf8)
        try "".write(to: real.appendingPathComponent("cups.swift"), atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: real)

        let deeper = try SpotFile(script: real.appendingPathComponent("cups.sh"), header: SpotHeader(text: "#!/bin/sh\n# view=views/cups.swift\n").block, id: "cups").spots.first
        let throughLink = try SpotFile(script: linked.appendingPathComponent("cups.sh"), header: SpotHeader(text: "#!/bin/sh\n# view=cups.swift\n").block, id: "cups").spots.first

        XCTAssertNil(deeper?.viewDate)
        XCTAssertNil(throughLink?.viewDate)
    }

    func testAnAnswersPatternIsTheWholeRestOfItsLine() throws {
        let header = SpotHeader(text: "#!/bin/sh\n# on=search.text ^\\s*([0-9,.]|(?i:today|now)\\b)\n").block

        let spot = try XCTUnwrap(try SpotFile(script: URL(fileURLWithPath: "/spots/calc.sh"), header: header, id: "calc").spots.first)

        XCTAssertEqual(spot.answers?.text, #"^\s*([0-9,.]|(?i:today|now)\b)"#)
        XCTAssertEqual(["1,5", "Today", "notes"].map { spot.answers?.matches($0) }, [true, true, false])
    }

    func testAHeaderPictureOnTheWebKeepsItsURL() throws {
        let header = SpotHeader(text: "#!/bin/sh\n# icon=https://example.com/cups.png\n").block

        let spot = try XCTUnwrap(try SpotFile(script: URL(fileURLWithPath: "/spots/home/cups.sh"), header: header, id: "home/cups").spots.first)

        XCTAssertEqual(spot.icon, .image("https://example.com/cups.png"))
    }

    func testAViewThatIsNoSwiftFileIsRefused() {
        let header = SpotHeader(text: "#!/bin/sh\n# title=Cups\n# view=cups.txt\n").block

        XCTAssertThrowsError(try SpotFile(script: URL(fileURLWithPath: "/spots/cups.sh"), header: header, id: "cups")) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "Cups needs a Swift file for its view, such as view=cups.swift")
        }
    }
}
