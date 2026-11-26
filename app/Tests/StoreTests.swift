import XCTest
@testable import OpenspotCore

@MainActor
final class StoreTests: XCTestCase {
    private var root: URL!
    private var places: AppPlaces!
    private var store: Store!
    private var toasts: [String] = []
    private var changes = 0

    override func setUp() async throws {
        root = try temporaryFolder()
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let trash = trash
        places = AppPlaces(
            environment: [
                "OPENSPOT_CONFIG": root.appendingPathComponent("config").path, "OPENSPOT_SPOTS": spots.path, "OPENSPOT_CORE": core.path,
                "OPENSPOT_EXAMPLES": examples.path
            ],
            home: root,
            defaults: UserDefaults(suiteName: "openspot-store-\(UUID().uuidString)") ?? .standard,
            trash: { url in try FileManager.default.moveItem(at: url, to: trash.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)) },
            defaultConfig: nil
        )
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"), toml: "title = 'Timer'\ndetail = 'Counts down'")
        try "#!/bin/sh\necho one\n".writeScript(to: examples.appendingPathComponent("clock.spot/clock.sh"), toml: "title = 'Clock'\ndetail = 'Tells the time'")
        try "#!/bin/sh\npbcopy\n".writeScript(to: examples.appendingPathComponent("paste.spot/paste.sh"), toml: "title = 'Paste'\nuses = ['clipboard']")
        try "#!/bin/sh\n".writeScript(to: spots.appendingPathComponent("mine.spot/mine.sh"), toml: "title = 'Mine'")
        store = Store(places: places, changed: { [weak self] in self?.changes += 1 }, toast: { [weak self] in self?.toasts.append($0.words) })
    }

    private var spots: URL { root.appendingPathComponent("spots", isDirectory: true) }
    private var core: URL { root.appendingPathComponent("core", isDirectory: true) }
    private var examples: URL { root.appendingPathComponent("examples", isDirectory: true) }
    private var trash: URL { root.appendingPathComponent("trash", isDirectory: true) }

    private func friends() throws -> URL {
        let friends = root.appendingPathComponent("friends", isDirectory: true)
        try "#!/bin/sh\n".writeScript(to: friends.appendingPathComponent("ports.spot/ports.sh"), toml: "title = 'Ports'")
        return friends
    }

    private func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: spots.appendingPathComponent(path).path)
    }

    private func release(_ id: String, _ body: String, toml: String) throws {
        let folder = examples.appendingPathComponent("\(id).spot")
        try body.write(to: folder.appendingPathComponent("\(id).sh"), atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.appendingPathComponent("\(id).sh").path)
        try toml.write(to: folder.appendingPathComponent("spot.toml"), atomically: true, encoding: .utf8)
        let later = try XCTUnwrap(ISO8601DateFormatter().date(from: "2031-11-25T12:00:00Z"))
        try FileManager.default.setAttributes([.modificationDate: later], ofItemAtPath: folder.appendingPathComponent("spot.toml").path)
    }

    private func installed(_ id: String) async throws {
        await store.install(id)
        await store.confirm()
        XCTAssertNil(store.ask)
    }

    private var marks: [String] {
        store.cards.map { "\($0.id)\($0.mark.map { " \($0.rawValue)" } ?? "")" }
    }

    func testItListsMySpotsThenTheBuiltInSourceThenEachAddedFolder() async throws {
        let friends = try friends()
        _ = try places.config.change { $0.add(store: StoreSource(url: friends)) }

        await store.read()

        XCTAssertEqual(store.sources.map(\.name), ["Openspot", "friends"])
        XCTAssertEqual(store.sources.map(\.isBuiltIn), [true, false])
        XCTAssertEqual(store.place, .mine)
        XCTAssertEqual(marks, ["mine", "timer core"])
    }

    func testASourceShowsEachOfItsSpotsAndMarksTheOnesYouHave() async throws {
        try "#!/bin/sh\n".writeScript(to: spots.appendingPathComponent("clock.spot/clock.sh"), toml: "title = 'Clock'")
        await store.read()

        store.choose(.source(.builtIn(examples)))

        XCTAssertEqual(marks, ["clock installed", "paste"])
    }

    func testBackReturnsToTheVisitThatWasLeftAndAFreshOpenIsANewVisit() async throws {
        await store.read()
        store.choose(.source(.builtIn(examples)))
        let shelf = store.visit

        await store.open("clock")
        XCTAssertNotEqual(store.visit, shelf)
        await store.goBack()
        XCTAssertEqual(store.visit, shelf)
        await store.goForward()
        let page = store.visit
        await store.goBack()
        await store.open("clock")

        XCTAssertEqual(store.page?.id, "clock")
        XCTAssertNotEqual(store.visit, page)
        XCTAssertNotEqual(store.visit, shelf)
    }

    func testBackAndForwardStepThroughThePlacesAndPagesYouOpened() async throws {
        await store.read()
        XCTAssertEqual(store.title, "My spots")
        XCTAssertTrue(store.back.isEmpty)

        store.choose(.source(.builtIn(examples)))
        await store.open("clock")
        XCTAssertEqual(store.title, "Clock")

        await store.goBack()
        XCTAssertNil(store.page)
        XCTAssertEqual(store.title, "Openspot")
        await store.goBack()
        XCTAssertEqual(store.place, .mine)
        XCTAssertTrue(store.back.isEmpty)

        await store.goForward()
        XCTAssertEqual(store.place, .source(.builtIn(examples)))
        await store.goForward()
        XCTAssertEqual(store.page?.id, "clock")
        XCTAssertTrue(store.forward.isEmpty)

        store.choose(.mine)
        XCTAssertTrue(store.forward.isEmpty)
        XCTAssertEqual(store.back.last.map { [$0.place, $0.spot] as [AnyHashable?] }, [StorePlace.source(.builtIn(examples)), "clock"])
    }

    func testShowingThePageThatShowsAddsNoStopAndASearchFromAPageCanGoBackToIt() async throws {
        await store.read()
        _ = await store.show("clock", search: nil)
        let stops = store.back

        _ = await store.show("clock", search: nil)
        XCTAssertEqual(store.back, stops)

        store.search("tells")
        XCTAssertNil(store.page)
        XCTAssertEqual(store.back.last.map { [$0.place, $0.spot] as [AnyHashable?] }, [StorePlace.source(.builtIn(examples)), "clock"])
    }

    func testARemovedSourceLeavesTheHistory() async throws {
        let friends = try friends()
        await store.read()
        await store.addSource(friends)
        store.choose(.mine)
        XCTAssertTrue(store.back.contains { $0.place.source?.url.path == friends.path })

        await store.removeSource(friends)

        XCTAssertFalse(store.back.contains { $0.place.source?.url.path == friends.path })
        XCTAssertFalse(store.forward.contains { $0.place.source?.url.path == friends.path })
    }

    func testTheSearchKeepsOnlyTheCardsOfThePlaceThatMatch() async throws {
        await store.read()
        store.choose(.source(.builtIn(examples)))

        store.search("tells")

        XCTAssertEqual(marks, ["clock"])
        store.choose(.mine)
        XCTAssertEqual(marks, [])
    }

    func testOpenWithAnIDShowsThePageOfThatSpotInItsPlace() async throws {
        try "# Clock\n\nTells the time.\n".write(to: examples.appendingPathComponent("clock.spot/readme.md"), atomically: true, encoding: .utf8)
        let day = try XCTUnwrap(ISO8601DateFormatter().date(from: "2031-11-03T12:00:00Z"))
        try FileManager.default.setAttributes([.modificationDate: day], ofItemAtPath: examples.appendingPathComponent("clock.spot/spot.toml").path)

        let found = await store.show("clock", search: nil)

        XCTAssertTrue(found)
        XCTAssertEqual(store.place, .source(.builtIn(examples)))
        let page = try XCTUnwrap(store.page)
        XCTAssertEqual(page.id, "clock")
        XCTAssertEqual(page.from, "From Openspot")
        XCTAssertEqual(page.updated, "Updated 3 Nov 2031")
        XCTAssertEqual(page.readme, ["# Clock", "", "Tells the time."])
        XCTAssertEqual(page.button, .install)
        XCTAssertEqual(page.trust.map(\.title), ["Uses", "Runs by itself", "Files"])
    }

    func testMySpotsGroupYoursApartFromTheOnesThatComeWithOpenspot() async throws {
        await store.read()

        XCTAssertEqual(store.groups.map(\.title), ["Yours", "Comes with Openspot"])
        XCTAssertEqual(store.groups.map { $0.cards.map(\.id) }, [["mine"], ["timer"]])
        XCTAssertEqual(store.summary, "1 yours · 1 comes with Openspot")
        store.choose(.source(.builtIn(examples)))
        XCTAssertEqual(store.groups.map(\.title), [nil])
    }

    func testASourceCardCarriesTheCardOfItsSampleData() async throws {
        try "frame=\nclass=gap-part\n\ntext=time\nclass=hidden card:flex\ntitle=21:45\n".write(to: examples.appendingPathComponent("clock.spot/sample.frame"), atomically: true, encoding: .utf8)
        await store.read()

        store.choose(.source(.builtIn(examples)))

        let clock = try XCTUnwrap(store.cards.first { $0.id == "clock" })
        XCTAssertEqual(clock.preview.size, .wide)
        XCTAssertTrue(clock.preview.face.draws(on: .wide))
        let paste = try XCTUnwrap(store.cards.first { $0.id == "paste" })
        XCTAssertEqual(paste.preview.size, .strip)
        XCTAssertFalse(paste.preview.drawsCard)
        XCTAssertTrue(clock.preview.drawsCard)
        XCTAssertFalse(paste.preview.face.draws(on: .strip))
    }

    func testInlineCodeOfAReadmeNeverBreaksAcrossLines() async throws {
        try "Run `claude -p /usage` or `a-b` here.\n".write(to: examples.appendingPathComponent("clock.spot/readme.md"), atomically: true, encoding: .utf8)

        _ = await store.show("clock", search: nil)

        guard case .text(let text)? = store.page?.shown.first else { return XCTFail("No text") }
        XCTAssertEqual(String(text.characters), "Run claude\u{00A0}-\u{2060}p\u{00A0}/usage or a-\u{2060}b here.")
        let code = text.runs.filter { $0.inlinePresentationIntent?.contains(.code) == true }.map { String(text[$0.range].characters) }
        XCTAssertEqual(code, ["claude\u{00A0}-\u{2060}p\u{00A0}/usage", "a-\u{2060}b"])
    }

    func testWrappedLinesOfAReadmeShowAsOneParagraph() async throws {
        let readme = "# Clock\n\nTells the time\nof each city.\n\n## Use\n\n- one\n  more\n- two\n1. first\n\n> A note\n> that wraps.\n\n```\nsh clock.sh\n  --zone Tokyo\n```\n"
        try readme.write(to: examples.appendingPathComponent("clock.spot/readme.md"), atomically: true, encoding: .utf8)

        _ = await store.show("clock", search: nil)

        let shown = try XCTUnwrap(store.page?.shown).map { line -> String in
            switch line {
            case .heading(let level, let text): "h\(level) \(text)"
            case .text(let text): String(text.characters)
            case .item(let marker, let text): "\(marker) \(String(text.characters))"
            case .quote(let text): "> \(String(text.characters))"
            case .code(let text): "code \(text)"
            case .media(let path, _): path
            }
        }
        XCTAssertEqual(shown, [
            "Tells the time of each city.", "h2 Use", "• one more", "• two", "1. first", "> A note that wraps.", "code sh clock.sh\n  --zone Tokyo"
        ])
    }

    func testOpenWithTextSearchesTheFirstSourceThatHasAMatch() async throws {
        let found = await store.show(nil, search: "paste")

        XCTAssertTrue(found)
        XCTAssertEqual(store.query, "paste")
        XCTAssertEqual(store.place, .source(.builtIn(examples)))
        XCTAssertEqual(marks, ["paste"])
    }

    func testAnUnknownIDOpensNothing() async throws {
        let found = await store.show("nope", search: nil)

        XCTAssertFalse(found)
        XCTAssertNil(store.page)
    }

    func testTheTrustLinesOfAPageNameWhatTheSpotUses() async throws {
        await store.read()
        store.choose(.source(.builtIn(examples)))

        await store.open("paste")

        let trust = try XCTUnwrap(store.page?.trust)
        XCTAssertEqual(trust.first { $0.title == "Uses" }?.words, ["clipboard"])
        XCTAssertEqual(trust.first { $0.title == "Can also" }?.words, ["Copy with `pbcopy` in place of `openspot clipboard`"])
        XCTAssertEqual(trust.first { $0.title == "Files" }?.words, ["paste.spot/paste.sh", "paste.spot/spot.toml"])
        let files = try XCTUnwrap(store.page?.files)
        XCTAssertEqual(files.map(\.name), ["paste.sh", "spot.toml"])
        XCTAssertEqual(files.map(\.symbol), ["terminal", "gearshape"])
        XCTAssertEqual(files.first?.url, examples.appendingPathComponent("paste.spot/paste.sh"))
        XCTAssertEqual(files.first?.size, "17 bytes")
    }

    func testACoreSpotIsLockedInMySpots() async throws {
        await store.read()

        await store.open("timer")

        XCTAssertEqual(store.page?.button, .locked)
        XCTAssertEqual(store.page?.from, "From Openspot")
    }

    func testInstallFromTheOpenPageCopiesAtOnceWithItsSampleCard() async throws {
        try "frame=\n\ntext=one\nclass=hidden card:flex\ntitle=1\n".write(to: examples.appendingPathComponent("paste.spot/sample.frame"), atomically: true, encoding: .utf8)
        await store.read()
        store.choose(.source(.builtIn(examples)))
        await store.open("paste")
        XCTAssertEqual(store.page?.preview.size, .wide)

        await store.installPage()

        XCTAssertNil(store.ask)
        XCTAssertTrue(exists("paste.spot/paste.sh"))
        XCTAssertEqual(store.page?.button, .installed)
    }

    func testInstallFromAPageWhoseSourceChangedSinceShowsTheReview() async throws {
        await store.read()
        store.choose(.source(.builtIn(examples)))
        await store.open("clock")
        try "title = 'Clock'\nuses = ['network']".write(to: examples.appendingPathComponent("clock.spot/spot.toml"), atomically: true, encoding: .utf8)

        await store.installPage()

        guard case .install? = store.ask else { return XCTFail("No review: \(String(describing: store.ask))") }
        XCTAssertFalse(exists("clock.spot"))
    }

    func testInstallOpensTheReviewAndCopiesNothingUntilItsYes() async throws {
        await store.read()
        store.choose(.source(.builtIn(examples)))

        await store.install("paste")

        guard case .install(let review)? = store.ask else { return XCTFail("No review: \(String(describing: store.ask))") }
        XCTAssertEqual(review.name, "Paste")
        XCTAssertEqual(review.from, "From Openspot")
        XCTAssertEqual(review.lines.first { $0.title == "Uses" }?.words, ["clipboard"])
        XCTAssertFalse(exists("paste.spot"))

        await store.confirm()

        XCTAssertTrue(exists("paste.spot/paste.sh"))
        XCTAssertNil(store.ask)
        XCTAssertEqual(marks, ["clock", "paste installed"])
        XCTAssertEqual(toasts, ["Installed Paste."])
        XCTAssertEqual(changes, 1)
    }

    func testInstallRefusesASourceFolderChangedSinceItsReview() async throws {
        await store.read()
        store.choose(.source(.builtIn(examples)))
        await store.install("paste")
        try "#!/bin/sh\ncurl -s example.com | pbcopy\n".write(to: examples.appendingPathComponent("paste.spot/paste.sh"), atomically: true, encoding: .utf8)

        await store.confirm()

        XCTAssertFalse(exists("paste.spot"))
        XCTAssertEqual(toasts, ["The file changed after you looked at it, so Openspot added nothing. Open it again to see it."])
    }

    func testStopLeavesYourSpotsAsTheyWere() async throws {
        await store.read()
        store.choose(.source(.builtIn(examples)))
        await store.install("paste")

        store.dismissAsk()

        XCTAssertNil(store.ask)
        XCTAssertFalse(exists("paste.spot"))
    }

    func testTheListOfMySpotsHoldsASpotRightAfterItsInstall() async throws {
        await store.read()
        store.choose(.source(.builtIn(examples)))

        try await installed("clock")
        store.choose(.mine)

        XCTAssertEqual(marks, ["clock", "mine", "timer core"])
    }

    func testASameIDInstallAsksFirstAndKeepBothGivesANewID() async throws {
        try "#!/bin/sh\necho mine\n".writeScript(to: spots.appendingPathComponent("clock.spot/clock.sh"), toml: "title = 'My clock'")
        await store.read()
        store.choose(.source(.builtIn(examples)))

        await store.install("clock")
        guard case .clash(let asked)? = store.ask else { return XCTFail("No question: \(String(describing: store.ask))") }
        XCTAssertEqual(asked.name, "Clock")

        await store.confirm(.keepBoth)
        guard case .install(let review)? = store.ask else { return XCTFail("No review after Keep Both") }
        XCTAssertEqual(review.clash, .keepBoth)
        await store.confirm()

        XCTAssertTrue(exists("clock-2.spot/clock-2.sh"))
        XCTAssertTrue(try String(contentsOf: spots.appendingPathComponent("clock.spot/clock.sh"), encoding: .utf8).contains("mine"))
        XCTAssertEqual(toasts, ["Installed Clock as clock-2."])
    }

    private func spotFile(_ id: String, _ body: String, toml: String) throws -> URL {
        let file = root.appendingPathComponent("\(id.capitalized).spot")
        try SpotPackage(files: [
            .init(path: "\(id).spot/\(id).sh", isExecutable: true, contents: Data(body.utf8)),
            .init(path: "\(id).spot/spot.toml", isExecutable: false, contents: Data(toml.utf8))
        ]).zip(to: file)
        return file
    }

    func testASpotWithSampleDataOffersTryOnItsPage() async throws {
        try "text=Stand-up\n".write(to: examples.appendingPathComponent("clock.spot/sample.frame"), atomically: true, encoding: .utf8)
        await store.read()
        store.choose(.source(.builtIn(examples)))

        await store.open("clock")
        let sampled = try XCTUnwrap(store.page)
        await store.open("paste")
        let plain = try XCTUnwrap(store.page)

        XCTAssertTrue(sampled.hasSample)
        XCTAssertFalse(sampled.runsSample)
        XCTAssertFalse(plain.hasSample)
    }

    func testAnOpenedSpotFileShowsItsPageWithItsTrustLines() async throws {
        let file = try spotFile("cups", "#!/bin/sh\npbcopy\n", toml: "title = 'Cups'\nuses = ['clipboard']")

        let isShown = await store.show(file: file)

        XCTAssertTrue(isShown)
        XCTAssertEqual(store.place.source?.url, file)
        XCTAssertEqual(store.sources.last?.name, "Cups.spot")
        let page = try XCTUnwrap(store.page)
        XCTAssertEqual(page.id, "cups")
        XCTAssertEqual(page.from, "From Cups.spot")
        XCTAssertEqual(page.button, .install)
        XCTAssertEqual(page.trust.first, ReviewLine(title: "Uses", words: ["clipboard"]))
        XCTAssertEqual(page.trust.first { $0.title == "Can also" }?.words, ["Copy with `pbcopy` in place of `openspot clipboard`"])
    }

    func testASpotPageNamesEachUseWithTheMacAccessItNeeds() async throws {
        let file = try spotFile("shots", "#!/bin/sh\nopenspot screen shot\n", toml: "title = 'Shots'\nuses = ['screen', 'clipboard']")

        _ = await store.show(file: file)

        let page = try XCTUnwrap(store.page)
        XCTAssertEqual(page.uses.map(\.id), [.clipboard, .screen])
        XCTAssertEqual(page.uses.first { $0.id == .screen }?.needs, [.screen])
        XCTAssertEqual(page.uses.first { $0.id == .clipboard }?.needs, [])
    }

    func testInstallOfAnOpenedFileAddsTheFileItRead() async throws {
        let file = try spotFile("cups", "#!/bin/sh\necho one\n", toml: "title = 'Cups'")
        _ = await store.show(file: file)

        try await installed("cups")

        XCTAssertEqual(try String(contentsOf: spots.appendingPathComponent("cups.spot/cups.sh"), encoding: .utf8), "#!/bin/sh\necho one\n")
        XCTAssertEqual(toasts, ["Installed Cups."])
        XCTAssertEqual(store.page?.button, .installed)
    }

    func testInstallOfAnOpenedFileRefusesAFileChangedSince() async throws {
        let file = try spotFile("cups", "#!/bin/sh\necho one\n", toml: "title = 'Cups'")
        _ = await store.show(file: file)
        await store.install("cups")
        try FileManager.default.removeItem(at: file)
        _ = try spotFile("cups", "#!/bin/sh\necho two\n", toml: "title = 'Cups'")

        await store.confirm()

        XCTAssertFalse(exists("cups.spot"))
        XCTAssertEqual(toasts, ["The file changed after you looked at it, so Openspot added nothing. Open it again to see it."])
    }

    func testKeepBothOfAnOpenedFileGivesANewID() async throws {
        try "#!/bin/sh\necho mine\n".writeScript(to: spots.appendingPathComponent("cups.spot/cups.sh"), toml: "title = 'My cups'")
        let file = try spotFile("cups", "#!/bin/sh\necho one\n", toml: "title = 'Cups'")
        _ = await store.show(file: file)

        await store.install("cups")
        await store.confirm(.keepBoth)
        await store.confirm()

        XCTAssertEqual(try String(contentsOf: spots.appendingPathComponent("cups-2.spot/cups-2.sh"), encoding: .utf8), "#!/bin/sh\necho one\n")
        XCTAssertTrue(try String(contentsOf: spots.appendingPathComponent("cups.spot/cups.sh"), encoding: .utf8).contains("mine"))
        XCTAssertEqual(toasts, ["Installed Cups as cups-2."])
    }

    func testAnUpdateThatAsksForANewPowerShowsUpdateAndNamesOnlyThatPower() async throws {
        await store.read()
        try await installed("clock")
        try release("clock", "#!/bin/sh\npbcopy\n", toml: "title = 'Clock'\nuses = ['clipboard', 'network']\n")
        await store.read()
        store.choose(.mine)

        await store.open("clock")
        XCTAssertEqual(store.page?.button, .update)
        XCTAssertEqual(marks, ["clock update", "mine", "timer core"])
        await store.update("clock")

        guard case .update(let change)? = store.ask else { return XCTFail("No review of the update") }
        XCTAssertEqual(change.powers, ["Uses clipboard, network", "Can also: Copy with pbcopy in place of openspot clipboard"])
        XCTAssertFalse(try String(contentsOf: spots.appendingPathComponent("clock.spot/clock.sh"), encoding: .utf8).contains("pbcopy"))

        await store.confirm()

        XCTAssertTrue(try String(contentsOf: spots.appendingPathComponent("clock.spot/clock.sh"), encoding: .utf8).contains("pbcopy"))
        XCTAssertEqual(store.page?.button, .installed)
    }

    func testUpdateRefusesASourceFolderChangedSinceItsReview() async throws {
        await store.read()
        try await installed("clock")
        try release("clock", "#!/bin/sh\npbcopy\n", toml: "title = 'Clock'\nuses = ['clipboard']\n")
        await store.read()
        await store.update("clock")
        try release("clock", "#!/bin/sh\npbcopy\n", toml: "title = 'Clock'\nuses = ['clipboard', 'network']\n")

        await store.confirm()

        XCTAssertFalse(try String(contentsOf: spots.appendingPathComponent("clock.spot/clock.sh"), encoding: .utf8).contains("pbcopy"))
        XCTAssertEqual(toasts.last, "The file changed after you looked at it, so Openspot added nothing. Open it again to see it.")
    }

    func testAnEditedCopyShowsEditedAndRevertAsksReplace() async throws {
        await store.read()
        try await installed("clock")
        try "#!/bin/sh\necho edited\n".write(to: spots.appendingPathComponent("clock.spot/clock.sh"), atomically: true, encoding: .utf8)
        await store.read()
        store.choose(.mine)
        await store.open("clock")
        XCTAssertEqual(store.page?.button, .edited)
        XCTAssertEqual(store.page?.from, "From Openspot")

        await store.revert("clock")
        guard case .revert(let change)? = store.ask else { return XCTFail("No Replace question") }
        XCTAssertEqual(change.name, "Clock")
        await store.confirm(.replace)

        XCTAssertEqual(try String(contentsOf: spots.appendingPathComponent("clock.spot/clock.sh"), encoding: .utf8), "#!/bin/sh\necho one\n")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: trash.path).count, 1)
        XCTAssertEqual(store.page?.button, .installed)
    }

    func testAddSourceListsItsSpotsAndRemoveDropsIt() async throws {
        let friends = try friends()
        await store.read()

        await store.addSource(friends)

        XCTAssertEqual(places.config.read().stores.map(\.url.path), [friends.path])
        XCTAssertEqual(store.place, .source(StoreSource(url: friends)))
        XCTAssertEqual(marks, ["ports"])
        await store.removeSource(friends)
        XCTAssertEqual(places.config.read().stores, [])
        XCTAssertEqual(store.place, .mine)
    }

    func testAGoneSourceIsMarkedMissing() async throws {
        let gone = root.appendingPathComponent("gone", isDirectory: true)
        _ = try places.config.change { $0.add(store: StoreSource(url: gone)) }

        await store.read()

        XCTAssertEqual(store.missing, [gone.standardizedFileURL.path])
    }

    func testStoreOpenAsksTheRunningAppToShowIt() async throws {
        let app = FakeRunningApp()
        let api = CommandAPI(mac: Mac(), places: places, app: app)

        let answer = try await XCTUnwrap(api.work(for: CommandRequest(arguments: ["store", "open", "clock"], folder: root.path), input: { "" }))()
        let searched = try await XCTUnwrap(api.work(for: CommandRequest(arguments: ["store", "open", "--search", "a clock"], folder: root.path), input: { "" }))()
        let unknown = try await XCTUnwrap(api.work(for: CommandRequest(arguments: ["store", "open", "nope"], folder: root.path), input: { "" }))()

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(searched.code, 0, searched.errors)
        let opened = await app.opened
        XCTAssertEqual(opened, ["store clock", "store search a clock"])
        XCTAssertEqual(unknown.code, 1)
        XCTAssertEqual(unknown.errors, "`nope` is not a spot of the Store. Run `openspot store list` to see each one.\n")
    }
}
