import XCTest
@testable import OpenspotCore

final class SpotAddTests: XCTestCase {
    private final class Host: Mac {
        func eventStore() -> any EventStore { FakeEventStore() }
        func reminderStore() -> any ReminderStore { FakeReminderStore() }
        func showCalendar(at time: Date) throws {}
        func open(_ link: URL) -> Bool { true }
    }

    private var root: URL!
    private var spots: URL!

    private var environment: [String: String] {
        ["OPENSPOT_CONFIG": root.path, "OPENSPOT_SPOTS": spots.path, "OPENSPOT_CORE": root.appendingPathComponent("core").path, "PWD": root.path]
    }

    override func setUpWithError() throws {
        GitRepo.isolate()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("spot-add-\(UUID().uuidString.prefix(8))")
        spots = root.appendingPathComponent("spots")
        try FileManager.default.createDirectory(at: spots, withIntermediateDirectories: true)
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
        try SpotsFolder(url: spots).scan().spots.map(\.id)
    }

    func testAGitRepositoryIsClonedIntoAFolderOfItsOwnWithNoGitFolder() async throws {
        let repo = try repo()

        let answer = try await answer(["spot", "add", repo.url.path])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertTrue(answer.output.hasPrefix("Added coffee at "), answer.output)
        XCTAssertEqual(try ids(), ["coffee"])
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: spots.appendingPathComponent("coffee.spot/coffee.sh").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: spots.appendingPathComponent("coffee.spot/.git").path))
    }

    func testAGitURLAddsAsAPathDoes() async throws {
        let repo = try repo()

        let answer = try await answer(["spot", "add", "file://\(repo.url.path)/.git"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(try ids(), ["coffee"])
    }

    func testAFolderIsCopied() async throws {
        let folder = root.appendingPathComponent("sources/tea")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("tea.sh"))

        let answer = try await answer(["spot", "add", "sources/tea"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(answer.output, "Added tea.\n")
        XCTAssertEqual(try ids(), ["tea"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("tea.sh").path))
    }

    func testASpotFileIsAdded() async throws {
        let file = root.appendingPathComponent("Cups.spot")
        try SpotPackage(files: [.init(path: "cups.spot/cups.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8))]).zip(to: file)

        let answer = try await answer(["spot", "add", file.path])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(answer.output, "Added cups.\n")
        XCTAssertEqual(try ids(), ["cups"])
    }

    func testASpotThatIsThereAlreadyIsAFaultAndStays() async throws {
        let repo = try repo()
        try FileManager.default.createDirectory(at: spots.appendingPathComponent("coffee.spot"), withIntermediateDirectories: true)
        try "#!/bin/sh\necho mine\n".writeScript(to: spots.appendingPathComponent("coffee.spot/mine.sh"))

        let answer = try await answer(["spot", "add", repo.url.path])

        XCTAssertEqual(answer.code, 1)
        XCTAssertEqual(answer.errors, "The spots folder has coffee already. Run `openspot spot remove coffee` first, or move it away.\n")
        XCTAssertEqual(try ids(), ["coffee/mine"])
    }

    func testASourceThatGitCannotCloneIsAFaultAndLeavesNothing() async throws {
        let answer = try await answer(["spot", "add", "file://\(root.path)/nothing.git"])

        XCTAssertEqual(answer.code, 1)
        XCTAssertTrue(answer.errors.hasPrefix("Openspot cannot add "), answer.errors)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: spots.path), [])
    }

    private func remove(_ id: String) throws -> (name: String, discarded: [String]) {
        var discarded: [String] = []
        let trash = root.appendingPathComponent("trash")
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let entry = try SpotLock(url: root.appendingPathComponent("spots.lock")).remove(id, from: spots) { url in
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
        let adding = Task { [spots] in try await lock.add(.git("git://127.0.0.1:\(port)/coffee"), to: spots!) }
        let connection = await Task.detached { Self.accepted(on: listener) }.value
        XCTAssertGreaterThanOrEqual(connection, 0, "git reached the fake server")

        adding.cancel()

        let isClosed = await Task.detached { Self.closes(connection) }.value
        close(connection)
        XCTAssertTrue(isClosed, "git ended")
        _ = try? await adding.value
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: spots.path), [])
    }

    private static func accepted(on listener: Int32) -> Int32 {
        var watch = pollfd(fd: listener, events: Int16(POLLIN), revents: 0)
        guard poll(&watch, 1, 10_000) == 1 else { return -1 }
        return accept(listener, nil, nil)
    }

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

        let removed = try remove("coffee")

        XCTAssertEqual(removed.name, "coffee")
        XCTAssertEqual(removed.discarded, ["coffee.spot"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: spots.path), [])
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
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: spots.path), [])
        XCTAssertEqual(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries(), [])
    }

    func testRemoveLeavesASpotThatAddDidNotAdd() async throws {
        try "#!/bin/sh\n".writeScript(to: spots.spotFile("mine"))

        let answer = try await answer(["spot", "remove", "mine"])

        XCTAssertEqual(answer.code, 1)
        XCTAssertEqual(answer.errors, "`openspot spot add` did not add mine, so Openspot leaves it. Move its file to the Trash to remove it.\n")
        XCTAssertEqual(try ids(), ["mine"])
    }

    func testAddAndRemoveCannotRunInARead() throws {
        let read = environment.merging(["OPENSPOT_REASON": "sheet"]) { _, new in new }

        XCTAssertEqual(CommandLineCall(arguments: ["spot", "add", "x"], environment: read), .refused("`openspot spot add` changes your spots folder, so it cannot run in a read. Run it from a pick or an action."))
        XCTAssertEqual(CommandLineCall(arguments: ["spot", "remove", "x"], environment: read), .refused("`openspot spot remove` changes your spots folder, so it cannot run in a read. Run it from a pick or an action."))
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
        try SpotPackage(files: [.init(path: "cups.spot/cups.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8))]).zip(to: file)

        _ = try await answer(["spot", "add", repo.url.path])
        _ = try await answer(["spot", "add", file.path])

        let entries = try SpotLock(url: root.appendingPathComponent("spots.lock")).entries()
        XCTAssertEqual(entries.map(\.source), [repo.url.standardizedFileURL.path, file.path])
        XCTAssertEqual(entries.map(\.paths), [["coffee.spot"], ["cups.spot/cups.sh"]])
        XCTAssertEqual(entries.first?.commit?.count, 40)
        XCTAssertNil(entries.last?.commit)
    }

    func testWithNoSourceItAddsTheSameFilesAgainAtTheCommitOfTheLock() async throws {
        let repo = try repo()
        _ = try await answer(["spot", "add", repo.url.path])
        let added = try files(in: spots)
        let commit = try XCTUnwrap(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries().first?.commit)
        try repo.commit(["coffee.sh": "#!/bin/sh\necho two\n"])
        try FileManager.default.removeItem(at: spots)

        let answer = try await answer(["spot", "add"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(answer.output, "Added coffee at \(commit.prefix(7)).\n")
        XCTAssertEqual(try files(in: spots), added)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: spots.appendingPathComponent("coffee.spot/coffee.sh").path))
    }

    func testWithNoSourceASpotThatIsThereStays() async throws {
        let repo = try repo()
        _ = try await answer(["spot", "add", repo.url.path])

        let answer = try await answer(["spot", "add"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(answer.output, "Each spot of spots.lock is in the spots folder.\n")
    }

    func testAFirstAddPrintsTheReviewAndNeedsYesWhenItHasAUse() async throws {
        let repo = try repo()
        try repo.commit(["coffee.sh": "#!/bin/sh\n# title=Coffee\n# uses=network\n# on=clock.60\ncurl -s https://example.com\n"])

        let first = try await answer(["spot", "add", repo.url.path])

        XCTAssertEqual(first.code, 1)
        XCTAssertEqual(first.errors, "Coffee\n\nUses\nnetwork\n\nRuns by itself\nCoffee: every 60 seconds\n\nOpenspot added nothing. Run `openspot spot add \(repo.url.standardizedFileURL.path) --yes` to add it.\n")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: spots.path), [])
        XCTAssertEqual(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries(), [])
        let confirmed = try await answer(["spot", "add", repo.url.path, "--yes"])
        XCTAssertEqual(confirmed.code, 0, confirmed.errors)
        XCTAssertEqual(try ids(), ["coffee"])
    }

    func testAFirstAddThatCannotBeReviewedNeedsYes() async throws {
        let repo = try GitRepo(at: root.appendingPathComponent("sources/notes"))
        try repo.commit(["README.md": "Notes\n"])

        let first = try await answer(["spot", "add", repo.url.path])

        XCTAssertEqual(first.code, 1)
        XCTAssertEqual(first.errors, "Openspot cannot review it: This file holds no spot.\nOpenspot added nothing. Run `openspot spot add \(repo.url.standardizedFileURL.path) --yes` to add it.\n")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: spots.path), [])
    }

    func testAnUpdateOfASpotFileFromAnEntryOfItsFolderKeepsItsEqualFiles() async throws {
        let file = root.appendingPathComponent("Foo.spot")
        try SpotPackage(files: [
            .init(path: "foo.spot/a.sh", isExecutable: true, contents: Data("#!/bin/sh\necho two\n".utf8)),
            .init(path: "foo.spot/b.sh", isExecutable: true, contents: Data("#!/bin/sh\necho b\n".utf8))
        ]).zip(to: file)
        try "#!/bin/sh\necho one\n".writeScript(to: spots.appendingPathComponent("foo.spot/a.sh"))
        try "#!/bin/sh\necho b\n".writeScript(to: spots.appendingPathComponent("foo.spot/b.sh"))
        try "#!/bin/sh\necho mine\n".writeScript(to: spots.appendingPathComponent("foo.spot/mine.sh"))
        let lock = SpotLock(url: root.appendingPathComponent("spots.lock"))
        try JSONEncoder().encode([SpotLock.Entry(source: file.path, commit: nil, paths: ["foo.spot"], hash: nil, uses: [])]).write(to: lock.url)

        _ = try await lock.add(.file(file), to: spots, isConfirmed: true) { try FileManager.default.removeItem(at: $0) }

        XCTAssertEqual(try String(contentsOf: spots.appendingPathComponent("foo.spot/a.sh"), encoding: .utf8), "#!/bin/sh\necho two\n")
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("foo.spot/b.sh").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("foo.spot/mine.sh").path))
    }

    func testRemoveTakesTheEntryOfTheSpotAndNotOneWithTheSameNameInAFolder() throws {
        try "#!/bin/sh\n".writeScript(to: spots.appendingPathComponent("tools.spot/notes.sh"))
        try "#!/bin/sh\n".writeScript(to: spots.spotFile("notes"))
        let lock = SpotLock(url: root.appendingPathComponent("spots.lock"))
        try JSONEncoder().encode([
            SpotLock.Entry(source: "/a.spot", commit: nil, paths: ["tools.spot/notes.sh"], hash: nil, uses: []),
            SpotLock.Entry(source: "/b.spot", commit: nil, paths: ["notes.spot/notes.sh"], hash: nil, uses: [])
        ]).write(to: lock.url)

        let removed = try lock.remove("notes", from: spots) { try FileManager.default.removeItem(at: $0) }

        XCTAssertEqual(removed.source, "/b.spot")
        XCTAssertTrue(FileManager.default.fileExists(atPath: spots.appendingPathComponent("tools.spot/notes.sh").path))
    }

    func testALockWithTheOldUsesReadsThemAsTheUsesThatTookThem() throws {
        let lock = SpotLock(url: root.appendingPathComponent("spots.lock"))
        try Data(#"[{"source":"/a.spot","paths":["a.sh"],"uses":["settings","update","network"]}]"#.utf8).write(to: lock.url)

        XCTAssertEqual(try lock.entries().map(\.uses), [[.spots, .app, .network]])
    }

    func testAnAddOfASignedSpotKeepsItsAddressAndKeyAndAnUpdateFromAnotherKeyNeedsYes() async throws {
        let file = root.appendingPathComponent("Cups.spot")
        let mine = try AccountKey.make()
        let cups = try SpotPackage(files: [.init(path: "cups.spot/cups.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8))]).signed(by: mine)
        try cups.zip(to: file)
        let lock = SpotLock(url: root.appendingPathComponent("spots.lock"))

        _ = try await lock.add(.file(file), to: spots, isConfirmed: true)

        let release = try XCTUnwrap(cups.releaseLog(in: "cups.spot")?.last)
        XCTAssertEqual(try lock.entries().map(\.address), [release.address])
        XCTAssertEqual(try lock.entries().map(\.key), [mine.publicKey])

        let changed = try SpotPackage(files: [.init(path: "cups.spot/cups.sh", isExecutable: true, contents: Data("#!/bin/sh\necho two\n".utf8))]).signed(by: AccountKey.make())
        try changed.zip(to: file)
        do {
            _ = try await lock.add(.file(file), to: spots)
            XCTFail("An update from another key needs --yes.")
        } catch {
            XCTAssertTrue((error as? SpotError)?.reason.hasPrefix("Another key signed this version than the one you have.") == true, "\(error)")
        }
        XCTAssertEqual(try String(contentsOf: spots.appendingPathComponent("cups.spot/cups.sh"), encoding: .utf8), "#!/bin/sh\n")
    }

    func testAFolderThatCannotTravelIsStillAddedWithItsHash() async throws {
        let folder = root.appendingPathComponent("sources/odd")
        try "#!/bin/sh\n".writeScript(to: folder.appendingPathComponent("odd.sh"))
        try "safe\u{202E}evil".write(to: folder.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let answer = try await answer(["spot", "add", "sources/odd", "--yes"])

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertNotNil(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries().first?.hash)
    }

    func testALockOfAnOlderOpenspotReadsEachPathInItsSpotFolder() throws {
        let lock = SpotLock(url: root.appendingPathComponent("spots.lock"))
        try Data(#"[{"source":"/a","paths":["coffee","notes.sh","notes.md","notes.preview.txt","tools/x.sh","tea.spot/tea.sh"]}]"#.utf8).write(to: lock.url)

        XCTAssertEqual(try lock.entries().map(\.paths), [["coffee.spot", "notes.spot/notes.sh", "notes.spot/readme.md", "notes.spot/preview.txt", "tools.spot/x.sh", "tea.spot/tea.sh"]])
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
                group.addTask { [spots] in _ = try? await lock.add(.folder(source), to: spots!) }
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
        XCTAssertEqual(try String(contentsOf: spots.appendingPathComponent("coffee.spot/coffee.sh"), encoding: .utf8), "#!/bin/sh\n# title=Coffee\necho two\n")
        XCTAssertEqual(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries().map(\.commit), [commit])
    }

    func testAnUpdateThatAddsAUseNeedsYes() async throws {
        let repo = try repo()
        _ = try await answer(["spot", "add", repo.url.path])
        let before = try files(in: spots)
        let commit = try repo.commit(["coffee.sh": "#!/bin/sh\n# title=Coffee\n# uses=network\ncurl example.com\n"])

        let refused = try await answer(["spot", "add", repo.url.path])

        XCTAssertEqual(refused.code, 1)
        XCTAssertEqual(refused.errors, "This version adds: network.\nOpenspot kept the one you have. Run `openspot spot add \(repo.url.standardizedFileURL.path) --yes` to update it.\n")
        XCTAssertEqual(try files(in: spots), before)
        let accepted = try await answer(["spot", "add", repo.url.path, "--yes"])
        XCTAssertEqual(accepted.code, 0, accepted.errors)
        XCTAssertEqual(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries().map(\.uses), [[.network]])
        XCTAssertEqual(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries().map(\.commit), [commit])
    }

    func testAnUpdateThatCanDoMoreWithTheSameUsesNeedsYes() async throws {
        let repo = try repo()
        _ = try await answer(["spot", "add", repo.url.path])
        let before = try files(in: spots)
        try repo.commit(["coffee.sh": "#!/bin/sh\n# title=Coffee\n# on=clock.60\nrm -f /tmp/x\n"])

        let refused = try await answer(["spot", "add", repo.url.path])

        XCTAssertEqual(refused.code, 1)
        XCTAssertEqual(refused.errors, "This version can do more.\nCan also: Delete files with rm\nRuns by itself: Coffee: every 60 seconds\nOpenspot kept the one you have. Run `openspot spot add \(repo.url.standardizedFileURL.path) --yes` to update it.\n")
        XCTAssertEqual(try files(in: spots), before)
    }

    func testWithNoSourceAFolderThatCanDoMoreNeedsYes() async throws {
        let tea = root.appendingPathComponent("sources/tea")
        try FileManager.default.createDirectory(at: tea, withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: tea.appendingPathComponent("tea.sh"))
        _ = try await answer(["spot", "add", tea.path])
        try "#!/bin/sh\nrm -f /tmp/x\n".writeScript(to: tea.appendingPathComponent("tea.sh"))
        try FileManager.default.removeItem(at: spots)

        let refused = try await answer(["spot", "add"])

        XCTAssertEqual(refused.code, 1)
        XCTAssertEqual(refused.errors, "tea: This version can do more.\nCan also: Delete files with rm\nOpenspot kept the one you have. Run `openspot spot add --yes` to update it.\n")
        XCTAssertEqual(try ids(), [])
    }

    func testAnUpdateMovesTheOldCopyToTheTrashWithEachPathTheNewOneDrops() async throws {
        let tea = root.appendingPathComponent("sources/tea.spot")
        try FileManager.default.createDirectory(at: tea.deletingLastPathComponent(), withIntermediateDirectories: true)
        try SpotPackage(files: [.init(path: "tea.spot/tea.sh", isExecutable: true, contents: Data("#!/bin/sh\necho one\n".utf8)), .init(path: "tea.spot/old.sh", isExecutable: true, contents: Data("#!/bin/sh\n".utf8))]).zip(to: tea)
        let lock = SpotLock(url: root.appendingPathComponent("spots.lock"))
        var discarded: [String] = []
        let trash = root.appendingPathComponent("trash")
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let discard: (URL) throws -> Void = { url in
            discarded.append(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: trash.appendingPathComponent(url.lastPathComponent))
        }
        _ = try await lock.add(SpotSource(text: tea.path, place: root), to: spots, discard: discard)
        try SpotPackage(files: [.init(path: "tea.spot/tea.sh", isExecutable: true, contents: Data("#!/bin/sh\necho two\n".utf8))]).zip(to: tea)

        _ = try await lock.add(SpotSource(text: tea.path, place: root), to: spots, discard: discard)

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
        try FileManager.default.removeItem(at: spots)

        let refused = try await answer(["spot", "add"])

        XCTAssertEqual(refused.code, 1)
        XCTAssertEqual(refused.errors, "tea: This version adds: screen.\nOpenspot kept the one you have. Run `openspot spot add --yes` to update it.\n")
        XCTAssertEqual(try ids(), [])
        let accepted = try await answer(["spot", "add", "--yes"])
        XCTAssertEqual(accepted.code, 0, accepted.errors)
        XCTAssertEqual(try ids(), ["tea"])
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
        try FileManager.default.removeItem(at: spots)

        let answer = try await answer(["spot", "add"])

        XCTAssertEqual(answer.code, 1)
        XCTAssertEqual(answer.errors, "tea: Openspot cannot find \(tea.standardizedFileURL.path).\n")
        XCTAssertEqual(try ids(), ["coffee"])
        XCTAssertEqual(try SpotLock(url: root.appendingPathComponent("spots.lock")).entries().count, 2)
    }
}
