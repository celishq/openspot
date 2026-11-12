import XCTest
@testable import OpenspotCore

/// Proves `openspot spot add` and `openspot spot remove`: a spot from a git repository, a folder or a `.spot` file goes into
/// the plugins folder, and only a spot that `spot add` added comes out (protocol: The openspot command).
final class SpotAddTests: XCTestCase {
    private final class Host: Mac {
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
        GitRepo.isolate()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("spot-add-\(UUID().uuidString.prefix(8))")
        plugins = root.appendingPathComponent("plugins")
        try FileManager.default.createDirectory(at: plugins, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func answer(_ arguments: [String]) async throws -> CommandAnswer {
        let call = try XCTUnwrap(CommandLineCall(arguments: arguments, environment: environment))
        let work = try XCTUnwrap(CommandAPI(mac: Host()).work(for: call, input: { "" }, environment: environment))
        return await work()
    }

    private func repo(_ name: String = "coffee") throws -> GitRepo {
        let repo = try GitRepo(at: root.appendingPathComponent("sources/\(name)"))
        try repo.commit(["coffee.sh": "#!/bin/sh\n# title=Coffee\necho one\n", "README.md": "Coffee\n"])
        return repo
    }

    private func ids() throws -> [String] {
        try SpotFolder(url: plugins).scan().spots.map(\.id)
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

    /// Removes through the lock as the API does, with the Trash of the test in place of the person's.
    private func remove(_ id: String) throws -> (name: String, discarded: [String]) {
        var discarded: [String] = []
        let trash = root.appendingPathComponent("trash")
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let entry = try SpotLock(url: root.appendingPathComponent("spots.lock")).remove(id, from: plugins) { url in
            discarded.append(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: trash.appendingPathComponent(url.lastPathComponent))
        }
        return (entry.name, discarded)
    }

    func testAStopEndsTheGitOfAnAddAndLeavesNothing() async throws {
        let listener = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(listener) }
        var address = sockaddr_in(sin_len: UInt8(MemoryLayout<sockaddr_in>.size), sin_family: sa_family_t(AF_INET), sin_port: 0, sin_addr: in_addr(s_addr: inet_addr("127.0.0.1")), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                _ = Darwin.bind(listener, $0, size)
                _ = Darwin.listen(listener, 8)
                _ = getsockname(listener, $0, &size)
            }
        }
        let port = UInt16(bigEndian: address.sin_port)
        let lock = SpotLock(url: root.appendingPathComponent("spots.lock"))
        let adding = Task { [plugins] in try await lock.add(.git("git://127.0.0.1:\(port)/coffee"), to: plugins!) }
        let connection = await Task.detached { Self.accepted(on: listener) }.value
        XCTAssertGreaterThanOrEqual(connection, 0, "git reached the fake server")

        adding.cancel()

        let isClosed = await Task.detached { Self.closes(connection) }.value
        close(connection)
        XCTAssertTrue(isClosed, "git ended")
        _ = try? await adding.value
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: plugins.path), [])
    }

    /// The first connection to a listener within 10 seconds, or -1.
    private static func accepted(on listener: Int32) -> Int32 {
        var watch = pollfd(fd: listener, events: Int16(POLLIN), revents: 0)
        guard poll(&watch, 1, 10_000) == 1 else { return -1 }
        return accept(listener, nil, nil)
    }

    /// Whether the other end closes a connection within 5 seconds, after all that it sends.
    private static func closes(_ connection: Int32) -> Bool {
        var buffer = [UInt8](repeating: 0, count: 4096)
        var watch = pollfd(fd: connection, events: Int16(POLLIN), revents: 0)
        let end = Date().addingTimeInterval(5)
        while Date() < end {
            guard poll(&watch, 1, 100) == 1 else { continue }
            if read(connection, &buffer, buffer.count) <= 0 { return true }
        }
        return false
    }

    func testRemoveMovesTheWholeFolderOfAnAddedSpotToTheTrash() async throws {
        let repo = try repo()
        _ = try await answer(["spot", "add", repo.url.path])

        let removed = try remove("coffee/coffee")

        XCTAssertEqual(removed.name, "coffee")
        XCTAssertEqual(removed.discarded, ["coffee"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: plugins.path), [])
        XCTAssertEqual(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries(), [])
    }

    func testRemoveTakesTheNameOfTheFolderToo() async throws {
        let repo = try repo()
        _ = try await answer(["spot", "add", repo.url.path])

        _ = try remove("coffee")

        XCTAssertEqual(try ids(), [])
    }

    func testAFolderThatCannotBeCopiedWholeLeavesNothing() async throws {
        let folder = root.appendingPathComponent("sources/tea")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("a.sh"))
        try "secret".write(to: folder.appendingPathComponent("z.txt"), atomically: true, encoding: .utf8)
        chmod(folder.appendingPathComponent("z.txt").path, 0)
        defer { chmod(folder.appendingPathComponent("z.txt").path, 0o644) }

        let answer = try await answer(["spot", "add", folder.path])

        XCTAssertEqual(answer.code, 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: plugins.path), [])
        XCTAssertEqual(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries(), [])
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

    func testAFirstAddPrintsTheReviewAndNeedsYesWhenItHasAUse() async throws {
        let repo = try repo()
        try repo.commit(["coffee.sh": "#!/bin/sh\n# title=Coffee\n# uses=network\n# on=clock.60\ncurl -s https://example.com\n"])

        let first = try await answer(["spot", "add", repo.url.path])

        XCTAssertEqual(first.code, 1)
        XCTAssertEqual(first.errors, "Coffee\n\nUses\nnetwork\n\nRuns by itself\nCoffee: every 60 seconds\n\nOpenspot added nothing. Run `openspot spot add \(repo.url.standardizedFileURL.path) --yes` to add it.\n")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: plugins.path), [])
        XCTAssertEqual(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries(), [])
        let confirmed = try await answer(["spot", "add", repo.url.path, "--yes"])
        XCTAssertEqual(confirmed.code, 0, confirmed.errors)
        XCTAssertEqual(try ids(), ["coffee/coffee"])
    }

    func testAFirstAddThatCannotBeReviewedNeedsYes() async throws {
        let repo = try GitRepo(at: root.appendingPathComponent("sources/notes"))
        try repo.commit(["README.md": "Notes\n"])

        let first = try await answer(["spot", "add", repo.url.path])

        XCTAssertEqual(first.code, 1)
        XCTAssertEqual(first.errors, "Openspot cannot review it: This file holds no spot.\nOpenspot added nothing. Run `openspot spot add \(repo.url.standardizedFileURL.path) --yes` to add it.\n")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: plugins.path), [])
    }

    func testAnUpdateOfASpotFileFromAnEntryOfItsFolderKeepsItsEqualFiles() async throws {
        let file = root.appendingPathComponent("Foo.spot")
        try SharedSpot(files: [
            .init(path: "foo/a.sh", isExecutable: true, contents: Data("#!/bin/sh\necho two\n".utf8)),
            .init(path: "foo/b.sh", isExecutable: true, contents: Data("#!/bin/sh\necho b\n".utf8))
        ]).data.write(to: file)
        try FileManager.default.createDirectory(at: plugins.appendingPathComponent("foo"), withIntermediateDirectories: true)
        try "#!/bin/sh\necho one\n".writeScript(to: plugins.appendingPathComponent("foo/a.sh"))
        try "#!/bin/sh\necho b\n".writeScript(to: plugins.appendingPathComponent("foo/b.sh"))
        try "#!/bin/sh\necho mine\n".writeScript(to: plugins.appendingPathComponent("foo/mine.sh"))
        let lock = SpotLock(url: root.appendingPathComponent("spots.lock"))
        try JSONEncoder().encode([SpotLock.Entry(source: file.path, commit: nil, paths: ["foo"], hash: nil, uses: [])]).write(to: lock.url)

        _ = try await lock.add(.file(file), to: plugins, isConfirmed: true) { try FileManager.default.removeItem(at: $0) }

        XCTAssertEqual(try String(contentsOf: plugins.appendingPathComponent("foo/a.sh"), encoding: .utf8), "#!/bin/sh\necho two\n")
        XCTAssertTrue(FileManager.default.fileExists(atPath: plugins.appendingPathComponent("foo/b.sh").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: plugins.appendingPathComponent("foo/mine.sh").path))
    }

    func testRemoveTakesTheEntryOfTheSpotAndNotOneWithTheSameNameInAFolder() throws {
        try FileManager.default.createDirectory(at: plugins.appendingPathComponent("tools"), withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: plugins.appendingPathComponent("tools/notes.sh"))
        try "#!/bin/sh\n".writeScript(to: plugins.appendingPathComponent("notes.sh"))
        let lock = SpotLock(url: root.appendingPathComponent("spots.lock"))
        try JSONEncoder().encode([
            SpotLock.Entry(source: "/a.spot", commit: nil, paths: ["tools/notes.sh"], hash: nil, uses: []),
            SpotLock.Entry(source: "/b.spot", commit: nil, paths: ["notes.sh"], hash: nil, uses: [])
        ]).write(to: lock.url)

        let removed = try lock.remove("notes", from: plugins) { try FileManager.default.removeItem(at: $0) }

        XCTAssertEqual(removed.source, "/b.spot")
        XCTAssertTrue(FileManager.default.fileExists(atPath: plugins.appendingPathComponent("tools/notes.sh").path))
    }

    func testAddsAtTheSameTimeLoseNoEntryOfTheLock() async throws {
        let sources = try (0..<12).map { index in
            let folder = root.appendingPathComponent("sources/s\(index)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("a.sh"))
            return folder
        }
        let lock = SpotLock(url: root.appendingPathComponent("spots.lock"))

        await withTaskGroup(of: Void.self) { group in
            for source in sources {
                group.addTask { [plugins] in _ = try? await lock.add(.folder(source), to: plugins!) }
            }
        }

        XCTAssertEqual(Set(try lock.entries().map(\.source)), Set(sources.map(\.path)))
    }

    func testTheLockKeepsAHashOfTheFilesAndTheUses() async throws {
        let repo = try repo()
        try repo.commit(["coffee.sh": "#!/bin/sh\n# title=Coffee\n# uses=network,app\necho one\n"])

        _ = try await answer(["spot", "add", repo.url.path, "--yes"])

        let entry = try XCTUnwrap(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries().first)
        XCTAssertEqual(entry.hash?.count, 64)
        XCTAssertEqual(entry.uses, [.app, .network])
    }

    func testAnUpdateThatAddsNoUseAppliesQuietly() async throws {
        let repo = try repo()
        _ = try await answer(["spot", "add", repo.url.path])
        let commit = try repo.commit(["coffee.sh": "#!/bin/sh\n# title=Coffee\necho two\n"])

        let answer = try await answer(["spot", "add", repo.url.path])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(answer.output, "Updated coffee to \(commit.prefix(7)).\n")
        XCTAssertEqual(try String(contentsOf: plugins.appendingPathComponent("coffee/coffee.sh"), encoding: .utf8), "#!/bin/sh\n# title=Coffee\necho two\n")
        XCTAssertEqual(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries().map(\.commit), [commit])
    }

    func testAnUpdateThatAddsAUseNeedsYes() async throws {
        let repo = try repo()
        _ = try await answer(["spot", "add", repo.url.path])
        let before = try files(in: plugins)
        let commit = try repo.commit(["coffee.sh": "#!/bin/sh\n# title=Coffee\n# uses=network\ncurl example.com\n"])

        let refused = try await answer(["spot", "add", repo.url.path])

        XCTAssertEqual(refused.code, 1)
        XCTAssertEqual(refused.errors, "This version adds: network.\nOpenspot kept the one you have. Run `openspot spot add \(repo.url.standardizedFileURL.path) --yes` to update it.\n")
        XCTAssertEqual(try files(in: plugins), before)
        let accepted = try await answer(["spot", "add", repo.url.path, "--yes"])
        XCTAssertEqual(accepted.code, 0, accepted.errors)
        XCTAssertEqual(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries().map(\.uses), [[.network]])
        XCTAssertEqual(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries().map(\.commit), [commit])
    }

    func testAnUpdateThatCanDoMoreWithTheSameUsesNeedsYes() async throws {
        let repo = try repo()
        _ = try await answer(["spot", "add", repo.url.path])
        let before = try files(in: plugins)
        try repo.commit(["coffee.sh": "#!/bin/sh\n# title=Coffee\n# on=clock.60\nrm -f /tmp/x\n"])

        let refused = try await answer(["spot", "add", repo.url.path])

        XCTAssertEqual(refused.code, 1)
        XCTAssertEqual(refused.errors, "This version can do more.\nCan also: Delete files with rm\nRuns by itself: Coffee: every 60 seconds\nOpenspot kept the one you have. Run `openspot spot add \(repo.url.standardizedFileURL.path) --yes` to update it.\n")
        XCTAssertEqual(try files(in: plugins), before)
    }

    func testWithNoSourceAFolderThatCanDoMoreNeedsYes() async throws {
        let tea = root.appendingPathComponent("sources/tea")
        try FileManager.default.createDirectory(at: tea, withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: tea.appendingPathComponent("tea.sh"))
        _ = try await answer(["spot", "add", tea.path])
        try "#!/bin/sh\nrm -f /tmp/x\n".writeScript(to: tea.appendingPathComponent("tea.sh"))
        try FileManager.default.removeItem(at: plugins)

        let refused = try await answer(["spot", "add"])

        XCTAssertEqual(refused.code, 1)
        XCTAssertEqual(refused.errors, "tea: This version can do more.\nCan also: Delete files with rm\nOpenspot kept the one you have. Run `openspot spot add --yes` to update it.\n")
        XCTAssertEqual(try ids(), [])
    }

    func testAnUpdateMovesTheOldCopyToTheTrashWithEachPathTheNewOneDrops() async throws {
        let tea = root.appendingPathComponent("sources/tea.spot")
        try FileManager.default.createDirectory(at: tea.deletingLastPathComponent(), withIntermediateDirectories: true)
        try SharedSpot(files: [.init(path: "tea.sh", isExecutable: true, contents: Data("#!/bin/sh\necho one\n".utf8)), .init(path: "old.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8))]).data.write(to: tea)
        let lock = SpotLock(url: root.appendingPathComponent("spots.lock"))
        var discarded: [String] = []
        let trash = root.appendingPathComponent("trash")
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let discard: (URL) throws -> Void = { url in
            discarded.append(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: trash.appendingPathComponent(url.lastPathComponent))
        }
        _ = try await lock.add(SpotSource(text: tea.path, place: root), to: plugins, discard: discard)
        try SharedSpot(files: [.init(path: "tea.sh", isExecutable: true, contents: Data("#!/bin/sh\necho two\n".utf8))]).data.write(to: tea)

        _ = try await lock.add(SpotSource(text: tea.path, place: root), to: plugins, discard: discard)

        XCTAssertEqual(discarded.sorted(), ["old.sh", "tea.sh"])
        XCTAssertEqual(try String(contentsOf: trash.appendingPathComponent("tea.sh"), encoding: .utf8), "#!/bin/sh\necho one\n")
        XCTAssertEqual(try ids(), ["tea"])
    }

    func testWithNoSourceAFolderThatGrewAUseNeedsYes() async throws {
        let tea = root.appendingPathComponent("sources/tea")
        try FileManager.default.createDirectory(at: tea, withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: tea.appendingPathComponent("tea.sh"))
        _ = try await answer(["spot", "add", tea.path])
        try "#!/bin/sh\n# uses=screen\n".writeScript(to: tea.appendingPathComponent("tea.sh"))
        try FileManager.default.removeItem(at: plugins)

        let refused = try await answer(["spot", "add"])

        XCTAssertEqual(refused.code, 1)
        XCTAssertEqual(refused.errors, "tea: This version adds: screen.\nOpenspot kept the one you have. Run `openspot spot add --yes` to update it.\n")
        XCTAssertEqual(try ids(), [])
        let accepted = try await answer(["spot", "add", "--yes"])
        XCTAssertEqual(accepted.code, 0, accepted.errors)
        XCTAssertEqual(try ids(), ["tea/tea"])
        XCTAssertEqual(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries().map(\.uses), [[.screen]])
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
