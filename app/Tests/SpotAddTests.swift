import XCTest
@testable import OpenspotCore

/// Proves `openspot spot add` and `openspot spot remove`: a spot from a git repository, a folder or a `.spot` file goes into
/// the plugins folder, and only a spot that `spot add` added comes out (N1).
final class SpotAddTests: XCTestCase {
    private struct Host: CommandHost {
        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { true }
    }

    private var root: URL!
    private var plugins: URL!

    private var environment: [String: String] {
        ["OPENSPOT_CONFIG": root.path, "OPENSPOT_PLUGINS": plugins.path, "OPENSPOT_CORE": root.appendingPathComponent("core").path, "PWD": root.path]
    }

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("spot-add-\(UUID().uuidString.prefix(8))")
        plugins = root.appendingPathComponent("plugins")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func answer(_ arguments: [String]) async throws -> CommandAnswer {
        let call = try XCTUnwrap(CommandLineCall(arguments: arguments, environment: environment))
        let work = try XCTUnwrap(CommandAPI(host: Host()).work(for: call, input: { "" }, environment: environment))
        return await work()
    }

    private func repo(_ name: String = "coffee") throws -> GitRepo {
        let repo = try GitRepo(at: root.appendingPathComponent("sources/\(name)"))
        try repo.commit(["coffee.sh": "#!/bin/sh\n# title=Coffee\necho one\n", "README.md": "Coffee\n"])
        return repo
    }

    private func ids() throws -> [String] {
        try PluginFolder(url: plugins).scan().commands.map(\.id)
    }

