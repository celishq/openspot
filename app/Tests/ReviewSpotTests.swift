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

    private func spot(_ files: [(path: String, text: String, isExecutable: Bool)]) throws -> SpotPackage {
        try SpotPackage(files: files.map { SpotPackage.File(path: $0.path, isExecutable: $0.isExecutable, contents: Data($0.text.utf8)) })
    }

    private func review(_ toml: String, path: String = "weather.spot/weather.sh", body: String = "") throws -> ReviewSpot {
        let manifest = ((path as NSString).deletingLastPathComponent as NSString).appendingPathComponent(Manifest.fileName)
        return try ReviewSpot(spot: spot([(path, "#!/bin/sh\n\(body)", true)] + (toml.isEmpty ? [] : [(manifest, toml, false)])), folder: folder)
    }

    private func sheet(_ review: ReviewSpot) throws -> Frame {
        Frame(text: try review.answer(["show"]))
    }

    private func shown(_ review: ReviewSpot) throws -> String {
        let part = try XCTUnwrap(sheet(review).parts.first { $0.id == "review" })
        guard case .text(let text, _, let isReadOnly) = part.control else { throw SpotError.badForm }
        XCTAssertTrue(isReadOnly)
        return text
    }

    func testItShowsAllOfTheTextOfEachFile() throws {
        let review = try ReviewSpot(
            spot: spot([("home.spot/a.sh", "#!/bin/sh\necho one\\two\n", true), ("home.spot/spot.toml", "[scripts.a]", false), ("home.spot/lib.sh", "lib code\n", false)]),
            folder: folder
        )

        let text = try shown(review)

        XCTAssertTrue(text.contains("home.spot/a.sh\n#!/bin/sh\necho one\\two\n"), text)
        XCTAssertTrue(text.contains("home.spot/lib.sh\nlib code\n"), text)
    }

    func testTheReviewOfASharedInlineCoreSpotShowsItsText() throws {
        let core = try temporaryFolder()
        let sums = core.appendingPathComponent("sums.spot")
        try "function main(args) { return 'frame=\\nclass=gap-part\\n\\nnumber=answer\\nvalue=3\\nclass=large:flex\\n' }\n".writeInline(to: sums.appendingPathComponent("sums.js"), toml: "title = 'Sums'\nicon = 'equal.square'\ndetail = 'Sums'\non = ['search.text ^[0-9]']\nuses = ['clipboard']")
        try "#!/bin/sh\nprintf 'frame=\\nclass=gap-part\\n\\nnumber=answer\\nvalue=3\\ntitle=1 + 2\\nclass=large:flex\\n'\n".writeScript(to: sums.appendingPathComponent("sample.sh"))
        try "# Sums\n\nAdds numbers.\n".write(to: sums.appendingPathComponent("readme.md"), atomically: true, encoding: .utf8)
        let scan = try SpotsFolder(url: folder, core: core, enabled: ["sums"]).scan()
        let shared = try XCTUnwrap(scan.spots.first { SpotsFolder.coreID(of: $0) == "sums" })

        let text = try shown(ReviewSpot(spot: SpotPackage(sharing: shared, from: scan), folder: folder, canAdd: false))

        XCTAssertTrue(text.contains("sums.js\n"), text)
        XCTAssertTrue(text.contains("function main("), text)
    }

    func testAnInlineSpotShowsItsTextAndRunsOnlyWhenItIsUsed() throws {
        let review = try ReviewSpot(spot: spot([("sum.spot/sum.js", "function main() { return '' }\n", false), ("sum.spot/spot.toml", "title = 'Sum'\non = ['panel.open']", false)]), folder: folder)

        let text = try shown(review)

        XCTAssertTrue(text.contains("sum.js\nfunction main()"), text)
        XCTAssertEqual(review.name, "Sum")
    }

    func testAFileThatIsNotTextIsNamedWithItsSize() throws {
        let files = [
            SpotPackage.File(path: "home.spot/a.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8)),
            SpotPackage.File(path: "home.spot/spot.toml", isExecutable: false, contents: Data("[scripts.a]\n".utf8)),
            SpotPackage.File(path: "home.spot/icon.png", isExecutable: false, contents: Data([0xFF, 0x00, 0xFE]))
        ]

        let text = try shown(ReviewSpot(spot: SpotPackage(files: files), folder: folder))

        XCTAssertTrue(text.contains("home.spot/icon.png\nNot text, so Openspot cannot show it. 3 bytes."), text)
        XCTAssertFalse(text.contains("Program"), text)
    }

    func testAProgramSaysThatItCannotBeShown() throws {
        let files = [SpotPackage.File(path: "tool.spot/tool", isExecutable: true, contents: Data([0xCF, 0xFA, 0xED, 0xFE, 0x00]))]

        let review = try ReviewSpot(spot: SpotPackage(files: files), folder: folder)

        XCTAssertEqual(review.subtitle, "Holds a program that you cannot read")
        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("\(review.name)\n\nProgram that Openspot cannot show\ntool.spot/tool\nIt can do all that you can. Add it only if you trust the sender.\n\n"), text)
    }

    func testVeryLongTextIsNamedAndNotDrawn() throws {
        let long = String(repeating: "x", count: ReviewSpot.textLimit + 1)
        let files = [
            SpotPackage.File(path: "a.spot/a.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8)),
            SpotPackage.File(path: "a.spot/notes.txt", isExecutable: false, contents: Data(long.utf8))
        ]

        let text = try shown(ReviewSpot(spot: SpotPackage(files: files), folder: folder))

        XCTAssertFalse(text.contains(long.prefix(100)))
        XCTAssertTrue(text.contains("notes.txt\nToo long to show. \(ReviewSpot.textLimit + 1) bytes."), text)
    }

    func testItTakesItsNameDescriptionAndSymbolFromTheHeader() throws {
        let review = try review("title = 'Weather now'\nicon = 'sun.max'\ndetail = 'Today and tomorrow'")

        XCTAssertEqual(review.name, "Weather now")
        XCTAssertEqual(review.symbol, "sun.max")
        XCTAssertEqual(review.subtitle, "Today and tomorrow")
        let command = review.spot
        XCTAssertEqual(command.name, "Weather now")
        XCTAssertEqual(command.symbol, "sun.max")
    }

    func testAProgramWarningComesBeforeTheDescription() throws {
        let long = "#!/bin/sh\necho nice\n" + String(repeating: "x", count: ReviewSpot.textLimit)
        let files = [SpotPackage.File(path: "tool.spot/tool", isExecutable: true, contents: Data(long.utf8))]

        XCTAssertEqual(try ReviewSpot(spot: SpotPackage(files: files), folder: folder).subtitle, "Holds a program that you cannot read")
    }

    func testADragOfASpotSaysWhatADropInstalls() throws {
        let file = folder.appendingPathComponent("any name.spot")
        try spot([("weather.spot/weather.sh", "#!/bin/sh\n", true), ("weather.spot/spot.toml", "title = 'Weather'\nicon = 'sun.max'\ndetail = 'Today'", false)]).zip(to: file)
        let target = folder.appendingPathComponent("spots")

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
        let review = try review("title = 'Weather'")

        XCTAssertEqual(review.subtitle, "Runs only when you use it")
        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("Weather\n\nUses nothing\n\nRuns only when you use it\n\n"), text)
        XCTAssertFalse(text.contains("Runs by itself"))
    }

    func testItSaysWhatRunsByItself() throws {
        let review = try review("title = 'Weather'\non = ['panel.open', 'clock.30']")

        XCTAssertEqual(review.subtitle, "Runs by itself")
        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("Weather\n\nUses nothing\n\nRuns by itself\nWeather: when the panel opens, every 30 seconds\n"), text)
    }

    func testItShowsTheUsesThatTheHeaderNames() throws {
        let text = try shown(review("title = 'Coffee'\nuses = ['network', 'app']"))

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
        let review = try review("title = 'Coffee'\nuses = ['clipboard']", body: body)

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
        Call openspot app quit without app in the uses of its spot.toml
        Call openspot setting get without spots in the uses of its spot.toml


        """), text)
        XCTAssertNotNil(try sheet(review).parts.first { $0.id == "install" }, "a review warns and never refuses")
    }

    func testASettingOfAnotherSpotWithAShellValueNeedsSpots() throws {
        let text = try shown(review("title = 'Coffee'", body: "openspot setting set --spot \"$id\" enabled \"$on\"\n"))

        XCTAssertTrue(text.contains("Call openspot setting set without spots in the uses of its spot.toml"), text)
    }

    func testANamedNetworkIsNoCanAlso() throws {
        let text = try shown(review("title = 'Coffee'\nuses = ['network']", body: "curl -s https://example.com\n"))

        XCTAssertFalse(text.contains("Can also"), text)
    }

    func testCanAlsoReadsTheCallsOfAnInlineSpot() throws {
        let review = try ReviewSpot(spot: spot([("bye.spot/bye.js", "function main() { openspot.call([\"app\", \"quit\"]) }\n", false), ("bye.spot/spot.toml", "title = 'Bye'", false)]), folder: folder)

        XCTAssertTrue(try shown(review).contains("Can also\nCall openspot app quit without app in the uses of its spot.toml\n"))
    }

    func testAReviewOfANewVersionSaysWhatItAdds() throws {
        try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("weather.spot/weather.sh"), toml: "title = 'Weather'\nuses = ['app']")

        let text = try shown(review("title = 'Weather'\nuses = ['app', 'network', 'screen']"))

        XCTAssertTrue(text.hasPrefix("Weather\nThis version adds: screen, network\n\n"), text)
    }

    func testAReviewReadsTheUsesOfEachInstalledFileOfTheSpot() throws {
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("home"), withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("home.spot/main.sh"), toml: "uses = ['network']")
        try "#!/bin/sh\necho one\n".writeScript(to: folder.appendingPathComponent("home.spot/helper.sh"))
        let review = try ReviewSpot(spot: spot([("home.spot/main.sh", "#!/bin/sh\n", true), ("home.spot/helper.sh", "#!/bin/sh\necho two\n", true), ("home.spot/spot.toml", "[scripts.main]\nuses = ['network']\n[scripts.helper]", false)]), folder: folder)

        XCTAssertFalse(try shown(review).contains("This version adds"))
    }

    func testAReviewOfANewVersionThatAddsNothingSaysNothing() throws {
        try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("weather.spot/weather.sh"), toml: "title = 'Weather'\nuses = ['app']")

        let text = try shown(review("title = 'Weather'\nuses = ['app']"))

        XCTAssertFalse(text.contains("This version adds"), text)
    }

    func testAStayingScriptSaysSo() throws {
        let review = try review("title = 'Weather'\nmode = 'stay'")

        let text = try shown(review)
        XCTAssertTrue(text.contains("Weather: keeps running while it is in use"), text)
    }

    func testAScriptThatAlwaysStaysSaysSo() throws {
        let review = try review("title = 'Relay'\non = ['app.launch']\nmode = 'stay'")

        let text = try shown(review)
        XCTAssertTrue(text.contains("Relay: keeps running while Openspot runs"), text)
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
            spot: spot([("good.spot/good.sh", "#!/bin/sh\n", true), ("bad.spot/bad.sh", "#!/bin/sh\n", true), ("bad.spot/spot.toml", "mode = 'never'", false)]),
            folder: folder
        )

        let text = try shown(review)
        XCTAssertTrue(text.contains("Will not load\nbad: Bad has an unknown mode: never."), text)
    }

    func testAClashWithAFolderIsRefusedBeforeTheReviewShows() throws {
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("weather.spot/weather.sh"), withIntermediateDirectories: true)

        XCTAssertThrowsError(try review(""))
    }

    private func filed(_ toml: String, body: String = "") throws -> ReviewSpot {
        let file = folder.appendingPathComponent("Weather.spot")
        try spot([("weather.spot/weather.sh", "#!/bin/sh\n\(body)", true), ("weather.spot/spot.toml", toml, false)]).zip(to: file)
        return try ReviewSpot(file: file, folder: folder.appendingPathComponent("spots"), lock: SpotLock(url: folder.appendingPathComponent("spots.lock")))
    }

    func testNoScriptRunsForAReviewOrForAdd() async throws {
        let mark = folder.appendingPathComponent("ran")
        let review = try filed("on = ['panel.open']", body: "touch \"\(mark.path)\"\n")
        _ = try review.answer(["show"])

        _ = try await review.add()

        XCTAssertFalse(FileManager.default.fileExists(atPath: mark.path))
    }

    func testAddPutsItInTheFolderThatTheNextScanReads() async throws {
        let answer = try await filed("title = 'Weather'\nicon = 'sun.max'").add()

        XCTAssertEqual(answer.effects, [.toast("Weather added")])
        let scan = try SpotsFolder(url: folder.appendingPathComponent("spots")).scan()
        XCTAssertEqual(scan.spots.map(\.name), ["Weather"])
        XCTAssertEqual(scan.refused, [])
    }

    func testAddKeepsTheSpotInTheLockAsSpotAddDoes() async throws {
        let file = folder.appendingPathComponent("Weather.spot")
        try spot([("weather.spot/weather.sh", "#!/bin/sh\n", true), ("weather.spot/spot.toml", "title = 'Weather'", false)]).zip(to: file)
        let spots = folder.appendingPathComponent("spots")
        let lock = SpotLock(url: folder.appendingPathComponent("spots.lock"))
        let review = try ReviewSpot(file: file, folder: spots, lock: lock)

        _ = try await review.add()

        XCTAssertEqual(try lock.entries().map(\.source), [file.path])
        XCTAssertEqual(try lock.entries().map(\.paths), [["weather.spot/spot.toml", "weather.spot/weather.sh"]])
        XCTAssertEqual(try SpotsFolder(url: spots).scan().spots.map(\.name), ["Weather"])
    }

    func testTheAppOffersTheReviewAsASheetThatGrowsOutOfTheField() async throws {
        let review = try review("title = 'Weather'")
        let command = review.spot

        XCTAssertEqual(command.name, "Weather")
        XCTAssertEqual(command.subtitle, "Runs only when you use it")
        XCTAssertEqual(command.kind, .list)
        XCTAssertEqual(command.on, .sheet)
        XCTAssertTrue(command.growsFromField)
        let answer = try await command.host?.answer(["show"], input: nil)
        XCTAssertEqual(answer?.frame, try review.answer(["show"]))
    }

    func testAnUnknownCallFails() throws {
        XCTAssertThrowsError(try review("").answer(["other"]))
    }

    private func weather(_ title: String) throws -> SpotPackage {
        try spot([("weather.spot/weather.sh", "#!/bin/sh\n", true), ("weather.spot/spot.toml", "title = '\(title)'", false)])
    }

    private func installed(_ spot: SpotPackage) throws -> URL {
        let spots = folder.appendingPathComponent("spots")
        try spot.add(to: spots)
        return spots
    }

    func testANewInstallSaysNothingOfItsSigner() throws {
        let review = try ReviewSpot(spot: weather("Weather").signed(by: AccountKey.make()), folder: folder.appendingPathComponent("spots"))

        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("Weather\n\n"), text)
        XCTAssertFalse(text.contains("releases.jsonl"))
    }

    func testAnUpdateFromTheSameKeySaysItsVersion() throws {
        let key = try AccountKey.make()
        let first = try weather("Weather").signed(by: key)
        let spots = try installed(first)
        let second = try SpotPackage(files: weather("Weather 2").files + first.files.filter { $0.path.hasSuffix("releases.jsonl") }).signed(by: key)

        let review = try ReviewSpot(spot: second, folder: spots)

        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("Weather 2\nUpdate to version 2\n\n"), text)
        XCTAssertNotEqual(review.subtitle, ReviewSpot.otherKeySubtitle)
    }

    func testAVersionThatAnotherKeySignedOrNoneSaysSoFirst() throws {
        let spots = try installed(weather("Weather").signed(by: AccountKey.make()))

        for other in [try weather("Weather 2").signed(by: AccountKey.make()), try weather("Weather 2")] {
            let review = try ReviewSpot(spot: other, folder: spots)

            XCTAssertEqual(review.subtitle, ReviewSpot.otherKeySubtitle)
            let text = try shown(review)
            XCTAssertTrue(text.hasPrefix("Weather 2\nAnother key signed this version than the one you have. Add it only if you trust the sender.\n"), text)
        }
    }

    func testAFileChangedAfterItsSignatureIsRefused() throws {
        let signed = try weather("Weather").signed(by: AccountKey.make())
        let changed = try SpotPackage(files: signed.files.map { $0.path.hasSuffix(".sh") ? SpotPackage.File(path: $0.path, isExecutable: true, contents: Data("#!/bin/sh\nrm -rf ~\n".utf8)) : $0 })

        XCTAssertThrowsError(try ReviewSpot(spot: changed, folder: folder)) { error in
            XCTAssertEqual((error as? SpotError)?.reason, "weather.spot does not match its last release, so a file changed after it was signed.")
        }
    }

    func testTheReviewShowsTheReadmeAndThePreviewAfterWhatItUsesAndTheAddKeepsThemInTheSpotFolder() async throws {
        let shared = try spot([
            ("timer.spot/timer.sh", "#!/bin/sh\n", true),
            ("timer.spot/spot.toml", "title = 'Timer'", false),
            ("timer.spot/readme.md", "Counts down from a time you pick.\n", false),
            ("timer.spot/sample.frame", "text=a\ntitle=5 minutes\n", false)
        ])
        let store = folder.appendingPathComponent("store")
        try shared.write(to: store)
        let package = store.appendingPathComponent("timer.spot")
        let spots = folder.appendingPathComponent("spots")
        let lock = SpotLock(url: folder.appendingPathComponent("spots.lock"))
        let review = try ReviewSpot(file: package, folder: spots, lock: lock)

        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("Timer\n\nUses nothing\n\nRuns only when you use it\n\nCounts down from a time you pick.\n\nPreview\n5 minutes\n\n"), text)

        _ = try await review.add()
        XCTAssertEqual(try String(contentsOf: spots.appendingPathComponent("timer.spot/readme.md"), encoding: .utf8), "Counts down from a time you pick.\n")
        XCTAssertEqual(try String(contentsOf: spots.appendingPathComponent("timer.spot/sample.frame"), encoding: .utf8), "text=a\ntitle=5 minutes\n")
        XCTAssertEqual(try lock.entries().map(\.paths), [["timer.spot/readme.md", "timer.spot/sample.frame", "timer.spot/spot.toml", "timer.spot/timer.sh"]])
        XCTAssertEqual(try lock.entries().map(\.source), [package.path])
    }

    func testThePreviewReadsTheViewsOfTheSpot() throws {
        let review = try ReviewSpot(spot: spot([
            ("cups.spot/cups.sh", "#!/bin/sh\n", true),
            ("cups.spot/spot.toml", "title = 'Cups'\nviews = ['liquid.swift']", false),
            ("cups.spot/sample.frame", "frame=\nclass=gap-part\n\nitems=list\n\ntext=a\nparent=list\ntitle=Water\n\nliquid=b\nparent=list\ntitle=Juice\n", false)
        ]), folder: folder)

        let text = try shown(review)
        XCTAssertTrue(text.contains("Preview\nWater\nJuice\n\n"), text)
    }
}
