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

    private func review(_ header: String, path: String = "weather.spot/weather.sh", body: String = "") throws -> ReviewSpot {
        let text = "#!/bin/sh\n\(header.split(separator: "\n").map { "# \($0)\n" }.joined())\(body)"
        return try ReviewSpot(spot: spot([(path, text, true)]), folder: folder)
    }

    private func sheet(_ review: ReviewSpot) throws -> SpotOutput {
        SpotOutput(text: try review.answer(["read"]))
    }

    private func shown(_ review: ReviewSpot) throws -> String {
        let part = try XCTUnwrap(sheet(review).parts.first { $0.id == "review" })
        guard case .text(let text, _, let isReadOnly) = part.control else { throw SpotError.badForm }
        XCTAssertTrue(isReadOnly)
        return text
    }

    func testItShowsAllOfTheTextOfEachFile() throws {
        let review = try ReviewSpot(
            spot: spot([("home.spot/a.sh", "#!/bin/sh\necho one\\two\n", true), ("home.spot/lib.sh", "lib code\n", false)]),
            folder: folder
        )

        let text = try shown(review)

        XCTAssertTrue(text.contains("home.spot/a.sh\n#!/bin/sh\necho one\\two\n"), text)
        XCTAssertTrue(text.contains("home.spot/lib.sh\nlib code\n"), text)
    }

    func testTheReviewOfTheInlineCalculatorShowsItsText() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let place = SpotFolder(url: folder, core: repo.appendingPathComponent("plugins"), enabled: ["calculator"])
        let scan = try place.scan()
        let calculator = try XCTUnwrap(scan.spots.first { SpotFolder.coreID(of: $0) == "calculator" })

        let text = try shown(ReviewSpot(spot: SharedSpot(sharing: calculator, from: scan), folder: folder, canAdd: false))

        XCTAssertTrue(text.contains("calculator.js\n// title=Calculator"), text)
        XCTAssertTrue(text.contains("function main("), text)
    }

    func testAnInlineSpotShowsItsTextAndRunsOnlyWhenItIsUsed() throws {
        let review = try ReviewSpot(spot: spot([("sum.spot/sum.js", "// title=Sum\n// on=panel.open\nfunction main() { return '' }\n", false)]), folder: folder)

        let text = try shown(review)

        XCTAssertTrue(text.contains("sum.js\n// title=Sum"), text)
        XCTAssertEqual(review.name, "Sum")
    }

    func testAFileThatIsNotTextIsNamedWithItsSize() throws {
        let files = [
            SharedSpot.File(path: "home.spot/a.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8)),
            SharedSpot.File(path: "home.spot/icon.png", isExecutable: false, contents: Data([0xFF, 0x00, 0xFE]))
        ]

        let text = try shown(ReviewSpot(spot: SharedSpot(files: files), folder: folder))

        XCTAssertTrue(text.contains("home.spot/icon.png\nNot text, so Openspot cannot show it. 3 bytes."), text)
        XCTAssertFalse(text.contains("Program"), text)
    }

    func testAProgramSaysThatItCannotBeShown() throws {
        let files = [SharedSpot.File(path: "tool.spot/tool", isExecutable: true, contents: Data([0xCF, 0xFA, 0xED, 0xFE, 0x00]))]

        let review = try ReviewSpot(spot: SharedSpot(files: files), folder: folder)

        XCTAssertEqual(review.subtitle, "Holds a program that you cannot read")
        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("\(review.name)\n\nProgram that Openspot cannot show\ntool.spot/tool\nIt can do all that you can. Add it only if you trust the sender.\n\n"), text)
    }

    func testVeryLongTextIsNamedAndNotDrawn() throws {
        let long = String(repeating: "x", count: ReviewSpot.textLimit + 1)
        let files = [
            SharedSpot.File(path: "a.spot/a.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8)),
            SharedSpot.File(path: "a.spot/notes.txt", isExecutable: false, contents: Data(long.utf8))
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
        let command = review.spot
        XCTAssertEqual(command.name, "Weather now")
        XCTAssertEqual(command.symbol, "sun.max")
    }

    func testAWidgetNamesItselfBeforeTheMetricsItPlaces() throws {
        let widget = "#!/bin/sh\n# title=Desk\n# grid.square=cpu\n"
        let review = try ReviewSpot(spot: spot([("board.spot/board.sh", widget, true), ("cpu.spot/cpu.sh", "#!/bin/sh\n# title=CPU\n# on=clock.5\n", true)]), folder: folder)

        XCTAssertEqual(review.name, "Desk")
    }

    func testAProgramWarningComesBeforeTheDescription() throws {
        let long = "#!/bin/sh\n# detail=Nice\n" + String(repeating: "x", count: ReviewSpot.textLimit)
        let files = [SharedSpot.File(path: "tool.spot/tool", isExecutable: true, contents: Data(long.utf8))]

        XCTAssertEqual(try ReviewSpot(spot: SharedSpot(files: files), folder: folder).subtitle, "Holds a program that you cannot read")
    }

    func testADragOfASpotSaysWhatADropInstalls() throws {
        let file = folder.appendingPathComponent("any name.spot")
        try spot([("weather.spot/weather.sh", "#!/bin/sh\n# title=Weather\n# icon=sun.max\n# detail=Today\n", true)]).zip(to: file)
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
        let review = try review("title=Weather\non=sheet.open")

        XCTAssertEqual(review.subtitle, "Runs only when you use it")
        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("Weather\n\nUses nothing\n\nRuns only when you use it\n\n"), text)
        XCTAssertFalse(text.contains("Runs by itself"))
    }

    func testItSaysWhatRunsByItself() throws {
        let review = try review("title=Weather\non=panel.open\non=clock.30")

        XCTAssertEqual(review.subtitle, "Runs by itself")
        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("Weather\n\nUses nothing\n\nRuns by itself\nWeather: when the panel opens, every 30 seconds\n"), text)
    }

    func testItShowsTheUsesThatTheHeaderNames() throws {
        let text = try shown(review("title=Coffee\nuses=network,app"))

        XCTAssertTrue(text.hasPrefix("Coffee\n\nUses\napp, network\n\n"), text)
        XCTAssertFalse(text.contains("Can also"), text)
    }

    func testCanAlsoSaysWhatTheTextSeemsToDoAndDoesNotName() throws {
        let body = """
        curl -s https://example.com | nc host 80
        rm -f "$OPENSPOT_DATA/old"
        screencapture -x shot.png && printf x | pbcopy
        old=$(pbpaste)
        openspot app quit
        openspot setting get --spot notes tone
        openspot setting get tone
        openspot clipboard copy
        """
        let review = try review("title=Coffee\nuses=clipboard", body: body)

        let text = try shown(review)

        XCTAssertTrue(text.contains("""
        Uses
        clipboard

        Can also
        Reach the network with curl and nc
        Delete files with rm
        Take screenshots with screencapture in place of openspot screen
        Copy with pbcopy in place of openspot clipboard
        Read the clipboard with pbpaste in place of openspot clipboard
        Call openspot app quit without uses=app
        Call openspot setting get without uses=spots


        """), text)
        XCTAssertNotNil(try sheet(review).parts.first { $0.id == "install" }, "a review warns and never refuses")
    }

    func testANamedNetworkIsNoCanAlso() throws {
        let text = try shown(review("title=Coffee\nuses=network", body: "curl -s https://example.com\n"))

        XCTAssertFalse(text.contains("Can also"), text)
    }

    func testCanAlsoReadsTheCallsOfAnInlineSpot() throws {
        let review = try ReviewSpot(spot: spot([("bye.spot/bye.js", "// title=Bye\nfunction main() { openspot.call([\"app\", \"quit\"]) }\n", false)]), folder: folder)

        XCTAssertTrue(try shown(review).contains("Can also\nCall openspot app quit without uses=app\n"))
    }

    func testAReviewOfANewVersionSaysWhatItAdds() throws {
        try "#!/bin/sh\n# title=Weather\n# uses=app\n".writeScript(to: folder.appendingPathComponent("weather.spot/weather.sh"))

        let text = try shown(review("title=Weather\nuses=app,network,screen"))

        XCTAssertTrue(text.hasPrefix("Weather\nThis version adds: screen, network\n\n"), text)
    }

    func testAReviewReadsTheUsesOfEachInstalledFileOfTheSpot() throws {
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("home"), withIntermediateDirectories: true)
        try "#!/bin/sh\n# uses=network\n".writeScript(to: folder.appendingPathComponent("home.spot/main.sh"))
        try "#!/bin/sh\necho one\n".writeScript(to: folder.appendingPathComponent("home.spot/helper.sh"))
        let review = try ReviewSpot(spot: spot([("home.spot/main.sh", "#!/bin/sh\n# uses=network\n", true), ("home.spot/helper.sh", "#!/bin/sh\necho two\n", true)]), folder: folder)

        XCTAssertFalse(try shown(review).contains("This version adds"))
    }

    func testAReviewOfANewVersionThatAddsNothingSaysNothing() throws {
        try "#!/bin/sh\n# title=Weather\n# uses=app\n".writeScript(to: folder.appendingPathComponent("weather.spot/weather.sh"))

        let text = try shown(review("title=Weather\nuses=app"))

        XCTAssertFalse(text.contains("This version adds"), text)
    }

    func testAStayingScriptSaysSo() throws {
        let review = try review("title=Weather\nmode=stay\non=sheet.open")

        let text = try shown(review)
        XCTAssertTrue(text.contains("Weather: keeps running while it is in use"), text)
    }

    func testAScriptThatAlwaysStaysSaysSo() throws {
        let review = try review("title=Relay\nmode=always")

        let text = try shown(review)
        XCTAssertTrue(text.contains("Relay: keeps running while Openspot runs"), text)
    }

    func testAMetricThatAWidgetPlacesRunsWhenThePanelOpens() throws {
        let widget = "#!/bin/sh\n# title=Desk\n# grid.square=cpu\n"
        let review = try ReviewSpot(
            spot: spot([("board.spot/board.sh", widget, true), ("cpu.spot/cpu.sh", "#!/bin/sh\n# title=CPU\n# on=sheet.open\n", true)]),
            folder: folder
        )

        let text = try shown(review)
        XCTAssertTrue(text.contains("CPU: when the panel opens"), text)
    }

    func testItNamesEachFileItReplaces() throws {
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("weather.spot"), withIntermediateDirectories: true)
        try Data("old".utf8).write(to: folder.appendingPathComponent("weather.spot/weather.sh"))

        let text = try shown(review(""))

        XCTAssertTrue(text.contains("Replaces, and moves the old file to the Trash\nweather.spot/weather.sh\n"), text)
    }

    func testAnEqualFileIsNotReplaced() throws {
        let url = folder.appendingPathComponent("weather.spot/weather.sh")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)

        XCTAssertFalse(try shown(review("")).contains("Replaces"))
    }

    func testAFileThatGivesNoSpotIsRefused() throws {
        XCTAssertThrowsError(try ReviewSpot(spot: spot([("notes.spot/notes.txt", "hello", false)]), folder: folder)) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "This file holds no spot.")
        }
    }

    func testAFaultThatStopsAPartOfItShows() throws {
        let review = try ReviewSpot(
            spot: spot([("good.spot/good.sh", "#!/bin/sh\n", true), ("bad.spot/bad.sh", "#!/bin/sh\n# read=never\n", true)]),
            folder: folder
        )

        let text = try shown(review)
        XCTAssertTrue(text.contains("Will not load\nbad: Bad has read=never, which Openspot no longer reads."), text)
    }

    func testAClashWithAFolderIsRefusedBeforeTheReviewShows() throws {
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("weather.spot/weather.sh"), withIntermediateDirectories: true)

        XCTAssertThrowsError(try review(""))
    }

    /// A review of a `.spot` file with one script, which adds to the folder `plugins` and records in a lock beside it.
    private func filed(_ header: String, body: String = "") throws -> ReviewSpot {
        let text = "#!/bin/sh\n\(header.split(separator: "\n").map { "# \($0)\n" }.joined())\(body)"
        let file = folder.appendingPathComponent("Weather.spot")
        try spot([("weather.spot/weather.sh", text, true)]).zip(to: file)
        return try ReviewSpot(file: file, folder: folder.appendingPathComponent("plugins"), lock: SpotLock(url: folder.appendingPathComponent("spots.lock")))
    }

    func testNoScriptRunsForAReviewOrForAdd() async throws {
        let mark = folder.appendingPathComponent("ran")
        let review = try filed("on=panel.open", body: "touch \"\(mark.path)\"\n")
        _ = try review.answer(["read"])

        _ = try await review.add()

        XCTAssertFalse(FileManager.default.fileExists(atPath: mark.path))
    }

    func testAddPutsItInTheFolderThatTheNextScanReads() async throws {
        let answer = try await filed("title=Weather\nicon=sun.max").add()

        XCTAssertEqual(SpotOutput(text: answer).summary?.value("toast"), "Weather added")
        let scan = try SpotFolder(url: folder.appendingPathComponent("plugins")).scan()
        XCTAssertEqual(scan.spots.map(\.name), ["Weather"])
        XCTAssertEqual(scan.refused, [])
    }

    func testAddKeepsTheSpotInTheLockAsSpotAddDoes() async throws {
        let file = folder.appendingPathComponent("Weather.spot")
        try spot([("weather.spot/weather.sh", "#!/bin/sh\n# title=Weather\n", true)]).zip(to: file)
        let plugins = folder.appendingPathComponent("plugins")
        let lock = SpotLock(url: folder.appendingPathComponent("spots.lock"))
        let review = try ReviewSpot(file: file, folder: plugins, lock: lock)

        _ = try await review.add()

        XCTAssertEqual(try lock.entries().map(\.source), [file.path])
        XCTAssertEqual(try lock.entries().map(\.paths), [["weather.spot/weather.sh"]])
        XCTAssertEqual(try SpotFolder(url: plugins).scan().spots.map(\.name), ["Weather"])
    }

    func testTheAppOffersTheReviewAsASheetThatGrowsOutOfTheField() async throws {
        let review = try review("title=Weather")
        let command = review.spot

        XCTAssertEqual(command.name, "Weather")
        XCTAssertEqual(command.subtitle, "Runs only when you use it")
        XCTAssertEqual(command.kind, .list)
        XCTAssertEqual(command.read, .sheet)
        XCTAssertTrue(command.growsFromField)
        let answer = try await command.host?.answer(["read"])
        XCTAssertEqual(answer, try review.answer(["read"]))
    }

    func testAnUnknownCallFails() throws {
        XCTAssertThrowsError(try review("").answer(["other"]))
    }

    func testTheReviewShowsTheReadmeAndThePreviewAfterWhatItUsesAndTheAddKeepsThemInTheSpotFolder() async throws {
        let shared = try spot([
            ("timer.spot/timer.sh", "#!/bin/sh\n# title=Timer\n", true),
            ("timer.spot/readme.md", "Counts down from a time you pick.\n", false),
            ("timer.spot/preview.txt", "row=a\ntitle=5 minutes\n", false)
        ])
        let store = folder.appendingPathComponent("store")
        try SpotPackage.write(shared, to: store)
        let package = SpotPackage(url: SpotPackage.url(for: "timer", in: store))
        let plugins = folder.appendingPathComponent("plugins")
        let lock = SpotLock(url: folder.appendingPathComponent("spots.lock"))
        let review = try ReviewSpot(file: package.url, folder: plugins, lock: lock)

        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("Timer\n\nUses nothing\n\nRuns only when you use it\n\nCounts down from a time you pick.\n\nPreview\n5 minutes\n\n"), text)

        _ = try await review.add()
        XCTAssertEqual(try String(contentsOf: plugins.appendingPathComponent("timer.spot/readme.md"), encoding: .utf8), "Counts down from a time you pick.\n")
        XCTAssertEqual(try String(contentsOf: plugins.appendingPathComponent("timer.spot/preview.txt"), encoding: .utf8), "row=a\ntitle=5 minutes\n")
        XCTAssertEqual(try lock.entries().map(\.paths), [["timer.spot/preview.txt", "timer.spot/readme.md", "timer.spot/timer.sh"]])
        XCTAssertEqual(try lock.entries().map(\.source), [package.url.path])
    }
}