    func testAGitRepositoryIsClonedIntoAFolderOfItsOwnWithNoGitFolder() async throws {
        let repo = try repo()

        let answer = try await answer(["spot", "add", repo.url.path])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertTrue(answer.output.hasPrefix("Added coffee at "), answer.output)
        XCTAssertEqual(try ids(), ["coffee/coffee"])
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: plugins.appendingPathComponent("coffee/coffee.sh").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: plugins.appendingPathComponent("coffee/.git").path))
    }

    func testAGitURLAddsAsAPathDoes() async throws {
        let repo = try repo()

        let answer = try await answer(["spot", "add", "file://\(repo.url.path)/.git"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(try ids(), ["coffee/coffee"])
    }

    func testAFolderIsCopied() async throws {
        let folder = root.appendingPathComponent("sources/tea")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("tea.sh"))

        let answer = try await answer(["spot", "add", "sources/tea"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(answer.output, "Added tea.\n")
        XCTAssertEqual(try ids(), ["tea/tea"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("tea.sh").path))
    }

    func testASpotFileIsAdded() async throws {
        let file = root.appendingPathComponent("Cups.spot")
        try SharedSpot(files: [.init(path: "cups.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8))]).data.write(to: file)

        let answer = try await answer(["spot", "add", file.path])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(answer.output, "Added cups.\n")
        XCTAssertEqual(try ids(), ["cups"])
    }

    func testASpotThatIsThereAlreadyIsAFaultAndStays() async throws {
        let repo = try repo()
        try FileManager.default.createDirectory(at: plugins.appendingPathComponent("coffee"), withIntermediateDirectories: true)
        try "#!/bin/sh\necho mine\n".writeScript(to: plugins.appendingPathComponent("coffee/mine.sh"))

        let answer = try await answer(["spot", "add", repo.url.path])

        XCTAssertEqual(answer.code, 1)
        XCTAssertEqual(answer.errors, "The plugins folder has coffee already. Run `openspot spot remove coffee` first, or move it away.\n")
        XCTAssertEqual(try ids(), ["coffee/mine"])
    }

    func testASourceThatGitCannotCloneIsAFaultAndLeavesNothing() async throws {
        let answer = try await answer(["spot", "add", "file://\(root.path)/nothing.git"])

        XCTAssertEqual(answer.code, 1)
        XCTAssertTrue(answer.errors.hasPrefix("Openspot cannot add "), answer.errors)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: plugins.path), [])
    }

    func testRemoveTakesOutTheWholeFolderOfAnAddedSpot() async throws {
        let repo = try repo()
        _ = try await answer(["spot", "add", repo.url.path])

        let answer = try await answer(["spot", "remove", "coffee/coffee"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(answer.output, "Removed coffee.\n")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: plugins.path), [])
    }

    func testRemoveTakesTheNameOfTheFolderToo() async throws {
        let repo = try repo()
        _ = try await answer(["spot", "add", repo.url.path])

        let answer = try await answer(["spot", "remove", "coffee"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(try ids(), [])
    }

    func testRemoveLeavesASpotThatAddDidNotAdd() async throws {
        try "#!/bin/sh\n".writeScript(to: plugins.appendingPathComponent("mine.sh"))

        let answer = try await answer(["spot", "remove", "mine"])

        XCTAssertEqual(answer.code, 1)
        XCTAssertEqual(answer.errors, "`openspot spot add` did not add mine, so Openspot leaves it. Move its file to the Trash to remove it.\n")
        XCTAssertEqual(try ids(), ["mine"])
    }

    func testAddAndRemoveCannotRunInARead() throws {
        let read = environment.merging(["OPENSPOT_REASON": "sheet"]) { _, new in new }

        XCTAssertEqual(CommandLineCall(arguments: ["spot", "add", "x"], environment: read), .refused("`openspot spot add` changes your plugins folder, so it cannot run in a read. Run it from a pick or an action."))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "remove", "x"], environment: read), .refused("`openspot spot remove` changes your plugins folder, so it cannot run in a read. Run it from a pick or an action."))
    }

    private func files(in folder: URL) throws -> [String: Data] {
        let paths = FileManager.default.subpaths(atPath: folder.path) ?? []
        var files: [String: Data] = [:]
        for path in paths where !path.hasSuffix("/") {
            var isFolder: ObjCBool = false
            FileManager.default.fileExists(atPath: folder.appendingPathComponent(path).path, isDirectory: &isFolder)
            if !isFolder.boolValue { files[path] = try Data(contentsOf: folder.appendingPathComponent(path)) }
        }
        return files
    }

    func testTheLockKeepsTheSourceTheCommitAndThePathsOfEachAddedSpot() async throws {
        let repo = try repo()
        let file = root.appendingPathComponent("Cups.spot")
        try SharedSpot(files: [.init(path: "cups.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8))]).data.write(to: file)

        _ = try await answer(["spot", "add", repo.url.path])
        _ = try await answer(["spot", "add", file.path])

        let entries = try SpotLock(url: root.appendingPathComponent("spots.lock")).entries()
        XCTAssertEqual(entries.map(\.source), [repo.url.standardizedFileURL.path, file.path])
        XCTAssertEqual(entries.map(\.paths), [["coffee"], ["cups.sh"]])
        XCTAssertEqual(entries.first?.commit?.count, 40)
        XCTAssertNil(entries.last?.commit)
    }

    func testWithNoSourceItAddsTheSameFilesAgainAtTheCommitOfTheLock() async throws {
        let repo = try repo()
        _ = try await answer(["spot", "add", repo.url.path])
        let added = try files(in: plugins)
        let commit = try XCTUnwrap(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries().first?.commit)
        try repo.commit(["coffee.sh": "#!/bin/sh\necho two\n"])
        try FileManager.default.removeItem(at: plugins)

        let answer = try await answer(["spot", "add"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(answer.output, "Added coffee at \(commit.prefix(7)).\n")
        XCTAssertEqual(try files(in: plugins), added)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: plugins.appendingPathComponent("coffee/coffee.sh").path))
    }

    func testWithNoSourceASpotThatIsThereStays() async throws {
        let repo = try repo()
        _ = try await answer(["spot", "add", repo.url.path])

        let answer = try await answer(["spot", "add"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(answer.output, "Each spot of spots.lock is in the plugins folder.\n")
    }

    func testWithNoSourceASourceThatIsGoneIsAFaultAndTheOthersComeBack() async throws {
        let repo = try repo()
        let tea = root.appendingPathComponent("sources/tea")
        try FileManager.default.createDirectory(at: tea, withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: tea.appendingPathComponent("tea.sh"))
        _ = try await answer(["spot", "add", tea.path])
        _ = try await answer(["spot", "add", repo.url.path])
        try FileManager.default.removeItem(at: tea)
        try FileManager.default.removeItem(at: plugins)

        let answer = try await answer(["spot", "add"])

        XCTAssertEqual(answer.code, 1)
        XCTAssertEqual(answer.errors, "tea: Openspot cannot find \(tea.standardizedFileURL.path).\n")
        XCTAssertEqual(try ids(), ["coffee/coffee"])
        XCTAssertEqual(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries().count, 2)
    }
}
