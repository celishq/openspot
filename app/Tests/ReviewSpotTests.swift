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
            spot: spot([("home.spot/home.sh", "#!/bin/sh\necho one\\two\n", true), ("home.spot/spot.toml", "title = 'Home'", false), ("home.spot/lib.sh", "lib code\n", false)]),
            folder: folder
        )

        let text = try shown(review)

        XCTAssertTrue(text.contains("home.spot/home.sh\n#!/bin/sh\necho one\\two\n"), text)
        XCTAssertTrue(text.contains("home.spot/lib.sh\nlib code\n"), text)
    }

    func testTheReviewOfASharedInlineCoreSpotShowsItsText() throws {
        let core = try temporaryFolder()
        let sums = core.appendingPathComponent("sums.spot")
        try "export default { async search() { return 'frame=\\nclass=gap-part\\n\\nnumber=answer\\nvalue=3\\nclass=large:flex\\n' } }\n".writeInline(to: sums.appendingPathComponent("sums.js"), toml: "title = 'Sums'\nicon = 'equal.square'\ndetail = 'Sums'\nuses = ['clipboard']\n\n[on]\nsearch = '^[0-9]'")
        try "#!/bin/sh\nprintf 'frame=\\nclass=gap-part\\n\\nnumber=answer\\nvalue=3\\ntitle=1 + 2\\nclass=large:flex\\n'\n".writeScript(to: sums.appendingPathComponent("sample.sh"))
        try "# Sums\n\nAdds numbers.\n".write(to: sums.appendingPathComponent("readme.md"), atomically: true, encoding: .utf8)
        let scan = try SpotsFolder(url: folder, core: core).scan()
        let shared = try XCTUnwrap(scan.spots.first { SpotsFolder.coreID(of: $0) == "sums" })

        let text = try shown(ReviewSpot(spot: SpotPackage(sharing: shared, from: scan), folder: folder))

        XCTAssertTrue(text.contains("sums.js\n"), text)
        XCTAssertTrue(text.contains("export default {"), text)
    }

    func testAnInlineSpotShowsItsTextAndRunsOnlyWhenItIsUsed() throws {
        let review = try ReviewSpot(spot: spot([("sum.spot/sum.js", "export default { async show() { return '' } }\n", false), ("sum.spot/spot.toml", "title = 'Sum'\n\n[on]\n\"panel.open\" = true", false)]), folder: folder)

        let text = try shown(review)

        XCTAssertTrue(text.contains("sum.js\nexport default {"), text)
        XCTAssertEqual(review.name, "Sum")
    }

    func testAFileThatIsNotTextIsNamedWithItsSize() throws {
        let files = [
            SpotPackage.File(path: "home.spot/home.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8)),
            SpotPackage.File(path: "home.spot/spot.toml", isExecutable: false, contents: Data("title = 'Home'\n".utf8)),
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

    func testADragOfASpotSaysWhatADropOpens() throws {
        let file = folder.appendingPathComponent("any name.spot")
        try spot([("weather.spot/weather.sh", "#!/bin/sh\n", true), ("weather.spot/spot.toml", "title = 'Weather'\nicon = 'sun.max'\ndetail = 'Today'", false)]).zip(to: file)
        let target = folder.appendingPathComponent("spots")

        let drop = SpotDrop(paths: [file.path], folder: target)

        XCTAssertEqual(drop.title, "Weather")
        XCTAssertEqual(drop.symbol, "sun.max")
        XCTAssertEqual(drop.detail, "Drop to open it in the Store")
        XCTAssertEqual(SpotDrop(paths: [file.path, file.path], folder: target).detail, "Openspot opens one spot at a time")
    }

    func testADragOfABadFileSaysWhyBeforeTheDrop() throws {
        let file = folder.appendingPathComponent("Broken.spot")
        try Data("nope".utf8).write(to: file)

        let drop = SpotDrop(paths: [file.path], folder: folder)

        XCTAssertEqual(drop.title, "Cannot open Broken")
        XCTAssertEqual(drop.detail, "This file is not a spot.")
    }

    func testAPlainScriptRunsOnlyWhenItIsUsed() throws {
        let review = try review("title = 'Weather'")

        XCTAssertEqual(review.subtitle, "Runs only when you use it")
        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("Weather\n\nUses nothing\n\nRuns only when you use it\n\n"), text)
        XCTAssertFalse(text.contains("Runs by itself"))
    }

    func testItSaysWhatRunsByItself() throws {
        let review = try review("title = 'Weather'\n\n[on]\n\"panel.open\" = true\nevery = 30")

        XCTAssertEqual(review.subtitle, "Runs by itself")
        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("Weather\n\nUses nothing\n\nRuns by itself\nWeather: when the panel opens, every 30 seconds\n"), text)
    }

    func testItShowsTheUsesThatTheHeaderNames() throws {
        let text = try shown(review("title = 'Coffee'\nuses = ['network', 'app']"))

        XCTAssertTrue(text.hasPrefix("Coffee\n\nUses\napp, network\n\n"), text)
        XCTAssertFalse(text.contains("Can also"), text)
    }

    func testItListsEachBindingWithItsUsesAndShowsABoundSpotThatIsNotInstalledAsMissing() throws {
        try "#!/bin/sh\n".writeScript(to: folder.spotFile("time-picker"))
        let review = try review("title = 'Snooze'\nuses = ['timer']\n[bindings]\npicker = { spot = 'time-picker' }\nmail = { spot = 'mailer' }")

        let text = try shown(review)

        XCTAssertTrue(text.hasPrefix("Snooze\n\nUses\ntimer\n\nBinds\npicker: time-picker\nmail: mailer, which is not installed\n\n"), text)
        XCTAssertEqual(review.trust, "Uses\ntimer\n\nBinds\npicker: time-picker\nmail: mailer, which is not installed\n\n")
        XCTAssertEqual(review.canDo, ["Binds picker: time-picker", "Binds mail: mailer"])
    }

    func testABindingToASpotThatComesWithOpenspotIsNotMissing() throws {
        let core = folder.appendingPathComponent("core", isDirectory: true)
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("mailer.spot/mailer.sh"))
        let package = folder.appendingPathComponent("drop/snooze.spot", isDirectory: true)
        try "#!/bin/sh\n".writeScript(to: package.appendingPathComponent("snooze.sh"), toml: "title = 'Snooze'\n[bindings]\nmail = { spot = 'mailer' }")
        let lock = SpotLock(url: folder.appendingPathComponent("spots.lock"), environment: ["OPENSPOT_CORE": core.path])

        let review = try ReviewSpot(spot: SpotPackage(contentsOf: package), folder: folder.appendingPathComponent("spots", isDirectory: true), core: SpotsFolder.core(environment: lock.environment))

        XCTAssertEqual(review.trust, "Binds\nmail: mailer\n\n")
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
        let review = try ReviewSpot(spot: spot([("bye.spot/bye.js", "export default { async press() { openspot.call([\"app\", \"quit\"]) } }\n", false), ("bye.spot/spot.toml", "title = 'Bye'", false)]), folder: folder)

        XCTAssertTrue(try shown(review).contains("Can also\nCall openspot app quit without app in the uses of its spot.toml\n"))
    }

    func testAReviewOfANewVersionSaysWhatItAdds() throws {
        try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("weather.spot/weather.sh"), toml: "title = 'Weather'\nuses = ['app']")

        let text = try shown(review("title = 'Weather'\nuses = ['app', 'network', 'screen']"))

        XCTAssertTrue(text.hasPrefix("Weather\nThis version adds: screen, network\n\n"), text)
    }

    func testAReviewReadsTheUsesOfEachInstalledFileOfTheSpot() throws {
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("home"), withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("home.spot/home.sh"), toml: "uses = ['network']")
        try "#!/bin/sh\necho one\n".writeScript(to: folder.appendingPathComponent("home.spot/helper.sh"))
        let review = try ReviewSpot(spot: spot([("home.spot/home.sh", "#!/bin/sh\n", true), ("home.spot/helper.sh", "#!/bin/sh\necho two\n", true), ("home.spot/spot.toml", "uses = ['network']", false)]), folder: folder)

        XCTAssertFalse(try shown(review).contains("This version adds"))
    }

    func testAReviewOfANewVersionThatAddsNothingSaysNothing() throws {
        try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("weather.spot/weather.sh"), toml: "title = 'Weather'\nuses = ['app']")

        let text = try shown(review("title = 'Weather'\nuses = ['app']"))

        XCTAssertFalse(text.contains("This version adds"), text)
    }

    func testAStayingScriptSaysSo() throws {
        let review = try review("title = 'Weather'\nstay = true")

        let text = try shown(review)
        XCTAssertTrue(text.contains("Weather: keeps running while it is in use"), text)
    }

    func testAScriptThatAlwaysStaysSaysSo() throws {
        let review = try review("title = 'Relay'\nstay = true\n\n[on]\n\"app.launch\" = true")

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
        XCTAssertTrue(text.contains("Will not load\nbad: Bad has an unknown key in its spot.toml: mode"), text)
    }

    func testAClashWithAFolderIsRefusedBeforeTheReviewShows() throws {
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("weather.spot/weather.sh"), withIntermediateDirectories: true)

        XCTAssertThrowsError(try review(""))
    }

    private func filed(_ toml: String, body: String = "") throws -> ReviewSpot {
        let file = folder.appendingPathComponent("Weather.spot")
        try spot([("weather.spot/weather.sh", "#!/bin/sh\n\(body)", true), ("weather.spot/spot.toml", toml, false)]).zip(to: file)
        return try ReviewSpot(spot: SpotPackage(contentsOf: file), folder: folder.appendingPathComponent("spots"))
    }

    func testNoScriptRunsForAReview() async throws {
        let mark = folder.appendingPathComponent("ran")
        let review = try filed("[on]\n\"panel.open\" = true", body: "touch \"\(mark.path)\"\n")
        _ = try review.answer(["show"])

        XCTAssertFalse(FileManager.default.fileExists(atPath: mark.path))
    }

    func testTheAppOffersTheReviewAsASheetThatGrowsOutOfTheField() async throws {
        let review = try review("title = 'Weather'")
        let command = review.spot

        XCTAssertEqual(command.name, "Weather")
        XCTAssertEqual(command.subtitle, "Runs only when you use it")
        XCTAssertEqual(command.kind, .list)
        XCTAssertEqual(command.triggers, .sheet)
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
            ("timer.spot/sample.frame", "item=a\ntitle=5 minutes\n", false)
        ])
        let store = folder.appendingPathComponent("store")
        try shared.write(to: store)
        let package = store.appendingPathComponent("timer.spot")
        let review = try ReviewSpot(spot: SpotPackage(contentsOf: package), folder: folder.appendingPathComponent("spots"))

        let text = try shown(review)
        XCTAssertTrue(text.hasPrefix("Timer\n\nUses nothing\n\nRuns only when you use it\n\nCounts down from a time you pick.\n\nPreview\n5 minutes\n\n"), text)
    }

    func testThePreviewReadsTheViewsOfTheSpot() throws {
        let review = try ReviewSpot(spot: spot([
            ("cups.spot/cups.sh", "#!/bin/sh\n", true),
            ("cups.spot/spot.toml", "title = 'Cups'\nviews = ['liquid.swift']", false),
            ("cups.spot/sample.frame", "frame=\nclass=gap-part\n\nitems=list\n\nitem=a\nparent=list\ntitle=Water\n\nliquid=b\nparent=list\ntitle=Juice\n", false)
        ]), folder: folder)

        let text = try shown(review)
        XCTAssertTrue(text.contains("Preview\nWater\nJuice\n\n"), text)
    }
}
