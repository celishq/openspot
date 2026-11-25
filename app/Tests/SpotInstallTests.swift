import XCTest
@testable import OpenspotCore

final class SpotInstallTests: XCTestCase {
    private var root: URL!
    private var places: AppPlaces!

    override func setUpWithError() throws {
        root = try temporaryFolder()
        let trash = root.appendingPathComponent("trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        places = AppPlaces(
            environment: ["OPENSPOT_CONFIG": root.appendingPathComponent("config").path, "OPENSPOT_SPOTS": spots.path, "OPENSPOT_CORE": core.path],
            home: root,
            defaults: UserDefaults(suiteName: "openspot-install-\(UUID().uuidString)") ?? .standard,
            trash: { url in try FileManager.default.moveItem(at: url, to: trash.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)) },
            defaultConfig: nil
        )
        try "#!/bin/sh\n".writeScript(to: source.appendingPathComponent("clock.spot/clock.sh"), toml: "title = 'Clock'")
        try "#!/bin/sh\npbcopy\n".writeScript(to: source.appendingPathComponent("paste.spot/paste.sh"), toml: "title = 'Paste'\nuses = ['clipboard']")
        try "#!/bin/sh\n".writeScript(to: core.appendingPathComponent("timer.spot/timer.sh"), toml: "title = 'Timer'")
    }

    private var spots: URL { root.appendingPathComponent("spots", isDirectory: true) }
    private var core: URL { root.appendingPathComponent("core", isDirectory: true) }
    private var source: URL { root.appendingPathComponent("friends", isDirectory: true) }

    private var catalog: SpotCatalog {
        SpotCatalog(published: places.store, folder: places.spots, arrangement: places.config.read().arrangement, stores: [StoreSource(url: source)])
    }

    private func install(_ id: String, _ clash: SpotClash? = nil, isConfirmed: Bool = false) async throws -> String {
        let install = try XCTUnwrap(try catalog.install(id, in: places))
        return try await install.run(clash, isConfirmed: isConfirmed)
    }

    private func mine() throws {
        try "#!/bin/sh\necho mine\n".writeScript(to: spots.appendingPathComponent("clock.spot/clock.sh"), toml: "title = 'My clock'")
    }

    private func text(_ path: String) throws -> String {
        try String(contentsOf: spots.appendingPathComponent(path), encoding: .utf8)
    }

    private func shown(_ review: ReviewSpot) throws -> Frame {
        Frame(text: try review.answer(["show"]))
    }

    func testInstallCopiesTheFolderOfItsSourceAndLeavesTheSourceAsItIs() async throws {
        let said = try await install("clock")

        XCTAssertEqual(said, "Installed Clock.\n")
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("clock.spot/clock.sh").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.appendingPathComponent("clock.spot/clock.sh").path))
        XCTAssertEqual(try places.lock.entries().map(\.paths), [["clock.spot"]])
    }

    func testAnInstallRecordsItsSourceAndTheVersionOfItsSource() async throws {
        _ = try await install("clock")

        let entry = try XCTUnwrap(try places.lock.entries().first)
        XCTAssertEqual(entry.source, source.appendingPathComponent("clock.spot").path)
        XCTAssertEqual(entry.version, try SpotVersion(of: source.appendingPathComponent("clock.spot")).text)
    }

    func testInstallMakesTheSpotSearchableAndLeavesItOffTheGrid() async throws {
        _ = try await install("clock")

        let arrangement = places.config.read().arrangement
        XCTAssertEqual(arrangement.isOnGrid(of: "clock"), false)
        XCTAssertNotEqual(arrangement.isFound(of: "clock"), false)
    }

    func testAnInstallKeepsWhereThePersonPutTheSpotBefore() async throws {
        _ = try places.config.change { $0.arrangement.set(isOnGrid: true, of: "clock") }

        _ = try await install("clock")

        XCTAssertEqual(places.config.read().arrangement.isOnGrid(of: "clock"), true)
    }

    func testASpotThatAsksForTrustIsCopiedOnlyAfterAYes() async throws {
        do {
            _ = try await install("paste")
            XCTFail("an install with a use passed with no yes")
        } catch {
            let said = (error as? SpotError)?.reason ?? ""
            XCTAssertTrue(said.hasPrefix("Paste\n\nUses\nclipboard\n\n"), said)
            XCTAssertTrue(said.contains("Can also\nCopy with pbcopy in place of openspot clipboard\n\n"), said)
            XCTAssertTrue(said.contains("Files\npaste.spot/paste.sh\npaste.spot/spot.toml\n\n"), said)
            XCTAssertTrue(said.hasSuffix("Openspot installed nothing. Run `openspot store get paste --yes` to install it."), said)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: spots.appendingPathComponent("paste.spot").path))

        _ = try await install("paste", isConfirmed: true)

        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("paste.spot/paste.sh").path))
    }

    func testACoreSpotNeedsNoInstall() throws {
        XCTAssertNil(try catalog.install("timer", in: places))
    }

    func testTheReviewOfAnInstallShowsItsFilesBeforeItsInstallButtonCopiesThem() async throws {
        let review = try XCTUnwrap(try catalog.install("clock", in: places)).review()
        let sheet = Frame(text: try review.answer(["show"]))

        let button = try XCTUnwrap(sheet.parts.first { $0.id == "install" })
        XCTAssertEqual(button.title, "Install")
        XCTAssertFalse(FileManager.default.fileExists(atPath: spots.appendingPathComponent("clock.spot").path))
        let text = try XCTUnwrap(sheet.parts.first { $0.id == "review" }).control
        guard case .text(let shown, _, _) = text else { return XCTFail("the review shows no text") }
        XCTAssertTrue(shown.contains("clock.spot/clock.sh\n#!/bin/sh\n"), shown)

        let answer = try await review.add()

        XCTAssertEqual(answer.effects, [.toast("Installed Clock.")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("clock.spot/clock.sh").path))
        XCTAssertEqual(places.config.read().arrangement.isOnGrid(of: "clock"), false)
    }

    func testAnInstallOfAnIDInYourSpotsChangesNothingAndNamesBothWaysOn() async throws {
        try mine()

        do {
            _ = try await install("clock")
            XCTFail("an install over your own spot passed")
        } catch {
            XCTAssertEqual(
                (error as? SpotError)?.reason,
                "Your spots have clock already. Run `openspot store get clock --replace` to move yours to the Trash, or `openspot store get clock --keep-both` to install this one as clock-2."
            )
        }
        XCTAssertEqual(try text("clock.spot/clock.sh"), "#!/bin/sh\necho mine\n")
    }

    func testReplaceMovesYoursToTheTrashAndCopiesTheNewOne() async throws {
        try mine()

        let said = try await install("clock", .replace)

        XCTAssertEqual(said, "Installed Clock.\n")
        XCTAssertEqual(try text("clock.spot/clock.sh"), "#!/bin/sh\n")
        let trashed = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("trash").path)
        XCTAssertEqual(trashed.map { $0.hasSuffix("-clock.spot") }, [true])
    }

    func testKeepBothInstallsTheNewOneUnderTheNextFreeID() async throws {
        try mine()
        try "#!/bin/sh\n".writeScript(to: spots.appendingPathComponent("clock-2.spot/clock-2.sh"), toml: "title = 'Second clock'")

        let said = try await install("clock", .keepBoth)

        XCTAssertEqual(said, "Installed Clock as clock-3.\n")
        XCTAssertEqual(try text("clock.spot/clock.sh"), "#!/bin/sh\necho mine\n")
        let scan = try SpotsFolder(url: spots).scan()
        XCTAssertEqual(scan.spots.map(\.id).sorted(), ["clock", "clock-2", "clock-3"])
        XCTAssertEqual(scan.spots.first { $0.id == "clock-3" }?.name, "Clock")
        XCTAssertEqual(places.config.read().arrangement.isOnGrid(of: "clock-3"), false)
        XCTAssertEqual(try places.lock.entries().map(\.paths), [["clock-3.spot"]])
    }

    func testAnInstallFromTheSourceOfAKeptBothCopyLeavesTheCopy() async throws {
        try "#!/bin/sh\n".writeScript(to: source.appendingPathComponent("clock.spot/clock.sh"), toml: "title = 'Clock'\nuses = ['spots']")
        _ = try await install("clock", isConfirmed: true)
        _ = try await install("clock", .keepBoth, isConfirmed: true)
        _ = try places.lock.remove("clock", from: spots, discard: places.trash)

        do {
            _ = try await install("clock")
            XCTFail("an install with a use passed with no yes")
        } catch {}
        _ = try await install("clock", isConfirmed: true)

        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("clock-2.spot/clock-2.sh").path))
        XCTAssertEqual(try places.lock.entries().map(\.paths).sorted { $0[0] < $1[0] }, [["clock-2.spot"], ["clock.spot"]])
    }

    func testAKeptBothCopyThatRunsItsOldIDRunsTheCopy() async throws {
        try "#!/bin/sh\necho \"tick from $(basename \"$(dirname \"$0\")\")\"\n".writeScript(to: source.appendingPathComponent("clock.spot/clock.sh"), toml: "title = 'Clock'\nuses = ['spots']")
        try mine()
        _ = try await install("clock", .keepBoth, isConfirmed: true)
        let copy = try XCTUnwrap(try SpotsFolder(url: spots).scan().scripts.first { $0.id == "clock-2" })

        let answer = try await Self.run(["spot", "run", "clock", "tick"], as: copy, in: places, root: root)

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(answer.output, "tick from clock-2.spot\n")
    }

    @MainActor
    private static func run(_ words: [String], as spot: Spot, in places: AppPlaces, root: URL) async throws -> CommandAnswer {
        let runs = SpotRuns(cache: SpotCache(folder: root.appendingPathComponent("cache")))
        defer { runs.quit() }
        let api = CommandAPI(mac: Mac(), places: places, app: FakeRunningApp(), runs: runs)
        let request = CommandRequest(arguments: words, folder: root.path, caller: SpotCaller(spot: spot))
        return await (try XCTUnwrap(api.work(for: request, input: { "" })))()
    }

    func testTheReviewOfAnIDInYourSpotsAsksReplaceKeepBothOrStopInTheWordsOfFinder() async throws {
        try mine()
        let review = try XCTUnwrap(try catalog.install("clock", in: places)).review()
        let sheet = try shown(review)

        XCTAssertEqual(sheet.parts.filter { $0.id != "review" }.map(\.title), ["A spot named “Clock” already exists in your spots. Do you want to replace it with the one you’re installing?", "Keep Both", "Stop", "Replace"])
        XCTAssertNil(sheet.parts.first { $0.id == "install" })

        _ = try await review.press("stop")
        XCTAssertFalse(FileManager.default.fileExists(atPath: spots.appendingPathComponent("clock-2.spot").path))
        XCTAssertEqual(try text("clock.spot/clock.sh"), "#!/bin/sh\necho mine\n")

        let kept = try await review.press("keep-both")
        XCTAssertEqual(kept.effects, [.toast("Installed Clock as clock-2.")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("clock-2.spot/clock-2.sh").path))
    }

    func testReplaceInTheReviewTakesThePlaceOfYours() async throws {
        try mine()
        let review = try XCTUnwrap(try catalog.install("clock", in: places)).review()

        _ = try await review.press("replace")

        XCTAssertEqual(try text("clock.spot/clock.sh"), "#!/bin/sh\n")
    }
}
