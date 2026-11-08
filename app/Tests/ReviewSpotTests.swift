import XCTest
@testable import OpenspotCore

final class ReviewSpotTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-review-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func spot(_ files: [(path: String, text: String, isExecutable: Bool)]) throws -> SharedSpot {
        try SharedSpot(files: files.map { SharedSpot.File(path: $0.path, isExecutable: $0.isExecutable, contents: Data($0.text.utf8)) })
    }

    private func review(_ header: String, path: String = "weather.sh", body: String = "") throws -> ReviewSpot {
        let text = "#!/bin/sh\n\(header.split(separator: "\n").map { "# \($0)\n" }.joined())\(body)"
        return try ReviewSpot(spot: spot([(path, text, true)]), folder: folder)
    }

    private func sheet(_ review: ReviewSpot) throws -> PluginOutput {
        PluginOutput(text: try review.answer(["read"]))
    }

    private func shown(_ review: ReviewSpot) throws -> String {
        let part = try XCTUnwrap(sheet(review).parts.first { $0.id == "review" })
        guard case .text(let text, _, let isReadOnly) = part.control else { throw PluginError.badForm }
        XCTAssertTrue(isReadOnly)
        return text
    }

    func testItShowsAllOfTheTextOfEachFile() throws {
        let review = try ReviewSpot(
            spot: spot([("home/a.sh", "#!/bin/sh\necho one\\two\n", true), ("home/lib.sh", "lib code\n", false)]),
            folder: folder
        )

        let text = try shown(review)

        XCTAssertTrue(text.contains("home/a.sh\n#!/bin/sh\necho one\\two\n"), text)
        XCTAssertTrue(text.contains("home/lib.sh\nlib code\n"), text)
    }

    func testAFileThatIsNotTextIsNamedWithItsSize() throws {
        let files = [
            SharedSpot.File(path: "home/a.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8)),
            SharedSpot.File(path: "home/icon.png", isExecutable: false, contents: Data([0xFF, 0x00, 0xFE]))
        ]

        let text = try shown(ReviewSpot(spot: SharedSpot(files: files), folder: folder))

        XCTAssertTrue(text.contains("home/icon.png\nNot text, so Openspot cannot show it. 3 bytes."), text)
        XCTAssertFalse(text.contains("Program"), text)
    }

    func testAProgramSaysThatItCannotBeShown() throws {
        let files = [SharedSpot.File(path: "tool", isExecutable: true, contents: Data([0xCF, 0xFA, 0xED, 0xFE, 0x00]))]

        let review = try ReviewSpot(spot: SharedSpot(files: files), folder: folder)

        XCTAssertEqual(review.subtitle, "Holds a program that you cannot read")
        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("Program that Openspot cannot show\ntool\nIt can do all that you can. Add it only if you trust the sender.\n\n"), text)
    }

    func testVeryLongTextIsNamedAndNotDrawn() throws {
        let long = String(repeating: "x", count: ReviewSpot.textLimit + 1)
        let files = [
            SharedSpot.File(path: "a.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8)),
            SharedSpot.File(path: "notes.txt", isExecutable: false, contents: Data(long.utf8))
        ]

        let text = try shown(ReviewSpot(spot: SharedSpot(files: files), folder: folder))

        XCTAssertFalse(text.contains(long.prefix(100)))
        XCTAssertTrue(text.contains("notes.txt\nToo long to show. \(ReviewSpot.textLimit + 1) bytes."), text)
    }

    func testItTakesItsNameDescriptionAndSymbolFromTheHeader() throws {
        let review = try review("title=Weather now\nicon=sun.max\ndetail=Today and tomorrow")

        XCTAssertEqual(review.name, "Weather now")
        XCTAssertEqual(review.symbol, "sun.max")
        XCTAssertEqual(review.subtitle, "Today and tomorrow")
        let command = ShippedSpot.command(reviewing: review)
        XCTAssertEqual(command.name, "Weather now")
        XCTAssertEqual(command.symbol, "sun.max")
    }

    func testAWidgetNamesItselfBeforeTheMetricsItPlaces() throws {
        let widget = "[[widgets]]\ntitle = \"Desk\"\ngrid = [\"a\"]\nplaces = { a = \"cpu\" }\nsize = \"square\"\n"
        let review = try ReviewSpot(spot: spot([("board.toml", widget, false), ("cpu.sh", "#!/bin/sh\n# title=CPU\n# read=5\n", true)]), folder: folder)

        XCTAssertEqual(review.name, "Desk")
    }

    func testAProgramWarningComesBeforeTheDescription() throws {
        let long = "#!/bin/sh\n# detail=Nice\n" + String(repeating: "x", count: ReviewSpot.textLimit)
        let files = [SharedSpot.File(path: "tool", isExecutable: true, contents: Data(long.utf8))]

        XCTAssertEqual(try ReviewSpot(spot: SharedSpot(files: files), folder: folder).subtitle, "Holds a program that you cannot read")
    }

    func testADragOfASpotSaysWhatADropInstalls() throws {
        let file = folder.appendingPathComponent("any name.spot")
        try spot([("weather.sh", "#!/bin/sh\n# title=Weather\n# icon=sun.max\n# detail=Today\n", true)]).data.write(to: file)
        let target = folder.appendingPathComponent("plugins")

        let drop = SpotDrop(paths: [file.path], folder: target)

        XCTAssertEqual(drop.title, "Weather")
        XCTAssertEqual(drop.symbol, "sun.max")
        XCTAssertEqual(drop.detail, "Drop to install")
        XCTAssertEqual(SpotDrop(paths: [file.path, file.path], folder: target).detail, "Openspot installs one spot at a time")
    }

    func testADragOfABadFileSaysWhyBeforeTheDrop() throws {
        let file = folder.appendingPathComponent("Broken.spot")
        try Data("nope".utf8).write(to: file)

        let drop = SpotDrop(paths: [file.path], folder: folder)

        XCTAssertEqual(drop.title, "Cannot install Broken")
        XCTAssertEqual(drop.detail, "This file is not a spot.")
    }

    func testOnlyACommandKeyAddsIt() throws {
        let add = try XCTUnwrap(sheet(review("")).parts.first { $0.id == "install" })

        XCTAssertEqual(add.key, ActionKey(name: "return", isCommand: true))
        XCTAssertEqual(add.title, "Add")
        XCTAssertTrue(add.closes)
        XCTAssertEqual(SheetParts(output: try sheet(review("")))?.hint, "⌘⏎ Add   Esc Close")
    }

    func testAPlainScriptRunsOnlyWhenItIsUsed() throws {
        let review = try review("title=Weather\nread=sheet")

        XCTAssertEqual(review.subtitle, "Runs only when you use it")
        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("Runs only when you use it\n\n"), text)
        XCTAssertFalse(text.contains("Runs by itself"))
    }

    func testItSaysWhatRunsByItself() throws {
        let review = try review("title=Weather\nread=panel,wake,launch,30")

        XCTAssertEqual(review.subtitle, "Runs by itself")
        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("Runs by itself\nWeather: when the panel opens, when the Mac wakes, when Openspot starts, every 30 seconds\n"), text)
    }

    func testAMetricThatAWidgetPlacesRunsWhenThePanelOpens() throws {
        let widget = "[[widgets]]\ntitle = \"Desk\"\ngrid = [\"a\"]\nplaces = { a = \"cpu\" }\nsize = \"square\"\n"
        let review = try ReviewSpot(
            spot: spot([("board.toml", widget, false), ("cpu.sh", "#!/bin/sh\n# title=CPU\n# read=sheet\n", true)]),
            folder: folder
        )

        let text = try shown(review)
        XCTAssertTrue(text.contains("CPU: when the panel opens"), text)
    }

    func testItNamesEachFileItReplaces() throws {
        try Data("old".utf8).write(to: folder.appendingPathComponent("weather.sh"))

        let text = try shown(review(""))

        XCTAssertTrue(text.contains("Replaces, and moves the old file to the Trash\nweather.sh\n"), text)
    }

    func testAnEqualFileIsNotReplaced() throws {
        let url = folder.appendingPathComponent("weather.sh")
        try Data("#!/bin/sh\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)

        XCTAssertFalse(try shown(review("")).contains("Replaces"))
    }

    func testAFileThatGivesNoSpotIsRefused() throws {
        XCTAssertThrowsError(try ReviewSpot(spot: spot([("notes.txt", "hello", false)]), folder: folder)) { error in
            XCTAssertEqual((error as? PluginError)?.reason, "This file holds no spot.")
        }
    }

    func testAFaultThatStopsAPartOfItShows() throws {
        let review = try ReviewSpot(
            spot: spot([("good.sh", "#!/bin/sh\n", true), ("bad.sh", "#!/bin/sh\n# read=never\n", true)]),
            folder: folder
        )

        let text = try shown(review)
        XCTAssertTrue(text.contains("Will not load\nbad: Bad has an unknown read: never."), text)
    }

    func testAClashWithAFolderIsRefusedBeforeTheReviewShows() throws {
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("weather.sh"), withIntermediateDirectories: true)

        XCTAssertThrowsError(try review(""))
    }

    func testNoScriptRunsForAReviewOrForAdd() throws {
        let mark = folder.appendingPathComponent("ran")
        let review = try review("read=panel,launch", body: "touch \"\(mark.path)\"\n")
        _ = try review.answer(["read"])

        _ = try review.answer(["install"])

        XCTAssertFalse(FileManager.default.fileExists(atPath: mark.path))
    }

    func testAddPutsItInTheFolderThatTheNextScanReads() throws {
        let answer = try review("title=Weather\nicon=sun.max").answer(["install"])

        XCTAssertEqual(PluginOutput(text: answer).summary?.value("toast"), "Weather added")
        let scan = try PluginFolder(url: folder).scan()
        XCTAssertEqual(scan.commands.map(\.name), ["Weather"])
        XCTAssertEqual(scan.refused, [])
    }

    func testAShippedSpotOffersTheReviewAsASheet() async throws {
        let review = try review("title=Weather")
        let command = ShippedSpot.command(reviewing: review)

        XCTAssertEqual(command.name, "Weather")
        XCTAssertEqual(command.subtitle, "Runs only when you use it")
        XCTAssertEqual(command.kind, .list)
        XCTAssertEqual(command.read, .sheet)
        let answer = try await command.shipped?.answer(["read"], input: nil)
        XCTAssertEqual(answer, try review.answer(["read"]))
    }

    func testAnUnknownCallFails() throws {
        XCTAssertThrowsError(try review("").answer(["other"]))
    }
}
