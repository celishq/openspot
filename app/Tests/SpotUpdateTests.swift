import XCTest
@testable import OpenspotCore

final class SpotUpdateTests: XCTestCase {
    private var root: URL!
    private var places: AppPlaces!

    override func setUpWithError() throws {
        root = try temporaryFolder()
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        places = places(builtIn: source)
        try "#!/bin/sh\necho one\n".writeScript(to: source.appendingPathComponent("clock.spot/clock.sh"), toml: "title = 'Clock'")
        try "#!/bin/sh\npbcopy\n".writeScript(to: source.appendingPathComponent("paste.spot/paste.sh"), toml: "title = 'Paste'\nuses = ['clipboard']")
    }

    private func places(builtIn: URL) -> AppPlaces {
        let trash = trash
        return AppPlaces(
            environment: [
                "OPENSPOT_CONFIG": root.appendingPathComponent("config").path, "OPENSPOT_SPOTS": spots.path, "OPENSPOT_CORE": root.appendingPathComponent("core").path,
                "OPENSPOT_EXAMPLES": builtIn.path
            ],
            home: root,
            defaults: UserDefaults(suiteName: "openspot-update-\(UUID().uuidString)") ?? .standard,
            trash: { url in try FileManager.default.moveItem(at: url, to: trash.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)) },
            defaultConfig: nil
        )
    }

    private var spots: URL { root.appendingPathComponent("spots", isDirectory: true) }
    private var source: URL { root.appendingPathComponent("friends", isDirectory: true) }
    private var trash: URL { root.appendingPathComponent("trash", isDirectory: true) }

    private func call(_ words: [String]) async throws -> CommandAnswer {
        let api = CommandAPI(mac: Mac(), places: places)
        return try await XCTUnwrap(api.work(for: CommandRequest(arguments: words, folder: root.path), input: { "" }))()
    }

    private func installed(_ id: String) async throws {
        let answer = try await call(["store", "get", id, "--yes"])
        XCTAssertEqual(answer.code, 0, answer.errors)
    }

    private func release(_ id: String, _ body: String, toml: String, in store: URL? = nil) throws {
        let folder = (store ?? source).appendingPathComponent("\(id).spot")
        try write(body, to: folder.appendingPathComponent("\(id).sh"))
        try toml.write(to: folder.appendingPathComponent("spot.toml"), atomically: true, encoding: .utf8)
        let later = try XCTUnwrap(ISO8601DateFormatter().date(from: "2031-11-25T12:00:00Z"))
        try FileManager.default.setAttributes([.modificationDate: later], ofItemAtPath: folder.appendingPathComponent("spot.toml").path)
    }

    private func write(_ body: String, to file: URL) throws {
        try body.write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
    }

    private func text(_ path: String) throws -> String {
        try String(contentsOf: spots.appendingPathComponent(path), encoding: .utf8)
    }

    private func listed(_ id: String) async throws -> TextBlock? {
        let answer = try await call(["store", "list"])
        XCTAssertEqual(answer.code, 0, answer.errors)
        return TextBlock.blocks(in: answer.output).first { $0.value("item") == id }
    }

    private func version(_ id: String) throws -> String? {
        try places.lock.entries().first { $0.paths == ["\(id).spot"] }?.version
    }

    func testStoreListTakesTheNewerVersionOfAnUntouchedCopy() async throws {
        try await installed("clock")
        try release("clock", "#!/bin/sh\necho two\n", toml: "title = 'Clock'\n")

        let row = try await listed("clock")

        XCTAssertEqual(try text("clock.spot/clock.sh"), "#!/bin/sh\necho two\n")
        XCTAssertEqual(try version("clock"), try SpotVersion(of: source.appendingPathComponent("clock.spot")).text)
        XCTAssertNil(row?.value("copy"))
        XCTAssertEqual(row?.value("updated"), "25 Nov 2031")
    }

    func testACopyOfTheBuiltInStoreUpdatesAfterTheAppsExamplesFolderMoves() async throws {
        try await installed("clock")
        let moved = root.appendingPathComponent("Other.app/examples", isDirectory: true)
        try FileManager.default.createDirectory(at: moved.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: source, to: moved)
        places = places(builtIn: moved)
        try release("clock", "#!/bin/sh\necho two\n", toml: "title = 'Clock'\n", in: moved)

        let answer = try await call(["store", "update", "clock"])

        XCTAssertEqual(answer.output, "Updated Clock to its version of 25 Nov 2031.\n", answer.errors)
        XCTAssertEqual(try text("clock.spot/clock.sh"), "#!/bin/sh\necho two\n")
    }

    func testStoreUpdateTakesTheNewerVersionOfOneSpot() async throws {
        try await installed("clock")
        let same = try await call(["store", "update", "clock"])
        XCTAssertEqual(same.output, "Clock is up to date.\n")
        try release("clock", "#!/bin/sh\necho two\n", toml: "title = 'Clock'\n")

        let answer = try await call(["store", "update", "clock"])

        XCTAssertEqual(answer.output, "Updated Clock to its version of 25 Nov 2031.\n")
        XCTAssertEqual(try text("clock.spot/clock.sh"), "#!/bin/sh\necho two\n")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: trash.path), [])
    }

    func testAnUpdateThatAsksForANewUseWaitsForAYesAndNamesOnlyTheNewPower() async throws {
        try await installed("paste")
        try release("paste", "#!/bin/sh\npbcopy\n", toml: "title = 'Paste'\nuses = ['clipboard', 'network']\n")

        let row = try await listed("paste")
        XCTAssertEqual(row?.value("copy"), "update")
        let refused = try await call(["store", "update", "paste"])
        XCTAssertEqual(refused.code, 1)
        XCTAssertEqual(refused.errors, "This version adds: network.\nOpenspot kept the one you have. Run `openspot store update paste --yes` to update it.\n")
        XCTAssertFalse(try text("paste.spot/spot.toml").contains("network"))
        let all = try await call(["store", "update"])
        XCTAssertEqual(all.output, "Paste waits for your yes. Run `openspot store update paste` to see what it adds.\n")

        let taken = try await call(["store", "update", "paste", "--yes"])

        XCTAssertEqual(taken.code, 0, taken.errors)
        XCTAssertTrue(try text("paste.spot/spot.toml").contains("network"))
    }

    func testAnEditedCopyIsAForkThatTakesNoUpdate() async throws {
        try await installed("clock")
        try write("#!/bin/sh\necho mine\n", to: spots.appendingPathComponent("clock.spot/clock.sh"))
        try release("clock", "#!/bin/sh\necho two\n", toml: "title = 'Clock'\n")

        let row = try await listed("clock")
        let refused = try await call(["store", "update", "clock"])

        XCTAssertEqual(row?.value("copy"), "edited")
        XCTAssertEqual(refused.code, 1)
        XCTAssertEqual(refused.errors, "Clock is edited, so it takes no update. Run `openspot store revert clock` to replace it with the version of its store.\n")
        XCTAssertEqual(try text("clock.spot/clock.sh"), "#!/bin/sh\necho mine\n")
    }

    func testRevertMovesAnEditedCopyToTheTrashAndInstallsTheVersionOfItsStore() async throws {
        try await installed("clock")
        let clean = try await call(["store", "revert", "clock"])
        XCTAssertEqual(clean.output, "Clock has no edit to revert.\n")
        try write("#!/bin/sh\necho mine\n", to: spots.appendingPathComponent("clock.spot/clock.sh"))
        try release("clock", "#!/bin/sh\necho two\n", toml: "title = 'Clock'\n")
        let data = root.appendingPathComponent("config/data/clock/kept")
        try FileManager.default.createDirectory(at: data.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "kept".write(to: data, atomically: true, encoding: .utf8)

        let answer = try await call(["store", "revert", "clock"])

        XCTAssertEqual(answer.output, "Reverted Clock to its version of 25 Nov 2031. Your edited copy is in the Trash.\n")
        XCTAssertEqual(try text("clock.spot/clock.sh"), "#!/bin/sh\necho two\n")
        XCTAssertEqual(try version("clock"), try SpotVersion(of: source.appendingPathComponent("clock.spot")).text)
        XCTAssertTrue(FileManager.default.fileExists(atPath: data.path))
        let trashed = try XCTUnwrap(try FileManager.default.contentsOfDirectory(atPath: trash.path).first)
        XCTAssertEqual(try String(contentsOf: trash.appendingPathComponent(trashed).appendingPathComponent("clock.sh"), encoding: .utf8), "#!/bin/sh\necho mine\n")
    }

    func testAKeptBothCopyUpdatesUnderItsOwnID() async throws {
        try "#!/bin/sh\necho mine\n".writeScript(to: spots.appendingPathComponent("clock.spot/clock.sh"), toml: "title = 'My clock'")
        let kept = try await call(["store", "get", "clock", "--keep-both"])
        XCTAssertEqual(kept.code, 0, kept.errors)
        try release("clock", "#!/bin/sh\necho two\n", toml: "title = 'Clock'\n")

        let answer = try await call(["store", "update", "clock-2"])

        XCTAssertEqual(answer.output, "Updated Clock to its version of 25 Nov 2031.\n")
        XCTAssertEqual(try text("clock-2.spot/clock-2.sh"), "#!/bin/sh\necho two\n")
        XCTAssertEqual(try text("clock.spot/clock.sh"), "#!/bin/sh\necho mine\n")
    }
}
