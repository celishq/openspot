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

        store.choose(.source(examples))

        XCTAssertEqual(marks, ["clock installed", "paste"])
    }

    func testTheSearchKeepsOnlyTheCardsOfThePlaceThatMatch() async throws {
        await store.read()
        store.choose(.source(examples))

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
        XCTAssertEqual(store.place, .source(examples))
        let page = try XCTUnwrap(store.page)
        XCTAssertEqual(page.id, "clock")
        XCTAssertEqual(page.from, "From Openspot")
        XCTAssertEqual(page.updated, "Updated 3 Nov 2031")
        XCTAssertEqual(page.readme, ["# Clock", "", "Tells the time."])
        XCTAssertEqual(page.button, .install)
        XCTAssertEqual(page.trust.map(\.title), ["Uses", "Runs by itself", "Files"])
    }

    func testOpenWithTextSearchesTheFirstSourceThatHasAMatch() async throws {
        let found = await store.show(nil, search: "paste")

        XCTAssertTrue(found)
        XCTAssertEqual(store.query, "paste")
        XCTAssertEqual(store.place, .source(examples))
        XCTAssertEqual(marks, ["paste"])
    }

    func testAnUnknownIDOpensNothing() async throws {
        let found = await store.show("nope", search: nil)

        XCTAssertFalse(found)
        XCTAssertNil(store.page)
    }

    func testTheTrustLinesOfAPageNameWhatTheSpotUses() async throws {
        await store.read()
        store.choose(.source(examples))

        await store.open("paste")

        let trust = try XCTUnwrap(store.page?.trust)
        XCTAssertEqual(trust.first { $0.title == "Uses" }?.words, ["clipboard"])
        XCTAssertEqual(trust.first { $0.title == "Can also" }?.words, ["Copy with pbcopy in place of openspot clipboard"])
        XCTAssertEqual(trust.first { $0.title == "Files" }?.words, ["paste.spot/paste.sh", "paste.spot/spot.toml"])
    }

    func testACoreSpotIsLockedInMySpots() async throws {
        await store.read()

        await store.open("timer")

        XCTAssertEqual(store.page?.button, .locked)
        XCTAssertEqual(store.page?.from, "Comes with Openspot")
    }

    func testInstallOpensTheReviewAndCopiesNothingUntilItsYes() async throws {
        await store.read()
        store.choose(.source(examples))

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

    func testStopLeavesYourSpotsAsTheyWere() async throws {
        await store.read()
        store.choose(.source(examples))
        await store.install("paste")

        store.dismissAsk()

        XCTAssertNil(store.ask)
        XCTAssertFalse(exists("paste.spot"))
    }

    func testTheListOfMySpotsHoldsASpotRightAfterItsInstall() async throws {
        await store.read()
        store.choose(.source(examples))

        try await installed("clock")
        store.choose(.mine)

        XCTAssertEqual(marks, ["clock", "mine", "timer core"])
    }

    func testASameIDInstallAsksFirstAndKeepBothGivesANewID() async throws {
        try "#!/bin/sh\necho mine\n".writeScript(to: spots.appendingPathComponent("clock.spot/clock.sh"), toml: "title = 'My clock'")
        await store.read()
        store.choose(.source(examples))

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

    func testAnEditedCopyShowsEditedAndRevertAsksReplace() async throws {
        await store.read()
        try await installed("clock")
        try "#!/bin/sh\necho edited\n".write(to: spots.appendingPathComponent("clock.spot/clock.sh"), atomically: true, encoding: .utf8)
        await store.read()
        store.choose(.mine)
        await store.open("clock")
        XCTAssertEqual(store.page?.button, .edited)

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
        XCTAssertEqual(store.place, .source(friends))
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
